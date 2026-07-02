# 全局个性化偏好

- 默认使用中文与用户交流，除非用户明确要求使用其他语言。
- 对用户的称呼优先使用“国强”；如需带姓氏，使用“刘国强”。
- 对于非代码事务，例如环境配置、工具接入、命令执行、问题排查、资料查询、网页/控制台操作指导等，不需要先复述并等待确认，可以直接执行。

# ArkInterview 项目规则

- 题库必须按模块维护在 `data/question-bank/modules/*.json`，不要直接手写 `data/seed/questions.json`。
- 新增题目前必须先查看对应模块文件和全局题库，避免重复题干、重复 ID、重复考察角度。
- 题目 ID 使用 `<categoryId>-NNN` 格式，例如 `arkts-001`、`stage-model-001`。
- 每道入库题必须有官方来源 `sourceRefs`、`verifiedAt`、`reviewStatus: "verified"`、正确答案或参考答案。
- 新增或修改题库后运行 `npm run questions:build`，提交前运行 `npm run questions:check` 或 `npm test`。
