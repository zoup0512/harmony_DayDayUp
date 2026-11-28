// 做题主流程（LessonRunnerView.swift + IntroCardView.swift）。
import { C, F, R, S, W, alpha, Motion } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { decideMood, decideReaction, MascotTriggerContext, pickBubble, pickRandom } from '../domain/Catalog';
import { gradeAnswer, instructionText } from '../domain/Grade';
import { renderMathText } from '../domain/MathText';
import { formatCountdown, isoString } from '../domain/Dates';
import {
  ActiveLessonSession, KnowledgeSummary, Lesson, LessonExtras, LessonRunResult, MascotMood, MascotReaction, Question,
  QuestionReportKind
} from '../models/Types';
import { LessonSlots } from '../domain/KidsMode';
import { ProgressStore } from '../stores/ProgressStore';
import { SettingsStore } from '../stores/SettingsStore';
import { DataLoader } from '../services/DataLoader';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { Files } from '../services/Files';
import { ChunkyButton, DuoIcon, ModalCard, ProgressBar, SpeechBubble } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { ComboOverlay, XPFloater } from '../components/Effects';
import { TTSButton } from '../components/Widgets';
import { QuestionPhase, QuestionRenderer, stemFontSize } from './Questions';
import { AppRoute, Router } from './Router';

/** 答对后自动进入下一题的延迟：留出 +XP 飞字（~1.05s）的时间；连击浮层（320ms 起，约 1.4s 结束）时再多等一会。 */
const AUTO_ADVANCE_MS: number = 1200;
const AUTO_ADVANCE_COMBO_MS: number = 1900;

/** 神速题：idle 未到 → running 计时中 → expired 超时（仍可作答，无奖励）/ hit 限时答对 → done。 */
type SpeedState = 'idle' | 'running' | 'expired' | 'hit' | 'done';

/** 课程内容指纹（不含音频），用来判断挂起的会话还能不能续。 */
export function lessonContentKey(lesson: Lesson): string {
  const stripped = JSON.parse(JSON.stringify(lesson)) as Lesson;
  stripped.questions.forEach((q: Question) => {
    q.audio = null;
  });
  if (stripped.knowledge !== undefined && stripped.knowledge !== null) {
    stripped.knowledge.audio = null;
  }
  return Files.sha256OfText(JSON.stringify(stripped));
}

export function canResume(session: ActiveLessonSession, lesson: Lesson): boolean {
  if (session.bookId !== lesson.bookId || session.lessonId !== lesson.id) {
    return false;
  }
  const key = session.contentKey;
  if (key !== undefined && key !== null) {
    return key === lessonContentKey(lesson);
  }
  return lesson.id !== 'chinese-g1up-u3-kp2';
}

const REPORT_KINDS: QuestionReportKind[] = ['question_wrong', 'answer_should_count', 'audio_issue'];

function reportLabel(k: QuestionReportKind): string {
  return k === 'question_wrong' ? '题目有误' : (k === 'answer_should_count' ? '我的答案应该算对' : '音频有问题');
}

function reportIcon(k: QuestionReportKind): string {
  return k === 'question_wrong' ? 'warn' : (k === 'answer_should_count' ? 'checkCircle' : 'speakerSlash');
}

@ComponentV2
export struct LessonRunner {
  @Param route: AppRoute = new AppRoute('lesson');
  store: ProgressStore = ProgressStore.shared;
  settings: SettingsStore = SettingsStore.shared;

  @Local lesson: Lesson | null = null;
  @Local loadError: string = '';
  @Local queue: Question[] = [];
  @Local index: number = 0;
  @Local phase: QuestionPhase = 'answering';
  @Local answer: string = '';
  @Local isCorrect: boolean = false;
  @Local solved: number[] = [];
  @Local missed: number[] = [];
  @Local combo: number = 0;
  @Local maxCombo: number = 0;
  @Local attempted: boolean = false;
  @Local sessionXp: number = 0;
  @Local pendingResume: ActiveLessonSession | null = null;
  @Local mood: MascotMood = 'happy';
  @Local reaction: MascotReaction = 'correct';
  @Local reactKey: number = 0;
  @Local bubble: string = '';
  @Local feedbackTitle: string = '';
  @Local comboValue: number = 0;
  @Local showCombo: boolean = false;
  @Local floaters: number[] = [];
  @Local showQuit: boolean = false;
  @Local showOutOfHearts: boolean = false;
  @Local flash: number = 0;
  @Local showSettings: boolean = false;
  @Local showIntro: boolean = false;
  @Local showReport: boolean = false;
  @Local reportedKind: string = '';
  @Local sweep: number = 0;
  @Local tick: number = Date.now();
  private pendingHeartLosses: number = 0;
  private startedAt: string = isoString();
  private floaterSeq: number = 0;
  private timer: number = -1;
  private autoTimer: number = -1;
  @Local mHearts: number = ProgressStore.shared.hearts;
  // ---- 儿童模式 ----
  /** 进入课程时的模式快照（课中切换设置不影响本课）。 */
  private kids: boolean = SettingsStore.shared.kidsMode;
  private slots: LessonSlots = LessonSlots.none();
  @Local speedState: SpeedState = 'idle';
  @Local speedLeft: number = LessonSlots.speedSeconds;
  private speedDeadline: number = 0;
  private speedTimer: number = -1;
  private bonusXp: number = 0;
  @Local floatAmount: number = Economy.xpPerCorrect;
  private cardTeased: boolean = false;
  @Local showCardTease: boolean = false;
  private unsubStore: () => void = () => {
  };
  private unsubBack: () => void = () => {
  };

  /** 计入心魔的错题（踮脚题答错不算）。 */
  private get demonIds(): number[] {
    return this.kids ? this.missed.filter((id: number) => id !== this.slots.stretchId) : [];
  }

  private get lessonId(): string {
    return this.route.lessonId;
  }

  private get total(): number {
    return Math.max(1, this.lesson?.questions.length ?? 1);
  }

  private questionNumber(q: Question): number {
    const order = this.slots.arrange(this.lesson?.questions ?? []);
    return order.findIndex((item: Question) => item.id === q.id) + 1;
  }

  private get isExam(): boolean {
    return Economy.isExamLessonId(this.lessonId);
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.mHearts = this.store.hearts;
    });
    this.unsubBack = Router.shared.interceptBack(() => this.onSystemBack());
    try {
      const l = DataLoader.loadLesson(this.route.bookId, this.lessonId);
      this.lesson = l;
      this.slots = this.kids && !this.isExam ? LessonSlots.pick(l.questions) : LessonSlots.none();
      this.queue = this.slots.arrange(l.questions);
      const session = this.store.activeSession(this.lessonId);
      if (session !== null && (session.solvedIds.length > 0 || session.missedIds.length > 0)) {
        if (canResume(session, l)) {
          this.pendingResume = session;
        } else {
          this.store.clearLessonSession();
        }
      }
      if (this.pendingResume === null && l.knowledge !== undefined && l.knowledge !== null &&
        !this.store.isLessonCompleted(this.lessonId) && !this.store.hasSeenIntro(this.lessonId)) {
        this.showIntro = true;
      }
      if (!this.showIntro && this.pendingResume === null) {
        this.autoNarrate();
        this.armSlot();
      }
    } catch (e) {
      this.loadError = (e as Error).message;
    }

    this.timer = setInterval(() => {
      if (this.showOutOfHearts) {
        this.tick = Date.now();
        this.store.tickHeartRecharge();
      }
    }, 1000);
    this.speedTimer = setInterval(() => {
      if (this.speedState !== 'running') {
        return;
      }
      const left = Math.max(0, Math.ceil((this.speedDeadline - Date.now()) / 1000));
      if (left !== this.speedLeft) {
        this.speedLeft = left;
      }
      if (left <= 0) {
        this.speedState = 'expired';
      }
    }, 250);
  }

  aboutToDisappear(): void {
    clearInterval(this.timer);
    clearInterval(this.speedTimer);
    this.cancelAutoAdvance();
    this.unsubStore();
    this.unsubBack();
    AudioPlayer.shared.stop();
  }

  /** 系统返回：先收起弹层/面板，再走与关闭按钮相同的「确定退出」流程。 */
  private onSystemBack(): boolean {
    if (this.showSettings || this.showReport) {
      this.showSettings = false;
      this.showReport = false;
      return true;
    }
    if (this.showQuit) {
      this.showQuit = false;
      return true;
    }
    if (this.pendingResume !== null || this.showOutOfHearts) {
      Router.shared.pop();
      return true;
    }
    this.requestClose();
    return true;
  }

  private current(): Question | undefined {
    return this.index < this.queue.length ? this.queue[this.index] : undefined;
  }

  private autoNarrate(): void {
    const q = this.current();
    if (!this.settings.autoNarrate || this.settings.isMuted || q === undefined) {
      return;
    }
    AudioPlayer.shared.playOne(q.audio?.question);
  }

  /** 关闭按钮 / 系统返回。 */
  requestClose(): void {
    if (this.showIntro || this.lesson === null) {
      Router.shared.pop();
      return;
    }
    if (this.phase === 'checked' || this.solved.length > 0 || this.missed.length > 0) {
      Haptics.tap();
      this.showQuit = true;
    } else {
      Router.shared.pop();
    }
  }

  /** 进入一道题时：神速题第一次出现开始计时。 */
  private armSlot(): void {
    const q = this.current();
    if (q === undefined || q.id !== this.slots.speedId || this.speedState !== 'idle') {
      return;
    }
    this.speedDeadline = Date.now() + LessonSlots.speedSeconds * 1000;
    this.speedLeft = LessonSlots.speedSeconds;
    this.speedState = 'running';
  }

  private isSpeedBanner(q: Question): boolean {
    return q.id === this.slots.speedId &&
      (this.speedState === 'running' || this.speedState === 'expired' || this.speedState === 'hit');
  }

  private check(q: Question): void {
    const ok = gradeAnswer(q, this.answer);
    this.feedbackTitle = ok ? pickRandom(['太棒了！', '完美！', '做得好！', '天才！', '继续保持！', '漂亮！']) :
      pickRandom(['答错了', '差一点', '加油', '没关系', '下次就对！']);
    let speedBonus = 0;
    if (q.id === this.slots.speedId && (this.speedState === 'running' || this.speedState === 'expired')) {
      if (ok && this.speedState === 'running' && Date.now() <= this.speedDeadline) {
        speedBonus = LessonSlots.speedBonusXp(Economy.isWeekend(), this.isExam);
        this.bonusXp += speedBonus;
        this.speedState = 'hit';
        this.feedbackTitle = '神速！';
      } else {
        this.speedState = 'done';
      }
    }
    this.getUIContext().animateTo({ curve: Motion.reveal() }, () => {
      this.phase = 'checked';
      this.isCorrect = ok;
    });
    if (ok) {
      if (!this.solved.includes(q.id)) {
        this.solved = this.solved.concat([q.id]);
      }
      this.combo++;
      this.maxCombo = Math.max(this.maxCombo, this.combo);
      SFXEngine.shared.play('correct', this.combo - 1);
      Haptics.correct();
      const floatXp = Economy.xpPerCorrect * (this.isExam ? Economy.examXpMultiplier : 1) *
        (Economy.isWeekend() ? Economy.weekendXpMultiplier : 1);
      this.sessionXp += floatXp;
      this.floatAmount = floatXp + speedBonus;
      this.floaters = this.floaters.concat([++this.floaterSeq]);
      this.sweep++;
      this.maybeTeaseCard();
      const isMilestone = this.combo === 3 || this.combo === 5 || this.combo === 10;
      if (isMilestone) {
        const milestone = this.combo;
        setTimeout(() => {
          this.comboValue = milestone;
          this.showCombo = true;
          setTimeout(() => {
            this.showCombo = false;
          }, 1500);
        }, 320);
      }
      if (this.settings.autoAdvance) {
        this.scheduleAutoAdvance(isMilestone ? AUTO_ADVANCE_COMBO_MS : AUTO_ADVANCE_MS);
      }
    } else {
      this.attempted = true;
      if (!this.missed.includes(q.id)) {
        this.missed = this.missed.concat([q.id]);
      }
      this.combo = 0;
      this.queue = this.queue.concat([q]);
      SFXEngine.shared.play('wrong');
      Haptics.wrong();
      this.flash++;
      if (!this.kids) {
        this.pendingHeartLosses++;
        setTimeout(() => {
          this.store.loseHeart();
          SFXEngine.shared.play('heartLoss');
          Haptics.heartLoss();
          this.pendingHeartLosses = Math.max(0, this.pendingHeartLosses - 1);
        }, 400);
      }
      this.store.recordMistake(this.lessonId, this.lesson?.title ?? null, q);
    }
    const ctx = new MascotTriggerContext();
    ctx.isCorrect = ok;
    ctx.isPerfectSession = this.missed.length === 0;
    ctx.attemptCount = this.attempted ? 2 : 1;
    ctx.remainingHearts = this.kids ? Economy.maxHearts : Math.max(0, this.store.hearts - this.pendingHeartLosses);
    ctx.combo = this.combo;
    ctx.maxCombo = this.maxCombo;
    ctx.index = this.solved.length;
    ctx.total = this.total;
    this.mood = decideMood(ctx);
    this.reaction = decideReaction(ctx);
    this.reactKey++;
    this.bubble = ok ? pickBubble(this.mood) : '';
    this.persistSession();
  }

  private persistSession(): void {
    const l = this.lesson;
    if (l === null) {
      return;
    }
    const remaining = this.queue.slice(this.index + 1).map((q: Question) => q.id);
    if (this.solved.length >= this.total || remaining.length === 0) {
      return;
    }
    const s: ActiveLessonSession = {
      bookId: this.route.bookId,
      lessonId: this.lessonId,
      queueIds: remaining,
      solvedIds: this.solved.slice().sort((a: number, b: number) => a - b),
      missedIds: this.missed.slice().sort((a: number, b: number) => a - b),
      combo: this.combo,
      maxCombo: this.maxCombo,
      sessionXp: this.sessionXp,
      startedAt: this.startedAt,
      contentKey: lessonContentKey(l)
    };
    this.store.upsertLessonSession(s);
  }

  private applyResume(s: ActiveLessonSession): void {
    const l = this.lesson;
    if (l === null) {
      return;
    }
    const byId = new Map<number, Question>();
    l.questions.forEach((q: Question) => byId.set(q.id, q));
    const restored: Question[] = [];
    s.queueIds.forEach((id: number) => {
      const q = byId.get(id);
      if (q !== undefined) {
        restored.push(q);
      }
    });
    if (restored.length === 0 || !canResume(s, l)) {
      this.store.clearLessonSession();
      return;
    }
    this.queue = restored;
    this.index = 0;
    this.solved = s.solvedIds.filter((id: number) => byId.has(id));
    this.missed = s.missedIds.filter((id: number) => byId.has(id));
    this.combo = s.combo;
    this.maxCombo = s.maxCombo;
    this.sessionXp = s.sessionXp;
    this.startedAt = s.startedAt;
    this.answer = '';
    this.phase = 'answering';
    this.attempted = false;
    this.armSlot();
  }

  /** 答对到约 60% 时「知识卡现身」：预告完成本课就能收下（已是金卡则不打扰）。 */
  private maybeTeaseCard(): void {
    if (this.cardTeased || this.isExam || this.store.cardTier(this.lessonId) >= 3) {
      return;
    }
    if (this.solved.length < Math.max(1, Math.ceil(this.total * 0.6)) || this.solved.length >= this.total) {
      return;
    }
    this.cardTeased = true;
    setTimeout(() => {
      this.showCardTease = true;
      setTimeout(() => {
        this.showCardTease = false;
      }, 1800);
    }, 150);
  }

  private proceed(): void {
    if (!this.kids && !this.isCorrect && this.store.hearts - this.pendingHeartLosses <= 0) {
      this.showOutOfHearts = true;
      return;
    }
    this.advance();
  }

  /** 答对后自动进入下一题（减少点击、保持节奏）；打开了弹层/面板时不自动跳，等手动「继续」。 */
  private scheduleAutoAdvance(delayMs: number): void {
    this.cancelAutoAdvance();
    const idx = this.index;
    this.autoTimer = setTimeout(() => {
      this.autoTimer = -1;
      if (this.index !== idx || this.phase !== 'checked' || !this.isCorrect || this.showReport ||
        this.showSettings || this.showQuit) {
        return;
      }
      this.proceed();
    }, delayMs);
  }

  private cancelAutoAdvance(): void {
    if (this.autoTimer !== -1) {
      clearTimeout(this.autoTimer);
      this.autoTimer = -1;
    }
  }

  private advance(): void {
    this.cancelAutoAdvance();
    if (this.isCorrect) {
      SFXEngine.shared.play('progressTick');
    }
    Haptics.tap();
    const l = this.lesson;
    if (l === null) {
      return;
    }
    if (this.solved.length >= this.total || this.index + 1 >= this.queue.length) {
      this.finish(l);
      return;
    }
    this.index++;
    this.answer = '';
    this.isCorrect = false;
    this.phase = 'answering';
    this.attempted = false;
    if (this.speedState === 'hit') {
      this.speedState = 'done';
    }
    this.armSlot();
    setTimeout(() => this.autoNarrate(), 50);
  }

  private finish(l: Lesson): void {
    const correctCount = this.total - this.missed.length;
    const extras = new LessonExtras();
    extras.bookId = this.route.bookId;
    extras.lessonTitle = l.title;
    extras.demonQuestionIds = this.demonIds;
    extras.bonusXp = this.bonusXp;
    const outcome = this.store.completeLesson(this.lessonId, correctCount, this.total, new Date(), extras);
    Router.shared.replaceTop(AppRoute.resultOf(new LessonRunResult(this.route.bookId, this.lessonId, l.title, this.total,
      correctCount, outcome)));
  }

  private submitReport(kind: QuestionReportKind, q: Question): void {
    this.store.addReport(this.lessonId, q.id, kind, this.answer, q.question);
    Haptics.success();
    SFXEngine.shared.play('tap');
    this.reportedKind = kind;
    setTimeout(() => {
      this.showReport = false;
    }, 900);
  }

  // ---------------- 视图 ----------------

  @Builder
  header() {
    Row({ space: 14 }) {
      Stack() {
        DuoIcon({ name: 'xmark', sz: 20, color: C.inkMuted })
      }
      .width(36)
      .height(36)
      .responseRegion({ x: '-20%', y: '-20%', width: '140%', height: '140%' })
      .onClick(() => this.requestClose())
      .accessibilityText('关闭')

      ProgressBar({ progress: this.solved.length / this.total, barHeight: 16, trackColor: C.surfaceAlt,
        sweepTrigger: this.sweep, comboLevel: this.combo }).layoutWeight(1)
      if (this.isExam) {
        Text('⚔️×2').fontSize(13).fontWeight(W.black).fontColor(C.beetle)
          .padding({ left: 7, right: 7, top: 4, bottom: 4 }).backgroundColor(alpha(C.beetle, 0.16)).borderRadius(999)
      }
      if (Economy.isWeekend()) {
        Row({ space: 2 }) {
          DuoIcon({ name: 'bolt', sz: 11, color: C.bee })
          Text('×2').fontSize(13).fontWeight(W.black).fontColor(C.bee)
        }
        .padding({ left: 7, right: 7, top: 4, bottom: 4 })
        .backgroundColor(alpha(C.bee, 0.16))
        .borderRadius(999)
      }
      if (this.kids) {
        // 儿童模式：不显示红心，显示本课宝箱状态（有心魔 = 宝箱会被封存）。
        if (this.demonIds.length > 0) {
          Text(`👾 ${this.demonIds.length}`).fontSize(F.body).fontWeight(W.heavy).fontColor(C.fox)
            .accessibilityText(`${this.demonIds.length} 只心魔，下课后收服`)
        } else {
          Image($r('app.media.learning_chest')).width(28).height(25).objectFit(ImageFit.Contain)
            .accessibilityText('宝箱完好')
        }
      } else {
        Row({ space: 3 }) {
          DuoIcon({ name: 'heart', sz: 16, color: this.mHearts > 0 ? C.danger : C.inkSofter })
          Text(`${this.mHearts}`).fontSize(F.body).fontWeight(W.heavy)
            .fontColor(this.mHearts > 0 ? C.danger : C.inkSofter)
        }
      }

      Stack() {
        DuoIcon({ name: 'gear', sz: 17, color: C.inkSofter })
      }
      .width(32)
      .height(36)
      .responseRegion({ x: '-20%', y: '-20%', width: '140%', height: '140%' })
      .onClick(() => {
        Haptics.tap();
        this.showSettings = true;
      })
      .accessibilityText('课程设置')
      .bindSheet(this.showSettings, this.settingsSheet(), {
        height: 460, dragBar: true, backgroundColor: C.bg, onDisappear: () => {
          this.showSettings = false;
        }
      })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 6, bottom: 10 })
  }

  @Builder
  toggleRow(icon: string, title: string, subtitle: string, on: boolean, change: (v: boolean) => void) {
    Row({ space: 12 }) {
      DuoIcon({ name: icon, sz: 20, color: C.secondary }).width(30)
      Column({ space: 2 }) {
        Text(title).fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink)
        Text(subtitle).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: on })
        .selectedColor(C.primary)
        .onChange((v: boolean) => change(v))
    }
    .padding(12)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }

  @Builder
  settingsSheet() {
    Column({ space: 18 }) {
      Text('课堂设置').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink).width('100%')
      this.toggleRow('speaker', '音效', '答题反馈与庆祝的声音', !this.settings.isMuted,
        (v: boolean) => this.settings.setMuted(!v))
      this.toggleRow('vibrate', '触感振动', '答对答错时的轻微振动', this.settings.hapticEnabled,
        (v: boolean) => this.settings.setHaptic(v))
      this.toggleRow('bubbleText', '自动朗读', '进入新题目时自动朗读题干', this.settings.autoNarrate,
        (v: boolean) => this.settings.setAutoNarrate(v))
      this.toggleRow('bolt', '答对自动下一题', '关掉后可以慢慢看完解析再点「继续」', this.settings.autoAdvance,
        (v: boolean) => this.settings.setAutoAdvance(v))
      ChunkyButton({ label: '好了', onTap: () => {
        this.showSettings = false;
      } })
    }
    .padding({ left: 20, right: 20, top: 18, bottom: 20 })
  }

  @Builder
  reportSheet() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        DuoIcon({ name: 'flagFill', sz: 20, color: C.fox })
        Text('这道题怎么了？').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      }
      .width('100%')

      Text('你的反馈只保存在这台设备上，可在「设置」里查看。').fontSize(F.micro).fontColor(C.inkSofter).width('100%')
      ForEach(REPORT_KINDS, (k: QuestionReportKind) => {
        Row({ space: 12 }) {
          DuoIcon({ name: reportIcon(k), sz: 18, color: this.reportedKind === k ? C.primary : C.secondary }).width(28)
          Text(reportLabel(k)).fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink).layoutWeight(1)
          if (this.reportedKind === k) {
            DuoIcon({ name: 'checkCircle', sz: 20, color: C.primary })
          }
        }
        .padding(14)
        .width('100%')
        .backgroundColor(C.surface)
        .borderRadius(R.card)
        .border({ width: 2, color: this.reportedKind === k ? C.primary : C.border, radius: R.card })
        .onClick(() => {
          const q = this.current();
          if (this.reportedKind.length === 0 && q !== undefined) {
            this.submitReport(k, q);
          }
        })
      }, (k: QuestionReportKind) => `${k}-${this.reportedKind}`)
      if (this.reportedKind.length > 0) {
        Text('已记录，谢谢小侦探！🕵️').fontSize(F.caption).fontWeight(W.bold).fontColor(C.primary)
      }
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => {
        this.showReport = false;
      } })
    }
    .padding({ left: 20, right: 20, top: 18, bottom: 20 })
  }

  @Builder
  feedbackPanel(q: Question) {
    Column({ space: 14 }) {
      Row().width('100%').height(2).backgroundColor(C.border)
      Row({ space: 12 }) {
        Mascot({ mood: this.mood, sz: 54, reactTo: this.reaction, reactKey: this.reactKey })
        Column({ space: 3 }) {
          Text(this.feedbackTitle).fontSize(F.heading).fontWeight(W.heavy)
            .fontColor(this.isCorrect ? C.primary : C.danger)
          if (!this.isCorrect) {
            Text(`正确答案：${renderMathText(q.answer)}`).fontSize(F.caption).fontWeight(W.bold).fontColor(C.danger)
            if (this.kids) {
              Text(q.id === this.slots.stretchId ? '踮脚题敢挑战就很棒，不封宝箱！' : '心魔出现了，下课后去收服它就能拿回宝箱')
                .fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).lineHeight(19)
            }
          } else if (this.bubble.length > 0) {
            Text(this.bubble).fontSize(F.caption).fontWeight(W.bold).fontColor(alpha(C.primary, 0.85))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Stack() {
          DuoIcon({ name: 'flag', sz: 16, color: alpha(this.isCorrect ? C.primary : C.danger, 0.65) })
        }
        .width(34)
        .height(34)
        .responseRegion({ x: '-20%', y: '-20%', width: '140%', height: '140%' })
        .onClick(() => {
          Haptics.tap();
          this.reportedKind = '';
          this.showReport = true;
        })
        .bindSheet(this.showReport, this.reportSheet(), {
          height: 450, dragBar: true, backgroundColor: C.bg, onDisappear: () => {
            this.showReport = false;
          }
        })
        .accessibilityText('报告题目问题')
      }
      .width('100%')

      if (q.explanation.length > 0) {
        Row({ space: 8 }) {
          Text(renderMathText(q.explanation)).fontSize(F.body).fontWeight(W.medium).fontColor(C.inkMuted).layoutWeight(1)
          TTSButton({ path: q.audio?.explanation, sz: 16 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      ChunkyButton({ label: this.isCorrect ? '继续' : '知道了', variant: this.isCorrect ? 'primary' : 'danger',
        onTap: () => this.proceed() })
    }
    .padding({ left: 20, right: 20, top: 16, bottom: 28 })
    .width('100%')
    .backgroundColor(alpha(this.isCorrect ? C.primary : C.danger, 0.12))
    .transition(TransitionEffect.move(TransitionEdge.BOTTOM))
  }

  @Builder
  runner(q: Question) {
    Stack({ alignContent: Alignment.Top }) {
      if (this.store.equippedBackdropData !== undefined && (this.store.equippedBackdropData?.stops.length ?? 0) > 0) {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: (this.store.equippedBackdropData?.stops ?? []).map((c: string, i: number, arr: string[]) =>
            [c, arr.length > 1 ? i / (arr.length - 1) : 0] as [ResourceColor, number])
          })
          .opacity(this.store.equippedBackdropData?.needsOverlay ? 0.26 : 0.55)
      }
      Column() {
        this.header()
        Scroll() {
          Column({ space: S.xl }) {
            Column({ space: S.m }) {
              this.slotBanner(q)
              Row({ space: 8 }) {
                Text(instructionText(q.type)).fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
                Text(`第 ${this.questionNumber(q)} / ${this.total} 题`)
                  .fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
                  .padding({ left: 9, right: 9, top: 4, bottom: 4 }).backgroundColor(C.surfaceAlt).borderRadius(16)
              }
              .width('100%')
              Row({ space: 10 }) {
                Text(renderMathText(q.question)).fontSize(stemFontSize(q.question)).fontWeight(W.bold).fontColor(C.ink)
                  .lineHeight(stemFontSize(q.question) * 1.4).layoutWeight(1)
                TTSButton({ path: q.audio?.question })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }
            .margin({ top: 6 })

            if (this.lessonId === 'g1up-u1-kp2' && q.type === 'choice' &&
              q.question.trim() === '桌上有3个杯子和3个盖子，杯子和盖子的数量关系是？') {
              Image($r('app.media.lesson_cup_pairs')).width('100%').height(130).objectFit(ImageFit.Contain)
                .backgroundColor(C.tone('lesson_figure_bg')).borderRadius(R.card)
                .border({ width: 1, color: C.rewardBorder, radius: R.card }).clip(true)
                .accessibilityText('三个盖子和三个杯子，上下各成一对')
            }
            QuestionRenderer({
              question: q, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
              qKey: `${q.id}-${this.index}`, onAnswer: (a: string) => {
                this.answer = a;
              }
            })
          }
          .padding({ left: 20, right: 20, bottom: 24 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        if (this.phase === 'checked') {
          this.feedbackPanel(q)
        } else {
          Column() {
            ChunkyButton({ label: '检查', variant: this.answer.trim().length === 0 ? 'disabled' : 'primary',
              onTap: () => this.check(q) })
          }
          .padding({ left: 20, right: 20, top: 14, bottom: 28 })
          .backgroundColor(C.bg)
        }
      }
      .width('100%')
      .height('100%')

      ForEach(this.floaters, (id: number) => {
        XPFloater({
          amount: this.floatAmount, onDone: () => {
            this.floaters = this.floaters.filter((x: number) => x !== id);
          }
        }).margin({ top: 300 })
      }, (id: number) => `${id}`)
      if (this.showCombo) {
        ComboOverlay({ combo: this.comboValue }).margin({ top: 240 })
      }
      if (this.showCardTease) {
        this.cardTease()
      }
      WrongFlash({ trigger: this.flash })
    }
    .width('100%')
    .height('100%')
  }

  /** 神速 / 踮脚题位横幅。 */
  @Builder
  slotBanner(q: Question) {
    if (this.isSpeedBanner(q)) {
      Row({ space: 8 }) {
        DuoIcon({ name: 'bolt', sz: 18, color: '#FFFFFF' })
        Text(this.speedState === 'hit' ? `神速成功！XP ×2` :
          (this.speedState === 'expired' ? '时间到啦，慢慢做也没关系' : `神速挑战 · ${LessonSlots.speedSeconds} 秒内答对 XP ×2`))
          .fontSize(F.caption).fontWeight(W.heavy).fontColor('#FFFFFF').layoutWeight(1)
        if (this.speedState === 'running') {
          Text(`${this.speedLeft}s`).fontSize(F.subhead).fontWeight(W.black).fontColor('#FFFFFF')
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .borderRadius(R.card)
      .linearGradient({
        angle: 90,
        colors: this.speedState === 'expired' ? [[C.inkSofter, 0], [C.inkMuted, 1]] : [[C.bee, 0], [C.fox, 1]]
      })
    } else if (q.id === this.slots.stretchId) {
      Row({ space: 8 }) {
        Text('🦶').fontSize(F.body)
        Text('踮脚题 · 难一点点，答错也不会封宝箱').fontSize(F.caption).fontWeight(W.heavy).fontColor(C.beetle)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .borderRadius(R.card)
      .backgroundColor(alpha(C.beetle, 0.12))
      .border({ width: 1.5, color: alpha(C.beetle, 0.35), radius: R.card })
    }
  }

  /** 「知识卡现身」预告（不拦截点击）。 */
  @Builder
  cardTease() {
    Row({ space: 12 }) {
      Column() {
        DuoIcon({ name: 'sparkles', sz: 22, color: '#FFFFFF' })
      }
      .width(44)
      .height(58)
      .justifyContent(FlexAlign.Center)
      .borderRadius(8)
      .linearGradient({ angle: 135, colors: [[C.secondary, 0], [C.beetle, 1]] })
      Column({ space: 2 }) {
        Text('知识卡现身！').fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink)
        Text(this.store.cardTier(this.lessonId) > 0 ? '全对通关可以升级这张卡' : '完成这一课就能收下它')
          .fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding({ left: 12, right: 18, top: 10, bottom: 10 })
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: alpha(C.beetle, 0.5), radius: R.card })
    .shadow({ radius: 12, color: alpha(C.beetle, 0.25), offsetY: 4 })
    .margin({ top: 64 })
    .hitTestBehavior(HitTestMode.None)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -20 })))
  }

  @Builder
  outOfHearts() {
    ModalCard() {
      DuoIcon({ name: 'heartSlash', sz: 60, color: C.danger })
      Text('红心用完了').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
      if (this.store.nextHeartAtMs !== null) {
        Column({ space: 2 }) {
          Text('下一颗红心还需').fontSize(F.caption).fontColor(C.inkMuted)
          Text(formatCountdown(this.store.nextHeartAtMs as number, this.tick)).fontSize(F.title).fontWeight(W.heavy)
            .fontColor(C.danger)
        }
      }
      ChunkyButton({
        label: `用宝石补满  ${Economy.heartRefillCost}`, icon: 'gem',
        variant: this.store.gems >= Economy.heartRefillCost ? 'secondary' : 'disabled',
        onTap: () => {
          if (this.store.buyHeartRefill(Economy.heartRefillCost)) {
            Haptics.success();
            SFXEngine.shared.play('purchase');
            this.showOutOfHearts = false;
            this.advance();
          } else {
            Haptics.wrong();
          }
        }
      })
      if (this.store.dueMistakes.length > 0) {
        ChunkyButton({ label: '做一组复习回 1 颗红心 ❤️', onTap: () => {
          Haptics.tap();
          Router.shared.replaceTop(new AppRoute('reviewRunner'));
        } })
        Text('这节课已帮你记住进度，复习完回来接着学').fontSize(F.micro).fontColor(C.inkMuted).textAlign(TextAlign.Center)
      }
      ChunkyButton({ label: '退出练习', variant: 'ghost', onTap: () => Router.shared.pop() })
    }
  }

  @Builder
  quitConfirm() {
    ModalCard({ onBackdrop: () => {
      this.showQuit = false;
    } }) {
      Mascot({ mood: 'sad', sz: 92 })
      Text('再坚持一下，快完成了！').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink).textAlign(TextAlign.Center)
      Text(`已答对 ${this.solved.length} / ${this.total} 题，现在放弃太可惜啦`).fontSize(F.caption).fontColor(C.inkMuted)
        .textAlign(TextAlign.Center)
      ChunkyButton({ label: '继续学习', onTap: () => {
        Haptics.tap();
        this.showQuit = false;
      } })
      ChunkyButton({ label: '退出', variant: 'ghost', onTap: () => {
        this.store.clearLessonSession();
        Router.shared.pop();
      } })
    }
  }

  @Builder
  resumePrompt() {
    ModalCard() {
      Mascot({ mood: 'wave', sz: 92 })
      Text('上次学到一半哦').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text(`已答对 ${this.pendingResume?.solvedIds.length ?? 0} / ${this.total} 题，接着做还是重新来？`)
        .fontSize(F.caption).fontColor(C.inkMuted).textAlign(TextAlign.Center)
      ChunkyButton({ label: `继续上次（第 ${(this.pendingResume?.solvedIds.length ?? 0) + 1} 题）`, onTap: () => {
        Haptics.tap();
        if (this.pendingResume !== null) {
          this.applyResume(this.pendingResume);
        }
        this.pendingResume = null;
        this.autoNarrate();
      } })
      ChunkyButton({ label: '重新开始', variant: 'ghost', onTap: () => {
        Haptics.tap();
        this.store.clearLessonSession();
        this.pendingResume = null;
        this.autoNarrate();
        this.armSlot();
      } })
    }
  }

  build() {
    Stack() {
      Stack() {
        if (this.showIntro && this.lesson !== null && this.lesson.knowledge !== undefined && this.lesson.knowledge !== null) {
          IntroCard({
            lesson: this.lesson, knowledge: this.lesson.knowledge,
            onStart: () => {
              this.store.markIntroSeen(this.lessonId);
              this.showIntro = false;
              this.autoNarrate();
              this.armSlot();
            },
            onExit: () => Router.shared.pop()
          })
        } else if (this.lesson !== null && this.current() !== undefined) {
          ForEach([this.current() as Question], (q: Question) => {
            this.runner(q)
          }, (q: Question) => `${this.index}-${q.id}`)
        } else if (this.loadError.length > 0) {
          Column({ space: S.m }) {
            Text('加载失败').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
            Text(this.loadError).fontSize(F.caption).fontColor(C.inkMuted)
            ChunkyButton({ label: '返回', variant: 'ghost', onTap: () => Router.shared.pop() }).width(200)
          }
        } else {
          LoadingProgress().width(40).color(C.primary)
        }
      }
      .width('100%')
      .height('100%')
      .accessibilityLevel(this.showOutOfHearts || this.showQuit || this.pendingResume !== null ?
        'no-hide-descendants' : 'auto')
      if (this.showOutOfHearts) {
        this.outOfHearts()
      }
      if (this.showQuit) {
        this.quitConfirm()
      }
      if (this.pendingResume !== null) {
        this.resumePrompt()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 答错时的全屏红闪。 */
@ComponentV2
export struct WrongFlash {
  @Param trigger: number = 0;
  @Local op: number = 0;

  @Monitor('trigger')
  onTrigger(): void {
    this.op = 0.18;
    this.getUIContext().animateTo({ duration: 450, curve: Curve.EaseOut }, () => {
      this.op = 0;
    });
  }

  build() {
    Column().width('100%').height('100%').backgroundColor(C.danger).opacity(this.op).hitTestBehavior(HitTestMode.None)
  }
}

class IntroPage {
  tone: string;
  title: string;
  icon: string;
  accent: string;
  mood: MascotMood;
  bubble: string;
  audio: (string | null | undefined)[];
  titleAudio: string | null | undefined;

  constructor(tone: string, title: string, icon: string, accent: string, mood: MascotMood, bubble: string,
    audio: (string | null | undefined)[], titleAudio: string | null | undefined) {
    this.tone = tone;
    this.title = title;
    this.icon = icon;
    this.accent = accent;
    this.mood = mood;
    this.bubble = bubble;
    this.audio = audio;
    this.titleAudio = titleAudio;
  }
}

/** 课前知识讲解卡片（IntroCardView）。 */
@ComponentV2
export struct IntroCard {
  @Param lesson: Lesson | undefined = undefined;
  @Param knowledge: KnowledgeSummary | undefined = undefined;
  @Event onStart: () => void = () => {
  };
  @Event onExit: () => void = () => {
  };
  @Local pageIdx: number = 0;
  @Local reactKey: number = 0;

  private pages(): IntroPage[] {
    const k = this.knowledge;
    const out: IntroPage[] = [];
    if (k === undefined) {
      return out;
    }
    if (k.core_concept.length > 0) {
      out.push(new IntroPage('concept', '这是什么？', 'book', C.secondary, 'think', '一起学！', [k.audio?.core_concept],
        k.audio?.core_concept));
    }
    if (k.key_formula.length > 0) {
      out.push(new IntroPage('rule', '记住这个！', 'target', C.primary, 'wave', '超级重要!', [k.audio?.key_formula],
        k.audio?.key_formula));
    }
    if (k.common_mistakes.length > 0) {
      out.push(new IntroPage('mistake', '小心这些坑！', 'xmarkCircle', C.danger, 'surprise', '别踩坑哦!',
        k.audio?.common_mistakes ?? [], null));
    }
    if (k.tips.length > 0) {
      out.push(new IntroPage('tip', '学习小妙招', 'bolt', C.bee, 'cheer', '你最棒!', [k.audio?.tips], k.audio?.tips));
    }
    return out;
  }

  aboutToAppear(): void {
    const all = this.pages();
    if (all.length === 0) {
      setTimeout(() => this.onStart(), 0);
      return;
    }
    this.enter(all[0]);
  }

  aboutToDisappear(): void {
    AudioPlayer.shared.stop();
  }

  private enter(p: IntroPage): void {
    this.reactKey++;
    SFXEngine.shared.play('progressTick');
    if (!SettingsStore.shared.autoNarrate || SettingsStore.shared.isMuted) {
      return;
    }
    const paths = p.audio.filter((x: string | null | undefined) => x !== null && x !== undefined);
    if (paths.length > 0) {
      AudioPlayer.shared.play(paths);
    }
  }

  private go(delta: number): void {
    const all = this.pages();
    Haptics.tap();
    SFXEngine.shared.play('tap');
    this.getUIContext().animateTo({ curve: Motion.bounce() }, () => {
      this.pageIdx = Math.max(0, Math.min(all.length - 1, this.pageIdx + delta));
    });
    this.enter(all[this.pageIdx]);
  }

  @Builder
  body(p: IntroPage) {
    if (p.tone === 'concept' || p.tone === 'tip') {
      Text(renderMathText(p.tone === 'concept' ? this.knowledge?.core_concept : this.knowledge?.tips))
        .fontSize(F.subhead).fontWeight(W.medium).fontColor(C.ink).lineHeight(28).textAlign(TextAlign.Center)
    } else if (p.tone === 'rule') {
      Text(renderMathText(this.knowledge?.key_formula))
        .fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink).lineHeight(32).textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 16, right: 16, top: 20, bottom: 20 })
        .backgroundColor(C.surfaceAlt)
        .borderRadius(R.card)
        .border({ width: 2, color: C.border, radius: R.card })
    } else {
      Column({ space: 10 }) {
        ForEach(this.knowledge?.common_mistakes ?? [], (m: string, i: number) => {
          Row({ space: 10 }) {
            DuoIcon({ name: 'xmarkCircle', sz: 18, color: C.danger }).margin({ top: 2 })
            Text(renderMathText(m)).fontSize(F.body).fontWeight(W.medium).fontColor(C.ink).lineHeight(22).layoutWeight(1)
            TTSButton({ path: (this.knowledge?.audio?.common_mistakes ?? [])[i], sz: 15 })
          }
          .alignItems(VerticalAlign.Top)
          .padding(12)
          .width('100%')
          .backgroundColor(alpha(C.danger, 0.07))
          .borderRadius(R.card)
          .border({ width: 2, color: alpha(C.danger, 0.25), radius: R.card })
        }, (m: string, i: number) => `${i}`)
      }
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Stack() {
          DuoIcon({ name: 'xmark', sz: 20, color: C.inkMuted })
        }
        .width(36)
        .height(36)
        .responseRegion({ x: '-20%', y: '-20%', width: '140%', height: '140%' })
        .onClick(() => {
          Haptics.tap();
          this.onExit();
        })
        .accessibilityText('关闭')

        Row({ space: 6 }) {
          ForEach(this.pages(), (p: IntroPage, i: number) => {
            Row()
              .width(i === this.pageIdx ? 24 : 8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(i <= this.pageIdx ? p.accent : C.surfaceAlt)
              .animation({ curve: Motion.bounce() })
          }, (p: IntroPage, i: number) => `${i}`)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)

        Text(`${this.pageIdx + 1}/${this.pages().length}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.inkSofter)
          .width(40).textAlign(TextAlign.End)
      }
      .padding({ left: 18, right: 18, top: 6, bottom: 8 })
      .border({ width: { bottom: 1 }, color: C.border })

      Column({ space: 2 }) {
        Text(`第 ${this.lesson?.unitNumber ?? 0} 单元 · ${this.lesson?.unitTitle ?? ''}`).fontSize(F.micro).fontWeight(W.bold)
          .fontColor(C.inkSofter).letterSpacing(1)
        Text(this.lesson?.title ?? '').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(1)
      }
      .padding({ top: 8, left: 20, right: 20 })

      if (this.pages().length > 0) {
        Scroll() {
          Column({ space: 16 }) {
            Row({ space: 8 }) {
              Mascot({ mood: this.pages()[this.pageIdx].mood, sz: 84, reactTo: 'levelup', reactKey: this.reactKey })
              SpeechBubble({ text: this.pages()[this.pageIdx].bubble, mood: this.pages()[this.pageIdx].mood })
                .margin({ bottom: 14 })
            }
            .alignItems(VerticalAlign.Bottom)
            .margin({ top: 12 })

            Stack() {
              Circle().width(76).height(76).fill(alpha(this.pages()[this.pageIdx].accent, 0.15))
              DuoIcon({ name: this.pages()[this.pageIdx].icon, sz: 34, color: this.pages()[this.pageIdx].accent })
            }

            Row({ space: 10 }) {
              Text(this.pages()[this.pageIdx].title).fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
              TTSButton({ path: this.pages()[this.pageIdx].titleAudio })
            }

            Column() {
              ForEach([this.pageIdx], (i: number) => {
                this.body(this.pages()[this.pageIdx])
              }, (i: number) => `${i}`)
            }
            .padding({ left: 24, right: 24, bottom: 24 })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }

      Row({ space: 12 }) {
        if (this.pageIdx > 0) {
          Stack() {
            DuoIcon({ name: 'chevronLeft', sz: 18, color: C.inkMuted })
          }
          .width(56)
          .height(50)
          .backgroundColor(C.surface)
          .borderRadius(R.card)
          .border({ width: 2, color: C.border, radius: R.card })
          .onClick(() => this.go(-1))
          .accessibilityText('上一步')
        }
        ChunkyButton({
          label: this.pageIdx >= this.pages().length - 1 ? '开始做题' : '下一步', onTap: () => {
            if (this.pageIdx >= this.pages().length - 1) {
              SFXEngine.shared.play('unlock');
              Haptics.success();
              AudioPlayer.shared.stop();
              this.onStart();
            } else {
              this.go(1);
            }
          }
        }).layoutWeight(1)
      }
      .padding({ left: 20, right: 20, top: 12, bottom: 28 })
      .border({ width: { top: 1 }, color: C.border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
