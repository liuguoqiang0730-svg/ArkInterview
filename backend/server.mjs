import http from 'node:http';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash, randomUUID, timingSafeEqual } from 'node:crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const defaultStorageDir = path.join(__dirname, 'storage');
const dbFile = process.env.DB_FILE ? path.resolve(process.env.DB_FILE) : path.join(defaultStorageDir, 'db.json');
const storageDir = path.dirname(dbFile);
const seedCategoriesFile = path.join(rootDir, 'data', 'seed', 'categories.json');
const seedQuestionsFile = path.join(rootDir, 'data', 'seed', 'questions.json');
const adminDir = path.join(rootDir, 'admin');

const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || '0.0.0.0';
const adminToken = String(process.env.ADMIN_TOKEN || '').trim();
const minimumAdminTokenLength = 32;

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}

function nowIso() {
  return new Date().toISOString();
}

async function createSeedDb() {
  const [categories, seedQuestions] = await Promise.all([
    readJson(seedCategoriesFile),
    readJson(seedQuestionsFile)
  ]);
  const now = nowIso();
  const questions = seedQuestions.map((question) => ({
    createdAt: now,
    updatedAt: now,
    ...question
  }));

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

async function ensureDb() {
  await mkdir(storageDir, { recursive: true });
  if (!existsSync(dbFile)) {
    const db = await createSeedDb();
    await writeJson(db);
    return db;
  }
  return readJson(dbFile);
}

async function writeJson(db) {
  db.meta.updatedAt = nowIso();
  await writeFile(dbFile, `${JSON.stringify(db, null, 2)}\n`, 'utf8');
}

function getDeviceId(req) {
  return req.headers['x-device-id'] || 'demo-device';
}

function assertValidServerConfig() {
  if (adminToken && adminToken.length < minimumAdminTokenLength) {
    throw new Error(`ADMIN_TOKEN must contain at least ${minimumAdminTokenLength} characters`);
  }
}

function authorizeAdmin(req) {
  if (!adminToken) {
    throw httpError(503, '管理接口未启用，请先配置 ADMIN_TOKEN');
  }

  const authorization = req.headers.authorization;
  const value = Array.isArray(authorization) ? authorization[0] : authorization;
  const match = typeof value === 'string' ? value.match(/^Bearer\s+(.+)$/i) : null;
  if (!match || !safeSecretEqual(match[1].trim(), adminToken)) {
    throw httpError(401, '管理员令牌无效或缺失');
  }
}

function safeSecretEqual(left, right) {
  const leftDigest = createHash('sha256').update(left).digest();
  const rightDigest = createHash('sha256').update(right).digest();
  return timingSafeEqual(leftDigest, rightDigest);
}

function ensureUser(db, deviceId) {
  if (!db.users[deviceId]) {
    db.users[deviceId] = {
      deviceId,
      favorites: [],
      wrongs: {},
      answers: []
    };
  }
  return db.users[deviceId];
}

function publicQuestion(question, { includeAnswer = false } = {}) {
  const base = {
    id: question.id,
    categoryId: question.categoryId,
    type: question.type,
    difficulty: question.difficulty,
    title: question.title,
    options: question.options,
    explanation: includeAnswer ? question.explanation : undefined,
    knowledgePoints: question.knowledgePoints,
    status: question.status
  };

  if (!includeAnswer) {
    return stripUndefined(base);
  }

  return stripUndefined({
    ...base,
    correctOptionIds: question.correctOptionIds,
    answerBoolean: question.answerBoolean,
    referenceAnswer: question.referenceAnswer,
    scoringPoints: question.scoringPoints,
    sourceRefs: question.sourceRefs,
    verifiedAt: question.verifiedAt,
    reviewStatus: question.reviewStatus,
    createdAt: question.createdAt,
    updatedAt: question.updatedAt
  });
}

function stripUndefined(value) {
  return Object.fromEntries(Object.entries(value).filter(([, item]) => item !== undefined));
}

function paginate(items, page, pageSize) {
  const total = items.length;
  const start = (page - 1) * pageSize;
  return {
    items: items.slice(start, start + pageSize),
    page,
    pageSize,
    total,
    totalPages: Math.max(1, Math.ceil(total / pageSize))
  };
}

function shuffle(items) {
  return [...items].sort(() => Math.random() - 0.5);
}

function sameSet(left = [], right = []) {
  if (left.length !== right.length) {
    return false;
  }
  const rightSet = new Set(right);
  return left.every((item) => rightSet.has(item));
}

function evaluateAnswer(question, payload) {
  if (question.type === 'short') {
    return {
      isCorrect: null,
      referenceAnswer: question.referenceAnswer,
      scoringPoints: question.scoringPoints,
      explanation: question.explanation,
      knowledgePoints: question.knowledgePoints
    };
  }

  if (question.type === 'boolean') {
    const isCorrect = payload.answerBoolean === question.answerBoolean;
    return answerFeedback(question, isCorrect);
  }

  const selectedOptionIds = Array.isArray(payload.selectedOptionIds) ? payload.selectedOptionIds : [];
  const isCorrect = sameSet(selectedOptionIds, question.correctOptionIds);
  return answerFeedback(question, isCorrect);
}

function normalizeQuestionPayload(payload, existing = {}) {
  const now = nowIso();
  const type = payload.type ?? existing.type;
  const orderValue = payload.order ?? existing.order;
  const question = {
    id: existing.id || payload.id || `q-${randomUUID()}`,
    categoryId: payload.categoryId ?? existing.categoryId,
    type,
    difficulty: payload.difficulty ?? existing.difficulty ?? 'medium',
    title: payload.title ?? existing.title,
    options: normalizeOptions(payload.options ?? existing.options ?? []),
    correctOptionIds: payload.correctOptionIds ?? existing.correctOptionIds ?? [],
    answerBoolean: payload.answerBoolean ?? existing.answerBoolean ?? null,
    referenceAnswer: payload.referenceAnswer ?? existing.referenceAnswer ?? '',
    scoringPoints: payload.scoringPoints ?? existing.scoringPoints ?? [],
    explanation: payload.explanation ?? existing.explanation ?? '',
    knowledgePoints: payload.knowledgePoints ?? existing.knowledgePoints ?? [],
    sourceRefs: normalizeSourceRefs(payload.sourceRefs ?? existing.sourceRefs ?? []),
    verifiedAt: payload.verifiedAt ?? existing.verifiedAt ?? null,
    reviewStatus: payload.reviewStatus ?? existing.reviewStatus ?? 'needs_review',
    status: payload.status ?? existing.status ?? 'draft',
    order: orderValue === undefined ? undefined : Number(orderValue),
    createdAt: existing.createdAt || now,
    updatedAt: now
  };

  if (question.type !== 'boolean') {
    question.answerBoolean = null;
  }
  if (question.type !== 'short') {
    question.referenceAnswer = '';
    question.scoringPoints = [];
  }
  if (question.type === 'boolean' || question.type === 'short') {
    question.options = [];
    question.correctOptionIds = [];
  }

  return question;
}

function normalizeSourceRefs(sourceRefs) {
  if (!Array.isArray(sourceRefs)) {
    return [];
  }
  return sourceRefs
    .filter((source) => source && source.title && source.url)
    .map((source) => ({
      title: String(source.title).trim(),
      url: String(source.url).trim(),
      publisher: source.publisher ? String(source.publisher).trim() : 'Huawei Developer'
    }));
}

function normalizeOptions(options) {
  if (!Array.isArray(options)) {
    return [];
  }
  return options
    .filter((option) => option && option.text)
    .map((option, index) => ({
      id: option.id || String.fromCharCode(97 + index),
      text: String(option.text)
    }));
}

function validateQuestion(question, db, { allowExistingId = false } = {}) {
  const types = new Set(['single', 'multiple', 'boolean', 'short']);
  const difficulties = new Set(['easy', 'medium', 'hard']);
  const statuses = new Set(['draft', 'published', 'offline']);
  const reviewStatuses = new Set(['needs_review', 'verified', 'rejected']);

  if (!question.categoryId || !db.categories.some((category) => category.id === question.categoryId)) {
    throw httpError(400, '题目必须关联有效分类');
  }
  if (!question.title || !String(question.title).trim()) {
    throw httpError(400, '题干不能为空');
  }
  if (!types.has(question.type)) {
    throw httpError(400, '题型必须是 single、multiple、boolean 或 short');
  }
  if (!difficulties.has(question.difficulty)) {
    throw httpError(400, '难度必须是 easy、medium 或 hard');
  }
  if (!statuses.has(question.status)) {
    throw httpError(400, '状态必须是 draft、published 或 offline');
  }
  if (!reviewStatuses.has(question.reviewStatus)) {
    throw httpError(400, '审核状态必须是 needs_review、verified 或 rejected');
  }
  if (question.order !== undefined && (!Number.isInteger(question.order) || question.order < 0)) {
    throw httpError(400, '题目顺序必须是非负整数');
  }
  if (!allowExistingId && db.questions.some((item) => item.id === question.id)) {
    throw httpError(409, '题目 ID 已存在');
  }

  if (question.type === 'single') {
    if (question.options.length < 2 || question.correctOptionIds.length !== 1) {
      throw httpError(400, '单选题至少需要 2 个选项和 1 个正确答案');
    }
  }
  if (question.type === 'multiple') {
    if (question.options.length < 2 || question.correctOptionIds.length < 2) {
      throw httpError(400, '多选题至少需要 2 个选项和 2 个正确答案');
    }
  }
  if (question.type === 'single' || question.type === 'multiple') {
    const optionIds = new Set(question.options.map((option) => option.id));
    if (!question.correctOptionIds.every((id) => optionIds.has(id))) {
      throw httpError(400, '正确答案必须来自选项 ID');
    }
  }
  if (question.type === 'boolean' && typeof question.answerBoolean !== 'boolean') {
    throw httpError(400, '判断题必须设置 answerBoolean');
  }
  if (question.type === 'short' && !question.referenceAnswer) {
    throw httpError(400, '简答题必须设置参考答案');
  }
  validateOfficialSources(question);
}

function validateOfficialSources(question) {
  if (question.reviewStatus !== 'verified') {
    throw httpError(400, '题目入库前必须先标记为已核验');
  }
  if (!question.verifiedAt) {
    throw httpError(400, '题目入库前必须填写核验日期');
  }
  if (question.sourceRefs.length === 0) {
    throw httpError(400, '题目入库前必须填写至少一个官方文档来源');
  }

  const invalid = question.sourceRefs.find((source) => !isOfficialSourceUrl(source.url));
  if (invalid) {
    throw httpError(400, `题目来源必须使用官方文档链接：${invalid.url}`);
  }
}

function isOfficialSourceUrl(value) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    const pathname = url.pathname.toLowerCase();
    return host === 'developer.huawei.com'
      || host === 'docs.openharmony.cn'
      || (host === 'gitee.com' && pathname.startsWith('/openharmony/docs'));
  } catch {
    return false;
  }
}

function interviewPlan(db, query) {
  const categoryId = query.get('categoryId');
  const count = Math.min(Math.max(Number(query.get('count') || 8), 1), 30);
  const pool = db.questions
    .filter((question) => question.status === 'published')
    .filter((question) => !categoryId || question.categoryId === categoryId);

  const preferredOrder = ['short', 'single', 'multiple', 'boolean'];
  const selected = [];
  for (const type of preferredOrder) {
    const item = shuffle(pool.filter((question) => question.type === type && !selected.includes(question))).at(0);
    if (item) {
      selected.push(item);
    }
  }

  for (const question of shuffle(pool)) {
    if (selected.length >= count) {
      break;
    }
    if (!selected.some((item) => item.id === question.id)) {
      selected.push(question);
    }
  }

  return {
    sessionId: `interview-${Date.now()}`,
    mode: 'basic',
    total: selected.length,
    items: selected.slice(0, count).map((question, index) => ({
      order: index + 1,
      ...publicQuestion(question)
    }))
  };
}

function practiceSession(db, user, query) {
  const mode = query.get('mode') || 'random';
  const categoryId = query.get('categoryId');
  const type = query.get('type');
  const count = Math.min(Math.max(Number(query.get('count') || 10), 1), 50);
  const publishedQuestions = db.questions
    .filter((question) => question.status === 'published')
    .filter((question) => !type || question.type === type);

  let pool = [];
  if (mode === 'category') {
    if (!categoryId) {
      throw httpError(400, '按分类练习必须传入 categoryId');
    }
    pool = publishedQuestions.filter((question) => question.categoryId === categoryId);
  } else if (mode === 'random') {
    pool = publishedQuestions.filter((question) => !categoryId || question.categoryId === categoryId);
  } else if (mode === 'wrongs') {
    const ids = new Set(Object.values(user.wrongs)
      .filter((wrong) => !wrong.mastered)
      .map((wrong) => wrong.questionId));
    pool = publishedQuestions.filter((question) => ids.has(question.id));
  } else if (mode === 'favorites') {
    const ids = new Set(user.favorites);
    pool = publishedQuestions.filter((question) => ids.has(question.id));
  } else {
    throw httpError(400, '练习模式必须是 category、random、wrongs 或 favorites');
  }

  const selected = shuffle(pool).slice(0, count);
  return {
    sessionId: `practice-${mode}-${Date.now()}`,
    mode,
    categoryId: categoryId || null,
    type: type || null,
    total: selected.length,
    items: selected.map((question, index) => questionForPractice(question, user, index + 1))
  };
}

function questionForPractice(question, user, order) {
  return stripUndefined({
    order,
    ...publicQuestion(question),
    isFavorite: user.favorites.includes(question.id),
    wrong: user.wrongs[question.id] || undefined
  });
}

function questionDetailForUser(question, user) {
  return stripUndefined({
    ...publicQuestion(question, { includeAnswer: true }),
    isFavorite: user.favorites.includes(question.id),
    wrong: user.wrongs[question.id] || undefined
  });
}

function answerFeedback(question, isCorrect) {
  return {
    isCorrect,
    correctOptionIds: question.correctOptionIds,
    answerBoolean: question.answerBoolean,
    explanation: question.explanation,
    knowledgePoints: question.knowledgePoints
  };
}

function statsFor(db, user) {
  const totalAnswers = user.answers.length;
  const gradedAnswers = user.answers.filter((answer) => answer.isCorrect !== null);
  const correctAnswers = gradedAnswers.filter((answer) => answer.isCorrect).length;
  const answeredQuestionCount = new Set(user.answers.map((answer) => answer.questionId)).size;
  const masteredWrongCount = Object.values(user.wrongs).filter((wrong) => wrong.mastered).length;
  const categoryMap = new Map(db.categories.map((category) => [category.id, {
    categoryId: category.id,
    name: category.name,
    attempts: 0,
    answeredQuestionIds: new Set(),
    correct: 0,
    totalPublished: db.questions.filter((question) => question.categoryId === category.id && question.status === 'published').length
  }]));

  for (const answer of user.answers) {
    const item = categoryMap.get(answer.categoryId);
    if (!item) {
      continue;
    }
    item.attempts += 1;
    item.answeredQuestionIds.add(answer.questionId);
    if (answer.isCorrect) {
      item.correct += 1;
    }
  }

  return {
    totalAnswers,
    answeredQuestionCount,
    correctAnswers,
    accuracy: gradedAnswers.length === 0 ? 0 : Number((correctAnswers / gradedAnswers.length).toFixed(4)),
    wrongCount: Object.values(user.wrongs).filter((wrong) => !wrong.mastered).length,
    masteredWrongCount,
    favoriteCount: user.favorites.length,
    lastPracticedAt: user.answers.at(-1)?.submittedAt || null,
    categories: Array.from(categoryMap.values()).map((item) => {
      const answered = item.answeredQuestionIds.size;
      return {
        categoryId: item.categoryId,
        name: item.name,
        attempts: item.attempts,
        answered,
        correct: item.correct,
        totalPublished: item.totalPublished,
        completionRate: item.totalPublished === 0 ? 0 : Number((answered / item.totalPublished).toFixed(4)),
        accuracy: item.attempts === 0 ? 0 : Number((item.correct / item.attempts).toFixed(4))
      };
    })
  };
}

async function parseBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const raw = Buffer.concat(chunks).toString('utf8');
  if (!raw) {
    return {};
  }
  try {
    return JSON.parse(raw);
  } catch {
    throw httpError(400, '请求体必须是合法 JSON');
  }
}

function httpError(status, message) {
  const error = new Error(message);
  error.status = status;
  return error;
}

function sendJson(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type, X-Device-Id',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS'
  });
  res.end(JSON.stringify(data, null, 2));
}

function notFound(res) {
  sendJson(res, 404, { error: 'Not Found' });
}

async function sendStatic(req, res, pathname) {
  let filePath = pathname === '/admin/' || pathname === '/admin'
    ? path.join(adminDir, 'index.html')
    : path.join(adminDir, pathname.replace('/admin/', ''));

  filePath = path.normalize(filePath);
  if (!filePath.startsWith(adminDir)) {
    notFound(res);
    return;
  }

  try {
    const data = await readFile(filePath);
    const ext = path.extname(filePath);
    const type = {
      '.html': 'text/html; charset=utf-8',
      '.js': 'text/javascript; charset=utf-8',
      '.css': 'text/css; charset=utf-8',
      '.json': 'application/json; charset=utf-8'
    }[ext] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type });
    res.end(data);
  } catch {
    notFound(res);
  }
}

async function routeApi(req, res, db, url) {
  const { pathname, searchParams } = url;
  const method = req.method || 'GET';
  const deviceId = getDeviceId(req);
  const user = ensureUser(db, deviceId);

  if (method === 'OPTIONS') {
    sendJson(res, 204, {});
    return;
  }

  if (method === 'GET' && pathname === '/api/categories') {
    sendJson(res, 200, { items: db.categories.sort((a, b) => a.order - b.order) });
    return;
  }

  if (method === 'GET' && pathname === '/api/questions') {
    const categoryId = searchParams.get('categoryId');
    const type = searchParams.get('type');
    const page = Number(searchParams.get('page') || 1);
    const pageSize = Number(searchParams.get('pageSize') || 20);
    const items = db.questions
      .filter((question) => question.status === 'published')
      .filter((question) => !categoryId || question.categoryId === categoryId)
      .filter((question) => !type || question.type === type)
      .map((question) => publicQuestion(question));
    sendJson(res, 200, paginate(items, page, pageSize));
    return;
  }

  if (method === 'GET' && pathname === '/api/interviews/basic') {
    sendJson(res, 200, interviewPlan(db, searchParams));
    return;
  }

  if (method === 'GET' && pathname === '/api/practice/session') {
    sendJson(res, 200, practiceSession(db, user, searchParams));
    return;
  }

  const questionMatch = pathname.match(/^\/api\/questions\/([^/]+)$/);
  if (method === 'GET' && questionMatch) {
    const question = db.questions.find((item) => item.id === questionMatch[1] && item.status === 'published');
    if (!question) {
      notFound(res);
      return;
    }
    sendJson(res, 200, { item: questionDetailForUser(question, user) });
    return;
  }

  if (method === 'POST' && pathname === '/api/answers/submit') {
    const payload = await parseBody(req);
    const question = db.questions.find((item) => item.id === payload.questionId && item.status === 'published');
    if (!question) {
      throw httpError(404, '题目不存在或未发布');
    }

    const feedback = evaluateAnswer(question, payload);
    const submittedAt = nowIso();
    user.answers.push({
      questionId: question.id,
      categoryId: question.categoryId,
      type: question.type,
      isCorrect: feedback.isCorrect,
      submittedAt
    });

    if (feedback.isCorrect === false) {
      const existing = user.wrongs[question.id];
      user.wrongs[question.id] = {
        questionId: question.id,
        wrongCount: existing ? existing.wrongCount + 1 : 1,
        mastered: false,
        updatedAt: submittedAt
      };
    }

    await writeJson(db);
    sendJson(res, 200, {
      questionId: question.id,
      ...feedback,
      stats: statsFor(db, user)
    });
    return;
  }

  if (method === 'GET' && pathname === '/api/users/me/stats') {
    sendJson(res, 200, statsFor(db, user));
    return;
  }

  if (method === 'GET' && pathname === '/api/users/me/wrongs') {
    const ids = new Set(Object.values(user.wrongs).filter((wrong) => !wrong.mastered).map((wrong) => wrong.questionId));
    const items = db.questions
      .filter((question) => ids.has(question.id))
      .map((question) => ({
        ...publicQuestion(question, { includeAnswer: true }),
        wrong: user.wrongs[question.id]
      }));
    sendJson(res, 200, { items });
    return;
  }

  const masteredMatch = pathname.match(/^\/api\/users\/me\/wrongs\/([^/]+)\/mastered$/);
  if (method === 'POST' && masteredMatch) {
    const wrong = user.wrongs[masteredMatch[1]];
    if (!wrong) {
      throw httpError(404, '错题不存在');
    }
    wrong.mastered = true;
    wrong.updatedAt = nowIso();
    await writeJson(db);
    sendJson(res, 200, { item: wrong });
    return;
  }

  if (method === 'GET' && pathname === '/api/users/me/favorites') {
    const ids = new Set(user.favorites);
    const items = db.questions
      .filter((question) => ids.has(question.id))
      .map((question) => publicQuestion(question, { includeAnswer: true }));
    sendJson(res, 200, { items });
    return;
  }

  if (method === 'POST' && pathname === '/api/users/me/favorites') {
    const payload = await parseBody(req);
    const question = db.questions.find((item) => item.id === payload.questionId && item.status === 'published');
    if (!question) {
      throw httpError(404, '题目不存在或未发布');
    }
    if (!user.favorites.includes(question.id)) {
      user.favorites.push(question.id);
    }
    await writeJson(db);
    sendJson(res, 201, { items: user.favorites });
    return;
  }

  const favoriteMatch = pathname.match(/^\/api\/users\/me\/favorites\/([^/]+)$/);
  if (method === 'DELETE' && favoriteMatch) {
    user.favorites = user.favorites.filter((id) => id !== favoriteMatch[1]);
    await writeJson(db);
    sendJson(res, 200, { items: user.favorites });
    return;
  }

  if (pathname.startsWith('/api/admin/')) {
    await routeAdmin(req, res, db, url);
    return;
  }

  notFound(res);
}

async function routeAdmin(req, res, db, url) {
  const { pathname } = url;
  const method = req.method || 'GET';
  authorizeAdmin(req);

  if (method === 'GET' && pathname === '/api/admin/categories') {
    sendJson(res, 200, { items: db.categories.sort((a, b) => a.order - b.order) });
    return;
  }

  if (method === 'POST' && pathname === '/api/admin/categories') {
    const payload = await parseBody(req);
    const item = normalizeCategoryPayload(payload, {}, db.categories.length + 1);
    validateCategory(item);
    if (db.categories.some((category) => category.id === item.id)) {
      throw httpError(409, '分类 ID 已存在');
    }
    db.categories.push(item);
    await writeJson(db);
    sendJson(res, 201, { item });
    return;
  }

  const adminCategoryMatch = pathname.match(/^\/api\/admin\/categories\/([^/]+)$/);
  if (method === 'PATCH' && adminCategoryMatch) {
    const category = db.categories.find((item) => item.id === adminCategoryMatch[1]);
    if (!category) {
      notFound(res);
      return;
    }
    const payload = await parseBody(req);
    const updated = normalizeCategoryPayload(payload, category, category.order);
    validateCategory(updated);
    Object.assign(category, updated, { id: category.id });
    await writeJson(db);
    sendJson(res, 200, { item: category });
    return;
  }

  if (method === 'GET' && pathname === '/api/admin/questions') {
    sendJson(res, 200, { items: db.questions });
    return;
  }

  if (method === 'POST' && pathname === '/api/admin/questions') {
    const payload = await parseBody(req);
    const item = normalizeQuestionPayload(payload);
    validateQuestion(item, db);
    db.questions.push(item);
    await writeJson(db);
    sendJson(res, 201, { item });
    return;
  }

  if (method === 'PATCH' && pathname === '/api/admin/questions/batch-status') {
    const payload = await parseBody(req);
    const requestedIds = Array.isArray(payload.questionIds) ? payload.questionIds : [];
    const questionIds = [...new Set(requestedIds.map((id) => String(id).trim()).filter(Boolean))];
    const status = payload.status;
    if (questionIds.length === 0 || questionIds.length > 500) {
      throw httpError(400, '批量操作必须包含 1 至 500 个题目 ID');
    }
    if (status !== 'published' && status !== 'offline') {
      throw httpError(400, '批量状态只能是 published 或 offline');
    }

    const questions = questionIds.map((id) => db.questions.find((question) => question.id === id));
    const missingIndex = questions.findIndex((question) => !question);
    if (missingIndex >= 0) {
      throw httpError(404, `题目不存在：${questionIds[missingIndex]}`);
    }

    const updates = questions.map((question) => normalizeQuestionPayload({ status }, question));
    for (const updated of updates) {
      validateQuestion(updated, db, { allowExistingId: true });
    }
    for (let index = 0; index < questions.length; index += 1) {
      Object.assign(questions[index], updates[index], { id: questions[index].id });
    }
    await writeJson(db);
    sendJson(res, 200, { items: questions });
    return;
  }

  const adminQuestionMatch = pathname.match(/^\/api\/admin\/questions\/([^/]+)$/);
  if (method === 'PATCH' && adminQuestionMatch) {
    const question = db.questions.find((item) => item.id === adminQuestionMatch[1]);
    if (!question) {
      notFound(res);
      return;
    }
    const payload = await parseBody(req);
    const updated = normalizeQuestionPayload(payload, question);
    validateQuestion(updated, db, { allowExistingId: true });
    Object.assign(question, updated, { id: question.id });
    await writeJson(db);
    sendJson(res, 200, { item: question });
    return;
  }

  notFound(res);
}

function normalizeCategoryPayload(payload, existing = {}, defaultOrder = 1) {
  const name = payload.name ?? existing.name;
  return {
    id: existing.id || payload.id || slugify(name || ''),
    name: typeof name === 'string' ? name.trim() : '',
    order: Number(payload.order ?? existing.order ?? defaultOrder),
    description: String(payload.description ?? existing.description ?? '').trim()
  };
}

function validateCategory(category) {
  if (!category.id || !category.name) {
    throw httpError(400, '分类 ID 和名称不能为空');
  }
  if (!Number.isInteger(category.order) || category.order < 0) {
    throw httpError(400, '分类顺序必须是非负整数');
  }
}

function slugify(input) {
  return String(input)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '-')
    .replace(/^-+|-+$/g, '') || `category-${Date.now()}`;
}

async function main() {
  assertValidServerConfig();
  const db = await ensureDb();
  if (process.argv.includes('--seed-only')) {
    await writeJson(await createSeedDb());
    console.log(`Seeded ${dbFile}`);
    return;
  }

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url || '/', `http://${req.headers.host || `127.0.0.1:${port}`}`);
    try {
      if (url.pathname.startsWith('/admin')) {
        await sendStatic(req, res, url.pathname);
        return;
      }
      if (url.pathname.startsWith('/api/')) {
        await routeApi(req, res, db, url);
        return;
      }
      if (url.pathname === '/') {
        res.writeHead(302, { Location: '/admin/' });
        res.end();
        return;
      }
      notFound(res);
    } catch (error) {
      const status = error.status || 500;
      if (status === 401) {
        res.setHeader('WWW-Authenticate', 'Bearer realm="ArkInterview Admin"');
      }
      sendJson(res, status, {
        error: error.message || 'Internal Server Error'
      });
    }
  });

  server.listen(port, host, () => {
    const localHost = host === '0.0.0.0' ? '127.0.0.1' : host;
    console.log(`ArkInterview API running at http://${localHost}:${port}`);
    console.log(`Admin console running at http://${localHost}:${port}/admin/`);
    console.log(adminToken
      ? 'Admin API authentication enabled.'
      : 'Admin API disabled: configure ADMIN_TOKEN to enable management access.');
    if (host === '0.0.0.0') {
      console.log(`LAN access enabled. Use http://<your-computer-ip>:${port}/api from a device.`);
    }
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
