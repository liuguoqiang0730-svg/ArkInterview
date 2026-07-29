# AI 工作交接

更新时间：2026-07-29

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
- 当前服务器地址：`http://47.97.45.170:8787/api`

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
17. 答题页支持连续刷题上下文：上一题/下一题、提交后停留当前题查看解析、右上角答题进度、题号状态面板；切题完全由用户操作。
18. 底部导航增加切换动效；答题页会继承练习来源导航状态，普通训练/分类训练高亮首页，错题和收藏高亮对应入口。
19. 答题页平板右侧从“答题提示”改为本轮状态面板，展示已答、正确、错误和题号状态。
20. 答题页增加本轮完成总结页：本轮答完后由用户点击“查看本轮结果”进入，可复盘错题、查看未答、返回题单。
21. 练习页增加题单筛选：按模块、题型筛选；错题练习支持未掌握/全部错题切换，筛选后的题单会进入连续答题上下文。
22. 新增错题/收藏管理页：底部导航进入列表管理，可搜索、按模块/题型筛选、按当前筛选复习；收藏支持取消收藏，错题支持标记掌握。
23. 错题/收藏管理页增加难度筛选和排序：支持默认、按难度、按题型排序；错题页额外支持按错误次数排序。
24. 路由和 Toast 已统一封装到 `entry/src/main/ets/utils/AppRouter.ets` 和 `entry/src/main/ets/utils/AppToast.ets`，页面层不再直接调用 `router` / `promptAction.showToast`。
25. 新增“常见面试题分享”独立页面：`entry/src/main/ets/pages/InterviewExperiencePage.ets`，首页单独入口，包含 16 个高频开放面试题、解释答案、面试要点、官方依据；可匹配的题目会直接展示华为开发者文档官方 CDN 图片，纯文字 API 题保留结构化学习图。
26. 新增题库数据库同步脚本：`scripts/sync-question-db.mjs`，支持增量 upsert、预演和可选下架缺失题目，不会清空用户、收藏、错题和答题记录。
27. 题库已完成新一轮 100 道模块化扩充，16 个模块全部覆盖，新增题均包含 OpenHarmony 官方来源、核验日期和正确答案/参考答案。
28. 本地聚合题库、本地后端数据库和线上服务器题库均已同步到 360 道；线上 `/api/questions` 已核对总数和代表性新增 ID。
29. 管理 API 已实现 Bearer Token 鉴权：服务端从 `ADMIN_TOKEN` 读取至少 32 字符的令牌，未配置时管理接口失败关闭；管理后台使用当前标签页会话保存令牌。
30. 新增远程题库增量发布脚本 `scripts/publish-question-bank.mjs`，通过 `ADMIN_API_URL` 和 `ADMIN_TOKEN` 对比并发布分类与题目，默认保留线上额外数据。
31. 新增生产部署脚本 `scripts/deploy-production.sh`：检查令牌和 Git 状态、备份数据库、运行测试、PM2 重载并验证公开 API 与管理鉴权。
32. 答题页已移除自动切题和自动跳转总结逻辑；提交后停留解析，隐藏重复的“已提交”按钮，未作答时禁止提交。
33. 路由与 Toast 已迁移到页面级 `UIContext`：路由使用 `getRouter()`，Toast 使用 `getPromptAction().openToast()`，当前构建已无应用代码 ArkTS deprecated 警告。
34. 平板答题页题卡浮层已与主内容右边缘对齐，点击遮罩关闭且面板交互不会误关闭；解析区导航顺序统一为左侧上一题、右侧下一题或查看结果。
35. 匿名设备 ID 已改为首次启动生成安全随机 UUID 并写入应用私有 Preferences；所有 REST 请求通过 `X-Device-Id` 使用该 ID，不同安装的练习数据相互隔离。
36. 管理后台已增加题型、审核状态、发布状态联合筛选，支持按当前筛选多选题目并批量发布/下架；批量接口采用整批校验、整批写入，已通过桌面、平板和手机响应式浏览器检查。
37. 后端运行时存储已从整份 JSON 重写迁移为 SQLite 分表持久化，旧 `db.json` 会自动导入且保留原文件；题库、用户、答题、错题、收藏、外部身份和登录会话已分表，迁移与重启恢复测试已覆盖。
38. 可选华为账号登录后端基础已完成：服务端按 Authorization Code 流程验证身份，签发并轮换 ArkInterview 访问/刷新令牌，首次登录事务合并匿名收藏、错题和答题记录；登录账户使用内部账户锚点，未携带访问令牌时不会通过旧设备 ID 暴露账户数据。
39. HarmonyOS 可选登录客户端已完成：新增平板优先“我的”页面和第五个底部导航项，使用 Account Kit 官方登录按钮获取 Authorization Code；ArkInterview 访问/刷新令牌使用系统 AssetStore 加密保存，普通 API 遇到 `401` 会自动轮换令牌并重试一次。HTTP 地址、AGC Client ID 未配置或服务端未启用时登录入口安全禁用，匿名刷题不受影响。
40. 排行榜参与授权已完成：新增仅登录用户可调用的 `PUT /api/users/me/leaderboard-preference`，严格要求 JSON 布尔值并即时持久化；“我的”页使用默认关闭的 Switch，更新成功后同步刷新 AssetStore 用户快照。匿名越权、参数校验、落库和账号合并保持测试已覆盖。
41. 排行榜首版已完成：SQLite Schema 升级到 v3，首次参与时记录授权时间，每条作答固化当时的榜单资格，匿名历史及退出期间答题不折算分数；`GET /api/leaderboards` 支持北京时间周榜、总榜和 16 个模块分类榜，只统计参与后已发布、已核验客观题的每题首次正确作答。响应仅返回脱敏昵称；HarmonyOS 新增平板左右分栏、手机单列的排行榜页，并保留底部导航。独立测试覆盖重复答题、授权边界、周周期、分类过滤、身份过滤、脱敏和排名顺序。
42. 排行榜治理后台已完成：SQLite Schema 升级到 v4，新增 `user_moderation_events` 审计表；按 60 秒和 5 分钟窗口标记异常提交频率但不自动封禁。管理后台新增题库/排行榜双视图，可搜索筛选参与账号、查看历史积分与峰值，并执行带原因的封禁/解封。封禁会事务写入审计、立即移出公开榜单、吊销全部登录会话并阻止华为身份重新登录；解封不恢复旧会话。桌面、1024px 平板和 390px 手机布局已实际检查，手机整页横向溢出已修复。
43. 已清理模块化题库中拿 Ark 面试通自身作为示例的内容：涉及的题干、选项、答案、解析、评分点和知识点统一改为商品/订单、资讯流、音视频、企业协作、设备管理、离线地图等真实业务场景；题库构建脚本新增自指场景拦截，后续题目不得再出现刷题、题库、答题、错题、练习、题单、questionId 或收藏等产品域示例。

题库当前状态：

- 模块数：16
- 题目数：360
- 模块文件目录：`data/question-bank/modules/*.json`
- 构建输出：`data/seed/questions.json`
- 当前模块题量：ArkTS/ArkUI 各 25 道；NAPI/性能/调试发布/NEXT 适配各 24 道；Stage 模型、组件通信、状态管理、relationalStore 各 22 道；其余模块各 21 道。
- 最近一次题库核验与线上同步：2026-07-23，本批新增 100 道，线上总数 360。

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
8. 不得拿 Ark 面试通自身功能举例；按考点选择真实外部业务场景，并确保题干、选项、答案和解析语境一致。

题库相关命令：

```bash
npm run questions:build
npm run questions:check
npm run questions:sync-db:dry
npm run questions:sync-db
npm run questions:publish:dry
npm run questions:publish
npm test
```

新增或修改题库后至少运行 `npm run questions:build`。提交前优先运行 `npm run questions:check` 或 `npm test`。

### 题库发布流程

题库源数据、后端和 App 当前位于同一个仓库，不需要为了题库再新建后端工程：

1. 只修改 `data/question-bank/modules/*.json`。
2. 运行 `npm run questions:build` 生成 `data/seed/questions.json`。
3. 先运行 `npm run questions:sync-db:dry` 查看新增、更新和保留数据数量。
4. 确认目标服务器的 `DB_FILE` 指向实际数据库文件后，运行 `npm run questions:sync-db`。
5. 重启或重新加载服务器后，通过 `/api/categories` 和 `/api/questions` 验证线上题量。

同步脚本按题目 ID 和分类 ID 增量更新，默认保留数据库中已有但本次聚合文件缺失的题目；只有显式增加 `--offline-missing` 时才会把缺失题标为下架。

跨机器发布线上题库时，不要直接修改服务器数据库文件。先配置 `ADMIN_API_URL` 和 `ADMIN_TOKEN`，运行 `npm run questions:publish:dry` 核对差异，再运行 `npm run questions:publish`。令牌只能通过环境变量注入，不能写入仓库。

## UI 方向

用户明确反馈：手机不是唯一目标，平板体验优先，但手机也要兼容。

当前 UI 方向：

1. 平板优先。
2. 首页使用左右两栏工作台：
   - 左侧：标题、学习进度、正确率、快捷训练。
   - 右侧：面试专题入口、题库模块列表。
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

当前构建状态：

- 应用 ArkTS 代码当前无 deprecated 警告。
- DevEco 打包工具仍会输出 Java `sun.misc.Unsafe` 终止弃用提示，来源是 SDK 自带 `app_packing_tool.jar`，不影响 HAP 构建和签名。

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

1. 将本轮鉴权代码部署到线上，生成并注入高强度 `ADMIN_TOKEN`；部署前线上旧管理接口仍未受保护。
2. 为公网 API 配置 HTTPS 和正式域名，之后再通过远程发布脚本传输管理员令牌并启用可选登录。
3. 在 AGC 为 `com.lgq.arkinterview` 开通 Account Kit，配置当前签名指纹和 OAuth Client ID，按 `docs/huawei-account-setup.md` 完成真机登录验收。
4. 继续对齐平板真实 UI 和预览方向，重点检查首页右侧滚动、答题页右侧状态面板、完成总结页、“我的”页和底部导航动效。
5. 真机检查平板底部导航是否遮挡内容，尤其是练习页、答题页、记录页和“我的”页。

优先级 P1：

1. 继续扩充题库，但必须按官方文档确认；下一批优先并发异常治理、ArkUI 布局与手势、RDB 索引/分页、崩溃与包体分析、折叠状态和字体缩放。
2. 每轮扩题后同步更新“已覆盖知识点”和“待补知识点”清单，防止重复出题。
3. 管理后台增加题目全文搜索、详情编辑和审核备注。
4. 练习记录页补 UI 和接口联调。
5. 错题/收藏管理页继续增强，例如批量操作和题卡更密集的平板布局。
6. 排行榜审计增加服务端分页、管理员备注和可识别的操作员身份，替代当前共享管理令牌下的统一操作来源。

优先级 P2：

1. 登录用户账号注销和数据导出。
2. 排行榜赛季、趋势和同分段展示。
3. 服务端 AI 简答题评分。
4. AI 模拟面试追问。
5. 每日一练。

暂缓：

1. 面经分享。
2. 用户投稿。
3. 评论区。
4. 会员功能。

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
2. 当前题库已有 360 道，数量达到 MVP 基线，但仍需持续补充真实面试场景并定期复核过时 API。
3. API 当前使用公网 HTTP 地址，线上尚未部署本轮鉴权代码；必须先部署鉴权，再补齐 TLS、正式域名和 AGC Client ID，客户端才会开放登录按钮。
4. 清除应用数据或卸载重装会生成新的匿名设备 ID；客户端和后端已经具备通过同一华为账号合并匿名记录的链路，但尚未完成 AGC 真实账号联调。
5. 当前开发机没有服务器 SSH 私钥或已配置的 SSH Agent，无法直接执行线上部署；需在服务器内运行 `scripts/deploy-production.sh`，或先为开发机配置受控的 SSH 登录方式。
