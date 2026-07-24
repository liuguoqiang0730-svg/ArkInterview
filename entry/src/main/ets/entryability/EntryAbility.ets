import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AuthSessionStore } from '../services/AuthSessionStore';
import { DeviceIdentity } from '../utils/DeviceIdentity';

const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'ArkInterview', 'EntryAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'ArkInterview', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.initializeApp().then(() => {
      this.loadHomePage(windowStage);
    }).catch((error: Error) => {
      hilog.error(DOMAIN, 'ArkInterview', 'App initialization failed: %{public}s', String(error));
      this.loadHomePage(windowStage);
    });
  }

  private async initializeApp(): Promise<void> {
    try {
      await DeviceIdentity.initialize(this.context);
    } catch (error) {
      DeviceIdentity.getId();
      hilog.error(DOMAIN, 'ArkInterview', 'Anonymous identity persistence failed: %{public}s', String(error));
    }

    try {
      await AuthSessionStore.initialize();
    } catch (error) {
      hilog.error(DOMAIN, 'ArkInterview', 'Secure session restore failed: %{public}s', String(error));
    }
  }

  private loadHomePage(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/HomePage', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, 'ArkInterview', 'Failed to load content: %{public}s', JSON.stringify(error));
        return;
      }
      hilog.info(DOMAIN, 'ArkInterview', 'HomePage loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'ArkInterview', 'WindowStage destroyed');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'ArkInterview', 'EntryAbility foreground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'ArkInterview', 'EntryAbility background');
  }
}
