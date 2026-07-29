# 题库模块覆盖清单

更新时间：2026-07-29

本文档用于规划 Ark 面试通后续题库扩充，避免重复 ID、重复题干和重复考察角度。事实依据仍以每道题的 `sourceRefs` 为准，本清单只负责记录覆盖范围和下一批方向。

## 当前总览

- 分类模块：16
- 已发布题目：560
- 所有模块均已有题目
- 题库源目录：`data/question-bank/modules/*.json`
- 聚合输出：`data/seed/questions.json`

新增题目前必须：

1. 查看本清单中的 ID 范围、已覆盖和待补方向。
2. 打开目标模块 JSON，逐题检查题干与考察角度。
3. 全局搜索相同 API、装饰器和关键词，避免跨模块重复。
4. 找到华为开发者或 OpenHarmony 官方文档，确认答案后再设置 `reviewStatus: "verified"`。
5. 运行 `npm run questions:build` 和 `npm run questions:check`。

## 模块明细

| 模块 | 当前题数 | 已用 ID | 已覆盖重点 | 下一批优先方向 |
| --- | ---: | --- | --- | --- |
| ArkTS | 45 | `arkts-001` - `arkts-045` | 静态类型、Promise/async/await、TaskPool 取消与异常、AsyncLock/ConditionVariable、共享容器、线性/非线性容器、懒加载/动态加载 | Worker 错误隔离、Sendable 深层约束、模块副作用、性能诊断 |
| ArkUI | 45 | `arkui-001` - `arkui-045` | 组件生命周期、渲染控制、布局测量/放置、DynamicLayout、布局调试、手势优先/并行/互斥/判定、转场与共享元素 | 组件复用性能实测、复杂滚动嵌套、无障碍焦点、动效性能诊断 |
| Stage 模型 | 32 | `stage-model-001` - `stage-model-032` | AbilityStage、UIAbility、WindowStage、AppStartup、Context、HAP/HAR/HSP、ExtensionAbility、后台治理与多设备窗口解耦 | 进程间通信、应用故障恢复、扩展能力高级场景 |
| Ability 生命周期 | 31 | `ability-lifecycle-001` - `ability-lifecycle-031` | 冷启动、后台启动、窗口阶段、前后台切换、启动模式、onNewWant、WindowStage 事件、应用级生命周期监听与资源边界 | Want 参数、多实例任务管理、异常退出恢复 |
| 组件通信 | 32 | `component-communication-001` - `component-communication-032` | V1/V2 父子通信、@Param/@Event/@Once、Provider/Consumer、alias、最近祖先匹配、函数和复杂对象跨层通信 | 跨页面边界、V1/V2 混用、事件总线取舍 |
| 状态管理 | 32 | `state-management-001` - `state-management-032` | @State、@Local、@ObservedV2/@Trace、@Monitor、AppStorage、PersistenceV2、LocalStorage、PersistentStorage、makeObserved 与辅助接口 | V1/V2 状态迁移、动态监听、复杂持久化边界 |
| 路由导航 | 31 | `routing-001` - `routing-031` | router、Navigation、NavPathStack、压栈/回退/替换/删除、系统路由表、结果回传、单实例与错误处理 | 自定义转场、深链、路由恢复与拦截高级场景 |
| 网络请求 | 31 | `network-001` - `network-031` | HttpRequest 生命周期、流式上传下载、进度、缓存、超时、证书、监听释放、错误分层、NetConnection | 请求取消、缓存协商、重试退避、HTTP 拦截器 |
| 权限申请 | 31 | `permissions-001` - `permissions-031` | 权限声明、AtManager、实时检查、运行时授权、多权限结果、拒绝降级、设置页申请、UI 加载时机 | 特殊权限、隐私弹窗、权限组边界 |
| 数据存储 | 31 | `storage-001` - `storage-031` | 存储选型、应用沙箱文件、异步/分段 I/O、偏移、文件流并发、哈希校验、备份恢复与空间治理 | 数据加密、跨版本迁移、文件锁与原子替换 |
| Preferences | 31 | `preferences-001` - `preferences-031` | get/put/flush、容量和类型边界、change/dataChange 监听、删除与缓存、多进程限制 | 加密数据、异常恢复、GSKV 高级场景 |
| relationalStore | 42 | `relational-store-001` - `relational-store-042` | CRUD、谓词分页/排序/索引提示、ResultSet/LiteResultSet、事务并发、加密与密钥轮换、备份恢复、内存/只读数据库 | 慢查询工具、FTS、分布式表、复杂迁移压测 |
| NAPI | 34 | `napi-001` - `napi-034` | 模块注册、参数解析、异步任务、Promise/callback、execute/complete 线程边界、取消状态、ArrayBuffer、线程安全函数、引用与工作项生命周期 | Native 异常映射、并发取消深化、性能测量 |
| 性能优化 | 24 | `performance-001` - `performance-024` | 长列表、稳定 key、缓存、冷启动阶段、Profiler Self Time、精准刷新范围 | 内存泄漏、图片资源、网络性能、布局与帧率分析 |
| 调试与发布 | 44 | `debug-release-001` - `debug-release-044` | SDK/签名、HiLog、CppCrash/JsCrash/AppFreeze、errorManager、HiAppEvent、SourceMap、自动化测试、可复现排障 | 包体组成分析、性能测试、流水线制品追溯、灰度与回滚 |
| HarmonyOS NEXT 适配 | 44 | `next-adaptation-001` - `next-adaptation-044` | 多窗口、媒体查询、GridRow、字体缩放、折叠状态、FolderStack 悬停、安全区、WindowLimits、键鼠与 PC 适配 | 多屏协同、自由窗口高级交互、无障碍大字体极限布局、设备能力降级 |

## 最近批次

2026-07-29 新增 100 道（总数 460 -> 560）：

- Stage 模型：`stage-model-023` - `stage-model-032`
- Ability 生命周期：`ability-lifecycle-022` - `ability-lifecycle-031`
- 组件通信：`component-communication-023` - `component-communication-032`
- 状态管理：`state-management-023` - `state-management-032`
- 路由、网络、权限、数据存储、Preferences：各 `022` - `031`
- NAPI：`napi-025` - `napi-034`

本批十个相对薄弱模块各补 10 道，统一题型分布为单选 4、多选 3、判断 2、简答 1，总计单选 40、多选 30、判断 20、简答 10。重点覆盖 ExtensionAbility 与后台治理、UIAbility 后台启动时序、Provider/Consumer 深层规则、状态作用域、Navigation 栈操作、HTTP 流式传输、权限拒绝降级、文件流治理、Preferences 精确监听和 NAPI 异步线程边界。

2026-07-29 新增 100 道（总数 360 -> 460）：

- ArkTS：`arkts-026` - `arkts-045`
- ArkUI：`arkui-026` - `arkui-045`
- relationalStore：`relational-store-023` - `relational-store-042`
- 调试与发布：`debug-release-025` - `debug-release-044`
- HarmonyOS NEXT 适配：`next-adaptation-025` - `next-adaptation-044`

本批五个高价值薄弱模块各补 20 道，覆盖 Promise 异常治理、TaskPool 取消、共享容器、布局测量、手势冲突、转场、RDB 分页/事务/加密、崩溃现场、SourceMap、测试、折叠屏、字体缩放、悬停态与自由窗口边界。题型分布：单选 40、多选 32、判断 23、简答 5。

2026-07-23 新增 100 道（总数 260 -> 360）：

- ArkTS：`arkts-020` - `arkts-025`
- ArkUI：`arkui-020` - `arkui-025`
- Stage 模型：`stage-model-016` - `stage-model-022`
- Ability 生命周期：`ability-lifecycle-016` - `ability-lifecycle-021`
- 组件通信：`component-communication-016` - `component-communication-022`
- 状态管理：`state-management-016` - `state-management-022`
- 路由、网络、权限、数据存储、Preferences：各 `016` - `021`
- relationalStore：`relational-store-016` - `relational-store-022`
- NAPI、性能优化、调试与发布、HarmonyOS NEXT 适配：各 `019` - `024`

本批题型分布：单选 38、多选 30、判断 16、简答 16。全部题目已按 OpenHarmony 官方文档核验，并带正确答案或参考答案、解析和评分点。

上一批新增 50 道：

- ArkTS：`arkts-011` - `arkts-019`
- ArkUI：`arkui-011` - `arkui-019`
- NAPI：`napi-011` - `napi-018`
- 性能优化：`performance-011` - `performance-018`
- 调试与发布：`debug-release-011` - `debug-release-018`
- HarmonyOS NEXT 适配：`next-adaptation-011` - `next-adaptation-018`

再上一批新增 50 道：

- Stage 模型、Ability 生命周期、状态管理、组件通信、路由、网络、权限、数据存储、Preferences、relationalStore 各补 5 道。

## 下一轮建议

下一轮继续按真实面试价值和未覆盖角度扩充：

1. ArkTS：Worker 错误隔离、Sendable 深层约束、模块副作用和性能诊断。
2. ArkUI：组件复用性能实测、复杂滚动嵌套、无障碍焦点和动效性能。
3. relationalStore：慢查询工具、FTS、分布式表和复杂迁移压测。
4. 调试发布：包体组成分析、性能测试、流水线制品追溯和灰度回滚。
5. NEXT 适配：多屏协同、自由窗口高级交互、大字体极限布局和设备能力降级。

每批可按 50 - 100 道规划，但必须先建立 ID 与考察角度清单；同一个官方页面可以提炼多个角度，不得只替换场景名重复同一结论。
