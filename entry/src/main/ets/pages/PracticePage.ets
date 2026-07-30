import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { PracticeMode, PracticeSession, Question } from '../models/QuestionModels';
import { AppRouter } from '../utils/AppRouter';
import { AppToast } from '../utils/AppToast';
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
const COLOR_SHADOW: string = '#1f2a3714';
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
  @State private categoryFilter: string = 'all';
  @State private typeFilter: string = 'all';
  @State private wrongScope: string = 'active';

  aboutToAppear(): void {
    this.updateLayoutMode();
    this.loadSession();
  }

  async loadSession() {
    const params = AppRouter.params(this.getUIContext());
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
        this.resetFilters();
        this.selectedQuestion = this.filteredQuestions()[0];
      } else {
        this.selectedQuestion = undefined;
      }
    } catch (error) {
      AppToast.show(this.getUIContext(), `加载失败：${String(error)}`);
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
              .onClick(() => AppRouter.back(this.getUIContext()))
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
        .shadow({ radius: 16, color: COLOR_SHADOW, offsetX: 0, offsetY: 8 })

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
            Button('返回首页')
              .height(38)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#ffffff')
              .backgroundColor(COLOR_GREEN)
              .borderRadius(8)
              .margin({ top: 16 })
              .onClick(() => AppRouter.push(this.getUIContext(), 'pages/HomePage'))
          }
          .width('100%')
          .padding(20)
          .margin({ left: 16, right: 16, top: 20 })
          .backgroundColor(COLOR_SURFACE)
          .borderRadius(8)
          .border({ width: 1, color: COLOR_LINE })
          .constraintSize({ maxWidth: this.pageMaxWidth() })
          .alignSelf(ItemAlign.Center)
          .shadow({ radius: 14, color: COLOR_SHADOW, offsetX: 0, offsetY: 7 })
        } else {
          if (this.isTablet) {
            this.TabletPracticeWorkspace()
          } else {
            this.FilterBar()
            this.QuestionList()
          }
        }
      }
      .layoutWeight(1)
      .width('100%')

      BottomNavBar({ active: 'practice', isTablet: this.isTablet })
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

        this.FilterBar()
        this.QuestionList()
      }
      .layoutWeight(1)
      .height('100%')
      .padding(16)
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
      .margin({ right: 0 })
      .shadow({ radius: 16, color: COLOR_SHADOW, offsetX: 0, offsetY: 8 })
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
    if (this.filteredQuestions().length === 0) {
      Column() {
        Text('当前筛选下没有题目')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text('可以切换模块、题型或错题范围继续复习。')
          .fontSize(12)
          .fontColor(COLOR_MUTED)
          .lineHeight(18)
          .margin({ top: 6 })
        Button('清空筛选')
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#ffffff')
          .backgroundColor(COLOR_GREEN)
          .borderRadius(8)
          .margin({ top: 14 })
          .onClick(() => this.resetFilters())
      }
      .width('100%')
      .padding(18)
      .backgroundColor(COLOR_SURFACE)
      .borderRadius(8)
      .border({ width: 1, color: COLOR_LINE })
      .shadow({ radius: 10, color: COLOR_SHADOW, offsetX: 0, offsetY: 5 })
    } else {
      List() {
        ForEach(this.filteredQuestions(), (question: Question) => {
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
  }

  @Builder
  FilterBar() {
    Column() {
      Row() {
        Text('筛选工具')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_NAVY)
          .layoutWeight(1)
        Text(`显示 ${this.filteredQuestions().length}/${this.session?.items.length ?? 0}`)
          .fontSize(12)
          .fontColor(COLOR_MUTED)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        this.FilterChip('模块', this.categoryFilterLabel(), COLOR_BLUE, COLOR_SOFT_BLUE, () => this.nextCategoryFilter())
        this.FilterChip('题型', this.typeFilterLabel(), COLOR_GREEN, COLOR_SOFT_GREEN, () => this.nextTypeFilter())
        if (this.mode === 'wrongs') {
          this.FilterChip('范围', this.wrongScopeLabel(), COLOR_ORANGE, COLOR_SOFT_ORANGE, () => this.nextWrongScope())
        }
      }
      .width('100%')

      Text(this.filterSummaryText())
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .margin({ top: 8 })
        .width('100%')

      if (this.hasActiveFilters()) {
        Row() {
          Text(this.activeFilterText())
            .fontSize(12)
            .fontColor(COLOR_BLUE)
            .layoutWeight(1)
          Button('清空')
            .height(30)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_GREEN)
            .backgroundColor(COLOR_SOFT_GREEN)
            .borderRadius(8)
            .onClick(() => this.resetFilters())
        }
        .width('100%')
        .padding({ left: 10, right: 8, top: 8, bottom: 8 })
        .margin({ top: 10 })
        .backgroundColor(COLOR_SOFT_BLUE)
        .borderRadius(8)
        .border({ width: 1, color: COLOR_BLUE })
      }
    }
    .width('100%')
    .padding({ left: this.isTablet ? 0 : 16, right: this.isTablet ? 0 : 16, top: this.isTablet ? 0 : 12, bottom: 12 })
  }

  @Builder
  FilterChip(label: string, value: string, color: string, bgColor: string, action: () => void) {
    Column() {
      Text(label)
        .fontSize(10)
        .fontColor(COLOR_MUTED)
      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .maxLines(1)
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 8, right: 8 })
    .margin({ left: 3, right: 3 })
    .backgroundColor(bgColor)
    .borderRadius(8)
    .border({ width: 1, color: color })
    .onClick(action)
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
          if (this.isSelectedQuestion(question)) {
            Text('当前预览')
              .fontSize(12)
              .fontColor(COLOR_GREEN)
              .backgroundColor(COLOR_SOFT_GREEN)
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

        Row() {
          Text(this.categoryName(question.categoryId))
            .fontSize(12)
            .fontColor(COLOR_BLUE)
            .backgroundColor(COLOR_SOFT_BLUE)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
          Text(this.questionListActionText(question))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.typeColor(question.type))
            .layoutWeight(1)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isSelectedQuestion(question) ? '#f1faf6' : COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: this.isSelectedQuestion(question) ? COLOR_GREEN : COLOR_LINE })
    .shadow({ radius: 10, color: COLOR_SHADOW, offsetX: 0, offsetY: 5 })
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

  questionListActionText(question: Question): string {
    if (this.isTablet) {
      return this.isSelectedQuestion(question) ? '开始答题 >' : '查看预览 >';
    }
    return '去答题 >';
  }

  pageMaxWidth(): number {
    return this.isTablet ? 1120 : 520;
  }

  resetFilters(): void {
    this.categoryFilter = 'all';
    this.typeFilter = 'all';
    this.wrongScope = this.mode === 'wrongs' ? 'active' : 'all';
  }

  filteredQuestions(): Question[] {
    const result: Question[] = [];
    for (const question of this.session?.items ?? []) {
      if (this.categoryFilter !== 'all' && question.categoryId !== this.categoryFilter) {
        continue;
      }
      if (this.typeFilter !== 'all' && question.type !== this.typeFilter) {
        continue;
      }
      if (this.mode === 'wrongs' && this.wrongScope === 'active' && question.wrong?.mastered === true) {
        continue;
      }
      result.push(question);
    }
    return result;
  }

  availableCategoryIds(): string[] {
    const ids: string[] = [];
    for (const question of this.session?.items ?? []) {
      if (!this.containsString(ids, question.categoryId)) {
        ids.push(question.categoryId);
      }
    }
    return ids;
  }

  containsString(items: string[], value: string): boolean {
    for (const item of items) {
      if (item === value) {
        return true;
      }
    }
    return false;
  }

  categoryFilterLabel(): string {
    if (this.categoryFilter === 'all') {
      return '全部模块';
    }
    return this.categoryName(this.categoryFilter);
  }

  typeFilterLabel(): string {
    if (this.typeFilter === 'single') {
      return '单选';
    }
    if (this.typeFilter === 'multiple') {
      return '多选';
    }
    if (this.typeFilter === 'boolean') {
      return '判断';
    }
    if (this.typeFilter === 'short') {
      return '简答';
    }
    return '全部题型';
  }

  filterSummaryText(): string {
    if (this.filteredQuestions().length === 0) {
      return '当前筛选没有题目，可以切换模块或题型。';
    }
    if (this.mode === 'wrongs') {
      return '优先处理未掌握题目，答对后可在解析中标记掌握。';
    }
    if (this.mode === 'favorites') {
      return '集中复习收藏题目，适合考前快速回看。';
    }
    if (this.mode === 'interview') {
      return '按面试节奏抽题，建议完整完成一轮后再复盘。';
    }
    return '选择题目开始练习，答题后会自动记录进度。';
  }

  hasActiveFilters(): boolean {
    if (this.categoryFilter !== 'all') {
      return true;
    }
    if (this.typeFilter !== 'all') {
      return true;
    }
    return this.mode === 'wrongs' && this.wrongScope !== 'active';
  }

  activeFilterText(): string {
    let count = 0;
    if (this.categoryFilter !== 'all') {
      count++;
    }
    if (this.typeFilter !== 'all') {
      count++;
    }
    if (this.mode === 'wrongs' && this.wrongScope !== 'active') {
      count++;
    }
    return `已启用 ${count} 个筛选条件`;
  }

  wrongScopeLabel(): string {
    return this.wrongScope === 'all' ? '全部错题' : '未掌握';
  }

  nextCategoryFilter(): void {
    const ids = this.availableCategoryIds();
    if (ids.length === 0) {
      this.categoryFilter = 'all';
      this.syncSelectedQuestion();
      return;
    }
    if (this.categoryFilter === 'all') {
      this.categoryFilter = ids[0];
      this.syncSelectedQuestion();
      return;
    }
    for (let index = 0; index < ids.length; index++) {
      if (ids[index] === this.categoryFilter) {
        if (index + 1 < ids.length) {
          this.categoryFilter = ids[index + 1];
        } else {
          this.categoryFilter = 'all';
        }
        this.syncSelectedQuestion();
        return;
      }
    }
    this.categoryFilter = 'all';
    this.syncSelectedQuestion();
  }

  nextTypeFilter(): void {
    if (this.typeFilter === 'all') {
      this.typeFilter = 'single';
    } else if (this.typeFilter === 'single') {
      this.typeFilter = 'multiple';
    } else if (this.typeFilter === 'multiple') {
      this.typeFilter = 'boolean';
    } else if (this.typeFilter === 'boolean') {
      this.typeFilter = 'short';
    } else {
      this.typeFilter = 'all';
    }
    this.syncSelectedQuestion();
  }

  nextWrongScope(): void {
    this.wrongScope = this.wrongScope === 'active' ? 'all' : 'active';
    this.syncSelectedQuestion();
  }

  syncSelectedQuestion(): void {
    const questions = this.filteredQuestions();
    if (questions.length === 0) {
      this.selectedQuestion = undefined;
      return;
    }
    if (!this.selectedQuestion) {
      this.selectedQuestion = questions[0];
      return;
    }
    for (const question of questions) {
      if (question.id === this.selectedQuestion.id) {
        return;
      }
    }
    this.selectedQuestion = questions[0];
  }

  categoryName(categoryId: string): string {
    if (categoryId === 'arkts') {
      return 'ArkTS';
    }
    if (categoryId === 'arkui') {
      return 'ArkUI';
    }
    if (categoryId === 'stage-model') {
      return 'Stage';
    }
    if (categoryId === 'ability-lifecycle') {
      return 'Ability';
    }
    if (categoryId === 'component-communication') {
      return '组件通信';
    }
    if (categoryId === 'state-management') {
      return '状态管理';
    }
    if (categoryId === 'routing') {
      return '路由';
    }
    if (categoryId === 'network') {
      return '网络';
    }
    if (categoryId === 'permissions') {
      return '权限';
    }
    if (categoryId === 'storage') {
      return '数据存储';
    }
    if (categoryId === 'preferences') {
      return 'Preferences';
    }
    if (categoryId === 'relational-store') {
      return '关系库';
    }
    if (categoryId === 'napi') {
      return 'NAPI';
    }
    if (categoryId === 'performance') {
      return '性能';
    }
    if (categoryId === 'debug-release') {
      return '调试发布';
    }
    if (categoryId === 'next-adaptation') {
      return 'NEXT';
    }
    return categoryId;
  }

  isSelectedQuestion(question: Question): boolean {
    return this.isTablet && this.selectedQuestion?.id === question.id;
  }

  handleQuestionTap(question: Question): void {
    this.openQuestion(question);
  }

  openSelectedQuestion(): void {
    if (!this.selectedQuestion) {
      return;
    }
    this.openQuestion(this.selectedQuestion);
  }

  openQuestion(question: Question): void {
    AppRouter.push(this.getUIContext(), 'pages/QuestionPage', {
      questionId: question.id,
      questionIds: this.sessionQuestionIds(),
      questionIndex: String(this.questionIndex(question))
    });
  }

  sessionQuestionIds(): string {
    const ids: string[] = [];
    for (const item of this.filteredQuestions()) {
      ids.push(item.id);
    }
    return ids.join(',');
  }

  questionIndex(question: Question): number {
    const items: Question[] = this.filteredQuestions();
    for (let index = 0; index < items.length; index++) {
      if (items[index].id === question.id) {
        return index;
      }
    }
    return 0;
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
