# AI 工作交接

更新时间：2026-07-02

本文档用于后续 AI / 开发者接手 ArkInterview 时快速了解项目目标、当前状态、开发规则和下一步任务。每次完成较大的功能、修复或产品方向变化后，都应该同步更新本文档。

## 项目定位

Ark 面试通是面向鸿蒙开发者的原生刷题与面试训练 App。第一版只聚焦鸿蒙开发者，不做泛职业平台。

核心目标：

1. 稳定刷题。
2. 按模块练习。
3. 看答案解析。
4. 收集错题。
5. 收藏题目。
6. 记录练习进度。
7. 支持基础模拟面试。

第一版先验证鸿蒙开发者是否愿意使用，再考虑 AI 评分、面经分享、社区和会员功能。

## 当前技术方案

- App：HarmonyOS 原生应用，ArkTS + ArkUI + Stage 模型。
- 后端：Node.js REST API。
- 管理后台：简单静态后台。
- 题库：服务端维护，App 通过 REST API 获取。
- 用户：MVP 不强制登录，使用匿名设备 ID 保存记录。
- AI：后续可接入服务端 AI 评分，API Key 必须放服务端，不能放 App 端。

当前 App 配置：

- 展示名：Ark 面试通
- 包名：com.lgq.arkinterview
- API 地址：`entry/src/main/ets/app/AppConfig.ets` 中的 `API_BASE_URL`
- 当前调试地址：`http://192.168.62.105:8787/api`

## 当前项目状态

已完成：

1. HarmonyOS 工程骨架。
2. 后端 REST API 骨架。
3. 简单管理后台骨架。
4. 题库模块化维护。
5. 首页、练习页、答题页基础流程。
6. 分类练习、随机练习、错题练习、收藏练习、基础模拟面试入口。
7. 收藏、错题、练习记录相关接口和本地/服务端状态流转。
8. 平板优先首页布局第一版。
9. 公共底部导航基础可用：首页、错题练习、收藏练习、练习记录、答题页保持底部导航一致。
10. 练习记录页基础版：总答题、正确率、错题、收藏、分类完成度。
11. 错题再次答对后可在答题反馈中标记已掌握。
12. 记录页分类完成度卡片可直接进入对应分类练习。
13. 练习页平板双栏布局：左侧题目列表，右侧选中题目预览和开始答题。
14. 答题页平板双栏布局：左侧题干和作答，右侧答题提示或解析反馈。
15. 题库模块覆盖清单：`docs/question-bank-coverage.md`。
16. 首页平板布局右侧题库模块独立滚动，左侧学习概览和快捷训练保持稳定。
17. 答题页支持连续刷题上下文：上一题/下一题、提交后自动切下一题、右上角答题进度、题号状态面板。
18. 底部导航增加切换动效；答题页会继承练习来源导航状态，普通训练/分类训练高亮首页，错题和收藏高亮对应入口。
19. 答题页平板右侧从“答题提示”改为本轮状态面板，展示已答、正确、错误和题号状态。
20. 答题页增加本轮完成总结页：最后一题提交后自动进入总结，可复盘错题、查看未答、返回题单。
21. 练习页增加题单筛选：按模块、题型筛选；错题练习支持未掌握/全部错题切换，筛选后的题单会进入连续答题上下文。
22. 新增错题/收藏管理页：底部导航进入列表管理，可搜索、按模块/题型筛选、按当前筛选复习；收藏支持取消收藏，错题支持标记掌握。
23. 错题/收藏管理页增加难度筛选和排序：支持默认、按难度、按题型排序；错题页额外支持按错误次数排序。

题库当前状态：

- 模块数：16
- 题目数：40
- 模块文件目录：`data/question-bank/modules/*.json`
- 构建输出：`data/seed/questions.json`

## 题库规则

题库质量是这个项目的核心，不允许为了数量瞎写。

新增或修改题目前必须遵守：

1. 先看对应模块文件和全局题库，避免重复题干、重复 ID、重复考察角度。
2. 题目只能写入 `data/question-bank/modules/*.json`，不要直接手写 `data/seed/questions.json`。
3. 题目 ID 使用 `<categoryId>-NNN` 格式，例如 `arkts-001`、`stage-model-001`。
4. 每道入库题必须有：
   - `sourceRefs`
   - `verifiedAt`
   - `reviewStatus: "verified"`
   - 正确答案或参考答案
   - 解析
   - 知识点
5. 题目和答案必须以鸿蒙官方文档为主进行确认。
6. 不直接搬运 CSDN、掘金、公众号等平台题库和答案。
7. 可以参考知识点，但必须重新组织题目、答案和解析。

题库相关命令：

```bash
npm run questions:build
npm run questions:check
npm test
```

新增或修改题库后至少运行 `npm run questions:build`。提交前优先运行 `npm run questions:check` 或 `npm test`。

## UI 方向

用户明确反馈：手机不是唯一目标，平板体验优先，但手机也要兼容。

当前 UI 方向：

1. 平板优先。
2. 首页使用左右两栏工作台：
   - 左侧：标题、学习进度、正确率、快捷训练。
   - 右侧：题库模块列表。
3. 练习页和答题页使用居中阅读宽度，避免平板横向拉满。
4. 视觉风格偏开发工具 / 学习工具：
   - 浅灰背景
   - 白色卡片
   - 深蓝数据面板
   - 绿色、蓝色、橙色作为状态和模块辅助色
5. 不做营销页，不做花哨装饰，不用大面积紫色渐变。

最近 UI 相关提交：

- `3b6eca8 Improve tablet-first app layout`
- `abbc09b Align tablet home UI with preview`
- `c77dcf8 Top align tablet home columns`

## 构建与环境注意事项

用户本地 DevEco / 签名配置非常重要。不要随便动工程配置。

特别注意：

1. `build-profile.json5` 可能包含 DevEco 自动生成或用户本地签名配置。
2. 不要主动清理、重置或提交 `build-profile.json5`，除非用户明确要求。
3. 用户之前反馈每次改代码后重新同步、重新配置签名很烦，所以提交时必须只 stage 本次真正需要的文件。
4. 运行构建时，如果系统 `DEVECO_SDK_HOME` 无效，可临时指定：

```powershell
$env:DEVECO_SDK_HOME="E:\DevEco Studio11\sdk"
& "E:\DevEco Studio11\tools\hvigor\bin\hvigorw.bat" assembleApp --no-daemon
```

当前已知构建警告：

- `app_name` 在 AppScope 和 entry resources 中重复声明。
- ArkTS 对 `router.pushUrl`、`router.back`、`router.getParams`、`promptAction.showToast` 有 deprecated 警告。
- 这些目前不阻塞构建，但后续可以统一迁移。

## Git 规则

远端仓库：

```text
https://github.com/liuguoqiang0730-svg/ArkInterview.git
```

当前主分支：`main`

提交前检查：

```bash
git status --short
git diff --cached --stat
```

除非明确需要，否则不要提交：

- `build-profile.json5`
- DevEco 本地签名材料
- 无关格式化改动
- 生成产物

## 接下来建议任务

优先级 P0：

1. 继续对齐平板真实 UI 和预览方向，重点检查首页右侧滚动、答题页右侧状态面板、完成总结页、底部导航动效和自动切题节奏。
2. 真机检查平板底部导航是否遮挡内容，尤其是练习页、答题页和记录页。
3. 处理 ArkUI deprecated API 警告，优先迁移路由和 Toast。
4. 按 `docs/question-bank-coverage.md` 优先补空模块题库，入库前必须逐题核验官方来源。

优先级 P1：

1. 继续扩充题库，但必须按官方文档确认。
2. 为每个模块建立“已覆盖知识点”和“待补知识点”清单，防止重复出题。
3. 管理后台增加题目审核状态筛选。
4. 练习记录页补 UI 和接口联调。
5. 错题/收藏管理页继续增强，例如批量操作和题卡更密集的平板布局。

优先级 P2：

1. 后端接入真实数据库，替换本地 JSON 持久化。
2. 增加账号登录和云端同步。
3. 服务端 AI 简答题评分。
4. AI 模拟面试追问。
5. 每日一练。

暂缓：

1. 面经分享。
2. 用户投稿。
3. 评论区。
4. 排行榜。
5. 会员功能。

## 后续 AI 接手步骤

每次接手优先执行：

1. 阅读 `AGENTS.md`。
2. 阅读本文档。
3. 查看 `git status --short`，确认是否存在用户本地改动。
4. 如果涉及题库，阅读 `docs/question-authoring-guidelines.md` 和 `docs/question-bank-coverage.md`。
5. 如果涉及产品范围，阅读 `docs/product-scope.md` 和 `docs/roadmap.md`。
6. 如果涉及接口或数据结构，阅读 `docs/api-contract.md` 和 `docs/data-model.md`。
7. 开始改动前确认不要覆盖用户本地签名配置。

## 当前风险

1. 平板 UI 仍需真机反馈，当前只能通过构建验证，无法完全替代设备视觉检查。
2. 当前题库数量还偏少，MVP 需要持续扩充。
3. 部分 ArkUI API 已 deprecated，后续需要集中处理。
4. API 地址是局域网 IP，换网络或真机环境后需要调整。
5. 匿名设备 ID 目前是开发默认值，后续需要生成真实设备匿名 ID。
