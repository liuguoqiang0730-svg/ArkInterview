import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import display from '@ohos.display';
import { BottomNavBar } from '../components/BottomNavBar';
import { Question } from '../models/QuestionModels';
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
const TABLET_MIN_VP: number = 680;

@Entry
@Component
struct ReviewListPage {
  @State private mode: string = 'wrongs';
  @State private title: string = '错题本';
  @State private questions: Question[] = [];
  @State private loading: boolean = true;
  @State private isTablet: boolean = false;
  @State private keyword: string = '';
  @State private categoryFilter: string = 'all';
  @State private typeFilter: string = 'all';
  @State private wrongScope: string = 'active';
  @State private busyQuestionId: string = '';

  aboutToAppear(): void {
    this.updateLayoutMode();
    const params = router.getParams() as Record<string, string>;
    this.mode = params.mode || 'wrongs';
    this.title = params.title || (this.mode === 'favorites' ? '收藏题目' : '错题本');
    this.wrongScope = this.mode === 'wrongs' ? 'active' : 'all';
    this.loadQuestions();
  }

  async loadQuestions(): Promise<void> {
    this.loading = true;
    try {
      if (this.mode === 'favorites') {
        this.questions = await store.loadFavorites();
      } else {
        this.questions = await store.loadWrongs();
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
        this.Header()

        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(36)
              .height(36)
            Text('正在加载题目')
              .fontSize(14)
              .fontColor(COLOR_MUTED)
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              this.ToolPanel()
              this.QuestionList()
            }
            .width('100%')
            .padding(16)
            .constraintSize({ maxWidth: this.pageMaxWidth() })
            .alignSelf(ItemAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
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
  Header() {
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
        Button('刷新')
          .height(34)
          .fontSize(13)
          .fontColor(COLOR_GREEN)
          .backgroundColor(COLOR_SOFT_GREEN)
          .borderRadius(8)
          .onClick(() => this.loadQuestions())
      }
      .width('100%')

      Row() {
        this.Metric('全部', String(this.questions.length), COLOR_SOFT_BLUE, COLOR_BLUE)
        this.Metric('当前', String(this.filteredQuestions().length), COLOR_SOFT_GREEN, COLOR_GREEN)
        if (this.mode === 'wrongs') {
          this.Metric('未掌握', String(this.activeWrongCount()), COLOR_SOFT_ORANGE, COLOR_ORANGE)
        } else {
          this.Metric('可复习', String(this.questions.length), COLOR_SOFT_ORANGE, COLOR_ORANGE)
        }
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
  }

  @Builder
  ToolPanel() {
    Column() {
      TextInput({ placeholder: '搜索题干或知识点', text: this.keyword })
        .height(42)
        .width('100%')
        .fontSize(14)
        .fontColor(COLOR_TEXT)
        .placeholderColor(COLOR_MUTED)
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(8)
        .border({ width: 1, color: COLOR_LINE })
        .onChange((value: string) => {
          this.keyword = value;
        })

      Row() {
        this.FilterChip('模块', this.categoryFilterLabel(), COLOR_BLUE, COLOR_SOFT_BLUE, () => this.nextCategoryFilter())
        this.FilterChip('题型', this.typeFilterLabel(), COLOR_GREEN, COLOR_SOFT_GREEN, () => this.nextTypeFilter())
        if (this.mode === 'wrongs') {
          this.FilterChip('范围', this.wrongScopeLabel(), COLOR_ORANGE, COLOR_SOFT_ORANGE, () => this.nextWrongScope())
        }
      }
      .width('100%')
      .margin({ top: 10 })

      Button(this.filteredQuestions().length > 0 ? '按当前筛选复习' : '当前筛选无题')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.filteredQuestions().length > 0 ? '#ffffff' : COLOR_MUTED)
        .enabled(this.filteredQuestions().length > 0)
        .backgroundColor(this.filteredQuestions().length > 0 ? COLOR_GREEN : '#eef2f6')
        .borderRadius(8)
        .margin({ top: 12 })
        .onClick(() => this.openReviewAt(0))
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#f8fafc')
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  QuestionList() {
    Column() {
      if (this.filteredQuestions().length === 0) {
        Column() {
          Text(this.emptyTitle())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
          Text('可以调整搜索、模块、题型或错题范围。')
            .fontSize(13)
            .fontColor(COLOR_MUTED)
            .lineHeight(19)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(20)
        .margin({ top: 14 })
        .backgroundColor(COLOR_SURFACE)
        .borderRadius(8)
        .border({ width: 1, color: COLOR_LINE })
      } else {
        ForEach(this.filteredQuestions(), (question: Question, index: number) => {
          this.QuestionItem(question, index)
        }, (question: Question) => question.id)
      }
    }
    .width('100%')
  }

  @Builder
  QuestionItem(question: Question, index: number) {
    Column() {
      Row() {
        Text(this.typeLabel(question.type))
          .fontSize(12)
          .fontColor(this.typeColor(question.type))
          .backgroundColor(this.typeSoftColor(question.type))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
        Text(this.categoryName(question.categoryId))
          .fontSize(12)
          .fontColor(COLOR_BLUE)
          .backgroundColor(COLOR_SOFT_BLUE)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(8)
          .margin({ left: 6 })
        if (question.wrong && question.wrong.mastered === true) {
          Text('已掌握')
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
        .margin({ top: 10 })
        .width('100%')

      Text((question.knowledgePoints || []).join(' / '))
        .fontSize(12)
        .fontColor(COLOR_MUTED)
        .lineHeight(18)
        .margin({ top: 8 })
        .width('100%')

      Row() {
        Button('开始复习')
          .layoutWeight(1)
          .height(38)
          .fontSize(13)
          .fontColor('#ffffff')
          .backgroundColor(COLOR_GREEN)
          .borderRadius(8)
          .onClick(() => this.openReviewAt(index))
        if (this.mode === 'favorites') {
          Button(this.busyQuestionId === question.id ? '处理中' : '取消收藏')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .fontColor(COLOR_ORANGE)
            .enabled(this.busyQuestionId !== question.id)
            .backgroundColor(COLOR_SOFT_ORANGE)
            .borderRadius(8)
            .margin({ left: 10 })
            .onClick(() => this.removeFavorite(question.id))
        } else if (question.wrong && question.wrong.mastered !== true) {
          Button(this.busyQuestionId === question.id ? '处理中' : '标记掌握')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .fontColor(COLOR_BLUE)
            .enabled(this.busyQuestionId !== question.id)
            .backgroundColor(COLOR_SOFT_BLUE)
            .borderRadius(8)
            .margin({ left: 10 })
            .onClick(() => this.markMastered(question.id))
        }
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(14)
    .margin({ top: 12 })
    .backgroundColor(COLOR_SURFACE)
    .borderRadius(8)
    .border({ width: 1, color: COLOR_LINE })
  }

  @Builder
  Metric(label: string, value: string, bgColor: string, textColor: string) {
    Column() {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(textColor)
      Text(label)
        .fontSize(10)
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

  filteredQuestions(): Question[] {
    const result: Question[] = [];
    const keyword = this.keyword.trim().toLowerCase();
    for (const question of this.questions) {
      if (this.categoryFilter !== 'all' && question.categoryId !== this.categoryFilter) {
        continue;
      }
      if (this.typeFilter !== 'all' && question.type !== this.typeFilter) {
        continue;
      }
      if (this.mode === 'wrongs' && this.wrongScope === 'active' && question.wrong?.mastered === true) {
        continue;
      }
      if (keyword.length > 0 && !this.matchesKeyword(question, keyword)) {
        continue;
      }
      result.push(question);
    }
    return result;
  }

  matchesKeyword(question: Question, keyword: string): boolean {
    if (question.title.toLowerCase().includes(keyword)) {
      return true;
    }
    for (const item of question.knowledgePoints || []) {
      if (item.toLowerCase().includes(keyword)) {
        return true;
      }
    }
    return false;
  }

  activeWrongCount(): number {
    let count = 0;
    for (const question of this.questions) {
      if (question.wrong && question.wrong.mastered !== true) {
        count++;
      }
    }
    return count;
  }

  navActive(): string {
    return this.mode === 'favorites' ? 'favorites' : 'wrongs';
  }

  emptyTitle(): string {
    if (this.questions.length === 0) {
      return this.mode === 'favorites' ? '还没有收藏题目' : '还没有错题';
    }
    return '当前筛选下没有题目';
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

  wrongScopeLabel(): string {
    return this.wrongScope === 'all' ? '全部错题' : '未掌握';
  }

  nextCategoryFilter(): void {
    const ids = this.availableCategoryIds();
    if (ids.length === 0) {
      this.categoryFilter = 'all';
      return;
    }
    if (this.categoryFilter === 'all') {
      this.categoryFilter = ids[0];
      return;
    }
    for (let index = 0; index < ids.length; index++) {
      if (ids[index] === this.categoryFilter) {
        this.categoryFilter = index + 1 < ids.length ? ids[index + 1] : 'all';
        return;
      }
    }
    this.categoryFilter = 'all';
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
  }

  nextWrongScope(): void {
    this.wrongScope = this.wrongScope === 'active' ? 'all' : 'active';
  }

  availableCategoryIds(): string[] {
    const ids: string[] = [];
    for (const question of this.questions) {
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

  openReviewAt(index: number): void {
    const items = this.filteredQuestions();
    if (items.length === 0 || index < 0 || index >= items.length) {
      return;
    }
    const ids: string[] = [];
    for (const item of items) {
      ids.push(item.id);
    }
    router.pushUrl({
      url: 'pages/QuestionPage',
      params: {
        questionId: items[index].id,
        questionIds: ids.join(','),
        questionIndex: String(index),
        navActive: this.navActive()
      }
    });
  }

  async removeFavorite(questionId: string): Promise<void> {
    if (this.busyQuestionId.length > 0) {
      return;
    }
    this.busyQuestionId = questionId;
    try {
      await store.removeFavorite(questionId);
      this.removeQuestionFromList(questionId);
      promptAction.showToast({ message: '已取消收藏' });
    } catch (error) {
      promptAction.showToast({ message: `操作失败：${String(error)}` });
    } finally {
      this.busyQuestionId = '';
    }
  }

  async markMastered(questionId: string): Promise<void> {
    if (this.busyQuestionId.length > 0) {
      return;
    }
    this.busyQuestionId = questionId;
    try {
      await store.markWrongMastered(questionId);
      this.markQuestionMastered(questionId);
      promptAction.showToast({ message: '已标记掌握' });
    } catch (error) {
      promptAction.showToast({ message: `操作失败：${String(error)}` });
    } finally {
      this.busyQuestionId = '';
    }
  }

  removeQuestionFromList(questionId: string): void {
    const next: Question[] = [];
    for (const question of this.questions) {
      if (question.id !== questionId) {
        next.push(question);
      }
    }
    this.questions = next;
  }

  markQuestionMastered(questionId: string): void {
    const next: Question[] = [];
    for (const question of this.questions) {
      if (question.id === questionId && question.wrong) {
        question.wrong.mastered = true;
      }
      next.push(question);
    }
    this.questions = next;
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

  pageMaxWidth(): number {
    return this.isTablet ? 980 : 520;
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
