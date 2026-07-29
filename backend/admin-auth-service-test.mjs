import assert from 'node:assert/strict';
import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { AdminAuthError, AdminAuthService } from './admin-auth-service.mjs';
import { openSqliteStore } from './sqlite-store.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const tempDir = path.join(rootDir, '.tmp', `admin-auth-${process.pid}-${Date.now()}`);
const dbFile = path.join(tempDir, 'admin-auth.sqlite');
const legacyToken = 'arkinterview-admin-auth-test-token-2026-07-29';

await mkdir(tempDir, { recursive: true });

let activeStore;
try {
  const opened = await openSqliteStore({
    dbFile,
    legacyDbFile: path.join(tempDir, 'missing.json'),
    createInitialData: createSnapshot
  });
  activeStore = opened.store;
  let clock = new Date('2026-07-29T08:00:00.000Z');
  const service = new AdminAuthService({
    store: opened.store,
    legacyToken,
    sessionTtlSeconds: 3600,
    loginWindowSeconds: 300,
    loginLockSeconds: 60,
    maximumLoginFailures: 3,
    now: () => clock
  });

  assert.deepEqual(service.status(), {
    enabled: true,
    bootstrapAvailable: true
  });
  assert.throws(
    () => service.bootstrap({
      authorization: 'Bearer invalid-token',
      username: 'owner',
      password: 'Owner-password-2026',
      displayName: '平台主管理员'
    }),
    (error) => error instanceof AdminAuthError && error.status === 401
  );

  const bootstrapped = service.bootstrap({
    authorization: `Bearer ${legacyToken}`,
    username: 'owner',
    password: 'Owner-password-2026',
    displayName: '平台主管理员',
    ipAddress: '10.0.0.1'
  });
  assert(bootstrapped.accessToken.startsWith('ark_admin_'));
  assert.equal(bootstrapped.admin.role, 'super_admin');
  assert(bootstrapped.admin.permissions.includes('admin:manage'));
  assert.equal(service.status().bootstrapAvailable, false);
  assert.throws(
    () => service.bootstrap({
      authorization: `Bearer ${legacyToken}`,
      username: 'another-owner',
      password: 'Another-password-2026',
      displayName: '另一位管理员'
    }),
    (error) => error instanceof AdminAuthError && error.status === 409
  );

  const ownerPrincipal = service.resolvePrincipal(`Bearer ${bootstrapped.accessToken}`);
  assert.equal(ownerPrincipal.admin.displayName, '平台主管理员');
  service.requirePermission(ownerPrincipal, 'admin:manage');

  const moderator = service.createUser({
    username: 'moderator.01',
    password: 'Moderator-password-2026',
    displayName: '排行榜审核员',
    role: 'moderator'
  });
  const editor = service.createUser({
    username: 'editor.01',
    password: 'Editor-password-2026',
    displayName: '题库编辑员',
    role: 'content_editor'
  });
  assert.equal(service.listUsers().length, 3);
  assert.equal(moderator.permissions.includes('leaderboard:moderate'), true);
  assert.equal(editor.permissions.includes('questions:write'), true);

  clock = new Date('2026-07-29T08:05:00.000Z');
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    assert.throws(
      () => service.login({
        username: 'editor.01',
        password: 'Wrong-password-2026',
        ipAddress: '10.0.0.2'
      }),
      (error) => error instanceof AdminAuthError && error.status === 401
    );
  }
  assert.throws(
    () => service.login({
      username: 'editor.01',
      password: 'Wrong-password-2026',
      ipAddress: '10.0.0.2'
    }),
    (error) => error instanceof AdminAuthError && error.status === 429 && error.retryAfter === 60
  );
  assert.throws(
    () => service.login({
      username: 'editor.01',
      password: 'Editor-password-2026',
      ipAddress: '10.0.0.2'
    }),
    (error) => error instanceof AdminAuthError && error.status === 429,
    'a correct password must not bypass an active source lock'
  );
  clock = new Date('2026-07-29T08:06:01.000Z');
  const editorLogin = service.login({
    username: 'editor.01',
    password: 'Editor-password-2026',
    ipAddress: '10.0.0.2'
  });
  assert.equal(editorLogin.admin.role, 'content_editor');

  clock = new Date('2026-07-29T08:10:00.000Z');
  const moderatorLogin = service.login({
    username: 'MODERATOR.01',
    password: 'Moderator-password-2026',
    ipAddress: '10.0.0.3'
  });
  const moderatorPrincipal = service.resolvePrincipal(`Bearer ${moderatorLogin.accessToken}`);
  service.requirePermission(moderatorPrincipal, 'leaderboard:moderate');
  assert.throws(
    () => service.requirePermission(moderatorPrincipal, 'questions:write'),
    (error) => error instanceof AdminAuthError && error.status === 403
  );

  service.updateUser(
    moderator.id,
    { role: 'content_editor', password: 'Changed-password-2026' },
    ownerPrincipal.admin.id
  );
  assert.throws(
    () => service.resolvePrincipal(`Bearer ${moderatorLogin.accessToken}`),
    (error) => error instanceof AdminAuthError && error.status === 401,
    'role and password changes should revoke existing sessions'
  );
  assert.throws(
    () => service.login({
      username: 'moderator.01',
      password: 'Moderator-password-2026'
    }),
    (error) => error instanceof AdminAuthError && error.status === 401
  );
  const changedLogin = service.login({
    username: 'moderator.01',
    password: 'Changed-password-2026'
  });
  assert.equal(changedLogin.admin.role, 'content_editor');

  assert.throws(
    () => service.updateUser(
      ownerPrincipal.admin.id,
      { status: 'disabled' },
      ownerPrincipal.admin.id
    ),
    (error) => error instanceof AdminAuthError && error.status === 409,
    'the current and last active super administrator must remain enabled'
  );

  const sessions = service.listSessions({}, ownerPrincipal.session.id);
  assert(sessions.some((session) => session.current), 'session lists should identify the current session');
  const editorSession = sessions.find((session) => session.id === editorLogin.sessionId);
  assert.equal(editorSession.ipAddress, '10.0.0.2');
  service.revokeSession(editorSession.id, ownerPrincipal);
  assert.throws(
    () => service.resolvePrincipal(`Bearer ${editorLogin.accessToken}`),
    (error) => error instanceof AdminAuthError && error.status === 401
  );
  assert.throws(
    () => service.revokeSession(ownerPrincipal.session.id, ownerPrincipal),
    (error) => error instanceof AdminAuthError && error.status === 409,
    'session management must not revoke the current session'
  );

  const secondEditorLogin = service.login({
    username: 'editor.01',
    password: 'Editor-password-2026',
    ipAddress: '10.0.0.4'
  });
  const bulkRevocation = service.revokeUserSessions(editor.id, ownerPrincipal);
  assert.equal(bulkRevocation.revokedCount, 1);
  assert.throws(
    () => service.resolvePrincipal(`Bearer ${secondEditorLogin.accessToken}`),
    (error) => error instanceof AdminAuthError && error.status === 401
  );

  const lockedEvents = service.listAuditEvents({
    action: 'auth.login_locked',
    from: '2026-07-29',
    to: '2026-07-29'
  });
  assert.equal(lockedEvents.items.length, 1);
  assert.equal(lockedEvents.items[0].ipAddress, '10.0.0.2');
  assert(lockedEvents.pagination.totalItems >= 1);

  service.logout(service.resolvePrincipal(`Bearer ${changedLogin.accessToken}`));
  assert.throws(
    () => service.resolvePrincipal(`Bearer ${changedLogin.accessToken}`),
    (error) => error instanceof AdminAuthError && error.status === 401
  );

  const servicePrincipal = service.resolvePrincipal(`Bearer ${legacyToken}`);
  assert.equal(servicePrincipal.serviceToken, true);
  assert.equal(servicePrincipal.admin.displayName, '部署服务令牌');
  assert.equal(opened.store.integrityCheck(), 'ok');

  console.log('Admin auth service tests passed.');
} finally {
  if (activeStore) {
    activeStore.close();
  }
  await rm(tempDir, { recursive: true, force: true });
}

function createSnapshot() {
  return {
    meta: {
      name: 'ArkInterview',
      displayName: 'Ark 面试通',
      packageName: 'com.lgq.arkinterview',
      createdAt: '2026-07-29T00:00:00.000Z',
      updatedAt: '2026-07-29T00:00:00.000Z'
    },
    categories: [],
    questions: [],
    users: {}
  };
}
