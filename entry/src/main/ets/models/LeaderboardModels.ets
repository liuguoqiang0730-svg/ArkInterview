export type LeaderboardScope = 'weekly' | 'overall';

export interface LeaderboardEntry {
  rank: number;
  displayName: string;
  score: number;
  lastScoredAt: string;
  isCurrentUser: boolean;
}

export interface LeaderboardResponse {
  scope: LeaderboardScope;
  categoryId: string | null;
  categoryName: string;
  periodStart: string | null;
  generatedAt: string;
  scoringRule: string;
  totalParticipants: number;
  entries: LeaderboardEntry[];
  me: LeaderboardEntry | null;
}
