import display from '@ohos.display';
import { APP_NAME } from '../app/AppConfig';
import { BottomNavBar } from '../components/BottomNavBar';
import { Category, UserStats } from '../models/QuestionModels';
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
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct HomePage {
  @State private categories: Category[] = [];
  @State private stats: UserStats | undefined = undefined;
  @State private loading: boolean = true;
  @State private isTablet: boolean = false;
  private observedStatsVersion: number = 0;

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.loadHome();
  }

  onPageShow(): void {
    this.updateLayoutMode();
    if (this.observedStatsVersion !== PracticeEvents.currentStatsVersion()) {
      this.loadHome();
    }
  }

  async loadHome() {
    this.loading = true;
    try {
      const snapshot = await store.loadHome();
      this.categories = snapshot.categories;
      this.stats = snapshot.stats;
      this.observedStatsVersion = PracticeEvents.currentStatsVersion();
    } catch (error) {
      AppToast.show(this.getUIContext(), `加载失败：${String(error)}`);
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      if (this.isTablet) {
        this.TabletHome()
      } else {
        Scroll() {
          this.PhoneHome()
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(COLOR_BG)
      }

      BottomNavBar({ active: 'home', isTablet: this.isTablet })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  TabletHome() {
    Row() {
      Column() {
        this.HomeHeader()
        this.OverviewPanel()
        this.ActionGrid()
      }
      .layoutWeight(4)
      .height('100%')
      .margin({ right: 18 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Column() {
        this.InterviewShareSection()
        this.CategoryHeader()
        if (this.loading) {
          LoadingProgress()
            .width(36)
            .height(36)
            .margin({ top: 28, bottom: 28 })
        } else {
          Scroll() {
            this.CategoryList()
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .layoutWeight(6)
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Top)
    .constraintSize({ maxWidth: 1220 })
    .alignSelf(ItemAlign.Center)
    .padding({ left: 28, right: 28, top: 26, bottom: 18 })
    .layoutWeight(1)
  }

  @Builder
  PhoneHome() {
    Column() {
      this.HomeHeader()
      this.OverviewPanel()
      this.ActionGrid()
      this.InterviewShareSection()
      this.CategorySection()
    }
    .width('100%')
    .constraintSize({ maxWidth: 520 })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  CategorySection() {
    Column() {
      this.CategoryHeader()
      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .margin({ top: 28, bottom: 28 })
      } else {
        this.CategoryList()
      }
    }
    .width('100%')
  }

  @Builder
  CategoryHeader() {
    Row() {
      Text('题库模块')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .layoutWeight(1)
      Text(`${this.categories.length} 个分类 · ${this.totalPublishedCount()} 道题`)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
    .padding({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, bottom: 8 })
  }

  @Builder
  CategoryList() {
    Column() {
      ForEach(this.categories, (category: Category) => {
        this.CategoryCard(category)
      }, (category: Category) => category.id)
    }
    .width('100%')
    .padding({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, bottom: 20 })
  }

  @Builder
  HomeHeader() {
    Row() {
      Column() {
        Text(APP_NAME)
          .fontSize(this.isTablet ? 34 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
        Text('HarmonyOS 开发者面试训练台')
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .margin({ top: 5 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button(this.isTablet ? '同步题库' : '刷新')
        .height(38)
        .fontSize(13)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .borderRadius(8)
        .onClick(() => this.loadHome())
    }
    .width('100%')
    .padding({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, top: this.isTablet ? 0 : 20, bottom: 14 })
  }

  @Builder
  OverviewPanel() {
    Column() {
      Row() {
        Column() {
          Text('学习进度')
            .fontSize(13)
            .fontColor('#d8efe8')
          Text(`${this.stats?.answeredQuestionCount ?? 0}`)
            .fontSize(this.isTablet ? 38 : 34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
            .margin({ top: 4 })
          Text('已覆盖题目')
            .fontSize(13)
            .fontColor('#d8efe8')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text(FormatUtils.percent(this.stats?.accuracy ?? 0))
            .fontSize(this.isTablet ? 32 : 28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
          Text('正确率')
            .fontSize(12)
            .fontColor('#d8efe8')
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')

      Row() {
        this.DashboardMetric('已答', String(this.stats?.totalAnswers ?? 0), COLOR_SOFT_BLUE, COLOR_BLUE)
        this.DashboardMetric('错题', String(this.stats?.wrongCount ?? 0), COLOR_SOFT_ORANGE, COLOR_ORANGE)
        this.DashboardMetric('收藏', String(this.stats?.favoriteCount ?? 0), COLOR_SOFT_GREEN, COLOR_GREEN)
      }
      .width('100%')
      .margin({ top: 18 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_NAVY)
    .borderRadius(8)
    .margin({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, bottom: 14 })
    .shadow({ radius: 18, color: COLOR_SHADOW, offsetX: 0, offsetY: 8 })
  }

  @Builder
  ActionGrid() {
    Column() {
      Row() {
        Text('快捷训练')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text('开始一次练习')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        this.ActionCard('随机练习', '快速进入综合训练', COLOR_GREEN, COLOR_SOFT_GREEN, 'random', '综合')
        this.ActionCard('模拟面试', '按面试节奏抽题', COLOR_BLUE, COLOR_SOFT_BLUE, 'interview', '8 题')
      }
      .width('100%')

      Row() {
        this.ActionCard('错题练习', '集中处理薄弱点', COLOR_ORANGE, COLOR_SOFT_ORANGE, 'wrongs', `${this.stats?.wrongCount ?? 0} 题`)
        this.ActionCard('收藏复习', '回看重点题目', COLOR_GREEN, COLOR_SOFT_GREEN, 'favorites', `${this.stats?.favoriteCount ?? 0} 题`)
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, bottom: 16 })
  }

  @Builder
  InterviewShareSection() {
    Column() {
      Row() {
        Text('面试专题')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text('高频开放题 · 16 题')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .padding({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, bottom: 10 })

      this.InterviewShareEntry()
    }
    .width('100%')
  }

  @Builder
  InterviewShareEntry() {
    Column() {
      Row() {
        Text('面')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_BLUE)
          .textAlign(TextAlign.Center)
          .width(38)
          .height(38)
          .backgroundColor(COLOR_SOFT_BLUE)
          .borderRadius(8)
          .margin({ right: 12 })

        Column() {
          Text('常见面试题分享')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .width('100%')
          Text('16 个高频开放题，按官方口径整理答案和图解')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .lineHeight(18)
            .margin({ top: 5 })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('>')
          .fontSize(18)
          .fontColor(COLOR_BLUE)
      }
      .width('100%')

      Row() {
        this.ShareTag('Stage')
        this.ShareTag('ArkUI')
        this.ShareTag('状态管理')
        this.ShareTag('一多适配')
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(14)
    .margin({ left: this.isTablet ? 0 : 18, right: this.isTablet ? 0 : 18, bottom: 16 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .shadow({ radius: 12, color: COLOR_SHADOW, offsetX: 0, offsetY: 6 })
    .onClick(() => this.openInterviewExperience())
  }

  @Builder
  ShareTag(label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(COLOR_BLUE)
      .backgroundColor(COLOR_SOFT_BLUE)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(8)
      .margin({ right: 6 })
  }

  @Builder
  DashboardMetric(label: string, value: string, bgColor: string, textColor: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(11)
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
  ActionCard(title: string, desc: string, color: string, bgColor: string, mode: string, meta: string) {
    Column() {
      Row() {
        Text(this.actionMark(mode))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .textAlign(TextAlign.Center)
          .width(34)
          .height(34)
          .backgroundColor(bgColor)
          .borderRadius(8)
          .margin({ right: 10 })

        Column() {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .width('100%')
          Text(desc)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 5 })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

        Text('>')
          .fontSize(18)
          .fontColor(color)
      }
      .width('100%')

      Row() {
        Text(meta)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .backgroundColor(bgColor)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
        Text(this.actionHint(mode))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .layoutWeight(1)
    .height(this.isTablet ? 124 : 112)
    .padding(14)
    .margin({ left: 4, right: 4 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .shadow({ radius: 12, color: COLOR_SHADOW, offsetX: 0, offsetY: 6 })
    .opacity(this.quickPracticeEnabled(mode) ? 1 : 0.72)
    .onClick(() => this.handleQuickPractice(mode))
  }

  @Builder
  CategoryCard(category: Category) {
    Row() {
      Text(this.categoryMark(category.name))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.categoryColor(category.order))
        .textAlign(TextAlign.Center)
        .width(42)
        .height(42)
        .backgroundColor(this.categorySoftColor(category.order))
        .borderRadius(8)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(category.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .layoutWeight(1)
          Text(this.categoryStateLabel(category.id))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.categoryColor(category.order))
            .backgroundColor(this.categorySoftColor(category.order))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
            .margin({ right: 6 })
          Text(this.categoryProgress(category.id))
            .fontSize(12)
            .fontColor(this.categoryColor(category.order))
            .backgroundColor(this.categorySoftColor(category.order))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
        }
        .width('100%')

        Text(category.description)
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 7 })
          .width('100%')

        Row() {
          Column()
            .height(6)
            .width(FormatUtils.percent(this.categoryCompletionRate(category.id)))
            .backgroundColor(this.categoryColor(category.order))
            .borderRadius(3)
        }
        .width('100%')
        .height(6)
        .backgroundColor('#eef2f6')
        .borderRadius(3)
        .margin({ top: 10 })

        Row() {
          Text(`模块 ${category.order} · ${this.categoryStatusText(category.id)}`)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .layoutWeight(1)
          Text('去练习 >')
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
    .margin({ bottom: 10 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .shadow({ radius: 10, color: COLOR_SHADOW, offsetX: 0, offsetY: 5 })
    .onClick(() => this.openPractice('category', category))
  }

  categoryProgress(categoryId: string): string {
    if (!this.stats) {
      return '待练习';
    }
    for (const item of this.stats.categories) {
      if (item.categoryId === categoryId) {
        if (item.totalPublished === 0) {
          return '待上新';
        }
        return `${item.answered}/${item.totalPublished}`;
      }
    }
    return '待练习';
  }

  totalPublishedCount(): number {
    if (!this.stats) {
      return 0;
    }
    let count = 0;
    for (const item of this.stats.categories) {
      count += item.totalPublished;
    }
    return count;
  }

  categoryCompletionRate(categoryId: string): number {
    if (!this.stats) {
      return 0;
    }
    for (const item of this.stats.categories) {
      if (item.categoryId === categoryId) {
        return item.completionRate;
      }
    }
    return 0;
  }

  categoryStatusText(categoryId: string): string {
    if (!this.stats) {
      return '尚未开始';
    }
    for (const item of this.stats.categories) {
      if (item.categoryId === categoryId) {
        if (item.attempts === 0) {
          return '尚未开始';
        }
        return `正确率 ${FormatUtils.percent(item.accuracy)} · 作答 ${item.attempts} 次`;
      }
    }
    return '尚未开始';
  }

  categoryStateLabel(categoryId: string): string {
    if (!this.stats) {
      return '待练';
    }
    for (const item of this.stats.categories) {
      if (item.categoryId === categoryId) {
        if (item.totalPublished === 0) {
          return '待上新';
        }
        if (item.completionRate >= 1) {
          return '已完成';
        }
        if (item.attempts > 0) {
          return '进行中';
        }
        return '待练';
      }
    }
    return '待练';
  }

  categoryColor(order: number): string {
    const index = order % 3;
    if (index === 1) {
      return COLOR_GREEN;
    }
    if (index === 2) {
      return COLOR_BLUE;
    }
    return COLOR_ORANGE;
  }

  categorySoftColor(order: number): string {
    const index = order % 3;
    if (index === 1) {
      return COLOR_SOFT_GREEN;
    }
    if (index === 2) {
      return COLOR_SOFT_BLUE;
    }
    return COLOR_SOFT_ORANGE;
  }

  actionMark(mode: string): string {
    if (mode === 'interview') {
      return '面';
    }
    if (mode === 'wrongs') {
      return '错';
    }
    if (mode === 'favorites') {
      return '藏';
    }
    return '练';
  }

  actionHint(mode: string): string {
    if (mode === 'interview') {
      return '模拟节奏';
    }
    if (mode === 'wrongs') {
      return '优先复盘';
    }
    if (mode === 'favorites') {
      return '重点回看';
    }
    return '立即开始';
  }

  quickPracticeEnabled(mode: string): boolean {
    if (mode === 'wrongs') {
      return (this.stats?.wrongCount ?? 0) > 0;
    }
    if (mode === 'favorites') {
      return (this.stats?.favoriteCount ?? 0) > 0;
    }
    return true;
  }

  handleQuickPractice(mode: string): void {
    if (!this.quickPracticeEnabled(mode)) {
      AppToast.show(this.getUIContext(),
        mode === 'wrongs' ? '还没有错题，先完成一组练习' : '还没有收藏题目，先收藏重点题');
      return;
    }
    this.openPractice(mode);
  }

  categoryMark(name: string): string {
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
    if (name.length >= 2) {
      return name.substring(0, 2);
    }
    return name;
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

  openPractice(mode: string, category?: Category) {
    if (mode === 'interview') {
      AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
        mode: 'interview',
        categoryId: '',
        title: '基础模拟面试'
      });
      return;
    }
    AppRouter.push(this.getUIContext(), 'pages/PracticePage', {
      mode,
      categoryId: category?.id ?? '',
      title: category?.name ?? ''
    });
  }

  openInterviewExperience(): void {
    AppRouter.push(this.getUIContext(), 'pages/InterviewExperiencePage');
  }
}
