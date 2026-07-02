import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PracticeMode, PracticeSession, Question } from '../models/QuestionModels';
import { PracticeStore } from '../viewmodels/PracticeStore';

const store = new PracticeStore();

@Entry
@Component
struct PracticePage {
  @State private title: string = '练习';
  @State private session?: PracticeSession = undefined;
  @State private loading: boolean = true;

  async aboutToAppear() {
    await this.loadSession();
  }

  async loadSession() {
    const params = router.getParams() as Record<string, string>;
    const mode = params.mode || 'random';
    const categoryId = params.categoryId || undefined;
    this.title = params.title || this.modeTitle(mode);
    this.loading = true;

    try {
      if (mode === 'interview') {
        this.session = await store.startInterview(8, categoryId);
      } else {
        this.session = await store.startPractice(mode as PracticeMode, {
          categoryId,
          count: 20
        });
      }
    } catch (error) {
      promptAction.showToast({ message: `加载失败：${String(error)}` });
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button('<')
          .width(44)
          .height(36)
          .onClick(() => router.back())
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('换题')
          .height(36)
          .onClick(() => this.loadSession())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 16, bottom: 12 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .margin({ top: 36 })
      } else if ((this.session?.items.length ?? 0) === 0) {
        Text('当前模式下还没有可练习题目')
          .fontSize(15)
          .fontColor('#5b6776')
          .margin({ top: 36 })
      } else {
        List() {
          ForEach(this.session?.items ?? [], (question: Question) => {
            ListItem() {
              Column() {
                Row() {
                  Text(`${question.order ?? 0}`)
                    .fontSize(13)
                    .fontColor('#ffffff')
                    .width(28)
                    .height(28)
                    .textAlign(TextAlign.Center)
                    .backgroundColor('#166a61')
                    .borderRadius(14)
                  Text(this.typeLabel(question.type))
                    .fontSize(12)
                    .fontColor('#5b6776')
                    .margin({ left: 8 })
                  if (question.isFavorite) {
                    Text('已收藏')
                      .fontSize(12)
                      .fontColor('#166a61')
                      .margin({ left: 8 })
                  }
                }

                Text(question.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .lineHeight(22)
                  .margin({ top: 10 })

                Text((question.knowledgePoints || []).join(' / '))
                  .fontSize(12)
                  .fontColor('#5b6776')
                  .margin({ top: 8 })
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#ffffff')
              .borderRadius(8)
              .onClick(() => router.pushUrl({
                url: 'pages/QuestionPage',
                params: { questionId: question.id }
              }))
            }
            .padding({ left: 16, right: 16, bottom: 8 })
          }, (question: Question) => question.id)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f6f8fb')
  }

  modeTitle(mode: string): string {
    if (mode === 'wrongs') {
      return '错题练习';
    }
    if (mode === 'favorites') {
      return '收藏练习';
    }
    if (mode === 'interview') {
      return '基础模拟面试';
    }
    return '随机练习';
  }

  typeLabel(type: string): string {
    if (type === 'single') {
      return '单选题';
    }
    if (type === 'multiple') {
      return '多选题';
    }
    if (type === 'boolean') {
      return '判断题';
    }
    return '简答题';
  }
}
