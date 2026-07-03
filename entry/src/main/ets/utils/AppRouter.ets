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
  }

  static back(): void {
    router.back();
  }

  static params(): Record<string, string> {
    return router.getParams() as Record<string, string>;
  }
}
