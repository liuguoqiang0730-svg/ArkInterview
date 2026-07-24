export interface AuthUser {
  id: string;
  displayName: string;
  avatarUrl: string;
  leaderboardOptIn: boolean;
}

export interface AuthStatusResponse {
  huaweiLoginEnabled: boolean;
  anonymousUsageEnabled: boolean;
}

export interface AuthTokenResponse {
  tokenType: string;
  accessToken: string;
  accessExpiresIn: number;
  refreshToken: string;
  refreshExpiresIn: number;
  user: AuthUser;
}

export interface UserProfileResponse {
  authenticated: boolean;
  user: AuthUser | null;
}

export interface HuaweiLoginRequest {
  authorizationCode: string;
}

export interface RefreshTokenRequest {
  refreshToken: string;
}

export interface StoredAuthSession {
  tokenType: string;
  accessToken: string;
  accessExpiresAt: number;
  refreshToken: string;
  refreshExpiresAt: number;
  user: AuthUser;
}

export interface SuccessResponse {
  success: boolean;
}

export interface ApiErrorResponse {
  error?: string;
  message?: string;
}
