# 可选用户系统设计

## 产品原则

- App 不登录也能完成刷题、收藏、错题和练习记录等核心流程。
- 登录是匿名用户的账号升级，用于跨设备同步、数据恢复和后续排行榜。
- 第一版只接入华为 Account Kit，不建设手机号、密码、短信验证码和找回密码体系。
- 第一版不主动申请手机号或邮箱，仅获取完成身份关联所需的稳定账号标识。

## 身份模型

ArkInterview 必须保留自己的内部用户 ID，不能把匿名设备 ID 或华为 OpenID 直接作为所有业务表的主键。

- `users.id`：ArkInterview 内部用户 ID。
- `anonymous_devices`：一个内部用户可关联多个安装设备，保存匿名设备 ID 与 `users.id` 的映射。
- `user_identities`：外部身份映射，保存 `provider`、`provider_subject` 和可选 `union_id`。
- `auth_sessions`：ArkInterview 自己的登录会话，只保存访问令牌与刷新令牌哈希、各自过期时间和吊销时间。

华为账号授权码和 Client Secret 必须在服务端完成兑换与验证。App 登录成功后使用 ArkInterview 后端签发的访问令牌，不直接把客户端上报的 OpenID 当成已登录凭证。

服务端实现依据华为官方 Authorization Code 流程：后端向 `oauth2/v3/token` 兑换授权码，再使用服务端获得的 access token 调用官方用户信息接口。华为 access token 和 refresh token 只用于本次身份验证，不写入 ArkInterview 数据库。

官方依据：

- [Account Kit](https://developer.huawei.com/consumer/cn/sdk/account-kit)
- [Authorization Code 登录示例](https://developer.huawei.com/consumer/en/codelab/HMSAccounts/index.html)
- [获取用户信息 REST API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/account-api-otherscene-getuserinfo-V5)
- [获取应用级 Access Token](https://developer.huawei.com/consumer/en/doc/harmonyos-references/account-api-obtain-app-token)

## 首次登录合并

首次登录请求同时携带华为账号授权码和当前匿名设备 ID。服务端在单个事务中完成：

1. 验证授权码并获取稳定的华为账号身份标识。
2. 创建或查找内部用户。
3. 将匿名收藏做并集合并。
4. 按答题记录 ID 去重合并练习历史。
5. 错题次数依据答题记录重新计算，掌握状态按最后更新时间处理。
6. 标记匿名设备记录已经归属该账号，防止重复合并。
7. 签发 ArkInterview 访问令牌和刷新令牌。

退出登录后必须切换到新的匿名会话，不能继续读取上一位登录用户的云端数据。

## 排行榜边界

- 只有已登录并主动开启 `leaderboardOptIn` 的用户参与。
- 默认使用 ArkInterview 脱敏昵称，不直接公开华为账号标识。
- 只统计服务端确认的已发布、已核验客观题。
- 同一道题应按首次作答或首次正确计分，防止重复刷分。
- 简答题自评暂不计分。
- 匿名历史记录可以合并到学习档案，但默认不折算排行榜积分。
- 榜单至少提供周榜、总榜和分类榜，并保留异常频率检测和封禁入口。

## 实施顺序

1. 已完成：SQLite 分表存储、旧 JSON 迁移和 Schema v1 到 v2 升级。
2. 已完成：服务端授权码验证、内部访问/刷新会话和令牌轮换。
3. 已完成：匿名收藏、错题和答题记录事务合并，以及登录账户与匿名设备隔离。
4. 已完成：HarmonyOS Account Kit 官方登录按钮和 Authorization Code 上报。
5. 已完成：“我的”页面、AssetStore 登录状态恢复、Token 自动刷新和退出登录。
6. 待完成：AGC 正式配置、生产 HTTPS 和真实华为账号联调。
7. 待完成：账号注销。
8. 待完成：排行榜统计与展示。
