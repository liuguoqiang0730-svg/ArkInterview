import router from '@ohos.router';

const COLOR_SURFACE: string = '#ffffff';
const COLOR_GREEN: string = '#16745f';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const NAV_ANIMATION_DURATION: number = 180;

@Component
export struct BottomNavBar {
  @Prop active: string = '';
  @Prop isTablet: boolean = false;

  build() {
    Row() {
      this.NavItem('首页', '训练', 'home')
      this.NavItem('错题', '复盘', 'wrongs')
      this.NavItem('收藏', '重点', 'favorites')
      this.NavItem('记录', '进度', 'records')
    }
    .width('100%')
    .height(this.isTablet ? 68 : 60)
    .constraintSize({ maxWidth: this.isTablet ? 1220 : 520 })
    .alignSelf(ItemAlign.Center)
    .padding({ left: this.isTablet ? 28 : 18, right: this.isTablet ? 28 : 18, top: 8, bottom: 8 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: { top: 1 }, color: COLOR_LINE })
  }

  @Builder
  NavItem(title: string, desc: string, target: string) {
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
      router.pushUrl({
        url: 'pages/HomePage'
      });
      return;
    }
    if (target === 'records') {
      router.pushUrl({
        url: 'pages/RecordPage'
      });
      return;
    }
    if (target === 'wrongs') {
      router.pushUrl({
        url: 'pages/PracticePage',
        params: {
          mode: 'wrongs',
          categoryId: '',
          title: '错题练习'
        }
      });
      return;
    }
    if (target === 'favorites') {
      router.pushUrl({
        url: 'pages/PracticePage',
        params: {
          mode: 'favorites',
          categoryId: '',
          title: '收藏练习'
        }
      });
    }
  }
}
