import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { LeaderboardEntry, LeaderboardResponse, LeaderboardScope } from '../models/LeaderboardModels';
import { Category } from '../models/QuestionModels';
import { ApiClient } from '../services/ApiClient';
import { AuthSessionStore } from '../services/AuthSessionStore';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';

const api = new ApiClient();
const COLOR_BG: string = '#f3f5f8';
const COLOR_SURFACE: string = '#ffffff';
const COLOR_NAVY: string = '#102033';
const COLOR_TEXT: string = '#1f2a37';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_GREEN: string = '#16745f';
const COLOR_BLUE: string = '#2c5f8f';
const COLOR_ORANGE: string = '#d97924';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct LeaderboardPage {
  @State private isTablet: boolean = false;
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private scope: LeaderboardScope = 'weekly';
  @State private categories: Category[] = [];
  @State private selectedCategoryIndex: number = 0;
  @State private leaderboard: LeaderboardResponse | undefined = undefined;
  @State private errorMessage: string = '';

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.loadInitialData();
  }

  private async loadInitialData(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';
    try {
      this.categories = await api.getCategories();
      await this.loadLeaderboard(false);
    } catch (error) {
      this.errorMessage = this.readableError(error);
    } finally {
      this.loading = false;
    }
  }

  private async loadLeaderboard(showFeedback: boolean): Promise<void> {
    this.refreshing = true;
    this.errorMessage = '';
    try {
      this.leaderboard = await api.getLeaderboard(this.scope, this.selectedCategoryId(), 50);
      if (showFeedback) {
        AppToast.show(this.getUIContext(), '排行榜已刷新');
      }
    } catch (error) {
      this.errorMessage = this.readableError(error);
      if (showFeedback) {
        AppToast.show(this.getUIContext(), `排行榜加载失败：${this.errorMessage}`);
      }
    } finally {
      this.refreshing = false;
    }
  }

  private selectScope(scope: LeaderboardScope): void {
    if (this.scope === scope || this.refreshing) {
      return;
    }
    this.scope = scope;
    this.loadLeaderboard(false);
  }

  private selectCategory(index: number): void {
    if (this.refreshing || index < 0 || index > this.categories.length) {
      return;
    }
    this.selectedCategoryIndex = index;
    this.loadLeaderboard(false);
  }

  build() {
    Column() {
      Column() {
        this.Header()

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
              .color(COLOR_GREEN)
            Text('正在加载排行榜')
              .fontSize(14)
              .fontColor(COLOR_MUTED)
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          if (this.errorMessage.length > 0) {
            this.ErrorBanner()
          }

          if (this.isTablet) {
            Row() {
              Column() {
                this.FilterPanel()
                this.MyRankPanel()
              }
              .width(330)
              .height('100%')

              this.DesktopLeaderboardPanel()
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16, top: 14, bottom: 16 })
            .constraintSize({ maxWidth: this.pageMaxWidth() })
            .alignSelf(ItemAlign.Center)
            .alignItems(VerticalAlign.Top)
          } else {
            Scroll() {
              Column() {
                this.FilterPanel()
                this.MyRankPanel()
                this.MobileLeaderboardPanel()
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 24 })
              .constraintSize({ maxWidth: this.pageMaxWidth() })
              .alignSelf(ItemAlign.Center)
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)

      BottomNavBar({ active: 'profile', isTablet: this.isTablet })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  Header() {
    Row() {
      Button('<')
        .width(38)
        .height(34)
        .fontColor(COLOR_NAVY)
        .backgroundColor('#eef2f6')
        .borderRadius(8)
        .onClick(() => AppRouter.back(this.getUIContext()))
      Column() {
        Text('开发者排行榜')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
        Text('参与后每道合规客观题首次答对计 1 分')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
      Button(this.refreshing ? '刷新中' : '刷新')
        .height(34)
        .fontSize(13)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .borderRadius(8)
        .enabled(!this.refreshing)
        .onClick(() => this.loadLeaderboard(true))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 15, bottom: 14 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(this.isTablet ? 8 : 0)
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .margin({ top: this.isTablet ? 20 : 0 })
    .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: 6 })
  }

  @Builder
  ErrorBanner() {
    Row() {
      Text('!')
        .width(28)
        .height(28)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ORANGE)
        .textAlign(TextAlign.Center)
        .backgroundColor(COLOR_SOFT_ORANGE)
        .borderRadius(8)
        .margin({ right: 10 })
      Text(`加载失败：${this.errorMessage}`)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
      Button('重试')
        .height(32)
        .fontSize(12)
        .fontColor(COLOR_ORANGE)
        .backgroundColor(COLOR_SOFT_ORANGE)
        .borderRadius(8)
        .onClick(() => this.loadLeaderboard(false))
    }
    .width('100%')
    .padding(12)
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .margin({ top: 12 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: '#f1c89f' })
    .borderRadius(8)
  }

  @Builder
  FilterPanel() {
    Column() {
      Text('榜单范围')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .width('100%')

      Row() {
        Button('本周榜')
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontWeight(this.scope === 'weekly' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.scope === 'weekly' ? '#ffffff' : COLOR_MUTED)
          .backgroundColor(this.scope === 'weekly' ? COLOR_GREEN : '#eef2f6')
          .borderRadius(7)
          .onClick(() => this.selectScope('weekly'))
        Button('总榜')
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontWeight(this.scope === 'overall' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.scope === 'overall' ? '#ffffff' : COLOR_MUTED)
          .backgroundColor(this.scope === 'overall' ? COLOR_GREEN : '#eef2f6')
          .borderRadius(7)
          .margin({ left: 6 })
          .onClick(() => this.selectScope('overall'))
      }
      .width('100%')
      .padding(4)
      .margin({ top: 9 })
      .backgroundColor('#eef2f6')
      .borderRadius(8)

      Text('题库模块')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .width('100%')
        .margin({ top: 18, bottom: 8 })

      Select(this.categoryOptions())
        .selected(this.selectedCategoryIndex)
        .value(this.selectedCategoryName())
        .width('100%')
        .height(42)
        .font({ size: 13 })
        .fontColor(COLOR_TEXT)
        .selectedOptionBgColor(COLOR_SOFT_GREEN)
        .optionBgColor(COLOR_SURFACE)
        .optionFontColor(COLOR_TEXT)
        .backgroundColor('#f8fafb')
        .border({ width: 1, color: COLOR_LINE })
        .borderRadius(8)
        .onSelect((index: number) => this.selectCategory(index))

      Divider()
        .color(COLOR_LINE)
        .margin({ top: 18, bottom: 14 })

      Row() {
        Text(this.scope === 'weekly' ? '周期' : '统计范围')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
        Text(this.periodLabel())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_BLUE)
      }
      .width('100%')

      Text('仅统计参与后答对的已发布、已核验单选、多选和判断题；同一题最多计 1 分。')
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .width('100%')
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  MyRankPanel() {
    Column() {
      Row() {
        Text('我的排名')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text(this.leaderboard?.me ? `第 ${this.leaderboard?.me?.rank} 名` : '暂未上榜')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.leaderboard?.me ? COLOR_GREEN : COLOR_MUTED)
      }
      .width('100%')

      if (this.leaderboard?.me) {
        Row() {
          Text(String(this.leaderboard?.me?.score ?? 0))
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_GREEN)
          Text('分')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ left: 4, top: 10 })
          Blank()
          Text(this.leaderboard?.me?.displayName ?? '')
            .fontSize(12)
            .fontColor(COLOR_BLUE)
        }
        .width('100%')
        .margin({ top: 12 })
      } else {
        Text(this.myRankHint())
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(19)
          .width('100%')
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 14 })
    .backgroundColor(this.leaderboard?.me ? COLOR_SOFT_GREEN : COLOR_SURFACE)
    .border({
      width: 1,
      color: this.leaderboard?.me ? '#b8ddcf' : COLOR_LINE
    })
    .borderRadius(8)
  }

  @Builder
  DesktopLeaderboardPanel() {
    Column() {
      this.ListHeader()
      if ((this.leaderboard?.entries.length ?? 0) === 0) {
        this.EmptyLeaderboard()
      } else {
        List({ space: 8 }) {
          ForEach(this.leaderboard?.entries ?? [], (item: LeaderboardEntry) => {
            ListItem() {
              this.LeaderboardRow(item)
            }
          }, (item: LeaderboardEntry) => String(item.rank))
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 14, right: 14, bottom: 14 })
        .scrollBar(BarState.Auto)
      }
    }
    .layoutWeight(1)
    .height('100%')
    .margin({ left: 16 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  MobileLeaderboardPanel() {
    Column() {
      this.ListHeader()
      if ((this.leaderboard?.entries.length ?? 0) === 0) {
        this.EmptyLeaderboard()
      } else {
        ForEach(this.leaderboard?.entries ?? [], (item: LeaderboardEntry) => {
          this.LeaderboardRow(item)
        }, (item: LeaderboardEntry) => String(item.rank))
      }
    }
    .width('100%')
    .margin({ top: 14 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  ListHeader() {
    Row() {
      Column() {
        Text(`${this.scope === 'weekly' ? '本周榜' : '总榜'} · ${this.selectedCategoryName()}`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
        Text(`${this.leaderboard?.totalParticipants ?? 0} 位开发者有有效得分`)
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('得分')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 15, bottom: 13 })
    .margin({ bottom: 2 })
    .border({ width: { bottom: 1 }, color: COLOR_LINE })
  }

  @Builder
  LeaderboardRow(item: LeaderboardEntry) {
    Row() {
      Text(String(item.rank))
        .width(38)
        .height(38)
        .fontSize(item.rank <= 3 ? 15 : 13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.rankColor(item.rank))
        .textAlign(TextAlign.Center)
        .backgroundColor(this.rankBackground(item.rank))
        .borderRadius(8)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(item.displayName)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (item.isCurrentUser) {
            Text('我')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_GREEN)
              .backgroundColor(COLOR_SOFT_GREEN)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .margin({ left: 7 })
          }
        }
        .width('100%')
        Text(`最后得分 ${this.formatDate(item.lastScoredAt)}`)
          .fontSize(10)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(String(item.score))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(item.rank <= 3 ? this.rankColor(item.rank) : COLOR_GREEN)
      Text('分')
        .fontSize(10)
        .fontColor(COLOR_MUTED)
        .margin({ left: 3, top: 6 })
    }
    .width('100%')
    .height(66)
    .padding({ left: 12, right: 12 })
    .margin({ left: this.isTablet ? 0 : 12, right: this.isTablet ? 0 : 12, bottom: 8 })
    .backgroundColor(item.isCurrentUser ? '#f2faf7' : '#f8fafb')
    .border({
      width: 1,
      color: item.isCurrentUser ? '#b8ddcf' : '#edf0f4'
    })
    .borderRadius(8)
  }

  @Builder
  EmptyLeaderboard() {
    Column() {
      Text('暂无有效排名')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
      Text('当前范围还没有主动参与并获得有效得分的开发者')
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(19)
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
    }
    .width('100%')
    .layoutWeight(this.isTablet ? 1 : 0)
    .height(this.isTablet ? 'auto' : 180)
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }

  private categoryOptions(): SelectOption[] {
    const options: SelectOption[] = [{ value: '全部模块' }];
    for (let index = 0; index < this.categories.length; index++) {
      options.push({ value: this.categories[index].name });
    }
    return options;
  }

  private selectedCategoryId(): string {
    if (this.selectedCategoryIndex <= 0 || this.selectedCategoryIndex > this.categories.length) {
      return '';
    }
    return this.categories[this.selectedCategoryIndex - 1].id;
  }

  private selectedCategoryName(): string {
    if (this.selectedCategoryIndex <= 0 || this.selectedCategoryIndex > this.categories.length) {
      return '全部模块';
    }
    return this.categories[this.selectedCategoryIndex - 1].name;
  }

  private periodLabel(): string {
    if (this.scope === 'overall') {
      return '全部历史';
    }
    const value = this.leaderboard?.periodStart;
    return value && value.length >= 10 ? `${this.formatShanghaiDate(value)} 起` : '本周';
  }

  private myRankHint(): string {
    if (!AuthSessionStore.isAuthenticated()) {
      return '登录并主动参与排行榜后，可在这里查看自己的排名。';
    }
    if (!AuthSessionStore.user()?.leaderboardOptIn) {
      return '当前账号尚未开启排行榜参与，可在“我的”页面主动开启。';
    }
    return '当前范围还没有有效得分，完成新的合规客观题后会进入排名。';
  }

  private rankColor(rank: number): string {
    if (rank === 1) {
      return COLOR_ORANGE;
    }
    if (rank === 2) {
      return COLOR_BLUE;
    }
    if (rank === 3) {
      return COLOR_GREEN;
    }
    return COLOR_MUTED;
  }

  private rankBackground(rank: number): string {
    if (rank === 1) {
      return COLOR_SOFT_ORANGE;
    }
    if (rank === 2) {
      return COLOR_SOFT_BLUE;
    }
    if (rank === 3) {
      return COLOR_SOFT_GREEN;
    }
    return '#eef2f6';
  }

  private formatDate(value: string): string {
    return this.formatShanghaiDate(value);
  }

  private formatShanghaiDate(value: string): string {
    const timestamp = Date.parse(value);
    if (Number.isNaN(timestamp)) {
      return value.length >= 10 ? value.substring(0, 10) : value;
    }
    const shifted = new Date(timestamp + 8 * 60 * 60 * 1000);
    const year = shifted.getUTCFullYear();
    const month = this.twoDigits(shifted.getUTCMonth() + 1);
    const day = this.twoDigits(shifted.getUTCDate());
    return `${year}-${month}-${day}`;
  }

  private twoDigits(value: number): string {
    return value < 10 ? `0${value}` : String(value);
  }

  private readableError(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return String(error);
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
