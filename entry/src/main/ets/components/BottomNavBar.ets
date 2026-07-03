import { AppRouter } from '../utils/AppRouter';

const COLOR_SURFACE: string = '#ffffff';
const COLOR_GREEN: string = '#16745f';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SHADOW: string = '#1f2a3714';
const NAV_ANIMATION_DURATION: number = 180;

@Component
export struct BottomNavBar {
  @Prop active: string = '';
  @Prop isTablet: boolean = false;

  build() {
    Row() {
      this.NavItem('首', '首页', '训练', 'home')
      this.NavItem('错', '错题', '复盘', 'wrongs')
      this.NavItem('藏', '收藏', '重点', 'favorites')
      this.NavItem('记', '记录', '进度', 'records')
    }
    .width('100%')
    .height(this.isTablet ? 72 : 64)
    .constraintSize({ maxWidth: this.isTablet ? 1220 : 520 })
    .alignSelf(ItemAlign.Center)
    .padding({ left: this.isTablet ? 28 : 18, right: this.isTablet ? 28 : 18, top: 8, bottom: 8 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: { top: 1 }, color: COLOR_LINE })
    .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: -4 })
  }

  @Builder
  NavItem(mark: string, title: string, desc: string, target: string) {
    Row() {
      Text(mark)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.active === target ? '#ffffff' : COLOR_MUTED)
        .textAlign(TextAlign.Center)
        .width(28)
        .height(28)
        .backgroundColor(this.active === target ? COLOR_GREEN : '#eef2f6')
        .borderRadius(8)
        .margin({ right: this.isTablet ? 8 : 5 })

      Column() {
        Text(title)
          .fontSize(13)
          .fontWeight(this.active === target ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.active === target ? COLOR_GREEN : COLOR_MUTED)
        Text(desc)
          .fontSize(10)
          .fontColor(this.active === target ? COLOR_GREEN : '#98a2b3')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.active === target ? COLOR_SOFT_GREEN : COLOR_SURFACE)
    .borderRadius(8)
    .margin({ left: 4, right: 4 })
    .scale({
      x: this.active === target ? 1.04 : 1,
      y: this.active === target ? 1.04 : 1
    })
    .opacity(this.active === target ? 1 : 0.82)
    .animation({
      duration: NAV_ANIMATION_DURATION,
      curve: Curve.EaseOut
    })
    .onClick(() => this.openTarget(target))
  }

  openTarget(target: string): void {
    if (target === this.active) {
      return;
    }
    if (target === 'home') {
      AppRouter.push('pages/HomePage');
      return;
    }
    if (target === 'records') {
      AppRouter.push('pages/RecordPage');
      return;
    }
    if (target === 'wrongs') {
      AppRouter.push('pages/ReviewListPage', {
        mode: 'wrongs',
        title: '错题本'
      });
      return;
    }
    if (target === 'favorites') {
      AppRouter.push('pages/ReviewListPage', {
        mode: 'favorites',
        title: '收藏题目'
      });
    }
  }
}
