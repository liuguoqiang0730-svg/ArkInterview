import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const categoriesFile = path.join(rootDir, 'data', 'seed', 'categories.json');
const questionsFile = path.join(rootDir, 'data', 'seed', 'questions.json');

const dryRun = process.argv.includes('--dry-run');
const offlineMissing = process.argv.includes('--offline-missing');
const adminToken = String(process.env.ADMIN_TOKEN || '').trim();
const apiBaseUrl = normalizeApiBaseUrl(process.env.ADMIN_API_URL);

if (adminToken.length < 32) {
  throw new Error('ADMIN_TOKEN must contain at least 32 characters');
}

if (apiBaseUrl.protocol !== 'https:' && !isLoopbackHost(apiBaseUrl.hostname)) {
  console.warn('Warning: ADMIN_API_URL uses HTTP on a non-local host. Configure HTTPS before production use.');
}

const [localCategories, localQuestions, remoteCategoryBody, remoteQuestionBody] = await Promise.all([
  readJson(categoriesFile),
  readJson(questionsFile),
  requestJson('/admin/categories'),
  requestJson('/admin/questions')
]);

const remoteCategories = Array.isArray(remoteCategoryBody.items) ? remoteCategoryBody.items : [];
const remoteQuestions = Array.isArray(remoteQuestionBody.items) ? remoteQuestionBody.items : [];
const categoryChanges = compareById(localCategories, remoteCategories, comparableCategory);
const questionChanges = compareById(localQuestions, remoteQuestions, comparableQuestion);
const questionsToOffline = offlineMissing
  ? questionChanges.remoteOnly.filter((question) => question.status !== 'offline')
  : [];

const summary = {
  apiUrl: apiBaseUrl.toString().replace(/\/$/, ''),
  categoriesAdded: categoryChanges.added.length,
  categoriesUpdated: categoryChanges.updated.length,
  categoriesUnchanged: categoryChanges.unchanged.length,
  remoteOnlyCategoriesPreserved: categoryChanges.remoteOnly.length,
  questionsAdded: questionChanges.added.length,
  questionsUpdated: questionChanges.updated.length,
  questionsUnchanged: questionChanges.unchanged.length,
  questionsMarkedOffline: questionsToOffline.length,
  remoteOnlyQuestionsPreserved: offlineMissing
    ? questionChanges.remoteOnly.length - questionsToOffline.length
    : questionChanges.remoteOnly.length,
  dryRun
};

if (!dryRun) {
  await applyChanges(categoryChanges.added, '/admin/categories', 'POST');
  await applyChanges(categoryChanges.updated, '/admin/categories', 'PATCH');
  await applyChanges(questionChanges.added, '/admin/questions', 'POST');
  await applyChanges(questionChanges.updated, '/admin/questions', 'PATCH');
  for (const question of questionsToOffline) {
    await requestJson(`/admin/questions/${encodeURIComponent(question.id)}`, {
      method: 'PATCH',
      body: {
        status: 'offline'
      }
    });
  }
}

console.log(JSON.stringify(summary, null, 2));

async function applyChanges(items, pathname, method) {
  for (const item of items) {
    const suffix = method === 'PATCH' ? `/${encodeURIComponent(item.id)}` : '';
    await requestJson(`${pathname}${suffix}`, {
      method,
      body: item
    });
  }
}

function compareById(localItems, remoteItems, comparable) {
  const remoteById = new Map(remoteItems.map((item) => [item.id, item]));
  const added = [];
  const updated = [];
  const unchanged = [];

  for (const localItem of localItems) {
    const remoteItem = remoteById.get(localItem.id);
    if (!remoteItem) {
      added.push(localItem);
      continue;
    }

    if (stableJson(comparable(localItem)) === stableJson(comparable(remoteItem))) {
      unchanged.push(localItem);
    } else {
      updated.push(localItem);
    }
    remoteById.delete(localItem.id);
  }

  return {
    added,
    updated,
    unchanged,
    remoteOnly: Array.from(remoteById.values())
  };
}

function comparableCategory(category) {
  return {
    id: String(category.id || ''),
    name: String(category.name || '').trim(),
    order: Number(category.order || 0),
    description: String(category.description || '').trim()
  };
}

function comparableQuestion(question) {
  const type = question.type;
  const isChoice = type === 'single' || type === 'multiple';
  const order = Number(question.order);
  const comparable = {
    id: String(question.id || ''),
    categoryId: String(question.categoryId || ''),
    type,
    difficulty: question.difficulty || 'medium',
    title: String(question.title || '').trim(),
    options: isChoice ? normalizeOptions(question.options) : [],
    correctOptionIds: isChoice ? normalizeStringArray(question.correctOptionIds) : [],
    answerBoolean: type === 'boolean' ? question.answerBoolean : null,
    referenceAnswer: type === 'short' ? String(question.referenceAnswer || '') : '',
    scoringPoints: type === 'short' ? normalizeStringArray(question.scoringPoints) : [],
    explanation: String(question.explanation || ''),
    knowledgePoints: normalizeStringArray(question.knowledgePoints),
    sourceRefs: normalizeSourceRefs(question.sourceRefs),
    verifiedAt: question.verifiedAt || null,
    reviewStatus: question.reviewStatus || 'needs_review',
    status: question.status || 'draft'
  };

  if (Number.isInteger(order) && order >= 0) {
    comparable.order = order;
  }
  return comparable;
}

function normalizeOptions(options) {
  if (!Array.isArray(options)) {
    return [];
  }
  return options.map((option, index) => ({
    id: String(option.id || String.fromCharCode(97 + index)),
    text: String(option.text || '')
  }));
}

function normalizeStringArray(value) {
  return Array.isArray(value) ? value.map((item) => String(item)) : [];
}

function normalizeSourceRefs(sourceRefs) {
  if (!Array.isArray(sourceRefs)) {
    return [];
  }
  return sourceRefs.map((source) => ({
    title: String(source.title || '').trim(),
    url: String(source.url || '').trim(),
    publisher: String(source.publisher || 'Huawei Developer').trim()
  }));
}

function stableJson(value) {
  return JSON.stringify(sortObject(value));
}

function sortObject(value) {
  if (Array.isArray(value)) {
    return value.map(sortObject);
  }
  if (!value || typeof value !== 'object') {
    return value;
  }
  return Object.keys(value)
    .sort()
    .reduce((result, key) => {
      result[key] = sortObject(value[key]);
      return result;
    }, {});
}

function normalizeApiBaseUrl(value) {
  if (!value) {
    throw new Error('ADMIN_API_URL is required, for example https://example.com/api');
  }
  const url = new URL(value);
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    throw new Error('ADMIN_API_URL must use HTTP or HTTPS');
  }
  url.pathname = url.pathname.replace(/\/+$/, '');
  if (!url.pathname.endsWith('/api')) {
    throw new Error('ADMIN_API_URL must end with /api');
  }
  url.search = '';
  url.hash = '';
  return url;
}

function isLoopbackHost(hostname) {
  return hostname === '127.0.0.1' || hostname === 'localhost' || hostname === '::1';
}

async function requestJson(pathname, options = {}) {
  const response = await fetch(new URL(`${apiBaseUrl.pathname}${pathname}`, apiBaseUrl.origin), {
    method: options.method || 'GET',
    headers: {
      Authorization: `Bearer ${adminToken}`,
      ...(options.body ? { 'Content-Type': 'application/json' } : {})
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
    signal: AbortSignal.timeout(20_000)
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`${options.method || 'GET'} ${pathname} failed (${response.status}): ${data.error || 'unknown error'}`);
  }
  return data;
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}
