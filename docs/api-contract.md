# API 契约

基础地址：`/api`

MVP 默认使用匿名设备 ID。客户端应在请求头中传入：

```http
X-Device-Id: <anonymous-device-id>
```

如果未传入，开发服务会使用 `demo-device`。

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

### GET /api/admin/categories

管理端分类列表。

### POST /api/admin/categories

新增分类。

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
  "knowledgePoints": ["ArkTS"]
}
```

### PATCH /api/admin/questions/{id}

更新题目，包括发布/下架、难度、知识点、解析等字段。
