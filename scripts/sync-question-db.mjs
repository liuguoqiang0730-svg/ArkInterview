import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  openSqliteStore,
  readSqliteSnapshot,
  resolveDatabasePaths
} from '../backend/sqlite-store.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const defaultStorageDir = path.join(rootDir, 'backend', 'storage');
const { dbFile, legacyDbFile } = resolveDatabasePaths(defaultStorageDir);
const categoriesFile = path.join(rootDir, 'data', 'seed', 'categories.json');
const questionsFile = path.join(rootDir, 'data', 'seed', 'questions.json');

const dryRun = process.argv.includes('--dry-run');
const offlineMissing = process.argv.includes('--offline-missing');

const now = new Date().toISOString();
const [seedCategories, seedQuestions] = await Promise.all([
  readJson(categoriesFile),
  readJson(questionsFile)
]);

const db = existsSync(dbFile)
  ? readSqliteSnapshot(dbFile)
  : existsSync(legacyDbFile)
    ? await readJson(legacyDbFile)
    : createEmptyDb();

const summary = {
  dbFile,
  legacyDbFile,
  categoriesAdded: 0,
  categoriesUpdated: 0,
  questionsAdded: 0,
  questionsUpdated: 0,
  questionsUnchanged: 0,
  questionsMarkedOffline: 0,
  usersPreserved: Object.keys(db.users || {}).length,
  dryRun
};

const existingMeta = db.meta || {};
db.meta = {
  name: 'ArkInterview',
  displayName: 'Ark 面试通',
  packageName: 'com.lgq.arkinterview',
  createdAt: existingMeta.createdAt || now,
  updatedAt: now,
  ...existingMeta
};
db.categories = upsertCategories(Array.isArray(db.categories) ? db.categories : [], seedCategories);
db.questions = upsertQuestions(Array.isArray(db.questions) ? db.questions : [], seedQuestions);
db.users = db.users && typeof db.users === 'object' ? db.users : {};
db.meta.updatedAt = now;

if (!dryRun) {
  const { store } = await openSqliteStore({
    dbFile,
    legacyDbFile,
    createInitialData: createEmptyDb
  });
  store.saveCatalog(db);
  store.close();
}

console.log(JSON.stringify(summary, null, 2));

function upsertCategories(currentCategories, nextCategories) {
  const categoryById = new Map(currentCategories.map((category) => [category.id, category]));
  const ordered = [];

  for (const nextCategory of nextCategories) {
    const existing = categoryById.get(nextCategory.id);
    if (!existing) {
      summary.categoriesAdded += 1;
      ordered.push(nextCategory);
      continue;
    }

    const merged = {
      ...existing,
      ...nextCategory
    };
    if (stableJson(existing) !== stableJson(merged)) {
      summary.categoriesUpdated += 1;
    }
    categoryById.delete(nextCategory.id);
    ordered.push(merged);
  }

  return [
    ...ordered,
    ...Array.from(categoryById.values())
  ].sort((left, right) => {
    const leftOrder = typeof left.order === 'number' ? left.order : 9999;
    const rightOrder = typeof right.order === 'number' ? right.order : 9999;
    return leftOrder - rightOrder || String(left.id).localeCompare(String(right.id));
  });
}

function upsertQuestions(currentQuestions, nextQuestions) {
  const questionById = new Map(currentQuestions.map((question) => [question.id, question]));
  const nextIds = new Set(nextQuestions.map((question) => question.id));
  const mergedQuestions = [];

  for (const nextQuestion of nextQuestions) {
    const existing = questionById.get(nextQuestion.id);
    if (!existing) {
      summary.questionsAdded += 1;
      mergedQuestions.push({
        createdAt: now,
        updatedAt: now,
        ...nextQuestion
      });
      continue;
    }

    const merged = {
      ...existing,
      ...nextQuestion,
      createdAt: existing.createdAt || now,
      updatedAt: now
    };

    if (sameQuestionContent(existing, merged)) {
      summary.questionsUnchanged += 1;
      merged.updatedAt = existing.updatedAt || existing.createdAt || now;
    } else {
      summary.questionsUpdated += 1;
    }

    questionById.delete(nextQuestion.id);
    mergedQuestions.push(merged);
  }

  for (const existing of questionById.values()) {
    if (offlineMissing && !nextIds.has(existing.id) && existing.status !== 'offline') {
      summary.questionsMarkedOffline += 1;
      mergedQuestions.push({
        ...existing,
        status: 'offline',
        updatedAt: now
      });
    } else {
      mergedQuestions.push(existing);
    }
  }

  return mergedQuestions.sort(compareQuestions);
}

function sameQuestionContent(left, right) {
  const ignoredFields = new Set(['createdAt', 'updatedAt']);
  return stableJson(stripFields(left, ignoredFields)) === stableJson(stripFields(right, ignoredFields));
}

function stripFields(value, ignoredFields) {
  return Object.fromEntries(
    Object.entries(value).filter(([key]) => !ignoredFields.has(key))
  );
}

function compareQuestions(left, right) {
  const leftOrder = typeof left.order === 'number' ? left.order : 999999;
  const rightOrder = typeof right.order === 'number' ? right.order : 999999;
  return String(left.categoryId).localeCompare(String(right.categoryId))
    || leftOrder - rightOrder
    || String(left.id).localeCompare(String(right.id));
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

function createEmptyDb() {
  return {
    meta: {
      name: 'ArkInterview',
      displayName: 'Ark 面试通',
      packageName: 'com.lgq.arkinterview',
      createdAt: now,
      updatedAt: now
    },
    categories: [],
    questions: [],
    users: {}
  };
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}
