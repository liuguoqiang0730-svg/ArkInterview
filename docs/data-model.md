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
