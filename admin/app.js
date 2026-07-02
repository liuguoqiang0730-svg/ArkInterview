const state = {
  categories: [],
  questions: [],
  activeCategoryId: '',
  activeType: ''
};

const els = {
  categoryCount: document.querySelector('#categoryCount'),
  questionCount: document.querySelector('#questionCount'),
  publishedCount: document.querySelector('#publishedCount'),
  draftCount: document.querySelector('#draftCount'),
  categoryList: document.querySelector('#categoryList'),
  questionList: document.querySelector('#questionList'),
  typeFilter: document.querySelector('#typeFilter'),
  refreshButton: document.querySelector('#refreshButton'),
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

async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {})
    },
    ...options
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || `请求失败：${response.status}`);
  }
  return data;
}

async function loadData() {
  const [categories, questions] = await Promise.all([
    request('/api/admin/categories'),
    request('/api/admin/questions')
  ]);
  state.categories = categories.items;
  state.questions = questions.items;
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
  const items = state.questions
    .filter((question) => !state.activeCategoryId || question.categoryId === state.activeCategoryId)
    .filter((question) => !state.activeType || question.type === state.activeType);

  if (items.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = '当前筛选条件下没有题目。';
    els.questionList.replaceChildren(empty);
    return;
  }

  els.questionList.replaceChildren(...items.map(questionItem));
}

function questionItem(question) {
  const article = document.createElement('article');
  const category = state.categories.find((item) => item.id === question.categoryId);
  article.className = 'question-item';
  article.innerHTML = `
    <div class="question-topline">
      <div>
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
      ${(question.knowledgePoints || []).map((point) => `<span class="badge">${escapeHtml(point)}</span>`).join('')}
    </div>
  `;
  article.querySelector('[data-action="save"]').addEventListener('click', () => saveQuestionPatch(question.id, article));
  return article;
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
    knowledgePoints: splitList(data.get('knowledgePointsText'))
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

els.refreshButton.addEventListener('click', loadData);

loadData().catch((error) => {
  els.questionList.innerHTML = `<p class="empty">${escapeHtml(error.message)}</p>`;
});
