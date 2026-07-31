export const HUAWEI_CLIENT_ID: string = '6917612395530063101';

export class HuaweiAccountConfig {
  static isConfigured(): boolean {
    return HUAWEI_CLIENT_ID !== 'HUAWEI_CLIENT_ID_PENDING' &&
      HUAWEI_CLIENT_ID.trim().length > 0;
  }
}
