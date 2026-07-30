export type QuestionType = 'single' | 'multiple' | 'boolean' | 'short';
export type Difficulty = 'easy' | 'medium' | 'hard';
export type PracticeMode = 'category' | 'random' | 'wrongs' | 'favorites';

export interface Category {
  id: string;
  name: string;
  order: number;
  description: string;
}

export interface QuestionOption {
  id: string;
  text: string;
}

export interface WrongRecord {
  questionId: string;
  wrongCount: number;
  mastered: boolean;
  updatedAt: string;
}

export interface SourceRef {
  title: string;
  url: string;
  publisher: string;
}

export interface Question {
  id: string;
  categoryId: string;
  type: QuestionType;
  difficulty: Difficulty;
  title: string;
  options: QuestionOption[];
  explanation?: string;
  correctOptionIds?: string[];
  answerBoolean?: boolean;
  referenceAnswer?: string;
  scoringPoints?: string[];
  sourceRefs?: SourceRef[];
  verifiedAt?: string;
  reviewStatus?: string;
  knowledgePoints: string[];
  status: string;
  order?: number;
  isFavorite?: boolean;
  wrong?: WrongRecord;
}

export interface PageResult<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface ListResult<T> {
  items: T[];
}

export interface ItemResult<T> {
  item: T;
}

export interface PracticeSession {
  sessionId: string;
  mode: PracticeMode;
  categoryId?: string;
  type?: QuestionType;
  difficulty?: Difficulty;
  total: number;
  items: Question[];
}

export interface PracticeAvailability {
  mode: string;
  categoryId?: string;
  type?: QuestionType;
  difficulty?: Difficulty;
  availableCount: number;
  maxCount: number;
}

export interface SubmitAnswerRequest {
  questionId: string;
  selectedOptionIds?: string[];
  answerBoolean?: boolean;
  shortAnswer?: string;
}

export interface SubmitAnswerResponse {
  questionId: string;
  isCorrect: boolean | null;
  correctOptionIds?: string[];
  answerBoolean?: boolean;
  referenceAnswer?: string;
  scoringPoints?: string[];
  explanation: string;
  knowledgePoints: string[];
  stats: UserStats;
}

export interface CategoryStats {
  categoryId: string;
  name: string;
  attempts: number;
  gradedAttempts?: number;
  answered: number;
  correct: number;
  totalPublished: number;
  completionRate: number;
  accuracy: number;
}

export interface PracticeRecordItem {
  id: string;
  questionId: string;
  categoryId: string;
  categoryName: string;
  questionTitle: string;
  questionType: QuestionType;
  isCorrect: boolean | null;
  submittedAt: string;
}

export interface DailyPracticeStats {
  date: string;
  attempts: number;
  gradedAttempts: number;
  correct: number;
  accuracy: number;
}

export interface PracticeRecordSummary {
  attempts: number;
  gradedAttempts: number;
  correct: number;
  accuracy: number;
}

export interface PracticeRecordPage extends PageResult<PracticeRecordItem> {
  date?: string | null;
  categoryId?: string | null;
  type?: QuestionType | null;
  summary?: PracticeRecordSummary;
  dailyStats?: DailyPracticeStats[];
}

export interface UserStats {
  totalAnswers: number;
  answeredQuestionCount: number;
  correctAnswers: number;
  accuracy: number;
  wrongCount: number;
  masteredWrongCount: number;
  favoriteCount: number;
  lastPracticedAt?: string;
  recentRecords?: PracticeRecordItem[];
  dailyStats?: DailyPracticeStats[];
  categories: CategoryStats[];
}
