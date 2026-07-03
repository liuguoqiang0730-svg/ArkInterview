import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { CategoryStats, UserStats } from '../models/QuestionModels';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';
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
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct RecordPage {
  @State private stats: UserStats | undefined = undefined;
  @State private loading: boolean = true;
  @State private isTablet: boolean = false;

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.loadStats();
  }

  async loadStats() {
    this.loading = true;
    try {
      this.stats = await store.loadStats();
    } catch (error) {
      AppToast.show(`加载失败：${String(error)}`);
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Column() {
        Row() {
          Button('<')
            .width(38)
            .height(34)
            .fontColor(COLOR_NAVY)
            .backgroundColor('#eef2f6')
            .borderRadius(8)
            .onClick(() => AppRouter.back())
          Text('练习记录')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
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

        if (this.loading) {
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
        } else {
          Scroll() {
            Column() {
              this.SummaryPanel()
              this.CategoryProgressList()
            }
            .width('100%')
            .padding(16)
            .constraintSize({ maxWidth: this.pageMaxWidth() })
            .alignSelf(ItemAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
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
          Text(`${Math.round((this.stats?.accuracy ?? 0) * 100)}%`)
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
  CategoryProgressList() {
    Column() {
      Row() {
        Text('分类完成度')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
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
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
        Text(`${item.answered}/${item.totalPublished}`)
          .fontSize(12)
          .fontColor(this.progressColor(item.completionRate))
          .backgroundColor(this.progressBgColor(item.completionRate))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
      }
      .width('100%')

      Row() {
        Column()
          .height(8)
          .width(`${Math.round(item.completionRate * 100)}%`)
          .backgroundColor(this.progressColor(item.completionRate))
          .borderRadius(4)
      }
      .width('100%')
      .height(8)
      .backgroundColor('#eef2f6')
      .borderRadius(4)
      .margin({ top: 10 })

      Row() {
        Text(`正确率 ${Math.round(item.accuracy * 100)}%`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
        Text(`作答 ${item.attempts} 次`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
        Text('去练习 >')
          .fontSize(12)
          .fontColor(this.progressColor(item.completionRate))
          .margin({ left: 10 })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 10 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .onClick(() => this.openCategoryPractice(item))
  }

  pageMaxWidth(): number {
    return this.isTablet ? 920 : 520;
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

  formatDate(value?: string): string {
    if (!value) {
      return '暂无';
    }
    return value.substring(0, 10);
  }

  openCategoryPractice(item: CategoryStats): void {
    AppRouter.push('pages/PracticePage', {
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
