import { createHash, randomBytes, randomUUID } from 'node:crypto';

const defaultAccessTtlSeconds = 15 * 60;
const defaultRefreshTtlSeconds = 30 * 24 * 60 * 60;
const deviceIdPattern = /^[A-Za-z0-9._:-]{1,128}$/;

export class AuthService {
  constructor({
    store,
    db,
    huaweiClient,
    accessTtlSeconds = defaultAccessTtlSeconds,
    refreshTtlSeconds = defaultRefreshTtlSeconds,
    now = () => new Date()
  }) {
    this.store = store;
    this.db = db;
    this.huaweiClient = huaweiClient;
    this.accessTtlSeconds = normalizeTtl(accessTtlSeconds, defaultAccessTtlSeconds, 60, 24 * 60 * 60);
    this.refreshTtlSeconds = normalizeTtl(
      refreshTtlSeconds,
      defaultRefreshTtlSeconds,
      60 * 60,
      180 * 24 * 60 * 60
    );
    this.now = now;
  }

  isHuaweiConfigured() {
    return this.huaweiClient.isConfigured();
  }

  ensureAnonymousUser(deviceIdInput) {
    const deviceId = normalizeDeviceId(deviceIdInput);
    const mappedUser = this.db.users[deviceId];
    if (mappedUser && !this.store.hasIdentityForUser(mappedUser.id)) {
      return mappedUser;
    }
    if (mappedUser) {
      anchorAccountUser(mappedUser);
      remapUserDevices(this.db, mappedUser);
      this.store.saveUser(mappedUser, this.db.meta);
    }
    if (!this.db.users[deviceId]) {
      const now = this.nowIso();
      this.db.users[deviceId] = {
        id: `user-${randomUUID()}`,
        deviceId,
        deviceIds: [deviceId],
        displayName: '',
        avatarUrl: '',
        leaderboardOptIn: false,
        leaderboardOptedInAt: null,
        status: 'active',
        createdAt: now,
        updatedAt: now,
        favorites: [],
        wrongs: {},
        answers: []
      };
    }
    return this.db.users[deviceId];
  }

  resolvePrincipal(authorization, deviceId) {
    const token = parseBearerToken(authorization);
    if (!token) {
      return {
        authenticated: false,
        session: undefined,
        user: this.ensureAnonymousUser(deviceId)
      };
    }
    if (!token.startsWith('ark_access_')) {
      throw new AuthError(401, '登录凭证无效');
    }

    const session = this.store.findActiveAccessSession(hashToken(token), this.nowIso());
    if (!session) {
      throw new AuthError(401, '登录凭证无效或已过期');
    }
    const user = findUserById(this.db, session.userId);
    if (!user || user.status !== 'active') {
      throw new AuthError(401, '用户不存在或已停用');
    }
    return {
      authenticated: true,
      session,
      user
    };
  }

  async loginWithHuawei({ authorizationCode, deviceId }) {
    const sourceUser = this.ensureAnonymousUser(deviceId);
    const profile = await this.huaweiClient.exchangeAuthorizationCode(authorizationCode);
    const now = this.nowIso();
    const existingIdentity = this.store.findIdentity('huawei', profile.providerSubject);
    const existingUser = existingIdentity
      ? findUserById(this.db, existingIdentity.userId)
      : undefined;
    if (existingIdentity && !existingUser) {
      throw new AuthError(409, '华为账号关联的用户记录不存在');
    }
    if (existingUser && existingUser.status !== 'active') {
      throw new AuthError(403, '该账号已停用，请联系管理员');
    }

    const user = existingUser || sourceUser;
    const mergedUserId = existingUser && existingUser.id !== sourceUser.id
      ? sourceUser.id
      : undefined;
    if (mergedUserId) {
      mergeUserState(user, sourceUser);
    }

    user.displayName = profile.displayName || user.displayName;
    user.avatarUrl = profile.avatarUrl || user.avatarUrl;
    user.updatedAt = now;
    this.db.meta.updatedAt = now;
    anchorAccountUser(user);

    const identity = {
      id: existingIdentity?.id || `identity-${randomUUID()}`,
      userId: user.id,
      provider: 'huawei',
      providerSubject: profile.providerSubject,
      unionId: profile.unionId,
      createdAt: existingIdentity?.createdAt || now,
      updatedAt: now
    };
    const issued = issueSession(user.id, now, this.accessTtlSeconds, this.refreshTtlSeconds);

    this.store.authenticateUser({
      user,
      mergedUserId,
      identity,
      session: issued.session,
      metadata: this.db.meta
    });
    remapUserDevices(this.db, user, mergedUserId);

    return {
      ...issued.response,
      user: publicUser(user)
    };
  }

  refresh(refreshTokenInput) {
    const refreshToken = String(refreshTokenInput || '').trim();
    if (!refreshToken.startsWith('ark_refresh_')) {
      throw new AuthError(401, '刷新凭证无效');
    }
    const now = this.nowIso();
    const existing = this.store.findActiveRefreshSession(hashToken(refreshToken), now);
    if (!existing) {
      throw new AuthError(401, '刷新凭证无效或已过期');
    }
    const user = findUserById(this.db, existing.userId);
    if (!user || user.status !== 'active') {
      throw new AuthError(401, '用户不存在或已停用');
    }

    const issued = issueSession(user.id, now, this.accessTtlSeconds, this.refreshTtlSeconds, existing.id);
    if (!this.store.rotateSession(issued.session)) {
      throw new AuthError(401, '刷新凭证已失效');
    }
    return {
      ...issued.response,
      user: publicUser(user)
    };
  }

  logout(principal) {
    if (!principal.authenticated || !principal.session) {
      throw new AuthError(401, '当前未登录');
    }
    this.store.revokeSession(principal.session.id, this.nowIso());
  }

  profile(principal) {
    return {
      authenticated: principal.authenticated,
      user: principal.authenticated ? publicUser(principal.user) : null
    };
  }

  updateLeaderboardPreference(principal, enabled) {
    if (!principal.authenticated) {
      throw new AuthError(401, '请先登录后再设置排行榜参与状态');
    }
    if (typeof enabled !== 'boolean') {
      throw new AuthError(400, 'enabled 必须是布尔值');
    }

    const now = this.nowIso();
    if (enabled && !principal.user.leaderboardOptedInAt) {
      principal.user.leaderboardOptedInAt = now;
    }
    principal.user.leaderboardOptIn = enabled;
    principal.user.updatedAt = now;
    this.db.meta.updatedAt = now;
    this.store.saveUserProfile(principal.user, this.db.meta);
    return this.profile(principal);
  }

  nowIso() {
    const value = this.now();
    return (value instanceof Date ? value : new Date(value)).toISOString();
  }
}

export class AuthError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'AuthError';
    this.status = status;
  }
}

function issueSession(userId, nowIso, accessTtlSeconds, refreshTtlSeconds, sessionId) {
  const accessToken = `ark_access_${randomBytes(32).toString('base64url')}`;
  const refreshToken = `ark_refresh_${randomBytes(48).toString('base64url')}`;
  const nowMs = Date.parse(nowIso);
  const accessExpiresAt = new Date(nowMs + accessTtlSeconds * 1000).toISOString();
  const refreshExpiresAt = new Date(nowMs + refreshTtlSeconds * 1000).toISOString();

  return {
    session: {
      id: sessionId || `session-${randomUUID()}`,
      userId,
      accessTokenHash: hashToken(accessToken),
      accessExpiresAt,
      refreshTokenHash: hashToken(refreshToken),
      refreshExpiresAt,
      createdAt: nowIso,
      updatedAt: nowIso
    },
    response: {
      tokenType: 'Bearer',
      accessToken,
      accessExpiresIn: accessTtlSeconds,
      refreshToken,
      refreshExpiresIn: refreshTtlSeconds
    }
  };
}

function mergeUserState(target, source) {
  const targetAnswerIds = new Set(target.answers.map((answer) => answer.id));
  const overlappingWrongQuestions = new Set(
    source.answers
      .filter((answer) => answer.isCorrect === false && targetAnswerIds.has(answer.id))
      .map((answer) => answer.questionId)
  );
  target.answers = [
    ...target.answers,
    ...source.answers.filter((answer) => !targetAnswerIds.has(answer.id))
  ].sort((left, right) => String(left.submittedAt).localeCompare(String(right.submittedAt)));
  target.favorites = [...new Set([...target.favorites, ...source.favorites])];

  for (const [questionId, sourceWrong] of Object.entries(source.wrongs)) {
    const targetWrong = target.wrongs[questionId];
    if (!targetWrong) {
      target.wrongs[questionId] = { ...sourceWrong };
      continue;
    }
    const latest = String(sourceWrong.updatedAt) > String(targetWrong.updatedAt)
      ? sourceWrong
      : targetWrong;
    target.wrongs[questionId] = {
      questionId,
      wrongCount: overlappingWrongQuestions.has(questionId)
        ? Math.max(targetWrong.wrongCount, sourceWrong.wrongCount)
        : targetWrong.wrongCount + sourceWrong.wrongCount,
      mastered: latest.mastered,
      updatedAt: latest.updatedAt
    };
  }

  target.createdAt = String(target.createdAt) < String(source.createdAt)
    ? target.createdAt
    : source.createdAt;
  target.updatedAt = String(target.updatedAt) > String(source.updatedAt)
    ? target.updatedAt
    : source.updatedAt;
}

function remapUserDevices(db, user, mergedUserId) {
  for (const [deviceId, mappedUser] of Object.entries(db.users)) {
    if (mappedUser.id === user.id || (mergedUserId && mappedUser.id === mergedUserId)) {
      delete db.users[deviceId];
    }
  }
  for (const deviceId of user.deviceIds) {
    db.users[deviceId] = user;
  }
}

function anchorAccountUser(user) {
  const accountDeviceId = `account/${user.id}`;
  user.deviceId = accountDeviceId;
  user.deviceIds = [accountDeviceId];
}

function publicUser(user) {
  return {
    id: user.id,
    displayName: user.displayName,
    avatarUrl: user.avatarUrl,
    leaderboardOptIn: user.leaderboardOptIn,
    leaderboardOptedInAt: user.leaderboardOptedInAt || null
  };
}

function findUserById(db, userId) {
  return Object.values(db.users).find((user) => user.id === userId);
}

function parseBearerToken(authorization) {
  const value = Array.isArray(authorization) ? authorization[0] : authorization;
  if (!value) {
    return '';
  }
  const match = String(value).match(/^Bearer\s+(\S+)$/i);
  if (!match) {
    throw new AuthError(401, 'Authorization 请求头格式错误');
  }
  return match[1];
}

function normalizeDeviceId(value) {
  const deviceId = Array.isArray(value) ? value[0] : String(value || 'demo-device').trim();
  if (!deviceIdPattern.test(deviceId)) {
    throw new AuthError(400, '匿名设备 ID 格式无效');
  }
  return deviceId;
}

function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

function normalizeTtl(value, fallback, minimum, maximum) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(maximum, Math.max(minimum, Math.floor(parsed)));
}
