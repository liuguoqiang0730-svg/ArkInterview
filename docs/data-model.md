# 数据模型

运行时数据保存在 `backend/storage/arkinterview.sqlite`，当前 Schema 版本为 `3`。题库源文件仍按模块维护在 `data/question-bank/modules/*.json`，构建后同步到 SQLite；用户私有数据不进入 Git。

SQLite 当前使用以下业务表：

- `categories`、`questions`：分类和题目。
- `users`、`anonymous_devices`：应用内部用户与一个或多个匿名安装设备的映射。
- `favorites`、`wrong_questions`、`answer_attempts`：用户学习数据。
- `user_identities`：保存经过服务端验证的华为账号等外部身份与内部用户的映射。
- `auth_sessions`：保存 ArkInterview 自己签发的登录会话，包括访问令牌哈希、刷新令牌哈希、各自过期时间和吊销时间。

已关联外部身份的用户使用 `account/<users.id>` 形式的内部设备锚点加载运行时状态；该格式不符合客户端设备 ID 约束，不能通过请求头使用。真实匿名设备 ID 不再直接映射到账户用户，因此客户端漏传访问令牌或退出登录后，只能进入独立匿名空间，不能依靠设备 ID 读取账户数据。

## Category

```json
{
  "id": "arkts",
  "name": "ArkTS",
  "order": 1,
  "description": "ArkTS 语言基础、类型系统、装饰器与工程实践"
}
```

## Question

```json
{
  "id": "q-arkts-001",
  "categoryId": "arkts",
  "type": "single",
  "difficulty": "easy",
  "title": "题干",
  "options": [
    { "id": "a", "text": "选项 A" }
  ],
  "correctOptionIds": ["a"],
  "answerBoolean": null,
  "referenceAnswer": "",
  "scoringPoints": [],
  "explanation": "解析",
  "knowledgePoints": ["ArkTS"],
  "sourceRefs": [
    {
      "title": "ArkTS 概述",
      "url": "https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-overview-V5",
      "publisher": "Huawei Developer"
    }
  ],
  "verifiedAt": "2026-07-02",
  "reviewStatus": "verified",
  "status": "published",
  "createdAt": "2026-07-02T00:00:00.000Z",
  "updatedAt": "2026-07-02T00:00:00.000Z"
}
```

题型约定：

- `single`：只使用 `options` 和单个 `correctOptionIds`。
- `multiple`：使用 `options` 和多个 `correctOptionIds`。
- `boolean`：使用 `answerBoolean`。
- `short`：使用 `referenceAnswer` 和 `scoringPoints`。

入库约束：

- 保存到运行题库前必须有官方 `sourceRefs`。
- 保存到运行题库前 `reviewStatus` 必须是 `verified`。
- 保存到运行题库前必须填写 `verifiedAt`。
- 后端只允许 `developer.huawei.com`、`docs.openharmony.cn`、`gitee.com/openharmony/docs` 作为官方来源域名。

## UserState

```json
{
  "id": "user-uuid",
  "deviceId": "demo-device",
  "deviceIds": ["demo-device"],
  "displayName": "",
  "avatarUrl": "",
  "leaderboardOptIn": false,
  "leaderboardOptedInAt": null,
  "status": "active",
  "createdAt": "2026-07-02T00:00:00.000Z",
  "updatedAt": "2026-07-02T00:00:00.000Z",
  "favorites": ["q-arkts-001"],
  "wrongs": {
    "q-arkts-001": {
      "questionId": "q-arkts-001",
      "wrongCount": 1,
      "mastered": false,
      "updatedAt": "2026-07-02T00:00:00.000Z"
    }
  },
  "answers": [
    {
      "id": "attempt-uuid",
      "questionId": "q-arkts-001",
      "categoryId": "arkts",
      "type": "single",
      "isCorrect": false,
      "leaderboardEligible": false,
      "submittedAt": "2026-07-02T00:00:00.000Z"
    }
  ]
}
```

匿名设备 ID 不是公开用户 ID。后续接入华为账号时，服务端应继续使用内部 `users.id` 关联学习数据，并通过 `user_identities` 保存服务端验证后的 OpenID/UnionID 映射，不能直接信任客户端上报的外部账号标识。

`leaderboardOptedInAt` 在用户第一次主动参与排行榜时写入，退出排行榜时保留，重新参与不会重置。每次作答还会固化 `leaderboardEligible`：只有已登录且答题当时处于参与状态时为 `true`。排行榜同时校验授权时间和该标记，因此匿名历史及退出排行榜期间的作答不会被补算。
