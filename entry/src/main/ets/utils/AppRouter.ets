import router from '@ohos.router';

export interface AppRouteParams {
  mode?: string;
  title?: string;
  categoryId?: string;
  questionId?: string;
  questionIds?: string;
  questionIndex?: string;
  navActive?: string;
}

export class AppRouter {
  static push(url: string, params?: AppRouteParams): void {
    try {
      if (params) {
        router.pushUrl({
          url,
          params
        });
        return;
      }
      router.pushUrl({
        url
      });
    } catch (error) {
      console.error(`route push failed: ${String(error)}`);
    }
  }

  static back(): void {
    try {
      router.back();
    } catch (error) {
      console.error(`route back failed: ${String(error)}`);
    }
  }

  static params(): Record<string, string> {
    try {
      return router.getParams() as Record<string, string>;
    } catch (error) {
      console.error(`route params failed: ${String(error)}`);
      return {};
    }
  }
}
