import promptAction from '@ohos.promptAction';

export class AppToast {
  static show(message: string): void {
    try {
      promptAction.showToast({ message });
    } catch (error) {
      console.error(`toast failed: ${String(error)}`);
    }
  }
}
