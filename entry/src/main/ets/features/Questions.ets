// 题型渲染（QuestionViews.swift）：选择 / 判断 / 填空 / 连词成句 / 连线。
import { LengthMetrics } from '@kit.ArkUI';
import { C, F, R, W, alpha, Motion } from '../design/Theme';
import { gradeAnswer, matchingPairs, readableWordOrderAnswer } from '../domain/Grade';
import { renderMathText } from '../domain/MathText';
import { Question } from '../models/Types';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { DuoIcon } from '../components/Kit';

export type QuestionPhase = 'answering' | 'checked';
type CardState = 'default' | 'selected' | 'correct' | 'wrong' | 'disabled';

function cardBorder(s: CardState): string {
  switch (s) {
    case 'selected':
      return C.secondary;
    case 'correct':
      return C.primary;
    case 'wrong':
      return C.danger;
    case 'disabled':
      return alpha(C.surfaceAlt, 0.5);
    default:
      return C.surfaceAlt;
  }
}

function cardFill(s: CardState): string {
  switch (s) {
    case 'selected':
      return alpha(C.secondary, 0.18);
    case 'correct':
      return alpha(C.primary, 0.22);
    case 'wrong':
      return alpha(C.danger, 0.20);
    case 'disabled':
      return alpha(C.surface, 0.5);
    default:
      return C.surface;
  }
}

function cardInk(s: CardState): string {
  switch (s) {
    case 'selected':
      return C.secondary;
    case 'correct':
      return C.primary;
    case 'wrong':
      return C.danger;
    case 'disabled':
      return C.inkSofter;
    default:
      return C.ink;
  }
}

function cardLedge(s: CardState): string {
  switch (s) {
    case 'selected':
      return C.secondaryDark;
    case 'correct':
      return C.primaryDark;
    case 'wrong':
      return C.dangerDark;
    case 'disabled':
      return alpha(C.border, 0.5);
    default:
      return C.border;
  }
}

/** 根据题型分发到具体题目视图；换题时通过 qKey 重建内部状态。 */
@ComponentV2
export struct QuestionRenderer {
  @Param question: Question | undefined = undefined;
  @Param answer: string = '';
  @Param phase: QuestionPhase = 'answering';
  @Param isCorrect: boolean = false;
  @Param qKey: string = '';
  @Event onAnswer: (a: string) => void = (_a: string) => {
  };

  build() {
    Column() {
      ForEach([this.qKey], (_k: string) => {
        if (this.question !== undefined) {
          if (this.question.type === 'choice') {
            ChoiceQuestion({
              question: this.question, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
              onAnswer: (a: string) => this.onAnswer(a)
            })
          } else if (this.question.type === 'true_false') {
            TrueFalseQuestion({
              question: this.question, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
              onAnswer: (a: string) => this.onAnswer(a)
            })
          } else if (this.question.type === 'word_order') {
            WordOrderQuestion({
              question: this.question, answer: this.answer, phase: this.phase,
              onAnswer: (a: string) => this.onAnswer(a)
            })
          } else if (this.question.type === 'matching') {
            MatchingQuestion({
              question: this.question, phase: this.phase, onAnswer: (a: string) => this.onAnswer(a)
            })
          } else {
            FillBlankQuestion({
              question: this.question, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
              numeric: this.question.type !== 'fill_blank_text', onAnswer: (a: string) => this.onAnswer(a)
            })
          }
        }
      }, (k: string) => k)
    }
    .width('100%')
  }
}

const TRUE_FALSE_CARD_HEIGHT: number = 110;

@ComponentV2
struct OptionCard {
  @Param label: string = '';
  @Param state: CardState = 'default';
  @Param tall: boolean = false;
  @Param icon: string = '';
  @Param shake: number = 0;
  @Event onTap: () => void = () => {
  };
  @Local pressed: boolean = false;
  @Local dx: number = 0;

  @Monitor('shake')
  onShake(): void {
    this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
      { duration: 60, event: () => { this.dx = 8; } },
      { duration: 70, event: () => { this.dx = -8; } },
      { duration: 70, event: () => { this.dx = 8; } },
      { duration: 70, event: () => { this.dx = -6; } },
      { duration: 60, event: () => { this.dx = 0; } }
    ]);
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row().width('100%').height(this.tall ? TRUE_FALSE_CARD_HEIGHT : '100%')
        .borderRadius(R.card).backgroundColor(cardLedge(this.state)).margin({ top: 4 })
      Column() {
        if (this.tall) {
          Column({ space: 8 }) {
            DuoIcon({ name: this.icon, sz: 36, color: cardInk(this.state) })
            Text(this.label).fontSize(F.subhead).fontWeight(W.bold).fontColor(cardInk(this.state))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Row({ space: 12 }) {
            Text(this.label).fontSize(F.body).fontWeight(W.heavy).fontColor(cardInk(this.state)).layoutWeight(1)
            if (this.state === 'correct') {
              DuoIcon({ name: 'checkCircle', sz: 22, color: C.primary })
            } else if (this.state === 'wrong') {
              DuoIcon({ name: 'xmarkCircle', sz: 22, color: C.danger })
            }
          }
          .width('100%')
          .constraintSize({ minHeight: 60 })
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
      }
      .width('100%')
      .height(this.tall ? TRUE_FALSE_CARD_HEIGHT : undefined)
      .backgroundColor(cardFill(this.state))
      .borderRadius(R.card)
      .border({ width: this.state === 'default' || this.state === 'disabled' ? 2 : 2.5, color: cardBorder(this.state), radius: R.card })
      .shadow(this.state === 'correct' ? { radius: 4, color: alpha(C.primary, 0.35) } :
        (this.state === 'wrong' ? { radius: 4, color: alpha(C.danger, 0.3) } : { radius: 0, color: Color.Transparent }))
      .translate({ y: this.pressed ? 4 : 0 })
      .animation({ curve: Motion.press() })
    }
    .width('100%')
    .padding({ bottom: 4 })
    .translate({ x: this.dx })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => this.onTap())
  }
}

@ComponentV2
struct ChoiceQuestion {
  @Param question: Question | undefined = undefined;
  @Param answer: string = '';
  @Param phase: QuestionPhase = 'answering';
  @Param isCorrect: boolean = false;
  @Event onAnswer: (a: string) => void = (_a: string) => {
  };
  @Local shake: number = 0;

  @Monitor('phase')
  onPhase(): void {
    if (this.phase === 'checked' && !this.isCorrect) {
      this.shake++;
    }
  }

  private stateFor(i: number): CardState {
    const letter = String.fromCharCode(65 + i);
    const selected = this.answer.toUpperCase() === letter;
    if (this.phase !== 'checked' || this.question === undefined) {
      return selected ? 'selected' : 'default';
    }
    if (gradeAnswer(this.question, letter)) {
      return 'correct';
    }
    return selected ? 'wrong' : 'disabled';
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.question?.options ?? [], (opt: string, i: number) => {
        OptionCard({
          label: renderMathText(opt),
          state: this.stateFor(i),
          shake: this.stateFor(i) === 'wrong' ? this.shake : 0,
          onTap: () => {
            if (this.phase !== 'answering') {
              return;
            }
            Haptics.tap();
            SFXEngine.shared.play('tap');
            this.onAnswer(String.fromCharCode(65 + i));
            const opts = this.question?.audio?.options;
            if (opts !== undefined && opts !== null && i < opts.length) {
              AudioPlayer.shared.playOne(opts[i]);
            }
          }
        })
      }, (opt: string, i: number) => `${i}-${opt}`)
    }
    .width('100%')
  }
}

@ComponentV2
struct TrueFalseQuestion {
  @Param question: Question | undefined = undefined;
  @Param answer: string = '';
  @Param phase: QuestionPhase = 'answering';
  @Param isCorrect: boolean = false;
  @Event onAnswer: (a: string) => void = (_a: string) => {
  };
  @Local shake: number = 0;

  @Monitor('phase')
  onPhase(): void {
    if (this.phase === 'checked' && !this.isCorrect) {
      this.shake++;
    }
  }

  private stateFor(value: string): CardState {
    const selected = this.answer === value;
    if (this.phase !== 'checked' || this.question === undefined) {
      return selected ? 'selected' : 'default';
    }
    if (gradeAnswer(this.question, value)) {
      return 'correct';
    }
    return selected ? 'wrong' : 'disabled';
  }

  build() {
    Row({ space: 16 }) {
      ForEach(['对', '错'], (v: string) => {
        OptionCard({
          label: v, state: this.stateFor(v), tall: true, icon: v === '对' ? 'checkCircle' : 'xmarkCircle',
          shake: this.stateFor(v) === 'wrong' ? this.shake : 0,
          onTap: () => {
            if (this.phase !== 'answering') {
              return;
            }
            Haptics.tap();
            SFXEngine.shared.play('tap');
            this.onAnswer(v);
          }
        }).layoutWeight(1)
      }, (v: string) => v)
    }
    .width('100%')
  }
}

@ComponentV2
struct FillBlankQuestion {
  @Param question: Question | undefined = undefined;
  @Param answer: string = '';
  @Param phase: QuestionPhase = 'answering';
  @Param isCorrect: boolean = false;
  @Param numeric: boolean = true;
  @Event onAnswer: (a: string) => void = (_a: string) => {
  };
  @Local dx: number = 0;

  @Monitor('phase')
  onPhase(): void {
    if (this.phase === 'checked' && !this.isCorrect) {
      this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
        { duration: 60, event: () => { this.dx = 8; } },
        { duration: 70, event: () => { this.dx = -8; } },
        { duration: 70, event: () => { this.dx = 6; } },
        { duration: 60, event: () => { this.dx = 0; } }
      ]);
    }
  }

  private state(): CardState {
    if (this.phase !== 'checked') {
      return this.answer.length === 0 ? 'default' : 'selected';
    }
    return this.isCorrect ? 'correct' : 'wrong';
  }

  build() {
    TextInput({ text: this.answer, placeholder: this.numeric ? '输入数字' : '在这里作答' })
      .type(this.numeric ? InputType.NUMBER_DECIMAL : InputType.Normal)
      .fontSize(20)
      .fontWeight(W.heavy)
      .fontColor(this.state() === 'correct' ? C.primary : (this.state() === 'wrong' ? C.danger : C.ink))
      .placeholderColor(C.inkSofter)
      .caretColor(C.secondary)
      .height(64)
      .padding({ left: 18, right: 18 })
      .backgroundColor(this.state() === 'correct' ? alpha(C.primary, 0.15) :
        (this.state() === 'wrong' ? alpha(C.danger, 0.15) : (this.state() === 'selected' ? alpha(C.secondary, 0.10) : C.surface)))
      .borderRadius(R.card)
      .border({
        width: this.state() === 'default' ? 2 : 2.5, radius: R.card,
        color: this.state() === 'correct' ? C.primary : (this.state() === 'wrong' ? C.danger :
          (this.state() === 'selected' ? C.secondary : C.border))
      })
      .enabled(this.phase === 'answering')
      .translate({ x: this.dx })
      .onChange((v: string) => this.onAnswer(v))
  }
}

@ComponentV2
struct WordOrderQuestion {
  @Param question: Question | undefined = undefined;
  @Param answer: string = '';
  @Param phase: QuestionPhase = 'answering';
  @Event onAnswer: (a: string) => void = (_a: string) => {
  };
  @Local picked: number[] = [];

  private options(): string[] {
    return this.question?.options ?? [];
  }

  private commit(next: number[]): void {
    Haptics.tap();
    SFXEngine.shared.play('tap');
    this.getUIContext().animateTo({ curve: Motion.reveal() }, () => {
      this.picked = next;
    });
    this.onAnswer(next.map((i: number) => this.options()[i]).join(','));
  }

  @Builder
  chip(text: string, filled: boolean, ghost: boolean, onTap: () => void) {
    Stack({ alignContent: Alignment.Top }) {
      if (!ghost) {
        Row().width('100%').height('100%').borderRadius(999).backgroundColor(filled ? C.primaryDark : C.border)
          .margin({ top: 3 })
      }
      Text(renderMathText(text))
        .fontSize(F.subhead)
        .fontWeight(W.bold)
        .fontColor(ghost ? Color.Transparent : (filled ? C.primary : C.ink))
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(ghost ? alpha(C.surfaceAlt, 0.5) : C.surface)
        .borderRadius(999)
        .border({ width: ghost ? 0 : 2, color: filled ? C.primary : C.border, radius: 999 })
    }
    .padding({ bottom: 3 })
    .onClick(() => {
      if (!ghost) {
        onTap();
      }
    })
  }

  build() {
    Column({ space: 14 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Column({ space: 36 }) {
          Row().width('100%').height(2).backgroundColor(C.border)
          Row().width('100%').height(2).backgroundColor(C.border)
        }
        .padding({ top: 32, left: 4, right: 4 })

        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(6) } }) {
          ForEach(this.picked, (i: number) => {
            this.chip(this.options()[i], true, false, () => {
              if (this.phase === 'answering') {
                this.commit(this.picked.filter((x: number) => x !== i));
              }
            })
          }, (i: number) => `p${i}`)
        }
        .constraintSize({ minHeight: 72 })
      }
      .width('100%')
      .constraintSize({ minHeight: 120 })

      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(6) } }) {
        ForEach(this.options(), (opt: string, i: number) => {
          this.chip(opt, false, this.picked.includes(i), () => {
            if (this.phase === 'answering') {
              this.commit(this.picked.concat([i]));
            }
          })
        }, (opt: string, i: number) => `o${i}-${this.picked.includes(i)}`)
      }

      if (this.phase === 'checked' && this.question !== undefined && !gradeAnswer(this.question, this.answer)) {
        Column({ space: 4 }) {
          Text('正确的句子是：').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
          Text(renderMathText(readableWordOrderAnswer(this.question.answer))).fontSize(F.subhead).fontWeight(W.bold)
            .fontColor(C.primary)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor(alpha(C.primary, 0.08))
        .borderRadius(R.card)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}


@ComponentV2
struct MatchingQuestion {
  @Param question: Question | undefined = undefined;
  @Param phase: QuestionPhase = 'answering';
  @Event onAnswer: (a: string) => void = (_a: string) => {
  };
  @Local matched: string[] = [];
  @Local activeLeft: string = '';
  @Local wrongLeft: string = '';
  @Local wrongRight: string = '';
  @Local dx: number = 0;
  private leftKeys: string[] = ['A', 'B', 'C', 'D'];
  private rightKeys: string[] = ['1', '2', '3', '4'];

  private correctMap(): Map<string, string> {
    return matchingPairs(this.question?.answer ?? '');
  }

  private tapLeft(key: string): void {
    Haptics.tap();
    SFXEngine.shared.play('tap');
    this.activeLeft = this.activeLeft === key ? '' : key;
  }

  private tapRight(key: string): void {
    const left = this.activeLeft;
    if (left.length === 0) {
      return;
    }
    const map = this.correctMap();
    if (map.get(left) === key) {
      Haptics.correct();
      SFXEngine.shared.play('pairMatch', this.matched.length);
      this.getUIContext().animateTo({ curve: Motion.reveal() }, () => {
        this.matched = this.matched.concat([left]);
        this.activeLeft = '';
      });
      if (this.matched.length === this.leftKeys.length) {
        const text = this.leftKeys.filter((k: string) => map.get(k) !== undefined)
          .map((k: string) => `${k}-${map.get(k)}`).join(',');
        this.onAnswer(text);
      }
    } else {
      Haptics.wrong();
      this.wrongLeft = left;
      this.wrongRight = key;
      this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
        { duration: 60, event: () => { this.dx = 8; } },
        { duration: 70, event: () => { this.dx = -8; } },
        { duration: 70, event: () => { this.dx = 6; } },
        { duration: 60, event: () => { this.dx = 0; } }
      ]);
      setTimeout(() => {
        this.wrongLeft = '';
        this.wrongRight = '';
        this.activeLeft = '';
      }, 500);
    }
  }

  @Builder
  tile(label: string, isLeft: boolean, key: string) {
    Stack({ alignContent: Alignment.Top }) {
      Row().width('100%').height('100%').borderRadius(R.card).margin({ top: 3 })
        .backgroundColor((isLeft ? this.wrongLeft === key : this.wrongRight === key) ? C.dangerDark :
          ((isLeft && this.activeLeft === key) ? C.secondaryDark : C.border))
      Text(renderMathText(label))
        .fontSize(F.subhead)
        .fontWeight(W.bold)
        .fontColor(C.ink)
        .width('100%')
        .constraintSize({ minHeight: 52 })
        .padding(12)
        .backgroundColor((isLeft ? this.wrongLeft === key : this.wrongRight === key) ? alpha(C.danger, 0.14) :
          ((isLeft && this.activeLeft === key) ? alpha(C.secondary, 0.12) : C.surface))
        .borderRadius(R.card)
        .border({
          width: 2, radius: R.card,
          color: (isLeft ? this.wrongLeft === key : this.wrongRight === key) ? C.danger :
            ((isLeft && this.activeLeft === key) ? C.secondary : C.border)
        })
    }
    .width('100%')
    .padding({ bottom: 3 })
    .translate({ x: (isLeft ? this.wrongLeft === key : this.wrongRight === key) ? this.dx : 0 })
    .onClick(() => {
      if (this.phase !== 'answering') {
        return;
      }
      if (isLeft) {
        this.tapLeft(key);
      } else {
        this.tapRight(key);
      }
    })
  }

  @Builder
  ghost() {
    Stack() {
      DuoIcon({ name: 'check', sz: 16, color: alpha(C.primary, 0.6) })
    }
    .width('100%')
    .height(52)
    .margin({ bottom: 3 })
    .backgroundColor(alpha(C.surfaceAlt, 0.4))
    .borderRadius(R.card)
  }

  private rightOwned(key: string): boolean {
    const map = this.correctMap();
    return this.matched.some((l: string) => map.get(l) === key);
  }

  build() {
    Row({ space: 14 }) {
      Column({ space: 10 }) {
        ForEach(this.leftKeys, (k: string, i: number) => {
          if (this.matched.includes(k)) {
            this.ghost()
          } else {
            this.tile((this.question?.options ?? [])[i] ?? '', true, k)
          }
        }, (k: string) => `${k}-${this.matched.includes(k)}-${this.activeLeft === k}-${this.wrongLeft === k}`)
      }
      .layoutWeight(1)

      Column({ space: 10 }) {
        ForEach(this.rightKeys, (k: string, i: number) => {
          if (this.rightOwned(k)) {
            this.ghost()
          } else {
            this.tile((this.question?.options ?? [])[i + 4] ?? '', false, k)
          }
        }, (k: string) => `${k}-${this.rightOwned(k)}-${this.wrongRight === k}`)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}

