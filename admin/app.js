const state = {
  categories: [],
  questions: [],
  activeCategoryId: '',
  activeType: '',
  activeReviewStatus: '',
  activePublishStatus: '',
  questionQuery: '',
  editingQuestionId: null,
  selectedQuestionIds: new Set(),
  batchPending: false,
  activeView: 'questions',
  auditRisk: 'all',
  auditStatus: 'all',
  auditQuery: '',
  audit: {
    summary: {
      totalAccounts: 0,
      optedInAccounts: 0,
      flaggedAccounts: 0,
      suspendedAccounts: 0,
      filteredAccounts: 0
    },
    items: []
  },
  moderationTarget: null,
  adminToken: sessionStorage.getItem('arkinterview.adminToken') || ''
};

const els = {
  authView: document.querySelector('#authView'),
  adminView: document.querySelector('#adminView'),
  questionManagementView: document.querySelector('#questionManagementView'),
  leaderboardAuditView: document.querySelector('#leaderboardAuditView'),
  adminTabs: [...document.querySelectorAll('.admin-tab')],
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
  questionSearchInput: document.querySelector('#questionSearchInput'),
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
  formMessage: document.querySelector('#formMessage'),
  questionEditorDialog: document.querySelector('#questionEditorDialog'),
  questionEditForm: document.querySelector('#questionEditForm'),
  editQuestionTypeInput: document.querySelector('#editQuestionTypeInput'),
  questionEditMessage: document.querySelector('#questionEditMessage'),
  questionEditCloseButton: document.querySelector('#questionEditCloseButton'),
  questionEditCancelButton: document.querySelector('#questionEditCancelButton'),
  questionEditSubmitButton: document.querySelector('#questionEditSubmitButton'),
  auditAccountCount: document.querySelector('#auditAccountCount'),
  auditOptInCount: document.querySelector('#auditOptInCount'),
  auditFlaggedCount: document.querySelector('#auditFlaggedCount'),
  auditSuspendedCount: document.querySelector('#auditSuspendedCount'),
  auditVisibleCount: document.querySelector('#auditVisibleCount'),
  auditFilterForm: document.querySelector('#auditFilterForm'),
  auditSearchInput: document.querySelector('#auditSearchInput'),
  auditRiskFilter: document.querySelector('#auditRiskFilter'),
  auditStatusFilter: document.querySelector('#auditStatusFilter'),
  auditMessage: document.querySelector('#auditMessage'),
  auditTableBody: document.querySelector('#auditTableBody'),
  auditEmpty: document.querySelector('#auditEmpty'),
  moderationDialog: document.querySelector('#moderationDialog'),
  moderationForm: document.querySelector('#moderationForm'),
  moderationTitle: document.querySelector('#moderationTitle'),
  moderationDescription: document.querySelector('#moderationDescription'),
  moderationReasonInput: document.querySelector('#moderationReasonInput'),
  moderationMessage: document.querySelector('#moderationMessage'),
  moderationCancelButton: document.querySelector('#moderationCancelButton'),
  moderationSubmitButton: document.querySelector('#moderationSubmitButton')
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
  state.editingQuestionId = null;
  state.audit.items = [];
  state.moderationTarget = null;
  state.selectedQuestionIds.clear();
  sessionStorage.removeItem('arkinterview.adminToken');
  els.authView.hidden = false;
  els.adminView.hidden = true;
  els.refreshButton.hidden = true;
  els.logoutButton.hidden = true;
  els.authMessage.textContent = message;
  if (els.moderationDialog.open) {
    els.moderationDialog.close();
  }
  if (els.questionEditorDialog.open) {
    els.questionEditorDialog.close();
  }
  els.adminTokenInput.focus();
}

async function unlockAdmin(token) {
  state.adminToken = token.trim();
  await loadData();
  sessionStorage.setItem('arkinterview.adminToken', state.adminToken);
  showAdmin();
}

async function loadData() {
  const [categories, questions, audit] = await Promise.all([
    request('/api/admin/categories'),
    request('/api/admin/questions'),
    request(auditRequestPath())
  ]);
  state.categories = categories.items;
  state.questions = questions.items;
  state.audit = audit;
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
  renderAudit();
  setActiveView(state.activeView);
  syncQuestionTypeFields();
}

function setActiveView(view) {
  state.activeView = view === 'leaderboard' ? 'leaderboard' : 'questions';
  els.questionManagementView.hidden = state.activeView !== 'questions';
  els.leaderboardAuditView.hidden = state.activeView !== 'leaderboard';
  for (const button of els.adminTabs) {
    const active = button.dataset.view === state.activeView;
    button.classList.toggle('active', active);
    button.setAttribute('aria-current', active ? 'page' : 'false');
  }
}

function renderStats() {
  const published = state.questions.filter((item) => item.status === 'published').length;
  const draft = state.questions.filter((item) => item.status === 'draft').length;
  els.categoryCount.textContent = String(state.categories.length);
  els.questionCount.textContent = String(state.questions.length);
  els.publishedCount.textContent = String(published);
  els.draftCount.textContent = String(draft);
}

function renderAudit() {
  const { summary, items } = state.audit;
  els.auditAccountCount.textContent = String(summary.totalAccounts);
  els.auditOptInCount.textContent = String(summary.optedInAccounts);
  els.auditFlaggedCount.textContent = String(summary.flaggedAccounts);
  els.auditSuspendedCount.textContent = String(summary.suspendedAccounts);
  els.auditVisibleCount.textContent = `${summary.filteredAccounts} 人`;
  els.auditEmpty.hidden = items.length > 0;
  els.auditTableBody.replaceChildren(...items.map(auditRow));
}

function auditRow(item) {
  const row = document.createElement('tr');
  const riskLabels = {
    normal: '正常',
    review: '需复核',
    high: '高风险'
  };
  const statusLabel = item.status === 'suspended' ? '已封禁' : '正常';
  const riskReason = item.riskReasons.length > 0
    ? item.riskReasons.join('；')
    : '未发现异常频率';
  const latestAction = item.lastModeration
    ? `${item.lastModeration.action === 'suspend' ? '封禁' : '解封'}：${item.lastModeration.reason}`
    : '';
  row.innerHTML = `
    <td>
      <strong class="account-name">${escapeHtml(item.displayName || '未设置昵称')}</strong>
      <code class="account-id">${escapeHtml(item.userId)}</code>
      <span class="account-provider">${escapeHtml(item.providers.join(' / ') || '账号')}</span>
    </td>
    <td>
      <div class="status-stack">
        <span class="badge account-${escapeHtml(item.status)}">${statusLabel}</span>
        <span class="badge risk-${escapeHtml(item.riskLevel)}" title="${escapeHtml(riskReason)}">${riskLabels[item.riskLevel] || item.riskLevel}</span>
      </div>
      ${latestAction ? `<span class="audit-secondary" title="${escapeHtml(latestAction)}">${escapeHtml(latestAction)}</span>` : ''}
    </td>
    <td><strong class="numeric-value">${item.score}</strong></td>
    <td>
      <strong class="numeric-value">${item.eligibleAttempts}</strong>
      <span class="audit-secondary">${item.eligibleCorrectRate}% 正确</span>
    </td>
    <td>
      <strong class="numeric-value">${item.maxAttemptsInMinute}/分钟</strong>
      <span class="audit-secondary">${item.maxAttemptsInFiveMinutes}/5 分钟</span>
    </td>
    <td>
      <span class="date-value">${formatDate(item.lastAnsweredAt)}</span>
      <span class="audit-secondary">${item.status === 'suspended' ? '封禁期间不公开' : item.leaderboardOptIn ? '当前参与排行' : '当前未参与'}</span>
    </td>
    <td class="audit-action-cell">
      <button
        class="${item.status === 'suspended' ? 'small-button' : 'danger-outline-button'}"
        type="button"
        data-action="moderate"
      >${item.status === 'suspended' ? '解封' : '封禁'}</button>
    </td>
  `;
  row.querySelector('[data-action="moderate"]').addEventListener('click', () => {
    openModerationDialog(item);
  });
  return row;
}

function auditRequestPath() {
  const params = new URLSearchParams({
    risk: state.auditRisk,
    status: state.auditStatus
  });
  if (state.auditQuery) {
    params.set('q', state.auditQuery);
  }
  return `/api/admin/leaderboard/users?${params.toString()}`;
}

async function loadAuditData() {
  setAuditMessage('正在刷新审计数据...');
  try {
    state.audit = await request(auditRequestPath());
    renderAudit();
    setAuditMessage('');
  } catch (error) {
    setAuditMessage(error.message, true);
    throw error;
  }
}

function openModerationDialog(item) {
  const nextStatus = item.status === 'suspended' ? 'active' : 'suspended';
  state.moderationTarget = {
    userId: item.userId,
    displayName: item.displayName || item.userId,
    status: nextStatus
  };
  const suspending = nextStatus === 'suspended';
  els.moderationTitle.textContent = suspending ? '封禁账号' : '解除封禁';
  els.moderationDescription.textContent = suspending
    ? `封禁 ${state.moderationTarget.displayName} 后，其登录会话会立即失效并退出排行榜。`
    : `解除 ${state.moderationTarget.displayName} 的封禁。用户需要重新登录，历史审计记录不会删除。`;
  els.moderationSubmitButton.textContent = suspending ? '确认封禁' : '确认解封';
  els.moderationSubmitButton.className = suspending ? 'danger-button' : 'primary-button';
  els.moderationReasonInput.value = '';
  els.moderationMessage.textContent = '';
  els.moderationDialog.showModal();
  els.moderationReasonInput.focus();
}

async function submitModeration() {
  const target = state.moderationTarget;
  if (!target) {
    return;
  }
  const reason = els.moderationReasonInput.value.trim();
  els.moderationSubmitButton.disabled = true;
  els.moderationMessage.textContent = '处理中...';
  try {
    await request(`/api/admin/leaderboard/users/${encodeURIComponent(target.userId)}/status`, {
      method: 'PATCH',
      body: JSON.stringify({
        status: target.status,
        reason
      })
    });
    els.moderationDialog.close();
    state.moderationTarget = null;
    await loadAuditData();
    setAuditMessage(target.status === 'suspended' ? '账号已封禁' : '账号已解除封禁');
  } catch (error) {
    els.moderationMessage.textContent = error.message;
  } finally {
    els.moderationSubmitButton.disabled = false;
  }
}

function setAuditMessage(message, isError = false) {
  els.auditMessage.textContent = message;
  els.auditMessage.classList.toggle('error', isError);
}

function formatDate(value) {
  if (!value) {
    return '暂无记录';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '时间无效';
  }
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false
  }).format(date);
}

function renderCategoryInput() {
  populateCategorySelect(els.categoryInput);
  const editCategoryInput = els.questionEditForm.elements.namedItem('categoryId');
  populateCategorySelect(editCategoryInput);
}

function populateCategorySelect(select) {
  const selected = select.value;
  select.replaceChildren(...state.categories.map((category) => {
    const option = document.createElement('option');
    option.value = category.id;
    option.textContent = category.name;
    return option;
  }));
  if (selected && state.categories.some((category) => category.id === selected)) {
    select.value = selected;
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
  const query = normalizeSearchValue(state.questionQuery);
  return state.questions
    .filter((question) => !state.activeCategoryId || question.categoryId === state.activeCategoryId)
    .filter((question) => !state.activeType || question.type === state.activeType)
    .filter((question) => !state.activeReviewStatus || question.reviewStatus === state.activeReviewStatus)
    .filter((question) => !state.activePublishStatus || question.status === state.activePublishStatus)
    .filter((question) => !query || questionSearchText(question).includes(query));
}

function questionSearchText(question) {
  const category = state.categories.find((item) => item.id === question.categoryId);
  return normalizeSearchValue(`${JSON.stringify(question)} ${category?.name || ''}`);
}

function normalizeSearchValue(value) {
  return String(value || '').normalize('NFKC').toLocaleLowerCase('zh-CN');
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
        <p class="question-meta">${escapeHtml(question.id)} · ${escapeHtml(category?.name || question.categoryId)} · ${typeLabels[question.type] || question.type} · ${difficultyLabels[question.difficulty] || question.difficulty}</p>
      </div>
      <div class="question-controls">
        ${selectHtml('difficulty', question.difficulty, difficultyLabels)}
        ${selectHtml('status', question.status, statusLabels)}
        <button class="secondary-button" type="button" data-action="edit">编辑</button>
        <button class="small-button" type="button" data-action="save">保存</button>
      </div>
    </div>
    <div class="badges">
      <span class="badge ${question.status}">${statusLabels[question.status] || question.status}</span>
      <span class="badge review-${question.reviewStatus || 'needs_review'}">${reviewStatusLabels[question.reviewStatus] || '待核验'}</span>
      <span class="badge">官方来源 ${(question.sourceRefs || []).length}</span>
      ${question.reviewNote ? '<span class="badge">有审核备注</span>' : ''}
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
  article.querySelector('[data-action="edit"]').addEventListener('click', () => openQuestionEditor(question.id));
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

function openQuestionEditor(questionId) {
  const question = state.questions.find((item) => item.id === questionId);
  if (!question) {
    setFormMessage('找不到需要编辑的题目', true);
    return;
  }

  state.editingQuestionId = questionId;
  const form = els.questionEditForm;
  setFormControl(form, 'id', question.id);
  setFormControl(form, 'order', question.order ?? '');
  setFormControl(form, 'categoryId', question.categoryId);
  setFormControl(form, 'type', question.type);
  setFormControl(form, 'difficulty', question.difficulty);
  setFormControl(form, 'status', question.status);
  setFormControl(form, 'reviewStatus', question.reviewStatus || 'needs_review');
  setFormControl(form, 'verifiedAt', question.verifiedAt || '');
  setFormControl(form, 'title', question.title || '');
  setFormControl(form, 'optionsText', formatOptions(question.options));
  setFormControl(form, 'correctOptionIds', (question.correctOptionIds || []).join(','));
  setFormControl(form, 'answerBoolean', String(question.answerBoolean ?? true));
  setFormControl(form, 'referenceAnswer', question.referenceAnswer || '');
  setFormControl(form, 'scoringPointsText', (question.scoringPoints || []).join('\n'));
  setFormControl(form, 'explanation', question.explanation || '');
  setFormControl(form, 'knowledgePointsText', (question.knowledgePoints || []).join(', '));
  setFormControl(form, 'sourceRefsText', formatSourceRefs(question.sourceRefs));
  setFormControl(form, 'reviewNote', question.reviewNote || '');
  els.questionEditMessage.textContent = '';
  syncQuestionTypeFields(form);
  els.questionEditorDialog.showModal();
  form.elements.namedItem('title').focus();
}

function setFormControl(form, name, value) {
  const control = form.elements.namedItem(name);
  if (control) {
    control.value = value;
  }
}

function formatOptions(options = []) {
  return options.map((option) => `${String(option.id).toUpperCase()}. ${option.text}`).join('\n');
}

function formatSourceRefs(sourceRefs = []) {
  return sourceRefs
    .map((source) => `${source.title} | ${source.url} | ${source.publisher || 'Huawei Developer'}`)
    .join('\n');
}

function closeQuestionEditor() {
  state.editingQuestionId = null;
  els.questionEditMessage.textContent = '';
  if (els.questionEditorDialog.open) {
    els.questionEditorDialog.close();
  }
}

async function submitQuestionEdit() {
  const questionId = state.editingQuestionId;
  if (!questionId) {
    return;
  }

  els.questionEditSubmitButton.disabled = true;
  els.questionEditMessage.textContent = '保存中...';
  try {
    const payload = parseQuestionForm(els.questionEditForm);
    const result = await request(`/api/admin/questions/${encodeURIComponent(questionId)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload)
    });
    const index = state.questions.findIndex((item) => item.id === questionId);
    if (index >= 0) {
      state.questions[index] = result.item;
    }
    closeQuestionEditor();
    setFormMessage('题目详情已更新');
    render();
  } catch (error) {
    els.questionEditMessage.textContent = error.message;
  } finally {
    els.questionEditSubmitButton.disabled = false;
  }
}

function syncQuestionTypeFields(form = els.questionForm) {
  const type = form.elements.namedItem('type').value;
  const choiceFields = form.querySelectorAll('.choice-field');
  const booleanFields = form.querySelectorAll('.boolean-field');
  const shortFields = form.querySelectorAll('.short-field');

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
    reviewStatus: data.get('reviewStatus'),
    reviewNote: String(data.get('reviewNote') || '').trim()
  };

  const order = String(data.get('order') ?? '').trim();
  if (order) {
    payload.order = Number(order);
  }

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

els.questionSearchInput.addEventListener('input', (event) => {
  state.questionQuery = event.target.value.trim();
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

els.questionTypeInput.addEventListener('change', () => syncQuestionTypeFields());
els.editQuestionTypeInput.addEventListener('change', () => syncQuestionTypeFields(els.questionEditForm));

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

els.questionEditForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  await submitQuestionEdit();
});

els.questionEditCloseButton.addEventListener('click', closeQuestionEditor);
els.questionEditCancelButton.addEventListener('click', closeQuestionEditor);
els.questionEditorDialog.addEventListener('click', (event) => {
  if (event.target === els.questionEditorDialog) {
    closeQuestionEditor();
  }
});
els.questionEditorDialog.addEventListener('close', () => {
  state.editingQuestionId = null;
  els.questionEditMessage.textContent = '';
});

for (const button of els.adminTabs) {
  button.addEventListener('click', () => {
    setActiveView(button.dataset.view);
  });
}

els.auditFilterForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  state.auditQuery = els.auditSearchInput.value.trim();
  await loadAuditData().catch(() => {});
});

els.auditRiskFilter.addEventListener('change', async (event) => {
  state.auditRisk = event.target.value;
  await loadAuditData().catch(() => {});
});

els.auditStatusFilter.addEventListener('change', async (event) => {
  state.auditStatus = event.target.value;
  await loadAuditData().catch(() => {});
});

els.moderationForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  await submitModeration();
});

els.moderationCancelButton.addEventListener('click', () => {
  state.moderationTarget = null;
  els.moderationDialog.close();
});

els.moderationDialog.addEventListener('click', (event) => {
  if (event.target === els.moderationDialog) {
    state.moderationTarget = null;
    els.moderationDialog.close();
  }
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
