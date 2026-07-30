import { ApiClient, ApiRequestError, PracticeSessionOptions } from '../services/ApiClient';
import {
  Category,
  PracticeAvailability,
  PracticeMode,
  PracticeRecordPage,
  PracticeSession,
  Question,
  QuestionType,
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

  async loadRecords(
    page: number = 1,
    pageSize: number = 20,
    date: string = '',
    categoryId: string = '',
    type?: QuestionType
  ): Promise<PracticeRecordPage> {
    return this.api.getPracticeRecords(page, pageSize, date, categoryId, type);
  }

  async startPractice(mode: PracticeMode, options?: PracticeSessionOptions): Promise<PracticeSession> {
    return this.api.getPracticeSession(mode, options);
  }

  async loadPracticeAvailability(
    mode: string,
    options?: PracticeSessionOptions
  ): Promise<PracticeAvailability> {
    return this.api.getPracticeAvailability(mode, options);
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

  async removeFavorites(questionIds: string[]): Promise<void> {
    try {
      await this.api.removeFavorites(questionIds);
    } catch (error) {
      if (error instanceof ApiRequestError && error.statusCode !== 404) {
        throw error;
      }
      if (!(error instanceof ApiRequestError)) {
        throw new Error(String(error));
      }
      for (const questionId of questionIds) {
        await this.api.removeFavorite(questionId);
      }
    }
  }

  async markWrongMastered(questionId: string): Promise<void> {
    await this.api.markWrongMastered(questionId);
  }

  async markWrongsMastered(questionIds: string[]): Promise<void> {
    try {
      await this.api.markWrongsMastered(questionIds);
    } catch (error) {
      if (error instanceof ApiRequestError && error.statusCode !== 404) {
        throw error;
      }
      if (!(error instanceof ApiRequestError)) {
        throw new Error(String(error));
      }
      for (const questionId of questionIds) {
        await this.api.markWrongMastered(questionId);
      }
    }
  }
}

export interface HomeSnapshot {
  categories: Category[];
  stats: UserStats;
}
