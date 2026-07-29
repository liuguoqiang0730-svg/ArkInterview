import http from '@ohos.net.http';
import { API_BASE_URL } from '../app/AppConfig';
import {
  ApiErrorResponse,
  AuthStatusResponse,
  AuthTokenResponse,
  AuthUser,
  HuaweiLoginRequest,
  LeaderboardPreferenceRequest,
  RefreshTokenRequest,
  SuccessResponse,
  UserProfileResponse
} from '../models/AccountModels';
import {
  Category,
  ItemResult,
  ListResult,
  PageResult,
  PracticeMode,
  PracticeRecordItem,
  PracticeSession,
  Question,
  QuestionType,
  SubmitAnswerRequest,
  SubmitAnswerResponse,
  UserStats
} from '../models/QuestionModels';
import {
  LeaderboardResponse,
  LeaderboardScope
} from '../models/LeaderboardModels';
import { DeviceIdentity } from '../utils/DeviceIdentity';
import { AuthSessionStore } from './AuthSessionStore';

export class ApiRequestError extends Error {
  readonly statusCode: number;

  constructor(statusCode: number, message: string) {
    super(message);
    this.name = 'ApiRequestError';
    this.statusCode = statusCode;
  }
}

export class ApiClient {
  private baseUrl: string;
  private deviceIdOverride: string | undefined;

  constructor(baseUrl: string = API_BASE_URL, deviceId?: string) {
    this.baseUrl = baseUrl;
    this.deviceIdOverride = deviceId;
  }

  isSecureAuthTransport(): boolean {
    return this.baseUrl.toLowerCase().startsWith('https://');
  }

  async getAuthStatus(): Promise<AuthStatusResponse> {
    return this.request<AuthStatusResponse>('/auth/status', 'GET', undefined, false, false);
  }

  async loginWithHuawei(authorizationCode: string): Promise<AuthTokenResponse> {
    this.requireSecureAuthTransport();
    const payload: HuaweiLoginRequest = {
      authorizationCode: authorizationCode
    };
    const response = await this.request<AuthTokenResponse>('/auth/huawei', 'POST', payload, false, false);
    await AuthSessionStore.save(response);
    return response;
  }

  async getProfile(): Promise<UserProfileResponse> {
    return this.request<UserProfileResponse>('/users/me/profile');
  }

  async updateLeaderboardPreference(enabled: boolean): Promise<AuthUser> {
    this.requireSecureAuthTransport();
    const payload: LeaderboardPreferenceRequest = {
      enabled: enabled
    };
    const response = await this.request<UserProfileResponse>(
      '/users/me/leaderboard-preference',
      'PUT',
      payload
    );
    if (!response.authenticated || response.user === null) {
      throw new ApiRequestError(401, '当前登录状态无效');
    }
    await AuthSessionStore.updateUser(response.user);
    return response.user;
  }

  async getLeaderboard(
    scope: LeaderboardScope,
    categoryId: string = '',
    limit: number = 50
  ): Promise<LeaderboardResponse> {
    const pairs: string[] = [];
    this.appendQueryParam(pairs, 'scope', scope);
    this.appendQueryParam(pairs, 'categoryId', categoryId);
    this.appendQueryParam(pairs, 'limit', String(limit));
    return this.request<LeaderboardResponse>(`/leaderboards${this.queryString(pairs)}`);
  }

  async logout(): Promise<void> {
    try {
      if (this.isSecureAuthTransport() && AuthSessionStore.accessToken().length > 0) {
        await this.request<SuccessResponse>('/auth/logout', 'POST');
      }
    } finally {
      await AuthSessionStore.clear();
    }
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

  async getPracticeRecords(
    page: number = 1,
    pageSize: number = 20,
    date: string = ''
  ): Promise<PageResult<PracticeRecordItem>> {
    const pairs: string[] = [];
    this.appendQueryParam(pairs, 'page', String(page));
    this.appendQueryParam(pairs, 'pageSize', String(pageSize));
    this.appendQueryParam(pairs, 'date', date);
    return this.request<PageResult<PracticeRecordItem>>(`/users/me/records${this.queryString(pairs)}`);
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
    const result = await this.request<ListResult<string>>(
      `/users/me/favorites/${encodeURIComponent(questionId)}`,
      'DELETE'
    );
    return result.items;
  }

  async markWrongMastered(questionId: string): Promise<void> {
    await this.request<ItemResult<object>>(`/users/me/wrongs/${encodeURIComponent(questionId)}/mastered`, 'POST');
  }

  private async request<T>(
    path: string,
    method: HttpMethod = 'GET',
    body?: object,
    allowRefresh: boolean = true,
    includeAuth: boolean = true
  ): Promise<T> {
    try {
      return await this.performRequest<T>(path, method, body, includeAuth);
    } catch (error) {
      if (error instanceof ApiRequestError &&
        error.statusCode === 401 &&
        allowRefresh &&
        includeAuth &&
        this.isSecureAuthTransport() &&
        AuthSessionStore.refreshToken().length > 0) {
        await this.refreshSession();
        return this.performRequest<T>(path, method, body, true);
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(String(error));
    }
  }

  private async refreshSession(): Promise<void> {
    this.requireSecureAuthTransport();
    const payload: RefreshTokenRequest = {
      refreshToken: AuthSessionStore.refreshToken()
    };
    try {
      const response = await this.performRequest<AuthTokenResponse>('/auth/refresh', 'POST', payload, false);
      await AuthSessionStore.save(response);
    } catch (error) {
      if (error instanceof ApiRequestError && error.statusCode === 401) {
        await AuthSessionStore.clear();
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(String(error));
    }
  }

  private async performRequest<T>(
    path: string,
    method: HttpMethod,
    body: object | undefined,
    includeAuth: boolean
  ): Promise<T> {
    const request = http.createHttp();
    const url = `${this.baseUrl}${path}`;
    const token = includeAuth && this.isSecureAuthTransport() ? AuthSessionStore.accessToken() : '';
    try {
      let options: http.HttpRequestOptions;
      if (token.length > 0) {
        options = {
          method: this.toRequestMethod(method),
          header: {
            'Content-Type': 'application/json',
            'X-Device-Id': this.deviceIdOverride ?? DeviceIdentity.getId(),
            'Authorization': `Bearer ${token}`
          },
          extraData: body ? JSON.stringify(body) : undefined,
          connectTimeout: 10000,
          readTimeout: 10000
        };
      } else {
        options = {
          method: this.toRequestMethod(method),
          header: {
            'Content-Type': 'application/json',
            'X-Device-Id': this.deviceIdOverride ?? DeviceIdentity.getId()
          },
          extraData: body ? JSON.stringify(body) : undefined,
          connectTimeout: 10000,
          readTimeout: 10000
        };
      }

      const response = await request.request(url, options);
      const code = response.responseCode;
      const text = response.result ? String(response.result) : '{}';
      if (code < 200 || code >= 300) {
        throw new ApiRequestError(code, this.errorMessage(code, text));
      }
      return JSON.parse(text) as T;
    } catch (error) {
      if (error instanceof ApiRequestError) {
        throw error;
      }
      throw new Error(`请求失败：${url}。请确认网络正常且后端服务可以访问。${String(error)}`);
    } finally {
      request.destroy();
    }
  }

  private errorMessage(statusCode: number, responseText: string): string {
    try {
      const payload = JSON.parse(responseText) as ApiErrorResponse;
      const message = payload.error ?? payload.message;
      if (message && message.trim().length > 0) {
        return message;
      }
    } catch (error) {
    }
    return `服务请求失败（HTTP ${statusCode}）`;
  }

  private requireSecureAuthTransport(): void {
    if (!this.isSecureAuthTransport()) {
      throw new Error('登录仅支持 HTTPS 服务地址，当前配置不会发送任何账号凭证');
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
    if (method === 'PUT') {
      return http.RequestMethod.PUT;
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

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';
