import Database from 'better-sqlite3';
import { existsSync } from 'node:fs';
import { mkdir, readFile } from 'node:fs/promises';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

const schemaVersion = 3;

export function resolveDatabasePaths(defaultStorageDir) {
  const configuredDbFile = process.env.DB_FILE
    ? path.resolve(process.env.DB_FILE)
    : path.join(defaultStorageDir, 'arkinterview.sqlite');
  const configuredLegacyFile = process.env.LEGACY_DB_FILE
    ? path.resolve(process.env.LEGACY_DB_FILE)
    : path.join(defaultStorageDir, 'db.json');

  if (path.extname(configuredDbFile).toLowerCase() === '.json') {
    return {
      dbFile: configuredDbFile.replace(/\.json$/i, '.sqlite'),
      legacyDbFile: configuredDbFile
    };
  }

  return {
    dbFile: configuredDbFile,
    legacyDbFile: configuredLegacyFile
  };
}

export async function openSqliteStore({ dbFile, legacyDbFile, createInitialData }) {
  await mkdir(path.dirname(dbFile), { recursive: true });
  const database = new Database(dbFile);
  try {
    const store = new SqliteStore(database, dbFile);
    store.initializeSchema();

    let importedLegacy = false;
    if (!store.hasData()) {
      let initialData;
      if (legacyDbFile && existsSync(legacyDbFile)) {
        initialData = JSON.parse(await readFile(legacyDbFile, 'utf8'));
        importedLegacy = true;
      } else {
        initialData = await createInitialData();
      }
      const snapshot = normalizeSnapshot(initialData);
      if (importedLegacy) {
        snapshot.meta.legacyImportedAt = new Date().toISOString();
        snapshot.meta.legacySource = legacyDbFile;
      }
      store.replaceAll(snapshot);
    }

    return {
      store,
      snapshot: store.loadSnapshot(),
      importedLegacy
    };
  } catch (error) {
    database.close();
    throw error;
  }
}

export function readSqliteSnapshot(dbFile) {
  const database = new Database(dbFile, { readonly: true, fileMustExist: true });
  try {
    const store = new SqliteStore(database, dbFile);
    store.assertReadableSchema();
    return store.loadSnapshot();
  } finally {
    database.close();
  }
}

export class SqliteStore {
  constructor(database, dbFile) {
    this.database = database;
    this.dbFile = dbFile;
  }

  initializeSchema() {
    this.database.pragma('foreign_keys = ON');
    this.database.pragma('busy_timeout = 5000');
    this.database.pragma('journal_mode = WAL');
    this.database.pragma('synchronous = NORMAL');

    const currentVersion = this.database.pragma('user_version', { simple: true });
    if (currentVersion > schemaVersion) {
      throw new Error(`SQLite schema ${currentVersion} is newer than supported schema ${schemaVersion}`);
    }
    if (currentVersion === 0) {
      this.database.exec(`
        CREATE TABLE IF NOT EXISTS app_metadata (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          payload_json TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          sort_order INTEGER NOT NULL,
          payload_json TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS questions (
          id TEXT PRIMARY KEY,
          category_id TEXT NOT NULL,
          type TEXT NOT NULL,
          difficulty TEXT NOT NULL,
          status TEXT NOT NULL,
          review_status TEXT NOT NULL,
          sort_order INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          payload_json TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES categories(id)
        );

        CREATE INDEX IF NOT EXISTS idx_questions_catalog
          ON questions(status, category_id, type, sort_order);
        CREATE INDEX IF NOT EXISTS idx_questions_review
          ON questions(review_status, status);

        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          display_name TEXT,
          avatar_url TEXT,
          leaderboard_opt_in INTEGER NOT NULL DEFAULT 0,
          leaderboard_opted_in_at TEXT,
          status TEXT NOT NULL DEFAULT 'active',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS anonymous_devices (
          device_id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_anonymous_devices_user
          ON anonymous_devices(user_id);

        CREATE TABLE IF NOT EXISTS user_identities (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          provider TEXT NOT NULL,
          provider_subject TEXT NOT NULL,
          union_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE (provider, provider_subject)
        );

        CREATE INDEX IF NOT EXISTS idx_user_identities_user
          ON user_identities(user_id);

        CREATE TABLE IF NOT EXISTS auth_sessions (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          access_token_hash TEXT UNIQUE,
          access_expires_at TEXT,
          refresh_token_hash TEXT NOT NULL UNIQUE,
          expires_at TEXT NOT NULL,
          revoked_at TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_auth_sessions_user
          ON auth_sessions(user_id, revoked_at, expires_at);
        CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_access_token
          ON auth_sessions(access_token_hash);

        CREATE TABLE IF NOT EXISTS favorites (
          user_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          created_at TEXT NOT NULL,
          PRIMARY KEY (user_id, question_id),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS wrong_questions (
          user_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          wrong_count INTEGER NOT NULL,
          mastered INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (user_id, question_id),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_wrong_questions_user
          ON wrong_questions(user_id, mastered, updated_at);

        CREATE TABLE IF NOT EXISTS answer_attempts (
          sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
          attempt_id TEXT NOT NULL UNIQUE,
          user_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          category_id TEXT NOT NULL,
          question_type TEXT NOT NULL,
          is_correct INTEGER,
          leaderboard_eligible INTEGER NOT NULL DEFAULT 0,
          submitted_at TEXT NOT NULL,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
        );

        CREATE INDEX IF NOT EXISTS idx_answer_attempts_user_time
          ON answer_attempts(user_id, submitted_at, sequence_id);
        CREATE INDEX IF NOT EXISTS idx_answer_attempts_leaderboard
          ON answer_attempts(question_id, is_correct, submitted_at);
      `);
      this.database.pragma(`user_version = ${schemaVersion}`);
    }
    if (currentVersion === 1) {
      this.database.exec(`
        ALTER TABLE auth_sessions ADD COLUMN access_token_hash TEXT;
        ALTER TABLE auth_sessions ADD COLUMN access_expires_at TEXT;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_access_token
          ON auth_sessions(access_token_hash);
      `);
      this.database.pragma('user_version = 2');
    }
    if (currentVersion === 1 || currentVersion === 2) {
      const userColumns = this.database
        .pragma('table_info(users)')
        .map((column) => column.name);
      if (!userColumns.includes('leaderboard_opted_in_at')) {
        this.database.exec('ALTER TABLE users ADD COLUMN leaderboard_opted_in_at TEXT');
      }
      const answerColumns = this.database
        .pragma('table_info(answer_attempts)')
        .map((column) => column.name);
      if (!answerColumns.includes('leaderboard_eligible')) {
        this.database.exec(
          'ALTER TABLE answer_attempts ADD COLUMN leaderboard_eligible INTEGER NOT NULL DEFAULT 0'
        );
      }
      this.database.prepare(
        `UPDATE users
         SET leaderboard_opted_in_at = ?
         WHERE leaderboard_opt_in = 1
           AND leaderboard_opted_in_at IS NULL`
      ).run(new Date().toISOString());
      this.database.pragma(`user_version = ${schemaVersion}`);
    }
    this.assertSupportedSchema();
  }

  assertSupportedSchema() {
    const currentVersion = this.database.pragma('user_version', { simple: true });
    if (currentVersion !== schemaVersion) {
      throw new Error(`Unsupported SQLite schema version: ${currentVersion}`);
    }
  }

  assertReadableSchema() {
    const currentVersion = this.database.pragma('user_version', { simple: true });
    if (currentVersion < 1 || currentVersion > schemaVersion) {
      throw new Error(`Unsupported SQLite schema version: ${currentVersion}`);
    }
  }

  hasData() {
    const row = this.database.prepare('SELECT 1 AS present FROM app_metadata WHERE id = 1').get();
    return Boolean(row);
  }

  loadSnapshot() {
    const metadataRow = this.database.prepare('SELECT payload_json FROM app_metadata WHERE id = 1').get();
    if (!metadataRow) {
      throw new Error(`SQLite database is not initialized: ${this.dbFile}`);
    }

    const categories = this.database.prepare(
      'SELECT payload_json FROM categories ORDER BY sort_order, id'
    ).all().map((row) => JSON.parse(row.payload_json));
    const questions = this.database.prepare(
      'SELECT payload_json FROM questions ORDER BY category_id, sort_order, id'
    ).all().map((row) => JSON.parse(row.payload_json));
    const users = {};
    const userById = new Map();
    const currentVersion = this.database.pragma('user_version', { simple: true });
    const leaderboardOptInTimeColumn = currentVersion >= 3
      ? 'leaderboard_opted_in_at'
      : 'NULL AS leaderboard_opted_in_at';

    for (const row of this.database.prepare(
      `SELECT id, display_name, avatar_url, leaderboard_opt_in,
              ${leaderboardOptInTimeColumn},
              status, created_at, updated_at
       FROM users
       ORDER BY created_at, id`
    ).all()) {
      const user = {
        id: row.id,
        deviceId: '',
        deviceIds: [],
        displayName: row.display_name || '',
        avatarUrl: row.avatar_url || '',
        leaderboardOptIn: Boolean(row.leaderboard_opt_in),
        leaderboardOptedInAt: row.leaderboard_opted_in_at || null,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        favorites: [],
        wrongs: {},
        answers: []
      };
      userById.set(row.id, user);
    }

    for (const row of this.database.prepare(
      `SELECT device_id, user_id
       FROM anonymous_devices
       ORDER BY created_at, device_id`
    ).all()) {
      const user = userById.get(row.user_id);
      if (user) {
        user.deviceIds.push(row.device_id);
        user.deviceId ||= row.device_id;
        users[row.device_id] = user;
      }
    }

    for (const row of this.database.prepare(
      `SELECT f.user_id, f.question_id
       FROM favorites f
       ORDER BY f.created_at, f.question_id`
    ).all()) {
      const user = userById.get(row.user_id);
      if (user) {
        user.favorites.push(row.question_id);
      }
    }

    for (const row of this.database.prepare(
      `SELECT user_id, question_id, wrong_count, mastered, updated_at
       FROM wrong_questions
       ORDER BY updated_at, question_id`
    ).all()) {
      const user = userById.get(row.user_id);
      if (user) {
        user.wrongs[row.question_id] = {
          questionId: row.question_id,
          wrongCount: row.wrong_count,
          mastered: Boolean(row.mastered),
          updatedAt: row.updated_at
        };
      }
    }

    for (const row of this.database.prepare(
      `SELECT attempt_id, user_id, question_id, category_id, question_type,
              is_correct,
              ${currentVersion >= 3 ? 'leaderboard_eligible' : '0 AS leaderboard_eligible'},
              submitted_at
       FROM answer_attempts
       ORDER BY sequence_id`
    ).all()) {
      const user = userById.get(row.user_id);
      if (user) {
        user.answers.push({
          id: row.attempt_id,
          questionId: row.question_id,
          categoryId: row.category_id,
          type: row.question_type,
          isCorrect: row.is_correct === null ? null : Boolean(row.is_correct),
          leaderboardEligible: Boolean(row.leaderboard_eligible),
          submittedAt: row.submitted_at
        });
      }
    }

    return {
      meta: JSON.parse(metadataRow.payload_json),
      categories,
      questions,
      users
    };
  }

  replaceAll(snapshot) {
    const normalized = normalizeSnapshot(snapshot);
    const replace = this.database.transaction(() => {
      this.database.exec(`
        DELETE FROM auth_sessions;
        DELETE FROM user_identities;
        DELETE FROM favorites;
        DELETE FROM wrong_questions;
        DELETE FROM answer_attempts;
        DELETE FROM anonymous_devices;
        DELETE FROM users;
        DELETE FROM questions;
        DELETE FROM categories;
        DELETE FROM app_metadata;
      `);
      this.saveMetadataRecord(normalized.meta);
      for (const category of normalized.categories) {
        this.saveCategoryRecord(category);
      }
      for (const question of normalized.questions) {
        this.saveQuestionRecord(question);
      }
      for (const user of Object.values(normalized.users)) {
        this.saveUserRecords(user);
      }
    });
    replace();
  }

  saveCatalog(snapshot) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(snapshot.meta);
      for (const category of snapshot.categories) {
        this.saveCategoryRecord(category);
      }
      for (const question of snapshot.questions) {
        this.saveQuestionRecord(question);
      }
    });
    save();
  }

  saveCategory(category, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveCategoryRecord(category);
    });
    save();
  }

  saveQuestion(question, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveQuestionRecord(question);
    });
    save();
  }

  saveQuestions(questions, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      for (const question of questions) {
        this.saveQuestionRecord(question);
      }
    });
    save();
  }

  saveUser(user, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecords(user);
    });
    save();
  }

  saveUserProfile(user, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecord(user);
    });
    save();
  }

  listLeaderboardRows({ categoryId = '', periodStart = null } = {}) {
    const categoryClause = categoryId ? 'AND q.category_id = ?' : '';
    const periodClause = periodStart ? 'WHERE first_correct_at >= ?' : '';
    const parameters = [];
    if (categoryId) {
      parameters.push(categoryId);
    }
    if (periodStart) {
      parameters.push(periodStart);
    }

    return this.database.prepare(
      `WITH first_correct AS (
         SELECT aa.user_id,
                aa.question_id,
                MIN(aa.submitted_at) AS first_correct_at
       FROM answer_attempts aa
       INNER JOIN questions q ON q.id = aa.question_id
       INNER JOIN users scoring_user ON scoring_user.id = aa.user_id
       WHERE aa.is_correct = 1
         AND aa.leaderboard_eligible = 1
         AND aa.submitted_at >= scoring_user.leaderboard_opted_in_at
         AND q.status = 'published'
           AND q.review_status = 'verified'
           AND q.type IN ('single', 'multiple', 'boolean')
           ${categoryClause}
         GROUP BY aa.user_id, aa.question_id
       ),
       scores AS (
         SELECT user_id,
                COUNT(*) AS score,
                MAX(first_correct_at) AS last_scored_at
         FROM first_correct
         ${periodClause}
         GROUP BY user_id
       )
       SELECT u.id AS user_id,
              scores.score,
              scores.last_scored_at
       FROM scores
       INNER JOIN users u ON u.id = scores.user_id
       WHERE u.leaderboard_opt_in = 1
         AND u.leaderboard_opted_in_at IS NOT NULL
         AND u.status = 'active'
         AND EXISTS (
           SELECT 1
           FROM user_identities identity
           WHERE identity.user_id = u.id
         )
       ORDER BY scores.score DESC,
                scores.last_scored_at ASC,
                u.created_at ASC,
                u.id ASC`
    ).all(...parameters).map((row) => ({
      userId: row.user_id,
      score: row.score,
      lastScoredAt: row.last_scored_at
    }));
  }

  recordAnswer(user, answer, wrong, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecord(user);
      this.saveAnswerRecord(user.id, answer);
      if (wrong) {
        this.saveWrongRecord(user.id, wrong, user.updatedAt);
      }
    });
    save();
  }

  setWrong(user, wrong, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecord(user);
      this.saveWrongRecord(user.id, wrong, user.updatedAt);
    });
    save();
  }

  addFavorite(user, questionId, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecord(user);
      this.database.prepare(
        `INSERT INTO favorites (user_id, question_id, created_at)
         VALUES (?, ?, ?)
         ON CONFLICT(user_id, question_id) DO NOTHING`
      ).run(user.id, questionId, user.updatedAt);
    });
    save();
  }

  removeFavorite(user, questionId, metadata) {
    const save = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecord(user);
      this.database.prepare(
        'DELETE FROM favorites WHERE user_id = ? AND question_id = ?'
      ).run(user.id, questionId);
    });
    save();
  }

  findIdentity(provider, providerSubject) {
    const row = this.database.prepare(
      `SELECT id, user_id, provider, provider_subject, union_id, created_at, updated_at
       FROM user_identities
       WHERE provider = ? AND provider_subject = ?`
    ).get(provider, providerSubject);
    return row ? mapIdentity(row) : undefined;
  }

  hasIdentityForUser(userId) {
    return Boolean(this.database.prepare(
      'SELECT 1 AS present FROM user_identities WHERE user_id = ? LIMIT 1'
    ).get(userId));
  }

  findActiveAccessSession(accessTokenHash, now) {
    const row = this.database.prepare(
      `SELECT id, user_id, access_expires_at, expires_at, revoked_at, created_at, updated_at
       FROM auth_sessions
       WHERE access_token_hash = ?
         AND revoked_at IS NULL
         AND access_expires_at > ?`
    ).get(accessTokenHash, now);
    return row ? mapSession(row) : undefined;
  }

  findActiveRefreshSession(refreshTokenHash, now) {
    const row = this.database.prepare(
      `SELECT id, user_id, access_expires_at, expires_at, revoked_at, created_at, updated_at
       FROM auth_sessions
       WHERE refresh_token_hash = ?
         AND revoked_at IS NULL
         AND expires_at > ?`
    ).get(refreshTokenHash, now);
    return row ? mapSession(row) : undefined;
  }

  authenticateUser({ user, mergedUserId, identity, session, metadata }) {
    const authenticate = this.database.transaction(() => {
      this.saveMetadataRecord(metadata);
      this.saveUserRecords(user);

      if (mergedUserId && mergedUserId !== user.id) {
        this.database.prepare(
          'UPDATE user_identities SET user_id = ?, updated_at = ? WHERE user_id = ?'
        ).run(user.id, session.updatedAt, mergedUserId);
        this.database.prepare(
          'UPDATE auth_sessions SET user_id = ?, updated_at = ? WHERE user_id = ?'
        ).run(user.id, session.updatedAt, mergedUserId);
        this.database.prepare('DELETE FROM users WHERE id = ?').run(mergedUserId);
      }

      this.saveIdentityRecord(identity);
      this.saveSessionRecord(session);
    });
    authenticate();
  }

  rotateSession(session) {
    const result = this.database.prepare(
      `UPDATE auth_sessions
       SET access_token_hash = ?,
           access_expires_at = ?,
           refresh_token_hash = ?,
           expires_at = ?,
           updated_at = ?
       WHERE id = ? AND revoked_at IS NULL`
    ).run(
      session.accessTokenHash,
      session.accessExpiresAt,
      session.refreshTokenHash,
      session.refreshExpiresAt,
      session.updatedAt,
      session.id
    );
    return result.changes === 1;
  }

  revokeSession(sessionId, revokedAt) {
    this.database.prepare(
      `UPDATE auth_sessions
       SET revoked_at = ?, updated_at = ?
       WHERE id = ? AND revoked_at IS NULL`
    ).run(revokedAt, revokedAt, sessionId);
  }

  integrityCheck() {
    return this.database.pragma('integrity_check', { simple: true });
  }

  close() {
    if (!this.database.open) {
      return;
    }
    this.database.pragma('wal_checkpoint(TRUNCATE)');
    this.database.close();
  }

  saveMetadataRecord(metadata) {
    this.database.prepare(
      `INSERT INTO app_metadata (id, payload_json)
       VALUES (1, ?)
       ON CONFLICT(id) DO UPDATE SET payload_json = excluded.payload_json`
    ).run(JSON.stringify(metadata));
  }

  saveCategoryRecord(category) {
    this.database.prepare(
      `INSERT INTO categories (id, sort_order, payload_json)
       VALUES (?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         sort_order = excluded.sort_order,
         payload_json = excluded.payload_json`
    ).run(
      category.id,
      Number.isInteger(category.order) ? category.order : 9999,
      JSON.stringify(category)
    );
  }

  saveQuestionRecord(question) {
    const createdAt = question.createdAt || new Date().toISOString();
    const updatedAt = question.updatedAt || createdAt;
    const normalized = {
      ...question,
      createdAt,
      updatedAt
    };
    this.database.prepare(
      `INSERT INTO questions (
         id, category_id, type, difficulty, status, review_status,
         sort_order, created_at, updated_at, payload_json
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         category_id = excluded.category_id,
         type = excluded.type,
         difficulty = excluded.difficulty,
         status = excluded.status,
         review_status = excluded.review_status,
         sort_order = excluded.sort_order,
         created_at = excluded.created_at,
         updated_at = excluded.updated_at,
         payload_json = excluded.payload_json`
    ).run(
      normalized.id,
      normalized.categoryId,
      normalized.type,
      normalized.difficulty,
      normalized.status,
      normalized.reviewStatus || 'needs_review',
      Number.isInteger(normalized.order) ? normalized.order : 999999,
      createdAt,
      updatedAt,
      JSON.stringify(normalized)
    );
  }

  saveIdentityRecord(identity) {
    const existing = this.findIdentity(identity.provider, identity.providerSubject);
    if (existing && existing.userId !== identity.userId) {
      throw new Error('External identity is already linked to another user');
    }
    this.database.prepare(
      `INSERT INTO user_identities (
         id, user_id, provider, provider_subject, union_id, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(provider, provider_subject) DO UPDATE SET
         union_id = excluded.union_id,
         updated_at = excluded.updated_at`
    ).run(
      identity.id,
      identity.userId,
      identity.provider,
      identity.providerSubject,
      identity.unionId || null,
      identity.createdAt,
      identity.updatedAt
    );
  }

  saveSessionRecord(session) {
    this.database.prepare(
      `INSERT INTO auth_sessions (
         id, user_id, access_token_hash, access_expires_at,
         refresh_token_hash, expires_at, revoked_at, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      session.id,
      session.userId,
      session.accessTokenHash,
      session.accessExpiresAt,
      session.refreshTokenHash,
      session.refreshExpiresAt,
      null,
      session.createdAt,
      session.updatedAt
    );
  }

  saveUserRecords(user) {
    normalizeUser(user);
    this.saveUserRecord(user);

    this.database.prepare('DELETE FROM favorites WHERE user_id = ?').run(user.id);
    const insertFavorite = this.database.prepare(
      `INSERT INTO favorites (user_id, question_id, created_at)
       VALUES (?, ?, ?)`
    );
    for (const questionId of user.favorites) {
      insertFavorite.run(user.id, questionId, user.updatedAt);
    }

    this.database.prepare('DELETE FROM wrong_questions WHERE user_id = ?').run(user.id);
    for (const wrong of Object.values(user.wrongs)) {
      this.saveWrongRecord(user.id, wrong, user.updatedAt);
    }

    for (const answer of user.answers) {
      this.saveAnswerRecord(user.id, answer);
    }
  }

  saveUserRecord(user) {
    normalizeUser(user);
    this.database.prepare(
      `INSERT INTO users (
         id, display_name, avatar_url,
         leaderboard_opt_in, leaderboard_opted_in_at,
         status, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         display_name = excluded.display_name,
         avatar_url = excluded.avatar_url,
         leaderboard_opt_in = excluded.leaderboard_opt_in,
         leaderboard_opted_in_at = excluded.leaderboard_opted_in_at,
         status = excluded.status,
         updated_at = excluded.updated_at`
    ).run(
      user.id,
      user.displayName || null,
      user.avatarUrl || null,
      user.leaderboardOptIn ? 1 : 0,
      user.leaderboardOptedInAt || null,
      user.status || 'active',
      user.createdAt,
      user.updatedAt
    );

    this.database.prepare(
      'DELETE FROM anonymous_devices WHERE user_id = ?'
    ).run(user.id);
    const upsertDevice = this.database.prepare(
      `INSERT INTO anonymous_devices (device_id, user_id, created_at, updated_at)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(device_id) DO UPDATE SET
         user_id = excluded.user_id,
         updated_at = excluded.updated_at`
    );
    for (const deviceId of user.deviceIds) {
      upsertDevice.run(deviceId, user.id, user.createdAt, user.updatedAt);
    }
  }

  saveWrongRecord(userId, wrong, fallbackUpdatedAt) {
    this.database.prepare(
      `INSERT INTO wrong_questions (
         user_id, question_id, wrong_count, mastered, updated_at
       ) VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(user_id, question_id) DO UPDATE SET
         wrong_count = excluded.wrong_count,
         mastered = excluded.mastered,
         updated_at = excluded.updated_at`
    ).run(
      userId,
      wrong.questionId,
      wrong.wrongCount,
      wrong.mastered ? 1 : 0,
      wrong.updatedAt || fallbackUpdatedAt
    );
  }

  saveAnswerRecord(userId, answer) {
    answer.id ||= `attempt-${randomUUID()}`;
    this.database.prepare(
      `INSERT INTO answer_attempts (
         attempt_id, user_id, question_id, category_id,
         question_type, is_correct, leaderboard_eligible, submitted_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(attempt_id) DO UPDATE SET
         user_id = excluded.user_id,
         question_id = excluded.question_id,
         category_id = excluded.category_id,
         question_type = excluded.question_type,
         is_correct = excluded.is_correct,
         leaderboard_eligible = excluded.leaderboard_eligible,
         submitted_at = excluded.submitted_at`
    ).run(
      answer.id,
      userId,
      answer.questionId,
      answer.categoryId,
      answer.type,
      answer.isCorrect === null ? null : answer.isCorrect ? 1 : 0,
      answer.leaderboardEligible ? 1 : 0,
      answer.submittedAt
    );
  }
}

function normalizeSnapshot(snapshot) {
  const now = new Date().toISOString();
  const meta = snapshot?.meta && typeof snapshot.meta === 'object'
    ? { ...snapshot.meta }
    : {};
  meta.name ||= 'ArkInterview';
  meta.displayName ||= 'Ark 面试通';
  meta.packageName ||= 'com.lgq.arkinterview';
  meta.createdAt ||= now;
  meta.updatedAt ||= now;

  const categories = Array.isArray(snapshot?.categories) ? snapshot.categories : [];
  const questions = Array.isArray(snapshot?.questions) ? snapshot.questions : [];
  const users = snapshot?.users && typeof snapshot.users === 'object'
    ? snapshot.users
    : {};

  for (const [deviceId, user] of Object.entries(users)) {
    user.deviceId ||= deviceId;
    normalizeUser(user);
  }

  return {
    meta,
    categories,
    questions,
    users
  };
}

function normalizeUser(user) {
  const now = new Date().toISOString();
  user.id ||= `user-${randomUUID()}`;
  user.deviceId = String(user.deviceId || '').trim();
  if (!user.deviceId) {
    throw new Error('Cannot persist a user without a device ID');
  }
  user.deviceIds = Array.isArray(user.deviceIds)
    ? [...new Set([user.deviceId, ...user.deviceIds.map((item) => String(item).trim()).filter(Boolean)])]
    : [user.deviceId];
  user.createdAt ||= now;
  user.updatedAt ||= user.createdAt;
  user.status ||= 'active';
  user.displayName ||= '';
  user.avatarUrl ||= '';
  user.leaderboardOptIn = Boolean(user.leaderboardOptIn);
  user.leaderboardOptedInAt ||= null;
  user.favorites = Array.isArray(user.favorites) ? [...new Set(user.favorites)] : [];
  user.wrongs = user.wrongs && typeof user.wrongs === 'object' ? user.wrongs : {};
  user.answers = Array.isArray(user.answers) ? user.answers : [];
}

function mapIdentity(row) {
  return {
    id: row.id,
    userId: row.user_id,
    provider: row.provider,
    providerSubject: row.provider_subject,
    unionId: row.union_id || '',
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function mapSession(row) {
  return {
    id: row.id,
    userId: row.user_id,
    accessExpiresAt: row.access_expires_at,
    refreshExpiresAt: row.expires_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}
