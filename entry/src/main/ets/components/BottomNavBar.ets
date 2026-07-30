import { AppRouter } from '../utils/AppRouter';

const COLOR_SURFACE: string = '#ffffff';
const COLOR_GREEN: string = '#16745f';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SHADOW: string = '#141f2a37';
const NAV_ANIMATION_DURATION: number = 180;

@Component
export struct BottomNavBar {
  @Prop active: string = '';
  @Prop isTablet: boolean = false;
  @Prop isRootPage: boolean = false;

  build() {
    Column() {
      Row() {
        this.NavItem('首', '首页', '总览', 'home')
        this.NavItem('练', '训练', '题单', 'practice')
        this.NavItem('我', '我的', '档案', 'profile')
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: this.isTablet ? 760 : 520 })
      .padding({ left: this.isTablet ? 20 : 14, right: this.isTablet ? 20 : 14, top: 8, bottom: 8 })
    }
    .width('100%')
    .height(this.isTablet ? 72 : 64)
    .constraintSize({ maxWidth: this.isTablet ? 1220 : 520 })
    .alignSelf(ItemAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
    if (target === this.active && this.isRootPage) {
      return;
    }
    if (target === 'home') {
      AppRouter.push(this.getUIContext(), 'pages/HomePage');
      return;
    }
    if (target === 'practice') {
      AppRouter.push(this.getUIContext(), 'pages/TrainingPage');
      return;
    }
    if (target === 'profile') {
      AppRouter.push(this.getUIContext(), 'pages/MyPage');
    }
  }
}
