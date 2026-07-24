const state = {
  categories: [],
  questions: [],
  activeCategoryId: '',
  activeType: '',
  activeReviewStatus: '',
  activePublishStatus: '',
  selectedQuestionIds: new Set(),
  batchPending: false,
  adminToken: sessionStorage.getItem('arkinterview.adminToken') || ''
};

const els = {
  authView: document.querySelector('#authView'),
  adminView: document.querySelector('#adminView'),
  authForm: document.querySelector('#authForm'),
  adminTokenInput: document.querySelector('#adminTokenInput'),
  authMessage: document.querySelector('#authMessage'),
  categoryCount: document.querySelector('#categoryCount'),
  questionCount: document.querySelector('#questionCount'),
  publishedCount: document.querySelector('#publishedCount'),
  draftCount: document.querySelector('#draftCount'),
  categoryList: document.querySelector('#categoryList'),
  questionList: document.querySelector('#questionList'),
  typeFilter: document.querySelector('#typeFilter'),
  reviewStatusFilter: document.querySelector('#reviewStatusFilter'),
  publishStatusFilter: document.querySelector('#publishStatusFilter'),
  visibleQuestionCount: document.querySelector('#visibleQuestionCount'),
  batchToolbar: document.querySelector('#batchToolbar'),
  selectVisibleQuestions: document.querySelector('#selectVisibleQuestions'),
  selectedQuestionCount: document.querySelector('#selectedQuestionCount'),
  batchPublishButton: document.querySelector('#batchPublishButton'),
  batchOfflineButton: document.querySelector('#batchOfflineButton'),
  clearSelectionButton: document.querySelector('#clearSelectionButton'),
  refreshButton: document.querySelector('#refreshButton'),
  logoutButton: document.querySelector('#logoutButton'),
  questionForm: document.querySelector('#questionForm'),
  categoryInput: document.querySelector('#categoryInput'),
  questionTypeInput: document.querySelector('#questionTypeInput'),
  formMessage: document.querySelector('#formMessage')
};

const typeLabels = {
  single: '单选题',
  multiple: '多选题',
  boolean: '判断题',
  short: '简答题'
};

const difficultyLabels = {
  easy: '简单',
  medium: '中等',
  hard: '困难'
};

const statusLabels = {
  draft: '草稿',
  published: '已发布',
  offline: '已下架'
};

const reviewStatusLabels = {
  needs_review: '待核验',
  verified: '已核验',
  rejected: '已驳回'
};

async function request(path, options = {}) {
  const headers = {
    'Content-Type': 'application/json',
    ...(state.adminToken ? { Authorization: `Bearer ${state.adminToken}` } : {}),
    ...(options.headers || {})
  };
  const response = await fetch(path, {
    ...options,
    headers
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    if (response.status === 401 || response.status === 503) {
      lockAdmin(data.error || '管理员验证已失效');
    }
    throw new Error(data.error || `请求失败：${response.status}`);
  }
  return data;
}

function showAdmin() {
  els.authView.hidden = true;
  els.adminView.hidden = false;
  els.refreshButton.hidden = false;
  els.logoutButton.hidden = false;
  els.authMessage.textContent = '';
  els.adminTokenInput.value = '';
}

function lockAdmin(message = '') {
  state.adminToken = '';
  state.categories = [];
  state.questions = [];
  state.selectedQuestionIds.clear();
  sessionStorage.removeItem('arkinterview.adminToken');
  els.authView.hidden = false;
  els.adminView.hidden = true;
  els.refreshButton.hidden = true;
  els.logoutButton.hidden = true;
  els.authMessage.textContent = message;
  els.adminTokenInput.focus();
}

async function unlockAdmin(token) {
  state.adminToken = token.trim();
  await loadData();
  sessionStorage.setItem('arkinterview.adminToken', state.adminToken);
  showAdmin();
}

async function loadData() {
  const [categories, questions] = await Promise.all([
    request('/api/admin/categories'),
    request('/api/admin/questions')
  ]);
  state.categories = categories.items;
  state.questions = questions.items;
  state.selectedQuestionIds = new Set(
    [...state.selectedQuestionIds].filter((id) => state.questions.some((question) => question.id === id))
  );
  render();
}

function render() {
  renderStats();
  renderCategoryInput();
  renderCategories();
  renderQuestions();
  syncQuestionTypeFields();
}

function renderStats() {
  const published = state.questions.filter((item) => item.status === 'published').length;
  const draft = state.questions.filter((item) => item.status === 'draft').length;
  els.categoryCount.textContent = String(state.categories.length);
  els.questionCount.textContent = String(state.questions.length);
  els.publishedCount.textContent = String(published);
  els.draftCount.textContent = String(draft);
}

function renderCategoryInput() {
  const selected = els.categoryInput.value;
  els.categoryInput.replaceChildren(...state.categories.map((category) => {
    const option = document.createElement('option');
    option.value = category.id;
    option.textContent = category.name;
    return option;
  }));
  if (selected && state.categories.some((category) => category.id === selected)) {
    els.categoryInput.value = selected;
  }
}

function renderCategories() {
  const allButton = categoryButton({
    id: '',
    name: '全部分类',
    description: '查看所有已录入题目'
  });
  els.categoryList.replaceChildren(allButton, ...state.categories.map(categoryButton));
}

function categoryButton(category) {
  const button = document.createElement('button');
  button.className = `category-item${state.activeCategoryId === category.id ? ' active' : ''}`;
  button.type = 'button';
  button.innerHTML = `
    <span class="category-title">${escapeHtml(category.name)}</span>
    <span class="category-desc">${escapeHtml(category.description || '')}</span>
  `;
  button.addEventListener('click', () => {
    state.activeCategoryId = category.id;
    render();
  });
  return button;
}

function renderQuestions() {
  const items = visibleQuestions();
  els.visibleQuestionCount.textContent = `${items.length} 条`;
  updateBatchToolbar(items);

  if (items.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = '当前筛选条件下没有题目。';
    els.questionList.replaceChildren(empty);
    return;
  }

  els.questionList.replaceChildren(...items.map(questionItem));
}

function visibleQuestions() {
  return state.questions
    .filter((question) => !state.activeCategoryId || question.categoryId === state.activeCategoryId)
    .filter((question) => !state.activeType || question.type === state.activeType)
    .filter((question) => !state.activeReviewStatus || question.reviewStatus === state.activeReviewStatus)
    .filter((question) => !state.activePublishStatus || question.status === state.activePublishStatus);
}

function questionItem(question) {
  const article = document.createElement('article');
  const category = state.categories.find((item) => item.id === question.categoryId);
  const selected = state.selectedQuestionIds.has(question.id);
  article.className = `question-item${selected ? ' selected' : ''}`;
  article.innerHTML = `
    <div class="question-topline">
      <input
        class="question-selector"
        type="checkbox"
        data-action="select"
        aria-label="选择题目：${escapeHtml(question.title)}"
        ${selected ? 'checked' : ''}
      >
      <div class="question-copy">
        <span class="question-title">${escapeHtml(question.title)}</span>
        <p class="question-meta">${escapeHtml(category?.name || question.categoryId)} · ${typeLabels[question.type] || question.type} · ${difficultyLabels[question.difficulty] || question.difficulty}</p>
      </div>
      <div class="question-controls">
        ${selectHtml('difficulty', question.difficulty, difficultyLabels)}
        ${selectHtml('status', question.status, statusLabels)}
        <button class="small-button" type="button" data-action="save">保存</button>
      </div>
    </div>
    <div class="badges">
      <span class="badge ${question.status}">${statusLabels[question.status] || question.status}</span>
      <span class="badge review-${question.reviewStatus || 'needs_review'}">${reviewStatusLabels[question.reviewStatus] || '待核验'}</span>
      <span class="badge">官方来源 ${(question.sourceRefs || []).length}</span>
      ${(question.knowledgePoints || []).map((point) => `<span class="badge">${escapeHtml(point)}</span>`).join('')}
    </div>
  `;
  article.querySelector('[data-action="select"]').addEventListener('change', (event) => {
    if (event.target.checked) {
      state.selectedQuestionIds.add(question.id);
    } else {
      state.selectedQuestionIds.delete(question.id);
    }
    article.classList.toggle('selected', event.target.checked);
    updateBatchToolbar();
  });
  article.querySelector('[data-action="save"]').addEventListener('click', () => saveQuestionPatch(question.id, article));
  return article;
}

function updateBatchToolbar(items = visibleQuestions()) {
  const selectedCount = state.selectedQuestionIds.size;
  const visibleIds = items.map((question) => question.id);
  const selectedVisibleCount = visibleIds.filter((id) => state.selectedQuestionIds.has(id)).length;
  els.selectedQuestionCount.textContent = String(selectedCount);
  els.selectVisibleQuestions.checked = visibleIds.length > 0 && selectedVisibleCount === visibleIds.length;
  els.selectVisibleQuestions.indeterminate = selectedVisibleCount > 0 && selectedVisibleCount < visibleIds.length;
  els.selectVisibleQuestions.disabled = state.batchPending || visibleIds.length === 0;
  els.batchPublishButton.disabled = state.batchPending || selectedCount === 0;
  els.batchOfflineButton.disabled = state.batchPending || selectedCount === 0;
  els.clearSelectionButton.disabled = state.batchPending || selectedCount === 0;
}

async function batchUpdateStatus(status) {
  const questionIds = [...state.selectedQuestionIds];
  if (questionIds.length === 0) {
    return;
  }

  const actionLabel = status === 'published' ? '发布' : '下架';
  const confirmed = window.confirm(`确定要${actionLabel}已选择的 ${questionIds.length} 道题吗？`);
  if (!confirmed) {
    return;
  }

  setBatchPending(true);
  setFormMessage(`正在批量${actionLabel}...`);
  try {
    const result = await request('/api/admin/questions/batch-status', {
      method: 'PATCH',
      body: JSON.stringify({ questionIds, status })
    });
    const updatedById = new Map(result.items.map((question) => [question.id, question]));
    state.questions = state.questions.map((question) => updatedById.get(question.id) || question);
    state.selectedQuestionIds.clear();
    setFormMessage(`已${actionLabel} ${result.items.length} 道题`);
    render();
  } catch (error) {
    setFormMessage(error.message, true);
  } finally {
    setBatchPending(false);
  }
}

function setBatchPending(pending) {
  state.batchPending = pending;
  updateBatchToolbar();
}

function selectHtml(name, current, labels) {
  const options = Object.entries(labels).map(([value, label]) => {
    const selected = value === current ? ' selected' : '';
    return `<option value="${value}"${selected}>${label}</option>`;
  });
  return `<select name="${name}" aria-label="${labels[current] || name}">${options.join('')}</select>`;
}

async function saveQuestionPatch(questionId, article) {
  const difficulty = article.querySelector('select[name="difficulty"]').value;
  const status = article.querySelector('select[name="status"]').value;
  const button = article.querySelector('[data-action="save"]');
  button.disabled = true;
  try {
    const result = await request(`/api/admin/questions/${questionId}`, {
      method: 'PATCH',
      body: JSON.stringify({ difficulty, status })
    });
    const index = state.questions.findIndex((item) => item.id === questionId);
    if (index >= 0) {
      state.questions[index] = result.item;
    }
    setFormMessage('题目已更新');
    render();
  } catch (error) {
    setFormMessage(error.message, true);
  } finally {
    button.disabled = false;
  }
}

function syncQuestionTypeFields() {
  const type = els.questionTypeInput.value;
  const choiceFields = document.querySelectorAll('.choice-field');
  const booleanFields = document.querySelectorAll('.boolean-field');
  const shortFields = document.querySelectorAll('.short-field');

  choiceFields.forEach((item) => {
    item.hidden = type !== 'single' && type !== 'multiple';
  });
  booleanFields.forEach((item) => {
    item.hidden = type !== 'boolean';
  });
  shortFields.forEach((item) => {
    item.hidden = type !== 'short';
  });
}

function parseQuestionForm(form) {
  const data = new FormData(form);
  const type = data.get('type');
  const payload = {
    categoryId: data.get('categoryId'),
    type,
    difficulty: data.get('difficulty'),
    status: data.get('status'),
    title: String(data.get('title') || '').trim(),
    explanation: String(data.get('explanation') || '').trim(),
    knowledgePoints: splitList(data.get('knowledgePointsText')),
    sourceRefs: parseSourceRefs(data.get('sourceRefsText')),
    verifiedAt: data.get('verifiedAt') || null,
    reviewStatus: data.get('reviewStatus')
  };

  if (type === 'single' || type === 'multiple') {
    payload.options = parseOptions(data.get('optionsText'));
    payload.correctOptionIds = splitList(data.get('correctOptionIds')).map((item) => item.toLowerCase());
  }

  if (type === 'boolean') {
    payload.answerBoolean = data.get('answerBoolean') === 'true';
  }

  if (type === 'short') {
    payload.referenceAnswer = String(data.get('referenceAnswer') || '').trim();
    payload.scoringPoints = splitLines(data.get('scoringPointsText'));
  }

  return payload;
}

function parseOptions(value) {
  return splitLines(value).map((line, index) => {
    const match = line.match(/^([a-zA-Z])[\s.、:：-]+(.+)$/);
    if (match) {
      return {
        id: match[1].toLowerCase(),
        text: match[2].trim()
      };
    }
    return {
      id: String.fromCharCode(97 + index),
      text: line
    };
  });
}

function splitList(value) {
  return String(value || '')
    .split(/[,，]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function splitLines(value) {
  return String(value || '')
    .split(/\r?\n/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function parseSourceRefs(value) {
  return splitLines(value).map((line) => {
    const parts = line.split('|').map((item) => item.trim());
    if (parts.length >= 2) {
      return {
        title: parts[0],
        url: parts[1],
        publisher: parts[2] || 'Huawei Developer'
      };
    }
    return {
      title: line,
      url: line,
      publisher: 'Huawei Developer'
    };
  });
}

function setFormMessage(message, isError = false) {
  els.formMessage.textContent = message;
  els.formMessage.classList.toggle('error', isError);
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

els.typeFilter.addEventListener('change', (event) => {
  state.activeType = event.target.value;
  renderQuestions();
});

els.reviewStatusFilter.addEventListener('change', (event) => {
  state.activeReviewStatus = event.target.value;
  renderQuestions();
});

els.publishStatusFilter.addEventListener('change', (event) => {
  state.activePublishStatus = event.target.value;
  renderQuestions();
});

els.selectVisibleQuestions.addEventListener('change', (event) => {
  for (const question of visibleQuestions()) {
    if (event.target.checked) {
      state.selectedQuestionIds.add(question.id);
    } else {
      state.selectedQuestionIds.delete(question.id);
    }
  }
  renderQuestions();
});

els.batchPublishButton.addEventListener('click', () => batchUpdateStatus('published'));
els.batchOfflineButton.addEventListener('click', () => batchUpdateStatus('offline'));
els.clearSelectionButton.addEventListener('click', () => {
  state.selectedQuestionIds.clear();
  renderQuestions();
});

els.questionTypeInput.addEventListener('change', syncQuestionTypeFields);

els.questionForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = els.questionForm.querySelector('button[type="submit"]');
  button.disabled = true;
  setFormMessage('保存中...');
  try {
    const payload = parseQuestionForm(els.questionForm);
    const result = await request('/api/admin/questions', {
      method: 'POST',
      body: JSON.stringify(payload)
    });
    state.questions.unshift(result.item);
    els.questionForm.reset();
    setFormMessage('题目已保存');
    render();
  } catch (error) {
    setFormMessage(error.message, true);
  } finally {
    button.disabled = false;
  }
});

els.questionForm.addEventListener('reset', () => {
  window.setTimeout(() => {
    setFormMessage('');
    syncQuestionTypeFields();
  });
});

els.authForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const button = els.authForm.querySelector('button[type="submit"]');
  const token = els.adminTokenInput.value.trim();
  button.disabled = true;
  els.authMessage.textContent = '验证中...';
  try {
    await unlockAdmin(token);
  } catch (error) {
    lockAdmin(error.message);
  } finally {
    button.disabled = false;
  }
});

els.logoutButton.addEventListener('click', () => {
  lockAdmin();
});

els.refreshButton.addEventListener('click', async () => {
  els.refreshButton.disabled = true;
  try {
    await loadData();
  } catch (error) {
    if (state.adminToken) {
      els.questionList.innerHTML = `<p class="empty">${escapeHtml(error.message)}</p>`;
    }
  } finally {
    els.refreshButton.disabled = false;
  }
});

if (state.adminToken) {
  loadData()
    .then(showAdmin)
    .catch((error) => lockAdmin(error.message));
} else {
  lockAdmin();
}
