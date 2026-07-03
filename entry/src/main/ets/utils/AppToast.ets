import promptAction from '@ohos.promptAction';

export class AppToast {
  static show(message: string): void {
    promptAction.showToast({ message });
  }
}
