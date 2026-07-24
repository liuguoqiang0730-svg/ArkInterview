import { createHash } from 'node:crypto';

const shanghaiOffsetMs = 8 * 60 * 60 * 1000;
const defaultLimit = 50;
const maximumLimit = 100;
const validScopes = new Set(['weekly', 'overall']);

export class LeaderboardService {
  constructor({ store, db, now = () => new Date() }) {
    this.store = store;
    this.db = db;
    this.now = now;
  }

  getLeaderboard({ scope: scopeInput, categoryId: categoryIdInput, limit: limitInput, currentUserId = '' }) {
    const scope = String(scopeInput || 'weekly').trim();
    if (!validScopes.has(scope)) {
      throw new LeaderboardError(400, 'scope 仅支持 weekly 或 overall');
    }

    const categoryId = String(categoryIdInput || '').trim();
    const category = categoryId
      ? this.db.categories.find((item) => item.id === categoryId)
      : undefined;
    if (categoryId && !category) {
      throw new LeaderboardError(400, '排行榜分类不存在');
    }

    const limit = parseLimit(limitInput);
    const now = this.now();
    const periodStart = scope === 'weekly' ? startOfShanghaiWeek(now).toISOString() : null;
    const rows = this.store.listLeaderboardRows({
      categoryId,
      periodStart
    });
    const currentIndex = currentUserId
      ? rows.findIndex((row) => row.userId === currentUserId)
      : -1;
    const entries = rows
      .slice(0, limit)
      .map((row, index) => publicEntry(row, index + 1, row.userId === currentUserId));

    return {
      scope,
      categoryId: categoryId || null,
      categoryName: category?.name || '全部模块',
      periodStart,
      generatedAt: now.toISOString(),
      scoringRule: 'first_correct_after_opt_in_per_verified_objective_question',
      totalParticipants: rows.length,
      entries,
      me: currentIndex >= 0
        ? publicEntry(rows[currentIndex], currentIndex + 1, true)
        : null
    };
  }
}

export class LeaderboardError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'LeaderboardError';
    this.status = status;
  }
}

export function startOfShanghaiWeek(value) {
  const input = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(input.getTime())) {
    throw new LeaderboardError(400, '排行榜时间无效');
  }
  const shifted = new Date(input.getTime() + shanghaiOffsetMs);
  const daysSinceMonday = (shifted.getUTCDay() + 6) % 7;
  const localMidnightUtc = Date.UTC(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth(),
    shifted.getUTCDate() - daysSinceMonday
  );
  return new Date(localMidnightUtc - shanghaiOffsetMs);
}

function parseLimit(value) {
  if (value === undefined || value === null || value === '') {
    return defaultLimit;
  }
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > maximumLimit) {
    throw new LeaderboardError(400, `limit 必须是 1 到 ${maximumLimit} 的整数`);
  }
  return parsed;
}

function publicEntry(row, rank, isCurrentUser) {
  return {
    rank,
    displayName: anonymizedName(row.userId),
    score: Number(row.score),
    lastScoredAt: row.lastScoredAt,
    isCurrentUser
  };
}

function anonymizedName(userId) {
  const suffix = createHash('sha256')
    .update(userId)
    .digest('hex')
    .slice(0, 4)
    .toUpperCase();
  return `Ark开发者·${suffix}`;
}
