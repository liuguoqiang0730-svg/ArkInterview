import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { Question, SubmitAnswerResponse } from '../models/QuestionModels';
import { PracticeStore } from '../viewmodels/PracticeStore';

const store = new PracticeStore();

@Entry
@Component
struct QuestionPage {
  @State private question?: Question = undefined;
  @State private selectedOptionIds: string[] = [];
  @State private answerBoolean?: boolean = undefined;
  @State private shortAnswer: string = '';
  @State private feedback?: SubmitAnswerResponse = undefined;
  @State private loading: boolean = true;

  async aboutToAppear() {
    const params = router.getParams() as Record<string, string>;
    const questionId = params.questionId;
    if (!questionId) {
      promptAction.showToast({ message: '题目参数缺失' });
      router.back();
      return;
    }
    await this.loadQuestion(questionId);
  }

  async loadQuestion(questionId: string) {
    this.loading = true;
    try {
      this.question = await store.loadQuestion(questionId);
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
        Text('答题')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button(this.question?.isFavorite ? '取消收藏' : '收藏')
          .height(36)
          .onClick(() => this.toggleFavorite())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 16, bottom: 12 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .margin({ top: 36 })
      } else if (this.question) {
        Scroll() {
          Column() {
            Text(this.question.title)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .lineHeight(27)
              .width('100%')

            Text((this.question.knowledgePoints || []).join(' / '))
              .fontSize(13)
              .fontColor('#5b6776')
              .margin({ top: 10 })
              .width('100%')

            this.AnswerArea()

            Button(this.feedback ? '已提交' : '提交答案')
              .width('100%')
              .height(44)
              .enabled(!this.feedback)
              .margin({ top: 18 })
              .onClick(() => this.submit())

            if (this.feedback) {
              this.FeedbackPanel()
            }
          }
          .padding(16)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f6f8fb')
  }

  @Builder
  AnswerArea() {
    if (this.question?.type === 'single' || this.question?.type === 'multiple') {
      Column() {
        ForEach(this.question.options, (option) => {
          Row() {
            Text(this.selectedOptionIds.includes(option.id) ? '✓' : '')
              .fontSize(16)
              .width(28)
              .height(28)
              .textAlign(TextAlign.Center)
              .fontColor('#ffffff')
              .backgroundColor(this.selectedOptionIds.includes(option.id) ? '#166a61' : '#d8e0e8')
              .borderRadius(14)
            Text(option.text)
              .fontSize(15)
              .layoutWeight(1)
              .margin({ left: 10 })
          }
          .width('100%')
          .padding(12)
          .margin({ top: 10 })
          .backgroundColor('#ffffff')
          .borderRadius(8)
          .onClick(() => this.toggleOption(option.id))
        }, (option) => option.id)
      }
      .width('100%')
      .margin({ top: 16 })
    } else if (this.question?.type === 'boolean') {
      Row() {
        Button('正确')
          .layoutWeight(1)
          .height(42)
          .backgroundColor(this.answerBoolean === true ? '#166a61' : '#ffffff')
          .fontColor(this.answerBoolean === true ? '#ffffff' : '#17202a')
          .onClick(() => this.answerBoolean = true)
        Button('错误')
          .layoutWeight(1)
          .height(42)
          .margin({ left: 10 })
          .backgroundColor(this.answerBoolean === false ? '#166a61' : '#ffffff')
          .fontColor(this.answerBoolean === false ? '#ffffff' : '#17202a')
          .onClick(() => this.answerBoolean = false)
      }
      .width('100%')
      .margin({ top: 18 })
    } else {
      TextArea({ placeholder: '输入你的简答思路，提交后对照参考答案自评。', text: this.shortAnswer })
        .height(150)
        .width('100%')
        .margin({ top: 18 })
        .onChange((value: string) => {
          this.shortAnswer = value;
        })
    }
  }

  @Builder
  FeedbackPanel() {
    Column() {
      if (this.feedback?.isCorrect === true) {
        Text('回答正确')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#166a61')
      } else if (this.feedback?.isCorrect === false) {
        Text('回答错误')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#b7412e')
      } else {
        Text('参考答案')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
      }

      if (this.feedback?.correctOptionIds) {
        Text(`正确选项：${this.feedback.correctOptionIds.join(', ')}`)
          .fontSize(14)
          .margin({ top: 10 })
          .width('100%')
      }
      if (this.feedback?.answerBoolean !== undefined) {
        Text(`正确答案：${this.feedback.answerBoolean ? '正确' : '错误'}`)
          .fontSize(14)
          .margin({ top: 10 })
          .width('100%')
      }
      if (this.feedback?.referenceAnswer) {
        Text(this.feedback.referenceAnswer)
          .fontSize(14)
          .lineHeight(22)
          .margin({ top: 10 })
          .width('100%')
      }
      if ((this.feedback?.scoringPoints?.length ?? 0) > 0) {
        Text(`评分点：${this.feedback?.scoringPoints?.join(' / ')}`)
          .fontSize(14)
          .lineHeight(22)
          .margin({ top: 10 })
          .width('100%')
      }

      Text(this.feedback?.explanation ?? '')
        .fontSize(14)
        .fontColor('#5b6776')
        .lineHeight(22)
        .margin({ top: 12 })
        .width('100%')
    }
    .width('100%')
    .padding(14)
    .margin({ top: 18 })
    .backgroundColor('#ffffff')
    .borderRadius(8)
  }

  toggleOption(optionId: string) {
    if (!this.question) {
      return;
    }
    if (this.question.type === 'single') {
      this.selectedOptionIds = [optionId];
      return;
    }
    if (this.selectedOptionIds.includes(optionId)) {
      this.selectedOptionIds = this.selectedOptionIds.filter((id) => id !== optionId);
    } else {
      this.selectedOptionIds = [...this.selectedOptionIds, optionId];
    }
  }

  async submit() {
    if (!this.question) {
      return;
    }
    try {
      this.feedback = await store.submitAnswer({
        questionId: this.question.id,
        selectedOptionIds: this.selectedOptionIds,
        answerBoolean: this.answerBoolean,
        shortAnswer: this.shortAnswer
      });
    } catch (error) {
      promptAction.showToast({ message: `提交失败：${String(error)}` });
    }
  }

  async toggleFavorite() {
    if (!this.question) {
      return;
    }
    try {
      if (this.question.isFavorite) {
        await store.removeFavorite(this.question.id);
        this.question = {
          ...this.question,
          isFavorite: false
        };
      } else {
        await store.addFavorite(this.question.id);
        this.question = {
          ...this.question,
          isFavorite: true
        };
      }
    } catch (error) {
      promptAction.showToast({ message: `操作失败：${String(error)}` });
    }
  }
}
