# 题库模块覆盖清单

更新时间：2026-07-02

本文档用于规划后续题库扩充，避免重复生成相同题干、相同 ID 或相同考察角度。新增题目前必须先阅读对应模块条目，再打开 `data/question-bank/modules/<categoryId>.json` 确认细节。

重要规则：

1. 本文档只记录覆盖情况和补题方向，不等同于题目事实来源。
2. 每道新增题仍必须按 `docs/question-authoring-guidelines.md` 对照官方文档核验。
3. 待补方向中的每个知识点，入库前都要找到官方来源并填写 `sourceRefs`。
4. 不要直接写入 `data/seed/questions.json`，只维护 `data/question-bank/modules/*.json`。

## 总览

- 分类模块：16
- 当前题目：40
- 已有题目的模块：11
- 暂无题目的模块：5

暂无题目的模块：

- `storage` 数据存储
- `napi` NAPI
- `performance` 性能优化
- `debug-release` 调试与发布
- `next-adaptation` HarmonyOS NEXT 适配

## 模块明细

### ArkTS (`arkts`)

当前题数：2

已覆盖：

- ArkTS 类型系统
- 对象字面量
- 接口建模
- ArkTS 编译规则
- 数组状态更新
- 静态类型检查

已覆盖题型：单选题

下一批建议补题：

- `let` / `const`、空安全、联合类型等基础语法在 ArkTS 严格模式下的使用边界。
- 装饰器、类、接口、泛型在 ArkTS 中的常见限制和面试误区。
- TypeScript 迁移 ArkTS 时常见不兼容写法，例如 `any` 滥用、动态对象、隐式类型。
- 简答题：让候选人说明为什么 ArkTS 更强调静态类型和可分析性。

### ArkUI (`arkui`)

当前题数：2

已覆盖：

- ArkUI
- 自定义组件生命周期
- `aboutToAppear`
- `aboutToDisappear`
- 状态变量
- `@Link`

已覆盖题型：单选题、判断题

下一批建议补题：

- 声明式 UI 基本结构：`@Entry`、`@Component`、`build()`。
- 常用基础组件布局：`Column`、`Row`、`List`、`Scroll`、`Button`、`Text`。
- 条件渲染和 `ForEach` 的稳定 key 设计。
- 事件处理和状态驱动 UI 更新。
- 简答题：解释 ArkUI 声明式 UI 与传统命令式 UI 的差异。

### Stage 模型 (`stage-model`)

当前题数：2

已覆盖：

- Stage 模型
- `AbilityStage`
- HAP 初始化
- `onCreate`
- 同步生命周期

已覆盖题型：单选题、判断题

下一批建议补题：

- Stage 模型工程结构：module、ability、page、resources 的关系。
- `UIAbility` 与 `AbilityStage` 的职责边界。
- 多 HAP 或多模块场景下初始化逻辑如何拆分。
- Stage 模型下应用启动链路。
- 简答题：说明为什么不应该把页面 UI 初始化放到 `AbilityStage`。

### Ability 生命周期 (`ability-lifecycle`)

当前题数：4

已覆盖：

- `UIAbility`
- 冷启动
- `onCreate`
- `WindowStage`
- 页面加载
- `onForeground`
- `onBackground`
- 资源管理
- `onWindowStageCreate`

已覆盖题型：单选题、多选题、简答题

下一批建议补题：

- `onWindowStageDestroy` 与窗口资源释放。
- 前后台切换时网络请求、定时器、定位等资源处理。
- 启动参数和 `want` 的处理。
- 多窗口或多实例相关生命周期问题。
- 判断题：区分 ability 生命周期和页面生命周期。

### 组件通信 (`component-communication`)

当前题数：4

已覆盖：

- 组件通信
- `@Prop`
- 父子组件传值
- `@Link`
- 双向同步
- `@Provide`
- `@Consume`
- 跨层级通信

已覆盖题型：单选题、多选题、判断题

下一批建议补题：

- `@Observed` / `@ObjectLink` 复杂对象变化观察。
- 父组件回调函数传递和子组件事件上报。
- 跨页面通信和组件通信的边界。
- 状态所有权设计题：什么时候应该上提状态。
- 简答题：解释 `@Prop` 与 `@Link` 的适用场景差异。

### 状态管理 (`state-management`)

当前题数：4

已覆盖：

- 状态管理
- `@State`
- UI 刷新
- `AppStorage`
- 应用级状态
- 状态所有权
- 作用域
- `@Prop`
- `@Link`

已覆盖题型：单选题、多选题、简答题

下一批建议补题：

- `LocalStorage` 与 `AppStorage` 的差异。
- `PersistentStorage` 适用场景和限制。
- 状态更新粒度和性能。
- 嵌套对象状态变化无法触发预期刷新时的处理。
- 简答题：如何设计一个页面内、跨组件、跨页面都清晰的状态流。

### 路由导航 (`routing`)

当前题数：4

已覆盖：

- 路由导航
- `pushUrl`
- 页面栈
- 参数传递
- `getParams`
- `back`
- 职责边界
- 页面职责

已覆盖题型：单选题、多选题、判断题

下一批建议补题：

- 页面返回栈和重复打开页面的处理。
- 路由参数校验和缺失参数兜底。
- 页面间传参不应承载复杂业务对象的原因。
- 路由 API deprecated 迁移方向，入库前必须确认官方最新推荐。
- 简答题：如何设计刷题 App 的路由层级。

### 网络请求 (`network`)

当前题数：4

已覆盖：

- 网络请求
- `HttpRequest`
- `createHttp`
- 超时
- `HttpRequestOptions`
- `HttpResponse`
- `responseCode`
- 资源释放

已覆盖题型：单选题、多选题、判断题

下一批建议补题：

- 请求头、设备 ID、鉴权 token 的统一封装。
- JSON 解析失败、HTTP 非 2xx、网络超时的错误分层。
- 真机不能访问 `127.0.0.1` 的调试问题。
- 请求取消、页面销毁后的异步回调处理。
- 简答题：设计一个可复用 API Client 的关键点。

### 权限申请 (`permissions`)

当前题数：4

已覆盖：

- 权限申请
- `AtManager`
- `createAtManager`
- 权限检查
- `checkAccessToken`
- 动态授权
- `requestPermissionsFromUser`
- `PermissionRequestResult`
- `authResults`

已覆盖题型：单选题、多选题

下一批建议补题：

- `module.json5` 中权限声明和运行时申请的关系。
- 用户拒绝权限后的交互和降级策略。
- 只在真正需要时申请权限的产品设计。
- 不同权限类型的申请时机。
- 简答题：如何设计拍照 / 定位功能的权限申请流程。

### 数据存储 (`storage`)

当前题数：0

已覆盖：暂无

下一批建议补题：

- 本地缓存、持久化、服务端同步的边界。
- Preferences、relationalStore、文件存储的选择。
- 离线缓存、收藏、错题、练习记录的数据边界。
- 数据迁移和版本升级策略。
- 简答题：刷题 App 中哪些数据适合本地存，哪些必须服务端存。

### Preferences (`preferences`)

当前题数：5

已覆盖：

- `Preferences`
- `getPreferences`
- 轻量键值存储
- 键值读写
- 本地存储
- 内存缓存
- `removePreferencesFromCache`
- `flush`
- 持久化
- `deletePreferences`
- 缓存管理

已覆盖题型：单选题、多选题、判断题

下一批建议补题：

- Preferences 适合存储的数据大小和结构边界。
- 多处读写同一 preferences 时的一致性设计。
- 异步读写错误处理。
- 与关系型数据库的取舍。
- 简答题：用 Preferences 实现设置页时要注意什么。

### relationalStore (`relational-store`)

当前题数：5

已覆盖：

- `relationalStore`
- `RdbStore`
- `getRdbStore`
- `StoreConfig`
- `SecurityLevel`
- CRUD
- `executeSql`
- 建表
- 事务
- `commit`
- `rollback`

已覆盖题型：单选题、多选题、判断题

下一批建议补题：

- 数据库版本升级和表结构迁移。
- 查询条件、分页和排序。
- 事务失败后的回滚场景。
- 数据库安全等级选择。
- 简答题：如何用 relationalStore 设计错题表和答题记录表。

### NAPI (`napi`)

当前题数：0

已覆盖：暂无

下一批建议补题：

- NAPI 的适用场景：性能、复用 C/C++ 能力、系统能力封装。
- JS / ArkTS 与 Native 层参数传递和类型转换。
- Native 模块初始化和导出函数。
- 异步 NAPI 调用和线程安全。
- 简答题：什么时候不应该为了“性能”引入 NAPI。

### 性能优化 (`performance`)

当前题数：0

已覆盖：暂无

下一批建议补题：

- 启动优化：初始化延迟、首屏加载、资源预加载边界。
- 列表性能：懒加载、稳定 key、减少不必要刷新。
- 网络性能：缓存、分页、超时、重试策略。
- 内存泄漏：生命周期与资源释放。
- 简答题：分析刷题列表卡顿时的排查步骤。

### 调试与发布 (`debug-release`)

当前题数：0

已覆盖：暂无

下一批建议补题：

- 日志分级和敏感信息处理。
- DevEco 调试、真机调试、断点调试。
- 签名配置、证书、profile 和包名关系。
- 构建产物、HAP / APP 打包差异。
- 简答题：无法安装到真机时如何排查签名和 SDK 兼容问题。

### HarmonyOS NEXT 适配 (`next-adaptation`)

当前题数：0

已覆盖：暂无

下一批建议补题：

- HarmonyOS NEXT 与传统 Android 兼容思路的差异。
- API 版本、SDK 版本、兼容 SDK 的选择。
- 三方库、Native 能力和系统能力适配。
- 废弃 API 迁移。
- 简答题：Android / 前端开发者转 HarmonyOS NEXT 时最容易踩哪些坑。

## 下一轮题库扩充建议

优先补空模块，建议顺序：

1. `storage`
2. `performance`
3. `debug-release`
4. `next-adaptation`
5. `napi`

原因：

- `storage`、`performance`、`debug-release` 是真实面试和项目落地中很常见的能力点。
- `next-adaptation` 符合产品定位，但容易受官方版本变化影响，必须严格核验。
- `napi` 更偏进阶，适合在基础模块题量稳定后补充。
