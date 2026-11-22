// 课外故事与课文跟读 (StoriesView / StoryReaderView / PassageReader / FollowUpQuiz 的鸿蒙版)。
import { C, F, R, S, W, alpha } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { readingId, ReadingKind } from '../domain/Catalog';
import { renderMathText } from '../domain/MathText';
import { gradeAnswer } from '../domain/Grade';
import { Passage, PassageSentence, Question, Story, StoryQuestion } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { DataLoader } from '../services/DataLoader';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { CardBox, ChunkyButton, DuoIcon, IconBadge, Pill, ProgressBar, TitleBar } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { ReadAllButton, TTSButton, SlowModeBadge } from '../components/Widgets';
import { AppRoute, Router } from './Router';
import { QuestionPhase, QuestionRenderer } from './Questions';

/** 当前课本（或路由 bookId）的故事列表。 */
@ComponentV2
export struct StoriesPage {
  @Param route: AppRoute = new AppRoute('stories');
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  private unsubStore: () => void = () => {
  };

  aboutToDisappear(): void {
    this.unsubStore();
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
  }

  private stories(): Story[] {
    const bookId = this.route.bookId.length > 0 ? this.route.bookId : this.store.activeBookId;
    if (bookId === null || bookId.length === 0) {
      return [];
    }
    const bs = DataLoader.loadStories(bookId);
    return bs !== null ? bs.stories : [];
  }

  build() {
    Column() {
      TitleBar({ title: '课外故事', onBack: () => Router.shared.pop() })
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.stories(), (s: Story) => {
            Row({ space: 12 }) {
              IconBadge('books', C.beetle, 44, 20)
              Column({ space: 2 }) {
                Text(s.title).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink).maxLines(2)
                Text(`第 ${s.unitNumber} 单元 · ${s.unitTitle}`).fontSize(F.micro).fontWeight(W.bold)
                  .fontColor(C.inkMuted).maxLines(1)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.store.isReadingCompleted('story', s.id)) {
                DuoIcon({ name: 'checkCircle', sz: 20, color: C.primary })
              } else {
                DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
              }
            }
            .padding(14)
            .width('100%')
            .backgroundColor(C.surface)
            .borderRadius(R.card)
            .border({ width: 2, color: C.border, radius: R.card })
            .onClick(() => {
              Haptics.tap();
              Router.shared.push(AppRoute.item('storyReader', s.bookId, s.id));
            })
          }, (s: Story) => `${s.id}-${this.rev}`)
          Blank().height(30)
        }
        .padding({ left: 16, right: 16, top: 8 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 故事阅读器（StoryReaderView）：阅读 → 逐题小测（判题 + 解析）→ 结果；奖励只发一次。 */
type StoryPhase = 'reading' | 'quiz' | 'result';

@ComponentV2
export struct StoryReaderPage {
  @Param route: AppRoute = new AppRoute('storyReader');
  store: ProgressStore = ProgressStore.shared;
  @Local story: Story | null = null;
  @Local phase: StoryPhase = 'reading';
  @Local qIndex: number = 0;
  @Local answer: string = '';
  @Local qPhase: QuestionPhase = 'answering';
  @Local isCorrect: boolean = false;
  @Local correctCount: number = 0;
  @Local listened: boolean = false;
  @Local done: boolean = false;
  @Local earnedXp: number = 0;
  @Local audioReady: boolean = true;
  private unsubBack: () => void = () => {
  };

  aboutToAppear(): void {
    const bs = DataLoader.loadStories(this.route.bookId);
    if (bs !== null) {
      this.story = bs.stories.find((s: Story) => s.id === this.route.itemId) ?? null;
    }
    const st = this.story;
    if (st !== null) {
      this.done = this.store.isReadingCompleted('story', st.id);
      this.audioReady = AudioPlayer.shared.hasAnyResolvable(st.sentences.map((x: PassageSentence) => x.audio));
    }
    // 小测中系统返回 → 回到阅读，而不是直接退出页面。
    this.unsubBack = Router.shared.interceptBack(() => {
      if (this.phase === 'quiz') {
        this.phase = 'reading';
        return true;
      }
      return false;
    });
  }

  aboutToDisappear(): void {
    this.unsubBack();
    AudioPlayer.shared.stop();
  }

  private questions(): StoryQuestion[] {
    return this.story?.questions ?? [];
  }

  private toQuestion(sq: StoryQuestion): Question {
    const q: Question = {
      id: sq.id,
      type: sq.type,
      question: sq.question,
      options: sq.options,
      answer: sq.answer,
      explanation: sq.explanation,
      audio: sq.audio
    } as Question;
    return q;
  }

  private startQuiz(): void {
    AudioPlayer.shared.stop();
    Haptics.tap();
    this.qIndex = 0;
    this.answer = '';
    this.qPhase = 'answering';
    this.isCorrect = false;
    this.correctCount = 0;
    this.phase = 'quiz';
  }

  private check(q: StoryQuestion): void {
    this.isCorrect = gradeAnswer(this.toQuestion(q), this.answer);
    this.qPhase = 'checked';
    if (this.isCorrect) {
      this.correctCount++;
      SFXEngine.shared.play('correct', 0);
      Haptics.correct();
    } else {
      SFXEngine.shared.play('wrong');
      Haptics.wrong();
    }
  }

  private nextQuestion(): void {
    if (this.qIndex + 1 < this.questions().length) {
      this.qIndex++;
      this.answer = '';
      this.isCorrect = false;
      this.qPhase = 'answering';
      return;
    }
    const st = this.story;
    if (st === null) {
      return;
    }
    const acc = this.correctCount / Math.max(1, this.questions().length);
    this.earnedXp = this.done ? 0 : Economy.storyQuizXp(acc);
    this.store.completeReading('story', st.id, Economy.storyQuizXp(acc));
    this.done = true;
    if (acc >= Economy.readingGoodThreshold) {
      SFXEngine.shared.play('complete');
      Haptics.success();
    }
    this.phase = 'result';
  }

  private canClaimPlain(): boolean {
    return !this.done && (this.listened || !this.audioReady);
  }

  @Builder
  readingBody(st: Story) {
    Scroll() {
      Column({ space: S.l }) {
        Row({ space: 10 }) {
          ReadAllButton({
            sentences: st.sentences,
            onCompleted: () => {
              this.listened = true;
            }
          })
          SlowModeBadge()
        }
        ForEach(st.sentences, (s: PassageSentence, i: number) => {
          Row({ space: 10 }) {
            Text(s.text).fontSize(F.body).fontColor(C.ink).lineHeight(24).layoutWeight(1)
            TTSButton({ path: s.audio, sz: 16, highlightIndex: i, slowCapable: true })
          }
          .alignItems(VerticalAlign.Top)
          .width('100%')
        }, (s: PassageSentence, i: number) => `${i}`)
        Blank().height(24)
      }
      .padding({ left: 20, right: 20, top: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .align(Alignment.Top)

    Column({ space: 8 }) {
      if (st.questions.length > 0) {
        ChunkyButton({ label: this.done ? '再答一次题' : `开始答题  ${st.questions.length} 道题`,
          onTap: () => this.startQuiz() })
        if (this.done) {
          Text('已读完 ✓ 奖励只发一次，但可以再练').fontSize(F.micro).fontColor(C.inkMuted)
        }
      } else {
        // 没有音频包时「听完」永远解不开：给一条不依赖音频的出路。
        ChunkyButton({
          label: this.done ? '已读完 ✓' : `读完了  +${Economy.readingStoryGoodXp} XP`,
          variant: this.canClaimPlain() ? 'primary' : 'disabled',
          onTap: () => {
            if (!this.canClaimPlain()) {
              return;
            }
            this.store.completeReading('story', st.id, Economy.readingStoryGoodXp);
            this.done = true;
            Haptics.success();
            SFXEngine.shared.play('complete');
          }
        })
        if (!this.done && !this.listened && this.audioReady) {
          Text('先听完整个故事，就能领奖励啦').fontSize(F.micro).fontColor(C.inkMuted)
        } else if (!this.done && !this.audioReady) {
          Text('音频还没下载完；先自己读一遍，也能领奖励～').fontSize(F.micro).fontColor(C.inkMuted)
        }
      }
    }
    .padding({ left: 20, right: 20, top: 12, bottom: 28 })
  }

  @Builder
  quizBody(q: StoryQuestion) {
    Row({ space: 12 }) {
      ProgressBar({ progress: (this.qIndex + (this.qPhase === 'checked' ? 1 : 0)) / Math.max(1, this.questions().length) })
        .layoutWeight(1)
      Text(`${this.qIndex + 1}/${this.questions().length}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.inkMuted)
    }
    .padding({ left: 18, right: 18, top: 6, bottom: 10 })

    Scroll() {
      Column({ space: S.xl }) {
        Text(renderMathText(q.question)).fontSize(F.subhead).fontWeight(W.medium).fontColor(C.ink).lineHeight(26)
          .width('100%')
        QuestionRenderer({
          question: this.toQuestion(q), answer: this.answer, phase: this.qPhase, isCorrect: this.isCorrect,
          qKey: `s${this.qIndex}`, onAnswer: (a: string) => {
            this.answer = a;
          }
        })
      }
      .padding({ left: 20, right: 20, bottom: 24 })
    }
    .layoutWeight(1)
    .align(Alignment.Top)

    if (this.qPhase === 'checked') {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          DuoIcon({ name: this.isCorrect ? 'checkCircle' : 'xmarkCircle', sz: 22,
            color: this.isCorrect ? C.primary : C.danger })
          Text(this.isCorrect ? '答对了！' : `正确答案：${renderMathText(q.answer)}`).fontSize(F.body)
            .fontWeight(W.bold).fontColor(this.isCorrect ? C.primary : C.danger).layoutWeight(1)
        }
        if (q.explanation.length > 0) {
          Text(renderMathText(q.explanation)).fontSize(F.caption).fontColor(C.inkMuted).width('100%')
        }
        ChunkyButton({ label: this.qIndex + 1 < this.questions().length ? '继续' : '看结果',
          variant: this.isCorrect ? 'primary' : 'danger', onTap: () => this.nextQuestion() })
      }
      .padding({ left: 20, right: 20, top: 14, bottom: 28 })
      .backgroundColor(alpha(this.isCorrect ? C.primary : C.danger, 0.10))
    } else {
      ChunkyButton({ label: '检查', variant: this.answer.trim().length === 0 ? 'disabled' : 'primary',
        onTap: () => this.check(q) })
        .padding({ left: 20, right: 20, top: 14, bottom: 28 })
    }
  }

  @Builder
  resultBody() {
    Column({ space: 16 }) {
      Mascot({ mood: this.correctCount / Math.max(1, this.questions().length) >= Economy.readingGoodThreshold ? 'proud' :
        'happy', sz: 120 })
      Text('读完啦！').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
      Text(`答对 ${this.correctCount} / ${this.questions().length} 题`).fontSize(F.body).fontColor(C.inkMuted)
      if (this.earnedXp > 0) {
        Text(`+${this.earnedXp} XP`).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.secondary)
      } else {
        Text('奖励已领过，这次是练习').fontSize(F.caption).fontColor(C.inkMuted)
      }
      ChunkyButton({ label: '完成', onTap: () => Router.shared.pop() }).width(220)
      ChunkyButton({ label: '再答一次', variant: 'ghost', onTap: () => this.startQuiz() }).width(220)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }

  build() {
    Column() {
      TitleBar({ title: this.story?.title ?? '', onBack: () => {
        if (this.phase === 'quiz') {
          this.phase = 'reading';
        } else {
          Router.shared.pop();
        }
      } })
      if (this.story === null) {
        Column() {
          Text('故事还没下载好').fontSize(F.body).fontColor(C.inkMuted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.phase === 'reading') {
        this.readingBody(this.story as Story)
      } else if (this.phase === 'quiz' && this.qIndex < this.questions().length) {
        ForEach([this.questions()[this.qIndex]], (q: StoryQuestion) => {
          this.quizBody(q)
        }, (q: StoryQuestion) => `q-${this.qIndex}-${q.id}`)
      } else {
        this.resultBody()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 课文跟读列表 — PassageListView. */
@ComponentV2
export struct PassagesPage {
  @Param route: AppRoute = new AppRoute('reading');
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  private unsubStore: () => void = () => {
  };

  aboutToDisappear(): void {
    this.unsubStore();
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
  }

  private passages(): Passage[] {
    const bookId = this.route.bookId.length > 0 ? this.route.bookId : this.store.activeBookId;
    if (bookId === null || bookId.length === 0) {
      return [];
    }
    const bp = DataLoader.loadPassages(bookId);
    return bp !== null ? bp.passages : [];
  }

  build() {
    Column() {
      TitleBar({ title: '课文跟读', onBack: () => Router.shared.pop() })
      Scroll() {
        Column({ space: 12 }) {
          ForEach(this.passages(), (p: Passage) => {
            Row({ space: 12 }) {
              IconBadge('textAlign', C.secondary, 44, 20)
              Column({ space: 2 }) {
                Text(p.title).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink).maxLines(2)
                Text(`${p.sentences.length} 句`).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (this.store.isReadingCompleted('listen', p.id)) {
                DuoIcon({ name: 'checkCircle', sz: 20, color: C.primary })
              } else {
                DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
              }
            }
            .padding(14)
            .width('100%')
            .backgroundColor(C.surface)
            .borderRadius(R.card)
            .border({ width: 2, color: C.border, radius: R.card })
            .onClick(() => {
              Haptics.tap();
              Router.shared.push(AppRoute.item('passageReader', p.bookId, p.id));
            })
          }, (p: Passage) => `${p.id}-${this.rev}`)
          Blank().height(30)
        }
        .padding({ left: 16, right: 16, top: 8 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 课文跟读器 — 听完全部句子即可领奖。 */
@ComponentV2
export struct PassageReaderPage {
  @Param route: AppRoute = new AppRoute('passageReader');
  store: ProgressStore = ProgressStore.shared;
  @Local passage: Passage | null = null;
  @Local finished: boolean = false;
  @Local audioReady: boolean = true;

  aboutToAppear(): void {
    const bp = DataLoader.loadPassages(this.route.bookId);
    if (bp !== null) {
      this.passage = bp.passages.find((p: Passage) => p.id === this.route.itemId) ?? null;
    }
    const ps = this.passage;
    if (ps !== null) {
      this.audioReady = AudioPlayer.shared.hasAnyResolvable(ps.sentences.map((x: PassageSentence) => x.audio));
    }
  }

  aboutToDisappear(): void {
    AudioPlayer.shared.stop();
  }

  private isDone(): boolean {
    return this.passage !== null && this.store.isReadingCompleted('listen', this.passage.id);
  }

  /** 听完全文才能领（没有音频时允许自己读完领取）。 */
  private canClaim(): boolean {
    return !this.isDone() && (this.finished || !this.audioReady);
  }

  build() {
    Column() {
      TitleBar({ title: this.passage?.title ?? '', onBack: () => Router.shared.pop() })
      if (this.passage === null) {
        Column() {
          LoadingProgress().width(40).color(C.primary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: S.l }) {
            Row({ space: 10 }) {
              ReadAllButton({
                sentences: (this.passage as Passage).sentences,
                onCompleted: () => {
                  this.finished = true;
                }
              })
              SlowModeBadge()
            }
            ForEach((this.passage as Passage).sentences, (s: PassageSentence, i: number) => {
              Row({ space: 10 }) {
                Text(s.text).fontSize(F.body).fontColor(C.ink).lineHeight(24).layoutWeight(1)
                TTSButton({ path: s.audio, sz: 16, highlightIndex: i, slowCapable: true })
              }
              .alignItems(VerticalAlign.Top)
              .width('100%')
            }, (s: PassageSentence, i: number) => `${i}`)
            Blank().height(24)
          }
          .padding({ left: 20, right: 20, top: 12 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)

        Column({ space: 8 }) {
          ChunkyButton({
            label: this.isDone() ? '已读完 ✓' : `读完了  +${Economy.readingListenXp} XP`,
            variant: this.canClaim() ? 'primary' : 'disabled',
            onTap: () => {
              if (!this.canClaim()) {
                return;
              }
              this.store.completeReading('listen', (this.passage as Passage).id, Economy.readingListenXp);
              SFXEngine.shared.play('complete');
              Router.shared.pop();
            }
          })
          if (!this.isDone() && !this.finished && this.audioReady) {
            Text('先点「全文朗读」听完整篇课文，就能领奖励啦').fontSize(F.micro).fontColor(C.inkMuted)
          } else if (!this.isDone() && !this.audioReady) {
            Text('音频还没下载完；先自己读一遍，也能领奖励～').fontSize(F.micro).fontColor(C.inkMuted)
          }
        }
        .padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
