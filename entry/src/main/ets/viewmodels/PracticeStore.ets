import { ApiClient, PracticeSessionOptions } from '../services/ApiClient';
import {
  Category,
  PracticeMode,
  PracticeSession,
  Question,
  SubmitAnswerRequest,
  SubmitAnswerResponse,
  UserStats
} from '../models/QuestionModels';

export class PracticeStore {
  private api: ApiClient;

  constructor(api: ApiClient = new ApiClient()) {
    this.api = api;
  }

  async loadHome(): Promise<HomeSnapshot> {
    const categories = await this.api.getCategories();
    const stats = await this.api.getStats();
    return { categories, stats };
  }

  async loadStats(): Promise<UserStats> {
    return this.api.getStats();
  }

  async startPractice(mode: PracticeMode, options?: PracticeSessionOptions): Promise<PracticeSession> {
    return this.api.getPracticeSession(mode, options);
  }

  async startInterview(count: number = 8, categoryId?: string): Promise<PracticeSession> {
    return this.api.getBasicInterview(count, categoryId);
  }

  async loadQuestion(questionId: string): Promise<Question> {
    return this.api.getQuestion(questionId);
  }

  async loadWrongs(): Promise<Question[]> {
    return this.api.getWrongs();
  }

  async loadFavorites(): Promise<Question[]> {
    return this.api.getFavorites();
  }

  async submitAnswer(payload: SubmitAnswerRequest): Promise<SubmitAnswerResponse> {
    return this.api.submitAnswer(payload);
  }

  async addFavorite(questionId: string): Promise<void> {
    await this.api.addFavorite(questionId);
  }

  async removeFavorite(questionId: string): Promise<void> {
    await this.api.removeFavorite(questionId);
  }

  async markWrongMastered(questionId: string): Promise<void> {
    await this.api.markWrongMastered(questionId);
  }
}

export interface HomeSnapshot {
  categories: Category[];
  stats: UserStats;
}
