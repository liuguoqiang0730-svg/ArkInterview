# 华为账号登录配置

ArkInterview 的账号登录是可选能力。未登录时，刷题、收藏、错题和练习记录继续使用匿名设备档案；完成华为账号登录后，服务端把当前匿名学习记录合并到 ArkInterview 内部账号。

## 前置条件

1. 在 AppGallery Connect 创建 HarmonyOS 应用，包名必须是 `com.lgq.arkinterview`。
2. 为应用开通 Account Kit，并配置当前调试/发布证书的 SHA-256 指纹。
3. 创建 OAuth 2.0 客户端，取得 Client ID、Client Secret，并登记服务端使用的 Redirect URI。
4. 为 ArkInterview API 配置可信 HTTPS 域名和证书。

Account Kit 官方资料：

- [Account Kit 产品页](https://developer.huawei.com/consumer/cn/sdk/account-kit)
- [获取用户信息 REST API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/account-api-otherscene-getuserinfo-V5)
- [Authorization Code 登录示例](https://developer.huawei.com/consumer/en/codelab/HMSAccounts/index.html)

AGC 控制台界面和字段名称可能随版本调整，应以当前官方控制台和 Account Kit 文档为准。

## 客户端配置

把同一个 OAuth Client ID 填入以下两处：

`entry/src/main/module.json5`

```json5
"metadata": [
  {
    "name": "client_id",
    "value": "<AGC OAuth Client ID>"
  }
]
```

`entry/src/main/ets/app/HuaweiAccountConfig.ets`

```typescript
export const HUAWEI_CLIENT_ID: string = '<AGC OAuth Client ID>';
```

然后把 `entry/src/main/ets/app/AppConfig.ets` 的 `API_BASE_URL` 改为正式 HTTPS 地址：

```typescript
export const API_BASE_URL: string = 'https://api.example.com/api';
```

客户端只保存 Client ID。禁止把 Client Secret、华为 access token 或 ArkInterview 明文令牌写入源码、资源文件、日志和截图。

## 服务端配置

在服务器环境中配置：

```bash
export HUAWEI_CLIENT_ID="<AGC OAuth Client ID>"
export HUAWEI_CLIENT_SECRET="<server-only Client Secret>"
export HUAWEI_REDIRECT_URI="<AGC 中登记的 Redirect URI>"
```

三项必须同时存在。服务端启动后检查：

```bash
curl https://api.example.com/api/auth/status
```

期望结果：

```json
{
  "huaweiLoginEnabled": true,
  "anonymousUsageEnabled": true
}
```

## 客户端安全行为

- App 使用 Account Kit 官方 `LoginWithHuaweiIDButton` 获取一次性 Authorization Code。
- App 只把 Authorization Code 和匿名设备 ID 发给 ArkInterview 服务端。
- 服务端使用 Client Secret 兑换并验证华为账号信息，再签发 ArkInterview 自己的访问令牌和刷新令牌。
- App 使用系统 AssetStore 加密保存 ArkInterview 会话，不使用 Preferences 明文保存 Token。
- 访问令牌过期后，网络层自动轮换访问令牌和刷新令牌；刷新凭证被服务端拒绝时清除本地会话。
- API 地址不是 HTTPS 时，App 不展示登录按钮，也不会发送 Authorization Code 或 ArkInterview Token。

## 验收清单

1. 未登录时可以正常刷题、收藏、查看错题和记录。
2. “我的”页显示 Account Kit 官方登录按钮，协议未勾选时不能继续登录。
3. 首次登录后，当前设备的匿名收藏、错题和答题记录仍然存在。
4. 杀掉并重启 App 后，登录状态可以从 AssetStore 恢复。
5. 访问令牌过期后，普通接口可自动刷新并继续请求。
6. 退出登录后切换到新的匿名档案，不能读取刚才账号的云端数据。
7. 将 API 地址临时改成 HTTP 后，页面明确显示等待 HTTPS，抓包中没有账号凭证。

真实登录验收必须同时使用 AGC 中登记的包名、证书指纹和 Client ID。更换签名证书后，要同步更新 AGC 指纹配置。
