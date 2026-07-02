import http from '@ohos.net.http';
import { API_BASE_URL, DEFAULT_DEVICE_ID } from '../app/AppConfig';
import {
  Category,
  ItemResult,
  ListResult,
  PageResult,
  PracticeMode,
  PracticeSession,
  Question,
  QuestionType,
  SubmitAnswerRequest,
  SubmitAnswerResponse,
  UserStats
} from '../models/QuestionModels';

export class ApiClient {
  private baseUrl: string;
  private deviceId: string;

  constructor(baseUrl: string = API_BASE_URL, deviceId: string = DEFAULT_DEVICE_ID) {
    this.baseUrl = baseUrl;
    this.deviceId = deviceId;
  }

  async getCategories(): Promise<Category[]> {
    const result = await this.request<ListResult<Category>>('/categories');
    return result.items;
  }

  async getQuestions(categoryId?: string, type?: QuestionType, page: number = 1): Promise<PageResult<Question>> {
    const query = this.queryString({
      categoryId,
      type,
      page: String(page)
    });
    return this.request<PageResult<Question>>(`/questions${query}`);
  }

  async getQuestion(id: string): Promise<Question> {
    const result = await this.request<ItemResult<Question>>(`/questions/${encodeURIComponent(id)}`);
    return result.item;
  }

  async getPracticeSession(mode: PracticeMode, options?: PracticeSessionOptions): Promise<PracticeSession> {
    const query = this.queryString({
      mode,
      categoryId: options?.categoryId,
      type: options?.type,
      count: options?.count ? String(options.count) : undefined
    });
    return this.request<PracticeSession>(`/practice/session${query}`);
  }

  async getBasicInterview(count: number = 8, categoryId?: string): Promise<PracticeSession> {
    const query = this.queryString({
      count: String(count),
      categoryId
    });
    return this.request<PracticeSession>(`/interviews/basic${query}`);
  }

  async submitAnswer(payload: SubmitAnswerRequest): Promise<SubmitAnswerResponse> {
    return this.request<SubmitAnswerResponse>('/answers/submit', 'POST', payload);
  }

  async getStats(): Promise<UserStats> {
    return this.request<UserStats>('/users/me/stats');
  }

  async getWrongs(): Promise<Question[]> {
    const result = await this.request<ListResult<Question>>('/users/me/wrongs');
    return result.items;
  }

  async getFavorites(): Promise<Question[]> {
    const result = await this.request<ListResult<Question>>('/users/me/favorites');
    return result.items;
  }

  async addFavorite(questionId: string): Promise<string[]> {
    const result = await this.request<ListResult<string>>('/users/me/favorites', 'POST', { questionId });
    return result.items;
  }

  async removeFavorite(questionId: string): Promise<string[]> {
    const result = await this.request<ListResult<string>>(`/users/me/favorites/${encodeURIComponent(questionId)}`, 'DELETE');
    return result.items;
  }

  async markWrongMastered(questionId: string): Promise<void> {
    await this.request<ItemResult<object>>(`/users/me/wrongs/${encodeURIComponent(questionId)}/mastered`, 'POST');
  }

  private async request<T>(path: string, method: HttpMethod = 'GET', body?: object): Promise<T> {
    const request = http.createHttp();
    try {
      const response = await request.request(`${this.baseUrl}${path}`, {
        method: this.toRequestMethod(method),
        header: {
          'Content-Type': 'application/json',
          'X-Device-Id': this.deviceId
        },
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      const code = response.responseCode;
      const text = response.result ? String(response.result) : '{}';
      if (code < 200 || code >= 300) {
        throw new Error(text);
      }
      return JSON.parse(text) as T;
    } finally {
      request.destroy();
    }
  }

  private queryString(params: Record<string, string | undefined>): string {
    const pairs: string[] = [];
    Object.keys(params).forEach((key: string) => {
      const value = params[key];
      if (value !== undefined && value !== '') {
        pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
      }
    });
    return pairs.length === 0 ? '' : `?${pairs.join('&')}`;
  }

  private toRequestMethod(method: HttpMethod): http.RequestMethod {
    if (method === 'POST') {
      return http.RequestMethod.POST;
    }
    if (method === 'DELETE') {
      return http.RequestMethod.DELETE;
    }
    return http.RequestMethod.GET;
  }
}

export interface PracticeSessionOptions {
  categoryId?: string;
  type?: QuestionType;
  count?: number;
}

type HttpMethod = 'GET' | 'POST' | 'DELETE';
