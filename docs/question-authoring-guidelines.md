# 题库编写与审核规范

Ark 面试通的题库必须以官方文档为第一来源，面向鸿蒙开发者真实面试场景设计。题目不能直接搬运 CSDN、掘金、公众号或其他题库内容，也不能用未经核验的 AI 输出直接入库。

## 来源优先级

1. 华为开发者官网 HarmonyOS 文档：`developer.huawei.com`
2. OpenHarmony 官方文档：`docs.openharmony.cn`
3. OpenHarmony docs 仓库：`gitee.com/openharmony/docs`

招聘 JD、开源项目、样例项目和个人经验只能用于发现高频能力点，不能作为事实答案的唯一依据。

## 发布规则

题目发布前必须满足：

1. `sourceRefs` 至少包含一个官方文档来源。
2. `reviewStatus` 必须是 `verified`。
3. `verifiedAt` 必须填写核验日期。
4. 题干、正确答案、解析、评分点都要能从官方文档或官方 API 行为推出。
5. 如果官方文档有版本差异，题目必须明确适用范围，例如 HarmonyOS NEXT、API 版本或 Stage 模型。

后端会拦截未核验或没有官方来源的发布请求。

## 编写要求

- 题干要贴近鸿蒙开发者日常开发和面试表达，避免“背概念”的空泛问题。
- 选择题的错误选项必须是常见误区，不能故意写明显荒谬选项凑数。
- 简答题必须包含参考答案和评分点，第一版由用户自评。
- 解析不能只说“因为官方文档这样写”，必须解释开发语境和易错点。
- 不确定、版本变化快、官方表述不明确的内容先放草稿，不发布。

## 审核流程

1. 根据官方文档提炼知识点。
2. 写题干、答案、解析、知识点和来源。
3. 标记 `needs_review`，先保存为草稿。
4. 人工对照官方文档逐项核验。
5. 核验通过后设置 `reviewStatus=verified` 和 `verifiedAt`。
6. 发布题目。

## 官方来源字段

```json
{
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
