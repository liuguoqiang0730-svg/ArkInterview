import { UIContext } from '@kit.ArkUI';

export class AppToast {
  static show(uiContext: UIContext, message: string): void {
    try {
      uiContext.getPromptAction().openToast({ message }).catch((error: Error) => {
        console.error(`toast failed: ${String(error)}`);
      });
    } catch (error) {
      console.error(`toast failed: ${String(error)}`);
    }
  }
}
