import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { CategoryStats, PracticeRecordItem, QuestionType, UserStats } from '../models/QuestionModels';
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
  private observedStatsVersion: number = 0;

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
    } catch (error) {
      this.loadError = String(error);
      AppToast.show(this.getUIContext(), '练习记录加载失败');
    } finally {
      this.loading = false;
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

      BottomNavBar({ active: 'records', isTablet: this.isTablet })
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
      .margin({ top: 18 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_NAVY)
    .borderRadius(8)
    .shadow({ radius: 18, color: COLOR_SHADOW, offsetX: 0, offsetY: 8 })
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
        .onClick(() => AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
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
          Text('最近作答')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text('保留最近 12 次提交记录')
            .fontSize(11)
            .fontColor(COLOR_MUTED)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.stats?.recentRecords.length ?? 0} 条`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ bottom: 10 })

      if ((this.stats?.recentRecords.length ?? 0) === 0) {
        Text('完成答题后，最近提交记录会显示在这里。')
          .width('100%')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .padding(16)
          .backgroundColor(COLOR_SURFACE)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_LINE })
      } else {
        ForEach(this.stats?.recentRecords ?? [], (item: PracticeRecordItem) => {
          this.RecentRecordItem(item)
        }, (item: PracticeRecordItem) => item.id)
      }
    }
    .width('100%')
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
    AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
      mode: 'random',
      categoryId: '',
      title: '随机练习'
    });
  }

  openRecord(item: PracticeRecordItem): void {
    AppRouter.push(this.getUIContext(), 'pages/QuestionPage', {
      questionId: item.questionId,
      questionIds: item.questionId,
      questionIndex: '0',
      navActive: 'records'
    });
  }

  openCategoryPractice(item: CategoryStats): void {
    AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
      mode: 'category',
      categoryId: item.categoryId,
      title: item.name
    });
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
