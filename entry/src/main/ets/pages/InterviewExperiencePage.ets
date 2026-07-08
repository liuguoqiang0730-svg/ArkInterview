import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { AppRouter } from '../utils/AppRouter';

interface InterviewQuestionItem {
  id: string;
  order: number;
  title: string;
  category: string;
  shortAnswer: string;
  answer: string;
  keyPoints: string[];
  visualTitle: string;
  visualItems: string[];
  visualNotes: string[];
  sourceRefs: string[];
}

const COLOR_BG: string = '#f3f5f8';
const COLOR_SURFACE: string = '#ffffff';
const COLOR_NAVY: string = '#102033';
const COLOR_TEXT: string = '#1f2a37';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_GREEN: string = '#16745f';
const COLOR_ORANGE: string = '#d97924';
const COLOR_BLUE: string = '#2c5f8f';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;

const INTERVIEW_QUESTIONS: InterviewQuestionItem[] = [
  {
    id: 'stage-model-basic',
    order: 1,
    title: '简单说下你对 Stage 模型的理解。',
    category: 'Stage 模型',
    shortAnswer: 'Stage 模型是 HarmonyOS 的应用模型组织方式，核心是把 HAP 级初始化、UIAbility 生命周期、WindowStage 窗口创建和 ArkUI 页面加载分层管理。',
    answer: '我会先说它解决的是应用结构和生命周期分层问题。AbilityStage 面向 HAP 或模块运行时，适合模块加载阶段的初始化；UIAbility 面向一个具体的 UI 能力，处理创建、前后台、销毁等生命周期；WindowStage 是 UIAbility 创建窗口后加载页面内容的阶段；ArkUI 页面和组件负责声明式 UI。面试里要特别说明：AbilityStage、UIAbility、WindowStage、页面组件不是同一层，初始化、窗口加载和 UI 构建要按职责放置。',
    keyPoints: ['AbilityStage：HAP 或模块级运行时初始化', 'UIAbility：承载具体 UI 能力和生命周期', 'WindowStage：窗口创建和页面加载入口', 'ArkUI 页面组件：负责声明式界面'],
    visualTitle: '官方结构重绘：Stage 分层',
    visualItems: ['HAP 模块', 'AbilityStage', 'UIAbility', 'WindowStage', 'ArkUI 页面'],
    visualNotes: ['应用能力以 HAP 模块组织', '模块加载期做必要初始化', '承载前后台和窗口生命周期', '拿到窗口阶段后加载页面', '页面和组件描述 UI'],
    sourceRefs: ['AbilityStage API', 'UIAbility API', '构建第一个 ArkTS 应用（Stage 模型）']
  },
  {
    id: 'data-sharing',
    order: 2,
    title: '数据共享如何实现？说一下你了解的。',
    category: '状态管理',
    shortAnswer: '数据共享先看作用域：组件内用 @State，父子用 @Prop/@Link，跨层级用 @Provide/@Consume，页面或应用级再考虑 LocalStorage、AppStorage 或持久化。',
    answer: '官方状态管理的思路是围绕状态所有权和作用域选装饰器。组件自己拥有的数据用 @State；父组件向子组件单向传递用 @Prop；子组件需要回写父组件状态用 @Link；祖先和子孙跨层级共享用 @Provide/@Consume；对象属性联动要考虑 @Observed/@ObjectLink 或 V2 里的可观察对象能力。跨页面或跨启动的数据不要用普通全局变量硬传，应放到应用级状态、Preferences、关系型数据库或服务端。',
    keyPoints: ['先判断状态所有者和生命周期', '@State、@Prop、@Link 处理局部和父子关系', '@Provide/@Consume 处理跨层级共享', '持久共享要进入数据存储或服务端'],
    visualTitle: '官方结构重绘：状态作用域',
    visualItems: ['组件内状态', '父子传递', '跨层级共享', '页面/应用状态', '持久化/服务端'],
    visualNotes: ['@State', '@Prop / @Link', '@Provide / @Consume', 'LocalStorage / AppStorage', 'Preferences / RDB / API'],
    sourceRefs: ['ArkUI 状态管理', '应用数据持久化概述']
  },
  {
    id: 'realtime-refresh-sync',
    order: 3,
    title: '如何实现数据实时刷新？数据同步？',
    category: '状态同步',
    shortAnswer: 'UI 实时刷新依赖可观察状态变化；数据同步依赖清晰的数据源、缓存策略、请求策略和冲突处理，二者不能混为一个问题。',
    answer: '我会拆成两层回答。第一层是 UI 刷新：ArkUI 是声明式 UI，页面应由状态驱动，状态变化后框架重新计算相关 UI，不应该靠手动修改控件。第二层是数据同步：本地数据和远端数据要有明确的数据源、加载时机、缓存失效策略、失败重试和冲突处理。实时性要求普通时可以在页面显示、前后台切换、用户操作后刷新；实时性要求高时再考虑长连接、订阅或轮询。',
    keyPoints: ['UI 刷新靠状态驱动，不靠手动改控件', '同步要区分本地缓存和远端真值', '明确刷新时机、失败重试和冲突策略', '实时能力按业务强度选择轮询或推送'],
    visualTitle: '官方结构重绘：刷新与同步',
    visualItems: ['状态变化', 'ArkUI 重新构建', '本地缓存', '远端接口', '冲突处理'],
    visualNotes: ['可观察状态触发', '声明式 UI 更新', '保存当前可用数据', '拉取或提交变化', '版本、时间戳、重试'],
    sourceRefs: ['ArkUI 状态管理', 'HTTP 数据请求', '应用数据持久化概述']
  },
  {
    id: 'promise-understanding',
    order: 4,
    title: '说你下你对 Promise 的理解？有没有研究过它的底层代码。',
    category: 'ArkTS / 异步',
    shortAnswer: 'Promise 是异步结果的状态抽象，核心是 pending、fulfilled、rejected 三态、状态不可逆、then 链式返回新 Promise，以及微任务调度。',
    answer: 'Promise 不是线程，也不等于并行执行，它只是把一个未来完成或失败的结果封装成可组合的对象。它的状态从 pending 只能转到 fulfilled 或 rejected，转移后不可再变。then 会注册回调并返回新的 Promise，所以可以链式编排异步流程；catch 处理 rejected；finally 做收尾。如果追问底层，我会讲状态机、回调队列、微任务队列和 Promise 解析过程：then 返回普通值会包装成成功态，返回 Promise 会跟随该 Promise 的最终状态。ArkTS 中常与 async/await 配合使用，但异常处理和并发控制仍要显式设计。',
    keyPoints: ['Promise 是异步状态容器，不是线程', '状态迁移单向且不可逆', 'then 返回新 Promise，形成链式组合', 'async/await 是基于 Promise 的语法层简化'],
    visualTitle: '官方结构重绘：Promise 状态机',
    visualItems: ['pending', 'fulfilled', 'rejected', 'then 链', 'catch/finally'],
    visualNotes: ['初始等待态', '成功完成', '失败完成', '返回新 Promise', '错误处理和收尾'],
    sourceRefs: ['TypeScript 到 ArkTS 适配指南', 'ArkTS 语言异步编程能力']
  },
  {
    id: 'package-difference',
    order: 5,
    title: '你觉得 har、hsp、hap 有什么区别？',
    category: '工程化',
    shortAnswer: 'HAP 是应用安装和运行的能力包；HAR 是静态共享包，编译时合入使用方；HSP 是动态共享包，可在应用内被多个模块共享。',
    answer: '我会按产物和复用方式回答。HAP 是 HarmonyOS Ability Package，entry 或 feature 模块通常会形成 HAP，是应用能力安装、运行和分发的重要单元。HAR 是 Harmony Archive，偏静态共享，适合放公共组件、工具和模型，使用方编译构建时会把相关代码和资源合入自身产物。HSP 是 Harmony Shared Package，偏动态共享，适合多个 HAP 或模块复用同一份代码和资源，能减少重复打包。选择时看复用范围、是否需要独立共享、包体和模块边界。',
    keyPoints: ['HAP：应用能力包，参与安装运行', 'HAR：静态复用，编译期合入', 'HSP：动态共享，多个模块复用一份实现', '公共代码不应在多个模块复制粘贴'],
    visualTitle: '官方结构重绘：包关系',
    visualItems: ['App 包', 'HAP', 'HAR', 'HSP', '模块复用'],
    visualNotes: ['最终分发容器', 'entry / feature 能力包', '静态共享库', '动态共享包', '按边界选择'],
    sourceRefs: ['Stage 模型应用包结构', 'HAR 开发指导', 'HSP 开发指导']
  },
  {
    id: 'arkts-ts',
    order: 6,
    title: '你觉得 ArkTS、TS 两者之间有什么区别和共同点？',
    category: 'ArkTS',
    shortAnswer: 'ArkTS 继承 TypeScript 的基础语法和类型体系，但为了高性能、可分析和原生开发体验，对动态特性做了更严格约束。',
    answer: '共同点是两者都有类、接口、模块、泛型、异步等现代语言能力，ArkTS 开发者可以沿用很多 TypeScript 思维。区别在于 ArkTS 面向 HarmonyOS 应用和 ArkUI 声明式开发，强调静态类型、可编译优化和运行稳定性，因此限制了不少 TypeScript 中常见的动态写法，例如过度使用 any、随意给对象增加属性、未声明结构的对象字面量等。面试回答要落到迁移规则：不是 TS 代码直接复制过来就一定能跑，而是要按 ArkTS 严格语法调整模型、接口和状态对象。',
    keyPoints: ['共享 TS 的基本语法和类型思路', 'ArkTS 更严格，减少动态特性', 'ArkTS 深度结合 ArkUI 和系统能力', '迁移时重点处理类型、对象结构和动态写法'],
    visualTitle: '官方结构重绘：ArkTS 与 TS',
    visualItems: ['TypeScript 基础', 'ArkTS 严格约束', 'ArkUI 声明式 UI', 'HarmonyOS API'],
    visualNotes: ['语法和类型基础', '静态类型和可优化', '状态驱动界面', '原生系统能力'],
    sourceRefs: ['TypeScript 到 ArkTS 适配指南', 'ArkUI 简介']
  },
  {
    id: 'router-navigation',
    order: 7,
    title: '你对路由跳转和 Navigation 的理解。',
    category: '路由导航',
    shortAnswer: 'router 是页面栈级的命令式跳转能力；Navigation 是 ArkUI 的导航容器，更适合复杂层级、列表详情和多设备自适应导航。',
    answer: 'router 适合回答成页面级 API：它负责 push、replace、back、参数传递等页面栈操作，适合简单页面跳转。Navigation 则是 ArkUI 组件体系里的导航容器，可以把导航状态放进组件树，通过路径栈管理内容展示，更适合列表详情、多层级页面、大屏分栏和多设备适配。工程选型上，简单独立页面可以用 router；当页面结构本身就是导航关系，尤其要做大屏或折叠屏体验时，Navigation 更合适。',
    keyPoints: ['router：命令式页面栈 API', 'Navigation：声明式导航容器', '复杂导航更适合路径栈管理', '大屏和折叠屏要考虑导航形态变化'],
    visualTitle: '官方结构重绘：导航选型',
    visualItems: ['简单页面', 'router', '复杂页面结构', 'Navigation', '自适应导航'],
    visualNotes: ['独立页面跳转', 'push / back / params', '列表详情或多层级', '组件化管理导航', '手机单列、大屏分栏'],
    sourceRefs: ['router API', 'Navigation 组件', '应用基础功能和兼容性体验建议']
  },
  {
    id: 'persistence',
    order: 8,
    title: '如果要实现持久化，可以采用那些方式？',
    category: '数据存储',
    shortAnswer: '轻量键值用 Preferences，结构化数据用 relationalStore，文件类数据用文件系统，多端一致和账号数据放服务端。',
    answer: '官方数据持久化会按数据形态选型。少量配置、开关、最近选择这类键值数据适合 Preferences；需要表结构、条件查询、排序、事务或统计的数据适合 relationalStore；图片、文档、导入导出和较大内容适合文件系统；如果数据要跨设备、跨账号或多人协作，就不应只依赖本地持久化，而要放到服务端并设计同步策略。回答时还要补充安全、迁移和清理：敏感数据要注意加密，版本升级要考虑表结构迁移，缓存要有过期和清理规则。',
    keyPoints: ['Preferences：轻量键值', 'relationalStore：结构化关系数据', '文件系统：大对象和导入导出', '服务端：账号、多端和协作一致性'],
    visualTitle: '官方结构重绘：持久化选型',
    visualItems: ['键值配置', '结构化数据', '文件数据', '服务端数据', '迁移与安全'],
    visualNotes: ['Preferences', 'relationalStore', 'File API', 'REST / 云端', '加密、升级、清理'],
    sourceRefs: ['应用数据持久化概述', 'Preferences API', 'relationalStore API']
  },
  {
    id: 'responsive-declarative',
    order: 9,
    title: '你对响应式开发和声明式开发有啥看法，实际开发过程中有什么区别？',
    category: 'ArkUI',
    shortAnswer: '声明式开发强调用状态描述 UI；响应式开发强调状态或环境变化后 UI 自动更新和适配。二者在 ArkUI 中是配合关系。',
    answer: '声明式开发回答的是“UI 怎么表达”：开发者描述某个状态下界面应该是什么样，而不是逐个命令式修改控件。响应式开发回答的是“变化怎么驱动界面”：状态变化、窗口尺寸变化、系统主题变化、横竖屏变化后，相关 UI 会根据状态重新计算。实际开发中，声明式让代码围绕状态组织，响应式让页面跟随状态和环境变化；二者结合后，才适合做手机、平板、折叠屏等多设备界面。',
    keyPoints: ['声明式：描述状态对应的 UI', '响应式：状态或环境变化触发更新', '不要把 UI 当成可随意手动修改的对象树', '适配多设备时要结合断点和条件渲染'],
    visualTitle: '官方结构重绘：声明式与响应式',
    visualItems: ['状态', 'build 描述 UI', '框架更新', '环境变化', '自适应布局'],
    visualNotes: ['数据源', 'UI = f(state)', '局部重新渲染', '尺寸、主题、方向', '断点和资源适配'],
    sourceRefs: ['ArkUI 简介', 'ArkUI 状态管理', '应用基础功能和兼容性体验建议']
  },
  {
    id: 'cross-module-message',
    order: 10,
    title: '若要实现跨模块信息传递，你如何实现？有那些方式？',
    category: '模块通信',
    shortAnswer: '跨模块传递要先定义模块边界：公共类型和能力放 HAR/HSP，页面上下文走路由参数，运行期共享状态走状态层，持久结果走存储或服务端。',
    answer: '我会避免让 feature 模块互相直接依赖对方内部实现。稳定做法是把公共接口、模型、工具和 UI 基础组件抽到 HAR 或 HSP；页面跳转只传递轻量参数，不传大对象；运行期需要共享的数据放到状态管理层或领域服务；需要跨启动保存的结果进入 Preferences、relationalStore 或服务端。事件通知可以作为解耦手段，但要管理订阅生命周期，防止隐式依赖和内存泄漏。',
    keyPoints: ['先划分模块边界和依赖方向', '公共能力沉到 HAR/HSP', '路由参数只传轻量上下文', '共享状态、持久化和事件通知要分场景使用'],
    visualTitle: '官方结构重绘：跨模块传递',
    visualItems: ['Feature 模块', 'HAR/HSP', '状态/服务层', '路由参数', '存储/服务端'],
    visualNotes: ['业务边界', '公共模型和组件', '运行期共享', '轻量上下文', '长期保存和同步'],
    sourceRefs: ['HAR 开发指导', 'HSP 开发指导', 'router API', 'ArkUI 状态管理']
  },
  {
    id: 'decorator-v1-v2',
    order: 11,
    title: '你对装饰器 V1 和 V2 的理解。',
    category: '状态管理',
    shortAnswer: 'V1 以 @State、@Prop、@Link、@Provide、@Consume 等为核心；V2 强化对象状态观测和精细化追踪，例如 @ObservedV2、@Trace。',
    answer: '我会按官方状态管理版本说明回答。V1 的常用装饰器覆盖组件内状态、父子通信、跨层级通信和对象联动，例如 @State、@Prop、@Link、@Provide、@Consume、@Observed、@ObjectLink。V2 的重点是增强复杂对象状态管理，常见组合是 @ObservedV2 标记可观察类，@Trace 标记需要追踪的属性，让对象内部属性变化也能更清晰地驱动刷新。实际项目中不要简单混用，而要根据 SDK 版本、团队规范和状态复杂度选择。',
    keyPoints: ['V1：覆盖组件状态和组件通信的基础装饰器', 'V2：面向复杂对象的可观察和精细追踪', '@ObservedV2 与 @Trace 常用于对象属性追踪', '选择装饰器前先确定状态所有权'],
    visualTitle: '官方结构重绘：状态管理版本',
    visualItems: ['V1 基础状态', '父子/跨层级', '对象联动', 'V2 可观察对象', '属性追踪'],
    visualNotes: ['@State 等', '@Prop / @Link / @Provide', '@Observed / @ObjectLink', '@ObservedV2', '@Trace'],
    sourceRefs: ['ArkUI 状态管理', '状态管理 V2', 'ObservedV2 / Trace']
  },
  {
    id: 'lifecycle-flow',
    order: 12,
    title: '生命周期这一块有去了解吗？详细说一下它们的流程（UIAbility、页面、组件）。',
    category: '生命周期',
    shortAnswer: 'UIAbility 管应用能力和窗口阶段，页面管显示隐藏，组件管创建、构建和销毁。三层生命周期要分开说。',
    answer: 'UIAbility 常见链路是：onCreate 做 Ability 实例创建时的初始化，onWindowStageCreate 获取 WindowStage 并加载页面，onForeground/onBackground 处理前后台切换，onWindowStageDestroy 和 onDestroy 处理窗口和 Ability 销毁。页面层关注 onPageShow、onPageHide 以及出现和消失；自定义组件关注 aboutToAppear、build、aboutToDisappear 等。面试回答的重点是职责边界：onCreate 还没有 WindowStage，不适合直接做依赖窗口的页面加载；build 是 UI 描述函数，不应放重型副作用。',
    keyPoints: ['UIAbility：onCreate、WindowStage、前后台、销毁', '页面：显示、隐藏、路由返回等状态', '组件：出现、构建、消失', '窗口相关逻辑应放在 WindowStage 创建后'],
    visualTitle: '官方结构重绘：生命周期链路',
    visualItems: ['UIAbility onCreate', 'onWindowStageCreate', 'Page Show/Hide', 'Component build', 'Destroy'],
    visualNotes: ['实例初始化', '窗口和页面加载', '页面可见性', '声明 UI', '释放资源'],
    sourceRefs: ['UIAbility API', '自定义组件生命周期', '构建第一个 ArkTS 应用（Stage 模型）']
  },
  {
    id: 'common-decorators',
    order: 13,
    title: '开发过程中，常用的装饰器有那些？',
    category: 'ArkUI 装饰器',
    shortAnswer: '常用装饰器可分为组件声明、状态管理、对象观察和 UI 复用四类，而不是孤立背名字。',
    answer: '组件声明常见 @Entry 和 @Component；状态管理常见 @State、@Prop、@Link、@Provide、@Consume；对象观察常见 @Observed、@ObjectLink，V2 中还会遇到 @ObservedV2、@Trace；UI 复用常见 @Builder、@BuilderParam、@Styles。面试时最好按用途说，并补一句：装饰器选择的核心不是名字，而是状态归谁所有、谁能修改、变化是否要驱动 UI 刷新。',
    keyPoints: ['组件声明：@Entry、@Component', '状态管理：@State、@Prop、@Link、@Provide、@Consume', '对象观察：@Observed、@ObjectLink、@ObservedV2、@Trace', 'UI 复用：@Builder、@BuilderParam、@Styles'],
    visualTitle: '官方结构重绘：装饰器分类',
    visualItems: ['组件声明', '状态传递', '跨层级共享', '对象观察', 'UI 复用'],
    visualNotes: ['@Entry / @Component', '@State / @Prop / @Link', '@Provide / @Consume', '@Observed 系列', '@Builder / @Styles'],
    sourceRefs: ['ArkUI 状态管理', '自定义组件生命周期', '状态管理 V2']
  },
  {
    id: 'ancestor-descendant-refresh',
    order: 14,
    title: '祖先组件和子孙组件的数据传输，若要实现 UI 刷新，可采用那些方式？你认为最应该采取那种方式？',
    category: '组件通信',
    shortAnswer: '祖先到深层子孙的响应式共享优先考虑 @Provide/@Consume；父子短链路用 @Prop/@Link；跨页面或全局状态再上应用级状态。',
    answer: '如果只是祖先组件和多层子孙之间共享状态，@Provide/@Consume 是更贴合的方式，因为它避免层层透传，同时能保持状态变化驱动 UI 更新。父子一两层关系时，@Prop 适合只读传递，@Link 适合子组件回写父组件状态。跨页面或更大范围共享时，再考虑 LocalStorage、AppStorage 或独立状态服务。不要为了 UI 刷新频繁读写数据库或 Preferences，它们是持久化工具，不是组件通信首选。',
    keyPoints: ['祖孙跨层级：@Provide/@Consume', '父到子只读：@Prop', '父子双向：@Link', '跨页面或全局：应用级状态或服务层'],
    visualTitle: '官方结构重绘：祖孙通信',
    visualItems: ['祖先状态', '@Provide', '@Consume', '子孙组件', 'UI 刷新'],
    visualNotes: ['状态所有者', '向下提供', '跨层级消费', '读取并响应变化', '状态变化驱动'],
    sourceRefs: ['ArkUI 状态管理', '组件通信相关装饰器']
  },
  {
    id: 'dark-light-mode',
    order: 15,
    title: '如何实现深浅色模式的切换？',
    category: '主题适配',
    shortAnswer: '深浅色切换应基于系统颜色模式或应用主题状态，统一管理颜色 token，并用状态变化驱动界面刷新。',
    answer: '我会先建立主题层，而不是在各组件里写死颜色。主题层提供背景、文字、分割线、主色、危险色、禁用态等 token；主题来源可以跟随系统，也可以由应用设置控制；用户选择可持久化到 Preferences；页面通过状态或主题服务读取当前模式，状态变化后触发 ArkUI 更新。适配时还要检查图标、图片、阴影、边框、透明度和文字对比度，避免只改背景色。',
    keyPoints: ['颜色 token 集中管理，避免硬编码散落', '支持跟随系统和应用内设置', '用户选择可用 Preferences 保存', '同时检查图片、图标、阴影和对比度'],
    visualTitle: '官方结构重绘：主题切换',
    visualItems: ['系统颜色模式', '应用主题状态', '主题 token', 'ArkUI 页面', 'Preferences'],
    visualNotes: ['跟随系统', '用户主动选择', '统一颜色语义', '状态驱动刷新', '保存偏好'],
    sourceRefs: ['ArkUI 状态管理', '应用数据持久化概述', 'Preferences API']
  },
  {
    id: 'one-code-multi-device',
    order: 16,
    title: '你对“一多”的理解有那些，你开发过程中是如何适配的？',
    category: '一多适配',
    shortAnswer: '“一多”不是把手机页面放大，而是在一套工程和业务能力下，针对不同设备尺寸、交互方式和窗口形态重组体验。',
    answer: '我会从“一个工程、多端体验”回答。它强调复用业务能力，但 UI 不能简单拉伸：手机通常是单列沉浸式，平板和折叠屏要考虑分栏、列表详情、横竖屏和多窗口，2in1 还要考虑键鼠、焦点和更高信息密度。开发时应使用相对布局、断点、条件渲染、资源适配和 Navigation 等能力，让同一功能在不同窗口尺寸下呈现合适的信息结构。面试里要强调：一多适配的核心是信息架构重组，不是等比例缩放。',
    keyPoints: ['同一业务能力适配多设备', '根据窗口尺寸和设备形态重组布局', '使用断点、相对布局、条件渲染和资源适配', '考虑触控、键鼠、多窗口和横竖屏'],
    visualTitle: '官方结构重绘：一多适配',
    visualItems: ['手机', '折叠屏', '平板', '2in1', '多窗口'],
    visualNotes: ['单列优先', '展开态重排', '分栏和更高密度', '键鼠与焦点', '动态窗口尺寸'],
    sourceRefs: ['应用基础功能和兼容性体验建议', 'ArkUI 简介', 'Navigation 组件']
  }
];

@Entry
@Component
struct InterviewExperiencePage {
  @State private selectedIndex: number = 0;
  @State private isTablet: boolean = false;

  aboutToAppear(): void {
    this.updateLayoutMode();
  }

  onPageShow(): void {
    this.updateLayoutMode();
  }

  build() {
    Column() {
      this.PageHeader()

      if (this.isTablet) {
        this.TabletWorkspace()
      } else {
        Scroll() {
          Column() {
            this.PhoneQuestionList()
            this.DetailPanel()
          }
          .width('100%')
          .constraintSize({ maxWidth: 520 })
          .alignSelf(ItemAlign.Center)
          .padding({ left: 16, right: 16, top: 14, bottom: 18 })
        }
        .width('100%')
        .layoutWeight(1)
      }

      BottomNavBar({ active: 'home', isTablet: this.isTablet })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  PageHeader() {
    Row() {
      Button('<')
        .width(38)
        .height(34)
        .fontColor(COLOR_NAVY)
        .backgroundColor('#eef2f6')
        .borderRadius(8)
        .onClick(() => AppRouter.back())

      Column() {
        Text('常见面试题分享')
          .fontSize(this.isTablet ? 24 : 21)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .textAlign(TextAlign.Center)
          .width('100%')
        Text('高频开放题 · 官方口径整理 · 可直接复述')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Text(`${INTERVIEW_QUESTIONS.length}题`)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .borderRadius(8)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 14 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(this.isTablet ? 8 : 0)
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .margin({ top: this.isTablet ? 20 : 0 })
    .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  TabletWorkspace() {
    Row() {
      Column() {
        Row() {
          Text('问题清单')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .layoutWeight(1)
          Text(`${this.selectedIndex + 1}/${INTERVIEW_QUESTIONS.length}`)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .margin({ bottom: 10 })

        List() {
          ForEach(INTERVIEW_QUESTIONS, (item: InterviewQuestionItem, index: number) => {
            ListItem() {
              this.QuestionItem(item, index)
            }
            .padding({ bottom: 10 })
          }, (item: InterviewQuestionItem) => item.id)
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width(360)
      .height('100%')
      .padding(16)
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
      .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: 7 })
      .margin({ right: 16 })

      Scroll() {
        this.DetailPanel()
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 16, bottom: 18 })
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  PhoneQuestionList() {
    Column() {
      Row() {
        Text('选择问题')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text(`${this.selectedIndex + 1}/${INTERVIEW_QUESTIONS.length}`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ bottom: 10 })

      ForEach(INTERVIEW_QUESTIONS, (item: InterviewQuestionItem, index: number) => {
        this.QuestionItem(item, index)
      }, (item: InterviewQuestionItem) => item.id)
    }
    .width('100%')
    .margin({ bottom: 14 })
  }

  @Builder
  QuestionItem(item: InterviewQuestionItem, index: number) {
    Row() {
      Text(String(item.order))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedIndex === index ? '#ffffff' : COLOR_BLUE)
        .textAlign(TextAlign.Center)
        .width(34)
        .height(34)
        .backgroundColor(this.selectedIndex === index ? COLOR_BLUE : COLOR_SOFT_BLUE)
        .borderRadius(8)
        .margin({ right: 10 })

      Column() {
        Text(item.title)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .lineHeight(20)
          .maxLines(this.isTablet ? 2 : 3)
          .width('100%')
        Text(item.category)
          .fontSize(11)
          .fontColor(this.selectedIndex === index ? COLOR_BLUE : COLOR_MUTED)
          .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .margin({ bottom: this.isTablet ? 0 : 8 })
    .backgroundColor(this.selectedIndex === index ? '#f1f7fb' : COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: this.selectedIndex === index ? COLOR_BLUE : COLOR_LINE })
    .onClick(() => this.selectedIndex = index)
  }

  @Builder
  DetailPanel() {
    Column() {
      this.AnswerHeader()
      this.AnswerBlock()
      this.KeyPointBlock()
      this.OfficialImageBlock()
      this.VisualBlock()
      this.SourceBlock()
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  AnswerHeader() {
    Column() {
      Row() {
        Text(this.currentQuestion().category)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_GREEN)
          .backgroundColor(COLOR_SOFT_GREEN)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(8)
        Text(`第 ${this.currentQuestion().order} 题`)
          .fontSize(12)
          .fontColor(COLOR_BLUE)
          .backgroundColor(COLOR_SOFT_BLUE)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(8)
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.currentQuestion().title)
        .fontSize(this.isTablet ? 25 : 21)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .lineHeight(this.isTablet ? 34 : 29)
        .margin({ top: 16 })
        .width('100%')

      Text(this.currentQuestion().shortAnswer)
        .fontSize(15)
        .fontColor(COLOR_TEXT)
        .lineHeight(24)
        .margin({ top: 14 })
        .padding(14)
        .backgroundColor('#f6f8fb')
        .borderRadius(8)
        .border({ width: 1, color: COLOR_LINE })
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  AnswerBlock() {
    Column() {
      Text('解释答案')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .width('100%')
      Text(this.currentQuestion().answer)
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .lineHeight(24)
        .margin({ top: 10 })
        .width('100%')
    }
    .width('100%')
    .margin({ top: 20 })
  }

  @Builder
  KeyPointBlock() {
    Column() {
      Text('面试要点')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .width('100%')

      ForEach(this.currentQuestion().keyPoints, (point: string, index: number) => {
        Row() {
          Text(String(index + 1))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_ORANGE)
            .textAlign(TextAlign.Center)
            .width(26)
            .height(26)
            .backgroundColor(COLOR_SOFT_ORANGE)
            .borderRadius(8)
            .margin({ right: 10 })
          Text(point)
            .fontSize(14)
            .fontColor(COLOR_TEXT)
            .lineHeight(21)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
        .border({ width: { bottom: 1 }, color: COLOR_LINE })
      }, (point: string) => point)
    }
    .width('100%')
    .margin({ top: 20 })
  }

  @Builder
  OfficialImageBlock() {
    if (this.officialImageUrl().length > 0) {
      Column() {
        Row() {
          Text('官方原图')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .layoutWeight(1)
          Text(this.officialImageSource())
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .margin({ bottom: 12 })

        Image(this.officialImageUrl())
          .width('100%')
          .constraintSize({ maxHeight: this.isTablet ? 360 : 260 })
          .objectFit(ImageFit.Contain)
          .backgroundColor('#ffffff')
          .borderRadius(8)
      }
      .width('100%')
      .padding(14)
      .margin({ top: 20 })
      .backgroundColor('#f6f8fb')
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
    }
  }
  @Builder
  VisualBlock() {
    Column() {
      Text(this.currentQuestion().visualTitle)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .width('100%')

      Column() {
        ForEach(this.currentQuestion().visualItems, (label: string, index: number) => {
          this.VisualStep(label, index)
        }, (label: string) => label)
      }
      .width('100%')
      .margin({ top: 12 })
      .padding(14)
      .backgroundColor('#f6f8fb')
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
    }
    .width('100%')
    .margin({ top: 20 })
  }

  @Builder
  VisualStep(label: string, index: number) {
    Row() {
      Text(String(index + 1))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .textAlign(TextAlign.Center)
        .width(32)
        .height(32)
        .backgroundColor(this.visualColor(index))
        .borderRadius(8)
        .margin({ right: 12 })

      Column() {
        Text(label)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .width('100%')
        Text(this.visualNote(index))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 4 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .margin({ bottom: 8 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  SourceBlock() {
    Column() {
      Text('官方依据')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .width('100%')

      ForEach(this.currentQuestion().sourceRefs, (source: string) => {
        Row() {
          Text('文')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_GREEN)
            .textAlign(TextAlign.Center)
            .width(26)
            .height(26)
            .backgroundColor(COLOR_SOFT_GREEN)
            .borderRadius(8)
            .margin({ right: 10 })
          Text(source)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .lineHeight(20)
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .border({ width: { bottom: 1 }, color: COLOR_LINE })
      }, (source: string) => source)

      Text('说明：上方优先展示可匹配到的官方原图；部分纯文字 API 文档没有官方配图时，继续使用结构化学习图辅助理解。')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(19)
        .margin({ top: 10 })
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .margin({ top: 20 })
    .backgroundColor('#f6f8fb')
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  currentQuestion(): InterviewQuestionItem {
    if (this.selectedIndex < 0 || this.selectedIndex >= INTERVIEW_QUESTIONS.length) {
      return INTERVIEW_QUESTIONS[0];
    }
    return INTERVIEW_QUESTIONS[this.selectedIndex];
  }

  officialImageUrl(): string {
    const id = this.currentQuestion().id;
    const stageMain = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165516.12511130782831718348495875756103:50001231000000:2800:25673E33B577E82BA10148CF87375F37ED12B69A57471FE00704C97F33AE674D.png';
    const stageSecond = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165516.10191332575616953294548628096297:50001231000000:2800:23C96AC1F14E16DF27C917B54D2A690EFB9661085C5DFBC0B3C4F8E84F289A9D.png';
    const stagePackage = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165517.49393395611960099920348597179424:50001231000000:2800:79E3C97EF4B10DDF61C72A8868E7024AC40FAE9E3988C896692F3A52B54A8B0E.png';
    const arkuiOverview = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165850.23829896734382038425938112575418:50001231000000:2800:C6AD3F1F7067B0AF1232FC17BD679295B618205B13E668370FCCDA25FF74D238.png';
    const stateOverview = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165524.39349138882082066526555706903094:50001231000000:2800:DD1A2B36D857E0B900B7762467DD7B988B40AD275B499A8ACFAA394BF47140AC.png';
    const stateFlow = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165524.86996992020281498568724616556632:50001231000000:2800:E1927FA58BEDF1B3A8DA836B2F63D33D0378C75801D3706C74918ED5D764E5B4.png';
    const stateObject = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165524.17771775163729110118782028788845:50001231000000:2800:A8F9214C0CD5F2D39CBBD74D9F948C1127E01A6CF5643E9D7734879586981720.png';
    const stateDecorator = 'https://alliance-communityfile-drcn.dbankcdn.com/FileServer/getFile/cmtyPub/011/111/111/0000000000011111111.20250314165524.11990269869709231553847522300893:50001231000000:2800:59A2B35262B6B77D30C6FD74FCFCC1F9CA9FCDD3A4088031790ED2D8E529A2E1.png';
    if (id === 'stage-model-basic') {
      return stageMain;
    }
    if (id === 'package-difference' || id === 'cross-module-message') {
      return stagePackage;
    }
    if (id === 'lifecycle-flow') {
      return stageSecond;
    }
    if (id === 'arkts-ts' || id === 'responsive-declarative' || id === 'one-code-multi-device') {
      return arkuiOverview;
    }
    if (id === 'data-sharing' || id === 'ancestor-descendant-refresh') {
      return stateFlow;
    }
    if (id === 'realtime-refresh-sync' || id === 'dark-light-mode') {
      return stateOverview;
    }
    if (id === 'decorator-v1-v2') {
      return stateObject;
    }
    if (id === 'common-decorators') {
      return stateDecorator;
    }
    return '';
  }

  officialImageSource(): string {
    const id = this.currentQuestion().id;
    if (id === 'stage-model-basic' || id === 'package-difference' || id === 'cross-module-message' || id === 'lifecycle-flow') {
      return '华为开发者文档 · Stage 模型';
    }
    if (id === 'arkts-ts' || id === 'responsive-declarative' || id === 'one-code-multi-device') {
      return '华为开发者文档 · ArkUI';
    }
    if (id === 'data-sharing' || id === 'ancestor-descendant-refresh' || id === 'realtime-refresh-sync' || id === 'dark-light-mode' || id === 'decorator-v1-v2' || id === 'common-decorators') {
      return '华为开发者文档 · 状态管理';
    }
    return '';
  }
  visualNote(index: number): string {
    const notes = this.currentQuestion().visualNotes;
    if (index < 0 || index >= notes.length) {
      return '';
    }
    return notes[index];
  }

  pageMaxWidth(): number {
    return this.isTablet ? 1220 : 520;
  }

  visualColor(index: number): string {
    const colorIndex = index % 3;
    if (colorIndex === 0) {
      return COLOR_GREEN;
    }
    if (colorIndex === 1) {
      return COLOR_BLUE;
    }
    return COLOR_ORANGE;
  }

  updateLayoutMode(): void {
    try {
      const currentDisplay = display.getDefaultDisplaySync();
      const density = currentDisplay.densityPixels > 0 ? currentDisplay.densityPixels : 1;
      const shortSideVp = Math.min(currentDisplay.width, currentDisplay.height) / density;
      this.isTablet = shortSideVp >= TABLET_MIN_VP;
    } catch (error) {
      this.isTablet = false;
    }
  }
}
