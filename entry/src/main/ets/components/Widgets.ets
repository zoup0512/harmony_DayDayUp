// 复用卡片与小部件：连胜日历、每日目标环、每日任务、周报、下载卡、朗读按钮、底部 Tab。
import { C, CONTENT_MAX_W, F, R, W, alpha } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { dateKey, weekdayLabel } from '../domain/Dates';
import { Quest } from '../domain/Seeded';
import { PassageSentence } from '../models/Types';
import { DayXp, ProgressStore } from '../stores/ProgressStore';
import { SettingsStore } from '../stores/SettingsStore';
import { AssetDownloader } from '../services/AssetDownloader';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { ChunkyButton, DuoIcon, IconBadge, ProgressBar, SmallChunkyButton } from './Kit';

export class CalendarDay {
  dateKey: string;
  studied: boolean;

  constructor(dateKey: string, studied: boolean) {
    this.dateKey = dateKey;
    this.studied = studied;
  }
}

export function weekCalendar(entries: DayXp[]): CalendarDay[] {
  return entries.map((d: DayXp) => new CalendarDay(d.date, d.xp > 0));
}

/** 本周 7 格火焰日历（StreakCalendarView）。 */
@ComponentV2
export struct StreakCalendar {
  @Param entries: CalendarDay[] = [];
  @Param todayIndex: number = 0;
  @Param todayStudied: boolean = false;
  @Param onDark: boolean = false;

  build() {
    Row({ space: 4 }) {
      ForEach(this.entries, (e: CalendarDay, i: number) => {
        Column({ space: 6 }) {
          Text(i === this.todayIndex ? '今' : weekdayLabel(e.dateKey))
            .fontSize(12)
            .fontWeight(W.heavy)
            .fontColor(i === this.todayIndex ? C.fox : (this.onDark ? '#CCFFFFFF' : C.inkMuted))
          Stack() {
            Circle().width(34).height(34)
              .fill((i === this.todayIndex ? this.todayStudied : e.studied) ? C.fox : (this.onDark ? '#38FFFFFF' : C.surfaceAlt))
            if (i === this.todayIndex ? this.todayStudied : e.studied) {
              DuoIcon({ name: 'flame', sz: 15, color: '#FFFFFF' })
            } else {
              Circle().width(6).height(6).fill(alpha(C.inkSofter, 0.35))
            }
            if (i === this.todayIndex) {
              Circle().width(42).height(42).fill(Color.Transparent).stroke(C.fox).strokeWidth(2)
            }
          }
          .width(42)
          .height(42)
        }
        .layoutWeight(1)
      }, (e: CalendarDay, i: number) => `${e.dateKey}-${i}-${e.studied}`)
    }
    .width('100%')
    .accessibilityText('本周学习日历')
  }
}

/** 今日 XP 进度环；点击弹出调整每日目标。 */
@ComponentV2
export struct DailyGoalRing {
  @Param sz: number = 72;
  @Param captionMode: 'none' | 'compact' | 'full' = 'none';
  @Local showSheet: boolean = false;
  store: ProgressStore = ProgressStore.shared;

  private progress(): number {
    const g = this.store.dailyGoal;
    return g > 0 ? Math.min(1, this.store.todayXp / g) : 0;
  }

  @Builder
  goalSheet() {
    Column({ space: 20 }) {
      Text('每日目标').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text('选择你的每日 XP 目标').fontSize(F.body).fontColor(C.inkLight)
      Grid() {
        ForEach(Economy.dailyGoalOptions, (goal: number) => {
          GridItem() {
            Column({ space: 4 }) {
              Text(`${goal}`).fontSize(F.heading).fontWeight(W.heavy)
                .fontColor(this.store.dailyGoal === goal ? '#FFFFFF' : C.ink)
              Text('XP').fontSize(F.caption).fontWeight(W.bold)
                .fontColor(this.store.dailyGoal === goal ? '#FFFFFF' : C.ink)
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .backgroundColor(this.store.dailyGoal === goal ? C.primary : C.bgSofter)
            .borderRadius(14)
            .onClick(() => {
              this.store.setDailyGoal(goal);
              this.showSheet = false;
            })
          }
        }, (goal: number) => `${goal}`)
      }
      .columnsTemplate('1fr 1fr')
      .rowsGap(12)
      .columnsGap(12)
      .height(180)
    }
    .padding(24)
    .width('100%')
  }

  @Builder
  ring() {
    Stack() {
      Progress({ value: 100, total: 100, type: ProgressType.Ring })
        .width(this.sz)
        .height(this.sz)
        .color(C.bgSofter)
        .style({ strokeWidth: Math.max(5, this.sz * 0.11) })
      Progress({ value: this.progress() * 100, total: 100, type: ProgressType.Ring })
        .width(this.sz)
        .height(this.sz)
        .color(this.progress() >= 1 ? C.bee : C.primary)
        .style({ strokeWidth: Math.max(5, this.sz * 0.11), shadow: true })
      Column({ space: 1 }) {
        if (this.progress() >= 1) {
          DuoIcon({ name: 'checkCircle', sz: this.sz * 0.26, color: C.primary })
        } else {
          DuoIcon({ name: 'bolt', sz: this.captionMode === 'compact' ? 14 : this.sz * 0.22, color: C.primaryDark })
        }
        if (this.captionMode !== 'compact') {
          Text(`${this.store.todayXp}`).fontSize(this.sz * 0.24).fontWeight(W.heavy).fontColor(C.ink)
        }
      }
    }
    .width(this.sz)
    .height(this.sz)
  }

  build() {
    Row({ space: this.captionMode === 'compact' ? 5 : 12 }) {
      this.ring()
      if (this.captionMode !== 'none') {
        Column({ space: 3 }) {
          Text('今日目标').fontSize(this.captionMode === 'compact' ? F.micro : F.body)
            .fontWeight(W.heavy).fontColor(C.ink)
          Text(`${this.store.todayXp} / ${this.store.dailyGoal}${this.captionMode === 'full' ? ' XP · 点圆环修改' : ''}`)
            .fontSize(this.captionMode === 'compact' ? F.micro : F.caption).fontColor(C.inkMuted)
          if (this.captionMode === 'full' && this.store.dailyGoalReached) {
            Text('今日目标已完成').fontSize(F.micro).fontWeight(W.bold).fontColor(C.primary)
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width(this.captionMode === 'full' ? '100%' : undefined)
    .onClick(() => {
      this.showSheet = true;
    })
    .bindSheet(this.showSheet, this.goalSheet(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      backgroundColor: C.bg,
      onDisappear: () => {
        this.showSheet = false;
      }
    })
    .accessibilityText(`今日经验 ${this.store.todayXp} / ${this.store.dailyGoal}`)
  }
}

/** 每日任务卡（DailyQuestsCard）。 */
@ComponentV2
export struct DailyQuestsCard {
  store: ProgressStore = ProgressStore.shared;

  @Builder
  row(q: Quest) {
    Row({ space: 9 }) {
      Stack() {
        DuoIcon({ name: this.store.isQuestClaimed(q) ? 'check' : q.icon, sz: 17,
          color: this.store.isQuestComplete(q) ? C.primaryDark : C.fox })
      }
      .width(31)
      .height(31)
      .backgroundColor(alpha(this.store.isQuestComplete(q) ? C.primary : C.fox, 0.16))
      .borderRadius(10)
      Column({ space: 3 }) {
        Text(q.title)
          .fontSize(F.caption)
          .fontWeight(W.bold)
          .fontColor(this.store.isQuestClaimed(q) ? C.inkSofter : C.ink)
          .decoration({ type: this.store.isQuestClaimed(q) ? TextDecorationType.LineThrough : TextDecorationType.None })
        Row({ space: 8 }) {
          ProgressBar({
            progress: Math.min(this.store.questProgress(q), q.target) / Math.max(1, q.target),
            barHeight: 6,
            fillColor: this.store.isQuestComplete(q) ? C.primary : C.fox,
            trackColor: C.surfaceAlt
          }).layoutWeight(1)
          Text(`${Math.min(this.store.questProgress(q), q.target)}/${q.target}`)
            .fontSize(F.micro).fontWeight(W.heavy).fontColor(C.inkMuted)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (!this.store.isQuestClaimed(q) && this.store.isQuestComplete(q)) {
        SmallChunkyButton({
          label: `领取 ${q.reward}`, icon: 'gem', bgColor: C.primaryDark, shadowColor: C.primaryDark,
          onTap: () => {
            if (this.store.claimQuest(q)) {
              Haptics.success();
              SFXEngine.shared.play('questClaim');
            }
          }
        }).width(88).accessibilityText(`${q.title}，领取 ${q.reward} 宝石`)
      } else if (this.store.isQuestClaimed(q)) {
        Text('已领取').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      } else {
        Row({ space: 3 }) {
          DuoIcon({ name: 'gem', sz: 13, color: C.beetle })
          Text(`${q.reward}`).fontSize(F.micro).fontWeight(W.heavy).fontColor(C.inkMuted)
        }
        .width(36)
        .justifyContent(FlexAlign.Center)
        .accessibilityText(`奖励 ${q.reward} 宝石`)
      }
    }
    .width('100%')
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        DuoIcon({ name: 'flag', sz: 18, color: C.primaryDark })
        Text('每日任务').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink).layoutWeight(1)
        if (this.store.claimableQuestCount > 0) {
          Text(`${this.store.claimableQuestCount} 个可领取`).fontSize(F.micro).fontWeight(W.bold).fontColor('#FFFFFF')
            .padding({ left: 9, right: 9, top: 4, bottom: 4 }).backgroundColor(C.fox).borderRadius(999)
        } else {
          Text('每天 0 点刷新').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkSofter)
        }
      }
      .width('100%')

      ForEach(this.store.todayQuests, (q: Quest) => {
        this.row(q)
      }, (q: Quest) => `${q.id}-${this.store.progress.claimedQuests?.length ?? 0}`)
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }
}

/** 本周报告卡（WeeklyReportCard）。 */
@ComponentV2
export struct WeeklyReportCard {
  store: ProgressStore = ProgressStore.shared;

  @Builder
  stat(label: string, value: string, tint: string) {
    Column({ space: 1 }) {
      Text(value).fontSize(F.caption).fontWeight(W.heavy).fontColor(tint)
      Text(label).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkSofter)
    }
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 14 }) {
      Row({ space: 8 }) {
        DuoIcon({ name: 'chart', sz: 16, color: C.secondary })
        Text('本周报告').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink).layoutWeight(1)
        if (this.store.weeklyTotal(1) === 0 && this.store.weeklyTotal(0) === 0) {
          Text('本周还没开始').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkSofter)
        } else {
          Row({ space: 3 }) {
            DuoIcon({ name: this.store.weeklyTotal(0) >= this.store.weeklyTotal(1) ? 'arrowUpRight' : 'arrowDown', sz: 10,
              color: this.store.weeklyTotal(0) >= this.store.weeklyTotal(1) ? C.primary : C.fox })
            Text(`${Math.abs(this.store.weeklyTotal(0) - this.store.weeklyTotal(1))} XP`).fontSize(F.micro).fontWeight(W.heavy)
              .fontColor(this.store.weeklyTotal(0) >= this.store.weeklyTotal(1) ? C.primary : C.fox)
          }
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(alpha(this.store.weeklyTotal(0) >= this.store.weeklyTotal(1) ? C.primary : C.fox, 0.14))
          .borderRadius(999)
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(this.store.weekXPEntries(), (d: DayXp) => {
          Column({ space: 6 }) {
            Stack({ alignContent: Alignment.Bottom }) {
              Column().width('100%').height(68).backgroundColor(C.surfaceAlt).borderRadius(4)
              Column()
                .width('100%')
                .height(Math.max(d.xp > 0 ? 6 : 0, 68 * d.xp / Math.max(1, ...this.store.weekXPEntries().map((x: DayXp) => x.xp))))
                .backgroundColor(d.date === dateKey() ? C.primary : C.secondary)
                .borderRadius(4)
            }
            .width('100%')
            .height(68)

            Text(weekdayLabel(d.date)).fontSize(F.micro).fontWeight(W.bold)
              .fontColor(d.date === dateKey() ? C.ink : C.inkMuted)
          }
          .layoutWeight(1)
        }, (d: DayXp) => `${d.date}-${d.xp}`)
      }
      .width('100%')

      Row({ space: 18 }) {
        this.stat('本周', `${this.store.weeklyTotal(0)} XP`, C.ink)
        this.stat('上周', `${this.store.weeklyTotal(1)} XP`, C.inkMuted)
        this.stat('最佳', `${Math.max(0, ...this.store.weekXPEntries().map((x: DayXp) => x.xp))} XP`, C.inkMuted)
      }
      .width('100%')
    }
    .padding(16)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }
}

/** 下载课本内容卡（BookDownloadCard）。 */
@ComponentV2
export struct BookDownloadCard {
  @Param bookId: string = '';
  @Event onComplete: () => void = () => {
  };
  dl: AssetDownloader = AssetDownloader.shared;

  build() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        DuoIcon({ name: 'downloadCircle', sz: 30, color: C.secondary })
        Column({ space: 2 }) {
          Text('下载课本内容').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink)
          Text(`含课程与音频 · ${this.dl.entry(this.bookId).lessonsCount} 课`)
            .fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (this.dl.inFlight.has(this.bookId)) {
        Column({ space: 6 }) {
          ProgressBar({ progress: this.dl.bookProgress.get(this.bookId) ?? 0, barHeight: 12, trackColor: C.surfaceAlt })
          Text(`${Math.floor((this.dl.bookProgress.get(this.bookId) ?? 0) * 100)}%`)
            .fontSize(F.caption).fontWeight(W.heavy).fontColor(C.secondary).width('100%').textAlign(TextAlign.End)
        }
      } else if (this.dl.lastError !== null) {
        Text(this.dl.lastError).fontSize(F.caption).fontColor(C.danger).width('100%')
      }

      ChunkyButton({
        label: this.dl.inFlight.has(this.bookId) ? '下载中…' : (this.dl.lastError !== null ? '重试下载' : '下载课本'),
        variant: this.dl.inFlight.has(this.bookId) ? 'disabled' : 'secondary',
        onTap: () => {
          const id = this.bookId;
          if (id.length === 0) {
            return;
          }
          this.dl.ensureBookDownloaded(id).then(() => {
            if (this.dl.isBookDownloaded(id)) {
              Haptics.success();
              this.onComplete();
            }
          }).catch(() => {
          });
        }
      })
    }
    .padding(16)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }
}

/** 朗读按钮；长按切换乌龟慢速；highlightIndex 让课文高亮对应句。 */
@ComponentV2
export struct TTSButton {
  @Param path: string | null | undefined = undefined;
  @Param sz: number = 20;
  @Param highlightIndex: number = -1;
  @Param slowCapable: boolean = false;
  player: AudioPlayer = AudioPlayer.shared;
  settings: SettingsStore = SettingsStore.shared;
  /** AudioPlayer 的 @Trace 直读不触发重绘，靠 onChange 同步到这两个镜像。 */
  @Local playing: boolean = false;
  @Local slow: boolean = false;
  private ownRunId: number = -1;
  private unsubPlayer: () => void = () => {
  };

  aboutToAppear(): void {
    this.syncPlayer();
    this.unsubPlayer = this.player.onChange(() => this.syncPlayer());
  }

  aboutToDisappear(): void {
    this.unsubPlayer();
  }

  /** 课文句（highlightIndex ≥ 0）：单句或「朗读全文」播到这一句都高亮；其它按钮只认自己发起的那次播放。 */
  private syncPlayer(): void {
    const p = this.player;
    this.playing = p.isPlaying &&
      (this.highlightIndex >= 0 ? p.nowPlayingIndex === this.highlightIndex : p.currentRunId === this.ownRunId);
    this.slow = p.isSlowMode;
  }

  build() {
    if (this.player.canPlay(this.path)) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Stack() {
          DuoIcon({ name: this.settings.isMuted ? 'speakerSlash' : 'speaker', sz: this.sz,
            color: this.playing ? '#FFFFFF' : C.primary })
        }
        .padding(8)
        .backgroundColor(this.playing ? C.primary : alpha(C.primary, 0.12))
        .borderRadius(999)

        if (this.slowCapable && this.slow) {
          Text('🐢').fontSize(this.sz * 0.6)
        }
      }
      .constraintSize({ minWidth: 44, minHeight: 44 })
      .align(Alignment.Center)
      .onClick(() => {
        if (this.highlightIndex > 0) {
          const paths: (string | null)[] = [];
          for (let i = 0; i < this.highlightIndex; i++) {
            paths.push(null);
          }
          paths.push(this.path ?? null);
          this.player.play(paths);
        } else {
          this.player.playOne(this.path);
        }
        this.ownRunId = this.player.currentRunId;
        this.syncPlayer();
      })
      .gesture(LongPressGesture({ duration: 450 }).onAction(() => {
        if (this.slowCapable) {
          this.player.setSlowMode(!this.player.isSlowMode);
          Haptics.tap();
        }
      }))
      .accessibilityText('朗读')
    }
  }
}

@ComponentV2
export struct MuteToggle {
  settings: SettingsStore = SettingsStore.shared;

  build() {
    Stack() {
      DuoIcon({ name: this.settings.isMuted ? 'speakerSlash' : 'speaker', sz: 20, color: C.primary })
    }
    .width(44)
    .height(44)
    .onClick(() => {
      this.settings.toggleMute();
      if (this.settings.isMuted) {
        AudioPlayer.shared.stop();
      }
    })
    .accessibilityText(this.settings.isMuted ? '取消静音' : '静音')
  }
}

@ComponentV2
export struct SlowModeBadge {
  player: AudioPlayer = AudioPlayer.shared;
  @Local slow: boolean = false;
  private unsubPlayer: () => void = () => {
  };

  aboutToAppear(): void {
    this.slow = this.player.isSlowMode;
    this.unsubPlayer = this.player.onChange(() => {
      this.slow = this.player.isSlowMode;
    });
  }

  aboutToDisappear(): void {
    this.unsubPlayer();
  }

  build() {
    Row({ space: 4 }) {
      Text('🐢').fontSize(14)
      Text(this.slow ? '慢速中' : '慢速').fontSize(F.micro).fontWeight(W.bold)
        .fontColor(this.slow ? C.primary : C.inkMuted)
    }
    .padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor(this.slow ? alpha(C.primary, 0.14) : C.surfaceAlt)
    .borderRadius(999)
    .border({ width: 1.5, color: this.slow ? alpha(C.primary, 0.5) : C.border, radius: 999 })
    .onClick(() => {
      this.player.setSlowMode(!this.player.isSlowMode);
      Haptics.tap();
    })
  }
}

/** 「朗读全文」：整队自然播完才回调 onCompleted（完成门槛）。 */
@ComponentV2
export struct ReadAllButton {
  @Param sentences: PassageSentence[] = [];
  @Param disabledExternally: boolean = false;
  @Event onStarted: () => void = () => {
  };
  @Event onCompleted: () => void = () => {
  };
  player: AudioPlayer = AudioPlayer.shared;
  /** 本按钮发起的整篇朗读正在播放（onChange 镜像；@Trace 直读不触发重绘）。 */
  @Local running: boolean = false;
  private runActive: boolean = false;
  private countAtStart: number = 0;
  private runId: number = 0;
  private unsubPlayer: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubPlayer = this.player.onChange(() => this.onPlayerChange());
  }

  aboutToDisappear(): void {
    this.unsubPlayer();
  }

  private hasAudio(): boolean {
    return this.player.hasAnyResolvable(this.sentences.map((s: PassageSentence) => s.audio));
  }

  /** 整队自然播完（计数 +1 且仍是本次 run）才算完成；被 stop / 单句打断不算。 */
  private onPlayerChange(): void {
    const p = this.player;
    if (this.runActive && (!p.isPlaying || p.currentRunId !== this.runId)) {
      this.runActive = false;
      if (p.queueCompletionCount > this.countAtStart && p.currentRunId === this.runId) {
        this.onCompleted();
      }
    }
    this.running = this.runActive && p.isPlaying;
  }

  private showStop(): boolean {
    return this.running && !this.disabledExternally;
  }

  build() {
    SmallChunkyButton({
      label: this.hasAudio() ? (this.showStop() ? '停止朗读' : '朗读全文') : '音频还没下载完',
      icon: this.hasAudio() ? (this.showStop() ? 'stop' : 'play') : 'downloadCircle',
      bgColor: this.hasAudio() ? (this.showStop() ? C.danger : C.primary) : C.inkSofter,
      shadowColor: this.hasAudio() ? (this.showStop() ? C.dangerDark : C.primaryDark) : C.inkMuted,
      active: this.hasAudio() && !this.disabledExternally,
      onTap: () => {
        if (!this.hasAudio()) {
          return;
        }
        if (this.running) {
          this.runActive = false;
          this.running = false;
          this.player.stop();
        } else {
          Haptics.tap();
          this.countAtStart = this.player.queueCompletionCount;
          this.player.play(this.sentences.map((s: PassageSentence) => s.audio));
          if (this.player.isPlaying) {
            this.runId = this.player.currentRunId;
            this.runActive = true;
            this.running = true;
            this.onStarted();
          }
        }
      }
    })
  }
}

export type AppTab = 'learn' | 'league' | 'review' | 'shop' | 'profile';

export const ALL_TABS: AppTab[] = ['learn', 'league', 'review', 'shop', 'profile'];

export function tabLabel(t: AppTab): string {
  switch (t) {
    case 'learn':
      return '学习';
    case 'league':
      return '排行';
    case 'review':
      return '错题本';
    case 'shop':
      return '商店';
    default:
      return '我的';
  }
}

function tabIcon(t: AppTab): string {
  switch (t) {
    case 'learn':
      return 'house';
    case 'league':
      return 'trophy';
    case 'review':
      return 'book';
    case 'shop':
      return 'bag';
    default:
      return 'person';
  }
}

/** 底部 Tab 栏（BottomTabBar）：错题待复习数 / 可领奖励数 / 联赛结算红点。 */
@ComponentV2
export struct BottomTabBar {
  @Param active: AppTab = 'learn';
  @Event onSelect: (t: AppTab) => void = (_t: AppTab) => {
  };
  store: ProgressStore = ProgressStore.shared;
  @Local dueReviews: number = 0;
  @Local readyRewards: number = 0;
  @Local leagueResult: boolean = false;
  private unsubscribe: () => void = () => {};

  private updateBadges(): void {
    this.dueReviews = this.store.dueMistakes.length;
    this.readyRewards = this.store.claimableQuestCount + this.store.claimableAchievementCount;
    this.leagueResult = this.store.pendingLeagueResult !== null;
  }

  aboutToAppear(): void {
    this.updateBadges();
    this.unsubscribe = this.store.onChange(() => this.updateBadges());
  }

  aboutToDisappear(): void {
    this.unsubscribe();
  }

  private tabInk(t: AppTab): string {
    if (t !== this.active) {
      return C.inkMuted;
    }
    return C.theme !== null ? C.primary : C.tone('tab_active_ink');
  }

  private badgeCount(t: AppTab): number {
    if (t === 'review') {
      return this.dueReviews;
    }
    if (t === 'profile') {
      return this.readyRewards;
    }
    return 0;
  }

  private tabA11y(t: AppTab): string {
    const n = this.badgeCount(t);
    if (n > 0) {
      return t === 'review' ? `${tabLabel(t)}，${n} 道待复习` : `${tabLabel(t)}，${n} 个奖励可领取`;
    }
    return t === 'league' && this.leagueResult ? `${tabLabel(t)}，有新结算` : tabLabel(t);
  }

  build() {
    Column() {
      Row() {
        ForEach(ALL_TABS, (t: AppTab) => {
          Column({ space: 3 }) {
            Stack() {
              DuoIcon({ name: tabIcon(t), sz: 21, color: this.tabInk(t) })
              if (this.badgeCount(t) > 0) {
                Text(this.badgeCount(t) > 99 ? '99+' : `${this.badgeCount(t)}`)
                  .fontSize(F.micro)
                  .fontWeight(W.heavy)
                  .fontColor('#FFFFFF')
                  .padding({ left: 5, right: 5 })
                  .constraintSize({ minWidth: 18 })
                  .height(18)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(C.danger)
                  .borderRadius(9)
                  .border({ width: 2, color: C.bg, radius: 9 })
                  .markAnchor({ x: 0, y: 0 })
                  .position({ x: 31, y: -6 })
              } else if (t === 'league' && this.leagueResult) {
                Circle().width(10).height(10).fill(C.danger).stroke(C.bg).strokeWidth(2)
                  .position({ x: 33, y: -1 })
              }
            }
            .width(48).height(29).borderRadius(11)
            .backgroundColor(this.active === t ? alpha(C.primary, 0.20) : Color.Transparent)
            Text(tabLabel(t)).fontSize(F.micro).fontWeight(W.bold).fontColor(this.tabInk(t)).maxLines(1)
          }
          .layoutWeight(1)
          .height(60)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            if (this.active !== t) {
              Haptics.tap();
              this.onSelect(t);
            }
          })
          .accessibilityGroup(true)
          .accessibilityText(this.tabA11y(t))
        }, (t: AppTab) => t)
      }
      .width('100%')
      .height(65)
      .constraintSize({ maxWidth: CONTENT_MAX_W })
      .padding({ left: 5, right: 5 })
    }
    .width('100%')
    .border({ width: { top: 1 }, color: C.border })
    .backgroundColor(C.theme !== null ? C.bg : C.tone('tab_bar_bg'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
