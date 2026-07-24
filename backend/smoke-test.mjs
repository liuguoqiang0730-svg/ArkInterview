import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const tempRoot = path.join(rootDir, '.tmp');
const tempDir = path.join(tempRoot, `smoke-${process.pid}-${Date.now()}`);
const dbFile = path.join(tempDir, 'smoke-db.json');
const port = 8791;
const baseUrl = `http://127.0.0.1:${port}`;
const adminToken = 'arkinterview-smoke-admin-token-2026-07-23';

await mkdir(tempRoot, { recursive: true });
await mkdir(tempDir, { recursive: true });

const server = spawn(process.execPath, [path.join(rootDir, 'backend', 'server.mjs')], {
  cwd: rootDir,
  env: {
    ...process.env,
    PORT: String(port),
    DB_FILE: dbFile,
    ADMIN_TOKEN: adminToken
  },
  stdio: ['ignore', 'pipe', 'pipe']
});

const logs = [];
server.stdout.on('data', (chunk) => logs.push(chunk.toString('utf8')));
server.stderr.on('data', (chunk) => logs.push(chunk.toString('utf8')));

try {
  await waitForServer();
  await runChecks();
  console.log('Smoke tests passed.');
} finally {
  if (!server.killed) {
    server.kill();
  }
  await once(server, 'exit').catch(() => {});
  await rm(tempDir, { recursive: true, force: true });
}

async function waitForServer() {
  const startedAt = Date.now();
  while (Date.now() - startedAt < 5000) {
    try {
      const response = await fetch(`${baseUrl}/api/categories`);
      if (response.ok) {
        return;
      }
    } catch {
      await delay(100);
    }
  }
  throw new Error(`Server did not start.\n${logs.join('')}`);
}

async function runChecks() {
  const missingTokenResponse = await fetch(`${baseUrl}/api/admin/questions`);
  assert(missingTokenResponse.status === 401, 'admin API should reject requests without a token');
  assert(
    missingTokenResponse.headers.get('www-authenticate')?.includes('Bearer'),
    'admin API should advertise Bearer authentication'
  );

  const invalidTokenResponse = await fetch(`${baseUrl}/api/admin/questions`, {
    headers: {
      Authorization: 'Bearer invalid-admin-token'
    }
  });
  assert(invalidTokenResponse.status === 401, 'admin API should reject an invalid token');

  const preflightResponse = await fetch(`${baseUrl}/api/admin/questions`, {
    method: 'OPTIONS',
    headers: {
      Origin: 'http://127.0.0.1:8787',
      'Access-Control-Request-Headers': 'authorization,content-type',
      'Access-Control-Request-Method': 'POST'
    }
  });
  assert(preflightResponse.status === 204, 'admin API preflight should remain available');
  assert(
    preflightResponse.headers.get('access-control-allow-headers')?.toLowerCase().includes('authorization'),
    'admin API preflight should allow the Authorization header'
  );

  const categories = await getJson('/api/categories');
  assert(categories.items.length === 16, 'categories count should be 16');

  await postJson('/api/admin/categories', {
    id: 'smoke-category',
    name: 'Smoke Category',
    order: 99,
    description: 'Category used by the backend smoke test.'
  });
  const updatedCategory = await patchJson('/api/admin/categories/smoke-category', {
    name: 'Updated Smoke Category',
    order: 100
  });
  assert(updatedCategory.item.name === 'Updated Smoke Category', 'admin category PATCH should update fields');
  assert(updatedCategory.item.order === 100, 'admin category PATCH should preserve numeric order');

  const questions = await getJson('/api/questions?pageSize=20');
  const seedPublishedTotal = questions.total;

  await createVerifiedSmokeQuestions();

  const adminQuestions = await getJson('/api/admin/questions');
  const orderedQuestion = adminQuestions.items.find((item) => item.id === 'q-smoke-single');
  assert(orderedQuestion.order === 9001, 'admin question create should preserve explicit order');

  const missingBatchQuestion = await patchJson('/api/admin/questions/batch-status', {
    questionIds: ['q-smoke-single', 'q-smoke-missing'],
    status: 'offline'
  }, false);
  assert(missingBatchQuestion.status === 404, 'batch status should reject a missing question atomically');
  const afterRejectedBatch = await getJson('/api/admin/questions');
  assert(
    afterRejectedBatch.items.find((item) => item.id === 'q-smoke-single').status === 'published',
    'a rejected batch should not update existing questions'
  );

  const invalidBatchStatus = await patchJson('/api/admin/questions/batch-status', {
    questionIds: ['q-smoke-single'],
    status: 'draft'
  }, false);
  assert(invalidBatchStatus.status === 400, 'batch status should only allow publish or offline actions');

  const offlineBatch = await patchJson('/api/admin/questions/batch-status', {
    questionIds: ['q-smoke-single', 'q-smoke-multiple'],
    status: 'offline'
  });
  assert(offlineBatch.items.every((item) => item.status === 'offline'), 'batch offline should update every selected question');
  const afterOffline = await getJson('/api/questions?pageSize=20');
  assert(afterOffline.total === seedPublishedTotal + 2, 'offline questions should leave the public question bank');

  const publishedBatch = await patchJson('/api/admin/questions/batch-status', {
    questionIds: ['q-smoke-single', 'q-smoke-multiple'],
    status: 'published'
  });
  assert(publishedBatch.items.every((item) => item.status === 'published'), 'batch publish should restore every selected question');

  const publishedQuestions = await getJson('/api/questions?pageSize=20');
  assert(publishedQuestions.total === seedPublishedTotal + 4, 'verified smoke questions should be added');

  const secondPage = await getJson('/api/questions?page=2&pageSize=5');
  assert(secondPage.page === 2, 'questions pagination should keep requested page');
  assert(secondPage.pageSize === 5, 'questions pagination should keep requested page size');
  assert(secondPage.items.length === 5, 'questions pagination should return page-sized items');
  assert(secondPage.total === seedPublishedTotal + 4, 'questions pagination should preserve total');
  assert(secondPage.totalPages >= 2, 'questions pagination should include total pages');

  const questionDetail = await getJson('/api/questions/q-smoke-single');
  assert(questionDetail.item.sourceRefs.length > 0, 'question detail should include official sources');

  const randomPractice = await getJson('/api/practice/session?mode=random&count=3');
  assert(randomPractice.total === 3, 'random practice should return 3 questions');
  assert(randomPractice.items.every((item) => item.correctOptionIds === undefined), 'practice list should not expose answers');

  const categoryPractice = await getJson('/api/practice/session?mode=category&categoryId=arkui&count=2');
  assert(categoryPractice.items.every((item) => item.categoryId === 'arkui'), 'category practice should filter category');

  const correctAnswer = await postJson('/api/answers/submit', {
    questionId: 'q-smoke-single',
    selectedOptionIds: ['b']
  });
  assert(correctAnswer.isCorrect === true, 'correct answer should be accepted');

  const missingAnswer = await postJson('/api/answers/submit', {
    questionId: 'q-missing',
    selectedOptionIds: ['a']
  }, false);
  assert(missingAnswer.status === 404, 'submitting a missing question should return 404');

  await postJson('/api/answers/submit', {
    questionId: 'q-smoke-single',
    selectedOptionIds: ['a']
  });
  const wrongPractice = await getJson('/api/practice/session?mode=wrongs&count=5');
  assert(wrongPractice.total === 1, 'wrong practice should include wrong question');

  await postJson('/api/users/me/favorites', { questionId: 'q-smoke-single' });
  const favoritePractice = await getJson('/api/practice/session?mode=favorites&count=5');
  assert(favoritePractice.total === 1, 'favorite practice should include favorite question');
  assert(favoritePractice.items[0].isFavorite === true, 'favorite practice should include favorite marker');

  const isolatedStats = await getJson('/api/users/me/stats', 'smoke-test-secondary');
  assert(isolatedStats.totalAnswers === 0, 'a second anonymous device should have isolated answer stats');
  const isolatedWrongs = await getJson('/api/users/me/wrongs', 'smoke-test-secondary');
  assert(isolatedWrongs.items.length === 0, 'a second anonymous device should not inherit wrong questions');
  const isolatedFavorites = await getJson('/api/users/me/favorites', 'smoke-test-secondary');
  assert(isolatedFavorites.items.length === 0, 'a second anonymous device should not inherit favorites');

  const interview = await getJson('/api/interviews/basic?count=4');
  assert(interview.total === 4, 'basic interview should return 4 questions');

  const blockedDraft = await postJson('/api/admin/questions', {
    categoryId: 'arkts',
    type: 'single',
    difficulty: 'easy',
    status: 'draft',
    reviewStatus: 'needs_review',
    title: '未核验题目不能直接发布',
    options: [
      { id: 'a', text: '正确选项' },
      { id: 'b', text: '错误选项' }
    ],
    correctOptionIds: ['a'],
    explanation: '这道题用于验证发布质量闸门。',
    knowledgePoints: ['内容审核']
  }, false);
  assert(blockedDraft.status === 400, 'saving unverified question should be blocked');
}

async function createVerifiedSmokeQuestions() {
  const common = {
    difficulty: 'easy',
    status: 'published',
    reviewStatus: 'verified',
    verifiedAt: '2026-07-02',
    sourceRefs: [
      {
        title: 'ArkTS 概述',
        url: 'https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-overview-V5',
        publisher: 'Huawei Developer'
      }
    ]
  };

  await postJson('/api/admin/questions', {
    ...common,
    id: 'q-smoke-single',
    order: 9001,
    categoryId: 'arkts',
    type: 'single',
    title: '已核验单选测试题',
    options: [
      { id: 'a', text: '错误选项' },
      { id: 'b', text: '正确选项' }
    ],
    correctOptionIds: ['b'],
    explanation: '用于验证单选题答题流程。',
    knowledgePoints: ['ArkTS']
  });

  await postJson('/api/admin/questions', {
    ...common,
    id: 'q-smoke-multiple',
    categoryId: 'network',
    type: 'multiple',
    title: '已核验多选测试题',
    options: [
      { id: 'a', text: '处理超时' },
      { id: 'b', text: '处理错误状态' },
      { id: 'c', text: '忽略失败' }
    ],
    correctOptionIds: ['a', 'b'],
    explanation: '用于验证多选题和随机练习流程。',
    knowledgePoints: ['网络请求']
  });

  await postJson('/api/admin/questions', {
    ...common,
    id: 'q-smoke-boolean',
    categoryId: 'preferences',
    type: 'boolean',
    title: '已核验判断测试题',
    answerBoolean: true,
    explanation: '用于验证判断题流程。',
    knowledgePoints: ['Preferences']
  });

  await postJson('/api/admin/questions', {
    ...common,
    id: 'q-smoke-short',
    categoryId: 'arkui',
    type: 'short',
    title: '已核验简答测试题',
    referenceAnswer: '这是用于验证简答题流程的参考答案。',
    scoringPoints: ['参考答案存在', '评分点存在'],
    explanation: '用于验证简答题和模拟面试流程。',
    knowledgePoints: ['ArkUI']
  });
}

async function getJson(pathname, deviceId = 'smoke-test') {
  const response = await fetch(`${baseUrl}${pathname}`, {
    headers: requestHeaders(pathname, {}, deviceId)
  });
  return parseResponse(response);
}

async function postJson(pathname, body, expectOk = true) {
  const response = await fetch(`${baseUrl}${pathname}`, {
    method: 'POST',
    headers: requestHeaders(pathname, { 'Content-Type': 'application/json' }),
    body: JSON.stringify(body)
  });
  if (!expectOk) {
    return {
      status: response.status,
      data: await response.json()
    };
  }
  return parseResponse(response);
}

async function patchJson(pathname, body, expectOk = true) {
  const response = await fetch(`${baseUrl}${pathname}`, {
    method: 'PATCH',
    headers: requestHeaders(pathname, { 'Content-Type': 'application/json' }),
    body: JSON.stringify(body)
  });
  if (!expectOk) {
    return {
      status: response.status,
      data: await response.json()
    };
  }
  return parseResponse(response);
}

function requestHeaders(pathname, extraHeaders = {}, deviceId = 'smoke-test') {
  return {
    'X-Device-Id': deviceId,
    ...(pathname.startsWith('/api/admin/') ? { Authorization: `Bearer ${adminToken}` } : {}),
    ...extraHeaders
  };
}

async function parseResponse(response) {
  const data = await response.json();
  if (!response.ok) {
    throw new Error(`${response.status}: ${JSON.stringify(data)}`);
  }
  return data;
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}
