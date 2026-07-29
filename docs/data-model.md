# 数据模型

运行时数据保存在 `backend/storage/arkinterview.sqlite`，当前 Schema 版本为 `4`。题库源文件仍按模块维护在 `data/question-bank/modules/*.json`，构建后同步到 SQLite；用户私有数据不进入 Git。

SQLite 当前使用以下业务表：

- `categories`、`questions`：分类和题目。
- `users`、`anonymous_devices`：应用内部用户与一个或多个匿名安装设备的映射。
- `favorites`、`wrong_questions`、`answer_attempts`：用户学习数据。练习记录页直接从 `answer_attempts` 分页读取完整历史，并按北京时间动态聚合每日作答量与正确率趋势；明细与趋势都不额外维护重复统计表。简答题没有自动判分结果，不计入正确率分母。
- `user_identities`：保存经过服务端验证的华为账号等外部身份与内部用户的映射。
- `auth_sessions`：保存 ArkInterview 自己签发的登录会话，包括访问令牌哈希、刷新令牌哈希、各自过期时间和吊销时间。
- `user_moderation_events`：保存管理员对登录账号执行的封禁/解封动作、原因和时间，作为不可由客户端修改的操作审计记录。

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
  "reviewNote": "已完成官方文档复核",
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

- 草稿和下架题可以使用 `needs_review` 或 `rejected`，并通过仅后台可见的 `reviewNote` 记录核验过程。
- 保存到公开运行题库前必须有官方 `sourceRefs`。
- 保存到公开运行题库前 `reviewStatus` 必须是 `verified`。
- 保存到公开运行题库前必须填写 `verifiedAt`。
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

## 排行榜治理

- `users.status` 仅允许业务层使用 `active` 或 `suspended`。公开榜单只返回状态正常且当前主动参与的账号。
- 异常频率检测基于答题时已固化的 `leaderboardEligible` 记录，当前复核阈值为 60 秒 15 次或 5 分钟 40 次；更高阈值标记为高风险。系统只标记，不自动封禁。
- 管理后台审计会保留封禁账号的历史合规积分，避免封禁后审计数据归零；公开排行榜仍会立即移除该账号。
- 封禁动作在同一事务中更新用户状态、写入 `user_moderation_events` 并吊销该用户全部有效登录会话。解封不会恢复旧会话，用户必须重新登录。
- 已封禁的华为身份不能通过新的 Authorization Code 再次创建 ArkInterview 会话。
