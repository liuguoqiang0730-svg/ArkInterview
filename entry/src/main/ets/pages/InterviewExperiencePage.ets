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
    shortAnswer: 'Stage 模型把应用拆成应用、模块、Ability、窗口和页面几个层级，核心是用 AbilityStage 做模块级初始化，用 UIAbility 承载界面能力，并在 WindowStage 中加载页面。',
    answer: '我会从职责边界回答：Stage 模型是 HarmonyOS 当前主推的应用模型，它不只是一个生命周期名称，而是一套工程组织方式。应用由一个或多个 HAP 模块组成，模块加载时可以通过 AbilityStage 做资源预加载、全局初始化等模块级工作；具体面向用户界面的能力由 UIAbility 承载；UIAbility 创建 WindowStage 后再加载 ArkUI 页面。实际开发中要避免把页面逻辑塞进 AbilityStage，也不要在还没有 WindowStage 时处理页面加载。',
    keyPoints: ['AbilityStage 偏 HAP 或模块级生命周期', 'UIAbility 偏具体界面能力和前后台状态', 'WindowStage 是窗口创建、页面加载的关键阶段', 'Stage 模型强调工程职责拆分'],
    visualTitle: 'Stage 层级图',
    visualItems: ['Application', 'HAP / AbilityStage', 'UIAbility', 'WindowStage', 'ArkUI Page']
  },
  {
    id: 'data-sharing',
    order: 2,
    title: '数据共享如何实现？说一下你了解的。',
    category: '数据共享',
    shortAnswer: '先按数据作用域选方案：组件内用状态变量，父子用 Prop/Link，跨层级用 Provide/Consume，页面或应用级用 LocalStorage/AppStorage，持久共享再用 Preferences、关系库或服务端。',
    answer: '数据共享不能只背一个 API，要先判断数据生命周期和作用域。组件内部状态适合用本组件持有的状态；父子之间用单向传值或双向绑定；祖先到深层子孙可以用 Provide/Consume；页面级或应用级共享可以放到 LocalStorage、AppStorage 或统一的状态管理服务中。需要离线保存或跨启动保留时，再落到 Preferences、关系型数据库、文件或服务端。我的原则是：短生命周期放状态，长生命周期放存储，跨端一致性放服务端。',
    keyPoints: ['先判断作用域：组件、页面、应用、设备、云端', 'UI 刷新依赖可观察状态，而不是普通全局变量', '持久化和实时共享不要混为一谈', '服务端才适合做多设备最终一致'],
    visualTitle: '按作用域选型',
    visualItems: ['组件状态', '父子绑定', '跨层级注入', '应用级状态', '本地/云端存储']
  },
  {
    id: 'realtime-refresh-sync',
    order: 3,
    title: '如何实现数据实时刷新？数据同步？',
    category: '状态同步',
    shortAnswer: '实时刷新靠单一数据源和响应式状态驱动 UI；数据同步靠本地缓存、版本号、时间戳、增量拉取或服务端推送，并处理冲突和失败重试。',
    answer: '我会把“实时刷新”和“数据同步”分开讲。页面实时刷新是 UI 层问题，关键是把数据放在可观察状态里，由状态变化驱动 build 更新，不要手动操作视图。数据同步是数据层问题，常见做法是进入页面或回前台时刷新，本地写入后更新缓存并上报服务端；对实时性要求高的场景可以用 WebSocket、长连接或轮询；对可靠性要求高的场景要设计版本号、更新时间、脏数据标记、失败重试和冲突策略。',
    keyPoints: ['单一数据源减少状态分叉', 'UI 刷新由状态变化触发', '同步需要缓存、版本和冲突处理', '高实时场景才上推送或长连接'],
    visualTitle: '刷新与同步链路',
    visualItems: ['用户操作', '更新状态', '刷新 UI', '写入缓存', '同步服务端']
  },
  {
    id: 'promise-understanding',
    order: 4,
    title: '说你下你对 Promise 的理解？有没有研究过它的底层代码。',
    category: 'ArkTS / 异步',
    shortAnswer: 'Promise 是异步结果的状态容器，状态从 pending 变为 fulfilled 或 rejected 后不可逆；then/catch/finally 通过微任务调度串联异步流程。',
    answer: 'Promise 不是线程，也不会让同步代码自动并行。它本质上是对未来异步结果的封装，有 pending、fulfilled、rejected 三种状态，状态一旦确定就不可再改变。then 会返回新的 Promise，所以可以链式组合；catch 处理拒绝态；finally 做收尾。底层重点是状态机、回调队列、微任务调度和 Promise Resolution Procedure：如果 then 返回普通值，新 Promise fulfilled；如果返回另一个 Promise，新 Promise 会跟随它的状态。实际开发中我会配合 async/await 使用，但仍要注意异常捕获和并发控制。',
    keyPoints: ['Promise 是状态机，不是线程', '状态确定后不可逆', 'then 返回新 Promise，支持链式调用', '回调通常进入微任务队列'],
    visualTitle: 'Promise 状态机',
    visualItems: ['pending', 'fulfilled', 'then 链', 'rejected', 'catch/finally']
  },
  {
    id: 'package-difference',
    order: 5,
    title: '你觉得 har、hsp、hap 有什么区别？',
    category: '工程化',
    shortAnswer: 'HAP 是可安装运行的功能包；HAR 是静态共享库，编译时打进依赖模块；HSP 是动态共享包，适合在同一应用内复用代码和资源并减少重复打包。',
    answer: '我会从“能不能独立安装运行、依赖怎么被打包、适合什么场景”回答。HAP 是 HarmonyOS Ability Package，entry 或 feature 模块最终会打成 HAP，是应用安装运行的基本单元。HAR 更像静态库，适合沉淀工具类、通用组件和业务基础能力，使用方编译时会把它打进自己的包里。HSP 是共享包，偏动态复用，适合多个模块共享同一份实现或资源，降低重复打包。选择时要看模块边界、复用范围、包体和运行期约束。',
    keyPoints: ['HAP：安装和运行单元', 'HAR：静态库，编译期合入', 'HSP：共享包，运行期复用能力更强', '公共能力优先抽 HAR/HSP，不要复制代码'],
    visualTitle: '包类型对比',
    visualItems: ['HAP 可运行', 'HAR 静态复用', 'HSP 动态共享', 'App Pack']
  },
  {
    id: 'arkts-ts',
    order: 6,
    title: '你觉得 ArkTS、TS 两者之间有什么区别和共同点？',
    category: 'ArkTS',
    shortAnswer: 'ArkTS 保留 TypeScript 的很多语法基础，但面向 HarmonyOS 和 ArkUI 做了更严格的静态约束，减少动态特性，提高可分析性、稳定性和性能。',
    answer: '共同点是两者都有类、接口、模块、泛型、Promise、async/await 等现代语言特性，开发者从 TS 转 ArkTS 会比较容易。区别是 ArkTS 面向 HarmonyOS 原生开发和 ArkUI 声明式 UI，对类型、对象字面量、动态属性、any、函数重载等会更严格，很多写法不能按前端 TS 的习惯来。我的理解是：TS 更偏 Web 生态的灵活性，ArkTS 更偏移动端原生应用的可编译、可优化和工程稳定性。',
    keyPoints: ['语法风格接近 TS', 'ArkTS 静态检查更严格', 'ArkTS 深度结合 ArkUI 和系统 API', '迁移时要主动减少动态写法'],
    visualTitle: '语言关系图',
    visualItems: ['TypeScript 基础', 'ArkTS 严格类型', 'ArkUI 声明式 UI', 'HarmonyOS 原生能力']
  },
  {
    id: 'router-navigation',
    order: 7,
    title: '你对路由跳转和 Navigation 的理解。',
    category: '路由导航',
    shortAnswer: 'router 更像页面级命令式跳转，适合简单页面栈；Navigation 是 ArkUI 声明式导航容器，适合列表详情、分栏、自适应和复杂页面结构。',
    answer: 'router.pushUrl 这类方式适合简单页面跳转，比如从首页进入练习页、从列表进入详情页。Navigation 更偏 ArkUI 组件体系里的导航容器，可以通过 NavPathStack 管理路径，适合列表详情、多级页面、平板分栏和复杂导航状态。实际开发中，简单业务可以先用 router；当页面需要保留导航栈、适配大屏分栏、处理详情页路径状态时，Navigation 会更自然。',
    keyPoints: ['router：命令式页面跳转', 'Navigation：声明式导航容器', 'NavPathStack 更适合复杂路径管理', '平板和折叠屏更适合 Navigation 思路'],
    visualTitle: '导航选择',
    visualItems: ['简单跳转', 'router', '复杂层级', 'Navigation', '自适应布局']
  },
  {
    id: 'persistence',
    order: 8,
    title: '如果要实现持久化，可以采用那些方式？',
    category: '数据存储',
    shortAnswer: '轻量配置用 Preferences；结构化列表和查询用 relationalStore；文件适合大文本、图片、导入导出；跨设备或账号数据放服务端。',
    answer: '我会先看数据形态。用户开关、主题、最近选择这种小型键值数据适合 Preferences；题库缓存、练习记录、错题收藏这种结构化数据，更适合关系型数据库，便于查询、排序和统计；大文件、图片或导入导出数据适合文件系统；需要多端同步、换机保留或团队共享的数据应该放服务端。本地持久化还要考虑版本升级、数据迁移、加密和清理策略。',
    keyPoints: ['Preferences：轻量键值配置', 'relationalStore：结构化数据和复杂查询', '文件：大对象和导入导出', '服务端：账号、多端和长期同步'],
    visualTitle: '持久化选型',
    visualItems: ['配置项', 'Preferences', '结构化数据', 'RDB', '文件/服务端']
  },
  {
    id: 'responsive-declarative',
    order: 9,
    title: '你对响应式开发和声明式开发有啥看法，实际开发过程中有什么区别？',
    category: 'ArkUI',
    shortAnswer: '声明式开发是用状态描述 UI，状态变了 UI 自动重建；响应式开发更强调 UI 能随状态、窗口尺寸、主题和设备形态变化而更新和适配。',
    answer: '声明式开发解决的是“怎么写 UI”：开发者描述当前状态下 UI 应该长什么样，而不是手动查找控件再修改控件。响应式开发解决的是“UI 怎么跟变化联动”：数据变化、窗口尺寸变化、深浅色变化、设备形态变化时，页面能自动更新。实际开发中二者是配合关系：用状态驱动声明式 UI，用断点、相对布局、条件渲染和资源适配完成手机、平板、折叠屏的一多体验。',
    keyPoints: ['声明式：UI = f(state)', '响应式：状态或环境变化后自动更新', '少写手动 DOM/控件更新逻辑', '实际要结合断点和自适应布局'],
    visualTitle: 'UI 更新模型',
    visualItems: ['State', 'build()', 'UI', '窗口尺寸', '自适应布局']
  },
  {
    id: 'cross-module-message',
    order: 10,
    title: '若要实现跨模块信息传递，你如何实现？有那些方式？',
    category: '模块通信',
    shortAnswer: '跨模块传递要按强弱依赖选择：公共接口放 HAR/HSP，页面跳转传轻量参数，共享状态放应用级状态或服务层，持久结果放数据库或服务端。',
    answer: '我不会直接让模块互相到处 import 业务实现。比较稳的方式是把公共模型、接口和工具沉到 HAR 或 HSP；页面间只通过路由参数传递小而稳定的上下文；复杂业务数据通过统一 service/repository 或状态管理层暴露；需要跨启动、跨设备保存的数据落到本地数据库或服务端。事件通知也可以用，但要控制生命周期和解绑，避免隐式依赖过多。',
    keyPoints: ['公共模型和能力抽到共享模块', '路由参数只传轻量上下文', '业务数据走 service/repository', '事件机制要注意解绑和可维护性'],
    visualTitle: '跨模块通信路径',
    visualItems: ['Feature A', 'Shared HAR/HSP', 'Service', 'Storage/API', 'Feature B']
  },
  {
    id: 'decorator-v1-v2',
    order: 11,
    title: '你对装饰器 V1 和 V2 的理解。',
    category: '状态管理',
    shortAnswer: 'V1 是常见的 @State、@Prop、@Link、@Provide、@Consume 等状态管理方式；V2 更强调可观察对象和精细化追踪，适合复杂对象状态，但项目中要看 API 版本和团队规范。',
    answer: '我会谨慎回答版本差异：V1 里最常用的是 @State 管理组件内状态，@Prop 接收父组件单向数据，@Link 做父子双向同步，@Provide/@Consume 做跨层级共享，@Observed/@ObjectLink 处理对象观察。V2 的方向是让复杂对象的状态追踪更清晰，常见会涉及 @ObservedV2、@Trace 等能力，用来改善对象内部属性变化的观察和刷新。工程里我不会为了新而新，而是先看当前 SDK、团队规范和兼容范围，避免 V1/V2 混用造成维护成本。',
    keyPoints: ['V1 覆盖常见组件状态和父子通信', 'V2 更关注复杂对象的可观察性', '选择前确认 API 版本和项目规范', '状态所有权比装饰器名字更重要'],
    visualTitle: '装饰器演进',
    visualItems: ['V1 基础状态', '父子/跨层级', '对象观察', 'V2 精细追踪']
  },
  {
    id: 'lifecycle-flow',
    order: 12,
    title: '生命周期这一块有去了解吗？详细说一下它们的流程（UIAbility、页面、组件）。',
    category: '生命周期',
    shortAnswer: 'UIAbility 关注创建、窗口、前后台和销毁；页面关注显示隐藏；组件关注创建前、构建和销毁。回答时要把三层职责分开。',
    answer: 'UIAbility 冷启动一般先进入 onCreate 做业务初始化，随后 onWindowStageCreate 拿到 WindowStage 并加载页面；进入前台会触发 onForeground，退到后台触发 onBackground；窗口销毁时有 onWindowStageDestroy，Ability 结束时有 onDestroy。ArkUI 页面常见关注 aboutToAppear、onPageShow、onPageHide、aboutToDisappear；组件层关注 aboutToAppear、build、aboutToDisappear 等。面试时我会强调：Ability 生命周期不等于页面生命周期，组件 build 也不是生命周期回调，而是声明 UI 的核心函数。',
    keyPoints: ['UIAbility：实例、窗口、前后台、销毁', '页面：显示和隐藏', '组件：出现、构建、消失', '不要把页面加载放到没有 WindowStage 的阶段'],
    visualTitle: '生命周期分层',
    visualItems: ['UIAbility onCreate', 'WindowStageCreate', 'Page Show/Hide', 'Component build', 'Destroy']
  },
  {
    id: 'common-decorators',
    order: 13,
    title: '开发过程中，常用的装饰器有那些？',
    category: 'ArkUI 装饰器',
    shortAnswer: '常用有 @Entry、@Component、@State、@Prop、@Link、@Provide、@Consume、@Observed、@ObjectLink、@Builder、@BuilderParam、@Styles 等。',
    answer: '我会按用途分类回答。页面和组件声明常见是 @Entry、@Component；状态管理常见是 @State、@Prop、@Link、@Provide、@Consume、@Observed、@ObjectLink；UI 复用常见是 @Builder、@BuilderParam、@Styles。实际项目中最重要的不是背名字，而是知道状态所有权：谁拥有状态、谁只读、谁可以回写、谁只是触发事件。',
    keyPoints: ['组件声明：@Entry、@Component', '状态传递：@State、@Prop、@Link', '跨层级：@Provide、@Consume', '复用构建：@Builder、@Styles'],
    visualTitle: '装饰器分类',
    visualItems: ['组件声明', '状态管理', '跨层级共享', 'UI 复用']
  },
  {
    id: 'ancestor-descendant-refresh',
    order: 14,
    title: '祖先组件和子孙组件的数据传输，若要实现 UI 刷新，可采用那些方式？你认为最应该采取那种方式？',
    category: '组件通信',
    shortAnswer: '祖先到深层子孙最推荐 @Provide/@Consume；父子少层级可用 Prop/Link；全局状态才考虑 AppStorage 或状态服务，持久化不应当只为 UI 刷新而使用。',
    answer: '如果只是祖先和深层子孙共享 UI 状态，我优先用 @Provide/@Consume，因为它能避免多层透传，也能保持响应式刷新。如果只有一两层父子关系，用 @Prop 或 @Link 更直观。全局状态、多个页面共享状态，可以抽到 AppStorage、LocalStorage 或状态服务。数据库、Preferences 更适合持久化，不适合为了组件刷新频繁读写。我的选择顺序是：先看状态作用域，局部就局部解决，跨层级用 Provide/Consume，跨页面再上应用级状态。',
    keyPoints: ['避免为了深层传值层层透传', '@Provide/@Consume 适合祖先和子孙响应式共享', '@Link 适合需要子组件回写父组件的场景', '持久化不是 UI 刷新的首选工具'],
    visualTitle: '祖孙通信方案',
    visualItems: ['Ancestor @Provide', 'Descendant @Consume', '状态变化', '自动刷新 UI']
  },
  {
    id: 'dark-light-mode',
    order: 15,
    title: '如何实现深浅色模式的切换？',
    category: '主题适配',
    shortAnswer: '用系统颜色模式或应用内主题状态驱动一套主题 token，颜色不要硬编码；用户选择可持久化到 Preferences，状态变化后触发页面重建。',
    answer: '我会把主题当成全局 UI 状态管理。首先定义颜色 token，比如背景、文字、分割线、主色、卡片色，而不是在每个组件里散落硬编码颜色。主题来源可以跟随系统，也可以提供应用内开关；用户选择需要存到 Preferences；页面通过应用级状态或主题服务读取当前模式，模式变化后触发 ArkUI 重建。适配时还要检查图片、图标、阴影、边框和禁用态，不能只改背景色。',
    keyPoints: ['主题 token 集中管理', '支持跟随系统或应用内开关', '用户选择用 Preferences 保存', '检查图标、边框、阴影和对比度'],
    visualTitle: '主题切换链路',
    visualItems: ['系统/用户选择', 'ThemeState', 'Color Tokens', 'ArkUI 重建', '持久化偏好']
  },
  {
    id: 'one-code-multi-device',
    order: 16,
    title: '你对“一多”的理解有那些，你开发过程中是如何适配的？',
    category: '一多适配',
    shortAnswer: '“一多”是一次开发、多端部署、多设备协同体验。开发中要按窗口尺寸、设备形态、输入方式和交互密度做自适应，而不是只拉伸手机布局。',
    answer: '我的理解是“一多”不是把一个手机页面等比例放大，而是用同一套工程和业务能力，在手机、平板、折叠屏、2in1 等设备上提供合适体验。开发时我会先设计断点：手机单列、平板左右分栏、宽屏增加信息密度；控件尺寸和间距使用相对布局，列表详情可以用 Navigation 或分栏；同时考虑横竖屏、多窗口、键鼠、触控和深浅色。比如这个刷题 App，手机更适合单题沉浸，平板更适合左侧题单右侧答题和统计。',
    keyPoints: ['不是简单拉伸，而是按设备重组信息结构', '断点、分栏、相对尺寸是核心', '考虑横竖屏、多窗口、键鼠和触控', '同一业务能力适配多种交互密度'],
    visualTitle: '一多布局策略',
    visualItems: ['手机单列', '折叠屏双态', '平板分栏', '2in1 键鼠', '多窗口']
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
      this.VisualBlock()
      this.SourceNote()
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
        .width(30)
        .height(30)
        .backgroundColor(this.visualColor(index))
        .borderRadius(8)
        .margin({ right: 10 })
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
      if (index + 1 < this.currentQuestion().visualItems.length) {
        Text('↓')
          .fontSize(14)
          .fontColor(COLOR_MUTED)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .height(42)
  }

  @Builder
  SourceNote() {
    Column() {
      Text('资料口径')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .width('100%')
      Text('本栏按 HarmonyOS / OpenHarmony 官方文档中的 Stage 模型、ArkUI、状态管理、应用包、数据管理和一多适配概念整理；属于面试表达材料，不直接混入刷题题库。')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(19)
        .margin({ top: 8 })
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .margin({ top: 20 })
    .backgroundColor(COLOR_SOFT_GREEN)
    .borderRadius(8)
  }

  currentQuestion(): InterviewQuestionItem {
    if (this.selectedIndex < 0 || this.selectedIndex >= INTERVIEW_QUESTIONS.length) {
      return INTERVIEW_QUESTIONS[0];
    }
    return INTERVIEW_QUESTIONS[this.selectedIndex];
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