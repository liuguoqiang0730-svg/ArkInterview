import assert from 'node:assert/strict';
import { mkdir, readFile, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AuthError, AuthService } from './auth-service.mjs';
import { HuaweiAccountClient } from './huawei-account-client.mjs';
import { openSqliteStore } from './sqlite-store.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const tempRoot = path.join(rootDir, '.tmp');
const tempDir = path.join(tempRoot, `auth-service-${process.pid}-${Date.now()}`);
const dbFile = path.join(tempDir, 'auth.sqlite');
const categoriesFile = path.join(rootDir, 'data', 'seed', 'categories.json');
const questionsFile = path.join(rootDir, 'data', 'seed', 'questions.json');

await mkdir(tempDir, { recursive: true });

let activeStore;
try {
  const [categories, questions] = await Promise.all([
    readJson(categoriesFile),
    readJson(questionsFile)
  ]);
  const firstQuestion = questions.find((question) => question.status === 'published');
  const secondQuestion = questions.find(
    (question) => question.status === 'published' && question.id !== firstQuestion.id
  );
  assert(firstQuestion && secondQuestion, 'auth tests require two published questions');

  const opened = await openSqliteStore({
    dbFile,
    legacyDbFile: path.join(tempDir, 'missing-legacy.json'),
    createInitialData: () => createSnapshot(categories, questions)
  });
  activeStore = opened.store;

  let clock = new Date('2026-07-24T09:00:00.000Z');
  const huaweiClient = {
    isConfigured() {
      return true;
    },
    async exchangeAuthorizationCode(code) {
      if (code !== 'valid-code') {
        const error = new Error('invalid code');
        error.status = 401;
        throw error;
      }
      return {
        providerSubject: 'huawei-open-id',
        unionId: 'huawei-union-id',
        displayName: 'Ark Developer',
        avatarUrl: 'https://example.com/avatar.png'
      };
    }
  };
  const auth = new AuthService({
    store: opened.store,
    db: opened.snapshot,
    huaweiClient,
    accessTtlSeconds: 15 * 60,
    refreshTtlSeconds: 30 * 24 * 60 * 60,
    now: () => clock
  });

  const phoneGuest = auth.ensureAnonymousUser('device-phone');
  addLearningState(phoneGuest, firstQuestion, 'phone-attempt');
  opened.store.saveUser(phoneGuest, opened.snapshot.meta);

  const firstLogin = await auth.loginWithHuawei({
    authorizationCode: 'valid-code',
    deviceId: 'device-phone'
  });
  assert(firstLogin.accessToken.startsWith('ark_access_'), 'login should issue an access token');
  assert(firstLogin.refreshToken.startsWith('ark_refresh_'), 'login should issue a refresh token');
  assert.equal(firstLogin.user.displayName, 'Ark Developer', 'Huawei profile should update display name');
  const anonymousAfterLogin = auth.resolvePrincipal('', 'device-phone');
  assert.equal(anonymousAfterLogin.authenticated, false, 'missing access token should use anonymous mode');
  assert.notEqual(
    anonymousAfterLogin.user.id,
    firstLogin.user.id,
    'a device ID must not expose the linked account without an access token'
  );
  assert.equal(anonymousAfterLogin.user.answers.length, 0, 'new anonymous state should not inherit account answers');

  const signedIn = auth.resolvePrincipal(
    `Bearer ${firstLogin.accessToken}`,
    'unused-device'
  );
  assert.equal(signedIn.authenticated, true, 'issued access token should authenticate');
  assert.equal(signedIn.user.id, firstLogin.user.id, 'access token should resolve the login user');
  assert.throws(
    () => auth.updateLeaderboardPreference(anonymousAfterLogin, true),
    (error) => error instanceof AuthError && error.status === 401,
    'anonymous users must not opt into the leaderboard'
  );
  assert.throws(
    () => auth.updateLeaderboardPreference(signedIn, 'true'),
    (error) => error instanceof AuthError && error.status === 400,
    'leaderboard preference must use a boolean value'
  );
  const leaderboardProfile = auth.updateLeaderboardPreference(signedIn, true);
  assert.equal(
    leaderboardProfile.user.leaderboardOptIn,
    true,
    'authenticated users should be able to explicitly opt into the leaderboard'
  );
  assert.equal(
    opened.store.database.prepare(
      'SELECT leaderboard_opt_in FROM users WHERE id = ?'
    ).get(firstLogin.user.id).leaderboard_opt_in,
    1,
    'leaderboard preference should persist immediately'
  );
  assert.throws(
    () => auth.resolvePrincipal('Basic invalid', 'device-phone'),
    (error) => error instanceof AuthError && error.status === 401,
    'unsupported authorization headers should be rejected'
  );
  assert.throws(
    () => auth.ensureAnonymousUser('../invalid-device'),
    (error) => error instanceof AuthError && error.status === 400,
    'invalid anonymous device IDs should be rejected'
  );
  assert.throws(
    () => auth.ensureAnonymousUser(`account/${firstLogin.user.id}`),
    (error) => error instanceof AuthError && error.status === 400,
    'internal account anchors must never be accepted as client device IDs'
  );

  clock = new Date('2026-07-24T09:16:00.000Z');
  assert.throws(
    () => auth.resolvePrincipal(`Bearer ${firstLogin.accessToken}`, 'unused-device'),
    (error) => error instanceof AuthError && error.status === 401,
    'expired access tokens should be rejected'
  );
  const refreshed = auth.refresh(firstLogin.refreshToken);
  assert.notEqual(refreshed.refreshToken, firstLogin.refreshToken, 'refresh token should rotate');
  assert.throws(
    () => auth.refresh(firstLogin.refreshToken),
    (error) => error instanceof AuthError && error.status === 401,
    'rotated refresh token should be rejected'
  );
  assert.throws(
    () => auth.resolvePrincipal(`Bearer ${firstLogin.accessToken}`, 'unused-device'),
    (error) => error instanceof AuthError && error.status === 401,
    'refreshing should invalidate the previous access token'
  );

  const refreshedPrincipal = auth.resolvePrincipal(
    `Bearer ${refreshed.accessToken}`,
    'unused-device'
  );
  auth.logout(refreshedPrincipal);
  assert.throws(
    () => auth.resolvePrincipal(`Bearer ${refreshed.accessToken}`, 'unused-device'),
    (error) => error instanceof AuthError && error.status === 401,
    'logout should revoke the active session'
  );

  clock = new Date('2026-07-24T10:00:00.000Z');
  const tabletGuest = auth.ensureAnonymousUser('device-tablet');
  addLearningState(tabletGuest, secondQuestion, 'tablet-attempt');
  opened.store.saveUser(tabletGuest, opened.snapshot.meta);
  const tabletGuestId = tabletGuest.id;

  const mergedLogin = await auth.loginWithHuawei({
    authorizationCode: 'valid-code',
    deviceId: 'device-tablet'
  });
  assert.equal(mergedLogin.user.id, firstLogin.user.id, 'same Huawei identity should reuse one user');
  assert.notEqual(mergedLogin.user.id, tabletGuestId, 'secondary anonymous user should be merged');
  const mergedPrincipal = auth.resolvePrincipal(`Bearer ${mergedLogin.accessToken}`, 'device-tablet');
  assert.deepEqual(
    new Set(mergedPrincipal.user.favorites),
    new Set([firstQuestion.id, secondQuestion.id]),
    'anonymous favorites should merge across devices'
  );
  assert.equal(
    mergedPrincipal.user.answers.length,
    2,
    'anonymous answer history should merge across devices'
  );
  const tabletAfterLogin = auth.resolvePrincipal('', 'device-tablet');
  assert.notEqual(
    tabletAfterLogin.user.id,
    mergedLogin.user.id,
    'secondary device should also return to an isolated anonymous state without a token'
  );

  const persisted = opened.store.loadSnapshot();
  const persistedAccount = Object.values(persisted.users)
    .find((user) => user.id === mergedLogin.user.id);
  assert(persistedAccount, 'linked account should remain loadable after a database restart');
  assert.equal(
    persistedAccount.deviceId,
    `account/${mergedLogin.user.id}`,
    'linked account should only use an internal account anchor'
  );
  assert.equal(persistedAccount.answers.length, 2, 'merged answers should persist');
  assert.equal(persistedAccount.leaderboardOptIn, true, 'leaderboard preference should survive account merges');
  const storedSession = opened.store.database.prepare(
    'SELECT access_token_hash, refresh_token_hash FROM auth_sessions WHERE user_id = ? ORDER BY created_at DESC LIMIT 1'
  ).get(mergedLogin.user.id);
  assert.match(storedSession.access_token_hash, /^[a-f0-9]{64}$/, 'access tokens should only be stored as hashes');
  assert.match(storedSession.refresh_token_hash, /^[a-f0-9]{64}$/, 'refresh tokens should only be stored as hashes');
  assert.notEqual(storedSession.access_token_hash, mergedLogin.accessToken, 'raw access token must not be stored');
  assert.notEqual(storedSession.refresh_token_hash, mergedLogin.refreshToken, 'raw refresh token must not be stored');
  assert.equal(opened.store.integrityCheck(), 'ok', 'auth data should keep SQLite integrity');

  await testHuaweiClientRequestShape();
  console.log('Auth service tests passed.');
} finally {
  if (activeStore) {
    activeStore.close();
  }
  await rm(tempDir, { recursive: true, force: true });
}

async function testHuaweiClientRequestShape() {
  const requests = [];
  const client = new HuaweiAccountClient({
    clientId: 'client-id',
    clientSecret: 'server-secret',
    redirectUri: 'https://example.com/account/callback',
    fetchImpl: async (url, options) => {
      requests.push({
        url,
        body: Object.fromEntries(options.body.entries())
      });
      if (requests.length === 1) {
        return new Response(JSON.stringify({
          access_token: 'huawei-access-token',
          expires_in: 3600,
          token_type: 'Bearer'
        }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        });
      }
      return new Response(JSON.stringify({
        openID: 'verified-open-id',
        unionID: 'verified-union-id',
        displayName: 'Verified User',
        headPictureURL: 'https://example.com/verified.png'
      }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
    }
  });

  const profile = await client.exchangeAuthorizationCode('authorization-code');
  assert.equal(requests.length, 2, 'Huawei login should call token and user info endpoints');
  assert.deepEqual(requests[0].body, {
    grant_type: 'authorization_code',
    code: 'authorization-code',
    client_id: 'client-id',
    client_secret: 'server-secret',
    redirect_uri: 'https://example.com/account/callback'
  }, 'token request should follow the official authorization code form');
  assert.deepEqual(requests[1].body, {
    access_token: 'huawei-access-token',
    getNickName: '0'
  }, 'user info request should use the server-obtained access token');
  assert.equal(profile.providerSubject, 'verified-open-id', 'verified OpenID should identify the user');
}

function createSnapshot(categories, questions) {
  const now = '2026-07-24T08:00:00.000Z';
  return {
    meta: {
      name: 'ArkInterview',
      displayName: 'Ark 面试通',
      packageName: 'com.lgq.arkinterview',
      createdAt: now,
      updatedAt: now
    },
    categories,
    questions,
    users: {}
  };
}

function addLearningState(user, question, attemptId) {
  const submittedAt = '2026-07-24T08:30:00.000Z';
  user.favorites.push(question.id);
  user.wrongs[question.id] = {
    questionId: question.id,
    wrongCount: 1,
    mastered: false,
    updatedAt: submittedAt
  };
  user.answers.push({
    id: attemptId,
    questionId: question.id,
    categoryId: question.categoryId,
    type: question.type,
    isCorrect: false,
    submittedAt
  });
  user.updatedAt = submittedAt;
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}
