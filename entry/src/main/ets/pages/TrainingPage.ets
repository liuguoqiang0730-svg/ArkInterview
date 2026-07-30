import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { Category, CategoryStats, UserStats } from '../models/QuestionModels';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';
import { FormatUtils } from '../utils/FormatUtils';
import { PracticeEvents } from '../utils/PracticeEvents';
import { PracticeStore } from '../viewmodels/PracticeStore';

const store = new PracticeStore();
const COLOR_BG: string = '#f3f5f8';
const COLOR_SURFACE: string = '#ffffff';
const COLOR_NAVY: string = '#102033';
const COLOR_TEXT: string = '#1f2a37';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_GREEN: string = '#16745f';
const COLOR_BLUE: string = '#2c5f8f';
const COLOR_ORANGE: string = '#d97924';
const COLOR_RED: string = '#b54747';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_RED: string = '#fcebea';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct TrainingPage {
  @State private categories: Category[] = [];
  @State private stats: UserStats | undefined = undefined;
  @State private loading: boolean = true;
  @State private loadError: string = '';
  @State private isTablet: boolean = false;
  @State private categoryKeyword: string = '';
  @State private showSetup: boolean = false;
  @State private setupMode: string = 'random';
  @State private setupTitle: string = '随机练习';
  @State private setupCategoryId: string = '';
  @State private setupCount: number = 20;
  @State private setupType: string = '';
  @State private setupDifficulty: string = '';
  private observedStatsVersion: number = 0;
  private pendingSetupMode: string = '';
  private pendingSetupCategoryId: string = '';
  private pendingSetupTitle: string = '';

  aboutToAppear(): void {
    this.updateLayoutMode();
    const params = AppRouter.params(this.getUIContext());
    this.pendingSetupMode = params.mode || '';
    this.pendingSetupCategoryId = params.categoryId || '';
    this.pendingSetupTitle = params.title || '';
    this.loadTraining();
  }

  onPageShow(): void {
    this.updateLayoutMode();
    if (this.observedStatsVersion !== PracticeEvents.currentStatsVersion()) {
      this.loadTraining();
    }
  }

  private async loadTraining(): Promise<void> {
    this.loading = true;
    this.loadError = '';
    try {
      const snapshot = await store.loadHome();
      this.categories = snapshot.categories;
      this.stats = snapshot.stats;
      this.observedStatsVersion = PracticeEvents.currentStatsVersion();
      this.openPendingSetup();
    } catch (error) {
      this.loadError = `训练数据加载失败：${String(error)}`;
    } finally {
      this.loading = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Column() {
          this.Header()

          if (this.loading) {
            this.LoadingState()
          } else if (this.loadError.length > 0) {
            this.ErrorState()
          } else if (this.isTablet) {
            this.TabletWorkspace()
          } else {
            Scroll() {
              this.PhoneWorkspace()
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
          }
        }
        .width('100%')
        .layoutWeight(1)

        BottomNavBar({ active: 'practice', isTablet: this.isTablet, isRootPage: true })
      }
      .width('100%')
      .height('100%')

      if (this.showSetup) {
        this.SetupOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  Header() {
    Row() {
      Column() {
        Text('训练中心')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
        Text('选择训练方式或按知识模块系统练习')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('刷新')
        .height(36)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .borderRadius(8)
        .onClick(() => this.loadTraining())
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 15, bottom: 14 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(this.isTablet ? 8 : 0)
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .margin({ top: this.isTablet ? 20 : 0 })
  }

  @Builder
  LoadingState() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(COLOR_GREEN)
      Text('正在准备训练内容')
        .fontSize(14)
        .fontColor(COLOR_MUTED)
        .margin({ top: 12 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ErrorState() {
    Column() {
      Text('训练内容暂时无法加载')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
      Text(this.loadError)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
      Button('重新加载')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .backgroundColor(COLOR_GREEN)
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => this.loadTraining())
    }
    .width('100%')
    .padding(22)
    .margin({ left: 18, right: 18, top: 20 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
    .constraintSize({ maxWidth: 520 })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  SetupOverlay() {
    Stack({ alignContent: this.isTablet ? Alignment.Center : Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#10203352')
        .onClick(() => this.showSetup = false)

      this.SetupPanel()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SetupPanel() {
    Column() {
      Row() {
        Column() {
          Text('训练设置')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text(this.setupTitle)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('×')
          .width(34)
          .height(34)
          .fontSize(19)
          .fontColor(COLOR_MUTED)
          .backgroundColor('#eef2f6')
          .borderRadius(8)
          .onClick(() => this.showSetup = false)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 14 })
      .border({ width: { bottom: 1 }, color: COLOR_LINE })

      Scroll() {
        Column() {
          this.SetupSummary()
          this.CountSelector()

          if (this.setupMode === 'interview') {
            Row() {
              Text('面')
                .width(36)
                .height(36)
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(COLOR_BLUE)
                .textAlign(TextAlign.Center)
                .backgroundColor(COLOR_SOFT_BLUE)
                .borderRadius(8)
                .margin({ right: 11 })
              Column() {
                Text('保持混合题型与难度')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(COLOR_TEXT)
                Text('优先覆盖简答、单选、多选和判断，接近真实面试节奏')
                  .fontSize(11)
                  .fontColor(COLOR_MUTED)
                  .lineHeight(17)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(13)
            .margin({ top: 16 })
            .backgroundColor(COLOR_SOFT_BLUE)
            .border({ width: 1, color: '#d6e4f2' })
            .borderRadius(8)
          } else {
            this.TypeSelector()
            this.DifficultySelector()
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 16 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)

      Button('开始训练')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .backgroundColor(COLOR_GREEN)
        .borderRadius(8)
        .margin({ left: 18, right: 18, bottom: this.isTablet ? 18 : 22 })
        .onClick(() => this.startConfiguredTraining())
    }
    .width(this.isTablet ? 520 : '100%')
    .height(this.isTablet ? 560 : '86%')
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(this.isTablet ? 8 : { topLeft: 8, topRight: 8 })
    .border({ width: 1, color: COLOR_LINE })
    .shadow({ radius: 20, color: '#10203333', offsetX: 0, offsetY: -6 })
  }

  @Builder
  SetupSummary() {
    Row() {
      Text(this.setupModeMark())
        .width(40)
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.setupModeColor())
        .textAlign(TextAlign.Center)
        .backgroundColor(this.setupModeSoftColor())
        .borderRadius(8)
        .margin({ right: 12 })

      Column() {
        Text(this.setupTitle)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text(this.setupScopeText())
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${this.setupCount} 题`)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.setupModeColor())
    }
    .width('100%')
    .padding(13)
    .margin({ top: 16 })
    .backgroundColor('#f8fafc')
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  CountSelector() {
    Column() {
      this.SetupSectionTitle('题量', this.setupMode === 'interview' ? '建议 8-10 题' : '本轮抽取数量')

      Row() {
        if (this.setupMode === 'interview') {
          this.SetupChoice('5', this.setupCount === 5, '23.5%', () => this.setupCount = 5)
          this.SetupChoice('8', this.setupCount === 8, '23.5%', () => this.setupCount = 8)
          this.SetupChoice('10', this.setupCount === 10, '23.5%', () => this.setupCount = 10)
          this.SetupChoice('15', this.setupCount === 15, '23.5%', () => this.setupCount = 15)
        } else {
          this.SetupChoice('5', this.setupCount === 5, '23.5%', () => this.setupCount = 5)
          this.SetupChoice('10', this.setupCount === 10, '23.5%', () => this.setupCount = 10)
          this.SetupChoice('20', this.setupCount === 20, '23.5%', () => this.setupCount = 20)
          this.SetupChoice('30', this.setupCount === 30, '23.5%', () => this.setupCount = 30)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 10 })
    }
    .width('100%')
    .margin({ top: 18 })
  }

  @Builder
  TypeSelector() {
    Column() {
      this.SetupSectionTitle('题型', '选择一种或保持混合')

      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Start
      }) {
        this.SetupChoice('全部', this.setupType === '', '31.8%', () => this.setupType = '')
        this.SetupChoice('单选', this.setupType === 'single', '31.8%', () => this.setupType = 'single')
        this.SetupChoice('多选', this.setupType === 'multiple', '31.8%', () => this.setupType = 'multiple')
        this.SetupChoice('判断', this.setupType === 'boolean', '31.8%', () => this.setupType = 'boolean')
        this.SetupChoice('简答', this.setupType === 'short', '31.8%', () => this.setupType = 'short')
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .margin({ top: 18 })
  }

  @Builder
  DifficultySelector() {
    Column() {
      this.SetupSectionTitle('难度', '按当前能力安排')

      Row() {
        this.SetupChoice('全部', this.setupDifficulty === '', '23.5%', () => this.setupDifficulty = '')
        this.SetupChoice('基础', this.setupDifficulty === 'easy', '23.5%', () => this.setupDifficulty = 'easy')
        this.SetupChoice('中等', this.setupDifficulty === 'medium', '23.5%', () => this.setupDifficulty = 'medium')
        this.SetupChoice('困难', this.setupDifficulty === 'hard', '23.5%', () => this.setupDifficulty = 'hard')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 10 })
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  SetupSectionTitle(title: string, hint: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .layoutWeight(1)
      Text(hint)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
  }

  @Builder
  SetupChoice(label: string, selected: boolean, width: string, action: () => void) {
    Button(label)
      .width(width)
      .height(38)
      .fontSize(13)
      .fontWeight(selected ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(selected ? '#ffffff' : COLOR_TEXT)
      .backgroundColor(selected ? COLOR_GREEN : '#f6f8fb')
      .border({ width: 1, color: selected ? COLOR_GREEN : COLOR_LINE })
      .borderRadius(8)
      .margin({ bottom: 8 })
      .onClick(action)
  }

  @Builder
  TabletWorkspace() {
    Row() {
      Scroll() {
        Column() {
          this.OverviewPanel()
          this.ModeSection()
        }
        .width('100%')
        .padding({ right: 8, bottom: 20 })
      }
      .layoutWeight(4)
      .height('100%')
      .scrollBar(BarState.Auto)

      Column() {
        this.CategoryToolbar()
        this.CategoryGrid()
      }
      .layoutWeight(6)
      .height('100%')
      .margin({ left: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 16 })
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  PhoneWorkspace() {
    Column() {
      this.OverviewPanel()
      this.ModeSection()
      this.CategoryToolbar()
      this.CategoryGrid()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  OverviewPanel() {
    Column() {
      Row() {
        Column() {
          Text('训练概览')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
          Text('从练习数据继续安排本轮训练')
            .fontSize(12)
            .fontColor('#d8efe8')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(FormatUtils.percent(this.stats?.accuracy ?? 0))
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
      }
      .width('100%')

      Row() {
        this.OverviewMetric('已覆盖', String(this.stats?.answeredQuestionCount ?? 0))
        this.OverviewMetric('待复盘', String(this.stats?.wrongCount ?? 0))
        this.OverviewMetric('已收藏', String(this.stats?.favoriteCount ?? 0))
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_NAVY)
    .borderRadius(8)
    .shadow({ radius: 16, color: COLOR_SHADOW, offsetX: 0, offsetY: 7 })
  }

  @Builder
  OverviewMetric(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
      Text(label)
        .fontSize(11)
        .fontColor('#d8efe8')
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 3, right: 3 })
    .backgroundColor('#ffffff14')
    .borderRadius(8)
    .border({ width: 1, color: '#ffffff26' })
  }

  @Builder
  ModeSection() {
    Column() {
      Row() {
        Column() {
          Text('训练方式')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text('按目标选择本轮练习')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 11 })

      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.Wrap,
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Start
      }) {
        this.ModeCard('练', '随机练习', '自定义题量、题型和难度', '配置', COLOR_GREEN, COLOR_SOFT_GREEN, 'random')
        this.ModeCard('面', '模拟面试', '自定义题量，保持混合题型', '配置', COLOR_BLUE, COLOR_SOFT_BLUE, 'interview')
        this.ModeCard(
          '错',
          '错题练习',
          '集中处理尚未掌握的题目',
          `${this.stats?.wrongCount ?? 0} 道`,
          COLOR_RED,
          COLOR_SOFT_RED,
          'wrongs'
        )
        this.ModeCard(
          '藏',
          '收藏复习',
          '回看已收藏的重点题目',
          `${this.stats?.favoriteCount ?? 0} 道`,
          COLOR_ORANGE,
          COLOR_SOFT_ORANGE,
          'favorites'
        )
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .margin({ top: 14 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  ModeCard(
    mark: string,
    title: string,
    detail: string,
    meta: string,
    color: string,
    softColor: string,
    mode: string
  ) {
    Column() {
      Row() {
        Text(mark)
          .width(34)
          .height(34)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .textAlign(TextAlign.Center)
          .backgroundColor(softColor)
          .borderRadius(8)
        Text(meta)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .width('100%')
        .margin({ top: 11 })

      Text(detail)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .lineHeight(17)
        .maxLines(2)
        .width('100%')
        .margin({ top: 5 })
    }
    .width('48.7%')
    .height(126)
    .padding(12)
    .margin({ bottom: 10 })
    .backgroundColor(this.modeEnabled(mode) ? '#ffffff' : '#f8fafc')
    .border({ width: 1, color: this.modeEnabled(mode) ? COLOR_LINE : '#edf0f4' })
    .borderRadius(8)
    .opacity(this.modeEnabled(mode) ? 1 : 0.72)
    .onClick(() => this.handleMode(mode))
  }

  @Builder
  CategoryToolbar() {
    Column() {
      Row() {
        Column() {
          Text('模块训练')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text(`${this.filteredCategories().length}/${this.categories.length} 个模块 · 共 ${this.totalPublishedCount()} 道题`)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      TextInput({ placeholder: '搜索模块名称或介绍', text: this.categoryKeyword })
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .placeholderColor('#98a2b3')
        .backgroundColor(COLOR_SURFACE)
        .border({ width: 1, color: COLOR_LINE })
        .borderRadius(8)
        .margin({ top: 12 })
        .onChange((value: string) => {
          this.categoryKeyword = value;
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  CategoryGrid() {
    if (this.filteredCategories().length === 0) {
      Column() {
        Text('没有匹配的训练模块')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text('调整搜索关键词后重新查看')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 6 })
        Button('清空搜索')
          .height(36)
          .fontSize(13)
          .fontColor(COLOR_GREEN)
          .backgroundColor(COLOR_SOFT_GREEN)
          .borderRadius(8)
          .margin({ top: 12 })
          .onClick(() => this.categoryKeyword = '')
      }
      .width('100%')
      .padding(20)
      .margin({ top: 12 })
      .backgroundColor(COLOR_SURFACE)
      .border({ width: 1, color: COLOR_LINE })
      .borderRadius(8)
    } else if (this.isTablet) {
      List() {
        ForEach(this.filteredCategories(), (category: Category) => {
          ListItem() {
            this.CategoryCard(category)
          }
          .padding({ bottom: 10 })
        }, (category: Category) => category.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ top: 12, bottom: 12 })
      .scrollBar(BarState.Auto)
    } else {
      Column() {
        ForEach(this.filteredCategories(), (category: Category) => {
          this.CategoryCard(category)
        }, (category: Category) => category.id)
      }
      .width('100%')
      .padding({ top: 12 })
    }
  }

  @Builder
  CategoryCard(category: Category) {
    Row() {
      Text(this.categoryMark(category.name))
        .width(44)
        .height(44)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.categoryColor(category.order))
        .textAlign(TextAlign.Center)
        .backgroundColor(this.categorySoftColor(category.order))
        .borderRadius(8)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(category.name)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.categoryProgress(category.id))
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.categoryColor(category.order))
            .backgroundColor(this.categorySoftColor(category.order))
            .padding({ left: 7, right: 7, top: 4, bottom: 4 })
            .borderRadius(8)
        }
        .width('100%')

        Text(category.description)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })

        Row() {
          Column()
            .width(FormatUtils.percent(this.categoryCompletionRate(category.id)))
            .height(5)
            .backgroundColor(this.categoryColor(category.order))
            .borderRadius(3)
        }
        .width('100%')
        .height(5)
        .backgroundColor('#eef2f6')
        .borderRadius(3)
        .margin({ top: 9 })

        Row() {
          Text(this.categoryStatusText(category.id))
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text('设置 >')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.categoryColor(category.order))
        }
        .width('100%')
        .margin({ top: 8 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
    .shadow({ radius: 9, color: COLOR_SHADOW, offsetX: 0, offsetY: 4 })
    .onClick(() => this.prepareTraining('category', category))
  }

  private filteredCategories(): Category[] {
    const keyword = this.categoryKeyword.trim().toLowerCase();
    if (keyword.length === 0) {
      return this.categories;
    }
    const result: Category[] = [];
    for (const category of this.categories) {
      if (category.name.toLowerCase().includes(keyword) ||
        category.description.toLowerCase().includes(keyword)) {
        result.push(category);
      }
    }
    return result;
  }

  private modeEnabled(mode: string): boolean {
    if (mode === 'wrongs') {
      return (this.stats?.wrongCount ?? 0) > 0;
    }
    if (mode === 'favorites') {
      return (this.stats?.favoriteCount ?? 0) > 0;
    }
    return true;
  }

  private handleMode(mode: string): void {
    if (!this.modeEnabled(mode)) {
      AppToast.show(this.getUIContext(), this.modeUnavailableMessage(mode));
      return;
    }
    this.prepareTraining(mode);
  }

  private prepareTraining(mode: string, category?: Category): void {
    this.setupMode = mode;
    this.setupTitle = category?.name ?? this.modeTitle(mode);
    this.setupCategoryId = category?.id ?? '';
    this.setupCount = mode === 'interview' ? 8 : 20;
    this.setupType = '';
    this.setupDifficulty = '';
    this.showSetup = true;
  }

  private openPendingSetup(): void {
    const mode = this.pendingSetupMode;
    if (mode.length === 0) {
      return;
    }
    const category = this.findCategory(this.pendingSetupCategoryId);
    this.pendingSetupMode = '';
    this.pendingSetupCategoryId = '';
    const requestedTitle = this.pendingSetupTitle;
    this.pendingSetupTitle = '';
    if (mode === 'category' && category === undefined) {
      AppToast.show(this.getUIContext(), '该训练模块已不可用，请重新选择');
      return;
    }
    if (!this.modeEnabled(mode)) {
      AppToast.show(this.getUIContext(), this.modeUnavailableMessage(mode));
      return;
    }
    this.prepareTraining(mode, category);
    if (requestedTitle.length > 0) {
      this.setupTitle = requestedTitle;
    }
  }

  private findCategory(categoryId: string): Category | undefined {
    if (categoryId.length === 0) {
      return undefined;
    }
    for (const category of this.categories) {
      if (category.id === categoryId) {
        return category;
      }
    }
    return undefined;
  }

  private modeUnavailableMessage(mode: string): string {
    return mode === 'wrongs' ?
      '还没有待复盘错题，先完成一次训练' :
      '还没有收藏题目，可以在答题页收藏重点';
  }

  private startConfiguredTraining(): void {
    this.showSetup = false;
    if (this.setupMode === 'interview') {
      AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
        mode: 'interview',
        categoryId: this.setupCategoryId,
        title: this.setupTitle,
        count: String(this.setupCount)
      });
      return;
    }
    AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
      mode: this.setupMode,
      categoryId: this.setupCategoryId,
      title: this.setupTitle,
      count: String(this.setupCount),
      type: this.setupType,
      difficulty: this.setupDifficulty
    });
  }

  private modeTitle(mode: string): string {
    if (mode === 'wrongs') {
      return '错题练习';
    }
    if (mode === 'favorites') {
      return '收藏复习';
    }
    return '随机练习';
  }

  private setupScopeText(): string {
    if (this.setupMode === 'category') {
      return '当前模块专项训练';
    }
    if (this.setupMode === 'wrongs') {
      return `${this.stats?.wrongCount ?? 0} 道待复盘题目`;
    }
    if (this.setupMode === 'favorites') {
      return `${this.stats?.favoriteCount ?? 0} 道收藏题目`;
    }
    if (this.setupMode === 'interview') {
      return '全模块基础模拟面试';
    }
    return '全题库随机抽取';
  }

  private setupModeMark(): string {
    if (this.setupMode === 'interview') {
      return '面';
    }
    if (this.setupMode === 'wrongs') {
      return '错';
    }
    if (this.setupMode === 'favorites') {
      return '藏';
    }
    if (this.setupMode === 'category') {
      return '专';
    }
    return '练';
  }

  private setupModeColor(): string {
    if (this.setupMode === 'interview') {
      return COLOR_BLUE;
    }
    if (this.setupMode === 'wrongs') {
      return COLOR_RED;
    }
    if (this.setupMode === 'favorites') {
      return COLOR_ORANGE;
    }
    return COLOR_GREEN;
  }

  private setupModeSoftColor(): string {
    if (this.setupMode === 'interview') {
      return COLOR_SOFT_BLUE;
    }
    if (this.setupMode === 'wrongs') {
      return COLOR_SOFT_RED;
    }
    if (this.setupMode === 'favorites') {
      return COLOR_SOFT_ORANGE;
    }
    return COLOR_SOFT_GREEN;
  }

  private categoryStats(categoryId: string): CategoryStats | undefined {
    for (const item of this.stats?.categories ?? []) {
      if (item.categoryId === categoryId) {
        return item;
      }
    }
    return undefined;
  }

  private categoryProgress(categoryId: string): string {
    const item = this.categoryStats(categoryId);
    return item === undefined ? '待练习' : `${item.answered}/${item.totalPublished}`;
  }

  private categoryCompletionRate(categoryId: string): number {
    return this.categoryStats(categoryId)?.completionRate ?? 0;
  }

  private categoryStatusText(categoryId: string): string {
    const item = this.categoryStats(categoryId);
    if (item === undefined || item.attempts === 0) {
      return '尚未开始';
    }
    return `正确率 ${FormatUtils.percent(item.accuracy)} · 作答 ${item.attempts} 次`;
  }

  private totalPublishedCount(): number {
    let count = 0;
    for (const item of this.stats?.categories ?? []) {
      count += item.totalPublished;
    }
    return count;
  }

  private categoryMark(name: string): string {
    if (name === 'ArkTS') {
      return 'TS';
    }
    if (name === 'ArkUI') {
      return 'UI';
    }
    if (name === 'Stage 模型') {
      return 'ST';
    }
    if (name === 'HarmonyOS NEXT 适配') {
      return 'NX';
    }
    return name.length >= 2 ? name.substring(0, 2) : name;
  }

  private categoryColor(order: number): string {
    const index = order % 3;
    if (index === 1) {
      return COLOR_GREEN;
    }
    if (index === 2) {
      return COLOR_BLUE;
    }
    return COLOR_ORANGE;
  }

  private categorySoftColor(order: number): string {
    const index = order % 3;
    if (index === 1) {
      return COLOR_SOFT_GREEN;
    }
    if (index === 2) {
      return COLOR_SOFT_BLUE;
    }
    return COLOR_SOFT_ORANGE;
  }

  private pageMaxWidth(): number {
    return this.isTablet ? 1120 : 520;
  }

  private updateLayoutMode(): void {
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
