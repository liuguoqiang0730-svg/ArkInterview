import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import {
  CategoryStats,
  DailyPracticeStats,
  PracticeRecordItem,
  QuestionType,
  UserStats
} from '../models/QuestionModels';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';
import { FormatUtils } from '../utils/FormatUtils';
import { PracticeEvents } from '../utils/PracticeEvents';
import { PracticeStore } from '../viewmodels/PracticeStore';
import { ApiRequestError } from '../services/ApiClient';

const store = new PracticeStore();
const COLOR_BG: string = '#f3f5f8';
const COLOR_SURFACE: string = '#ffffff';
const COLOR_NAVY: string = '#102033';
const COLOR_TEXT: string = '#1f2a37';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_GREEN: string = '#16745f';
const COLOR_ORANGE: string = '#d97924';
const COLOR_BLUE: string = '#2c5f8f';
const COLOR_RED: string = '#b42318';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SOFT_RED: string = '#fee4e2';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct RecordPage {
  @State private stats: UserStats | undefined = undefined;
  @State private loading: boolean = true;
  @State private loadError: string = '';
  @State private isTablet: boolean = false;
  @State private selectedRange: string = '7d';
  @State private selectedDate: string = '';
  @State private selectedCategoryIndex: number = 0;
  @State private selectedTypeIndex: number = 0;
  @State private records: PracticeRecordItem[] = [];
  @State private recordDailyStats: DailyPracticeStats[] = [];
  @State private recordPage: number = 1;
  @State private recordTotal: number = 0;
  @State private recordsLoading: boolean = false;
  @State private historyApiAvailable: boolean = true;
  @State private historyFilterApiAvailable: boolean = true;
  private observedStatsVersion: number = 0;
  private pendingRecordsReload: boolean = false;

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.loadStats();
  }

  onPageShow(): void {
    this.updateLayoutMode();
    if (this.observedStatsVersion !== PracticeEvents.currentStatsVersion()) {
      this.loadStats();
    }
  }

  async loadStats(): Promise<void> {
    this.loading = true;
    this.loadError = '';
    try {
      this.stats = await store.loadStats();
      this.observedStatsVersion = PracticeEvents.currentStatsVersion();
      this.historyApiAvailable = true;
      this.historyFilterApiAvailable = true;
      this.applyFallbackRecords();
      await this.loadRecords(true);
    } catch (error) {
      this.loadError = String(error);
      AppToast.show(this.getUIContext(), '练习记录加载失败');
    } finally {
      this.loading = false;
    }
  }

  async loadRecords(reset: boolean): Promise<void> {
    if (this.recordsLoading) {
      if (reset) {
        this.pendingRecordsReload = true;
      }
      return;
    }
    if (!this.historyApiAvailable) {
      this.applyFallbackRecords();
      return;
    }
    const targetPage = reset ? 1 : this.recordPage + 1;
    const categoryId = this.selectedRecordCategoryId();
    const type = this.selectedRecordType();
    this.recordsLoading = true;
    if (reset) {
      this.records = [];
      this.recordTotal = 0;
    }
    try {
      const result = await store.loadRecords(targetPage, 20, this.selectedDate, categoryId, type);
      if ((categoryId.length > 0 && result.categoryId !== categoryId) ||
        (type !== undefined && result.type !== type)) {
        this.historyFilterApiAvailable = false;
        this.applyFallbackRecords();
        return;
      }
      this.historyFilterApiAvailable = true;
      if (reset) {
        this.records = result.items;
      } else {
        const merged = new Array<PracticeRecordItem>();
        this.records.forEach((item: PracticeRecordItem) => merged.push(item));
        result.items.forEach((item: PracticeRecordItem) => merged.push(item));
        this.records = merged;
      }
      this.recordPage = result.page;
      this.recordTotal = result.total;
      this.recordDailyStats = result.dailyStats ?? this.defaultDailyStats();
    } catch (error) {
      if (error instanceof ApiRequestError && error.statusCode === 404) {
        this.historyApiAvailable = false;
        this.applyFallbackRecords();
      } else {
        this.applyFallbackRecords();
        AppToast.show(this.getUIContext(), '历史记录加载失败');
      }
    } finally {
      this.recordsLoading = false;
      if (this.pendingRecordsReload) {
        this.pendingRecordsReload = false;
        this.loadRecords(true);
      }
    }
  }

  build() {
    Column() {
      Column() {
        this.PageHeader()

        if (this.loading) {
          this.LoadingState()
        } else if (this.loadError.length > 0) {
          this.ErrorState()
        } else if (this.isTablet) {
          this.TabletWorkspace()
        } else {
          this.PhoneWorkspace()
        }
      }
      .layoutWeight(1)
      .width('100%')

      BottomNavBar({ active: 'profile', isTablet: this.isTablet })
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
        .onClick(() => AppRouter.back(this.getUIContext()))
      Column() {
        Text('练习记录')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
        Text('回看最近作答与模块进度')
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      Button('刷新')
        .height(34)
        .fontSize(13)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .borderRadius(8)
        .onClick(() => this.loadStats())
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
  LoadingState() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
      Text('正在加载练习记录')
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
      Text('!')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_RED)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(COLOR_SOFT_RED)
        .borderRadius(20)
      Text('练习记录暂时无法加载')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .margin({ top: 14 })
      Text('请检查服务连接后重试')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .margin({ top: 6 })
      Button('重新加载')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .backgroundColor(COLOR_GREEN)
        .borderRadius(8)
        .margin({ top: 18 })
        .onClick(() => this.loadStats())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TabletWorkspace() {
    Row() {
      Column() {
        this.SummaryPanel()
        if (this.isEmptyRecord()) {
          this.EmptyRecordPanel()
        } else {
          this.ReviewShortcutPanel()
        }
      }
      .width(350)
      .height('100%')
      .padding({ left: 16, top: 16, bottom: 16 })

      Scroll() {
        Column() {
          this.TrendPanel()
          this.RecentRecordsPanel()
          this.CategoryProgressList()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  PhoneWorkspace() {
    Scroll() {
      Column() {
        this.SummaryPanel()
        this.TrendPanel()
        if (this.isEmptyRecord()) {
          this.EmptyRecordPanel()
        } else {
          this.ReviewShortcutPanel()
          this.RecentRecordsPanel()
        }
        this.CategoryProgressList()
      }
      .width('100%')
      .padding(16)
      .constraintSize({ maxWidth: this.pageMaxWidth() })
      .alignSelf(ItemAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
  }

  @Builder
  SummaryPanel() {
    Column() {
      Row() {
        Column() {
          Text('累计答题')
            .fontSize(13)
            .fontColor('#d8efe8')
          Text(`${this.stats?.totalAnswers ?? 0}`)
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
            .margin({ top: 4 })
          Text('最近练习：' + this.formatDate(this.stats?.lastPracticedAt))
            .fontSize(12)
            .fontColor('#d8efe8')
            .margin({ top: 5 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text(FormatUtils.percent(this.stats?.accuracy ?? 0))
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
          Text('总正确率')
            .fontSize(12)
            .fontColor('#d8efe8')
            .margin({ top: 4 })
          Text(this.practiceTodayLabel())
            .fontSize(11)
            .fontColor('#8ed8c5')
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row() {
        this.MetricCard('已覆盖', String(this.stats?.answeredQuestionCount ?? 0), COLOR_SOFT_BLUE, COLOR_BLUE)
        this.MetricCard('错题', String(this.stats?.wrongCount ?? 0), COLOR_SOFT_ORANGE, COLOR_ORANGE)
        this.MetricCard('已掌握', String(this.stats?.masteredWrongCount ?? 0), COLOR_SOFT_GREEN, COLOR_GREEN)
        this.MetricCard('收藏', String(this.stats?.favoriteCount ?? 0), COLOR_SOFT_GREEN, COLOR_GREEN)
      }
      .width('100%')
      .margin({ top: 14 })

      this.StreakMilestonePanel()

      this.FocusCategoryPanel()
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_NAVY)
    .borderRadius(8)
    .shadow({ radius: 18, color: COLOR_SHADOW, offsetX: 0, offsetY: 8 })
  }

  @Builder
  StreakMilestonePanel() {
    Column() {
      Row() {
        Text(this.practiceStreakLabel())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
          .layoutWeight(1)

        Text(`${this.currentPracticeStreak()}/${this.nextStreakMilestone()} 天`)
          .fontSize(11)
          .fontColor('#8ed8c5')
      }
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor('#ffffff24')
          .borderRadius(3)
        Row()
          .width(this.streakProgressWidth())
          .height(6)
          .backgroundColor('#58c4a7')
          .borderRadius(3)
      }
      .width('100%')
      .height(6)
      .margin({ top: 8 })

      Text(this.streakMilestoneDetail())
        .fontSize(11)
        .fontColor('#b9d7cf')
        .width('100%')
        .margin({ top: 7 })
    }
    .width('100%')
    .padding({ top: 12 })
    .margin({ top: 12 })
    .border({ width: { top: 1 }, color: '#ffffff24' })
  }

  @Builder
  FocusCategoryPanel() {
    Column() {
      Row() {
        Column() {
          Text(this.focusCategoryTitle())
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#d8efe8')
          Text(this.focusCategoryDetail())
            .fontSize(12)
            .fontColor('#ffffff')
            .maxLines(3)
            .lineHeight(18)
            .margin({ top: 4 })
          if (this.focusCategory() !== undefined) {
            Text(this.focusCategoryEvidence())
              .fontSize(10)
              .fontColor('#8ed8c5')
              .margin({ top: 5 })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.focusCategory() !== undefined) {
          Text('去练习 >')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#8ed8c5')
            .margin({ left: 10 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 12 })
    .margin({ top: 12 })
    .border({ width: { top: 1 }, color: '#ffffff24' })
    .onClick(() => this.openFocusCategory())
  }

  @Builder
  MetricCard(label: string, value: string, bgColor: string, textColor: string) {
    Column() {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(10)
        .fontColor(COLOR_MUTED)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 3, right: 3 })
    .backgroundColor(bgColor)
    .borderRadius(8)
  }

  @Builder
  TrendPanel() {
    Column() {
      Row() {
        Column() {
          Text('正确率趋势')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text(this.rangeSummary())
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          this.RangeOption('7 天', '7d')
          this.RangeOption('30 天', '30d')
          this.RangeOption('全部', 'all')
        }
        .padding(3)
        .backgroundColor('#eef2f6')
        .borderRadius(8)
      }
      .width('100%')

      Row() {
        this.TrendMetric('作答', String(this.periodAttempts()))
        Divider()
          .vertical(true)
          .height(30)
          .color(COLOR_LINE)
        this.TrendMetric('判分', String(this.periodGradedAttempts()))
        Divider()
          .vertical(true)
          .height(30)
          .color(COLOR_LINE)
        this.TrendMetric('正确率', FormatUtils.percent(this.periodAccuracy()))
      }
      .width('100%')
      .margin({ top: 18, bottom: 10 })

      Column() {
        Row() {
          Text(this.periodComparisonTitle())
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .layoutWeight(1)
          Text(this.periodComparisonState())
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.periodComparisonColor())
        }
        .width('100%')

        Text(this.periodComparisonDetail())
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .maxLines(2)
          .width('100%')
          .margin({ top: 3 })
      }
      .width('100%')
      .padding({ top: 9, bottom: 9 })
      .margin({ bottom: 14 })
      .border({
        width: { top: 1, bottom: 1 },
        color: COLOR_LINE
      })

      if (this.trendItems().length === 0) {
        Column() {
          Text('当前时间范围还没有可展示的数据')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .height(108)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#f8fafc')
        .borderRadius(8)
      } else {
        Row() {
          ForEach(this.trendItems(), (item: DailyPracticeStats) => {
            this.DailyTrendBar(item)
          }, (item: DailyPracticeStats) => item.date)
        }
        .width('100%')
        .height(108)
        .alignItems(VerticalAlign.Bottom)
        .padding({ left: 4, right: 4, top: 6 })
        .border({ width: { bottom: 1 }, color: COLOR_LINE })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 14 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  RangeOption(label: string, value: string) {
    Button(label)
      .height(28)
      .padding({ left: this.isTablet ? 12 : 9, right: this.isTablet ? 12 : 9 })
      .fontSize(11)
      .fontWeight(this.selectedRange === value ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedRange === value ? COLOR_GREEN : COLOR_MUTED)
      .backgroundColor(this.selectedRange === value ? COLOR_SURFACE : '#00000000')
      .borderRadius(6)
      .shadow({
        radius: this.selectedRange === value ? 6 : 0,
        color: this.selectedRange === value ? COLOR_SHADOW : '#00000000',
        offsetX: 0,
        offsetY: 2
      })
      .onClick(() => {
        this.changeRange(value);
      })
  }

  @Builder
  TrendMetric(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
      Text(label)
        .fontSize(10)
        .fontColor(COLOR_MUTED)
        .margin({ top: 3 })
    }
    .layoutWeight(1)
  }

  @Builder
  DailyTrendBar(item: DailyPracticeStats) {
    Column() {
      Text(this.dailyAccuracyLabel(item))
        .fontSize(9)
        .fontColor(this.trendColor(item))
        .maxLines(1)
      Column()
        .width(this.isTablet ? 16 : 12)
        .height(this.trendBarHeight(item))
        .backgroundColor(this.trendColor(item))
        .borderRadius({ topLeft: 4, topRight: 4 })
        .margin({ top: 4 })
      Text(this.shortDate(item.date))
        .fontSize(9)
        .fontColor(COLOR_MUTED)
        .margin({ top: 5 })
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.End)
    .backgroundColor(this.selectedDate === item.date ? COLOR_SOFT_BLUE : '#00000000')
    .borderRadius(6)
    .opacity(this.selectedDate.length === 0 || this.selectedDate === item.date ? 1 : 0.58)
    .onClick(() => this.selectDate(item.date))
  }

  @Builder
  ReviewShortcutPanel() {
    Column() {
      Row() {
        Column() {
          Text('优先复盘')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
          Text(this.reviewHint())
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.stats?.wrongCount ?? 0}`)
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_ORANGE)
      }
      .width('100%')

      Button(this.reviewButtonLabel())
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .backgroundColor((this.stats?.wrongCount ?? 0) > 0 ? COLOR_ORANGE : COLOR_BLUE)
        .borderRadius(8)
        .margin({ top: 14 })
        .onClick(() => this.openReview())
    }
    .width('100%')
    .padding(16)
    .margin({ top: 14 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  EmptyRecordPanel() {
    Column() {
      Text('还没有练习记录')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .width('100%')
      Text('完成任意一组题目后，这里会展示最近作答、正确率和分类进度。')
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .margin({ top: 8 })
        .width('100%')
      Button('开始随机练习')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .backgroundColor(COLOR_GREEN)
        .borderRadius(8)
        .margin({ top: 14 })
        .onClick(() => AppRouter.push(this.getUIContext(), 'pages/TrainingPage', {
          mode: 'random',
          categoryId: '',
          title: '随机练习'
        }))
    }
    .width('100%')
    .padding(16)
    .margin({ top: 14 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  RecentRecordsPanel() {
    Column() {
      Row() {
        Column() {
          Text(this.recordsPanelTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text(this.recordsPanelSubtitle())
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.selectedDate.length > 0) {
          Button('清除日期')
            .height(28)
            .fontSize(11)
            .fontColor(COLOR_BLUE)
            .backgroundColor(COLOR_SOFT_BLUE)
            .borderRadius(7)
            .margin({ right: 8 })
            .onClick(() => this.clearDateFilter())
        }

        Text(`${this.records.length}/${this.recordTotal}`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ bottom: 10 })

      this.RecordFilters()

      if (this.recordsLoading && this.records.length === 0) {
        Row() {
          LoadingProgress()
            .width(22)
            .height(22)
          Text('正在加载历史记录')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .margin({ left: 9 })
        }
        .width('100%')
        .height(72)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(8)
        .border({ width: 1, color: COLOR_LINE })
      } else if (this.records.length === 0) {
        Text(this.emptyRecordsLabel())
          .width('100%')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding(16)
          .backgroundColor(COLOR_SURFACE)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_LINE })
      } else {
        ForEach(this.records, (item: PracticeRecordItem) => {
          this.RecentRecordItem(item)
        }, (item: PracticeRecordItem) => item.id)

        if (this.hasMoreRecords()) {
          Button(this.recordsLoading ? '加载中' : '加载更多')
            .width('100%')
            .height(40)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_BLUE)
            .backgroundColor(COLOR_SOFT_BLUE)
            .borderRadius(8)
            .enabled(!this.recordsLoading)
            .onClick(() => this.loadRecords(false))
        }
      }
    }
    .width('100%')
  }

  @Builder
  RecordFilters() {
    Row() {
      Column() {
        Text('模块')
          .fontSize(10)
          .fontColor(COLOR_MUTED)
          .width('100%')
          .margin({ bottom: 5 })
        Select(this.recordCategoryOptions())
          .selected(this.selectedCategoryIndex)
          .value(this.selectedRecordCategoryName())
          .width('100%')
          .height(38)
          .font({ size: 12 })
          .fontColor(COLOR_TEXT)
          .selectedOptionBgColor(COLOR_SOFT_GREEN)
          .optionBgColor(COLOR_SURFACE)
          .optionFontColor(COLOR_TEXT)
          .backgroundColor('#f8fafb')
          .border({ width: 1, color: COLOR_LINE })
          .borderRadius(8)
          .onSelect((index: number) => this.selectRecordCategory(index))
      }
      .layoutWeight(1)

      Column() {
        Text('题型')
          .fontSize(10)
          .fontColor(COLOR_MUTED)
          .width('100%')
          .margin({ bottom: 5 })
        Select(this.recordTypeOptions())
          .selected(this.selectedTypeIndex)
          .value(this.selectedRecordTypeName())
          .width('100%')
          .height(38)
          .font({ size: 12 })
          .fontColor(COLOR_TEXT)
          .selectedOptionBgColor(COLOR_SOFT_BLUE)
          .optionBgColor(COLOR_SURFACE)
          .optionFontColor(COLOR_TEXT)
          .backgroundColor('#f8fafb')
          .border({ width: 1, color: COLOR_LINE })
          .borderRadius(8)
          .onSelect((index: number) => this.selectRecordType(index))
      }
      .layoutWeight(1)
      .margin({ left: 8 })

      if (this.hasRecordFilters()) {
        Button('重置')
          .width(54)
          .height(38)
          .fontSize(11)
          .fontColor(COLOR_BLUE)
          .backgroundColor(COLOR_SOFT_BLUE)
          .borderRadius(8)
          .margin({ left: 8, top: 15 })
          .onClick(() => this.resetRecordFilters())
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Bottom)
    .margin({ bottom: 12 })
  }

  @Builder
  RecentRecordItem(item: PracticeRecordItem) {
    Row() {
      Text(this.recordStatusMark(item))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.recordStatusColor(item))
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.recordStatusBgColor(item))
        .borderRadius(17)
        .margin({ right: 12 })

      Column() {
        Text(item.questionTitle)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row() {
          Text(item.categoryName)
            .fontSize(11)
            .fontColor(COLOR_MUTED)
          Text('·')
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .margin({ left: 5, right: 5 })
          Text(this.questionTypeLabel(item.questionType))
            .fontSize(11)
            .fontColor(COLOR_MUTED)
          Text(this.formatRecordTime(item.submittedAt))
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .layoutWeight(1)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .margin({ top: 7 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('再答 >')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_BLUE)
        .margin({ left: 12 })
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 9 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .onClick(() => this.openRecord(item))
  }

  @Builder
  CategoryProgressList() {
    Column() {
      Row() {
        Column() {
          Text('分类完成度')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text('按去重题目计算覆盖率')
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.stats?.categories.length ?? 0} 个模块`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ top: 18, bottom: 10 })

      ForEach(this.stats?.categories ?? [], (item: CategoryStats) => {
        this.CategoryProgressItem(item)
      }, (item: CategoryStats) => item.categoryId)
    }
    .width('100%')
  }

  @Builder
  CategoryProgressItem(item: CategoryStats) {
    Column() {
      Row() {
        Text(item.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
        Text(`${item.answered}/${item.totalPublished}`)
          .fontSize(12)
          .fontColor(this.progressColor(item.completionRate))
          .backgroundColor(this.progressBgColor(item.completionRate))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
        Text(this.categoryStatusLabel(item))
          .fontSize(12)
          .fontColor(this.progressColor(item.completionRate))
          .margin({ left: 10 })
      }
      .width('100%')

      Row() {
        Column()
          .height(7)
          .width(FormatUtils.percent(item.completionRate))
          .backgroundColor(this.progressColor(item.completionRate))
          .borderRadius(4)
      }
      .width('100%')
      .height(7)
      .backgroundColor('#eef2f6')
      .borderRadius(4)
      .margin({ top: 10 })

      Row() {
        Text(`正确率 ${FormatUtils.percent(item.accuracy)}`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
        Text(`作答 ${item.attempts} 次`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
        Text('去练习 >')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.progressColor(item.completionRate))
          .margin({ left: 12 })
      }
      .width('100%')
      .margin({ top: 9 })
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 9 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .onClick(() => this.openCategoryPractice(item))
  }

  pageMaxWidth(): number {
    return this.isTablet ? 1120 : 520;
  }

  progressColor(rate: number): string {
    if (rate >= 0.7) {
      return COLOR_GREEN;
    }
    if (rate >= 0.3) {
      return COLOR_BLUE;
    }
    return COLOR_ORANGE;
  }

  progressBgColor(rate: number): string {
    if (rate >= 0.7) {
      return COLOR_SOFT_GREEN;
    }
    if (rate >= 0.3) {
      return COLOR_SOFT_BLUE;
    }
    return COLOR_SOFT_ORANGE;
  }

  categoryStatusLabel(item: CategoryStats): string {
    if (item.completionRate >= 1) {
      return '已完成';
    }
    if (item.attempts > 0) {
      return '进行中';
    }
    return '未开始';
  }

  practiceStreakLabel(): string {
    const streak = this.currentPracticeStreak();
    return streak > 0 ? `连续 ${streak} 天` : '今天开始练习';
  }

  practiceTodayLabel(): string {
    return this.hasPracticeOnDate(this.defaultDailyStats(), this.shanghaiToday()) ? '今日已记录' : '今日待练习';
  }

  nextStreakMilestone(): number {
    const streak = this.currentPracticeStreak();
    const milestones: number[] = [3, 7, 14, 30, 60, 100, 180, 365];
    for (let index = 0; index < milestones.length; index += 1) {
      if (streak < milestones[index]) {
        return milestones[index];
      }
    }
    return Math.ceil((streak + 1) / 100) * 100;
  }

  streakProgressWidth(): string {
    const target = this.nextStreakMilestone();
    const progress = target === 0 ? 0 : Math.min(100, Math.round(this.currentPracticeStreak() / target * 100));
    return `${progress}%`;
  }

  streakMilestoneDetail(): string {
    const streak = this.currentPracticeStreak();
    const target = this.nextStreakMilestone();
    if (streak === 0) {
      return '今天完成一次练习，开启 3 天连续里程碑。';
    }
    const remaining = target - streak;
    if (!this.hasPracticeOnDate(this.defaultDailyStats(), this.shanghaiToday())) {
      return `今天完成一次即可延续，距离 ${target} 天还差 ${remaining} 天。`;
    }
    return `今日连续记录已完成，距离 ${target} 天还差 ${remaining} 天。`;
  }

  currentPracticeStreak(): number {
    const source = this.defaultDailyStats();
    if (source.length === 0) {
      return 0;
    }
    let cursor = this.shanghaiToday();
    if (!this.hasPracticeOnDate(source, cursor)) {
      cursor = this.shiftDateKey(cursor, -1);
    }
    let streak = 0;
    while (this.hasPracticeOnDate(source, cursor)) {
      streak += 1;
      cursor = this.shiftDateKey(cursor, -1);
    }
    return streak;
  }

  hasPracticeOnDate(source: DailyPracticeStats[], date: string): boolean {
    return source.some((item: DailyPracticeStats) => item.date === date && item.attempts > 0);
  }

  shanghaiToday(): string {
    return new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString().substring(0, 10);
  }

  shiftDateKey(date: string, days: number): string {
    const timestamp = Date.parse(`${date}T00:00:00Z`);
    return new Date(timestamp + days * 24 * 60 * 60 * 1000).toISOString().substring(0, 10);
  }

  focusCategory(): CategoryStats | undefined {
    let result: CategoryStats | undefined = undefined;
    (this.stats?.categories ?? []).forEach((item: CategoryStats) => {
      if (this.categoryGradedAttempts(item) < 3) {
        return;
      }
      if (result === undefined ||
        item.accuracy < result.accuracy ||
        (item.accuracy === result.accuracy && item.completionRate < result.completionRate)) {
        result = item;
      }
    });
    return result;
  }

  categoryGradedAttempts(item: CategoryStats): number {
    if (item.gradedAttempts !== undefined) {
      return item.gradedAttempts;
    }
    let count = 0;
    (this.stats?.recentRecords ?? []).forEach((record: PracticeRecordItem) => {
      if (record.categoryId === item.categoryId && record.isCorrect !== null) {
        count += 1;
      }
    });
    return count;
  }

  focusCategoryTitle(): string {
    const category = this.focusCategory();
    if (category === undefined) {
      return '重点模块建议';
    }
    return category.accuracy < 0.8 ? `薄弱模块 · ${category.name}` : `建议拓展 · ${category.name}`;
  }

  focusCategoryDetail(): string {
    const category = this.focusCategory();
    if (category === undefined) {
      return '每个模块完成至少 3 次客观题判分后，这里会给出复习建议。';
    }
    if (category.accuracy < 0.8) {
      return '在达到样本门槛的模块中正确率最低，建议先复习高频失分知识点。';
    }
    return '当前正确率已达到稳定线，可继续扩大题目覆盖并保持正确率。';
  }

  focusCategoryEvidence(): string {
    const category = this.focusCategory();
    if (category === undefined) {
      return '';
    }
    return `判分 ${this.categoryGradedAttempts(category)} 次 · 正确率 ${FormatUtils.percent(category.accuracy)} · 完成度 ${FormatUtils.percent(category.completionRate)}`;
  }

  reviewHint(): string {
    if ((this.stats?.wrongCount ?? 0) > 0) {
      return '从尚未掌握的错题开始巩固';
    }
    return '当前没有待掌握错题，可回看全部记录';
  }

  reviewButtonLabel(): string {
    return (this.stats?.wrongCount ?? 0) > 0 ? '进入错题本' : '开始随机练习';
  }

  recordStatusMark(item: PracticeRecordItem): string {
    if (item.isCorrect === null) {
      return '评';
    }
    return item.isCorrect ? '对' : '错';
  }

  recordStatusColor(item: PracticeRecordItem): string {
    if (item.isCorrect === null) {
      return COLOR_BLUE;
    }
    return item.isCorrect ? COLOR_GREEN : COLOR_RED;
  }

  recordStatusBgColor(item: PracticeRecordItem): string {
    if (item.isCorrect === null) {
      return COLOR_SOFT_BLUE;
    }
    return item.isCorrect ? COLOR_SOFT_GREEN : COLOR_SOFT_RED;
  }

  questionTypeLabel(type: QuestionType): string {
    if (type === 'single') {
      return '单选题';
    }
    if (type === 'multiple') {
      return '多选题';
    }
    if (type === 'boolean') {
      return '判断题';
    }
    return '简答题';
  }

  isEmptyRecord(): boolean {
    return (this.stats?.totalAnswers ?? 0) === 0;
  }

  selectedDailyStats(): DailyPracticeStats[] {
    const source = this.dailyStatsSource();
    if (this.selectedRange === 'all') {
      return source;
    }
    const days = this.selectedRange === '30d' ? 30 : 7;
    const startDate = this.rangeStartDate(days);
    const result = new Array<DailyPracticeStats>();
    source.forEach((item: DailyPracticeStats) => {
      if (item.date >= startDate) {
        result.push(item);
      }
    });
    return result;
  }

  applyFallbackRecords(): void {
    const scoped = new Array<PracticeRecordItem>();
    const fallback = new Array<PracticeRecordItem>();
    (this.stats?.recentRecords ?? []).forEach((item: PracticeRecordItem) => {
      if (this.recordMatchesFilters(item)) {
        scoped.push(item);
      }
      if (this.recordMatchesFilters(item) &&
        (this.selectedDate.length === 0 || this.recordDate(item.submittedAt) === this.selectedDate)) {
        fallback.push(item);
      }
    });
    this.recordDailyStats = this.hasRecordFilters() ? this.buildDailyStats(scoped) : this.defaultDailyStats();
    this.records = fallback;
    this.recordPage = 1;
    this.recordTotal = fallback.length;
  }

  dailyStatsSource(): DailyPracticeStats[] {
    if (this.hasRecordFilters()) {
      return this.recordDailyStats;
    }
    return this.defaultDailyStats();
  }

  defaultDailyStats(): DailyPracticeStats[] {
    if (this.stats?.dailyStats !== undefined) {
      return this.stats.dailyStats;
    }
    return this.buildDailyStats(this.stats?.recentRecords ?? []);
  }

  buildDailyStats(records: PracticeRecordItem[]): DailyPracticeStats[] {
    const result = new Array<DailyPracticeStats>();
    records.forEach((record: PracticeRecordItem) => {
      const date = this.recordDate(record.submittedAt);
      let daily = result.find((item: DailyPracticeStats) => item.date === date);
      if (daily === undefined) {
        daily = {
          date,
          attempts: 0,
          gradedAttempts: 0,
          correct: 0,
          accuracy: 0
        };
        result.push(daily);
      }
      daily.attempts += 1;
      if (record.isCorrect !== null) {
        daily.gradedAttempts += 1;
        if (record.isCorrect) {
          daily.correct += 1;
        }
        daily.accuracy = daily.correct / daily.gradedAttempts;
      }
    });
    result.sort((left: DailyPracticeStats, right: DailyPracticeStats) => left.date.localeCompare(right.date));
    return result;
  }

  trendItems(): DailyPracticeStats[] {
    const selected = this.selectedDailyStats();
    const limit = this.isTablet ? 12 : 7;
    const start = Math.max(0, selected.length - limit);
    return selected.slice(start);
  }

  periodAttempts(): number {
    let total = 0;
    this.selectedDailyStats().forEach((item: DailyPracticeStats) => {
      total += item.attempts;
    });
    return total;
  }

  periodGradedAttempts(): number {
    let total = 0;
    this.selectedDailyStats().forEach((item: DailyPracticeStats) => {
      total += item.gradedAttempts;
    });
    return total;
  }

  periodCorrectAnswers(): number {
    let total = 0;
    this.selectedDailyStats().forEach((item: DailyPracticeStats) => {
      total += item.correct;
    });
    return total;
  }

  periodAccuracy(): number {
    const gradedAttempts = this.periodGradedAttempts();
    if (gradedAttempts === 0) {
      return 0;
    }
    return this.periodCorrectAnswers() / gradedAttempts;
  }

  previousPeriodDailyStats(): DailyPracticeStats[] {
    if (this.selectedRange === 'all') {
      return [];
    }
    const days = this.selectedRange === '30d' ? 30 : 7;
    const currentStart = this.rangeStartDate(days);
    const previousStart = this.rangeStartDate(days * 2);
    const result = new Array<DailyPracticeStats>();
    this.dailyStatsSource().forEach((item: DailyPracticeStats) => {
      if (item.date >= previousStart && item.date < currentStart) {
        result.push(item);
      }
    });
    return result;
  }

  previousPeriodAttempts(): number {
    let total = 0;
    this.previousPeriodDailyStats().forEach((item: DailyPracticeStats) => {
      total += item.attempts;
    });
    return total;
  }

  previousPeriodGradedAttempts(): number {
    let total = 0;
    this.previousPeriodDailyStats().forEach((item: DailyPracticeStats) => {
      total += item.gradedAttempts;
    });
    return total;
  }

  previousPeriodCorrectAnswers(): number {
    let total = 0;
    this.previousPeriodDailyStats().forEach((item: DailyPracticeStats) => {
      total += item.correct;
    });
    return total;
  }

  previousPeriodAccuracy(): number {
    const gradedAttempts = this.previousPeriodGradedAttempts();
    if (gradedAttempts === 0) {
      return 0;
    }
    return this.previousPeriodCorrectAnswers() / gradedAttempts;
  }

  periodComparisonTitle(): string {
    if (this.selectedRange === 'all') {
      return '累计统计';
    }
    return this.selectedRange === '30d' ? '对比前 30 天' : '对比前 7 天';
  }

  periodComparisonState(): string {
    if (this.selectedRange === 'all') {
      return '不做环比';
    }
    if (this.hasRecordFilters() && !this.historyFilterApiAvailable) {
      return '等待服务升级';
    }
    if (this.previousPeriodAttempts() === 0) {
      return '暂无基线';
    }
    if (this.periodAttempts() === 0) {
      return '本期未练习';
    }
    if (this.periodGradedAttempts() === 0 || this.previousPeriodGradedAttempts() === 0) {
      return '判分不足';
    }
    const delta = this.periodAccuracy() - this.previousPeriodAccuracy();
    if (delta > 0) {
      return '正确率提升';
    }
    if (delta < 0) {
      return '正确率下降';
    }
    return '正确率持平';
  }

  periodComparisonDetail(): string {
    if (this.selectedRange === 'all') {
      return '累计范围展示全部历史，不与任意长度的前置周期比较。';
    }
    if (this.hasRecordFilters() && !this.historyFilterApiAvailable) {
      return '当前仅有最近记录的筛选结果，服务端提供完整筛选历史后再计算环比。';
    }
    const previousAttempts = this.previousPeriodAttempts();
    if (previousAttempts === 0) {
      return '上一周期没有作答记录，完成下一周期后即可形成有效对比。';
    }
    if (this.periodAttempts() === 0) {
      return `本周期暂无作答；上一周期共作答 ${previousAttempts} 次。`;
    }
    const attemptDelta = this.periodAttempts() - previousAttempts;
    if (this.periodGradedAttempts() === 0 || this.previousPeriodGradedAttempts() === 0) {
      return `作答 ${this.signedInteger(attemptDelta)} 次；客观题判分不足，暂不比较正确率。`;
    }
    const accuracyPoints = (this.periodAccuracy() - this.previousPeriodAccuracy()) * 100;
    return `作答 ${this.signedInteger(attemptDelta)} 次 · 正确率 ${this.signedDecimal(accuracyPoints)} 个百分点`;
  }

  periodComparisonColor(): string {
    if (this.selectedRange === 'all' ||
      (this.hasRecordFilters() && !this.historyFilterApiAvailable) ||
      this.previousPeriodAttempts() === 0 ||
      this.periodGradedAttempts() === 0 ||
      this.previousPeriodGradedAttempts() === 0) {
      return COLOR_MUTED;
    }
    const delta = this.periodAccuracy() - this.previousPeriodAccuracy();
    if (delta > 0) {
      return COLOR_GREEN;
    }
    if (delta < 0) {
      return COLOR_RED;
    }
    return COLOR_BLUE;
  }

  signedInteger(value: number): string {
    return value > 0 ? `+${value}` : String(value);
  }

  signedDecimal(value: number): string {
    const formatted = value.toFixed(1);
    return value > 0 ? `+${formatted}` : formatted;
  }

  rangeSummary(): string {
    let range = '近 7 天活跃日表现';
    if (this.selectedRange === '30d') {
      range = '近 30 天活跃日表现';
    } else if (this.selectedRange === 'all') {
      range = '累计活跃日表现';
    }
    const filter = this.recordFilterSummary();
    return filter.length > 0 ? `${range} · ${filter}` : range;
  }

  changeRange(value: string): void {
    this.selectedRange = value;
    if (this.selectedDate.length > 0) {
      this.selectedDate = '';
      this.loadRecords(true);
    }
  }

  selectDate(date: string): void {
    this.selectedDate = this.selectedDate === date ? '' : date;
    this.loadRecords(true);
  }

  clearDateFilter(): void {
    this.selectedDate = '';
    this.loadRecords(true);
  }

  hasMoreRecords(): boolean {
    return this.historyApiAvailable &&
      (!this.hasRecordFilters() || this.historyFilterApiAvailable) &&
      this.records.length < this.recordTotal;
  }

  recordsPanelTitle(): string {
    if (this.selectedDate.length > 0) {
      return `${this.shortDate(this.selectedDate)} 作答明细`;
    }
    return '历史作答';
  }

  recordsPanelSubtitle(): string {
    const filter = this.recordFilterSummary();
    if (this.hasRecordFilters() && !this.historyFilterApiAvailable) {
      return `服务器待升级，暂按最近 12 次记录筛选${filter.length > 0 ? ` · ${filter}` : ''}`;
    }
    if (this.selectedDate.length > 0) {
      return `按北京时间筛选当天提交${filter.length > 0 ? ` · ${filter}` : ''}`;
    }
    if (!this.historyApiAvailable) {
      return `最近 12 次提交记录${filter.length > 0 ? ` · ${filter}` : ''}`;
    }
    return `按提交时间从新到旧排列${filter.length > 0 ? ` · ${filter}` : ''}`;
  }

  emptyRecordsLabel(): string {
    if (this.selectedDate.length > 0 || this.hasRecordFilters()) {
      return '当前筛选条件下没有作答记录。';
    }
    return '完成作答后，提交记录会显示在这里。';
  }

  recordCategoryOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部模块' }];
    (this.stats?.categories ?? []).forEach((category: CategoryStats) => {
      options.push({ value: category.name });
    });
    return options;
  }

  recordTypeOptions(): SelectOption[] {
    return [
      { value: '全部题型' },
      { value: '单选题' },
      { value: '多选题' },
      { value: '判断题' },
      { value: '简答题' }
    ];
  }

  selectedRecordCategoryId(): string {
    const categories = this.stats?.categories ?? [];
    if (this.selectedCategoryIndex <= 0 || this.selectedCategoryIndex > categories.length) {
      return '';
    }
    return categories[this.selectedCategoryIndex - 1].categoryId;
  }

  selectedRecordCategoryName(): string {
    const categories = this.stats?.categories ?? [];
    if (this.selectedCategoryIndex <= 0 || this.selectedCategoryIndex > categories.length) {
      return '全部模块';
    }
    return categories[this.selectedCategoryIndex - 1].name;
  }

  selectedRecordType(): QuestionType | undefined {
    if (this.selectedTypeIndex === 1) {
      return 'single';
    }
    if (this.selectedTypeIndex === 2) {
      return 'multiple';
    }
    if (this.selectedTypeIndex === 3) {
      return 'boolean';
    }
    if (this.selectedTypeIndex === 4) {
      return 'short';
    }
    return undefined;
  }

  selectedRecordTypeName(): string {
    if (this.selectedTypeIndex === 1) {
      return '单选题';
    }
    if (this.selectedTypeIndex === 2) {
      return '多选题';
    }
    if (this.selectedTypeIndex === 3) {
      return '判断题';
    }
    if (this.selectedTypeIndex === 4) {
      return '简答题';
    }
    return '全部题型';
  }

  selectRecordCategory(index: number): void {
    const categories = this.stats?.categories ?? [];
    if (index < 0 || index > categories.length || index === this.selectedCategoryIndex) {
      return;
    }
    this.selectedCategoryIndex = index;
    this.loadRecords(true);
  }

  selectRecordType(index: number): void {
    if (index < 0 || index > 4 || index === this.selectedTypeIndex) {
      return;
    }
    this.selectedTypeIndex = index;
    this.loadRecords(true);
  }

  resetRecordFilters(): void {
    this.selectedCategoryIndex = 0;
    this.selectedTypeIndex = 0;
    this.loadRecords(true);
  }

  hasRecordFilters(): boolean {
    return this.selectedCategoryIndex > 0 || this.selectedTypeIndex > 0;
  }

  recordFilterSummary(): string {
    const labels = new Array<string>();
    if (this.selectedCategoryIndex > 0) {
      labels.push(this.selectedRecordCategoryName());
    }
    if (this.selectedTypeIndex > 0) {
      labels.push(this.selectedRecordTypeName());
    }
    return labels.join(' · ');
  }

  recordMatchesFilters(item: PracticeRecordItem): boolean {
    const categoryId = this.selectedRecordCategoryId();
    const type = this.selectedRecordType();
    return (categoryId.length === 0 || item.categoryId === categoryId) &&
      (type === undefined || item.questionType === type);
  }

  rangeStartDate(days: number): string {
    const shanghaiNow = Date.now() + 8 * 60 * 60 * 1000;
    const start = shanghaiNow - (days - 1) * 24 * 60 * 60 * 1000;
    return new Date(start).toISOString().substring(0, 10);
  }

  dailyAccuracyLabel(item: DailyPracticeStats): string {
    if (item.gradedAttempts === 0) {
      return '自评';
    }
    return FormatUtils.percent(item.accuracy);
  }

  trendBarHeight(item: DailyPracticeStats): number {
    if (item.gradedAttempts === 0) {
      return 12;
    }
    return 14 + Math.round(item.accuracy * 48);
  }

  trendColor(item: DailyPracticeStats): string {
    if (item.gradedAttempts === 0) {
      return COLOR_BLUE;
    }
    if (item.accuracy >= 0.8) {
      return COLOR_GREEN;
    }
    if (item.accuracy >= 0.5) {
      return COLOR_ORANGE;
    }
    return COLOR_RED;
  }

  shortDate(value: string): string {
    if (value.length < 10) {
      return value;
    }
    return `${value.substring(5, 7)}/${value.substring(8, 10)}`;
  }

  recordDate(value: string): string {
    const timestamp = Date.parse(value);
    if (!Number.isFinite(timestamp)) {
      return value.substring(0, 10);
    }
    return new Date(timestamp + 8 * 60 * 60 * 1000).toISOString().substring(0, 10);
  }

  formatDate(value?: string): string {
    if (!value) {
      return '暂无';
    }
    return value.substring(0, 10);
  }

  formatRecordTime(value: string): string {
    if (value.length < 16) {
      return value;
    }
    return `${value.substring(5, 10)} ${value.substring(11, 16)}`;
  }

  openReview(): void {
    if ((this.stats?.wrongCount ?? 0) > 0) {
      AppRouter.push(this.getUIContext(), 'pages/ReviewListPage', {
        mode: 'wrongs',
        title: '错题本'
      });
      return;
    }
    AppRouter.push(this.getUIContext(), 'pages/TrainingPage', {
      mode: 'random',
      categoryId: '',
      title: '随机练习'
    });
  }

  openRecord(item: PracticeRecordItem): void {
    AppRouter.push(this.getUIContext(), 'pages/QuestionPage', {
      questionId: item.questionId,
      questionIds: item.questionId,
      questionIndex: '0'
    });
  }

  openCategoryPractice(item: CategoryStats): void {
    AppRouter.push(this.getUIContext(), 'pages/TrainingPage', {
      mode: 'category',
      categoryId: item.categoryId,
      title: item.name
    });
  }

  openFocusCategory(): void {
    const category = this.focusCategory();
    if (category !== undefined) {
      this.openCategoryPractice(category);
    }
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
