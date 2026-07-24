import assert from 'node:assert/strict';
import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { LeaderboardError, LeaderboardService, startOfShanghaiWeek } from './leaderboard-service.mjs';
import { openSqliteStore } from './sqlite-store.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const tempDir = path.join(rootDir, '.tmp', `leaderboard-${process.pid}-${Date.now()}`);
const dbFile = path.join(tempDir, 'leaderboard.sqlite');
const now = new Date('2026-07-24T09:00:00.000Z');

await mkdir(tempDir, { recursive: true });

let activeStore;
try {
  const opened = await openSqliteStore({
    dbFile,
    legacyDbFile: path.join(tempDir, 'missing.json'),
    createInitialData: createSnapshot
  });
  activeStore = opened.store;
  const questions = Object.fromEntries(opened.snapshot.questions.map((question) => [question.id, question]));

  addAccount(opened, {
    id: 'user-a',
    displayName: '真实用户甲',
    leaderboardOptIn: true,
    answers: [
      answer('a-q1-wrong', questions.q1, false, '2026-07-20T00:00:00.000Z'),
      answer('a-q1-first-correct', questions.q1, true, '2026-07-20T01:00:00.000Z'),
      answer('a-q1-repeat', questions.q1, true, '2026-07-23T01:00:00.000Z'),
      answer('a-q2-correct', questions.q2, true, '2026-07-21T01:00:00.000Z'),
      answer('a-short', questions.q3, true, '2026-07-21T02:00:00.000Z'),
      answer('a-draft', questions.q4, true, '2026-07-21T03:00:00.000Z'),
      answer('a-unverified', questions.q5, true, '2026-07-21T04:00:00.000Z')
    ]
  });
  addAccount(opened, {
    id: 'user-b',
    displayName: '真实用户乙',
    leaderboardOptIn: true,
    answers: [
      answer('b-q1-correct', questions.q1, true, '2026-07-22T01:00:00.000Z')
    ]
  });
  addAccount(opened, {
    id: 'user-c',
    displayName: '未授权用户',
    leaderboardOptIn: false,
    answers: [
      answer('c-q1-correct', questions.q1, true, '2026-07-20T01:00:00.000Z'),
      answer('c-q2-correct', questions.q2, true, '2026-07-20T02:00:00.000Z')
    ]
  });
  addAccount(opened, {
    id: 'user-d',
    displayName: '未绑定账号用户',
    leaderboardOptIn: true,
    hasIdentity: false,
    answers: [
      answer('d-q1-correct', questions.q1, true, '2026-07-20T01:00:00.000Z'),
      answer('d-q2-correct', questions.q2, true, '2026-07-20T02:00:00.000Z')
    ]
  });
  addAccount(opened, {
    id: 'user-e',
    displayName: '历史得分用户',
    leaderboardOptIn: true,
    answers: [
      answer('e-q1-old-correct', questions.q1, true, '2026-07-10T01:00:00.000Z', false),
      answer('e-q1-repeat-this-week', questions.q1, true, '2026-07-23T01:00:00.000Z')
    ]
  });
  addAccount(opened, {
    id: 'user-f',
    displayName: '只有匿名历史的用户',
    leaderboardOptIn: true,
    answers: [
      answer('f-q1-old-correct', questions.q1, true, '2026-07-10T01:00:00.000Z', false)
    ]
  });
  addAccount(opened, {
    id: 'user-g',
    displayName: '退出期间作答用户',
    leaderboardOptIn: true,
    answers: [
      answer('g-q1-opted-out-correct', questions.q1, true, '2026-07-22T02:00:00.000Z', false)
    ]
  });

  const service = new LeaderboardService({
    store: opened.store,
    db: opened.snapshot,
    now: () => now
  });

  assert.equal(
    startOfShanghaiWeek(now).toISOString(),
    '2026-07-19T16:00:00.000Z',
    'weekly periods should start at Monday 00:00 in Asia/Shanghai'
  );

  const weekly = service.getLeaderboard({
    scope: 'weekly',
    limit: 50,
    currentUserId: 'user-b'
  });
  assert.equal(weekly.periodStart, '2026-07-19T16:00:00.000Z');
  assert.equal(weekly.totalParticipants, 3, 'only opted-in account users with weekly scores should appear');
  assert.deepEqual(
    weekly.entries.map((entry) => entry.score),
    [2, 1, 1],
    'duplicate correct answers and ineligible questions must not add score'
  );
  assert.equal(weekly.entries[1].isCurrentUser, true, 'the current signed-in user should be marked');
  assert.equal(weekly.me.rank, 2, 'the signed-in user should receive their current rank');
  assert.equal(
    weekly.entries[2].lastScoredAt,
    '2026-07-23T01:00:00.000Z',
    'only correct answers submitted after opt-in should establish the eligible first-correct time'
  );

  const overall = service.getLeaderboard({
    scope: 'overall',
    limit: 1,
    currentUserId: 'user-b'
  });
  assert.equal(overall.periodStart, null, 'overall rankings should not have a period start');
  assert.equal(overall.totalParticipants, 3, 'older first-correct scores should remain in the overall ranking');
  assert.equal(overall.entries.length, 1, 'limit should only trim the public entries list');
  assert.equal(overall.entries[0].score, 2);
  assert.equal(overall.me.rank, 2, 'current user rank should remain available outside the top limit');
  assert.equal(overall.me.score, 1);

  const category = service.getLeaderboard({
    scope: 'overall',
    categoryId: 'arkts',
    currentUserId: ''
  });
  assert.equal(category.categoryName, 'ArkTS');
  assert.equal(category.totalParticipants, 3);
  assert.deepEqual(
    category.entries.map((entry) => entry.score),
    [1, 1, 1],
    'category rankings should only include questions from the selected category'
  );

  const serialized = JSON.stringify(overall);
  assert(!serialized.includes('真实用户甲'), 'leaderboards must not expose account display names');
  assert(!serialized.includes('user-a'), 'leaderboards must not expose internal user IDs');
  assert.match(overall.entries[0].displayName, /^Ark开发者·[A-F0-9]{4}$/);

  assert.throws(
    () => service.getLeaderboard({ scope: 'daily' }),
    (error) => error instanceof LeaderboardError && error.status === 400,
    'unsupported scopes should be rejected'
  );
  assert.throws(
    () => service.getLeaderboard({ scope: 'weekly', categoryId: 'missing' }),
    (error) => error instanceof LeaderboardError && error.status === 400,
    'unknown categories should be rejected'
  );
  assert.throws(
    () => service.getLeaderboard({ scope: 'weekly', limit: 101 }),
    (error) => error instanceof LeaderboardError && error.status === 400,
    'oversized limits should be rejected'
  );
  assert.equal(opened.store.integrityCheck(), 'ok');

  console.log('Leaderboard service tests passed.');
} finally {
  if (activeStore) {
    activeStore.close();
  }
  await rm(tempDir, { recursive: true, force: true });
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
      question('q1', 'arkts', 'single', 'published', 'verified', createdAt),
      question('q2', 'arkui', 'multiple', 'published', 'verified', createdAt),
      question('q3', 'arkts', 'short', 'published', 'verified', createdAt),
      question('q4', 'arkts', 'single', 'draft', 'verified', createdAt),
      question('q5', 'arkts', 'boolean', 'published', 'needs_review', createdAt)
    ],
    users: {}
  };
}

function question(id, categoryId, type, status, reviewStatus, timestamp) {
  return {
    id,
    categoryId,
    type,
    difficulty: 'basic',
    title: id,
    options: [],
    explanation: '',
    knowledgePoints: [],
    status,
    reviewStatus,
    verifiedAt: '2026-07-24',
    sourceRefs: ['official-test-source'],
    order: 1,
    createdAt: timestamp,
    updatedAt: timestamp
  };
}

function answer(id, questionItem, isCorrect, submittedAt, leaderboardEligible = true) {
  return {
    id,
    questionId: questionItem.id,
    categoryId: questionItem.categoryId,
    type: questionItem.type,
    isCorrect,
    leaderboardEligible,
    submittedAt
  };
}

function addAccount(opened, {
  id,
  displayName,
  leaderboardOptIn,
  answers,
  hasIdentity = true
}) {
  const createdAt = '2026-07-01T00:00:00.000Z';
  const deviceId = `account/${id}`;
  const user = {
    id,
    deviceId,
    deviceIds: [deviceId],
    displayName,
    avatarUrl: 'https://example.com/private-avatar.png',
    leaderboardOptIn,
    leaderboardOptedInAt: leaderboardOptIn ? '2026-07-19T16:00:00.000Z' : null,
    status: 'active',
    createdAt,
    updatedAt: answers.at(-1)?.submittedAt || createdAt,
    favorites: [],
    wrongs: {},
    answers
  };
  opened.store.saveUser(user, opened.snapshot.meta);

  if (hasIdentity) {
    opened.store.database.prepare(
      `INSERT INTO user_identities (
         id, user_id, provider, provider_subject, union_id, created_at, updated_at
       ) VALUES (?, ?, 'huawei', ?, NULL, ?, ?)`
    ).run(`identity-${id}`, id, `subject-${id}`, createdAt, createdAt);
  }
}
