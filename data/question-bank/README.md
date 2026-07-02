# 模块化题库维护说明

题库源数据按模块拆分维护在 `data/question-bank/modules/*.json`。不要直接编辑 `data/seed/questions.json`，它是后端运行用的聚合文件，由脚本生成。

## 目录规则

- `manifest.json`：登记所有题库模块、分类 ID、模块文件和题目 ID 前缀。
- `modules/<categoryId>.json`：对应分类的题目源数据。
- `../seed/questions.json`：由 `npm run questions:build` 生成，后端只读取这个文件。

## 新增题目流程

1. 打开 `manifest.json` 找到分类对应的模块文件。
2. 先搜索对应模块和全局题库，确认题干、ID、考察角度没有重复。
3. 新题 ID 使用 `<categoryId>-NNN`，例如 `arkts-001`。
4. 只把已经按官方文档核验过的题放进模块文件。
5. 运行 `npm run questions:build` 生成聚合题库。
6. 运行 `npm run questions:check` 或 `npm test` 做查重和字段校验。

## 去重口径

脚本会拦截：

- 重复题目 ID。
- 规范化后重复的题干。
- 分类 ID 和模块文件不一致。
- 非官方来源链接。
- 缺少正确答案、解析、知识点或核验信息。

同一个知识点可以多次考，但必须换题型或换考察角度，不能只改写题干。
