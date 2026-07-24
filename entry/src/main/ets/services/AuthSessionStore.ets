import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { AuthTokenResponse, AuthUser, StoredAuthSession } from '../models/AccountModels';

const SESSION_ALIAS: string = 'arkinterview.session.v1';
const ASSET_NOT_FOUND: number = 24000002;

export class AuthSessionStore {
  private static session: StoredAuthSession | undefined = undefined;
  private static initialized: boolean = false;

  static async initialize(): Promise<void> {
    if (AuthSessionStore.initialized) {
      return;
    }
    AuthSessionStore.session = await AuthSessionStore.read();
    AuthSessionStore.initialized = true;
  }

  static isAuthenticated(): boolean {
    return AuthSessionStore.session !== undefined;
  }

  static accessToken(): string {
    return AuthSessionStore.session?.accessToken ?? '';
  }

  static refreshToken(): string {
    return AuthSessionStore.session?.refreshToken ?? '';
  }

  static user(): AuthUser | undefined {
    return AuthSessionStore.session?.user;
  }

  static async save(response: AuthTokenResponse): Promise<void> {
    const now: number = Date.now();
    const stored: StoredAuthSession = {
      tokenType: response.tokenType,
      accessToken: response.accessToken,
      accessExpiresAt: now + response.accessExpiresIn * 1000,
      refreshToken: response.refreshToken,
      refreshExpiresAt: now + response.refreshExpiresIn * 1000,
      user: response.user
    };
    AuthSessionStore.validate(stored);
    await AuthSessionStore.persist(stored);
    AuthSessionStore.session = stored;
    AuthSessionStore.initialized = true;
  }

  static async updateUser(user: AuthUser): Promise<void> {
    const current = AuthSessionStore.session;
    if (current === undefined || current.user.id !== user.id) {
      throw new Error('当前登录会话与用户资料不匹配');
    }
    const updated: StoredAuthSession = {
      tokenType: current.tokenType,
      accessToken: current.accessToken,
      accessExpiresAt: current.accessExpiresAt,
      refreshToken: current.refreshToken,
      refreshExpiresAt: current.refreshExpiresAt,
      user: user
    };
    AuthSessionStore.validate(updated);
    await AuthSessionStore.persist(updated);
    AuthSessionStore.session = updated;
  }

  static async clear(): Promise<void> {
    AuthSessionStore.session = undefined;
    AuthSessionStore.initialized = true;

    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, AuthSessionStore.toBytes(SESSION_ALIAS));
    try {
      await asset.remove(query);
    } catch (error) {
      const businessError = error as BusinessError;
      if (businessError.code !== ASSET_NOT_FOUND) {
        throw new Error(`登录凭证删除失败：${businessError.message}`);
      }
    }
  }

  private static async read(): Promise<StoredAuthSession | undefined> {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    query.set(asset.Tag.ALIAS, AuthSessionStore.toBytes(SESSION_ALIAS));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);

    let results: asset.AssetMap[];
    try {
      results = await asset.query(query);
    } catch (error) {
      const businessError = error as BusinessError;
      if (businessError.code === ASSET_NOT_FOUND) {
        return undefined;
      }
      throw new Error(`登录凭证读取失败：${businessError.message}`);
    }
    if (results.length === 0) {
      return undefined;
    }

    const secret = results[0].get(asset.Tag.SECRET);
    if (!(secret instanceof Uint8Array)) {
      await AuthSessionStore.clear();
      return undefined;
    }

    try {
      const text = new util.TextDecoder().decodeToString(secret);
      const stored = JSON.parse(text) as StoredAuthSession;
      AuthSessionStore.validate(stored);
      if (stored.refreshExpiresAt <= Date.now()) {
        await AuthSessionStore.clear();
        return undefined;
      }
      return stored;
    } catch (error) {
      await AuthSessionStore.clear();
      return undefined;
    }
  }

  private static validate(value: StoredAuthSession): void {
    if (!value || value.tokenType !== 'Bearer' ||
      !value.accessToken.startsWith('ark_access_') ||
      !value.refreshToken.startsWith('ark_refresh_') ||
      value.accessExpiresAt <= 0 ||
      value.refreshExpiresAt <= 0 ||
      !value.user ||
      value.user.id.trim().length === 0) {
      throw new Error('登录会话格式无效');
    }
  }

  private static async persist(stored: StoredAuthSession): Promise<void> {
    const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
    attributes.set(asset.Tag.ALIAS, AuthSessionStore.toBytes(SESSION_ALIAS));
    attributes.set(asset.Tag.SECRET, AuthSessionStore.toBytes(JSON.stringify(stored)));
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attributes.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try {
      await asset.add(attributes);
    } catch (error) {
      const businessError = error as BusinessError;
      throw new Error(`登录凭证安全保存失败：${businessError.message}`);
    }
  }

  private static toBytes(value: string): Uint8Array {
    return new util.TextEncoder().encodeInto(value);
  }
}
