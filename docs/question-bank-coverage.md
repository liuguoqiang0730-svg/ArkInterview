# 题库模块覆盖清单

更新时间：2026-07-23

本文档用于规划 Ark 面试通后续题库扩充，避免重复 ID、重复题干和重复考察角度。事实依据仍以每道题的 `sourceRefs` 为准，本清单只负责记录覆盖范围和下一批方向。

## 当前总览

- 分类模块：16
- 已发布题目：360
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
| ArkTS | 25 | `arkts-001` - `arkts-025` | 静态类型、TS 迁移、Promise、TaskPool/Worker、Sendable、结构化克隆、AsyncLock、共享模块 | 错误类型、集合容器、模块懒加载、并发异常治理 |
| ArkUI | 25 | `arkui-001` - `arkui-025` | 组件生命周期、声明式 UI、ForEach/LazyForEach/Repeat、模板复用、@ReusableV2 | 布局测量、转场动画、手势冲突、组件复用性能分析 |
| Stage 模型 | 22 | `stage-model-001` - `stage-model-022` | AbilityStage、UIAbility、WindowStage、AppStartup、Context、HAP/HAR/HSP、多模块启动依赖 | 进程模型、ExtensionAbility、跨进程场景、应用故障恢复 |
| Ability 生命周期 | 21 | `ability-lifecycle-001` - `ability-lifecycle-021` | 冷启动、窗口阶段、前后台切换、启动模式、onNewWant、状态恢复、回调顺序 | Want 参数、多实例任务管理、异常退出恢复、资源释放边界 |
| 组件通信 | 22 | `component-communication-001` - `component-communication-022` | V1/V2 父子通信、@Param/@Event/@Once、Provider/Consumer、状态上提 | 跨页面边界、复杂对象契约、V1/V2 混用、事件总线取舍 |
| 状态管理 | 22 | `state-management-001` - `state-management-022` | @State、@Local、@ObservedV2/@Trace、@Monitor、AppStorage、PersistenceV2 | LocalStorage、PersistentStorage、makeObserved、V1/V2 状态迁移 |
| 路由导航 | 21 | `routing-001` - `routing-021` | router、Navigation、NavPathStack、栈操作、系统路由表、NavDestination | 自定义转场、深链、跨模块注册、路由失败恢复 |
| 网络请求 | 21 | `network-001` - `network-021` | HttpRequest 完整生命周期、监听释放、错误分层、NetConnection、网络权限 | 证书校验、请求取消、上传下载、缓存协商、重试退避 |
| 权限申请 | 21 | `permissions-001` - `permissions-021` | 权限声明、AtManager、运行时授权、单次授权、设置页申请、状态监听 | 特殊权限、隐私弹窗、重复拒绝策略、权限组边界 |
| 数据存储 | 21 | `storage-001` - `storage-021` | Preferences/KV/RDB 选型、应用沙箱文件、文件 I/O、备份恢复、缓存边界 | 数据加密、跨版本迁移、空间治理、文件并发访问 |
| Preferences | 21 | `preferences-001` - `preferences-021` | get/put/flush、has/getAll、XML/GSKV、多进程限制、删除与缓存 | 观察器、加密数据、容量边界、异常恢复 |
| relationalStore | 22 | `relational-store-001` - `relational-store-022` | CRUD、谓词、ResultSet、事务、版本迁移、备份、StoreConfig | 分页排序、索引设计、加密数据库、慢查询分析 |
| NAPI | 24 | `napi-001` - `napi-024` | 模块注册、参数解析、异步任务、Promise、ArrayBuffer、线程安全函数、引用生命周期 | Native 异常映射、资源清理、并发取消、性能测量 |
| 性能优化 | 24 | `performance-001` - `performance-024` | 长列表、稳定 key、缓存、冷启动阶段、Profiler Self Time、精准刷新范围 | 内存泄漏、图片资源、网络性能、布局与帧率分析 |
| 调试与发布 | 24 | `debug-release-001` - `debug-release-024` | SDK/签名、HiLog、HAP/HAR/HSP、同签名要求、混淆、发布流水线 | 崩溃日志、自动化测试、包体分析、可复现构建 |
| HarmonyOS NEXT 适配 | 24 | `next-adaptation-001` - `next-adaptation-024` | 多窗口、媒体查询、GridRow、深浅色、无障碍、安全区、键鼠与 PC 适配 | 折叠状态、字体缩放、2in1 悬停、自由窗口极限尺寸 |

## 最近批次

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

下一轮不要继续平均铺量，优先补真实面试价值高且当前仍缺少的角度：

1. ArkTS：错误类型、集合容器、并发取消与异常治理。
2. ArkUI：布局测量、转场动画、手势冲突与复用性能分析。
3. relationalStore：分页、索引、加密数据库与慢查询定位。
4. 调试发布：崩溃日志、自动化测试、包体分析和可复现构建。
5. NEXT 适配：折叠状态、字体缩放、2in1 悬停与自由窗口边界。

每批可按 50 - 100 道规划，但必须先建立 ID 与考察角度清单；同一个官方页面可以提炼多个角度，不得只替换场景名重复同一结论。
