import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { Question, QuestionOption, SubmitAnswerResponse } from '../models/QuestionModels';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';
import { PracticeEvents } from '../utils/PracticeEvents';
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
const COLOR_RED: string = '#b42318';
const COLOR_SOFT_GREEN: string = '#e7f4ef';
const COLOR_SOFT_ORANGE: string = '#fff1e5';
const COLOR_SOFT_BLUE: string = '#e9f0f7';
const COLOR_SOFT_RED: string = '#fee4e2';
const COLOR_SHADOW: string = '#1f2a3714';
const TABLET_MIN_VP: number = 680;
const ANSWER_STATUS_UNANSWERED: string = 'unanswered';
const ANSWER_STATUS_CORRECT: string = 'correct';
const ANSWER_STATUS_WRONG: string = 'wrong';
const ANSWER_STATUS_REVIEW: string = 'review';

interface AnswerProgressItem {
  questionId: string;
  order: number;
  status: string;
  isCorrect: boolean | null;
  selectedOptionIds: string[];
  answerBoolean?: boolean;
  shortAnswer: string;
  feedback?: SubmitAnswerResponse;
}

@Entry
@Component
struct QuestionPage {
  @State private question: Question | undefined = undefined;
  @State private questionIds: string[] = [];
  @State private currentIndex: number = 0;
  @State private answerProgress: AnswerProgressItem[] = [];
  @State private showProgressPanel: boolean = false;
  @State private selectedOptionIds: string[] = [];
  @State private answerBoolean: boolean | undefined = undefined;
  @State private shortAnswer: string = '';
  @State private feedback: SubmitAnswerResponse | undefined = undefined;
  @State private loading: boolean = true;
  @State private isTablet: boolean = false;
  @State private masteringWrong: boolean = false;
  @State private autoMoveToken: number = 0;
  @State private navActive: string = 'home';
  @State private showCompletionSummary: boolean = false;

  aboutToAppear(): void {
    this.updateLayoutMode();
    const params = AppRouter.params();
    const questionId = params.questionId;
    if (!questionId) {
      AppToast.show('题目参数缺失');
      AppRouter.back();
      return;
    }
    this.navActive = params.navActive || 'home';
    const ids = this.parseQuestionIds(params.questionIds, questionId);
    this.questionIds = ids;
    this.answerProgress = this.createProgress(ids);
    this.currentIndex = this.findQuestionIndex(ids, questionId);
    this.loadQuestion(ids[this.currentIndex]);
  }

  async loadQuestion(questionId: string) {
    this.loading = true;
    this.masteringWrong = false;
    try {
      this.question = await store.loadQuestion(questionId);
      this.restoreAnswerState(questionId);
    } catch (error) {
      AppToast.show(`加载失败：${String(error)}`);
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
        Row() {
          Button('<')
            .width(38)
            .height(34)
            .fontColor(COLOR_NAVY)
            .backgroundColor('#eef2f6')
            .borderRadius(8)
            .onClick(() => AppRouter.back())
          Column() {
            Text('训练答题')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_NAVY)
            Text(this.headerProgressText())
              .fontSize(11)
              .fontColor(COLOR_MUTED)
              .margin({ top: 2 })
          }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          this.ProgressButton()
          Button(this.favoriteButtonText())
            .height(34)
            .fontSize(13)
            .fontColor(this.question?.isFavorite ? COLOR_ORANGE : COLOR_GREEN)
            .backgroundColor(this.question?.isFavorite ? COLOR_SOFT_ORANGE : COLOR_SOFT_GREEN)
            .borderRadius(8)
            .onClick(() => this.toggleFavorite())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 14 })
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(this.isTablet ? 8 : 0)
        .constraintSize({ maxWidth: this.pageMaxWidth() })
        .alignSelf(ItemAlign.Center)
        .margin({ top: this.isTablet ? 20 : 0 })
        .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: 7 })

        if (this.showCompletionSummary) {
          this.CompletionFlow()
        } else if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
            Text('正在加载题目详情')
              .fontSize(14)
              .fontColor(COLOR_MUTED)
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.question) {
          if (this.isTablet) {
            this.TabletAnswerWorkspace()
          } else {
            this.PhoneAnswerFlow()
          }
        }
        }
        .width('100%')
        .height('100%')

        if (this.showProgressPanel) {
          this.ProgressOverlay()
        }
      }
      .layoutWeight(1)
      .width('100%')

      BottomNavBar({ active: this.navActive, isTablet: this.isTablet })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  ProgressButton() {
    Row() {
      Text(this.questionCardStateMark())
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.showProgressPanel ? COLOR_BLUE : '#ffffff')
        .textAlign(TextAlign.Center)
        .width(18)
        .height(18)
        .backgroundColor(this.showProgressPanel ? '#ffffff' : this.questionCardToneColor())
        .borderRadius(9)
        .margin({ right: 7 })
      Text(this.questionCardTitle())
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.showProgressPanel ? '#ffffff' : COLOR_BLUE)
      Text(this.questionCardSummary())
        .fontSize(11)
        .fontColor(this.showProgressPanel ? '#e9f0f7' : COLOR_MUTED)
        .margin({ left: 6 })
    }
    .height(34)
    .padding({ left: 12, right: 12 })
    .margin({ right: 8 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.showProgressPanel ? COLOR_BLUE : COLOR_SOFT_BLUE)
    .borderRadius(8)
    .border({ width: 1, color: this.showProgressPanel ? COLOR_BLUE : '#d6e4f2' })
    .onClick(() => this.showProgressPanel = !this.showProgressPanel)
  }

  @Builder
  CompletionFlow() {
    Scroll() {
      Column() {
        this.CompletionPanel()
      }
      .width('100%')
      .padding(16)
      .constraintSize({ maxWidth: this.pageMaxWidth() })
      .alignSelf(ItemAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  CompletionPanel() {
    Column() {
      this.CompletionHero()

      Row() {
        this.SummaryMetric('题量', String(this.questionIds.length), COLOR_SOFT_BLUE, COLOR_BLUE)
        this.SummaryMetric('已答', String(this.answeredCount()), COLOR_SOFT_GREEN, COLOR_GREEN)
        this.SummaryMetric('正确率', this.correctRateText(), COLOR_SOFT_ORANGE, COLOR_ORANGE)
      }
      .width('100%')
      .margin({ top: 18 })

      Row() {
        this.SummaryMetric('正确', String(this.correctCount()), COLOR_SOFT_GREEN, COLOR_GREEN)
        this.SummaryMetric('错误', String(this.wrongCount()), COLOR_SOFT_RED, COLOR_RED)
        this.SummaryMetric('未答', String(this.unansweredCount()), '#f8fafc', COLOR_MUTED)
      }
      .width('100%')
      .margin({ top: 10 })

      Column() {
        Text(this.completionAdviceTitle())
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .width('100%')
        Text(this.completionAdviceText())
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(20)
          .margin({ top: 6 })
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .margin({ top: 14 })
      .backgroundColor(COLOR_SOFT_BLUE)
      .borderRadius(8)
      .border({ width: 1, color: '#d6e4f2' })

      Text('题号总览')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .width('100%')
        .margin({ top: 20 })

      Grid() {
        ForEach(this.answerProgress, (item: AnswerProgressItem) => {
          GridItem() {
            Text(String(item.order + 1))
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.progressTextColor(item))
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(36)
              .backgroundColor(this.progressBgColor(item))
              .borderRadius(8)
              .border({ width: 1, color: this.progressBorderColor(item) })
          }
          .onClick(() => this.goQuestionAt(item.order))
        }, (item: AnswerProgressItem) => item.questionId)
      }
      .columnsTemplate(this.isTablet ? '1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr' : '1fr 1fr 1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
      .margin({ top: 12 })

      Row() {
        Button('复盘错题')
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.wrongCount() > 0 ? '#ffffff' : COLOR_MUTED)
          .enabled(this.wrongCount() > 0)
          .backgroundColor(this.wrongCount() > 0 ? COLOR_RED : '#eef2f6')
          .borderRadius(8)
          .margin({ right: 8 })
          .onClick(() => this.goFirstByStatus(ANSWER_STATUS_WRONG))
        Button('查看未答')
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.unansweredCount() > 0 ? '#ffffff' : COLOR_MUTED)
          .enabled(this.unansweredCount() > 0)
          .backgroundColor(this.unansweredCount() > 0 ? COLOR_BLUE : '#eef2f6')
          .borderRadius(8)
          .margin({ left: 8 })
          .onClick(() => this.goFirstByStatus(ANSWER_STATUS_UNANSWERED))
      }
      .width('100%')
      .margin({ top: 22 })

      Button('返回题单')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_GREEN)
        .backgroundColor(COLOR_SOFT_GREEN)
        .borderRadius(8)
        .margin({ top: 12 })
        .onClick(() => AppRouter.back())
    }
    .width('100%')
    .padding(18)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  CompletionHero() {
    Row() {
      Column() {
        Text('本轮复盘')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
          .width('100%')
        Text(this.completionSummaryText())
          .fontSize(13)
          .fontColor('#d8efe8')
          .lineHeight(20)
          .margin({ top: 8 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text(this.correctRateText())
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
        Text('正确率')
          .fontSize(12)
          .fontColor('#d8efe8')
          .margin({ top: 4 })
      }
      .width(108)
      .height(108)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#ffffff1f')
      .borderRadius(8)
      .border({ width: 1, color: '#ffffff33' })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.completionToneColor())
    .borderRadius(8)
    .margin({ bottom: 18 })
  }

  @Builder
  SummaryMetric(label: string, value: string, bgColor: string, textColor: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .margin({ top: 3 })
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .margin({ left: 3, right: 3 })
    .backgroundColor(bgColor)
    .borderRadius(8)
  }

  @Builder
  PhoneAnswerFlow() {
    Scroll() {
      Column() {
        this.QuestionCard()
        this.QuestionNavigator()
        this.AnswerArea()
        this.SubmitButton()
        if (this.feedback) {
          this.FeedbackPanel()
        }
      }
      .width('100%')
      .padding(16)
      .constraintSize({ maxWidth: this.pageMaxWidth() })
      .alignSelf(ItemAlign.Center)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  TabletAnswerWorkspace() {
    Scroll() {
      Column() {
        this.QuestionCard()
        this.QuestionNavigator()
        this.AnswerArea()
        this.SubmitButton()
        if (this.feedback) {
          this.FeedbackPanel()
        }
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  ProgressOverlay() {
    Column() {
      this.ProgressPanel()
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.isTablet ? 74 : 58, right: this.isTablet ? 28 : 16 })
    .alignItems(HorizontalAlign.End)
    .backgroundColor('#00000000')
    .onClick(() => this.showProgressPanel = false)
  }

  @Builder
  ProgressPanel() {
    Column() {
      Row() {
        Text('本轮进度')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text('绿=正确  红=错误  蓝=待自评')
          .fontSize(11)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        this.StatusMetric('已答', String(this.answeredCount()), COLOR_SOFT_BLUE, COLOR_BLUE)
        this.StatusMetric('正确', String(this.correctCount()), COLOR_SOFT_GREEN, COLOR_GREEN)
        this.StatusMetric('错误', String(this.wrongCount()), COLOR_SOFT_RED, COLOR_RED)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        this.ProgressLegend('正确', COLOR_SOFT_GREEN, COLOR_GREEN)
        this.ProgressLegend('错误', COLOR_SOFT_RED, COLOR_RED)
        this.ProgressLegend('未答', '#f8fafc', COLOR_LINE)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Grid() {
        ForEach(this.answerProgress, (item: AnswerProgressItem) => {
          GridItem() {
            Text(String(item.order + 1))
              .fontSize(13)
              .fontWeight(this.currentIndex === item.order ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.progressTextColor(item))
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(30)
              .backgroundColor(this.progressBgColor(item))
              .borderRadius(8)
              .border({ width: 1, color: this.currentIndex === item.order ? COLOR_NAVY : this.progressBorderColor(item) })
          }
          .onClick(() => this.goQuestionAt(item.order))
        }, (item: AnswerProgressItem) => item.questionId)
      }
      .columnsTemplate(this.isTablet ? '1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr' : '1fr 1fr 1fr 1fr 1fr')
      .columnsGap(7)
      .rowsGap(7)
      .width('100%')
    }
    .width(this.isTablet ? 392 : 312)
    .padding(14)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
    .shadow({ radius: 18, color: '#1f2a3726', offsetX: 0, offsetY: 8 })
  }

  @Builder
  QuestionNavigator() {
    Row() {
      Button('上一题')
        .height(38)
        .fontSize(13)
        .fontColor(this.hasPrevious() ? COLOR_NAVY : COLOR_MUTED)
        .enabled(this.hasPrevious())
        .backgroundColor('#eef2f6')
        .borderRadius(8)
        .onClick(() => this.goPreviousQuestion())

      Text(`第 ${this.currentIndex + 1}/${this.questionIds.length || 1} 题`)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_MUTED)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)

      Button('下一题')
        .height(38)
        .fontSize(13)
        .fontColor(this.hasNext() ? COLOR_NAVY : COLOR_MUTED)
        .enabled(this.hasNext())
        .backgroundColor('#eef2f6')
        .borderRadius(8)
        .onClick(() => this.goNextQuestion())
    }
    .width('100%')
    .padding({ left: 2, right: 2 })
    .margin({ top: 12 })
  }

  @Builder
  SessionStatusPanel() {
    Column() {
      Text('本轮状态')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_NAVY)
        .width('100%')

      Row() {
        this.StatusMetric('已答', String(this.answeredCount()), COLOR_SOFT_BLUE, COLOR_BLUE)
        this.StatusMetric('正确', String(this.correctCount()), COLOR_SOFT_GREEN, COLOR_GREEN)
        this.StatusMetric('错误', String(this.wrongCount()), COLOR_SOFT_RED, COLOR_RED)
      }
      .width('100%')
      .margin({ top: 14 })

      Text('题号状态')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .width('100%')
        .margin({ top: 18 })

      Grid() {
        ForEach(this.answerProgress, (item: AnswerProgressItem) => {
          GridItem() {
            Text(String(item.order + 1))
              .fontSize(12)
              .fontWeight(this.currentIndex === item.order ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.progressTextColor(item))
              .textAlign(TextAlign.Center)
              .width('100%')
              .height(32)
              .backgroundColor(this.progressBgColor(item))
              .borderRadius(8)
              .border({ width: 1, color: this.currentIndex === item.order ? COLOR_NAVY : this.progressBorderColor(item) })
          }
          .onClick(() => this.goQuestionAt(item.order))
        }, (item: AnswerProgressItem) => item.questionId)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .columnsGap(8)
      .rowsGap(8)
      .width('100%')
      .margin({ top: 10 })

      Text((this.question?.knowledgePoints || []).join(' / '))
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(20)
        .margin({ top: 18 })
        .width('100%')

      if (this.question?.wrong && this.question.wrong.mastered !== true) {
        Row() {
          Text('错题本')
            .fontSize(12)
            .fontColor(COLOR_ORANGE)
            .backgroundColor(COLOR_SOFT_ORANGE)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(8)
          Text(`已错 ${this.question.wrong.wrongCount} 次`)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 14 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  ProgressLegend(label: string, bgColor: string, borderColor: string) {
    Row() {
      Text('')
        .width(10)
        .height(10)
        .backgroundColor(bgColor)
        .borderRadius(3)
        .border({ width: 1, color: borderColor })
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .margin({ left: 5 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  StatusMetric(label: string, value: string, bgColor: string, textColor: string) {
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
  SubmitButton() {
    Button(this.feedback ? '已提交' : '提交答案')
      .width('100%')
      .height(46)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#ffffff')
      .enabled(!this.feedback)
      .backgroundColor(this.feedback ? '#aab3bd' : COLOR_GREEN)
      .borderRadius(8)
      .margin({ top: 16 })
      .onClick(() => this.submit())
  }

  @Builder
  QuestionCard() {
    Column() {
      Row() {
        Text(this.typeLabel(this.question?.type ?? 'single'))
          .fontSize(12)
          .fontColor(this.typeColor(this.question?.type ?? 'single'))
          .backgroundColor(this.typeSoftColor(this.question?.type ?? 'single'))
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(8)
        Text(this.question?.difficulty === 'hard' ? '困难' : this.question?.difficulty === 'medium' ? '中等' : '基础')
          .fontSize(12)
          .fontColor(COLOR_ORANGE)
          .backgroundColor(COLOR_SOFT_ORANGE)
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .borderRadius(8)
          .margin({ left: 8 })
      }
      .width('100%')

      Text(this.question?.title ?? '')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .lineHeight(28)
        .margin({ top: 14 })
        .width('100%')

      Text((this.question?.knowledgePoints || []).join(' / '))
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .lineHeight(19)
        .margin({ top: 12 })
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  AnswerArea() {
    if (this.question?.type === 'single' || this.question?.type === 'multiple') {
      Column() {
        Row() {
          Text('选择答案')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .layoutWeight(1)
          Text(this.question.type === 'multiple' ? '可多选' : '单选')
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .margin({ bottom: 4 })

        ForEach(this.question.options, (option: QuestionOption) => {
          Row() {
            Text(option.id.toUpperCase())
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .width(30)
              .height(30)
              .textAlign(TextAlign.Center)
              .fontColor(this.optionBadgeTextColor(option.id))
              .backgroundColor(this.optionBadgeBgColor(option.id))
              .borderRadius(8)
            Text(option.text)
              .fontSize(15)
              .fontColor(COLOR_TEXT)
              .lineHeight(21)
              .layoutWeight(1)
              .margin({ left: 12 })
          }
          .width('100%')
          .padding(12)
          .margin({ top: 10 })
          .backgroundColor(this.optionBgColor(option.id))
          .borderRadius(8)
          .border({ width: 1, color: this.optionBorderColor(option.id) })
          .onClick(() => this.toggleOption(option.id))
        }, (option: QuestionOption) => option.id)
      }
      .width('100%')
      .padding(16)
      .margin({ top: 14 })
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
    } else if (this.question?.type === 'boolean') {
      Column() {
        Text('判断题')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .width('100%')
        Row() {
          Button('正确')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(this.booleanBgColor(true))
            .fontColor(this.booleanTextColor(true))
            .borderRadius(8)
            .border({ width: 1, color: this.booleanBorderColor(true) })
            .margin({ right: 8 })
            .onClick(() => this.selectBoolean(true))
          Button('错误')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 8 })
            .backgroundColor(this.booleanBgColor(false))
            .fontColor(this.booleanTextColor(false))
            .borderRadius(8)
            .border({ width: 1, color: this.booleanBorderColor(false) })
            .onClick(() => this.selectBoolean(false))
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .margin({ top: 14 })
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
    } else {
      Column() {
        Text('简答思路')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .width('100%')
        TextArea({ placeholder: '输入你的作答思路，提交后对照参考答案和评分点自评。', text: this.shortAnswer })
          .height(160)
          .width('100%')
          .fontSize(14)
          .fontColor(COLOR_TEXT)
          .placeholderColor(COLOR_MUTED)
          .backgroundColor('#f8fafc')
          .borderRadius(8)
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.shortAnswer = value;
          })
      }
        .width('100%')
        .padding(16)
        .margin({ top: 14 })
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(8)
        .border({ width: 1, color: COLOR_LINE })
    }
  }

  @Builder
  FeedbackPanel() {
    Column() {
      if (this.feedback?.isCorrect === true) {
        Text('回答正确')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_GREEN)
      } else if (this.feedback?.isCorrect === false) {
        Text('回答错误')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_RED)
      } else {
        Text('参考答案')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_BLUE)
      }

      if (this.feedback?.correctOptionIds) {
        this.ResultLine('正确选项', this.feedback.correctOptionIds.join(', '))
      }
      if (this.feedback?.answerBoolean !== undefined) {
        this.ResultLine('正确答案', this.feedback.answerBoolean ? '正确' : '错误')
      }
      if (this.feedback?.referenceAnswer) {
        this.SectionText('参考答案', this.feedback.referenceAnswer)
      }
      if ((this.feedback?.scoringPoints?.length ?? 0) > 0) {
        this.SectionText('评分点', this.feedback?.scoringPoints?.join(' / ') ?? '')
      }

      this.SectionText('解析', this.feedback?.explanation ?? '')

      if (this.canMarkMastered()) {
        Button(this.masteringWrong ? '正在标记' : '标记已掌握')
          .width('100%')
          .height(42)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
          .enabled(!this.masteringWrong)
          .backgroundColor(this.masteringWrong ? '#aab3bd' : COLOR_GREEN)
          .borderRadius(8)
          .margin({ top: 14 })
          .onClick(() => this.markWrongMastered())
      }

      this.FeedbackActions()
    }
    .width('100%')
    .padding(16)
    .margin({ top: 16, bottom: 24 })
    .backgroundColor(this.feedbackBgColor())
    .borderRadius(8)
    .border({ width: 1, color: this.feedbackColor() })
  }

  @Builder
  FeedbackActions() {
    Row() {
      Button(this.feedbackPrimaryActionLabel())
        .layoutWeight(1)
        .height(42)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#ffffff')
        .backgroundColor(COLOR_NAVY)
        .borderRadius(8)
        .margin({ right: this.hasPrevious() ? 8 : 0 })
        .onClick(() => this.handleFeedbackPrimaryAction())

      if (this.hasPrevious()) {
        Button('上一题')
          .layoutWeight(1)
          .height(42)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .backgroundColor('#eef2f6')
          .borderRadius(8)
          .margin({ left: 8 })
          .onClick(() => this.goPreviousQuestion())
      }
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  ResultLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .width(76)
      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: 12 })
  }

  @Builder
  SectionText(label: string, value: string) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor(COLOR_MUTED)
        .width('100%')
      Text(value)
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .lineHeight(22)
        .margin({ top: 6 })
        .width('100%')
    }
    .width('100%')
    .margin({ top: 12 })
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

  typeColor(type: string): string {
    if (type === 'single') {
      return COLOR_GREEN;
    }
    if (type === 'multiple') {
      return COLOR_BLUE;
    }
    if (type === 'boolean') {
      return COLOR_ORANGE;
    }
    return COLOR_NAVY;
  }

  typeSoftColor(type: string): string {
    if (type === 'single') {
      return COLOR_SOFT_GREEN;
    }
    if (type === 'multiple') {
      return COLOR_SOFT_BLUE;
    }
    if (type === 'boolean') {
      return COLOR_SOFT_ORANGE;
    }
    return '#eef2f6';
  }

  optionBgColor(optionId: string): string {
    if (this.feedback) {
      if (this.isCorrectOption(optionId)) {
        return COLOR_SOFT_GREEN;
      }
      if (this.isSelectedOption(optionId)) {
        return COLOR_SOFT_RED;
      }
      return '#f8fafc';
    }
    return this.isSelectedOption(optionId) ? '#f1faf6' : '#f8fafc';
  }

  optionBorderColor(optionId: string): string {
    if (this.feedback) {
      if (this.isCorrectOption(optionId)) {
        return COLOR_GREEN;
      }
      if (this.isSelectedOption(optionId)) {
        return COLOR_RED;
      }
      return COLOR_LINE;
    }
    return this.isSelectedOption(optionId) ? COLOR_GREEN : COLOR_LINE;
  }

  optionBadgeBgColor(optionId: string): string {
    if (this.feedback) {
      if (this.isCorrectOption(optionId)) {
        return COLOR_GREEN;
      }
      if (this.isSelectedOption(optionId)) {
        return COLOR_RED;
      }
      return '#eef2f6';
    }
    return this.isSelectedOption(optionId) ? COLOR_GREEN : COLOR_SOFT_GREEN;
  }

  optionBadgeTextColor(optionId: string): string {
    if (this.feedback) {
      if (this.isCorrectOption(optionId) || this.isSelectedOption(optionId)) {
        return '#ffffff';
      }
      return COLOR_MUTED;
    }
    return this.isSelectedOption(optionId) ? '#ffffff' : COLOR_GREEN;
  }

  isSelectedOption(optionId: string): boolean {
    for (const id of this.selectedOptionIds) {
      if (id === optionId) {
        return true;
      }
    }
    return false;
  }

  isCorrectOption(optionId: string): boolean {
    for (const id of this.feedback?.correctOptionIds ?? []) {
      if (id === optionId) {
        return true;
      }
    }
    return false;
  }

  booleanBgColor(value: boolean): string {
    if (this.feedback && this.feedback.answerBoolean !== undefined) {
      if (this.feedback.answerBoolean === value) {
        return COLOR_GREEN;
      }
      if (this.answerBoolean === value) {
        return COLOR_RED;
      }
      return '#f8fafc';
    }
    return this.answerBoolean === value ? COLOR_GREEN : '#f8fafc';
  }

  booleanTextColor(value: boolean): string {
    if (this.feedback && this.feedback.answerBoolean !== undefined) {
      if (this.feedback.answerBoolean === value || this.answerBoolean === value) {
        return '#ffffff';
      }
      return COLOR_TEXT;
    }
    return this.answerBoolean === value ? '#ffffff' : COLOR_TEXT;
  }

  booleanBorderColor(value: boolean): string {
    if (this.feedback && this.feedback.answerBoolean !== undefined) {
      if (this.feedback.answerBoolean === value) {
        return COLOR_GREEN;
      }
      if (this.answerBoolean === value) {
        return COLOR_RED;
      }
      return COLOR_LINE;
    }
    return this.answerBoolean === value ? COLOR_GREEN : COLOR_LINE;
  }

  feedbackColor(): string {
    if (this.feedback?.isCorrect === false) {
      return COLOR_RED;
    }
    if (this.feedback?.isCorrect === true) {
      return COLOR_GREEN;
    }
    return COLOR_BLUE;
  }

  feedbackBgColor(): string {
    if (this.feedback?.isCorrect === false) {
      return COLOR_SOFT_RED;
    }
    if (this.feedback?.isCorrect === true) {
      return COLOR_SOFT_GREEN;
    }
    return COLOR_SOFT_BLUE;
  }

  canMarkMastered(): boolean {
    if (!this.question || !this.question.wrong || !this.feedback) {
      return false;
    }
    return this.feedback.isCorrect === true && this.question.wrong.mastered !== true;
  }

  pageMaxWidth(): number {
    return this.isTablet ? 1120 : 520;
  }

  parseQuestionIds(value: string | undefined, fallback: string): string[] {
    const ids: string[] = [];
    const rawItems = (value ?? '').split(',');
    for (const raw of rawItems) {
      const id = raw.trim();
      if (id.length > 0) {
        ids.push(id);
      }
    }
    if (ids.length === 0) {
      ids.push(fallback);
    }
    return ids;
  }

  createProgress(ids: string[]): AnswerProgressItem[] {
    const items: AnswerProgressItem[] = [];
    for (let index = 0; index < ids.length; index++) {
      const item: AnswerProgressItem = {
        questionId: ids[index],
        order: index,
        status: ANSWER_STATUS_UNANSWERED,
        isCorrect: null,
        selectedOptionIds: [],
        shortAnswer: ''
      };
      items.push(item);
    }
    return items;
  }

  findQuestionIndex(ids: string[], questionId: string): number {
    for (let index = 0; index < ids.length; index++) {
      if (ids[index] === questionId) {
        return index;
      }
    }
    return 0;
  }

  restoreAnswerState(questionId: string): void {
    const item = this.progressFor(questionId);
    if (item) {
      this.selectedOptionIds = this.copyStringArray(item.selectedOptionIds);
      this.answerBoolean = item.answerBoolean;
      this.shortAnswer = item.shortAnswer;
      this.feedback = item.feedback;
      return;
    }
    this.selectedOptionIds = [];
    this.answerBoolean = undefined;
    this.shortAnswer = '';
    this.feedback = undefined;
  }

  progressFor(questionId: string): AnswerProgressItem | undefined {
    for (const item of this.answerProgress) {
      if (item.questionId === questionId) {
        return item;
      }
    }
    return undefined;
  }

  copyStringArray(values: string[]): string[] {
    const copied: string[] = [];
    for (const value of values) {
      copied.push(value);
    }
    return copied;
  }

  progressSummary(): string {
    return `已答 ${this.answeredCount()}/${this.questionIds.length || 1}`;
  }

  headerProgressText(): string {
    return `第 ${this.currentIndex + 1}/${this.questionIds.length || 1} 题 · 已答 ${this.answeredCount()}`;
  }

  questionCardSummary(): string {
    return `${this.answeredCount()}/${this.questionIds.length || 1}`;
  }

  questionCardTitle(): string {
    if (this.showProgressPanel) {
      return '收起';
    }
    if (this.unansweredCount() === 0) {
      return '完成';
    }
    return '题卡';
  }

  questionCardStateMark(): string {
    if (this.showProgressPanel) {
      return '↑';
    }
    if (this.unansweredCount() === 0) {
      return '✓';
    }
    return String(this.unansweredCount());
  }

  questionCardToneColor(): string {
    if (this.unansweredCount() === 0) {
      return COLOR_GREEN;
    }
    return COLOR_BLUE;
  }

  favoriteButtonText(): string {
    return this.question?.isFavorite ? '取消收藏' : '加入收藏';
  }

  answeredCount(): number {
    let count = 0;
    for (const item of this.answerProgress) {
      if (item.status !== ANSWER_STATUS_UNANSWERED) {
        count++;
      }
    }
    return count;
  }

  correctCount(): number {
    let count = 0;
    for (const item of this.answerProgress) {
      if (item.status === ANSWER_STATUS_CORRECT) {
        count++;
      }
    }
    return count;
  }

  wrongCount(): number {
    let count = 0;
    for (const item of this.answerProgress) {
      if (item.status === ANSWER_STATUS_WRONG) {
        count++;
      }
    }
    return count;
  }

  unansweredCount(): number {
    let count = 0;
    for (const item of this.answerProgress) {
      if (item.status === ANSWER_STATUS_UNANSWERED) {
        count++;
      }
    }
    return count;
  }

  correctRateText(): string {
    const checkedCount = this.correctCount() + this.wrongCount();
    if (checkedCount === 0) {
      return '0%';
    }
    return `${Math.round(this.correctCount() * 100 / checkedCount)}%`;
  }

  completionSummaryText(): string {
    if (this.wrongCount() === 0 && this.unansweredCount() === 0) {
      return '这轮全部答对，可以继续保持节奏。';
    }
    if (this.wrongCount() > 0) {
      return '建议先复盘红色题号，再回到对应解析补齐薄弱点。';
    }
    return '还有未答题目，可以从下方题号继续补做。';
  }

  completionAdviceTitle(): string {
    if (this.unansweredCount() > 0) {
      return '先补齐未答题';
    }
    if (this.wrongCount() > 0) {
      return '优先复盘错题';
    }
    return '本轮状态很好';
  }

  completionAdviceText(): string {
    if (this.unansweredCount() > 0) {
      return `还有 ${this.unansweredCount()} 道未答题，建议先补完再看整体正确率。`;
    }
    if (this.wrongCount() > 0) {
      return `本轮有 ${this.wrongCount()} 道错题，可以点击红色题号回到解析页复盘。`;
    }
    return '可以返回题单继续下一组练习，或者回首页查看学习记录变化。';
  }

  completionToneColor(): string {
    if (this.wrongCount() === 0 && this.unansweredCount() === 0) {
      return COLOR_GREEN;
    }
    if (this.wrongCount() > 0) {
      return COLOR_NAVY;
    }
    return COLOR_BLUE;
  }

  progressTextColor(item: AnswerProgressItem): string {
    if (item.status === ANSWER_STATUS_CORRECT) {
      return COLOR_GREEN;
    }
    if (item.status === ANSWER_STATUS_WRONG) {
      return COLOR_RED;
    }
    if (item.status === ANSWER_STATUS_REVIEW) {
      return COLOR_BLUE;
    }
    return COLOR_MUTED;
  }

  progressBgColor(item: AnswerProgressItem): string {
    if (item.status === ANSWER_STATUS_CORRECT) {
      return COLOR_SOFT_GREEN;
    }
    if (item.status === ANSWER_STATUS_WRONG) {
      return COLOR_SOFT_RED;
    }
    if (item.status === ANSWER_STATUS_REVIEW) {
      return COLOR_SOFT_BLUE;
    }
    return '#f8fafc';
  }

  progressBorderColor(item: AnswerProgressItem): string {
    if (item.status === ANSWER_STATUS_CORRECT) {
      return COLOR_GREEN;
    }
    if (item.status === ANSWER_STATUS_WRONG) {
      return COLOR_RED;
    }
    if (item.status === ANSWER_STATUS_REVIEW) {
      return COLOR_BLUE;
    }
    return COLOR_LINE;
  }

  hasPrevious(): boolean {
    return this.currentIndex > 0;
  }

  hasNext(): boolean {
    return this.currentIndex < this.questionIds.length - 1;
  }

  goPreviousQuestion(): void {
    this.goQuestionAt(this.currentIndex - 1);
  }

  goNextQuestion(): void {
    this.goQuestionAt(this.currentIndex + 1);
  }

  goQuestionAt(index: number): void {
    if (index < 0 || index >= this.questionIds.length) {
      return;
    }
    this.autoMoveToken++;
    this.showCompletionSummary = false;
    this.showProgressPanel = false;
    this.currentIndex = index;
    this.loadQuestion(this.questionIds[index]);
  }

  goFirstByStatus(status: string): void {
    for (const item of this.answerProgress) {
      if (item.status === status) {
        this.goQuestionAt(item.order);
        return;
      }
    }
  }

  feedbackPrimaryActionLabel(): string {
    if (this.answeredCount() === this.questionIds.length) {
      return '查看本轮结果';
    }
    if (this.hasNext()) {
      return '下一题';
    }
    return '补做未答';
  }

  handleFeedbackPrimaryAction(): void {
    if (this.answeredCount() === this.questionIds.length) {
      this.showProgressPanel = false;
      this.showCompletionSummary = true;
      return;
    }
    if (this.hasNext()) {
      this.goNextQuestion();
      return;
    }
    this.goFirstByStatus(ANSWER_STATUS_UNANSWERED);
  }

  updateLayoutMode(): void {
    try {
      const currentDisplay = display.getDefaultDisplaySync();
      const density = currentDisplay.densityPixels > 0 ? currentDisplay.densityPixels : 1;
      const shortSideVp = Math.min(currentDisplay.width, currentDisplay.height) / density;
      this.isTablet = shortSideVp >= TABLET_MIN_VP;
    } catch (error) {
      this.isTablet = false;
    }
  }

  toggleOption(optionId: string) {
    if (!this.question || this.feedback) {
      return;
    }
    if (this.question.type === 'single') {
      this.selectedOptionIds = [optionId];
      return;
    }
    if (this.selectedOptionIds.includes(optionId)) {
      this.selectedOptionIds = this.selectedOptionIds.filter((id) => id !== optionId);
    } else {
      const next: string[] = [];
      for (const id of this.selectedOptionIds) {
        next.push(id);
      }
      next.push(optionId);
      this.selectedOptionIds = next;
    }
  }

  selectBoolean(value: boolean): void {
    if (this.feedback) {
      return;
    }
    this.answerBoolean = value;
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
      this.updateAnswerProgress(this.feedback);
      PracticeEvents.markStatsChanged();
      if (this.answeredCount() === this.questionIds.length) {
        this.scheduleCompletionSummary(this.feedback.questionId);
      } else {
        AppToast.show('已提交');
      }
    } catch (error) {
      AppToast.show(`提交失败：${String(error)}`);
    }
  }

  updateAnswerProgress(response: SubmitAnswerResponse): void {
    let status = ANSWER_STATUS_REVIEW;
    if (response.isCorrect === true) {
      status = ANSWER_STATUS_CORRECT;
    } else if (response.isCorrect === false) {
      status = ANSWER_STATUS_WRONG;
    }

    const next: AnswerProgressItem[] = [];
    for (const item of this.answerProgress) {
      if (item.questionId === response.questionId) {
        const updated: AnswerProgressItem = {
          questionId: item.questionId,
          order: item.order,
          status,
          isCorrect: response.isCorrect,
          selectedOptionIds: this.copyStringArray(this.selectedOptionIds),
          answerBoolean: this.answerBoolean,
          shortAnswer: this.shortAnswer,
          feedback: response
        };
        next.push(updated);
      } else {
        next.push(item);
      }
    }
    this.answerProgress = next;
  }

  scheduleAutoNext(questionId: string): void {
    if (!this.hasNext()) {
      this.scheduleCompletionSummary(questionId);
      return;
    }
    this.autoMoveToken++;
    const token = this.autoMoveToken;
    const message = this.feedback?.isCorrect === false ? '已记录，切到下一题' : '已提交，切到下一题';
    AppToast.show(message);
    setTimeout(() => {
      if (this.autoMoveToken === token && this.question?.id === questionId) {
        this.goNextQuestion();
      }
    }, 800);
  }

  scheduleCompletionSummary(questionId: string): void {
    this.autoMoveToken++;
    const token = this.autoMoveToken;
    AppToast.show('本轮已完成');
    setTimeout(() => {
      if (this.autoMoveToken === token && this.question?.id === questionId) {
        this.showProgressPanel = false;
        this.showCompletionSummary = true;
      }
    }, 700);
  }

  async toggleFavorite() {
    if (!this.question) {
      return;
    }
    try {
      if (this.question.isFavorite) {
        await store.removeFavorite(this.question.id);
        this.updateFavoriteState(false);
      } else {
        await store.addFavorite(this.question.id);
        this.updateFavoriteState(true);
      }
      PracticeEvents.markStatsChanged();
    } catch (error) {
      AppToast.show(`操作失败：${String(error)}`);
    }
  }

  async markWrongMastered() {
    if (!this.question || !this.question.wrong || this.masteringWrong) {
      return;
    }
    this.masteringWrong = true;
    try {
      await store.markWrongMastered(this.question.id);
      const current: Question = this.question;
      if (current.wrong) {
        current.wrong.mastered = true;
      }
      this.question = current;
      PracticeEvents.markStatsChanged();
      AppToast.show('已标记掌握');
    } catch (error) {
      AppToast.show(`操作失败：${String(error)}`);
    } finally {
      this.masteringWrong = false;
    }
  }

  private updateFavoriteState(isFavorite: boolean): void {
    if (!this.question) {
      return;
    }
    const current: Question = this.question;
    current.isFavorite = isFavorite;
    this.question = current;
  }
}
