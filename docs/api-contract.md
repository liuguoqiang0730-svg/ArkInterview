# API 契约

基础地址：`/api`

MVP 默认使用匿名设备 ID。客户端应在请求头中传入：

```http
X-Device-Id: <anonymous-device-id>
```

如果未传入，开发服务会使用 `demo-device`。

App 首次启动时使用安全随机 UUID 生成 `ark-<uuid>` 格式的匿名设备 ID，并保存到应用私有 Preferences。后续启动继续使用同一个 ID，因此答题记录、错题和收藏可以在本机持续关联；不同安装的数据相互隔离。清除应用数据或卸载重装后会生成新的 ID。登录用户可通过华为账号合并不同设备的匿名学习记录。

## 可选登录

匿名模式始终可用。登录后，客户端在需要读取或写入用户数据的请求中携带 ArkInterview 访问令牌：

```http
Authorization: Bearer <ark_access_token>
```

不允许把华为 OpenID、华为 access token 或客户端自行生成的用户 ID 当作 ArkInterview 登录凭证。

### GET /api/auth/status

返回服务端是否已启用华为账号登录。未配置华为凭据时 `huaweiLoginEnabled` 为 `false`，匿名模式不受影响。

### POST /api/auth/huawei

App 通过 Account Kit 获取 Authorization Code 后，将授权码和当前 `X-Device-Id` 发给 ArkInterview 服务端：

```json
{
  "authorizationCode": "<authorization-code>"
}
```

服务端使用华为凭据兑换并验证账号身份，随后在一个事务中创建或查找内部用户、合并当前匿名学习记录并签发 ArkInterview 自己的访问令牌和刷新令牌。服务端未完整配置华为凭据时返回 `503`。

### POST /api/auth/refresh

```json
{
  "refreshToken": "<ark_refresh_token>"
}
```

刷新成功后访问令牌和刷新令牌都会轮换，旧令牌立即失效。

### POST /api/auth/logout

需要携带有效的 ArkInterview 访问令牌。服务端吊销当前会话；客户端应删除访问令牌和刷新令牌，后续请求恢复为匿名模式。

### GET /api/users/me/profile

匿名请求返回 `authenticated: false`；携带有效访问令牌时返回 ArkInterview 内部用户 ID、展示名、头像和排行榜参与设置。

### PUT /api/users/me/leaderboard-preference

仅允许已登录用户修改是否参与排行榜，匿名请求返回 `401`。该设置默认关闭，客户端必须由用户主动操作开启。

```json
{
  "enabled": true
}
```

`enabled` 必须是 JSON 布尔值。成功后返回最新的登录用户资料，客户端应同步更新本地用户快照。关闭后，后续排行榜查询不得再公开该用户；历史答题记录本身不会被删除。

### GET /api/leaderboards

读取公开排行榜，匿名用户也可以查看；登录用户使用 HTTPS 携带有效访问令牌时，响应会标记自己的榜单项并返回 `me`。支持参数：

- `scope`：`weekly` 或 `overall`，默认 `weekly`。
- `categoryId`：可选；为空时统计全部模块，传值时生成对应分类榜。
- `limit`：可选，默认 `50`，范围 `1` 到 `100`。

```json
{
  "scope": "weekly",
  "categoryId": "arkts",
  "categoryName": "ArkTS",
  "periodStart": "2026-07-19T16:00:00.000Z",
  "generatedAt": "2026-07-24T09:00:00.000Z",
  "scoringRule": "first_correct_after_opt_in_per_verified_objective_question",
  "totalParticipants": 2,
  "entries": [
    {
      "rank": 1,
      "displayName": "Ark开发者·A1B2",
      "score": 12,
      "lastScoredAt": "2026-07-23T08:00:00.000Z",
      "isCurrentUser": false
    }
  ],
  "me": null
}
```

计分规则：

- 只有已绑定外部身份、状态正常且主动参与排行榜的用户进入榜单。
- 开启参与时记录 `leaderboardOptedInAt`，并在每次作答时固化是否具备榜单资格；匿名历史和退出排行榜期间的答题不计分。
- 仅统计当前仍为已发布、已核验状态的单选题、多选题和判断题。
- 每个用户、每道题只取参与后的首次正确作答，每题最多 `1` 分。
- 周榜按北京时间周一 `00:00` 开始，只统计本周产生的合规首次正确作答。
- 同分时，越早完成最后一道得分题的用户排名越靠前。
- 响应只提供稳定脱敏昵称，不提供华为账号资料、头像或 ArkInterview 内部用户 ID。

访问令牌默认有效期 15 分钟，刷新令牌默认有效期 30 天。数据库只保存两类令牌的 SHA-256 哈希，不保存明文令牌，也不保存华为 access token 或 refresh token。

## 题库

### GET /api/categories

返回全部分类。

### GET /api/questions

查询题目列表。

Query 参数：

- `categoryId`：可选，分类 ID。
- `type`：可选，`single`、`multiple`、`boolean`、`short`。
- `page`：可选，默认 `1`。
- `pageSize`：可选，默认 `20`。

### GET /api/questions/{id}

返回题目详情。

## 基础模拟面试

### GET /api/interviews/basic

生成一组基础模拟面试题。接口会优先混合简答题、单选题、多选题和判断题。

Query 参数：

- `categoryId`：可选，限定分类。
- `count`：可选，默认 `8`，最大 `30`。

返回示例：

```json
{
  "sessionId": "interview-1782960000000",
  "mode": "basic",
  "total": 4,
  "items": []
}
```

## 练习会话

### GET /api/practice/session

生成一组练习题，不返回正确答案。客户端进入题目详情或提交答案后再展示解析。

Query 参数：

- `mode`：练习模式，支持 `category`、`random`、`wrongs`、`favorites`，默认 `random`。
- `categoryId`：可选。`mode=category` 时必填；`mode=random` 时可用于限制分类。
- `type`：可选，`single`、`multiple`、`boolean`、`short`。
- `count`：可选，默认 `10`，最大 `50`。

示例：

```http
GET /api/practice/session?mode=category&categoryId=arkui&count=20
GET /api/practice/session?mode=random&count=10
GET /api/practice/session?mode=wrongs&count=20
GET /api/practice/session?mode=favorites&count=20
```

## 答题

### POST /api/answers/submit

请求体示例：

```json
{
  "questionId": "q-arkts-001",
  "selectedOptionIds": ["b"]
}
```

判断题示例：

```json
{
  "questionId": "q-stage-001",
  "answerBoolean": true
}
```

简答题示例：

```json
{
  "questionId": "q-arkui-003",
  "shortAnswer": "用户输入的答案"
}
```

选择题和判断题会返回 `isCorrect`。简答题第一版返回参考答案和评分点，`isCorrect` 为 `null`。

## 用户状态

### GET /api/users/me/stats

返回答题数量、正确率、分类完成度、最近练习时间、最近 12 次作答记录和按日聚合的历史趋势。

分类统计中的 `attempts` 是作答次数，`answered` 是去重后的已答题目数，`completionRate` 基于去重题目数计算。分类正确率只统计可以自动判分的客观题，`isCorrect=null` 的简答题不计入正确率分母。

`recentRecords` 按提交时间倒序返回，包含作答记录 ID、题目 ID、题干、分类、题型、判定结果和提交时间。简答题的 `isCorrect` 为 `null`；历史题目下架后仍保留作答记录，题干显示为“题目已下架”。

`dailyStats` 按北京时间自然日升序返回历史活跃日，字段包括：

- `date`：`YYYY-MM-DD` 日期。
- `attempts`：当天全部提交次数。
- `gradedAttempts`：当天可自动判分的提交次数。
- `correct`：当天正确次数。
- `accuracy`：`correct / gradedAttempts`；当天只有简答题时为 `0`。

### GET /api/users/me/records

分页返回当前匿名设备或登录账号的完整作答历史，按提交时间倒序排列。

Query 参数：

- `page`：页码，默认 `1`。
- `pageSize`：每页数量，默认 `20`，最大 `50`。
- `date`：可选，北京时间自然日，格式必须为 `YYYY-MM-DD`。

返回字段沿用通用分页结构：`items`、`page`、`pageSize`、`total`、`totalPages`，并附带当前 `date` 过滤值。每条记录包含题目 ID、题干、分类、题型、判定结果和提交时间。

### GET /api/users/me/wrongs

返回全部错题，包括已标记掌握的题目。客户端通过每题的 `wrong.mastered` 区分未掌握和已掌握；`mode=wrongs` 的练习会话仍只抽取未掌握错题。

### POST /api/users/me/wrongs/{questionId}/mastered

将错题标记为已掌握。

### POST /api/users/me/wrongs/mastered

批量将错题标记为已掌握。一次支持 1 至 200 个去重后的题目 ID，整批校验通过后在一个 SQLite 事务中写入。

```json
{
  "questionIds": ["arkts-001", "arkui-001"]
}
```

若任一题目的错题状态已经不存在，返回 `409`，整批不写入。

### GET /api/users/me/favorites

返回收藏题目列表。

### POST /api/users/me/favorites

请求体：

```json
{
  "questionId": "q-arkts-001"
}
```

### DELETE /api/users/me/favorites/{questionId}

取消收藏。

### POST /api/users/me/favorites/remove

批量取消收藏。请求体同批量标记掌握接口，一次支持 1 至 200 个题目 ID。若任一题目已不在收藏列表中，返回 `409`，整批不写入。

## 管理后台

所有 `/api/admin/*` 请求都必须携带服务端环境变量 `ADMIN_TOKEN` 对应的 Bearer Token：

```http
Authorization: Bearer <ADMIN_TOKEN>
```

- 未携带或令牌错误：返回 `401`。
- 服务端未配置 `ADMIN_TOKEN`：返回 `503`，管理接口关闭。
- `ADMIN_TOKEN` 至少 32 个字符，不能写入仓库或前端源码。
- 公网调用必须使用 HTTPS。

### GET /api/admin/leaderboard/users

读取已绑定外部身份的排行榜账号审计列表。支持查询参数：

- `risk`：`all`、`flagged`、`normal`、`review` 或 `high`。
- `status`：`all`、`active` 或 `suspended`。
- `q`：按展示名、内部用户 ID 或身份提供方搜索，最长 100 个字符。

响应包含账号总数、参与数、待复核数、封禁数，以及每个账号的历史积分、有效提交数、正确率、60 秒/5 分钟峰值、风险原因和最近一次管理员操作。异常检测只提供复核信号，不会自动封禁。

### PATCH /api/admin/leaderboard/users/{userId}/status

封禁或解封已绑定账号。请求体：

```json
{
  "status": "suspended",
  "reason": "一分钟内连续提交次数异常，人工复核后暂停排行榜资格"
}
```

- `status` 仅允许 `active` 或 `suspended`。
- `reason` 必须包含 4 至 300 个字符。
- 封禁会立即从公开排行榜移除账号、吊销全部有效 ArkInterview 登录会话，并阻止该华为身份重新登录。
- 解封后旧会话不会恢复，用户需要重新登录。
- 每次状态变化都会写入独立审计记录；重复设置相同状态返回 `409`。

### GET /api/admin/categories

管理端分类列表。

### POST /api/admin/categories

新增分类。

### PATCH /api/admin/categories/{id}

更新分类名称、排序或说明，不允许修改分类 ID。

### GET /api/admin/questions

管理端题目列表。

### POST /api/admin/questions

新增题目。

请求体核心字段：

```json
{
  "categoryId": "arkts",
  "type": "single",
  "difficulty": "medium",
  "status": "draft",
  "title": "题干",
  "options": [
    { "id": "a", "text": "选项 A" },
    { "id": "b", "text": "选项 B" }
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
  "reviewNote": "已对照 ArkTS 官方文档复核，答案与当前 API 行为一致"
}
```

`draft` 或 `offline` 题目可以使用 `needs_review` / `rejected` 审核状态保存，供后台继续整理；任何 `published` 题目必须满足 `reviewStatus=verified`、填写 `verifiedAt`，并至少包含一个官方 `sourceRefs`。`reviewNote` 最长 2000 个字符，仅供管理后台记录待核验点、复核结论或修改原因，不会返回给公开题目接口。
模块化题库还会携带非负整数 `order`，用于保持模块内题目顺序。

### PATCH /api/admin/questions/{id}

更新题目，包括分类、题型、发布状态、审核状态、难度、选项、答案、知识点、解析、官方来源、排序和审核备注等字段。题目 ID 不允许修改。

### PATCH /api/admin/questions/batch-status

批量发布或下架题目。

```json
{
  "questionIds": ["arkts-001", "arkts-002"],
  "status": "published"
}
```

- `questionIds` 必须包含 1 至 500 个有效题目 ID，重复 ID 会自动去重。
- `status` 仅允许 `published` 或 `offline`。
- 后端会对整批题目重新执行题库质量校验；任一题不存在或校验失败时整批拒绝，不写入部分结果。
- 成功后返回更新后的 `items` 数组。
