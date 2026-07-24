const defaultTokenEndpoint = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
const defaultUserInfoEndpoint =
  'https://account.cloud.huawei.com/rest.php?nsp_svc=GOpen.User.getInfo';

export class HuaweiAccountClient {
  constructor({
    clientId,
    clientSecret,
    redirectUri,
    fetchImpl = globalThis.fetch,
    tokenEndpoint = defaultTokenEndpoint,
    userInfoEndpoint = defaultUserInfoEndpoint,
    timeoutMs = 10000
  }) {
    this.clientId = String(clientId || '').trim();
    this.clientSecret = String(clientSecret || '').trim();
    this.redirectUri = String(redirectUri || '').trim();
    this.fetchImpl = fetchImpl;
    this.tokenEndpoint = tokenEndpoint;
    this.userInfoEndpoint = userInfoEndpoint;
    this.timeoutMs = timeoutMs;
  }

  isConfigured() {
    return Boolean(this.clientId && this.clientSecret && this.redirectUri);
  }

  async exchangeAuthorizationCode(authorizationCode) {
    if (!this.isConfigured()) {
      throw new AccountProviderError(503, '华为账号登录尚未配置');
    }

    const code = String(authorizationCode || '').trim();
    if (!code) {
      throw new AccountProviderError(400, '华为账号授权码不能为空');
    }

    const tokenPayload = await this.postForm(this.tokenEndpoint, {
      grant_type: 'authorization_code',
      code,
      client_id: this.clientId,
      client_secret: this.clientSecret,
      redirect_uri: this.redirectUri
    }, '华为账号授权码无效或已过期');

    const accessToken = String(tokenPayload.access_token || '').trim();
    if (!accessToken) {
      throw new AccountProviderError(502, '华为账号服务未返回访问凭证');
    }

    const profile = await this.postForm(this.userInfoEndpoint, {
      access_token: accessToken,
      getNickName: '0'
    }, '无法获取华为账号用户信息', { inspectNspStatus: true });

    const openId = String(profile.openID || '').trim();
    if (!openId) {
      throw new AccountProviderError(502, '华为账号服务未返回用户身份标识');
    }

    return {
      providerSubject: openId,
      unionId: String(profile.unionID || '').trim(),
      displayName: String(profile.displayName || '').trim(),
      avatarUrl: String(profile.headPictureURL || '').trim()
    };
  }

  async postForm(url, values, rejectedMessage, { inspectNspStatus = false } = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    let response;

    try {
      response = await this.fetchImpl(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams(values),
        signal: controller.signal
      });
    } catch (error) {
      if (error?.name === 'AbortError') {
        throw new AccountProviderError(504, '华为账号服务请求超时');
      }
      throw new AccountProviderError(502, '无法连接华为账号服务');
    } finally {
      clearTimeout(timeout);
    }

    const payload = await readJsonResponse(response);
    const nspStatus = inspectNspStatus ? response.headers.get('nsp_status') : null;
    if (!response.ok || payload.error || (nspStatus && nspStatus !== '0')) {
      const status = response.status >= 500 ? 502 : 401;
      throw new AccountProviderError(status, rejectedMessage);
    }
    return payload;
  }
}

export class AccountProviderError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'AccountProviderError';
    this.status = status;
  }
}

async function readJsonResponse(response) {
  try {
    return await response.json();
  } catch {
    throw new AccountProviderError(502, '华为账号服务返回了无法解析的数据');
  }
}
