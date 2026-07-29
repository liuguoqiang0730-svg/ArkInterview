import {
  createHash,
  randomBytes,
  randomUUID,
  scryptSync,
  timingSafeEqual
} from 'node:crypto';

const defaultSessionTtlSeconds = 8 * 60 * 60;
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
    now = () => new Date()
  }) {
    this.store = store;
    this.legacyToken = String(legacyToken || '').trim();
    this.sessionTtlSeconds = normalizeTtl(sessionTtlSeconds);
    this.now = now;
  }

  status() {
    return {
      enabled: this.store.countAdminUsers() > 0 || Boolean(this.legacyToken),
      bootstrapAvailable: this.store.countAdminUsers() === 0 && Boolean(this.legacyToken)
    };
  }

  bootstrap({ authorization, username, password, displayName }) {
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
    return this.issueLogin(user);
  }

  login({ username, password }) {
    const normalizedUsername = normalizeUsername(username);
    const user = this.store.findAdminUserByUsername(normalizedUsername);
    const passwordValue = String(password || '');
    if (
      !user ||
      user.status !== 'active' ||
      !verifyPassword(passwordValue, user.passwordSalt, user.passwordHash)
    ) {
      throw new AdminAuthError(401, '管理员账号或密码错误');
    }
    return this.issueLogin(user);
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

  logout(principal) {
    if (!principal.session) {
      throw new AdminAuthError(400, '部署服务令牌不能通过会话接口退出');
    }
    this.store.revokeAdminSession(principal.session.id, this.nowIso());
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

  issueLogin(user) {
    const timestamp = this.nowIso();
    const token = `ark_admin_${randomBytes(36).toString('base64url')}`;
    const expiresAt = new Date(
      Date.parse(timestamp) + this.sessionTtlSeconds * 1000
    ).toISOString();
    user.lastLoginAt = timestamp;
    user.updatedAt = timestamp;
    this.store.createAdminSession(user, {
      id: `admin-session-${randomUUID()}`,
      tokenHash: hashToken(token),
      expiresAt,
      createdAt: timestamp,
      updatedAt: timestamp
    });
    return {
      tokenType: 'Bearer',
      accessToken: token,
      expiresIn: this.sessionTtlSeconds,
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
