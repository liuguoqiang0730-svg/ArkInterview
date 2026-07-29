import {
  createHash,
  randomBytes,
  randomUUID,
  scryptSync,
  timingSafeEqual
} from 'node:crypto';

const defaultSessionTtlSeconds = 8 * 60 * 60;
const defaultLoginWindowSeconds = 15 * 60;
const defaultLoginLockSeconds = 15 * 60;
const defaultMaximumLoginFailures = 5;
const maximumAuditPageSize = 100;
const usernamePattern = /^[A-Za-z0-9._-]{3,32}$/;
const validRoles = new Set(['super_admin', 'content_editor', 'moderator']);
const validStatuses = new Set(['active', 'disabled']);
const rolePermissions = {
  super_admin: [
    'admin:manage',
    'questions:read',
    'questions:write',
    'leaderboard:read',
    'leaderboard:moderate'
  ],
  content_editor: ['questions:read', 'questions:write'],
  moderator: ['leaderboard:read', 'leaderboard:moderate']
};

export class AdminAuthService {
  constructor({
    store,
    legacyToken = '',
    sessionTtlSeconds = defaultSessionTtlSeconds,
    loginWindowSeconds = defaultLoginWindowSeconds,
    loginLockSeconds = defaultLoginLockSeconds,
    maximumLoginFailures = defaultMaximumLoginFailures,
    now = () => new Date()
  }) {
    this.store = store;
    this.legacyToken = String(legacyToken || '').trim();
    this.sessionTtlSeconds = normalizeTtl(sessionTtlSeconds);
    this.loginWindowSeconds = normalizePositiveInteger(
      loginWindowSeconds,
      defaultLoginWindowSeconds,
      60,
      24 * 60 * 60
    );
    this.loginLockSeconds = normalizePositiveInteger(
      loginLockSeconds,
      defaultLoginLockSeconds,
      60,
      24 * 60 * 60
    );
    this.maximumLoginFailures = normalizePositiveInteger(
      maximumLoginFailures,
      defaultMaximumLoginFailures,
      3,
      20
    );
    this.now = now;
  }

  status() {
    return {
      enabled: this.store.countAdminUsers() > 0 || Boolean(this.legacyToken),
      bootstrapAvailable: this.store.countAdminUsers() === 0 && Boolean(this.legacyToken)
    };
  }

  bootstrap({ authorization, username, password, displayName, ipAddress = '' }) {
    if (!this.legacyToken) {
      throw new AdminAuthError(503, '首次初始化需要先配置 ADMIN_TOKEN');
    }
    const token = parseBearerToken(authorization);
    if (!token || !safeSecretEqual(token, this.legacyToken)) {
      throw new AdminAuthError(401, '初始化令牌无效或缺失');
    }
    if (this.store.countAdminUsers() > 0) {
      throw new AdminAuthError(409, '管理员账号已经初始化');
    }
    const user = this.createUserRecord({
      username,
      password,
      displayName,
      role: 'super_admin'
    });
    const result = this.issueLogin(user, ipAddress);
    this.recordAudit(null, {
      actorAdmin: user,
      action: 'auth.bootstrap',
      targetType: 'admin_account',
      targetId: user.id,
      summary: `初始化超级管理员 ${user.displayName}`
    }, ipAddress);
    return result;
  }

  login({ username, password, ipAddress = '' }) {
    const normalizedUsername = normalizeUsername(username);
    const normalizedIp = normalizeIpAddress(ipAddress);
    const loginKey = hashToken(`${normalizedUsername}\n${normalizedIp}`);
    const timestamp = this.nowIso();
    const timestampMs = Date.parse(timestamp);
    const retentionSeconds = Math.max(this.loginWindowSeconds, this.loginLockSeconds) * 2;
    this.store.pruneAdminLoginLimits(
      new Date(timestampMs - retentionSeconds * 1000).toISOString()
    );
    const limit = this.store.getAdminLoginLimit(loginKey);
    if (limit?.lockedUntil && Date.parse(limit.lockedUntil) > timestampMs) {
      throw rateLimitError(limit.lockedUntil, timestampMs);
    }

    const user = this.store.findAdminUserByUsername(normalizedUsername);
    const passwordValue = String(password || '');
    if (
      !user ||
      user.status !== 'active' ||
      !verifyPassword(passwordValue, user.passwordSalt, user.passwordHash)
    ) {
      const withinWindow = limit &&
        timestampMs - Date.parse(limit.windowStartedAt) < this.loginWindowSeconds * 1000;
      const failedCount = withinWindow ? limit.failedCount + 1 : 1;
      const lockedUntil = failedCount >= this.maximumLoginFailures
        ? new Date(timestampMs + this.loginLockSeconds * 1000).toISOString()
        : null;
      this.store.saveAdminLoginLimit({
        loginKey,
        username: normalizedUsername,
        ipAddress: normalizedIp,
        failedCount,
        windowStartedAt: withinWindow ? limit.windowStartedAt : timestamp,
        lockedUntil,
        updatedAt: timestamp
      });
      this.recordAudit(null, {
        actorAdmin: user || {
          id: null,
          username: normalizedUsername,
          displayName: normalizedUsername,
          role: 'unknown'
        },
        action: lockedUntil ? 'auth.login_locked' : 'auth.login_failed',
        targetType: 'admin_account',
        targetId: user?.id || normalizedUsername,
        summary: lockedUntil
          ? `管理员登录失败次数过多，账号来源已临时锁定`
          : `管理员登录失败（${failedCount}/${this.maximumLoginFailures}）`,
        details: { failedCount }
      }, normalizedIp);
      if (lockedUntil) {
        throw rateLimitError(lockedUntil, timestampMs);
      }
      throw new AdminAuthError(401, '管理员账号或密码错误');
    }
    this.store.clearAdminLoginLimit(loginKey);
    const result = this.issueLogin(user, normalizedIp);
    this.recordAudit(null, {
      actorAdmin: user,
      action: 'auth.login_succeeded',
      targetType: 'admin_session',
      targetId: result.sessionId,
      summary: `${user.displayName} 登录管理后台`
    }, normalizedIp);
    return result;
  }

  resolvePrincipal(authorization) {
    const token = parseBearerToken(authorization);
    if (!token) {
      throw new AdminAuthError(401, '管理员登录凭证缺失');
    }
    if (this.legacyToken && safeSecretEqual(token, this.legacyToken)) {
      return {
        authenticated: true,
        serviceToken: true,
        session: null,
        admin: {
          id: 'service-token',
          username: 'service-token',
          displayName: '部署服务令牌',
          role: 'super_admin',
          status: 'active',
          permissions: [...rolePermissions.super_admin]
        }
      };
    }
    if (!token.startsWith('ark_admin_')) {
      throw new AdminAuthError(401, '管理员登录凭证无效');
    }
    const resolved = this.store.findActiveAdminSession(hashToken(token), this.nowIso());
    if (!resolved) {
      throw new AdminAuthError(401, '管理员登录已失效或过期');
    }
    return {
      authenticated: true,
      serviceToken: false,
      session: resolved.session,
      admin: publicAdmin(resolved.user)
    };
  }

  logout(principal, ipAddress = '') {
    if (!principal.session) {
      throw new AdminAuthError(400, '部署服务令牌不能通过会话接口退出');
    }
    this.store.revokeAdminSession(principal.session.id, this.nowIso());
    this.recordAudit(principal, {
      action: 'auth.logout',
      targetType: 'admin_session',
      targetId: principal.session.id,
      summary: `${principal.admin.displayName} 退出管理后台`
    }, ipAddress);
  }

  listUsers() {
    return this.store.listAdminUsers().map(publicAdmin);
  }

  createUser({ username, password, displayName, role }) {
    return publicAdmin(this.createUserRecord({ username, password, displayName, role }));
  }

  createUserRecord({ username, password, displayName, role }) {
    const normalizedUsername = normalizeUsername(username);
    const normalizedDisplayName = normalizeDisplayName(displayName);
    const normalizedRole = normalizeRole(role);
    const passwordRecord = hashPassword(password);
    if (this.store.findAdminUserByUsername(normalizedUsername)) {
      throw new AdminAuthError(409, '管理员用户名已存在');
    }
    const timestamp = this.nowIso();
    const user = {
      id: `admin-${randomUUID()}`,
      username: normalizedUsername,
      displayName: normalizedDisplayName,
      role: normalizedRole,
      passwordSalt: passwordRecord.salt,
      passwordHash: passwordRecord.hash,
      status: 'active',
      lastLoginAt: null,
      createdAt: timestamp,
      updatedAt: timestamp
    };
    this.store.createAdminUser(user);
    return user;
  }

  updateUser(userIdInput, payload, currentAdminId) {
    const userId = String(userIdInput || '').trim();
    const user = this.store.findAdminUserById(userId);
    if (!user) {
      throw new AdminAuthError(404, '管理员账号不存在');
    }

    const nextRole = payload.role === undefined ? user.role : normalizeRole(payload.role);
    const nextStatus = payload.status === undefined ? user.status : normalizeStatus(payload.status);
    const roleChanged = nextRole !== user.role;
    if (
      user.role === 'super_admin' &&
      user.status === 'active' &&
      (nextRole !== 'super_admin' || nextStatus !== 'active') &&
      this.activeSuperAdminCount() <= 1
    ) {
      throw new AdminAuthError(409, '必须至少保留一个启用的超级管理员');
    }
    if (user.id === currentAdminId && nextStatus !== 'active') {
      throw new AdminAuthError(409, '不能停用当前登录账号');
    }

    const passwordChanged = payload.password !== undefined && String(payload.password || '').length > 0;
    const passwordRecord = passwordChanged ? hashPassword(payload.password) : null;
    user.displayName = payload.displayName === undefined
      ? user.displayName
      : normalizeDisplayName(payload.displayName);
    user.role = nextRole;
    user.status = nextStatus;
    if (passwordRecord) {
      user.passwordSalt = passwordRecord.salt;
      user.passwordHash = passwordRecord.hash;
    }
    user.updatedAt = this.nowIso();
    this.store.updateAdminUser(user, {
      revokeSessions: passwordChanged || nextStatus !== 'active' || roleChanged
    });
    return publicAdmin(user);
  }

  requirePermission(principal, permission) {
    if (!principal.admin.permissions.includes(permission)) {
      throw new AdminAuthError(403, '当前管理员没有执行此操作的权限');
    }
  }

  listSessions({ adminId = '', status = 'all' } = {}, currentSessionId = '') {
    const normalizedStatus = String(status || 'all').trim();
    if (!['all', 'active', 'expired', 'revoked'].includes(normalizedStatus)) {
      throw new AdminAuthError(400, '会话状态筛选无效');
    }
    const timestampMs = Date.parse(this.nowIso());
    return this.store.listAdminSessions({
      adminId: String(adminId || '').trim()
    }).map((session) => publicAdminSession(session, timestampMs, currentSessionId))
      .filter((session) => normalizedStatus === 'all' || session.status === normalizedStatus);
  }

  revokeSession(sessionIdInput, principal) {
    const sessionId = String(sessionIdInput || '').trim();
    const session = this.store.findAdminSessionById(sessionId);
    if (!session) {
      throw new AdminAuthError(404, '管理员会话不存在');
    }
    if (session.id === principal.session?.id) {
      throw new AdminAuthError(409, '不能在会话管理中强制下线当前会话，请使用退出登录');
    }
    if (session.revokedAt || Date.parse(session.expiresAt) <= Date.parse(this.nowIso())) {
      throw new AdminAuthError(409, '管理员会话已经失效');
    }
    this.store.revokeAdminSession(session.id, this.nowIso());
    return session;
  }

  revokeUserSessions(adminUserIdInput, principal) {
    const adminUserId = String(adminUserIdInput || '').trim();
    const user = this.store.findAdminUserById(adminUserId);
    if (!user) {
      throw new AdminAuthError(404, '管理员账号不存在');
    }
    if (adminUserId === principal.admin.id) {
      throw new AdminAuthError(409, '不能强制下线当前登录账号');
    }
    const result = this.store.revokeAdminSessionsForUser(adminUserId, this.nowIso());
    return { user: publicAdmin(user), revokedCount: result.changes };
  }

  listAuditEvents({
    action = '',
    actorId = '',
    query = '',
    from = '',
    to = '',
    page = 1,
    pageSize = 20
  } = {}) {
    const normalizedAction = String(action || '').trim();
    const normalizedActorId = String(actorId || '').trim();
    const normalizedQuery = String(query || '').trim();
    if (normalizedAction.length > 64 || normalizedActorId.length > 80) {
      throw new AdminAuthError(400, '审计筛选参数过长');
    }
    if (normalizedQuery.length > 100) {
      throw new AdminAuthError(400, '审计搜索内容不能超过 100 个字符');
    }
    const normalizedPage = normalizePositiveInteger(page, 1, 1, Number.MAX_SAFE_INTEGER);
    const normalizedPageSize = normalizePositiveInteger(pageSize, 20, 1, maximumAuditPageSize);
    const fromDate = normalizeAuditDate(from, false);
    const toDate = normalizeAuditDate(to, true);
    if (fromDate && toDate && Date.parse(fromDate) > Date.parse(toDate)) {
      throw new AdminAuthError(400, '审计开始日期不能晚于结束日期');
    }
    const offset = (normalizedPage - 1) * normalizedPageSize;
    const result = this.store.listAdminAuditEvents({
      action: normalizedAction,
      actorId: normalizedActorId,
      query: normalizedQuery,
      from: fromDate,
      to: toDate,
      offset,
      limit: normalizedPageSize
    });
    const totalPages = Math.max(1, Math.ceil(result.total / normalizedPageSize));
    const effectivePage = Math.min(normalizedPage, totalPages);
    if (effectivePage !== normalizedPage) {
      return this.listAuditEvents({
        action,
        actorId,
        query,
        from,
        to,
        page: effectivePage,
        pageSize: normalizedPageSize
      });
    }
    return {
      items: result.items,
      pagination: {
        page: effectivePage,
        pageSize: normalizedPageSize,
        totalItems: result.total,
        totalPages,
        hasPrevious: effectivePage > 1,
        hasNext: effectivePage < totalPages
      }
    };
  }

  recordAudit(principal, event, ipAddress = '') {
    const actor = event.actorAdmin || principal?.admin || {
      id: null,
      username: 'system',
      displayName: '系统',
      role: 'system'
    };
    this.store.createAdminAuditEvent({
      id: `admin-audit-${randomUUID()}`,
      actorAdminId: actor.id || null,
      actorUsername: String(actor.username || 'unknown').slice(0, 64),
      actorDisplayName: String(actor.displayName || actor.username || '未知操作人').slice(0, 64),
      actorRole: String(actor.role || 'unknown').slice(0, 32),
      action: String(event.action || 'unknown').slice(0, 64),
      targetType: String(event.targetType || 'unknown').slice(0, 64),
      targetId: String(event.targetId || '').slice(0, 160),
      summary: String(event.summary || '').slice(0, 300),
      details: event.details || {},
      ipAddress: normalizeIpAddress(ipAddress),
      createdAt: this.nowIso()
    });
  }

  issueLogin(user, ipAddress = '') {
    const timestamp = this.nowIso();
    const token = `ark_admin_${randomBytes(36).toString('base64url')}`;
    const expiresAt = new Date(
      Date.parse(timestamp) + this.sessionTtlSeconds * 1000
    ).toISOString();
    user.lastLoginAt = timestamp;
    user.updatedAt = timestamp;
    const session = {
      id: `admin-session-${randomUUID()}`,
      tokenHash: hashToken(token),
      ipAddress: normalizeIpAddress(ipAddress),
      expiresAt,
      createdAt: timestamp,
      updatedAt: timestamp
    };
    this.store.createAdminSession(user, session);
    return {
      tokenType: 'Bearer',
      accessToken: token,
      expiresIn: this.sessionTtlSeconds,
      sessionId: session.id,
      admin: publicAdmin(user)
    };
  }

  activeSuperAdminCount() {
    return this.store.listAdminUsers().filter(
      (user) => user.role === 'super_admin' && user.status === 'active'
    ).length;
  }

  nowIso() {
    const value = this.now();
    return (value instanceof Date ? value : new Date(value)).toISOString();
  }
}

export class AdminAuthError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'AdminAuthError';
    this.status = status;
  }
}

export function publicAdmin(user) {
  return {
    id: user.id,
    username: user.username,
    displayName: user.displayName,
    role: user.role,
    status: user.status,
    permissions: [...(rolePermissions[user.role] || [])],
    lastLoginAt: user.lastLoginAt || null,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt
  };
}

function parseBearerToken(authorization) {
  const value = Array.isArray(authorization) ? authorization[0] : authorization;
  if (!value) {
    return '';
  }
  const match = String(value).match(/^Bearer\s+(\S+)$/i);
  if (!match) {
    throw new AdminAuthError(401, 'Authorization 请求头格式错误');
  }
  return match[1];
}

function normalizeUsername(value) {
  const username = String(value || '').trim().toLowerCase();
  if (!usernamePattern.test(username)) {
    throw new AdminAuthError(400, '用户名必须为 3 至 32 位字母、数字、点、下划线或短横线');
  }
  return username;
}

function normalizeDisplayName(value) {
  const displayName = String(value || '').trim().replace(/\s+/g, ' ');
  if (displayName.length < 2 || displayName.length > 64) {
    throw new AdminAuthError(400, '显示名称必须包含 2 至 64 个字符');
  }
  return displayName;
}

function normalizeRole(value) {
  const role = String(value || '').trim();
  if (!validRoles.has(role)) {
    throw new AdminAuthError(400, '管理员角色无效');
  }
  return role;
}

function normalizeStatus(value) {
  const status = String(value || '').trim();
  if (!validStatuses.has(status)) {
    throw new AdminAuthError(400, '管理员状态无效');
  }
  return status;
}

function hashPassword(passwordInput) {
  const password = String(passwordInput || '');
  if (password.length < 12 || password.length > 128) {
    throw new AdminAuthError(400, '管理员密码必须包含 12 至 128 个字符');
  }
  const salt = randomBytes(16).toString('hex');
  return {
    salt,
    hash: scryptSync(password, salt, 64).toString('hex')
  };
}

function verifyPassword(password, salt, expectedHash) {
  if (!salt || !expectedHash || password.length > 128) {
    return false;
  }
  const actual = scryptSync(password, salt, 64);
  const expected = Buffer.from(expectedHash, 'hex');
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

function safeSecretEqual(left, right) {
  const leftDigest = createHash('sha256').update(String(left)).digest();
  const rightDigest = createHash('sha256').update(String(right)).digest();
  return timingSafeEqual(leftDigest, rightDigest);
}

function normalizeTtl(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return defaultSessionTtlSeconds;
  }
  return Math.min(7 * 24 * 60 * 60, Math.max(5 * 60, Math.floor(parsed)));
}

function normalizePositiveInteger(value, fallback, minimum, maximum) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed)) {
    return fallback;
  }
  return Math.min(maximum, Math.max(minimum, parsed));
}

function normalizeIpAddress(value) {
  return String(value || 'unknown').trim().slice(0, 64) || 'unknown';
}

function rateLimitError(lockedUntil, nowMs) {
  const error = new AdminAuthError(429, '登录失败次数过多，请稍后再试');
  error.retryAfter = Math.max(1, Math.ceil((Date.parse(lockedUntil) - nowMs) / 1000));
  return error;
}

function publicAdminSession(session, nowMs, currentSessionId) {
  const status = session.revokedAt
    ? 'revoked'
    : Date.parse(session.expiresAt) <= nowMs
      ? 'expired'
      : 'active';
  return {
    id: session.id,
    adminUserId: session.adminUserId,
    username: session.username,
    displayName: session.displayName,
    role: session.role,
    ipAddress: session.ipAddress || 'unknown',
    status,
    current: session.id === currentSessionId,
    expiresAt: session.expiresAt,
    revokedAt: session.revokedAt,
    createdAt: session.createdAt
  };
}

function normalizeAuditDate(value, endOfDay) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    return '';
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
    throw new AdminAuthError(400, '审计日期必须使用 YYYY-MM-DD 格式');
  }
  const [year, month, day] = normalized.split('-').map(Number);
  const calendarDate = new Date(Date.UTC(year, month - 1, day));
  if (
    calendarDate.getUTCFullYear() !== year ||
    calendarDate.getUTCMonth() !== month - 1 ||
    calendarDate.getUTCDate() !== day
  ) {
    throw new AdminAuthError(400, '审计日期无效');
  }
  return `${normalized}${endOfDay ? 'T23:59:59.999+08:00' : 'T00:00:00.000+08:00'}`;
}
