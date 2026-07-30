import router from '@ohos.router';
import { UIContext } from '@kit.ArkUI';

export interface AppRouteParams {
  mode?: string;
  title?: string;
  categoryId?: string;
  count?: string;
  type?: string;
  difficulty?: string;
  questionId?: string;
  questionIds?: string;
  questionIndex?: string;
}

export class AppRouter {
  static push(uiContext: UIContext, url: string, params?: AppRouteParams): void {
    try {
      const options: router.RouterOptions = {
        url
      };
      if (params !== undefined) {
        options.params = params;
      }
      uiContext.getRouter().pushUrl(options).catch((error: Error) => {
        console.error(`route push failed: ${String(error)}`);
      });
    } catch (error) {
      console.error(`route push failed: ${String(error)}`);
    }
  }

  static back(uiContext: UIContext): void {
    try {
      uiContext.getRouter().back();
    } catch (error) {
      console.error(`route back failed: ${String(error)}`);
    }
  }

  static params(uiContext: UIContext): Record<string, string> {
    try {
      return uiContext.getRouter().getParams() as Record<string, string>;
    } catch (error) {
      console.error(`route params failed: ${String(error)}`);
      return {};
    }
  }
}
