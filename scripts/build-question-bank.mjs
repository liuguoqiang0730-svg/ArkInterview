import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const manifestFile = path.join(rootDir, 'data', 'question-bank', 'manifest.json');
const categoriesFile = path.join(rootDir, 'data', 'seed', 'categories.json');
const seedQuestionsFile = path.join(rootDir, 'data', 'seed', 'questions.json');
const checkOnly = process.argv.includes('--check');

const allowedTypes = new Set(['single', 'multiple', 'boolean', 'short']);
const allowedDifficulties = new Set(['easy', 'medium', 'hard']);
const allowedStatuses = new Set(['draft', 'published', 'offline']);
const forbiddenSelfReferentialScenario =
  /刷题|题库|ArkInterview|Ark 面试通|答题|错题|练习|题单|questionId|questionIds|收藏/i;

const [manifest, categories] = await Promise.all([
  readJson(manifestFile),
  readJson(categoriesFile)
]);

const categoryById = new Map(categories.map((category) => [category.id, category]));
const categoryOrder = new Map(categories.map((category) => [category.id, category.order]));
const errors = [];
const entries = [];

if (!Array.isArray(manifest.modules)) {
  errors.push('data/question-bank/manifest.json 必须包含 modules 数组');
} else {
  for (const moduleConfig of manifest.modules) {
    await loadModule(moduleConfig);
  }
}

validateGlobalDuplicates(entries);

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  throw new Error(`Question bank validation failed with ${errors.length} error(s).`);
}

const questions = entries
  .map((entry) => entry.question)
  .sort(compareQuestions);
const output = `${JSON.stringify(questions, null, 2)}\n`;

if (checkOnly) {
  const current = await readFile(seedQuestionsFile, 'utf8');
  if (current !== output) {
    throw new Error('data/seed/questions.json 不是最新聚合结果，请先运行 npm run questions:build');
  }
} else {
  await writeFile(seedQuestionsFile, output, 'utf8');
}

console.log(`Question modules: ${manifest.modules.length}`);
console.log(`Questions built: ${questions.length}`);
console.log(`Published questions: ${questions.filter((question) => question.status === 'published').length}`);

async function loadModule(moduleConfig) {
  if (!moduleConfig || !moduleConfig.categoryId || !moduleConfig.sourceFile) {
    errors.push('manifest.modules 中每一项都必须包含 categoryId 和 sourceFile');
    return;
  }

  if (!categoryById.has(moduleConfig.categoryId)) {
    errors.push(`manifest 模块 ${moduleConfig.categoryId} 没有关联有效分类`);
  }

  const sourcePath = path.join(rootDir, 'data', 'question-bank', moduleConfig.sourceFile);
  let questions;
  try {
    questions = await readJson(sourcePath);
  } catch (error) {
    errors.push(`无法读取模块 ${moduleConfig.categoryId}: ${error.message}`);
    return;
  }

  if (!Array.isArray(questions)) {
    errors.push(`${moduleConfig.sourceFile} 必须是题目数组`);
    return;
  }

  questions.forEach((question, index) => {
    const location = `${moduleConfig.sourceFile}[${index}]`;
    validateQuestion(question, moduleConfig, location);
    entries.push({
      question,
      moduleConfig,
      location
    });
  });
}

function validateQuestion(question, moduleConfig, location) {
  if (!question || typeof question !== 'object') {
    errors.push(`${location}: 题目必须是对象`);
    return;
  }

  if (!question.id || typeof question.id !== 'string') {
    errors.push(`${location}: 题目必须有字符串 id`);
  } else {
    const prefix = `${moduleConfig.idPrefix || moduleConfig.categoryId}-`;
    if (!question.id.startsWith(prefix)) {
      errors.push(`${location}: 题目 ID 必须以 ${prefix} 开头`);
    }
  }

  if (question.categoryId !== moduleConfig.categoryId) {
    errors.push(`${location}: categoryId 必须是 ${moduleConfig.categoryId}`);
  }
  if (!categoryById.has(question.categoryId)) {
    errors.push(`${location}: categoryId 无效`);
  }
  if (!question.title || !String(question.title).trim()) {
    errors.push(`${location}: 题干不能为空`);
  }
  if (!allowedTypes.has(question.type)) {
    errors.push(`${location}: type 必须是 single、multiple、boolean 或 short`);
  }
  if (!allowedDifficulties.has(question.difficulty)) {
    errors.push(`${location}: difficulty 必须是 easy、medium 或 hard`);
  }
  if (!allowedStatuses.has(question.status)) {
    errors.push(`${location}: status 必须是 draft、published 或 offline`);
  }
  if (question.reviewStatus !== 'verified') {
    errors.push(`${location}: reviewStatus 必须是 verified`);
  }
  if (!isIsoDate(question.verifiedAt)) {
    errors.push(`${location}: verifiedAt 必须是 YYYY-MM-DD`);
  }
  if (!Array.isArray(question.knowledgePoints) || question.knowledgePoints.length === 0) {
    errors.push(`${location}: knowledgePoints 至少需要 1 项`);
  }
  if (!question.explanation || !String(question.explanation).trim()) {
    errors.push(`${location}: explanation 不能为空`);
  }

  const selfReferentialMatch = JSON.stringify(question).match(forbiddenSelfReferentialScenario);
  if (selfReferentialMatch) {
    errors.push(
      `${location}: question content must use a real external business scenario, not ArkInterview domain term "${selfReferentialMatch[0]}"`
    );
  }

  validateSources(question, location);
  validateAnswer(question, location);
}

function validateSources(question, location) {
  if (!Array.isArray(question.sourceRefs) || question.sourceRefs.length === 0) {
    errors.push(`${location}: sourceRefs 至少需要 1 个官方来源`);
    return;
  }

  question.sourceRefs.forEach((source, index) => {
    const sourceLocation = `${location}.sourceRefs[${index}]`;
    if (!source || !source.title || !source.url) {
      errors.push(`${sourceLocation}: 必须包含 title 和 url`);
      return;
    }
    if (!isOfficialSourceUrl(source.url)) {
      errors.push(`${sourceLocation}: 必须是官方文档链接：${source.url}`);
    }
  });
}

function validateAnswer(question, location) {
  if (question.type === 'single' || question.type === 'multiple') {
    if (!Array.isArray(question.options) || question.options.length < 2) {
      errors.push(`${location}: 选择题至少需要 2 个选项`);
      return;
    }
    if (!Array.isArray(question.correctOptionIds)) {
      errors.push(`${location}: 选择题必须有 correctOptionIds`);
      return;
    }

    const optionIds = new Set();
    const optionTexts = new Set();
    for (const option of question.options) {
      if (!option.id || !option.text) {
        errors.push(`${location}: 每个选项都必须包含 id 和 text`);
        continue;
      }
      if (optionIds.has(option.id)) {
        errors.push(`${location}: 选项 ID 重复：${option.id}`);
      }
      optionIds.add(option.id);

      const normalizedText = normalizeTitle(option.text);
      if (optionTexts.has(normalizedText)) {
        errors.push(`${location}: 选项文案重复：${option.text}`);
      }
      optionTexts.add(normalizedText);
    }

    if (question.type === 'single' && question.correctOptionIds.length !== 1) {
      errors.push(`${location}: 单选题必须只有 1 个正确选项`);
    }
    if (question.type === 'multiple' && question.correctOptionIds.length < 2) {
      errors.push(`${location}: 多选题至少需要 2 个正确选项`);
    }
    for (const id of question.correctOptionIds) {
      if (!optionIds.has(id)) {
        errors.push(`${location}: 正确答案 ${id} 不在选项中`);
      }
    }
  }

  if (question.type === 'boolean' && typeof question.answerBoolean !== 'boolean') {
    errors.push(`${location}: 判断题必须设置 boolean 类型 answerBoolean`);
  }

  if (question.type === 'short') {
    if (!question.referenceAnswer || !String(question.referenceAnswer).trim()) {
      errors.push(`${location}: 简答题必须有 referenceAnswer`);
    }
    if (!Array.isArray(question.scoringPoints) || question.scoringPoints.length === 0) {
      errors.push(`${location}: 简答题必须有 scoringPoints`);
    }
  }
}

function validateGlobalDuplicates(items) {
  const ids = new Map();
  const titles = new Map();

  for (const item of items) {
    const { question, location } = item;
    if (question.id) {
      if (ids.has(question.id)) {
        errors.push(`${location}: 题目 ID 与 ${ids.get(question.id)} 重复：${question.id}`);
      } else {
        ids.set(question.id, location);
      }
    }

    const normalizedTitle = normalizeTitle(question.title || '');
    if (normalizedTitle) {
      if (titles.has(normalizedTitle)) {
        errors.push(`${location}: 题干与 ${titles.get(normalizedTitle)} 重复：${question.title}`);
      } else {
        titles.set(normalizedTitle, location);
      }
    }
  }
}

function compareQuestions(left, right) {
  const leftCategory = categoryOrder.get(left.categoryId) || 9999;
  const rightCategory = categoryOrder.get(right.categoryId) || 9999;
  if (leftCategory !== rightCategory) {
    return leftCategory - rightCategory;
  }

  const leftOrder = typeof left.order === 'number' ? left.order : 999999;
  const rightOrder = typeof right.order === 'number' ? right.order : 999999;
  if (leftOrder !== rightOrder) {
    return leftOrder - rightOrder;
  }

  return String(left.id).localeCompare(String(right.id));
}

function normalizeTitle(value) {
  return String(value)
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\s\p{P}\p{S}]+/gu, '');
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

function isIsoDate(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

async function readJson(file) {
  return JSON.parse(await readFile(file, 'utf8'));
}
