import { randomUUID } from 'node:crypto';

const validRiskFilters = new Set(['all', 'flagged', 'normal', 'review', 'high']);
const validStatusFilters = new Set(['all', 'active', 'suspended']);
const validUserStatuses = new Set(['active', 'suspended']);
const reviewMinuteThreshold = 15;
const highMinuteThreshold = 30;
const reviewFiveMinuteThreshold = 40;
const highFiveMinuteThreshold = 80;
const defaultPageSize = 20;
const maximumPageSize = 100;

export class LeaderboardAdminService {
  constructor({ store, db, now = () => new Date() }) {
    this.store = store;
    this.db = db;
    this.now = now;
  }

  listUsers({
    risk: riskInput = 'all',
    status: statusInput = 'all',
    query: queryInput = '',
    page: pageInput = 1,
    pageSize: pageSizeInput = defaultPageSize
  } = {}) {
    const risk = String(riskInput || 'all').trim();
    const status = String(statusInput || 'all').trim();
    const query = String(queryInput || '').trim().toLocaleLowerCase('zh-CN');
    const requestedPage = positiveInteger(pageInput, 'page');
    const pageSize = positiveInteger(pageSizeInput, 'pageSize', maximumPageSize);
    if (!validRiskFilters.has(risk)) {
      throw new LeaderboardAdminError(400, 'risk 筛选条件无效');
    }
    if (!validStatusFilters.has(status)) {
      throw new LeaderboardAdminError(400, 'status 筛选条件无效');
    }
    if (query.length > 100) {
      throw new LeaderboardAdminError(400, '搜索内容不能超过 100 个字符');
    }

    const allItems = this.buildAuditItems();

    const filteredItems = allItems
      .filter((item) => status === 'all' || item.status === status)
      .filter((item) => riskMatches(item.riskLevel, risk))
      .filter((item) => !query || searchText(item).includes(query))
      .sort(compareAuditItems);
    const totalItems = filteredItems.length;
    const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
    const page = Math.min(requestedPage, totalPages);
    const offset = (page - 1) * pageSize;
    const items = filteredItems.slice(offset, offset + pageSize);

    return {
      generatedAt: this.nowIso(),
      thresholds: {
        reviewMinute: reviewMinuteThreshold,
        highMinute: highMinuteThreshold,
        reviewFiveMinutes: reviewFiveMinuteThreshold,
        highFiveMinutes: highFiveMinuteThreshold
      },
      summary: {
        totalAccounts: allItems.length,
        optedInAccounts: allItems.filter((item) => item.leaderboardOptIn).length,
        flaggedAccounts: allItems.filter((item) => item.riskLevel !== 'normal').length,
        suspendedAccounts: allItems.filter((item) => item.status === 'suspended').length,
        filteredAccounts: totalItems
      },
      pagination: {
        page,
        pageSize,
        totalItems,
        totalPages,
        hasPrevious: page > 1,
        hasNext: page < totalPages
      },
      items
    };
  }

  updateUserStatus({
    userId: userIdInput,
    status: statusInput,
    reason: reasonInput,
    operator: operatorInput,
    note: noteInput = ''
  }) {
    const userId = String(userIdInput || '').trim();
    const status = String(statusInput || '').trim();
    const reason = String(reasonInput || '').trim();
    const operator = normalizeOperator(operatorInput);
    const note = String(noteInput || '').trim();
    if (!validUserStatuses.has(status)) {
      throw new LeaderboardAdminError(400, '用户状态只能是 active 或 suspended');
    }
    if (reason.length < 4 || reason.length > 300) {
      throw new LeaderboardAdminError(400, '操作原因必须包含 4 至 300 个字符');
    }
    if (note.length > 1000) {
      throw new LeaderboardAdminError(400, '管理员备注不能超过 1000 个字符');
    }

    const user = uniqueUsers(this.db).find((item) => item.id === userId);
    if (!user || !this.store.hasIdentityForUser(userId)) {
      throw new LeaderboardAdminError(404, '排行榜账号不存在');
    }
    if (user.status === status) {
      throw new LeaderboardAdminError(409, status === 'suspended' ? '账号已处于封禁状态' : '账号已处于正常状态');
    }

    const timestamp = this.nowIso();
    user.status = status;
    user.updatedAt = timestamp;
    this.db.meta.updatedAt = timestamp;
    this.store.moderateUser(user, {
      id: `moderation-${randomUUID()}`,
      action: status === 'suspended' ? 'suspend' : 'restore',
      reason,
      operator,
      note,
      createdAt: timestamp
    }, this.db.meta);

    return this.buildAuditItems().find((item) => item.userId === userId);
  }

  buildAuditItems() {
    const attemptsByUser = groupByUser(this.store.listLeaderboardAuditAttempts());
    const eventsByUser = groupByUser(this.store.listUserModerationEvents());
    const scoresByUser = new Map(
      this.store.listLeaderboardRows({ includeInactive: true })
        .map((row) => [row.userId, Number(row.score)])
    );
    return this.store.listLeaderboardAuditUsers().map((user) => buildAuditItem(
      user,
      attemptsByUser.get(user.userId) || [],
      eventsByUser.get(user.userId) || [],
      scoresByUser.get(user.userId) || 0
    ));
  }

  nowIso() {
    const value = this.now();
    return (value instanceof Date ? value : new Date(value)).toISOString();
  }
}

export class LeaderboardAdminError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'LeaderboardAdminError';
    this.status = status;
  }
}

function positiveInteger(value, field, maximum = Number.MAX_SAFE_INTEGER) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > maximum) {
    const maximumHint = maximum === Number.MAX_SAFE_INTEGER ? '' : `且不能超过 ${maximum}`;
    throw new LeaderboardAdminError(400, `${field} 必须是正整数${maximumHint}`);
  }
  return parsed;
}

function normalizeOperator(value) {
  const operator = String(value || '').trim().replace(/\s+/g, ' ');
  if (operator.length < 2 || operator.length > 64) {
    throw new LeaderboardAdminError(400, '操作员标识必须包含 2 至 64 个字符');
  }
  return operator;
}

function buildAuditItem(user, attempts, events, score) {
  const eligibleAttempts = attempts.filter((attempt) => attempt.leaderboardEligible);
  const correctEligibleAttempts = eligibleAttempts.filter((attempt) => attempt.isCorrect === true);
  const frequency = analyzeFrequency(eligibleAttempts);
  return {
    ...user,
    score,
    totalAttempts: attempts.length,
    eligibleAttempts: eligibleAttempts.length,
    correctEligibleAttempts: correctEligibleAttempts.length,
    eligibleCorrectRate: eligibleAttempts.length > 0
      ? Math.round((correctEligibleAttempts.length / eligibleAttempts.length) * 1000) / 10
      : 0,
    lastAnsweredAt: attempts.at(-1)?.submittedAt || null,
    maxAttemptsInMinute: frequency.maxAttemptsInMinute,
    maxAttemptsInFiveMinutes: frequency.maxAttemptsInFiveMinutes,
    riskLevel: frequency.riskLevel,
    riskReasons: frequency.riskReasons,
    lastModeration: events[0] || null,
    moderationCount: events.length
  };
}

function analyzeFrequency(attempts) {
  const timestamps = attempts
    .map((attempt) => Date.parse(attempt.submittedAt))
    .filter(Number.isFinite)
    .sort((left, right) => left - right);
  const maxAttemptsInMinute = maxEventsInWindow(timestamps, 60 * 1000);
  const maxAttemptsInFiveMinutes = maxEventsInWindow(timestamps, 5 * 60 * 1000);
  const riskReasons = [];

  if (maxAttemptsInMinute >= reviewMinuteThreshold) {
    riskReasons.push(`60 秒内提交 ${maxAttemptsInMinute} 次`);
  }
  if (maxAttemptsInFiveMinutes >= reviewFiveMinuteThreshold) {
    riskReasons.push(`5 分钟内提交 ${maxAttemptsInFiveMinutes} 次`);
  }

  let riskLevel = 'normal';
  if (
    maxAttemptsInMinute >= highMinuteThreshold ||
    maxAttemptsInFiveMinutes >= highFiveMinuteThreshold
  ) {
    riskLevel = 'high';
  } else if (riskReasons.length > 0) {
    riskLevel = 'review';
  }

  return {
    maxAttemptsInMinute,
    maxAttemptsInFiveMinutes,
    riskLevel,
    riskReasons
  };
}

function maxEventsInWindow(timestamps, windowMs) {
  let maximum = 0;
  let start = 0;
  for (let end = 0; end < timestamps.length; end += 1) {
    while (timestamps[end] - timestamps[start] >= windowMs) {
      start += 1;
    }
    maximum = Math.max(maximum, end - start + 1);
  }
  return maximum;
}

function groupByUser(items) {
  const grouped = new Map();
  for (const item of items) {
    const current = grouped.get(item.userId) || [];
    current.push(item);
    grouped.set(item.userId, current);
  }
  return grouped;
}

function uniqueUsers(db) {
  return [...new Map(Object.values(db.users).map((user) => [user.id, user])).values()];
}

function riskMatches(level, filter) {
  if (filter === 'all') {
    return true;
  }
  if (filter === 'flagged') {
    return level !== 'normal';
  }
  return level === filter;
}

function searchText(item) {
  return [
    item.userId,
    item.displayName,
    ...item.providers
  ].join(' ').toLocaleLowerCase('zh-CN');
}

function compareAuditItems(left, right) {
  const riskWeight = { high: 0, review: 1, normal: 2 };
  return riskWeight[left.riskLevel] - riskWeight[right.riskLevel]
    || Number(right.status === 'suspended') - Number(left.status === 'suspended')
    || right.maxAttemptsInMinute - left.maxAttemptsInMinute
    || String(right.lastAnsweredAt || '').localeCompare(String(left.lastAnsweredAt || ''))
    || left.userId.localeCompare(right.userId);
}
