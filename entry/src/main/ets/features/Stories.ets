// 课外故事与课文跟读 (StoriesView / StoryReaderView / PassageReader / FollowUpQuiz 的鸿蒙版)。
import { C, F, R, S, W, alpha } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { readingId, ReadingKind } from '../domain/Catalog';
import { renderMathText } from '../domain/MathText';
import { gradeAnswer } from '../domain/Grade';
import { Passage, PassageSentence, Question, Story, StoryQuestion } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { DataLoader } from '../services/DataLoader';
import { SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { CardBox, ChunkyButton, DuoIcon, IconBadge, Pill, TitleBar } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { ReadAllButton, TTSButton, SlowModeBadge } from '../components/Widgets';
import { AppRoute, Router } from './Router';

/** 当前课本（或路由 bookId）的故事列表。 */
@ComponentV2
export struct StoriesPage {
  @Param route: AppRoute = new AppRoute('stories');
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  aboutToAppear(): void {
    this.store.onChange(() => {
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

/** 故事阅读器：逐句音频 + 末尾小测；完成发 XP 并标记已读。 */
@ComponentV2
export struct StoryReaderPage {
  @Param route: AppRoute = new AppRoute('storyReader');
  store: ProgressStore = ProgressStore.shared;
  @Local story: Story | null = null;
  @Local quizIndex: number = 0;
  @Local answers: string[] = [];
  @Local readFinished: boolean = false;

  aboutToAppear(): void {
    const bs = DataLoader.loadStories(this.route.bookId);
    if (bs !== null) {
      this.story = bs.stories.find((s: Story) => s.id === this.route.itemId) ?? null;
    }
  }

  private submitQuiz(): void {
    const s = this.story;
    if (s === null) {
      return;
    }
    const correct = s.questions.filter((q: StoryQuestion, i: number) =>
      gradeAnswer(this.toQuestion(q), this.answers[i] ?? '')).length;
    const acc = correct / Math.max(1, s.questions.length);
    const xp = Economy.storyQuizXp(acc);
    this.store.completeReading('story', s.id, xp);
    if (acc >= Economy.readingGoodThreshold) {
      SFXEngine.shared.play('complete');
      Haptics.success();
    } else {
      SFXEngine.shared.play('wrong');
      Haptics.wrong();
    }
    Router.shared.pop();
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

  build() {
    Column() {
      TitleBar({ title: this.story?.title ?? '', onBack: () => Router.shared.pop() })
      if (this.story === null) {
        Column() {
          LoadingProgress().width(40).color(C.primary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: S.l }) {
            ReadAllButton({
              sentences: (this.story as Story).sentences,
              onCompleted: () => {
                this.readFinished = true;
              }
            })
            SlowModeBadge()
            ForEach((this.story as Story).sentences, (s: PassageSentence, i: number) => {
              Row({ space: 10 }) {
                Text(s.text).fontSize(F.body).fontColor(C.ink).lineHeight(24).layoutWeight(1)
                TTSButton({ path: s.audio, sz: 16, highlightIndex: i, slowCapable: true })
              }
              .alignItems(VerticalAlign.Top)
              .width('100%')
            }, (s: PassageSentence, i: number) => `${i}`)

            if ((this.story as Story).questions.length > 0) {
              Text('读后小测').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).margin({ top: 8 })
              ForEach((this.story as Story).questions, (q: StoryQuestion, i: number) => {
                CardBox() {
                  Column({ space: 8 }) {
                    Text(`${i + 1}. ${q.question}`).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
                    if (q.type === 'choice') {
                      ForEach(q.options, (opt: string, oi: number) => {
                        Row({ space: 8 }) {
                          Radio({ value: `${i}-${oi}`, group: `q${i}` })
                            .onChange((checked: boolean) => {
                              if (checked) {
                                const next = this.answers.slice();
                                while (next.length <= i) {
                                  next.push('');
                                }
                                next[i] = String.fromCharCode(65 + oi);
                                this.answers = next;
                              }
                            })
                          Text(renderMathText(opt)).fontSize(F.body).fontColor(C.ink)
                        }
                      }, (opt: string, oi: number) => `${oi}`)
                    } else {
                      TextInput({ text: this.answers[i] ?? '', placeholder: '写出答案' })
                        .fontSize(F.body)
                        .fontColor(C.ink)
                        .backgroundColor(C.surfaceAlt)
                        .borderRadius(12)
                        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                        .onChange((v: string) => {
                          const next = this.answers.slice();
                          while (next.length <= i) {
                            next.push('');
                          }
                          next[i] = v;
                          this.answers = next;
                        })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')
                }
              }, (q: StoryQuestion, i: number) => `${i}`)
            }
            Blank().height(24)
          }
          .padding({ left: 20, right: 20, top: 12 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .align(Alignment.Top)

        ChunkyButton({
          label: (this.story as Story).questions.length > 0
            ? '完成'
            : (this.store.isReadingCompleted('story', (this.story as Story).id)
              ? '已读完 ✓'
              : `读完了  +${Economy.readingStoryBaseXp} XP`),
          variant: (this.story as Story).questions.length > 0
            ? (this.answers.filter((a: string) => a.length > 0).length < (this.story as Story).questions.length
              ? 'disabled'
              : 'primary')
            : (this.store.isReadingCompleted('story', (this.story as Story).id) ? 'disabled' : 'primary'),
          onTap: () => {
            if ((this.story as Story).questions.length > 0) {
              this.submitQuiz();
            } else if (!this.store.isReadingCompleted('story', (this.story as Story).id)) {
              this.store.completeReading('story', (this.story as Story).id, Economy.readingStoryBaseXp);
              Router.shared.pop();
            }
          }
        }).padding({ left: 20, right: 20, top: 12, bottom: 28 })
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

  aboutToAppear(): void {
    this.store.onChange(() => {
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

  aboutToAppear(): void {
    const bp = DataLoader.loadPassages(this.route.bookId);
    if (bp !== null) {
      this.passage = bp.passages.find((p: Passage) => p.id === this.route.itemId) ?? null;
    }
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

        ChunkyButton({
          label: this.store.isReadingCompleted('listen', (this.passage as Passage).id)
            ? '已读完 ✓'
            : `读完了  +${Economy.readingListenXp} XP`,
          variant: this.store.isReadingCompleted('listen', (this.passage as Passage).id) ? 'disabled' : 'primary',
          onTap: () => {
            if (this.store.isReadingCompleted('listen', (this.passage as Passage).id)) {
              return;
            }
            this.store.completeReading('listen', (this.passage as Passage).id, Economy.readingListenXp);
            SFXEngine.shared.play('complete');
            Router.shared.pop();
          }
        }).padding({ left: 20, right: 20, top: 12, bottom: 28 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
