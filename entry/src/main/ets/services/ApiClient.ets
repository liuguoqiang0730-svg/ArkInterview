import http from '@ohos.net.http';
import { API_BASE_URL } from '../app/AppConfig';
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
import { DeviceIdentity } from '../utils/DeviceIdentity';

export class ApiClient {
  private baseUrl: string;
  private deviceIdOverride: string | undefined;

  constructor(baseUrl: string = API_BASE_URL, deviceId?: string) {
    this.baseUrl = baseUrl;
    this.deviceIdOverride = deviceId;
  }

  async getCategories(): Promise<Category[]> {
    const result = await this.request<ListResult<Category>>('/categories');
    return result.items;
  }

  async getQuestions(categoryId?: string, type?: QuestionType, page: number = 1): Promise<PageResult<Question>> {
    const pairs: string[] = [];
    this.appendQueryParam(pairs, 'categoryId', categoryId);
    this.appendQueryParam(pairs, 'type', type);
    this.appendQueryParam(pairs, 'page', String(page));
    const query = this.queryString(pairs);
    return this.request<PageResult<Question>>(`/questions${query}`);
  }

  async getQuestion(id: string): Promise<Question> {
    const result = await this.request<ItemResult<Question>>(`/questions/${encodeURIComponent(id)}`);
    return result.item;
  }

  async getPracticeSession(mode: PracticeMode, options?: PracticeSessionOptions): Promise<PracticeSession> {
    const pairs: string[] = [];
    this.appendQueryParam(pairs, 'mode', mode);
    this.appendQueryParam(pairs, 'categoryId', options?.categoryId);
    this.appendQueryParam(pairs, 'type', options?.type);
    this.appendQueryParam(pairs, 'count', options?.count ? String(options.count) : undefined);
    const query = this.queryString(pairs);
    return this.request<PracticeSession>(`/practice/session${query}`);
  }

  async getBasicInterview(count: number = 8, categoryId?: string): Promise<PracticeSession> {
    const pairs: string[] = [];
    this.appendQueryParam(pairs, 'count', String(count));
    this.appendQueryParam(pairs, 'categoryId', categoryId);
    const query = this.queryString(pairs);
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
    const payload: FavoriteQuestionRequest = {
      questionId: questionId
    };
    const result = await this.request<ListResult<string>>('/users/me/favorites', 'POST', payload);
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
    const url = `${this.baseUrl}${path}`;
    try {
      const response = await request.request(url, {
        method: this.toRequestMethod(method),
        header: {
          'Content-Type': 'application/json',
          'X-Device-Id': this.deviceIdOverride ?? DeviceIdentity.getId()
        },
        extraData: body ? JSON.stringify(body) : undefined,
        connectTimeout: 10000,
        readTimeout: 10000
      });

      const code = response.responseCode;
      const text = response.result ? String(response.result) : '{}';
      if (code < 200 || code >= 300) {
        throw new Error(`HTTP ${code}: ${text}`);
      }
      return JSON.parse(text) as T;
    } catch (error) {
      throw new Error(`请求失败：${url}。请确认后端已启动，并且设备能访问该地址。${String(error)}`);
    } finally {
      request.destroy();
    }
  }

  private appendQueryParam(pairs: string[], key: string, value?: string): void {
    if (value !== undefined && value !== '') {
      pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
    }
  }

  private queryString(pairs: string[]): string {
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

interface FavoriteQuestionRequest {
  questionId: string;
}

type HttpMethod = 'GET' | 'POST' | 'DELETE';
