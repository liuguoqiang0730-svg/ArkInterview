export const HUAWEI_CLIENT_ID: string = 'HUAWEI_CLIENT_ID_PENDING';

export class HuaweiAccountConfig {
  static isConfigured(): boolean {
    return HUAWEI_CLIENT_ID !== 'HUAWEI_CLIENT_ID_PENDING' &&
      HUAWEI_CLIENT_ID.trim().length > 0;
  }
}
