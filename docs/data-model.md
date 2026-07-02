# 数据模型

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

## UserState

```json
{
  "deviceId": "demo-device",
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
      "questionId": "q-arkts-001",
      "categoryId": "arkts",
      "type": "single",
      "isCorrect": false,
      "submittedAt": "2026-07-02T00:00:00.000Z"
    }
  ]
}
```
