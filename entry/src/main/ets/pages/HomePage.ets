import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { APP_NAME } from '../app/AppConfig';
import { Category, UserStats } from '../models/QuestionModels';
import { PracticeStore } from '../viewmodels/PracticeStore';

const store = new PracticeStore();
const COLOR_BG: string = '#f3f5f8';
const COLOR_SURFACE: string = '#ffffff';
const COLOR_NAVY: string = '#102033';
const COLOR_TEXT: string = '#1f2a37';
const COLOR_MUTED: string = '#667085';
const COLOR_LINE: string = '#e4e9f0';
const COLOR_GREEN: string = '#16745f';
const COLOR_ORANGE: string = '#d97924';
const COLOR_BLUE: string = '#2c5f8f';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_BLUE: string = '#e9f0f7';

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
    Scroll() {
      Column() {
        Row() {
          Column() {
            Text(APP_NAME)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_NAVY)
            Text('HarmonyOS 开发者面试训练台')
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .margin({ top: 5 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('刷新')
            .height(36)
            .fontSize(13)
            .fontColor(COLOR_GREEN)
            .backgroundColor(COLOR_SOFT_GREEN)
            .borderRadius(8)
            .onClick(() => this.loadHome())
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 20, bottom: 14 })

        Column() {
          Row() {
            Column() {
              Text('学习进度')
                .fontSize(13)
                .fontColor('#d8efe8')
              Text(`${this.stats?.answeredQuestionCount ?? 0}`)
                .fontSize(34)
                .fontWeight(FontWeight.Bold)
                .fontColor('#ffffff')
                .margin({ top: 4 })
              Text('已覆盖题目')
                .fontSize(13)
                .fontColor('#d8efe8')
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              Text(`${Math.round((this.stats?.accuracy ?? 0) * 100)}%`)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#ffffff')
              Text('正确率')
                .fontSize(12)
                .fontColor('#d8efe8')
                .margin({ top: 3 })
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')

          Row() {
            this.DashboardMetric('已答', String(this.stats?.totalAnswers ?? 0), COLOR_SOFT_BLUE, COLOR_BLUE)
            this.DashboardMetric('错题', String(this.stats?.wrongCount ?? 0), COLOR_SOFT_ORANGE, COLOR_ORANGE)
            this.DashboardMetric('收藏', String(this.stats?.favoriteCount ?? 0), COLOR_SOFT_GREEN, COLOR_GREEN)
          }
          .width('100%')
          .margin({ top: 18 })
        }
        .width('100%')
        .padding(18)
        .backgroundColor(COLOR_NAVY)
        .borderRadius(8)
        .margin({ left: 18, right: 18, bottom: 14 })

        Column() {
          Row() {
            this.ActionCard('随机练习', '快速进入综合训练', COLOR_GREEN, COLOR_SOFT_GREEN, 'random')
            this.ActionCard('模拟面试', '按面试节奏抽题', COLOR_BLUE, COLOR_SOFT_BLUE, 'interview')
          }
          .width('100%')

          Row() {
            this.ActionCard('错题练习', '集中处理薄弱点', COLOR_ORANGE, COLOR_SOFT_ORANGE, 'wrongs')
            this.ActionCard('收藏复习', '回看重点题目', COLOR_GREEN, COLOR_SOFT_GREEN, 'favorites')
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 16 })

        Row() {
          Text('题库模块')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .layoutWeight(1)
          Text(`${this.categories.length} 个分类`)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 8 })

        if (this.loading) {
          LoadingProgress()
            .width(36)
            .height(36)
            .margin({ top: 28, bottom: 28 })
        } else {
          Column() {
            ForEach(this.categories, (category: Category) => {
              this.CategoryCard(category)
            }, (category: Category) => category.id)
          }
          .width('100%')
          .padding({ left: 18, right: 18, bottom: 20 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  DashboardMetric(label: string, value: string, bgColor: string, textColor: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 3, right: 3 })
    .backgroundColor(bgColor)
    .borderRadius(8)
  }

  @Builder
  ActionCard(title: string, desc: string, color: string, bgColor: string, mode: string) {
    Column() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
        Text('>')
          .fontSize(18)
          .fontColor(color)
      }
      .width('100%')

      Text(desc)
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 8 })
        .width('100%')
    }
    .layoutWeight(1)
    .height(94)
    .padding(14)
    .margin({ left: 4, right: 4 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: bgColor })
    .onClick(() => this.openPractice(mode))
  }

  @Builder
  CategoryCard(category: Category) {
    Row() {
      Column()
        .width(4)
        .height(58)
        .backgroundColor(this.categoryColor(category.order))
        .borderRadius(2)
        .margin({ right: 12 })

      Column() {
        Row() {
          Text(category.name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .layoutWeight(1)
          Text(this.categoryProgress(category.id))
            .fontSize(12)
            .fontColor(this.categoryColor(category.order))
            .backgroundColor(this.categorySoftColor(category.order))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
        }
        .width('100%')

        Text(category.description)
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 6 })
          .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .margin({ bottom: 10 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .onClick(() => this.openPractice('category', category))
  }

  categoryProgress(categoryId: string): string {
    if (!this.stats) {
      return '待练习';
    }
    for (const item of this.stats.categories) {
      if (item.categoryId === categoryId) {
        if (item.totalPublished === 0) {
          return '待上新';
        }
        return `${item.answered}/${item.totalPublished}`;
      }
    }
    return '待练习';
  }

  categoryColor(order: number): string {
    const index = order % 3;
    if (index === 1) {
      return COLOR_GREEN;
    }
    if (index === 2) {
      return COLOR_BLUE;
    }
    return COLOR_ORANGE;
  }

  categorySoftColor(order: number): string {
    const index = order % 3;
    if (index === 1) {
      return COLOR_SOFT_GREEN;
    }
    if (index === 2) {
      return COLOR_SOFT_BLUE;
    }
    return COLOR_SOFT_ORANGE;
  }

  openPractice(mode: string, category?: Category) {
    if (mode === 'interview') {
      router.pushUrl({
        url: 'pages/PracticePage',
        params: {
          mode: 'interview',
          categoryId: '',
          title: '基础模拟面试'
        }
      });
      return;
    }
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
