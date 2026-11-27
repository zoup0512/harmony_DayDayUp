// 心魔试炼（儿童模式）：每只心魔 = 课上答错的一道题。订正原题 + 再答对 need 道同类题即收服；
// 每再错一次 need +1（上限 5），连错 3 次弹「请教时刻」。全部收服 → 宝箱解封，返还宝石 + 知识卡 + 收服奖励。
// 每答一题都落盘，中途退出下次接着来。
import { C, F, R, S, W, alpha, Motion } from '../design/Theme';
import { CardTier, Remedy } from '../domain/KidsMode';
import { gradeAnswer, instructionText } from '../domain/Grade';
import { renderMathText } from '../domain/MathText';
import { DemonState, KnowledgeSummary, Lesson, Question, SealedChest } from '../models/Types';
import { ProgressStore, UnsealResult } from '../stores/ProgressStore';
import { DataLoader } from '../services/DataLoader';
import { SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { ChunkyButton, DuoIcon, ModalCard, Pill } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { Confetti } from '../components/Effects';
import { TTSButton } from '../components/Widgets';
import { CardReveal } from './Cards';
import { QuestionPhase, QuestionRenderer, stemFontSize } from './Questions';
import { AppRoute, Router } from './Router';

type RemedyStage = 'intro' | 'quiz' | 'subdued' | 'done' | 'error';

const AUTO_CONTINUE_MS: number = 1200;

@ComponentV2
export struct RemedyPage {
  @Param route: AppRoute = new AppRoute('remedy');
  store: ProgressStore = ProgressStore.shared;
  @Local chest: SealedChest | null = null;
  @Local lesson: Lesson | null = null;
  @Local demons: DemonState[] = [];
  @Local stage: RemedyStage = 'intro';
  @Local demonIdx: number = 0;
  @Local q: Question | null = null;
  @Local qSeq: number = 0;
  @Local answer: string = '';
  @Local phase: QuestionPhase = 'answering';
  @Local isCorrect: boolean = false;
  @Local showHint: boolean = false;
  @Local showHelp: boolean = false;
  @Local unseal: UnsealResult | null = null;
  @Local errorText: string = '';
  private variantTurn: number = 0;
  private autoTimer: number = -1;
  private unsubBack: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubBack = Router.shared.interceptBack(() => {
      if (this.showHelp) {
        this.closeHelp();
        return true;
      }
      return false;
    });
    this.load();
  }

  aboutToDisappear(): void {
    this.cancelAuto();
    this.unsubBack();
  }

  private load(): void {
    const c = this.store.sealedChest(this.route.itemId);
    if (c === null) {
      this.errorText = '这个宝箱已经解封或过期了';
      this.stage = 'error';
      return;
    }
    this.chest = c;
    const l = DataLoader.tryLesson(c.bookId, c.lessonId);
    if (l === null) {
      this.errorText = '课程还没下载好，先回去下载课本吧';
      this.stage = 'error';
      return;
    }
    this.lesson = l;
    // 题库更新后找不到原题的心魔直接算收服，避免卡死。
    this.demons = c.demons.map((d: DemonState) => {
      if (l.questions.some((x: Question) => x.id === d.questionId)) {
        return d;
      }
      const done: DemonState = {
        questionId: d.questionId, need: d.need, variantsDone: d.need, corrected: true, wrongStreak: 0
      };
      return done;
    });
  }

  private get knowledge(): KnowledgeSummary | null {
    return this.lesson?.knowledge ?? null;
  }

  private get subduedCount(): number {
    return this.demons.filter((d: DemonState) => Remedy.isSubdued(d)).length;
  }

  private get current(): DemonState | null {
    return this.demonIdx < this.demons.length ? this.demons[this.demonIdx] : null;
  }

  /** 当前心魔（UI 读这个而不是 builder 参数，作答后才能实时刷新）。 */
  private get cd(): DemonState {
    return this.current ?? Remedy.newDemon(-1);
  }

  private original(d: DemonState): Question | null {
    return this.lesson?.questions.find((x: Question) => x.id === d.questionId) ?? null;
  }

  private pickQuestion(d: DemonState): Question | null {
    const orig = this.original(d);
    if (orig === null || this.lesson === null) {
      return null;
    }
    if (!d.corrected) {
      return orig;
    }
    const pool = Remedy.variantPool(this.lesson.questions, orig);
    if (pool.length === 0) {
      return orig;
    }
    const pick = pool[(d.questionId + this.variantTurn) % pool.length];
    this.variantTurn++;
    return pick;
  }

  private nextDemon(): void {
    const idx = this.demons.findIndex((d: DemonState) => !Remedy.isSubdued(d));
    if (idx < 0) {
      this.finish();
      return;
    }
    this.demonIdx = idx;
    this.stage = 'quiz';
    this.ask();
  }

  private ask(): void {
    const d = this.current;
    if (d === null) {
      this.finish();
      return;
    }
    this.q = this.pickQuestion(d);
    this.qSeq++;
    this.answer = '';
    this.phase = 'answering';
    this.isCorrect = false;
    this.showHint = false;
  }

  private check(): void {
    const q = this.q;
    const d = this.current;
    const chest = this.chest;
    if (q === null || d === null || chest === null) {
      return;
    }
    const ok = gradeAnswer(q, this.answer);
    const wasOriginal = !d.corrected;
    const updated = Remedy.afterAnswer(d, ok);
    this.demons = this.demons.map((x: DemonState, i: number) => i === this.demonIdx ? updated : x);
    this.store.updateChestDemons(chest.id, this.demons);
    if (wasOriginal) {
      this.store.reviewMistake(chest.lessonId, q.id, ok);
    }
    this.getUIContext().animateTo({ curve: Motion.reveal() }, () => {
      this.phase = 'checked';
      this.isCorrect = ok;
    });
    if (ok) {
      SFXEngine.shared.play('correct', updated.variantsDone);
      Haptics.correct();
      this.scheduleAuto();
    } else {
      SFXEngine.shared.play('wrong');
      Haptics.wrong();
    }
  }

  private scheduleAuto(): void {
    this.cancelAuto();
    const seq = this.qSeq;
    this.autoTimer = setTimeout(() => {
      this.autoTimer = -1;
      if (this.qSeq === seq && this.phase === 'checked' && this.isCorrect && !this.showHelp) {
        this.proceed();
      }
    }, AUTO_CONTINUE_MS);
  }

  private cancelAuto(): void {
    if (this.autoTimer !== -1) {
      clearTimeout(this.autoTimer);
      this.autoTimer = -1;
    }
  }

  private proceed(): void {
    this.cancelAuto();
    const d = this.current;
    if (d === null) {
      return;
    }
    if (!this.isCorrect && d.wrongStreak >= Remedy.askHelpAfter) {
      this.showHelp = true;
      return;
    }
    if (Remedy.isSubdued(d)) {
      SFXEngine.shared.play('complete');
      Haptics.success();
      this.stage = 'subdued';
      return;
    }
    this.ask();
  }

  private closeHelp(): void {
    const d = this.current;
    const chest = this.chest;
    this.showHelp = false;
    if (d !== null && chest !== null) {
      const reset: DemonState = {
        questionId: d.questionId, need: d.need, variantsDone: d.variantsDone, corrected: d.corrected, wrongStreak: 0
      };
      this.demons = this.demons.map((x: DemonState, i: number) => i === this.demonIdx ? reset : x);
      this.store.updateChestDemons(chest.id, this.demons);
    }
    this.ask();
  }

  private finish(): void {
    const chest = this.chest;
    if (chest === null) {
      return;
    }
    this.unseal = this.store.unsealChest(chest.id);
    this.stage = 'done';
    SFXEngine.shared.play('complete');
    Haptics.success();
  }

  private progressLabel(d: DemonState): string {
    return d.corrected ? `同类题 ${Math.min(d.variantsDone + 1, d.need)}/${d.need}` : '订正原题';
  }

  // ---------------- 视图 ----------------

  @Builder
  header() {
    Row({ space: 12 }) {
      Stack() {
        DuoIcon({ name: 'chevronLeft', sz: 18, color: C.ink })
      }
      .width(38)
      .height(38)
      .backgroundColor(C.surface)
      .borderRadius(R.control)
      .onClick(() => Router.shared.pop())
      .accessibilityText('返回')

      Text('心魔试炼').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
      if (this.stage === 'quiz' || this.stage === 'subdued') {
        Pill(`已收服 ${this.subduedCount}/${this.demons.length}`, C.ink, C.surface)
      }
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 9, bottom: 13 })
    .backgroundColor(C.studyHeader)
  }

  @Builder
  intro() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        if (this.lesson !== null) {
          Pill(`${this.lesson.unitTitle} · 第 ${this.lesson.kpIndex + 1} 课`, C.ink, alpha(C.bee, 0.30))
        }
        Image($r('app.media.learning_chest')).width(140).height(112).objectFit(ImageFit.Contain)
          .accessibilityLevel('no')
        Text(`${this.demons.length - this.subduedCount} 只心魔待收服`).fontSize(F.heading).fontWeight(W.heavy)
          .fontColor(C.ink).textAlign(TextAlign.Center)
        Text(this.chest?.lessonTitle ?? '').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
          .textAlign(TextAlign.Center)
      }
      .padding(14)
      .width('100%')
      .backgroundColor(C.rewardSurface)
      .borderRadius(R.card)
      .border({ width: 1.5, color: C.rewardBorder, radius: R.card })
      Text('收服方法').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink)
        .width('100%').textAlign(TextAlign.Start)
      Column({ space: 10 }) {
        this.ruleRow('pencil', '订正原题', '先重新答对课上做错的题。', C.primary)
        Divider().color(C.border)
        this.ruleRow('arrowCounter', `答对 ${Remedy.initialVariants} 道同类题`,
          `每错一次多练 1 道，最多 ${Remedy.maxVariants} 道。`, C.primary)
        Divider().color(C.border)
        this.ruleRow('chest', '解封宝箱', `取回 ${this.chest?.gems ?? 0} 宝石` +
          ((this.chest?.cardTier ?? 0) > 0 ? `和${CardTier.label(this.chest?.cardTier ?? 0)}` : '') +
          `，每只心魔再奖 ${Remedy.bonusGemsPerDemon} 宝石。`, C.fox)
      }
      .padding(13)
      .width('100%')
      .backgroundColor(C.surface)
      .borderRadius(R.card)
      .border({ width: 1, color: C.border, radius: R.card })

      Row({ space: 5 }) {
        DuoIcon({ name: 'clock', sz: 13, color: C.inkMuted })
        Text(`宝箱保留到 ${this.chest?.expiresOn ?? ''}`).fontSize(F.caption).fontColor(C.inkMuted)
      }
    }
    .padding({ left: 18, right: 18, top: 16, bottom: 12 })
    .width('100%')
  }

  @Builder
  ruleRow(icon: string, title: string, detail: string, tint: string) {
    Row({ space: 10 }) {
      Stack() {
        DuoIcon({ name: icon, sz: 18, color: tint })
      }
      .width(36).height(36).borderRadius(R.control).backgroundColor(alpha(tint, 0.15))
      Column({ space: 3 }) {
        Text(title).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        Text(detail).fontSize(F.caption).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  quiz(q: Question) {
    Column() {
      Scroll() {
        Column({ space: S.xl }) {
          Column({ space: S.m }) {
            Row({ space: 8 }) {
              Pill(this.progressLabel(this.cd), '#FFFFFF', this.cd.corrected ? C.secondary : C.fox)
              Text(instructionText(q.type)).fontSize(F.subhead).fontWeight(W.bold).fontColor(C.inkMuted)
            }
            Row({ space: 10 }) {
              Text(renderMathText(q.question)).fontSize(stemFontSize(q.question)).fontWeight(W.bold).fontColor(C.ink)
                .lineHeight(stemFontSize(q.question) * 1.4).layoutWeight(1)
              TTSButton({ path: q.audio?.question })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          .alignItems(HorizontalAlign.Start)

          QuestionRenderer({
            question: q, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
            qKey: `rm-${this.qSeq}`, onAnswer: (a: string) => {
              this.answer = a;
            }
          })

          if (this.phase === 'answering' && !this.cd.corrected && q.explanation.length > 0) {
            if (this.showHint) {
              Text(`💡 ${renderMathText(q.explanation)}`).fontSize(F.body).fontColor(C.inkMuted).lineHeight(22)
                .padding(14).width('100%').backgroundColor(alpha(C.bee, 0.12)).borderRadius(R.card)
            } else {
              Text('💡 先看看讲解').fontSize(F.caption).fontWeight(W.bold).fontColor(C.secondary)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 }).backgroundColor(alpha(C.secondary, 0.12))
                .borderRadius(999)
                .onClick(() => {
                  Haptics.tap();
                  this.showHint = true;
                })
            }
          }
        }
        .padding({ left: 20, right: 20, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      if (this.phase === 'checked') {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            DuoIcon({ name: this.isCorrect ? 'checkCircle' : 'xmarkCircle', sz: 22,
              color: this.isCorrect ? C.primary : C.danger })
            Column({ space: 3 }) {
              Text(this.isCorrect ? (Remedy.isSubdued(this.cd) ? '收服成功！' : '答对了！') :
                `正确答案：${renderMathText(q.answer)}`)
                .fontSize(F.body).fontWeight(W.heavy).fontColor(this.isCorrect ? C.primary : C.danger)
              if (!this.isCorrect) {
                Text(this.cd.corrected ? `没关系，还要再答对 ${Math.max(0, this.cd.need - this.cd.variantsDone)} 道同类题` : '没关系，看看讲解，再订正一次').fontSize(F.micro).fontWeight(W.bold)
                  .fontColor(C.inkMuted)
                if (q.explanation.length > 0) {
                  Text(renderMathText(q.explanation)).fontSize(F.caption).fontColor(C.inkMuted).lineHeight(19)
                }
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .alignItems(VerticalAlign.Top)

          ChunkyButton({ label: this.isCorrect ? '继续' : '知道了', variant: this.isCorrect ? 'primary' : 'danger',
            onTap: () => this.proceed() })
        }
        .padding({ left: 20, right: 20, top: 14, bottom: 28 })
        .backgroundColor(alpha(this.isCorrect ? C.primary : C.danger, 0.10))
      } else {
        ChunkyButton({ label: '检查', variant: this.answer.trim().length === 0 ? 'disabled' : 'primary',
          onTap: () => this.check() })
          .padding({ left: 20, right: 20, top: 14, bottom: 28 })
          .backgroundColor(C.bg)
      }
    }
    .layoutWeight(1)
  }

  @Builder
  subdued() {
    Column({ space: 16 }) {
      Stack() {
        Text('👾').fontSize(80).opacity(0.35)
        Text('已收服').fontSize(F.title).fontWeight(W.black).fontColor(C.danger)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .border({ width: 3, color: C.danger, radius: 10 })
          .rotate({ angle: -12 })
      }
      .height(130)
      Text(`收服 ${this.subduedCount}/${this.demons.length} 只`).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text(this.subduedCount >= this.demons.length ? '全部收服！去打开宝箱吧' : '继续收服下一只心魔').fontSize(F.body)
        .fontColor(C.inkMuted)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }

  @Builder
  done() {
    Stack() {
      Scroll() {
        Column({ space: 16 }) {
          Mascot({ mood: 'proud', sz: 100, reactTo: 'levelup' })
          Text('宝箱解封！').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
          if (this.unseal !== null) {
            Row({ space: 8 }) {
              DuoIcon({ name: 'gem', sz: 24, color: C.beetle })
              Text(`+${this.unseal?.gems ?? 0} 宝石`).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.beetle)
            }
            Text(`含收服奖励 +${this.unseal?.bonusGems ?? 0}`).fontSize(F.caption).fontWeight(W.bold)
              .fontColor(C.inkMuted)
            if ((this.unseal?.cardTier ?? 0) > 0) {
              CardReveal({
                title: this.unseal?.lessonTitle ?? '', caption: '知识卡',
                tier: this.unseal?.cardTier ?? 1,
                badge: (this.unseal?.cardNew ?? false) ? 'NEW' : ((this.unseal?.cardUpgraded ?? false) ? '升级' : '')
              })
            }
          } else {
            Text('宝箱已经领过了').fontSize(F.body).fontColor(C.inkMuted)
          }
        }
        .padding({ left: 24, right: 24, top: 30, bottom: 30 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)

      Confetti({ active: true, burstMs: 1400 })
    }
    .layoutWeight(1)
  }

  @Builder
  helpModal() {
    ModalCard({ onBackdrop: () => this.closeHelp() }) {
      Mascot({ mood: 'think', sz: 84 })
      Text('请教时刻').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text('这只心魔有点难缠，我们先一起看看方法：').fontSize(F.caption).fontColor(C.inkMuted)
      if (this.knowledge !== null) {
        Column({ space: 6 }) {
          if ((this.knowledge?.core_concept ?? '').length > 0) {
            Text(renderMathText(this.knowledge?.core_concept)).fontSize(F.caption).fontColor(C.ink).lineHeight(20)
          }
          if ((this.knowledge?.key_formula ?? '').length > 0) {
            Text(renderMathText(this.knowledge?.key_formula)).fontSize(F.caption).fontWeight(W.heavy)
              .fontColor(C.primary).lineHeight(20)
          }
          if ((this.knowledge?.tips ?? '').length > 0) {
            Text(`小提示：${renderMathText(this.knowledge?.tips)}`).fontSize(F.caption).fontColor(C.ink).lineHeight(20)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .width('100%')
        .backgroundColor(alpha(C.secondary, 0.08))
        .borderRadius(R.card)
      }
      Text('还是不太懂？可以请爸爸妈妈帮帮忙哦 👨‍👩‍👧').fontSize(F.caption).fontWeight(W.bold).fontColor(C.fox)
        .textAlign(TextAlign.Center)
      ChunkyButton({ label: '我再试试', onTap: () => this.closeHelp() })
    }
  }

  build() {
    Stack() {
      Column() {
        this.header()
        if (this.stage === 'error') {
          Column({ space: 16 }) {
            Mascot({ mood: 'think', sz: 110 })
            Text(this.errorText).fontSize(F.body).fontColor(C.inkMuted).textAlign(TextAlign.Center)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding(24)
          ChunkyButton({ label: '返回', variant: 'ghost', onTap: () => Router.shared.pop() })
            .padding({ left: 20, right: 20, top: 14, bottom: 28 })
        } else if (this.stage === 'intro') {
          Scroll() {
            this.intro()
          }
          .layoutWeight(1)
          .align(Alignment.Top)
          ChunkyButton({ label: '开始收服', onTap: () => {
            Haptics.tap();
            this.nextDemon();
          } }).padding({ left: 20, right: 20, top: 14, bottom: 28 })
        } else if (this.stage === 'quiz' && this.q !== null && this.current !== null) {
          ForEach([this.qSeq], (s: number) => {
            this.quiz(this.q as Question)
          }, (s: number) => `q-${s}`)
        } else if (this.stage === 'subdued') {
          this.subdued()
          ChunkyButton({ label: this.subduedCount >= this.demons.length ? '打开宝箱' : '下一只', onTap: () => {
            Haptics.tap();
            this.nextDemon();
          } }).padding({ left: 20, right: 20, top: 14, bottom: 28 })
        } else if (this.stage === 'done') {
          this.done()
          ChunkyButton({ label: '收下', onTap: () => {
            Haptics.tap();
            SFXEngine.shared.play('purchase');
            Router.shared.pop();
          } }).padding({ left: 20, right: 20, top: 14, bottom: 28 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(C.bg)

      if (this.showHelp) {
        this.helpModal()
      }
    }
    .width('100%')
    .height('100%')
  }
}
