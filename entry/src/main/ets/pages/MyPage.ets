import { common, Want } from '@kit.AbilityKit';
import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import display from '@ohos.display';
import { HuaweiAccountConfig } from '../app/HuaweiAccountConfig';
import { BottomNavBar } from '../components/BottomNavBar';
import { AuthStatusResponse, AuthUser, UserProfileResponse } from '../models/AccountModels';
import { UserStats } from '../models/QuestionModels';
import { ApiClient, ApiRequestError } from '../services/ApiClient';
import { AuthSessionStore } from '../services/AuthSessionStore';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';
import { FormatUtils } from '../utils/FormatUtils';

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
const COLOR_RED: string = '#b54747';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_RED: string = '#fcebea';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;
const HUAWEI_AGREEMENT_URL: string =
  'https://privacy.consumer.huawei.com/legal/id/authentication-terms.htm?code=CN&language=zh-CN';

@Entry
@Component
struct MyPage {
  @State private isTablet: boolean = false;
  @State private loading: boolean = true;
  @State private refreshing: boolean = false;
  @State private loginBusy: boolean = false;
  @State private logoutBusy: boolean = false;
  @State private preferenceBusy: boolean = false;
  @State private agreementAccepted: boolean = false;
  @State private authenticated: boolean = false;
  @State private currentUser: AuthUser | undefined = undefined;
  @State private stats: UserStats | undefined = undefined;
  @State private backendReachable: boolean = false;
  @State private huaweiLoginEnabled: boolean = false;
  @State private loadError: string = '';
  private loginButtonController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController();

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.registerHuaweiLogin();
    this.loadData(false);
  }

  private registerHuaweiLogin(): void {
    this.loginButtonController
      .setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED)
      .onClickLoginWithHuaweiIDButton(
        (error: BusinessError | undefined, credential: loginComponentManager.HuaweiIDCredential) => {
          if (error !== undefined) {
            this.handleHuaweiLoginError(error);
            return;
          }
          this.completeHuaweiLogin(credential.authorizationCode);
        });
  }

  private async loadData(showFeedback: boolean): Promise<void> {
    if (showFeedback) {
      this.refreshing = true;
    } else {
      this.loading = true;
    }
    this.loadError = '';
    this.authenticated = AuthSessionStore.isAuthenticated();
    this.currentUser = AuthSessionStore.user();

    try {
      const status: AuthStatusResponse = await api.getAuthStatus();
      this.backendReachable = true;
      this.huaweiLoginEnabled = status.huaweiLoginEnabled;
    } catch (error) {
      this.backendReachable = false;
      this.huaweiLoginEnabled = false;
      this.loadError = this.authStatusError(error);
    }

    try {
      this.stats = await api.getStats();
    } catch (error) {
      if (this.loadError.length === 0) {
        this.loadError = `学习数据加载失败：${this.readableError(error)}`;
      }
    }

    if (AuthSessionStore.isAuthenticated() && api.isSecureAuthTransport()) {
      try {
        const profile: UserProfileResponse = await api.getProfile();
        if (profile.authenticated && profile.user !== null) {
          this.authenticated = true;
          this.currentUser = profile.user;
        } else {
          await AuthSessionStore.clear();
          this.authenticated = false;
          this.currentUser = undefined;
        }
      } catch (error) {
        this.authenticated = AuthSessionStore.isAuthenticated();
        this.currentUser = AuthSessionStore.user();
        if (this.loadError.length === 0) {
          this.loadError = `登录状态校验失败：${this.readableError(error)}`;
        }
      }
    }

    this.authenticated = AuthSessionStore.isAuthenticated();
    if (!this.authenticated) {
      this.currentUser = undefined;
    }
    this.loading = false;
    this.refreshing = false;
    this.updateLoginButtonState();
    if (showFeedback && this.loadError.length === 0) {
      AppToast.show(this.getUIContext(), '已刷新');
    }
  }

  private async completeHuaweiLogin(authorizationCode: string): Promise<void> {
    if (!this.loginReady()) {
      AppToast.show(this.getUIContext(), this.loginAvailabilityMessage());
      return;
    }
    if (authorizationCode.trim().length === 0) {
      AppToast.show(this.getUIContext(), '华为账号未返回授权码');
      return;
    }

    this.loginBusy = true;
    this.updateLoginButtonState();
    try {
      const response = await api.loginWithHuawei(authorizationCode);
      this.authenticated = true;
      this.currentUser = response.user;
      this.agreementAccepted = false;
      this.loginButtonController.setAgreementStatus(loginComponentManager.AgreementStatus.NOT_ACCEPTED);
      this.stats = await api.getStats();
      AppToast.show(this.getUIContext(), '已登录，当前设备的学习记录已归入账号');
    } catch (error) {
      AppToast.show(this.getUIContext(), this.loginRequestError(error));
    } finally {
      this.loginBusy = false;
      this.updateLoginButtonState();
    }
  }

  private async confirmLogout(): Promise<void> {
    if (this.logoutBusy) {
      return;
    }
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        title: '退出登录',
        message: '退出后会切换回匿名模式，账号中的云端学习记录不会被删除。',
        buttons: [
          { text: '退出登录', color: COLOR_RED },
          { text: '取消', color: COLOR_MUTED }
        ],
        alignment: DialogAlignment.Center
      });
      if (result.index !== 0) {
        return;
      }
      this.logoutBusy = true;
      await api.logout();
      this.authenticated = false;
      this.currentUser = undefined;
      this.stats = await api.getStats();
      AppToast.show(this.getUIContext(), '已退出登录');
    } catch (error) {
      AppToast.show(this.getUIContext(), `退出失败：${this.readableError(error)}`);
    } finally {
      this.logoutBusy = false;
    }
  }

  private updateAgreement(accepted: boolean): void {
    this.agreementAccepted = accepted;
    this.loginButtonController.setAgreementStatus(accepted ?
      loginComponentManager.AgreementStatus.ACCEPTED :
      loginComponentManager.AgreementStatus.NOT_ACCEPTED);
  }

  private async updateLeaderboardPreference(enabled: boolean): Promise<void> {
    if (this.preferenceBusy) {
      return;
    }
    if (!this.authenticated || !api.isSecureAuthTransport()) {
      AppToast.show(this.getUIContext(), '排行榜设置需要登录并使用 HTTPS 服务');
      return;
    }

    this.preferenceBusy = true;
    try {
      this.currentUser = await api.updateLeaderboardPreference(enabled);
      AppToast.show(
        this.getUIContext(),
        enabled ? '已同意参与排行榜' : '已退出排行榜'
      );
    } catch (error) {
      AppToast.show(this.getUIContext(), `排行榜设置失败：${this.readableError(error)}`);
    } finally {
      this.preferenceBusy = false;
    }
  }

  private updateLoginButtonState(): void {
    this.loginButtonController.setEnabled(this.loginReady() && !this.loginBusy);
  }

  private handleHuaweiLoginError(error: BusinessError): void {
    if (error.code === 1001502012) {
      AppToast.show(this.getUIContext(), '已取消华为账号授权');
    } else if (error.code === 1001502001) {
      AppToast.show(this.getUIContext(), '请先在设备上登录华为账号');
    } else if (error.code === 1001502005) {
      AppToast.show(this.getUIContext(), '华为账号服务网络异常，请稍后重试');
    } else if (error.code === 1001502002 || error.code === 1001502014 || error.code === 1001500003) {
      AppToast.show(this.getUIContext(), 'Account Kit 尚未为当前应用正确开通');
    } else if (error.code === 1001500001) {
      AppToast.show(this.getUIContext(), '应用签名指纹校验失败，请检查 AGC 配置');
    } else if (error.code === 1005300001) {
      AppToast.show(this.getUIContext(), '请先阅读并勾选华为账号用户认证协议');
    } else {
      AppToast.show(this.getUIContext(), `华为账号授权失败：${error.message}`);
    }
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
            Text('正在加载账户与学习数据')
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
              if (this.loadError.length > 0) {
                this.ErrorBanner()
              }

              if (this.isTablet) {
                Row() {
                  Column() {
                    this.AccountPanel()
                  }
                  .layoutWeight(6)

                  Column() {
                    this.StatsPanel()
                  }
                  .layoutWeight(5)
                  .margin({ left: 16 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              } else {
                this.AccountPanel()
                this.StatsPanel()
              }

              this.LearningCenterPanel()
              this.DataStatusPanel()
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 24 })
            .constraintSize({ maxWidth: this.pageMaxWidth() })
            .alignSelf(ItemAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .layoutWeight(1)

      BottomNavBar({ active: 'profile', isTablet: this.isTablet, isRootPage: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  Header() {
    Row() {
      Column() {
        Text('我的')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
        Text(this.authenticated ? '华为账号已关联' : '当前使用匿名档案')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.authenticated ? '已登录' : '匿名')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.authenticated ? COLOR_GREEN : COLOR_BLUE)
        .backgroundColor(this.authenticated ? COLOR_SOFT_GREEN : COLOR_SOFT_BLUE)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(8)
        .margin({ right: 10 })

      Button(this.refreshing ? '刷新中' : '刷新')
        .height(36)
        .fontSize(13)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .borderRadius(8)
        .enabled(!this.refreshing)
        .onClick(() => this.loadData(true))
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
  ErrorBanner() {
    Row() {
      Text('!')
        .width(28)
        .height(28)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_ORANGE)
        .textAlign(TextAlign.Center)
        .backgroundColor(COLOR_SOFT_ORANGE)
        .borderRadius(8)
        .margin({ right: 10 })
      Text(this.loadError)
        .fontSize(13)
        .fontColor(COLOR_TEXT)
        .lineHeight(19)
        .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .margin({ bottom: 12 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: '#f1c89f' })
    .borderRadius(8)
  }

  @Builder
  AccountPanel() {
    Column() {
      Row() {
        if (this.authenticated && this.avatarUrl().length > 0) {
          Image(this.avatarUrl())
            .width(56)
            .height(56)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
            .margin({ right: 13 })
        } else {
          Text(this.userInitial())
            .width(56)
            .height(56)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#ffffff')
            .textAlign(TextAlign.Center)
            .backgroundColor(this.authenticated ? COLOR_GREEN : COLOR_BLUE)
            .borderRadius(8)
            .margin({ right: 13 })
        }

        Column() {
          Text(this.accountName())
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.authenticated ? '学习数据已关联 ArkInterview 账号' : '无需登录即可继续刷题')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 5 })
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Divider()
        .color(COLOR_LINE)
        .margin({ top: 16, bottom: 14 })

      if (this.authenticated) {
        this.AccountInfoRow('登录方式', '华为账号', COLOR_GREEN)
        this.AccountInfoRow('云端档案', '已连接', COLOR_GREEN)
        this.LeaderboardPreferenceRow()

        Button(this.logoutBusy ? '正在退出' : '退出登录')
          .width('100%')
          .height(42)
          .fontSize(14)
          .fontColor(COLOR_RED)
          .backgroundColor(COLOR_SOFT_RED)
          .borderRadius(8)
          .margin({ top: 16 })
          .enabled(!this.logoutBusy)
          .onClick(() => this.confirmLogout())
      } else {
        Text('可选登录')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .width('100%')
        Text(this.loginAvailabilityMessage())
          .fontSize(12)
          .fontColor(this.loginReady() ? COLOR_MUTED : COLOR_ORANGE)
          .lineHeight(19)
          .width('100%')
          .margin({ top: 6 })

        if (this.loginReady()) {
          LoginWithHuaweiIDButton({
            params: {
              style: loginComponentManager.Style.BUTTON_WHITE_OUTLINE,
              borderRadius: 8,
              supportDarkMode: true,
              loginType: loginComponentManager.LoginType.ID,
              textAndIconStyle: true
            },
            controller: this.loginButtonController
          })
            .width('100%')
            .height(42)
            .margin({ top: 14 })

          Row() {
            Checkbox({ name: 'huaweiAgreement', group: 'accountAgreement' })
              .width(18)
              .height(18)
              .select(this.agreementAccepted)
              .selectedColor(COLOR_GREEN)
              .onChange((value: boolean) => this.updateAgreement(value))
            Text('我已阅读并同意')
              .fontSize(12)
              .fontColor(COLOR_MUTED)
              .margin({ left: 7 })
            Text('《华为账号用户认证协议》')
              .fontSize(12)
              .fontColor(COLOR_BLUE)
              .onClick(() => this.openAgreement())
          }
          .width('100%')
          .margin({ top: 11 })
          .alignItems(VerticalAlign.Center)
        } else {
          Row() {
            Text('登录暂不可用')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_ORANGE)
              .layoutWeight(1)
            Text(this.loginStatusTag())
              .fontSize(11)
              .fontColor(COLOR_ORANGE)
              .backgroundColor(COLOR_SOFT_ORANGE)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(8)
          }
          .width('100%')
          .padding(12)
          .margin({ top: 14 })
          .backgroundColor('#fffaf5')
          .border({ width: 1, color: '#f1c89f' })
          .borderRadius(8)
        }
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
    .shadow({ radius: 12, color: COLOR_SHADOW, offsetX: 0, offsetY: 5 })
  }

  @Builder
  AccountInfoRow(label: string, value: string, valueColor: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
    }
    .width('100%')
    .height(32)
  }

  @Builder
  LeaderboardPreferenceRow() {
    Row() {
      Column() {
        Text('参与排行榜')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text('允许使用有效客观题成绩，默认关闭')
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.preferenceBusy) {
        LoadingProgress()
          .width(22)
          .height(22)
          .color(COLOR_GREEN)
          .margin({ right: 8 })
      }

      Toggle({
        type: ToggleType.Switch,
        isOn: this.currentUser?.leaderboardOptIn ?? false
      })
        .selectedColor(COLOR_GREEN)
        .enabled(!this.preferenceBusy && api.isSecureAuthTransport())
        .onChange((enabled: boolean) => this.updateLeaderboardPreference(enabled))
    }
    .width('100%')
    .padding({ top: 10, bottom: 8 })
  }

  @Builder
  StatsPanel() {
    Column() {
      Row() {
        Column() {
          Text('学习概览')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text('当前档案的累计练习数据')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(FormatUtils.percent(this.stats?.accuracy ?? 0))
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_GREEN)
      }
      .width('100%')

      Row() {
        this.Metric('累计答题', String(this.stats?.totalAnswers ?? 0), COLOR_BLUE)
        Divider()
          .vertical(true)
          .height(44)
          .color(COLOR_LINE)
        this.Metric('已覆盖', String(this.stats?.answeredQuestionCount ?? 0), COLOR_GREEN)
      }
      .width('100%')
      .margin({ top: 21 })

      Divider()
        .color(COLOR_LINE)
        .margin({ top: 14, bottom: 14 })

      Row() {
        this.Metric('待复盘错题', String(this.stats?.wrongCount ?? 0), COLOR_ORANGE)
        Divider()
          .vertical(true)
          .height(44)
          .color(COLOR_LINE)
        this.Metric('收藏题目', String(this.stats?.favoriteCount ?? 0), COLOR_BLUE)
      }
      .width('100%')

      Row() {
        Text('最近练习')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .layoutWeight(1)
        Text(this.lastPracticeLabel())
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
      }
      .width('100%')
      .padding({ top: 13 })
      .margin({ top: 16 })
      .border({ width: { top: 1 }, color: COLOR_LINE })
    }
    .width('100%')
    .padding(18)
    .margin({ top: this.isTablet ? 0 : 14 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
    .shadow({ radius: 12, color: COLOR_SHADOW, offsetX: 0, offsetY: 5 })
  }

  @Builder
  Metric(label: string, value: string, color: string) {
    Column() {
      Text(value)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
  }

  @Builder
  LearningCenterPanel() {
    Column() {
      Row() {
        Column() {
          Text('学习中心')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
          Text('练习历史、复习资产与能力排名')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('4 个入口')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_GREEN)
          .backgroundColor(COLOR_SOFT_GREEN)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 17, bottom: 12 })

      Divider()
        .color(COLOR_LINE)

      if (this.isTablet) {
        Row() {
          this.LearningEntry(
            '记',
            '练习记录',
            this.recordEntryDetail(),
            String(this.stats?.totalAnswers ?? 0),
            COLOR_BLUE,
            COLOR_SOFT_BLUE,
            'records'
          )
          this.LearningEntry(
            '错',
            '错题本',
            this.wrongEntryDetail(),
            String(this.stats?.wrongCount ?? 0),
            COLOR_RED,
            COLOR_SOFT_RED,
            'wrongs'
          )
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Divider()
          .color(COLOR_LINE)
          .margin({ left: 18, right: 18 })

        Row() {
          this.LearningEntry(
            '藏',
            '收藏题目',
            this.favoriteEntryDetail(),
            String(this.stats?.favoriteCount ?? 0),
            COLOR_ORANGE,
            COLOR_SOFT_ORANGE,
            'favorites'
          )
          this.LearningEntry(
            '榜',
            '开发者排行榜',
            this.leaderboardEntryDetail(),
            '查看',
            COLOR_GREEN,
            COLOR_SOFT_GREEN,
            'leaderboard'
          )
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      } else {
        this.LearningEntry(
          '记',
          '练习记录',
          this.recordEntryDetail(),
          String(this.stats?.totalAnswers ?? 0),
          COLOR_BLUE,
          COLOR_SOFT_BLUE,
          'records'
        )
        this.LearningDivider()
        this.LearningEntry(
          '错',
          '错题本',
          this.wrongEntryDetail(),
          String(this.stats?.wrongCount ?? 0),
          COLOR_RED,
          COLOR_SOFT_RED,
          'wrongs'
        )
        this.LearningDivider()
        this.LearningEntry(
          '藏',
          '收藏题目',
          this.favoriteEntryDetail(),
          String(this.stats?.favoriteCount ?? 0),
          COLOR_ORANGE,
          COLOR_SOFT_ORANGE,
          'favorites'
        )
        this.LearningDivider()
        this.LearningEntry(
          '榜',
          '开发者排行榜',
          this.leaderboardEntryDetail(),
          '查看',
          COLOR_GREEN,
          COLOR_SOFT_GREEN,
          'leaderboard'
        )
      }
    }
    .width('100%')
    .margin({ top: 16 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
    .shadow({ radius: 12, color: COLOR_SHADOW, offsetX: 0, offsetY: 5 })
  }

  @Builder
  LearningEntry(
    mark: string,
    title: string,
    detail: string,
    value: string,
    color: string,
    softColor: string,
    target: string
  ) {
    Row() {
      Text(mark)
        .width(42)
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .textAlign(TextAlign.Center)
        .backgroundColor(softColor)
        .borderRadius(8)
        .margin({ right: 12 })

      Column() {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text(detail)
          .fontSize(11)
          .fontColor(COLOR_MUTED)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ left: 8 })

      Text('>')
        .fontSize(17)
        .fontColor(COLOR_MUTED)
        .margin({ left: 8 })
    }
    .width(this.isTablet ? '49.5%' : '100%')
    .height(74)
    .padding({ left: 18, right: 16 })
    .onClick(() => this.openLearningEntry(target))
  }

  @Builder
  LearningDivider() {
    Divider()
      .color(COLOR_LINE)
      .margin({ left: 72, right: 18 })
  }

  @Builder
  DataStatusPanel() {
    Column() {
      Row() {
        Text('数据与安全')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text(this.authenticated ? '账号模式' : '匿名模式')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.authenticated ? COLOR_GREEN : COLOR_BLUE)
          .backgroundColor(this.authenticated ? COLOR_SOFT_GREEN : COLOR_SOFT_BLUE)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
      }
      .width('100%')

      this.StatusRow(
        '练习记录',
        this.authenticated ? '保存在账号档案中' : '由本机匿名设备 ID 关联',
        this.authenticated ? COLOR_GREEN : COLOR_BLUE
      )
      this.StatusRow(
        '登录凭证',
        this.authenticated ? '由系统 AssetStore 加密保存' : '当前没有登录凭证',
        this.authenticated ? COLOR_GREEN : COLOR_MUTED
      )
      this.StatusRow(
        '传输保护',
        api.isSecureAuthTransport() ? 'HTTPS 已启用' : '当前 API 为 HTTP，账号凭证禁止发送',
        api.isSecureAuthTransport() ? COLOR_GREEN : COLOR_ORANGE
      )
    }
    .width('100%')
    .padding(18)
    .margin({ top: 16 })
    .backgroundColor(COLOR_SURFACE)
    .border({ width: 1, color: COLOR_LINE })
    .borderRadius(8)
  }

  @Builder
  StatusRow(label: string, value: string, valueColor: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .width(this.isTablet ? 100 : 82)
      Text(value)
        .fontSize(13)
        .fontColor(valueColor)
        .lineHeight(19)
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 13 })
    .margin({ top: 12 })
    .border({ width: { top: 1 }, color: COLOR_LINE })
  }

  private loginReady(): boolean {
    return api.isSecureAuthTransport() &&
      HuaweiAccountConfig.isConfigured() &&
      this.backendReachable &&
      this.huaweiLoginEnabled;
  }

  private loginAvailabilityMessage(): string {
    if (!api.isSecureAuthTransport()) {
      return '登录仅支持 HTTPS 服务地址。匿名刷题不受影响，当前不会发送任何账号凭证。';
    }
    if (!HuaweiAccountConfig.isConfigured()) {
      return '需要先在 AGC 开通 Account Kit，并填写 OAuth Client ID。';
    }
    if (!this.backendReachable) {
      return '暂时无法确认服务器登录能力，请检查服务版本与网络。';
    }
    if (!this.huaweiLoginEnabled) {
      return '服务器尚未配置华为账号凭据，匿名刷题可以继续使用。';
    }
    return '登录后可将当前设备的学习记录归入账号档案。';
  }

  private loginStatusTag(): string {
    if (!api.isSecureAuthTransport()) {
      return '等待 HTTPS';
    }
    if (!HuaweiAccountConfig.isConfigured()) {
      return '等待 AGC';
    }
    if (!this.backendReachable) {
      return '服务未就绪';
    }
    return '服务端未启用';
  }

  private authStatusError(error: Object): string {
    if (error instanceof ApiRequestError && error.statusCode === 404) {
      return '服务器尚未部署账号接口，匿名模式保持可用';
    }
    return `账号服务状态获取失败：${this.readableError(error)}`;
  }

  private loginRequestError(error: Object): string {
    if (error instanceof ApiRequestError && error.statusCode === 503) {
      return '服务器尚未配置华为账号登录';
    }
    if (error instanceof ApiRequestError && error.statusCode === 404) {
      return '服务器尚未升级账号登录能力';
    }
    return `登录失败：${this.readableError(error)}`;
  }

  private readableError(error: Object): string {
    if (error instanceof Error) {
      return error.message;
    }
    return String(error);
  }

  private accountName(): string {
    if (!this.authenticated) {
      return '访客用户';
    }
    const displayName = this.currentUser?.displayName.trim() ?? '';
    return displayName.length > 0 ? displayName : '华为账号用户';
  }

  private userInitial(): string {
    const name = this.accountName();
    return name.length > 0 ? name.substring(0, 1) : '我';
  }

  private avatarUrl(): string {
    return this.currentUser?.avatarUrl.trim() ?? '';
  }

  private lastPracticeLabel(): string {
    const value = this.stats?.lastPracticedAt;
    return value && value.length >= 10 ? value.substring(0, 10) : '暂无记录';
  }

  private recordEntryDetail(): string {
    return `累计 ${this.stats?.answeredQuestionCount ?? 0} 道题，最近 ${this.lastPracticeLabel()}`;
  }

  private wrongEntryDetail(): string {
    const mastered = this.stats?.masteredWrongCount ?? 0;
    return mastered > 0 ? `待复盘题目，另有 ${mastered} 道已掌握` : '集中复盘答错且尚未掌握的题目';
  }

  private favoriteEntryDetail(): string {
    return (this.stats?.favoriteCount ?? 0) > 0 ? '集中复习已收藏的重点题目' : '收藏重点题后可在这里集中复习';
  }

  private leaderboardEntryDetail(): string {
    if (!this.authenticated) {
      return '登录后可参与周榜、总榜和模块榜';
    }
    return this.currentUser?.leaderboardOptIn === true ? '已参与成绩排名，查看当前名次' : '可选择参与周榜、总榜和模块榜';
  }

  private openLearningEntry(target: string): void {
    if (target === 'records') {
      AppRouter.push(this.getUIContext(), 'pages/RecordPage');
      return;
    }
    if (target === 'wrongs') {
      AppRouter.push(this.getUIContext(), 'pages/ReviewListPage', {
        mode: 'wrongs',
        title: '错题本'
      });
      return;
    }
    if (target === 'favorites') {
      AppRouter.push(this.getUIContext(), 'pages/ReviewListPage', {
        mode: 'favorites',
        title: '收藏题目'
      });
      return;
    }
    if (target === 'leaderboard') {
      AppRouter.push(this.getUIContext(), 'pages/LeaderboardPage');
    }
  }

  private openAgreement(): void {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      AppToast.show(this.getUIContext(), '无法打开协议页面');
      return;
    }
    const context = hostContext as common.UIAbilityContext;
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: HUAWEI_AGREEMENT_URL
    };
    context.startAbility(want).catch((error: BusinessError) => {
      AppToast.show(this.getUIContext(), '无法打开协议页面');
    });
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
