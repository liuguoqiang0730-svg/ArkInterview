import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { PracticeMode, PracticeSession, Question } from '../models/QuestionModels';
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
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct PracticePage {
  @State private title: string = '练习';
  @State private mode: string = 'random';
  @State private session: PracticeSession | undefined = undefined;
  @State private selectedQuestion: Question | undefined = undefined;
  @State private loading: boolean = true;
  @State private isTablet: boolean = false;

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.loadSession();
  }

  async loadSession() {
    const params = router.getParams() as Record<string, string>;
    const mode = params.mode || 'random';
    const categoryId = params.categoryId || undefined;
    this.mode = mode;
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
      if ((this.session?.items.length ?? 0) > 0) {
        this.selectedQuestion = this.session?.items[0];
      } else {
        this.selectedQuestion = undefined;
      }
    } catch (error) {
      promptAction.showToast({ message: `加载失败：${String(error)}` });
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Column() {
        Column() {
          Row() {
            Button('<')
              .width(38)
              .height(34)
              .fontColor(COLOR_NAVY)
              .backgroundColor('#eef2f6')
              .borderRadius(8)
              .onClick(() => router.back())
            Text(this.title)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_NAVY)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Button('换题')
              .height(34)
              .fontSize(13)
              .fontColor(COLOR_GREEN)
              .backgroundColor(COLOR_SOFT_GREEN)
              .borderRadius(8)
              .onClick(() => this.loadSession())
          }
          .width('100%')

          Row() {
            this.SummaryPill('题量', `${this.session?.total ?? 0}`)
            this.SummaryPill('模式', this.title)
            this.SummaryPill('状态', this.loading ? '加载中' : '可练习')
          }
          .width('100%')
          .margin({ top: 14 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 14 })
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(this.isTablet ? 8 : 0)
        .constraintSize({ maxWidth: this.pageMaxWidth() })
        .alignSelf(ItemAlign.Center)
        .margin({ top: this.isTablet ? 20 : 0 })

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
            Text('正在加载训练题目')
              .fontSize(14)
              .fontColor(COLOR_MUTED)
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if ((this.session?.items.length ?? 0) === 0) {
          Column() {
            Text('当前模式下还没有可练习题目')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_TEXT)
            Text('可以先切换到随机练习，或等待该模块题库补充。')
              .fontSize(13)
              .fontColor(COLOR_MUTED)
              .lineHeight(19)
              .textAlign(TextAlign.Center)
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(20)
          .margin({ left: 16, right: 16, top: 20 })
          .backgroundColor(COLOR_SURFACE)
          .borderRadius(8)
          .constraintSize({ maxWidth: this.pageMaxWidth() })
          .alignSelf(ItemAlign.Center)
        } else {
          if (this.isTablet) {
            this.TabletPracticeWorkspace()
          } else {
            this.QuestionList()
          }
        }
      }
      .layoutWeight(1)
      .width('100%')

      BottomNavBar({ active: this.navActive(), isTablet: this.isTablet })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  TabletPracticeWorkspace() {
    Row() {
      Column() {
        Row() {
          Text('题目列表')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_NAVY)
            .layoutWeight(1)
          Text(`${this.session?.items.length ?? 0} 题`)
            .fontSize(12)
            .fontColor(COLOR_MUTED)
        }
        .width('100%')
        .margin({ bottom: 10 })

        this.QuestionList()
      }
      .layoutWeight(5)
      .height('100%')
      .padding(16)
      .backgroundColor('#f8fafc')
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
      .margin({ right: 16 })

      this.QuestionPreview()
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 16, bottom: 18 })
    .constraintSize({ maxWidth: this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  QuestionList() {
    List() {
      ForEach(this.session?.items ?? [], (question: Question) => {
        ListItem() {
          this.QuestionListItem(question)
        }
        .padding({ left: this.isTablet ? 0 : 16, right: this.isTablet ? 0 : 16, bottom: 10 })
      }, (question: Question) => question.id)
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ top: this.isTablet ? 0 : 14 })
    .constraintSize({ maxWidth: this.isTablet ? 9999 : this.pageMaxWidth() })
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  QuestionListItem(question: Question) {
    Row() {
      Column() {
        Text(`${question.order ?? 0}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.typeColor(question.type))
        Text(this.typeLabel(question.type))
          .fontSize(10)
          .fontColor(COLOR_MUTED)
          .margin({ top: 4 })
      }
      .width(54)
      .height(54)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.typeSoftColor(question.type))
      .borderRadius(8)
      .margin({ right: 12 })

      Column() {
        Row() {
          Text(this.difficultyLabel(question.difficulty))
            .fontSize(12)
            .fontColor(this.typeColor(question.type))
            .backgroundColor(this.typeSoftColor(question.type))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
          if (question.isFavorite) {
            Text('已收藏')
              .fontSize(12)
              .fontColor(COLOR_ORANGE)
              .backgroundColor(COLOR_SOFT_ORANGE)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .borderRadius(8)
              .margin({ left: 6 })
          }
        }
        .width('100%')

        Text(question.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .lineHeight(22)
          .margin({ top: 9 })
          .width('100%')

        Text((question.knowledgePoints || []).join(' / '))
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 8 })
          .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isSelectedQuestion(question) ? '#f1faf6' : COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: this.isSelectedQuestion(question) ? COLOR_GREEN : COLOR_LINE })
    .onClick(() => this.handleQuestionTap(question))
  }

  @Builder
  QuestionPreview() {
    Column() {
      if (this.selectedQuestion) {
        Row() {
          Text(this.typeLabel(this.selectedQuestion.type))
            .fontSize(12)
            .fontColor(this.typeColor(this.selectedQuestion.type))
            .backgroundColor(this.typeSoftColor(this.selectedQuestion.type))
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(8)
          Text(this.difficultyLabel(this.selectedQuestion.difficulty))
            .fontSize(12)
            .fontColor(COLOR_ORANGE)
            .backgroundColor(COLOR_SOFT_ORANGE)
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .borderRadius(8)
            .margin({ left: 8 })
        }
        .width('100%')

        Text(this.selectedQuestion.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
          .lineHeight(30)
          .margin({ top: 18 })
          .width('100%')

        Text((this.selectedQuestion.knowledgePoints || []).join(' / '))
          .fontSize(13)
          .fontColor(COLOR_MUTED)
          .lineHeight(20)
          .margin({ top: 12 })
          .width('100%')

        Button('开始答题')
          .width('100%')
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
          .backgroundColor(COLOR_GREEN)
          .borderRadius(8)
          .margin({ top: 24 })
          .onClick(() => this.openSelectedQuestion())
      } else {
        Text('请选择一道题目')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
      }
    }
    .layoutWeight(4)
    .height('100%')
    .padding(18)
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  SummaryPill(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(COLOR_TEXT)
        .maxLines(1)
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_MUTED)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .margin({ left: 3, right: 3 })
    .backgroundColor('#f6f8fb')
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
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

  difficultyLabel(difficulty: string): string {
    if (difficulty === 'hard') {
      return '困难';
    }
    if (difficulty === 'medium') {
      return '中等';
    }
    return '基础';
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

  pageMaxWidth(): number {
    return this.isTablet ? 1120 : 520;
  }

  navActive(): string {
    if (this.mode === 'wrongs' || this.mode === 'favorites') {
      return this.mode;
    }
    return '';
  }

  isSelectedQuestion(question: Question): boolean {
    return this.isTablet && this.selectedQuestion?.id === question.id;
  }

  handleQuestionTap(question: Question): void {
    if (this.isTablet) {
      this.selectedQuestion = question;
      return;
    }
    this.openQuestion(question);
  }

  openSelectedQuestion(): void {
    if (!this.selectedQuestion) {
      return;
    }
    this.openQuestion(this.selectedQuestion);
  }

  openQuestion(question: Question): void {
    router.pushUrl({
      url: 'pages/QuestionPage',
      params: { questionId: question.id }
    });
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
}
