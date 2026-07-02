import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { APP_NAME } from '../app/AppConfig';
import { Category, UserStats } from '../models/QuestionModels';
import { PracticeStore } from '../viewmodels/PracticeStore';

const store = new PracticeStore();

@Entry
@Component
struct HomePage {
  @State private categories: Category[] = [];
  @State private stats: UserStats | undefined = undefined;
  @State private loading: boolean = true;

  aboutToAppear(): void {
    this.loadHome();
  }

  async loadHome() {
    this.loading = true;
    try {
      const snapshot = await store.loadHome();
      this.categories = snapshot.categories;
      this.stats = snapshot.stats;
    } catch (error) {
      promptAction.showToast({ message: `加载失败：${String(error)}` });
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text(APP_NAME)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
          Text('鸿蒙开发面试刷题')
            .fontSize(14)
            .fontColor('#5b6776')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('刷新')
          .height(36)
          .onClick(() => this.loadHome())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 18, bottom: 12 })

      Row() {
        this.Metric('已答', String(this.stats?.totalAnswers ?? 0))
        this.Metric('正确率', `${Math.round((this.stats?.accuracy ?? 0) * 100)}%`)
        this.Metric('错题', String(this.stats?.wrongCount ?? 0))
        this.Metric('收藏', String(this.stats?.favoriteCount ?? 0))
      }
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 12 })

      Row() {
        Button('随机练习')
          .layoutWeight(1)
          .onClick(() => this.openPractice('random'))
        Button('错题练习')
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => this.openPractice('wrongs'))
        Button('收藏练习')
          .layoutWeight(1)
          .margin({ left: 8 })
          .onClick(() => this.openPractice('favorites'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 10 })

      Row() {
        Button('基础模拟面试')
          .layoutWeight(1)
          .height(42)
          .onClick(() => router.pushUrl({ url: 'pages/PracticePage', params: { mode: 'interview' } }))
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Text('题库分类')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, right: 16, top: 18, bottom: 8 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .margin({ top: 28 })
      } else {
        List() {
          ForEach(this.categories, (category: Category) => {
            ListItem() {
              Column() {
                Text(category.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                Text(category.description)
                  .fontSize(13)
                  .fontColor('#5b6776')
                  .margin({ top: 4 })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#ffffff')
              .borderRadius(8)
              .onClick(() => this.openPractice('category', category))
            }
            .padding({ left: 16, right: 16, bottom: 8 })
          }, (category: Category) => category.id)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f6f8fb')
  }

  @Builder
  Metric(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Text(label)
        .fontSize(12)
        .fontColor('#5b6776')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding(12)
    .margin({ left: 4, right: 4 })
    .backgroundColor('#ffffff')
    .borderRadius(8)
  }

  openPractice(mode: string, category?: Category) {
    router.pushUrl({
      url: 'pages/PracticePage',
      params: {
        mode,
        categoryId: category?.id ?? '',
        title: category?.name ?? ''
      }
    });
  }
}
