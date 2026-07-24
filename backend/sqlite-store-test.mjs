import assert from 'node:assert/strict';
import Database from 'better-sqlite3';
import { existsSync } from 'node:fs';
import { mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { openSqliteStore, readSqliteSnapshot } from './sqlite-store.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const tempRoot = path.join(rootDir, '.tmp');
const tempDir = path.join(tempRoot, `sqlite-store-${process.pid}-${Date.now()}`);
const dbFile = path.join(tempDir, 'arkinterview.sqlite');
const legacyDbFile = path.join(tempDir, 'db.json');
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
  assert(firstQuestion && secondQuestion, 'seed data should contain at least two published questions');

  const legacySnapshot = createLegacySnapshot(categories, questions, firstQuestion);
  const legacyText = `${JSON.stringify(legacySnapshot, null, 2)}\n`;
  await writeFile(legacyDbFile, legacyText, 'utf8');

  const opened = await openSqliteStore({
    dbFile,
    legacyDbFile,
    createInitialData: () => {
      throw new Error('legacy JSON should be imported before seed data is requested');
    }
  });
  activeStore = opened.store;

  assert.equal(opened.importedLegacy, true, 'first open should import legacy JSON');
  assert.equal(opened.snapshot.categories.length, categories.length, 'all categories should migrate');
  assert.equal(opened.snapshot.questions.length, questions.length, 'all questions should migrate');
  assert.equal(opened.store.integrityCheck(), 'ok', 'migrated SQLite database should pass integrity check');

  const migratedUser = opened.snapshot.users['legacy-device'];
  assert(migratedUser, 'legacy anonymous user should migrate');
  assert.deepEqual(migratedUser.favorites, [firstQuestion.id], 'legacy favorites should migrate');
  assert.equal(migratedUser.wrongs[firstQuestion.id].wrongCount, 2, 'legacy wrong count should migrate');
  assert.equal(migratedUser.answers.length, 1, 'legacy answer history should migrate');

  migratedUser.deviceIds.push('legacy-tablet');
  migratedUser.favorites.push(secondQuestion.id);
  migratedUser.updatedAt = '2026-07-24T08:00:00.000Z';
  opened.snapshot.meta.updatedAt = migratedUser.updatedAt;
  opened.store.saveUser(migratedUser, opened.snapshot.meta);
  opened.store.close();
  activeStore = undefined;
  downgradeAuthSchemaForMigrationTest(dbFile);
  const schemaV1Snapshot = readSqliteSnapshot(dbFile);
  assert.equal(
    schemaV1Snapshot.users['legacy-device'].answers.length,
    1,
    'read-only catalog sync should remain compatible with schema v1 before migration'
  );

  const reopened = await openSqliteStore({
    dbFile,
    legacyDbFile,
    createInitialData: () => {
      throw new Error('existing SQLite data should be reused');
    }
  });
  activeStore = reopened.store;

  assert.equal(reopened.importedLegacy, false, 'later opens should reuse SQLite without reimporting JSON');
  assert.deepEqual(
    reopened.snapshot.users['legacy-device'].favorites,
    [firstQuestion.id, secondQuestion.id],
    'user changes should survive a database restart'
  );
  assert.equal(
    reopened.snapshot.users['legacy-tablet'].id,
    reopened.snapshot.users['legacy-device'].id,
    'multiple devices should resolve to the same internal user'
  );
  assert.equal(
    reopened.snapshot.users['legacy-device'].answers[0].questionId,
    firstQuestion.id,
    'answer history should survive a database restart'
  );
  assert.equal(reopened.store.integrityCheck(), 'ok', 'reopened SQLite database should pass integrity check');
  assert.equal(
    reopened.store.database.pragma('user_version', { simple: true }),
    2,
    'opening a schema v1 database should migrate it to schema v2'
  );
  const authSessionColumns = reopened.store.database
    .pragma('table_info(auth_sessions)')
    .map((column) => column.name);
  assert(authSessionColumns.includes('access_token_hash'), 'schema v2 should add access token hashes');
  assert(authSessionColumns.includes('access_expires_at'), 'schema v2 should add access token expiry');
  assert.equal(await readFile(legacyDbFile, 'utf8'), legacyText, 'migration must not modify legacy JSON');
  assert.equal(existsSync(dbFile), true, 'migration should create the SQLite database file');

  console.log('SQLite store tests passed.');
} finally {
  if (activeStore) {
    activeStore.close();
  }
  await rm(tempDir, { recursive: true, force: true });
}

function createLegacySnapshot(categories, questions, question) {
  return {
    meta: {
      name: 'ArkInterview',
      displayName: 'Ark 面试通',
      packageName: 'com.lgq.arkinterview',
      createdAt: '2026-07-01T00:00:00.000Z',
      updatedAt: '2026-07-24T07:00:00.000Z'
    },
    categories,
    questions,
    users: {
      'legacy-device': {
        deviceId: 'legacy-device',
        favorites: [question.id],
        wrongs: {
          [question.id]: {
            questionId: question.id,
            wrongCount: 2,
            mastered: false,
            updatedAt: '2026-07-24T07:00:00.000Z'
          }
        },
        answers: [
          {
            questionId: question.id,
            categoryId: question.categoryId,
            type: question.type,
            isCorrect: false,
            submittedAt: '2026-07-24T07:00:00.000Z'
          }
        ]
      }
    }
  };
}

function downgradeAuthSchemaForMigrationTest(file) {
  const database = new Database(file);
  try {
    database.pragma('foreign_keys = OFF');
    database.exec(`
      DROP INDEX IF EXISTS idx_auth_sessions_user;
      DROP INDEX IF EXISTS idx_auth_sessions_access_token;
      ALTER TABLE auth_sessions RENAME TO auth_sessions_v2;
      CREATE TABLE auth_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        refresh_token_hash TEXT NOT NULL UNIQUE,
        expires_at TEXT NOT NULL,
        revoked_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      );
      CREATE INDEX idx_auth_sessions_user
        ON auth_sessions(user_id, revoked_at, expires_at);
      DROP TABLE auth_sessions_v2;
      PRAGMA user_version = 1;
    `);
  } finally {
    database.close();
  }
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}
