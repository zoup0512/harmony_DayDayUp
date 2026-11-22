// 用户进度 store —— ProgressStore.swift 的逐方法移植（持久化到 filesDir/cstf/progress.json）。
// 鸿蒙版不接 iCloud：跨设备迁移走「设置 › 导出/导入存档」（与 Web / iOS 共用同一信封格式）。
import {
  ActiveLessonSession, LeagueWeekResult, LessonOutcome, LessonResult, MistakeEntry, Question, QuestionReport, QuestionReportKind,
  UserProgress
} from '../models/Types';
import { advanceStreakDay, Economy, SRS } from '../domain/Economy';
import { dateString, daysBetween, isDateKey, isoString, todayString, weekDateKeys, weekStartKey,
  weekStartKeyWeeksAgo, dayIndexInWeek } from '../domain/Dates';
import { Achievement, AchievementSnapshot, Achievements, bookIdFromLessonId, CosmeticItem, Cosmetics,
  LessonBackdropData, normalizeReadingId, normalizeReadingIds, readingId, ReadingKind, UiThemeData } from '../domain/Catalog';
import { dailyQuests, League, LeagueTierId, Quest } from '../domain/Seeded';
import { BackupEnvelope, makeEnvelope, userProgressFromEnvelope } from '../domain/Backup';
import { AppEnv, Files } from '../services/Files';
import { DataLoader } from '../services/DataLoader';
import { ReminderContext, StreakReminders } from '../services/Feedback';
import { SettingsStore } from './SettingsStore';
import { WidgetSync } from '../services/WidgetSync';

interface Prefs {
  selectedGrade: number;
  activeBookId?: string | null;
  hasCompletedOnboarding?: boolean | null;
}

export class DailyRewardClaim {
  gems: number;
  effectiveStreak: number;

  constructor(gems: number, effectiveStreak: number) {
    this.gems = gems;
    this.effectiveStreak = effectiveStreak;
  }
}

export class QuestSnapshot {
  quest: Quest;
  progress: number;
  claimed: boolean;

  constructor(quest: Quest, progress: number, claimed: boolean) {
    this.quest = quest;
    this.progress = progress;
    this.claimed = claimed;
  }

  get isComplete(): boolean {
    return this.progress >= this.quest.target;
  }
}

export class DayXp {
  date: string;
  xp: number;

  constructor(date: string, xp: number) {
    this.date = date;
    this.xp = xp;
  }
}

class StreakBump {
  milestoneGems: number;
  freezesConsumed: number;

  constructor(milestoneGems: number, freezesConsumed: number) {
    this.milestoneGems = milestoneGems;
    this.freezesConsumed = freezesConsumed;
  }
}

function freshProgress(): UserProgress {
  const p: UserProgress = {
    xp: 0,
    streak: 0,
    lastActiveDate: '',
    completedLessons: {},
    mistakesBank: [],
    streakFreezes: Economy.initialFreezes,
    freezesMigrated: true,
    unlockedAchievements: [],
    claimedAchievements: [],
    joinedDate: todayString()
  };
  return p;
}

function clone(p: UserProgress): UserProgress {
  return JSON.parse(JSON.stringify(p)) as UserProgress;
}

function snapshotOf(p: UserProgress): AchievementSnapshot {
  const s = new AchievementSnapshot();
  s.xp = p.xp;
  s.streak = p.streak;
  s.lifetimeGems = p.lifetimeGems ?? (p.gems ?? 0);
  const results = Object.keys(p.completedLessons).map((k: string) => p.completedLessons[k]);
  s.completedLessonCount = results.length;
  s.perfectedLessonCount = results.filter((r: LessonResult) => r.stars === 3).length;
  const owned = new Set<string>(Cosmetics.starterIds());
  (p.ownedCosmetics ?? []).forEach((id: string) => owned.add(id));
  s.ownedCosmeticCount = owned.size;
  s.reviewedMistakeCount = p.mistakesBank.filter((e: MistakeEntry) => (e.correctCount ?? 0) > 0).length;
  return s;
}

/** 把新解锁的成就锁进永久账本，返回本次新解锁的成就。 */
function latchAchievements(p: UserProgress): Achievement[] {
  const current = Achievements.unlockedIds(snapshotOf(p));
  const ledger = p.unlockedAchievements ?? [];
  const ledgerSet = new Set<string>(ledger);
  const currentSet = new Set<string>(current);
  const newly = Achievements.all.filter((a: Achievement) => currentSet.has(a.id) && !ledgerSet.has(a.id));
  if (newly.length > 0) {
    p.unlockedAchievements = Achievements.latchUnlocked(ledger, current);
  }
  return newly;
}

function rollDailyIfNeeded(p: UserProgress, now: Date): void {
  const today = todayString(now);
  if (p.dailyDate === today) {
    return;
  }
  p.dailyDate = today;
  p.dailyLessons = 0;
  p.dailyReviews = 0;
  p.dailyReadings = 0;
}

function recordXP(p: UserProgress, amount: number, now: Date): void {
  if (amount <= 0) {
    return;
  }
  const today = todayString(now);
  p.xp += amount;
  if (p.lastXpDate === today) {
    p.todayXp = (p.todayXp ?? 0) + amount;
  } else {
    p.todayXp = amount;
    p.lastXpDate = today;
  }
  const history: Record<string, number> = p.xpHistory ?? {};
  history[today] = (history[today] ?? 0) + amount;
  const keys = Object.keys(history).sort();
  if (keys.length > 21) {
    const trimmed: Record<string, number> = {};
    keys.slice(keys.length - 21).forEach((k: string) => {
      trimmed[k] = history[k];
    });
    p.xpHistory = trimmed;
  } else {
    p.xpHistory = history;
  }
}

function bumpStreak(p: UserProgress, now: Date): StreakBump {
  const adv = advanceStreakDay(p.streak, p.streakFreezes ?? 0, p.lastActiveDate, todayString(now));
  p.streak = adv.streak;
  p.streakFreezes = adv.streakFreezes;
  p.lastActiveDate = adv.lastActiveDate;
  const reward = Economy.streakMilestoneReward(p.streak);
  const claimed = p.claimedStreakRewards ?? [];
  if (reward <= 0 || claimed.includes(p.streak)) {
    return new StreakBump(0, adv.freezesConsumed);
  }
  claimed.push(p.streak);
  p.claimedStreakRewards = claimed;
  p.gems = (p.gems ?? 0) + reward;
  p.lifetimeGems = (p.lifetimeGems ?? 0) + reward;
  return new StreakBump(reward, adv.freezesConsumed);
}

@ObservedV2
export class ProgressStore {
  static readonly shared: ProgressStore = new ProgressStore();
  static readonly maxHearts: number = Economy.maxHearts;

  @Trace progress: UserProgress = freshProgress();
  @Trace selectedGrade: number = 0;
  @Trace activeBookId: string | null = null;
  @Trace hasCompletedOnboarding: boolean = false;
  @Trace pendingDailyReward: DailyRewardClaim | null = null;
  /** 当前「今天」——跨日时改写，驱动所有按日派生的视图重算。 */
  @Trace dayKey: string = todayString();

  private loaded: boolean = false;

  private get progressPath(): string {
    return `${AppEnv.cstfRoot()}/progress.json`;
  }

  private get prefsPath(): string {
    return `${AppEnv.cstfRoot()}/prefs.json`;
  }

  load(): void {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    const raw = Files.readText(this.progressPath);
    let p: UserProgress = freshProgress();
    if (raw !== null) {
      try {
        p = JSON.parse(raw) as UserProgress;
        if (p.freezesMigrated !== true) {
          p.streakFreezes = Math.max(p.streakFreezes ?? 0, Economy.initialFreezes);
          p.freezesMigrated = true;
        }
      } catch (e) {
        p = freshProgress();
      }
    }
    const prefsRaw = Files.readText(this.prefsPath);
    if (prefsRaw !== null) {
      try {
        const prefs = JSON.parse(prefsRaw) as Prefs;
        this.selectedGrade = prefs.selectedGrade;
        this.activeBookId = prefs.activeBookId ?? null;
        this.hasCompletedOnboarding = prefs.hasCompletedOnboarding ?? true;
      } catch (e) {
        this.hasCompletedOnboarding = false;
      }
    }
    let migrated = false;
    if (p.unlockedAchievements === undefined || p.unlockedAchievements === null) {
      p.unlockedAchievements = Achievements.latchUnlocked([], Achievements.unlockedIds(snapshotOf(p)));
      migrated = true;
    }
    if (p.claimedAchievements === undefined || p.claimedAchievements === null) {
      p.claimedAchievements = (p.unlockedAchievements ?? []).slice();
      migrated = true;
    }
    const before = p.completedReadings ?? [];
    const normalized = normalizeReadingIds(before);
    if (normalized.length !== new Set<string>(before).size || normalized.some((id: string) => !before.includes(id))) {
      p.completedReadings = normalized;
      migrated = true;
    }
    if (p.joinedDate === undefined || p.joinedDate === null) {
      const dates = Object.keys(p.completedLessons).map((k: string) => p.completedLessons[k].completedAt).sort();
      p.joinedDate = dates.length > 0 ? dates[0].substring(0, 10) : todayString();
      migrated = true;
    }
    this.progress = p;
    if (migrated) {
      this.save();
    }
  }

  private listeners: Array<() => void> = [];

  /** @Trace 跨组件字段实测不派发——组件侧改为 onChange + @Local 镜像驱动重绘。 */
  onChange(cb: () => void): () => void {
    this.listeners.push(cb);
    return () => {
      this.listeners = this.listeners.filter((x: () => void) => x !== cb);
    };
  }

  private emit(): void {
    this.listeners.forEach((cb: () => void) => cb());
  }

  private commit(p: UserProgress): void {
    this.progress = p;
    this.save();
    this.emit();
  }

  private save(): void {
    try {
      Files.writeTextAtomic(this.progressPath, JSON.stringify(this.progress));
    } catch (e) {
      console.error(`[ProgressStore] save failed ${JSON.stringify(e)}`);
    }
    WidgetSync.push(this.progress);
  }

  private persistPrefs(): void {
    const prefs: Prefs = {
      selectedGrade: this.selectedGrade,
      activeBookId: this.activeBookId,
      hasCompletedOnboarding: this.hasCompletedOnboarding
    };
    this.emit();
    try {
      Files.writeTextAtomic(this.prefsPath, JSON.stringify(prefs));
    } catch (e) {
      console.error(`[ProgressStore] prefs save failed`);
    }
  }

  private lastReminderKey: string = '';

  /** 只有提醒相关输入变化时才重排（心跳每 30s 调 refreshForNow，不能每次都 cancel+publish）。 */
  private reschedule(streak: number, studiedToday: boolean): void {
    const st = SettingsStore.shared;
    const key = `${streak}|${studiedToday}|${this.dueMistakes.length}|${todayString()}|` +
      `${st.streakReminderEnabled}|${st.reminderHour}:${st.reminderMinute}`;
    if (key === this.lastReminderKey) {
      return;
    }
    this.lastReminderKey = key;
    StreakReminders.reschedule(new ReminderContext(streak, this.dueMistakes.length), studiedToday);
  }

  // ============================================================
  // 课程结算
  // ============================================================

  completeLesson(lessonId: string, correctCount: number, questionCount: number, now: Date = new Date()): LessonOutcome {
    this.tickHeartRecharge(now);
    const total = Math.max(1, questionCount);
    const correct = Math.min(Math.max(0, correctCount), total);
    const accuracy = correct / total;
    const stars = Economy.starsFromAccuracy(accuracy);
    const perfect = correct >= total;
    const isWeekend = Economy.isWeekend(now);
    const isExam = Economy.isExamLessonId(lessonId);
    const result: LessonResult = { lessonId: lessonId, stars: stars, accuracy: accuracy, completedAt: isoString(now) };
    const goal = this.dailyGoal;
    const todayKey = todayString(now);
    const todayXpBefore = this.progress.lastXpDate === todayKey ? (this.progress.todayXp ?? 0) : 0;
    const streakBefore = this.progress.streak;

    const p = clone(this.progress);
    rollDailyIfNeeded(p, now);
    if (p.activeLesson?.lessonId === lessonId) {
      p.activeLesson = null;
    }
    const prior = p.completedLessons[lessonId];
    const priorStars = prior !== undefined ? prior.stars : 0;
    const firstPerfect = stars === 3 && priorStars < 3;
    const xpGain = Economy.xpForLesson(correct, perfect, firstPerfect, isWeekend, isExam);
    recordXP(p, xpGain, now);
    p.dailyLessons = (p.dailyLessons ?? 0) + 1;
    if (prior === undefined || stars >= prior.stars) {
      p.completedLessons[lessonId] = result;
    }
    const bump = bumpStreak(p, now);
    const reachedNow = todayXpBefore < goal && (p.todayXp ?? 0) >= goal;
    const gemsGained = Economy.lessonGemDrip(stars, firstPerfect, reachedNow);
    p.gems = (p.gems ?? 0) + gemsGained;
    p.lifetimeGems = (p.lifetimeGems ?? 0) + gemsGained;
    const newly = latchAchievements(p);
    this.commit(p);
    this.reschedule(p.streak, true);

    const o = new LessonOutcome();
    o.xpGained = xpGain;
    o.stars = stars;
    o.streakBefore = streakBefore;
    o.streakAfter = p.streak;
    o.dailyGoalReachedNow = reachedNow;
    o.gemsGained = gemsGained;
    o.newAchievementIds = newly.map((a: Achievement) => a.id);
    o.milestoneGems = bump.milestoneGems;
    o.weekendDoubled = isWeekend && xpGain > 0;
    o.freezesConsumed = bump.freezesConsumed;
    o.examDoubled = isExam && xpGain > 0;
    return o;
  }

  // ============================================================
  // 课程会话（中途退出可续）
  // ============================================================

  activeSession(lessonId: string): ActiveLessonSession | null {
    const s = this.progress.activeLesson;
    return (s !== undefined && s !== null && s.lessonId === lessonId) ? s : null;
  }

  upsertLessonSession(session: ActiveLessonSession): void {
    const p = clone(this.progress);
    p.activeLesson = session;
    this.commit(p);
  }

  clearLessonSession(): void {
    if (this.progress.activeLesson === undefined || this.progress.activeLesson === null) {
      return;
    }
    const p = clone(this.progress);
    p.activeLesson = null;
    this.commit(p);
  }

  // ============================================================
  // 错题本
  // ============================================================

  recordMistake(lessonId: string, lessonTitle: string | null, question: Question, now: Date = new Date()): void {
    const exists = this.progress.mistakesBank.some((e: MistakeEntry) => e.lessonId === lessonId &&
      e.question.id === question.id);
    if (exists) {
      return;
    }
    const p = clone(this.progress);
    p.mistakesBank.push(SRS.newEntry(lessonId, lessonTitle, question, now));
    this.commit(p);
  }

  /** 返回 true 表示这次复习让该题新毕业。 */
  reviewMistake(lessonId: string, questionId: number, isCorrect: boolean, now: Date = new Date()): boolean {
    const p = clone(this.progress);
    const idx = p.mistakesBank.findIndex((e: MistakeEntry) => e.lessonId === lessonId && e.question.id === questionId);
    if (idx < 0) {
      return false;
    }
    const wasGraduated = SRS.isGraduated(p.mistakesBank[idx]);
    const updated = SRS.review(p.mistakesBank[idx], isCorrect, now);
    let newlyGraduated = false;
    if (!isCorrect) {
      updated.graduated = false;
    } else if (SRS.isGraduatedState(null, updated.box, updated.correctCount)) {
      updated.graduated = true;
      newlyGraduated = !wasGraduated;
    }
    p.mistakesBank[idx] = updated;
    latchAchievements(p);
    this.commit(p);
    return newlyGraduated;
  }

  get dueMistakes(): MistakeEntry[] {
    const _day = this.dayKey;
    return SRS.dueEntries(this.progress.mistakesBank);
  }

  // ============================================================
  // 偏好
  // ============================================================

  setSelectedGrade(grade: number): void {
    this.selectedGrade = grade;
    this.persistPrefs();
  }

  setActiveBook(bookId: string | null): void {
    this.activeBookId = bookId;
    this.persistPrefs();
  }

  completeOnboarding(): void {
    this.hasCompletedOnboarding = true;
    this.persistPrefs();
  }

  // ============================================================
  // 查询
  // ============================================================

  isLessonCompleted(lessonId: string): boolean {
    return this.progress.completedLessons[lessonId] !== undefined;
  }

  stars(lessonId: string): number {
    const r = this.progress.completedLessons[lessonId];
    return r !== undefined ? r.stars : 0;
  }

  get totalCompletedLessons(): number {
    return Object.keys(this.progress.completedLessons).length;
  }

  get perfectedLessonCount(): number {
    const c = this.progress.completedLessons;
    return Object.keys(c).filter((k: string) => c[k].stars === 3).length;
  }

  get achievementSnapshot(): AchievementSnapshot {
    return snapshotOf(this.progress);
  }

  get unlockedAchievementIds(): Set<string> {
    const set = new Set<string>(this.progress.unlockedAchievements ?? []);
    Achievements.unlockedIds(this.achievementSnapshot).forEach((id: string) => set.add(id));
    return set;
  }

  get hearts(): number {
    return this.progress.hearts ?? Economy.maxHearts;
  }

  get gems(): number {
    return this.progress.gems ?? 0;
  }

  get dailyGoal(): number {
    return this.progress.dailyGoal ?? Economy.defaultDailyGoal;
  }

  get streakFreezes(): number {
    return this.progress.streakFreezes ?? 0;
  }

  get todayXp(): number {
    return this.progress.lastXpDate === this.dayKey ? (this.progress.todayXp ?? 0) : 0;
  }

  get dailyGoalReached(): boolean {
    return this.todayXp >= this.dailyGoal;
  }

  get studiedToday(): boolean {
    return this.progress.lastActiveDate === this.dayKey;
  }

  salvageableStreak(now: Date = new Date()): number {
    const today = todayString(now);
    const p = this.progress;
    if (p.lastActiveDate === today) {
      return p.streak;
    }
    const adv = advanceStreakDay(p.streak, p.streakFreezes ?? 0, p.lastActiveDate, today);
    return adv.streak === p.streak + 1 ? p.streak : 0;
  }

  get displayStreak(): number {
    const _day = this.dayKey;
    return this.salvageableStreak();
  }

  get reminderStreak(): number {
    return this.salvageableStreak();
  }

  get nextHeartAtMs(): number | null {
    return this.progress.nextHeartAt ?? null;
  }

  // ============================================================
  // 每日登录奖励 / 补卡
  // ============================================================

  claimDailyRewardIfDue(now: Date = new Date()): void {
    const today = todayString(now);
    if (this.progress.lastDailyRewardDate === today) {
      return;
    }
    const effective = this.salvageableStreak(now);
    const gems = Economy.dailyRewardForStreak(effective);
    const p = clone(this.progress);
    p.lastDailyRewardDate = today;
    p.lastDailyRewardStreak = effective;
    p.gems = (p.gems ?? 0) + gems;
    p.lifetimeGems = (p.lifetimeGems ?? 0) + gems;
    this.commit(p);
    this.pendingDailyReward = new DailyRewardClaim(gems, effective);
    this.emit();
  }

  private topUpDailyRewardAfterMakeup(now: Date): void {
    const today = todayString(now);
    const paid = this.progress.lastDailyRewardStreak;
    if (this.progress.lastDailyRewardDate !== today || paid === undefined || paid === null) {
      return;
    }
    const effective = this.salvageableStreak(now);
    if (effective <= paid) {
      return;
    }
    const delta = Economy.dailyRewardForStreak(effective) - Economy.dailyRewardForStreak(paid);
    if (delta <= 0) {
      return;
    }
    const p = clone(this.progress);
    p.lastDailyRewardStreak = effective;
    p.gems = (p.gems ?? 0) + delta;
    p.lifetimeGems = (p.lifetimeGems ?? 0) + delta;
    this.commit(p);
    const shown = (this.pendingDailyReward?.gems ?? 0) + delta;
    this.pendingDailyReward = new DailyRewardClaim(shown, effective);
    this.emit();
  }

  get canOfferMakeup(): boolean {
    const p = this.progress;
    return !this.studiedToday && this.displayStreak === 0 && p.streak > 0 &&
      daysBetween(p.lastActiveDate, todayString()) >= 2;
  }

  makeUpYesterdayStreak(now: Date = new Date()): boolean {
    const today = todayString(now);
    const p0 = this.progress;
    if (p0.streak <= 0 || p0.lastActiveDate.length === 0 || p0.lastActiveDate === today ||
      daysBetween(p0.lastActiveDate, today) < 2 || this.salvageableStreak(now) !== 0) {
      return false;
    }
    if (!this.spendGems(Economy.streakMakeupCost)) {
      return false;
    }
    const p = clone(this.progress);
    p.lastActiveDate = dateString(-1, now);
    this.commit(p);
    this.topUpDailyRewardAfterMakeup(now);
    return true;
  }

  // ============================================================
  // 红心
  // ============================================================

  loseHeart(now: Date = new Date()): void {
    this.tickHeartRecharge(now);
    const current = this.hearts;
    if (current <= 0) {
      return;
    }
    const p = clone(this.progress);
    p.hearts = current - 1;
    if (p.nextHeartAt === undefined || p.nextHeartAt === null) {
      p.nextHeartAt = now.getTime() + Economy.heartRegenSeconds * 1000;
    }
    this.commit(p);
  }

  addHeart(n: number = 1, now: Date = new Date()): void {
    if (n <= 0) {
      return;
    }
    this.tickHeartRecharge(now);
    const current = this.hearts;
    if (current >= Economy.maxHearts) {
      return;
    }
    const p = clone(this.progress);
    const next = Math.min(Economy.maxHearts, current + n);
    p.hearts = next;
    if (next >= Economy.maxHearts) {
      p.nextHeartAt = null;
    }
    this.commit(p);
  }

  claimReviewHeartIfEligible(correctCount: number, now: Date = new Date()): boolean {
    this.tickHeartRecharge(now);
    const today = todayString(now);
    if (this.progress.lastReviewHeartDate === today) {
      return false;
    }
    const reward = Economy.reviewHeartReward(correctCount, this.hearts);
    if (reward <= 0) {
      return false;
    }
    const p = clone(this.progress);
    p.lastReviewHeartDate = today;
    this.commit(p);
    this.addHeart(reward, now);
    return true;
  }

  canClaimReviewHeart(now: Date = new Date()): boolean {
    return this.progress.lastReviewHeartDate !== todayString(now) && this.hearts < Economy.maxHearts;
  }

  /** 推进回心计时；缺心却没有计时（老档/导入）时当场补种计时。 */
  tickHeartRecharge(now: Date = new Date()): void {
    let hearts = this.hearts;
    const next = this.progress.nextHeartAt;
    if (hearts >= Economy.maxHearts) {
      if (next !== undefined && next !== null) {
        const p = clone(this.progress);
        p.nextHeartAt = null;
        this.commit(p);
      }
      return;
    }
    if (next === undefined || next === null) {
      const p = clone(this.progress);
      p.nextHeartAt = now.getTime() + Economy.heartRegenSeconds * 1000;
      this.commit(p);
      return;
    }
    let nextMs = next;
    const nowMs = now.getTime();
    if (nextMs > nowMs) {
      return;
    }
    while (nextMs <= nowMs && hearts < Economy.maxHearts) {
      hearts++;
      nextMs += Economy.heartRegenSeconds * 1000;
    }
    const p = clone(this.progress);
    p.hearts = hearts;
    p.nextHeartAt = hearts < Economy.maxHearts ? nextMs : null;
    this.commit(p);
  }

  refillHearts(): void {
    const p = clone(this.progress);
    p.hearts = Economy.maxHearts;
    p.nextHeartAt = null;
    this.commit(p);
  }

  buyHeartRefill(cost: number = Economy.heartRefillCost, now: Date = new Date()): boolean {
    this.tickHeartRecharge(now);
    if (this.hearts >= Economy.maxHearts) {
      return false;
    }
    if (!this.spendGems(cost)) {
      return false;
    }
    this.refillHearts();
    return true;
  }

  // ============================================================
  // 宝石 / 护盾
  // ============================================================

  addGems(amount: number): void {
    const p = clone(this.progress);
    p.gems = (p.gems ?? 0) + amount;
    if (amount > 0) {
      p.lifetimeGems = (p.lifetimeGems ?? 0) + amount;
    }
    latchAchievements(p);
    this.commit(p);
  }

  spendGems(amount: number): boolean {
    const current = this.gems;
    if (current < amount) {
      return false;
    }
    const p = clone(this.progress);
    p.gems = current - amount;
    this.commit(p);
    return true;
  }

  buyStreakFreeze(cost: number = Economy.freezeCost): boolean {
    if (this.streakFreezes >= Economy.maxFreezes) {
      return false;
    }
    if (!this.spendGems(cost)) {
      return false;
    }
    const p = clone(this.progress);
    p.streakFreezes = (p.streakFreezes ?? 0) + 1;
    this.commit(p);
    return true;
  }

  // ============================================================
  // 美妆
  // ============================================================

  get ownedCosmetics(): Set<string> {
    const set = new Set<string>(Cosmetics.starterIds());
    (this.progress.ownedCosmetics ?? []).forEach((id: string) => set.add(id));
    return set;
  }

  isOwned(id: string): boolean {
    return this.ownedCosmetics.has(id);
  }

  get equippedMascotSkin(): string {
    return this.progress.equippedMascotSkin ?? Cosmetics.defaultSkin;
  }

  get equippedTheme(): string {
    return this.progress.equippedTheme ?? Cosmetics.defaultTheme;
  }

  get equippedBackdrop(): string {
    return this.progress.equippedBackdrop ?? Cosmetics.defaultBackdrop;
  }

  isEquipped(id: string): boolean {
    return id === this.equippedMascotSkin || id === this.equippedTheme || id === this.equippedBackdrop;
  }

  buyCosmetic(item: CosmeticItem): boolean {
    if (this.isOwned(item.id)) {
      return true;
    }
    if (!this.spendGems(item.cost)) {
      return false;
    }
    const p = clone(this.progress);
    const owned = p.ownedCosmetics ?? [];
    owned.push(item.id);
    p.ownedCosmetics = owned;
    latchAchievements(p);
    this.commit(p);
    return true;
  }

  equipCosmetic(item: CosmeticItem): void {
    if (!this.isOwned(item.id)) {
      return;
    }
    const p = clone(this.progress);
    if (item.type === 'mascot_skin') {
      p.equippedMascotSkin = item.id;
    } else if (item.type === 'ui_theme') {
      p.equippedTheme = item.id;
    } else {
      p.equippedBackdrop = item.id;
    }
    this.commit(p);
  }

  get equippedThemeData(): UiThemeData | undefined {
    return Cosmetics.themeData(this.equippedTheme);
  }

  get equippedBackdropData(): LessonBackdropData | undefined {
    return Cosmetics.backdropData(this.equippedBackdrop);
  }

  // ============================================================
  // 复习 XP / 阅读
  // ============================================================

  awardReviewXP(amount: number, reviewedCount: number = 0, now: Date = new Date()): void {
    if (amount <= 0 && reviewedCount <= 0) {
      return;
    }
    const p = clone(this.progress);
    rollDailyIfNeeded(p, now);
    recordXP(p, amount, now);
    p.dailyReviews = (p.dailyReviews ?? 0) + Math.max(0, reviewedCount);
    bumpStreak(p, now);
    latchAchievements(p);
    this.commit(p);
    this.reschedule(p.streak, true);
  }

  get completedReadings(): Set<string> {
    return new Set<string>(this.progress.completedReadings ?? []);
  }

  isReadingCompleted(kind: ReadingKind, rawId: string): boolean {
    return this.completedReadings.has(readingId(kind, rawId));
  }

  completeReading(kind: ReadingKind, rawId: string, xp: number, now: Date = new Date()): void {
    const key = normalizeReadingId(readingId(kind, rawId));
    if (key.length === 0) {
      return;
    }
    const set = this.completedReadings;
    if (set.has(key)) {
      return;
    }
    set.add(key);
    const p = clone(this.progress);
    p.completedReadings = Array.from(set);
    rollDailyIfNeeded(p, now);
    recordXP(p, xp, now);
    p.dailyReadings = (p.dailyReadings ?? 0) + 1;
    bumpStreak(p, now);
    latchAchievements(p);
    this.commit(p);
    this.reschedule(p.streak, true);
  }

  // ============================================================
  // 个人资料
  // ============================================================

  get joinedDate(): string {
    return this.progress.joinedDate ?? todayString();
  }

  get displayName(): string {
    return this.progress.displayName ?? '小学员';
  }

  setDisplayName(name: string): void {
    const p = clone(this.progress);
    p.displayName = name.length === 0 ? null : name;
    this.commit(p);
  }

  resetProgress(): void {
    this.pendingDailyReward = null;
    this.commit(freshProgress());
  }

  /** 领取弹窗关闭（不改存档，只清内存态）。 */
  dismissDailyReward(): void {
    this.pendingDailyReward = null;
    this.emit();
  }

  setDailyGoal(goal: number): void {
    const p = clone(this.progress);
    p.dailyGoal = goal;
    this.commit(p);
  }

  claimChest(chestId: string): void {
    const p = clone(this.progress);
    const claimed: Record<string, boolean> = p.claimedChests ?? {};
    claimed[chestId] = true;
    p.claimedChests = claimed;
    this.commit(p);
  }

  isChestClaimed(chestId: string): boolean {
    const c = this.progress.claimedChests;
    return c !== undefined && c !== null && c[chestId] === true;
  }

  get graduatedMistakes(): MistakeEntry[] {
    return this.progress.mistakesBank.filter((e: MistakeEntry) => SRS.isGraduated(e));
  }

  // ============================================================
  // 每日任务 & 周报
  // ============================================================

  get todayQuests(): Quest[] {
    return dailyQuests(this.dayKey);
  }

  questProgress(quest: Quest, now: Date = new Date()): number {
    const today = todayString(now);
    if (this.progress.dailyDate !== today) {
      return quest.kind === 'earnXP' ? this.todayXp : 0;
    }
    switch (quest.kind) {
      case 'earnXP':
        return this.todayXp;
      case 'finishLessons':
        return this.progress.dailyLessons ?? 0;
      case 'reviewMistakes':
        return this.progress.dailyReviews ?? 0;
      default:
        return this.progress.dailyReadings ?? 0;
    }
  }

  isQuestComplete(quest: Quest): boolean {
    return this.questProgress(quest) >= quest.target;
  }

  questsSnapshot(now: Date = new Date()): QuestSnapshot[] {
    return this.todayQuests.map((q: Quest) => new QuestSnapshot(q, this.questProgress(q, now), this.isQuestClaimed(q)));
  }

  get claimableQuestCount(): number {
    return this.todayQuests.filter((q: Quest) => this.isQuestComplete(q) && !this.isQuestClaimed(q)).length;
  }

  private questKey(quest: Quest): string {
    return `${todayString()}:${quest.id}`;
  }

  isQuestClaimed(quest: Quest): boolean {
    return (this.progress.claimedQuests ?? []).includes(this.questKey(quest));
  }

  claimQuest(quest: Quest): boolean {
    if (!this.isQuestComplete(quest) || this.isQuestClaimed(quest)) {
      return false;
    }
    const p = clone(this.progress);
    let claimed = p.claimedQuests ?? [];
    claimed.push(this.questKey(quest));
    if (claimed.length > 60) {
      claimed = claimed.slice(claimed.length - 60);
    }
    p.claimedQuests = claimed;
    this.commit(p);
    this.addGems(quest.reward);
    return true;
  }

  weekXP(weekKey: string, now: Date = new Date()): DayXp[] {
    const history = this.progress.xpHistory ?? {};
    return weekDateKeys(weekKey, now).map((d: string) => new DayXp(d, history[d] ?? 0));
  }

  weekXPEntries(now: Date = new Date()): DayXp[] {
    const _day = this.dayKey;
    return this.weekXP(weekStartKey(now), now);
  }

  todayIndexInWeek(now: Date = new Date()): number {
    return Math.min(Math.max(0, dayIndexInWeek(weekStartKey(now), now, now)), 6);
  }

  weeklyTotal(weeksAgo: number, now: Date = new Date()): number {
    return this.weekXP(weekStartKeyWeeksAgo(weeksAgo, now), now).reduce((n: number, d: DayXp) => n + d.xp, 0);
  }

  // ============================================================
  // 本地联赛
  // ============================================================

  get leagueUnlocked(): boolean {
    return this.totalCompletedLessons >= League.unlockLessons;
  }

  get leagueTierId(): LeagueTierId {
    return League.tier(this.progress.leagueTier ?? 'bronze').id;
  }

  get leagueSalt(): string | null {
    return this.progress.leagueSalt ?? null;
  }

  get pendingLeagueResult(): LeagueWeekResult | null {
    return this.progress.pendingLeagueResult ?? null;
  }

  leagueWeeklyXpFor(weekKey: string): number {
    if (!isDateKey(weekKey)) {
      return 0;
    }
    const history = this.progress.xpHistory ?? {};
    return weekDateKeys(weekKey).reduce((n: number, d: string) => n + (history[d] ?? 0), 0);
  }

  leagueWeeklyXp(now: Date = new Date()): number {
    return this.leagueWeeklyXpFor(League.weekKeyFor(now));
  }

  /** 入组 + 周一结算（幂等）。 */
  refreshLeague(now: Date = new Date()): void {
    if (!this.leagueUnlocked) {
      return;
    }
    const currentWeek = League.weekKeyFor(now);
    const p = clone(this.progress);
    let changed = false;
    if (p.leagueSalt === undefined || p.leagueSalt === null) {
      p.leagueSalt = Files.uuid().toUpperCase();
      changed = true;
    }
    if (p.leagueTier === undefined || p.leagueTier === null) {
      p.leagueTier = 'bronze';
      changed = true;
    }
    if (p.leagueWeekKey === undefined || p.leagueWeekKey === null) {
      p.leagueWeekKey = currentWeek;
      changed = true;
    }
    const lastWeek = p.leagueWeekKey;
    const salt = p.leagueSalt;
    if (lastWeek !== currentWeek && salt !== undefined && salt !== null) {
      const tierId = League.tier(p.leagueTier ?? '').id;
      const botXps: number[] = [];
      for (let i = 0; i < League.botCount; i++) {
        botXps.push(League.botWeeklyGoal(lastWeek, tierId, salt, i));
      }
      const rank = League.userRank(this.leagueWeeklyXpFor(lastWeek), botXps);
      const settle = League.settleRank(rank, tierId);
      const after: LeagueTierId = settle.promoted ? League.nextTierId(tierId) :
        (settle.demoted ? League.prevTierId(tierId) : tierId);
      p.pendingLeagueResult = {
        weekKey: lastWeek, rank: rank, tierBefore: tierId, tierAfter: after,
        promoted: settle.promoted, demoted: settle.demoted, gems: settle.gems
      };
      if (settle.gems > 0) {
        p.gems = (p.gems ?? 0) + settle.gems;
        p.lifetimeGems = (p.lifetimeGems ?? 0) + settle.gems;
      }
      p.leagueTier = after;
      p.leagueWeekKey = currentWeek;
      latchAchievements(p);
      changed = true;
    }
    if (changed) {
      this.commit(p);
    }
  }

  clearPendingLeagueResult(): void {
    if (this.progress.pendingLeagueResult === undefined || this.progress.pendingLeagueResult === null) {
      return;
    }
    const p = clone(this.progress);
    p.pendingLeagueResult = null;
    this.commit(p);
  }

  // ============================================================
  // 跳级 / 课前讲解 / 报错
  // ============================================================

  /** 跳级通过：未完成的前置课标记为 1 星，不发 XP/宝石/连胜。 */
  applyJumpUnlock(lessonIds: string[], now: Date = new Date()): number {
    const p = clone(this.progress);
    const stamp = isoString(now);
    let marked = 0;
    for (const id of lessonIds) {
      if (p.completedLessons[id] === undefined) {
        const r: LessonResult = { lessonId: id, stars: 1, accuracy: 0.8, completedAt: stamp };
        p.completedLessons[id] = r;
        marked++;
      }
    }
    if (marked === 0) {
      return 0;
    }
    latchAchievements(p);
    this.commit(p);
    return marked;
  }

  hasSeenIntro(lessonId: string): boolean {
    return (this.progress.seenIntros ?? []).includes(lessonId);
  }

  markIntroSeen(lessonId: string): void {
    if (this.hasSeenIntro(lessonId)) {
      return;
    }
    const p = clone(this.progress);
    const seen = p.seenIntros ?? [];
    seen.push(lessonId);
    p.seenIntros = seen;
    this.commit(p);
  }

  get reports(): QuestionReport[] {
    return this.progress.reports ?? [];
  }

  addReport(lessonId: string, questionId: number, kind: QuestionReportKind, userAnswer: string,
    questionText: string, now: Date = new Date()): boolean {
    const p = clone(this.progress);
    let list = p.reports ?? [];
    if (list.some((r: QuestionReport) => r.lessonId === lessonId && r.questionId === questionId && r.kind === kind)) {
      return false;
    }
    const report: QuestionReport = {
      lessonId: lessonId, questionId: questionId, kind: kind, createdAt: isoString(now),
      userAnswer: userAnswer.length === 0 ? null : userAnswer, questionText: questionText
    };
    list.push(report);
    if (list.length > 200) {
      list = list.slice(list.length - 200);
    }
    p.reports = list;
    this.commit(p);
    return true;
  }

  exportReportsJson(): string {
    return JSON.stringify(this.reports, null, 2);
  }

  // ============================================================
  // 存档备份（BackupEnvelope v1）
  // ============================================================

  exportBackupEnvelope(now: Date = new Date()): BackupEnvelope {
    return makeEnvelope(this.progress, now);
  }

  importBackup(env: BackupEnvelope, now: Date = new Date()): void {
    const restored = userProgressFromEnvelope(env, (lessonId: string, questionId: number): Question | null => {
      const bookId = bookIdFromLessonId(lessonId);
      if (bookId === null) {
        return null;
      }
      const lesson = DataLoader.tryLesson(bookId, lessonId);
      return lesson?.questions.find((q: Question) => q.id === questionId) ?? null;
    }, this.progress.leagueSalt, this.progress.lastReviewHeartDate, now);
    this.pendingDailyReward = null;
    this.commit(restored);
  }

  // ============================================================
  // 成就领取（解锁 ≠ 发奖）
  // ============================================================

  get claimedAchievementIds(): Set<string> {
    return new Set<string>(this.progress.claimedAchievements ?? []);
  }

  get claimableAchievementIds(): Set<string> {
    const claimed = this.claimedAchievementIds;
    const out = new Set<string>();
    this.unlockedAchievementIds.forEach((id: string) => {
      if (!claimed.has(id)) {
        out.add(id);
      }
    });
    return out;
  }

  get claimableAchievementCount(): number {
    return this.claimableAchievementIds.size;
  }

  claimAchievement(id: string): number {
    const a = Achievements.byId(id);
    if (a === undefined || !this.unlockedAchievementIds.has(id) || this.claimedAchievementIds.has(id)) {
      return 0;
    }
    const p = clone(this.progress);
    latchAchievements(p);
    const claimed = p.claimedAchievements ?? [];
    claimed.push(id);
    p.claimedAchievements = claimed;
    p.gems = (p.gems ?? 0) + a.reward;
    p.lifetimeGems = (p.lifetimeGems ?? 0) + a.reward;
    latchAchievements(p);
    this.commit(p);
    return a.reward;
  }

  // ============================================================
  // 时钟同步
  // ============================================================

  /** 启动 / 回前台 / 跨日时调用：回心、发登录奖励、联赛结算、刷新提醒。 */
  refreshForNow(now: Date = new Date()): void {
    // 进度未载入前一律跳过——否则每日奖励会在 freshProgress 上误判、重复发奖。
    if (!this.loaded) {
      return;
    }
    this.tickHeartRecharge(now);
    this.claimDailyRewardIfDue(now);
    this.refreshLeague(now);
    const today = todayString(now);
    if (today !== this.dayKey) {
      this.dayKey = today;
      this.emit();
    }
    this.reschedule(this.salvageableStreak(now), this.progress.lastActiveDate === today);
  }
}
