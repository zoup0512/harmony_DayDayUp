// 学习主页 + 课本选择/详情 + 单元知识手册 + 跳级测试（Home / BookList / BookDetail / UnitGuide / JumpTest）。
import { C, F, R, S, W, alpha, unitColors } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { Chest, pathLessonMetas, priorLessonMetas } from '../domain/Catalog';
import { Jump, JumpQuestionSource, JumpSampledQuestion } from '../domain/Seeded';
import { Book, KnowledgePoint, Outline, PathLessonMeta, Question, SubjectId, Unit } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { DataLoader } from '../services/DataLoader';
import { Files } from '../services/Files';
import { AssetDownloader } from '../services/AssetDownloader';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { CardBox, ChunkyButton, DuoIcon, IconBadge, Pill, ProgressBar, TitleBar } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { ChestModal } from '../components/Effects';
import {
  BottomTabBar, BookDownloadCard, DailyGoalRing, DailyQuestsCard, StreakCalendar, weekCalendar
} from '../components/Widgets';
import { buildPathNodes, PathMap, PathMapNode } from '../components/PathMap';
import { AppRoute, RouteName, Router } from './Router';
import { QuestionPhase, QuestionRenderer } from './Questions';
import { gradeAnswer } from '../domain/Grade';
import { renderMathText } from '../domain/MathText';

function subjectIcon(s: SubjectId | null | undefined): string {
  return s === 'math' ? 'chart' : (s === 'english' ? 'books' : (s === 'science' ? 'sparkles' : 'book'));
}

function subjectColor(s: SubjectId | null | undefined): string {
  return s === 'math' ? C.secondary : (s === 'english' ? C.beetle : (s === 'science' ? '#00CD9C' : C.primary));
}

const GRADE_NAMES: string[] = ['全部', '一年级', '二年级', '三年级', '四年级', '五年级', '六年级'];

export function allBooks(): Book[] {
  try {
    return DataLoader.loadSiteIndex().books.slice().sort((a: Book, b: Book) =>
      a.grade - b.grade || a.semester.localeCompare(b.semester) || a.id.localeCompare(b.id));
  } catch (e) {
    return [];
  }
}

export function activeBook(store: ProgressStore): Book | null {
  const books = allBooks();
  if (books.length === 0) {
    return null;
  }
  if (store.activeBookId !== null) {
    const found = books.find((b: Book) => b.id === store.activeBookId);
    if (found !== undefined) {
      return found;
    }
  }
  const graded = books.filter((b: Book) => b.grade === store.selectedGrade);
  const installed = graded.filter((b: Book) => bookInstalled(b.id));
  return (installed.length > 0 ? installed : (graded.length > 0 ? graded : books))[0];
}

export function bookInstalled(bookId: string): boolean {
  return Files.exists(`${DataLoader.bookDir(bookId)}/outline.json`);
}

export function allGrades(books: Book[]): number[] {
  const set = new Set<number>();
  books.forEach((b: Book) => set.add(b.grade));
  const out = [0];
  Array.from(set).sort((a: number, b: number) => a - b).forEach((g: number) => out.push(g));
  return out;
}

function gradeLabel(g: number): string {
  return g >= 0 && g < GRADE_NAMES.length ? GRADE_NAMES[g] : `${g}年级`;
}

/** 学习 Tab：顶部状态条 + 课本/路径地图。 */
@ComponentV2
export struct LearnHome {
  @Local store: ProgressStore = ProgressStore.shared;
  dl: AssetDownloader = AssetDownloader.shared;
  @Local nodes: PathMapNode[] = [];
  @Local book: Book | null = null;
  @Local outlineData: Outline | null = null;
  @Local chestId: string = '';
  @Local showSwitch: boolean = false;
  @Local mStreak: number = 0;
  @Local mGems: number = 0;
  @Local mHearts: number = 0;
  @Local mDone: number = 0;
  @Local mRev: number = 0;

  private rebuild(): void {
    this.mStreak = this.store.displayStreak;
    this.mGems = this.store.gems;
    this.mHearts = this.store.hearts;
    this.mDone = this.store.totalCompletedLessons;
    this.mRev++;
    const b = activeBook(this.store);
    this.book = b;
    if (b === null) {
      this.nodes = [];
      return;
    }
    this.outlineData = DataLoader.tryOutline(b.id);
    if (this.outlineData === null) {
      this.nodes = [];
      return;
    }
    const o = this.outlineData;
    this.nodes = buildPathNodes(b.id, pathLessonMetas(o, b.id, (id: string) =>
      DataLoader.tryLesson(b.id, id)?.questions.length ?? 0), this.store, DataLoader.examSlots(o, b.id));
  }

  aboutToAppear(): void {
    this.store.onChange(() => {
      this.rebuild();
    });
    this.rebuild();
  }

  @Monitor('store.progress', 'store.activeBookId', 'store.selectedGrade')
  onProgress(): void {
    this.rebuild();
  }

  @Builder
  topBar() {
    Row({ space: 8 }) {
      Stack() {
        DuoIcon({ name: 'flame', sz: 24, color: this.mStreak > 0 ? C.fox : C.inkSofter })
        Text(`${this.mStreak}`).fontSize(F.micro).fontWeight(W.heavy).fontColor('#FFFFFF').translate({ y: 4 })
      }
      .width(30)
      .height(30)

      Row({ space: 4 }) {
        DuoIcon({ name: 'gem', sz: 17, color: C.beetle })
        Text(`${this.mGems}`).fontSize(F.body).fontWeight(W.heavy).fontColor(C.beetle)
      }

      Row({ space: 4 }) {
        DuoIcon({ name: 'heart', sz: 17, color: this.mHearts > 0 ? C.danger : C.inkSofter })
        Text(`${this.mHearts}`).fontSize(F.body).fontWeight(W.heavy)
          .fontColor(this.mHearts > 0 ? C.danger : C.inkSofter)
      }

      Blank()
      ForEach([this.mRev], (r: number) => {
        DailyGoalRing({ sz: 44 })
      }, (r: number) => `${r}`)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 6 })
    .backgroundColor(C.bg)
  }

  @Builder
  bookHeader() {
    if (this.book !== null) {
      Row({ space: 10 }) {
        Row({ space: 10 }) {
          IconBadge(subjectIcon(this.book?.subject), subjectColor(this.book?.subject), 44, 22)
          Column({ space: 1 }) {
            Text(this.book?.fullName ?? '').fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.mDone} 课已完成`).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .onClick(() => {
          Router.shared.push(AppRoute.book('bookDetail', this.book?.id ?? ''));
        })

        Text('换课本').fontSize(F.caption).fontWeight(W.bold).fontColor(C.secondary)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(alpha(C.secondary, 0.12))
          .borderRadius(999)
          .onClick(() => {
            this.showSwitch = true;
          })
          .bindSheet(this.showSwitch, this.bookPicker(), {
            height: SheetSize.LARGE, dragBar: true, backgroundColor: C.bg, onDisappear: () => {
              this.showSwitch = false;
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })
    }
  }

  @Builder
  bookPicker() {
    Column() {
      TitleBar({ title: '选择课本', showBack: false })
      BookListBody({ inSheet: true, onPicked: () => {
        this.showSwitch = false;
      } })
    }
  }

  build() {
    Stack() {
      Column() {
      this.topBar()
      this.bookHeader()
      if (this.book === null) {
        Column({ space: 16 }) {
          Mascot({ mood: 'wave', sz: 140 })
          Text('挑一本课本开始学习吧').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
          ChunkyButton({ label: '选择课本', onTap: () => {
            this.showSwitch = true;
          } }).width(220)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.nodes.length === 0) {
        Column({ space: 16 }) {
          BookDownloadCard({ bookId: this.book?.id ?? '', onComplete: () => this.rebuild() })
            .padding({ left: 20, right: 20 })
        }
        .layoutWeight(1)
      } else {
        PathMap({
          lessons: this.nodes, bookKey: `${this.book?.id}-${this.mDone}`,
          onTapNode: (n: PathMapNode) => {
            if (n.kind === 'chest') {
              this.chestId = n.id;
            } else if (n.status !== 'locked') {
              Router.shared.push(AppRoute.lesson(this.book?.id ?? '', n.id));
            }
          },
          onGuideTap: (u: number) => {
            Router.shared.push(AppRoute.unit('guide', this.book?.id ?? '', u));
          },
          onJumpTap: (u: number) => {
            Router.shared.push(AppRoute.unit('jumpTest', this.book?.id ?? '', u));
          }
        }).layoutWeight(1)
      }
      ForEach([this.mRev], (r: number) => {
        DailyQuestsCard().margin({ left: 16, right: 16, bottom: 8 })
      }, (r: number) => `${r}`)
    }
      .width('100%')
      .height('100%')

      if (this.chestId.length > 0) {
        ChestModal({
          onClaim: (g: number) => {
            this.store.claimChest(this.chestId);
            this.store.addGems(g);
          },
          onDismiss: () => {
            this.chestId = '';
            this.rebuild();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 课本列表（也可放进 sheet 里当切换器）。 */
@ComponentV2
export struct BookListBody {
  @Param inSheet: boolean = false;
  @Event onPicked: () => void = () => {
  };
  store: ProgressStore = ProgressStore.shared;
  dl: AssetDownloader = AssetDownloader.shared;
  @Local grade: number = 0;

  aboutToAppear(): void {
    this.grade = this.store.selectedGrade;
  }

  private books(): Book[] {
    const all = allBooks();
    return this.grade === 0 ? all : all.filter((b: Book) => b.grade === this.grade);
  }

  private pick(b: Book): void {
    Haptics.tap();
    SFXEngine.shared.play('tap');
    this.store.setActiveBook(b.id);
    if (!this.inSheet) {
      Router.shared.push(AppRoute.book('bookDetail', b.id));
    } else {
      this.onPicked();
    }
  }

  @Builder
  bookRow(b: Book) {
    Row({ space: 12 }) {
      IconBadge(subjectIcon(b.subject), subjectColor(b.subject), 46, 22)
      Column({ space: 3 }) {
        Text(b.fullName).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink).maxLines(2)
        Row({ space: 6 }) {
          Pill(`${b.unitsCount} 单元 · ${b.lessonsCount} 课`, C.inkMuted, C.surfaceAlt)
          if (this.store.activeBookId === b.id) {
            Pill('学习中', '#FFFFFF', C.primary)
          } else if (!bookInstalled(b.id)) {
            Pill('待下载', C.secondary, alpha(C.secondary, 0.12))
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: this.store.activeBookId === b.id ? C.primary : C.border, radius: R.card })
    .onClick(() => this.pick(b))
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Scroll() {
            Row({ space: 8 }) {
              ForEach(allGrades(allBooks()), (g: number) => {
                Text(gradeLabel(g))
                  .fontSize(F.caption)
                  .fontWeight(W.bold)
                  .fontColor(this.grade === g ? '#FFFFFF' : C.ink)
                  .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .backgroundColor(this.grade === g ? C.primary : C.surfaceAlt)
                  .borderRadius(999)
                  .onClick(() => {
                    Haptics.tap();
                    this.grade = g;
                    this.store.setSelectedGrade(g);
                  })
              }, (g: number) => `${g}`)
            }
            .padding({ left: 16, top: 12, bottom: 4 })
          }
          .scrollBar(BarState.Off)
          .align(Alignment.Start)

          ForEach(this.books(), (b: Book) => {
            this.bookRow(b)
          }, (b: Book) => `${b.id}-${this.store.activeBookId}`)

          Blank().height(30)
        }
        .padding({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .layoutWeight(1)
  }
}

@ComponentV2
export struct BookListPage {
  build() {
    Column() {
      TitleBar({ title: '选择课本', onBack: () => Router.shared.pop() })
      BookListBody()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 课本详情（BookDetailView）：单元列表 + 故事/阅读入口 + 开始按钮。 */
@ComponentV2
export struct BookDetailPage {
  @Param route: AppRoute = new AppRoute('bookDetail');
  store: ProgressStore = ProgressStore.shared;
  dl: AssetDownloader = AssetDownloader.shared;

  private book(): Book | undefined {
    return allBooks().find((b: Book) => b.id === this.route.bookId);
  }

  private outlineData(): Outline | null {
    return DataLoader.tryOutline(this.route.bookId);
  }

  @Builder
  unitRow(unitNo: number, title: string, kpCount: number) {
    Row({ space: 12 }) {
      Stack() {
        Circle().width(40).height(40).fill(alpha(unitColors(unitNo)[0], 0.16))
        Text(`${unitNo}`).fontSize(F.subhead).fontWeight(W.heavy).fontColor(unitColors(unitNo)[0])
      }
      Column({ space: 2 }) {
        Text(title).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        Text(`${kpCount} 个知识点`).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .width('100%')
    .backgroundColor(C.surfaceAlt)
    .borderRadius(R.card)
  }

  build() {
    Column() {
      TitleBar({
        title: this.book()?.fullName ?? '', onBack: () => Router.shared.pop(), trailing: (): void => {
          this.trail();
        }
      })
      Scroll() {
        Column({ space: 14 }) {
          if (this.outlineData() === null) {
            BookDownloadCard({ bookId: this.route.bookId })
          } else {
            Text('单元').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            ForEach(this.outlineData()?.units ?? [], (u: Unit) => {
              this.unitRow(u.unit_number, u.title, u.knowledge_points.length)
            }, (u: Unit) => `${u.unit_number}`)
            if ((this.book()?.hasPassages ?? false) || (this.book()?.hasStories ?? false)) {
              Text('延伸阅读').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
                .margin({ top: 4 })
              if (this.book()?.hasPassages ?? false) {
                this.linkRow('textAlign', '课文跟读', 'reading')
              }
              if (this.book()?.hasStories ?? false) {
                this.linkRow('books', '课外故事', 'stories')
              }
            }
          }
          Blank().height(24)
        }
        .padding({ left: 16, right: 16, top: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      if (this.outlineData() !== null) {
        ChunkyButton({ label: '开始学习', onTap: () => {
          const b = this.book();
          if (b === undefined) {
            return;
          }
          this.store.setActiveBook(b.id);
          Haptics.success();
          Router.shared.clear();
        } }).padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }

  @Builder
  trail() {
    Text('').width(0)
  }

  @Builder
  linkRow(icon: string, title: string, dest: RouteName) {
    Row({ space: 12 }) {
      IconBadge(icon, C.secondary, 40, 18)
      Text(title).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink).layoutWeight(1)
      DuoIcon({ name: 'chevronRight', sz: 16, color: C.inkSofter })
    }
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .width('100%')
    .backgroundColor(C.surfaceAlt)
    .borderRadius(R.card)
    .onClick(() => {
      Haptics.tap();
      const r = new AppRoute(dest);
      r.bookId = this.route.bookId;
      Router.shared.push(r);
    })
  }
}


/** 单元知识手册（UnitGuideView）：本单元的概念/公式/易错点汇总，带朗读。 */
@ComponentV2
export struct UnitGuidePage {
  @Param route: AppRoute = new AppRoute('guide');
  store: ProgressStore = ProgressStore.shared;

  private unitNo(): number {
    return this.route.unitNumber;
  }

  @Builder
  kpCard(kp: KnowledgePoint) {
    CardBox() {
      Column({ space: 8 }) {
        Text(kp.name).fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink)
        if (kp.description.length > 0) {
          Text(renderMathText(kp.description)).fontSize(F.body).fontColor(C.inkMuted).lineHeight(22)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
  }

  build() {
    Column() {
      TitleBar({ title: `第 ${this.unitNo()} 单元 · 知识手册`, onBack: () => Router.shared.pop() })
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.lessons(), (m: PathLessonMeta) => {
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                DuoIcon({ name: this.store.isLessonCompleted(m.id) ? 'checkCircle' : 'star', sz: 16,
                  color: this.store.isLessonCompleted(m.id) ? C.primary : C.inkSofter })
                Text(m.title).fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
              }
              .width('100%')

              ForEach(this.knowledgeOf(m.id), (kp: KnowledgePoint, i: number) => {
                this.kpCard(kp)
              }, (kp: KnowledgePoint, i: number) => `${m.id}-${i}`)
            }
            .alignItems(HorizontalAlign.Start)
          }, (m: PathLessonMeta) => m.id)
          Blank().height(30)
        }
        .padding({ left: 16, right: 16, top: 12 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }

  private lessons(): PathLessonMeta[] {
    const o = DataLoader.tryOutline(this.route.bookId);
    if (o === null) {
      return [];
    }
    return pathLessonMetas(o, this.route.bookId).filter((m: PathLessonMeta) => m.unitNumber === this.unitNo());
  }

  private knowledgeOf(lessonId: string): KnowledgePoint[] {
    const l = DataLoader.tryLesson(this.route.bookId, lessonId);
    if (l === null || l.knowledge === undefined || l.knowledge === null) {
      return [];
    }
    const k = l.knowledge;
    const out: KnowledgePoint[] = [];
    const rows: string[] = [
      k.core_concept.length > 0 ? `📖 ${k.core_concept}` : '',
      k.key_formula.length > 0 ? `⭐ ${k.key_formula}` : '',
      k.tips.length > 0 ? `💡 ${k.tips}` : ''
    ];
    k.common_mistakes.forEach((m: string) => rows.push(`⚠️ ${m}`));
    rows.filter((r: string) => r.length > 0).forEach((r: string) => {
      const kp = { name: '', description: r, difficulty: 0, question_types: [] } as KnowledgePoint;
      out.push(kp);
    });
    return out;
  }
}

/** 跳级测试（JumpTestView）：15 题一次答完，≥80% 则解锁该单元之前的课程。 */
@ComponentV2
export struct JumpTestPage {
  @Param route: AppRoute = new AppRoute('jumpTest');
  store: ProgressStore = ProgressStore.shared;
  @Local sampled: JumpSampledQuestion[] = [];
  @Local questions: Question[] = [];
  private priorIds: string[] = [];
  @Local index: number = 0;
  @Local answer: string = '';
  @Local phase: QuestionPhase = 'answering';
  @Local isCorrect: boolean = false;
  @Local correctCount: number = 0;
  @Local done: boolean = false;
  @Local passed: boolean = false;
  @Local marked: number = 0;

  aboutToAppear(): void {
    const o = DataLoader.tryOutline(this.route.bookId);
    if (o === null) {
      return;
    }
    const priors = priorLessonMetas(o, this.route.bookId, this.route.unitNumber);
    this.priorIds = priors.map((m: PathLessonMeta) => m.id);
    const sources: JumpQuestionSource[] = [];
    priors.forEach((m: PathLessonMeta) => {
      const l = DataLoader.tryLesson(this.route.bookId, m.id);
      if (l !== null) {
        sources.push(new JumpQuestionSource(m.id, l.questions));
      }
    });
    this.sampled = Jump.sampleQuestions(sources, Jump.testSize, `${this.route.bookId}-u${this.route.unitNumber}`);
    this.questions = this.sampled.map((x: JumpSampledQuestion) => x.question);
  }

  private current(): Question | undefined {
    return this.questions[this.index];
  }

  private next(): void {
    if (this.isCorrect) {
      this.correctCount++;
    }
    if (this.index + 1 >= this.questions.length) {
      const acc = this.correctCount / Math.max(1, this.questions.length);
      this.passed = acc >= Jump.passAccuracy;
      if (this.passed) {
        this.marked = this.store.applyJumpUnlock(this.priorIds);
      }
      Haptics.success();
      SFXEngine.shared.play(this.passed ? 'complete' : 'wrong');
      this.done = true;
      return;
    }
    this.index++;
    this.answer = '';
    this.phase = 'answering';
    this.isCorrect = false;
  }

  build() {
    Column() {
      TitleBar({ title: '⚡ 跳级测试', onBack: () => Router.shared.pop() })
      if (this.done) {
        Column({ space: 16 }) {
          Mascot({ mood: this.passed ? 'proud' : 'sad', sz: 130 })
          Text(this.passed ? '挑战成功！' : '差一点点').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
          Text(this.passed ?
            `答对 ${this.correctCount}/${this.questions.length} 题，前面的 ${this.marked} 节课已为你解锁` :
            `答对 ${this.correctCount}/${this.questions.length} 题，需要 80% 正确率`)
            .fontSize(F.body).fontColor(C.inkMuted).textAlign(TextAlign.Center)
          ChunkyButton({ label: '好的', onTap: () => Router.shared.clear() }).width(220)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
      } else if (this.current() !== undefined) {
        ForEach([this.current() as Question], (q: Question) => {
          this.runner(q)
        }, (q: Question) => `${this.index}-${q.id}`)
      } else {
        Column() {
          LoadingProgress().width(40).color(C.primary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }

  @Builder
  runner(q: Question) {
    Column() {
      Row({ space: 12 }) {
        ProgressBar({ progress: (this.index + (this.phase === 'checked' ? 1 : 0)) / Math.max(1, this.questions.length) })
          .layoutWeight(1)
        Text(`${this.index + 1}/${this.questions.length}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.inkMuted)
      }
      .padding({ left: 18, right: 18, top: 6, bottom: 10 })

      Scroll() {
        Column({ space: S.xl }) {
          Text(renderMathText(q.question)).fontSize(F.subhead).fontWeight(W.medium).fontColor(C.ink).lineHeight(26)
            .width('100%')
          QuestionRenderer({
            question: q, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
            qKey: `j${this.index}`, onAnswer: (a: string) => {
              this.answer = a;
            }
          })
        }
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      if (this.phase === 'checked') {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            DuoIcon({ name: this.isCorrect ? 'checkCircle' : 'xmarkCircle', sz: 22,
              color: this.isCorrect ? C.primary : C.danger })
            Text(this.isCorrect ? '正确' : `正确答案：${renderMathText(q.answer)}`).fontSize(F.body).fontWeight(W.bold)
              .fontColor(this.isCorrect ? C.primary : C.danger).layoutWeight(1)
          }
          ChunkyButton({ label: '继续', variant: this.isCorrect ? 'primary' : 'danger', onTap: () => this.next() })
        }
        .padding({ left: 20, right: 20, top: 14, bottom: 28 })
        .backgroundColor(alpha(this.isCorrect ? C.primary : C.danger, 0.10))
      } else {
        ChunkyButton({ label: '检查', variant: this.answer.trim().length === 0 ? 'disabled' : 'primary',
          onTap: () => {
            this.isCorrect = gradeAnswer(q, this.answer);
            this.phase = 'checked';
            if (this.isCorrect) {
              SFXEngine.shared.play('correct', 0);
              Haptics.correct();
            } else {
              SFXEngine.shared.play('wrong');
              Haptics.wrong();
            }
          } })
          .padding({ left: 20, right: 20, top: 14, bottom: 28 })
          .backgroundColor(C.bg)
      }
    }
    .layoutWeight(1)
  }
}
