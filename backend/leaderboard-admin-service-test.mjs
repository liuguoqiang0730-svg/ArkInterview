import assert from 'node:assert/strict';
import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AuthError, AuthService } from './auth-service.mjs';
import {
  LeaderboardAdminError,
  LeaderboardAdminService
} from './leaderboard-admin-service.mjs';
import { openSqliteStore } from './sqlite-store.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const tempDir = path.join(rootDir, '.tmp', `leaderboard-admin-${process.pid}-${Date.now()}`);
const dbFile = path.join(tempDir, 'leaderboard-admin.sqlite');

await mkdir(tempDir, { recursive: true });

let activeStore;
try {
  const opened = await openSqliteStore({
    dbFile,
    legacyDbFile: path.join(tempDir, 'missing.json'),
    createInitialData: createSnapshot
  });
  activeStore = opened.store;

  let clock = new Date('2026-07-24T09:00:00.000Z');
  const auth = new AuthService({
    store: opened.store,
    db: opened.snapshot,
    huaweiClient: fakeHuaweiClient(),
    accessTtlSeconds: 24 * 60 * 60,
    now: () => clock
  });

  const riskyLogin = await createAccount(auth, opened, {
    code: 'risky-code',
    deviceId: 'risky-device',
    answers: burstAnswers('risky', 20, '2026-07-24T09:00:00.000Z', 2)
  });
  await createAccount(auth, opened, {
    code: 'normal-code',
    deviceId: 'normal-device',
    answers: burstAnswers('normal', 3, '2026-07-24T09:00:00.000Z', 120)
  });

  const service = new LeaderboardAdminService({
    store: opened.store,
    db: opened.snapshot,
    now: () => clock
  });

  const audit = service.listUsers();
  assert.equal(audit.summary.totalAccounts, 2, 'only linked accounts should enter the audit list');
  assert.equal(audit.summary.flaggedAccounts, 1, 'the answer burst should be marked for review');
  assert.equal(audit.summary.suspendedAccounts, 0, 'frequency detection must not auto-suspend accounts');
  const risky = audit.items.find((item) => item.userId === riskyLogin.user.id);
  assert.equal(risky.riskLevel, 'review');
  assert.equal(risky.maxAttemptsInMinute, 20);
  assert.equal(risky.totalAttempts, 20);
  assert.equal(risky.score, 2, 'audit score should use the same first-correct rule as the public leaderboard');
  assert.match(risky.riskReasons[0], /60 秒内提交 20 次/);
  assert.equal(service.listUsers({ risk: 'flagged' }).items.length, 1);
  assert.equal(service.listUsers({ query: '高频测试账号' }).items[0].userId, riskyLogin.user.id);
  const firstPage = service.listUsers({ page: 1, pageSize: 1 });
  const secondPage = service.listUsers({ page: 2, pageSize: 1 });
  assert.equal(firstPage.pagination.totalItems, 2);
  assert.equal(firstPage.pagination.totalPages, 2);
  assert.equal(firstPage.pagination.hasNext, true);
  assert.equal(secondPage.pagination.hasPrevious, true);
  assert.notEqual(firstPage.items[0].userId, secondPage.items[0].userId);

  clock = new Date('2026-07-24T10:00:00.000Z');
  const suspended = service.updateUserStatus({
    userId: riskyLogin.user.id,
    status: 'suspended',
    reason: '一分钟内连续提交次数异常，人工复核后暂停排行榜资格',
    operator: '刘国强',
    note: '已保留提交时间线和测试设备信息，等待账号持有人说明。'
  });
  assert.equal(suspended.status, 'suspended');
  assert.equal(suspended.score, 2, 'moderation audit should retain the historical score after suspension');
  assert.equal(suspended.lastModeration.action, 'suspend');
  assert.equal(suspended.lastModeration.operator, '刘国强');
  assert.match(suspended.lastModeration.note, /提交时间线/);
  assert.equal(service.listUsers().summary.suspendedAccounts, 1);
  assert.equal(
    opened.store.listLeaderboardRows().some((row) => row.userId === riskyLogin.user.id),
    false,
    'suspended users must be removed from public leaderboard scoring'
  );
  assert.throws(
    () => auth.resolvePrincipal(`Bearer ${riskyLogin.accessToken}`, 'unused-device'),
    (error) => error instanceof AuthError && error.status === 401,
    'suspending an account should revoke its active sessions immediately'
  );
  await assert.rejects(
    () => auth.loginWithHuawei({
      authorizationCode: 'risky-code',
      deviceId: 'risky-relogin-device'
    }),
    (error) => error instanceof AuthError && error.status === 403,
    'a suspended Huawei identity must not create a new session'
  );

  clock = new Date('2026-07-24T10:05:00.000Z');
  const restored = service.updateUserStatus({
    userId: riskyLogin.user.id,
    status: 'active',
    reason: '人工复核完成，确认是内部压测账号，恢复正常使用',
    operator: '复核管理员',
    note: '账号已完成归属确认。'
  });
  assert.equal(restored.status, 'active');
  assert.equal(restored.lastModeration.action, 'restore');
  assert.equal(restored.lastModeration.operator, '复核管理员');
  assert.equal(restored.moderationCount, 2, 'suspend and restore actions should both remain auditable');
  assert.throws(
    () => auth.resolvePrincipal(`Bearer ${riskyLogin.accessToken}`, 'unused-device'),
    (error) => error instanceof AuthError && error.status === 401,
    'restoring an account must not revive previously revoked sessions'
  );
  const relogin = await auth.loginWithHuawei({
    authorizationCode: 'risky-code',
    deviceId: 'risky-restored-device'
  });
  assert(relogin.accessToken.startsWith('ark_access_'), 'restored accounts should be able to sign in again');

  assert.throws(
    () => service.updateUserStatus({
      userId: riskyLogin.user.id,
      status: 'suspended',
      reason: '短',
      operator: '刘国强'
    }),
    (error) => error instanceof LeaderboardAdminError && error.status === 400,
    'moderation actions should require a meaningful reason'
  );
  assert.throws(
    () => service.listUsers({ risk: 'unknown' }),
    (error) => error instanceof LeaderboardAdminError && error.status === 400,
    'unsupported audit filters should be rejected'
  );
  assert.throws(
    () => service.listUsers({ page: 0 }),
    (error) => error instanceof LeaderboardAdminError && error.status === 400,
    'audit pagination should reject non-positive pages'
  );
  assert.throws(
    () => service.listUsers({ pageSize: 101 }),
    (error) => error instanceof LeaderboardAdminError && error.status === 400,
    'audit pagination should enforce the maximum page size'
  );
  assert.throws(
    () => service.updateUserStatus({
      userId: riskyLogin.user.id,
      status: 'suspended',
      reason: '再次发现异常提交，需要暂停账号'
    }),
    (error) => error instanceof LeaderboardAdminError && error.status === 400,
    'moderation actions should require an operator identity'
  );
  assert.equal(opened.store.integrityCheck(), 'ok');

  console.log('Leaderboard admin service tests passed.');
} finally {
  if (activeStore) {
    activeStore.close();
  }
  await rm(tempDir, { recursive: true, force: true });
}

async function createAccount(auth, opened, { code, deviceId, answers }) {
  const login = await auth.loginWithHuawei({
    authorizationCode: code,
    deviceId
  });
  const principal = auth.resolvePrincipal(`Bearer ${login.accessToken}`, deviceId);
  auth.updateLeaderboardPreference(principal, true);
  principal.user.answers.push(...answers);
  principal.user.updatedAt = answers.at(-1)?.submittedAt || principal.user.updatedAt;
  opened.snapshot.meta.updatedAt = principal.user.updatedAt;
  opened.store.saveUser(principal.user, opened.snapshot.meta);
  return login;
}

function burstAnswers(prefix, count, start, intervalSeconds) {
  const startMs = Date.parse(start);
  return Array.from({ length: count }, (_, index) => ({
    id: `${prefix}-attempt-${index}`,
    questionId: index % 2 === 0 ? 'q1' : 'q2',
    categoryId: index % 2 === 0 ? 'arkts' : 'arkui',
    type: index % 2 === 0 ? 'single' : 'boolean',
    isCorrect: true,
    leaderboardEligible: true,
    submittedAt: new Date(startMs + index * intervalSeconds * 1000).toISOString()
  }));
}

function fakeHuaweiClient() {
  return {
    isConfigured() {
      return true;
    },
    async exchangeAuthorizationCode(code) {
      if (code === 'risky-code') {
        return {
          providerSubject: 'risky-subject',
          unionId: '',
          displayName: '高频测试账号',
          avatarUrl: ''
        };
      }
      if (code === 'normal-code') {
        return {
          providerSubject: 'normal-subject',
          unionId: '',
          displayName: '正常测试账号',
          avatarUrl: ''
        };
      }
      throw new AuthError(401, '授权码无效');
    }
  };
}

function createSnapshot() {
  const createdAt = '2026-07-01T00:00:00.000Z';
  return {
    meta: {
      name: 'ArkInterview',
      displayName: 'Ark 面试通',
      packageName: 'com.lgq.arkinterview',
      createdAt,
      updatedAt: createdAt
    },
    categories: [
      { id: 'arkts', name: 'ArkTS', order: 1 },
      { id: 'arkui', name: 'ArkUI', order: 2 }
    ],
    questions: [
      question('q1', 'arkts', 'single', createdAt),
      question('q2', 'arkui', 'boolean', createdAt)
    ],
    users: {}
  };
}

function question(id, categoryId, type, timestamp) {
  return {
    id,
    categoryId,
    type,
    difficulty: 'easy',
    title: id,
    options: [],
    explanation: '',
    knowledgePoints: [],
    status: 'published',
    reviewStatus: 'verified',
    verifiedAt: '2026-07-24',
    sourceRefs: ['official-test-source'],
    order: 1,
    createdAt: timestamp,
    updatedAt: timestamp
  };
}
