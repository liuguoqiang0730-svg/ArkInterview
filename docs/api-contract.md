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

返回答题数量、正确率、分类完成度和最近练习时间。

分类统计中的 `attempts` 是作答次数，`answered` 是去重后的已答题目数，`completionRate` 基于去重题目数计算。

### GET /api/users/me/wrongs

返回错题列表。

### POST /api/users/me/wrongs/{questionId}/mastered

将错题标记为已掌握。

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

## 管理后台

所有 `/api/admin/*` 请求都必须携带服务端环境变量 `ADMIN_TOKEN` 对应的 Bearer Token：

```http
Authorization: Bearer <ADMIN_TOKEN>
```

- 未携带或令牌错误：返回 `401`。
- 服务端未配置 `ADMIN_TOKEN`：返回 `503`，管理接口关闭。
- `ADMIN_TOKEN` 至少 32 个字符，不能写入仓库或前端源码。
- 公网调用必须使用 HTTPS。

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
  "reviewStatus": "verified"
}
```

保存题目入库时，后端会要求 `sourceRefs` 至少包含一个官方来源，`reviewStatus` 为 `verified`，且 `verifiedAt` 已填写。
模块化题库还会携带非负整数 `order`，用于保持模块内题目顺序。

### PATCH /api/admin/questions/{id}

更新题目，包括发布/下架、难度、知识点、解析等字段。

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
