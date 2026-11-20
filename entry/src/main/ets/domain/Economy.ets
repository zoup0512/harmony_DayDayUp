// 经济系统单一事实源 —— Economy.swift / core economy.ts 的逐项镜像。
import { MistakeEntry, Question } from '../models/Types';
import { daysBetween, isoString, parseDateKey, todayString, dateString } from './Dates';

export class Economy {
  static readonly threeStarAccuracy: number = 0.95;
  static readonly twoStarAccuracy: number = 0.80;

  static starsFromAccuracy(accuracy: number): number {
    if (accuracy >= Economy.threeStarAccuracy) {
      return 3;
    }
    if (accuracy >= Economy.twoStarAccuracy) {
      return 2;
    }
    return 1;
  }

  static readonly xpPerCorrect: number = 10;
  static readonly perfectXpBonus: number = 5;
  static readonly firstPerfectXpBonus: number = 5;
  static readonly weekendXpMultiplier: number = 2;
  static readonly examXpMultiplier: number = 2;

  static xpForLesson(correctCount: number, perfect: boolean, firstPerfect: boolean, isWeekend: boolean,
    isExam: boolean = false): number {
    let xp = correctCount * Economy.xpPerCorrect;
    if (perfect) {
      xp += Economy.perfectXpBonus;
    }
    if (firstPerfect) {
      xp += Economy.firstPerfectXpBonus;
    }
    if (isExam) {
      xp *= Economy.examXpMultiplier;
    }
    if (isWeekend) {
      xp *= Economy.weekendXpMultiplier;
    }
    return xp;
  }

  static isExamLessonId(lessonId: string): boolean {
    return lessonId.endsWith('-exam');
  }

  static isWeekend(date: Date = new Date()): boolean {
    const d = date.getDay();
    return d === 0 || d === 6;
  }

  static isMonday(date: Date = new Date()): boolean {
    return date.getDay() === 1;
  }

  static readonly lessonGemBase: number = 3;
  static readonly lessonGemTwoStarBonus: number = 5;
  static readonly lessonGemThreeStarBonus: number = 10;
  static readonly firstPerfectGemBonus: number = 15;
  static readonly dailyGoalBonus: number = 20;

  static lessonGemDrip(stars: number, isFirstPerfect: boolean, crossedDailyGoal: boolean): number {
    let gems = Economy.lessonGemBase;
    if (stars === 3) {
      gems += Economy.lessonGemThreeStarBonus;
    } else if (stars === 2) {
      gems += Economy.lessonGemTwoStarBonus;
    }
    if (isFirstPerfect) {
      gems += Economy.firstPerfectGemBonus;
    }
    if (crossedDailyGoal) {
      gems += Economy.dailyGoalBonus;
    }
    return gems;
  }

  static readonly maxHearts: number = 5;
  static readonly heartRegenSeconds: number = 300;
  static readonly heartRefillCost: number = 350;
  static readonly reviewHeartRewardAmount: number = 1;
  static readonly reviewHeartMinCorrect: number = 5;

  static reviewHeartReward(correctCount: number, hearts: number): number {
    if (correctCount < Economy.reviewHeartMinCorrect) {
      return 0;
    }
    return Math.min(Economy.reviewHeartRewardAmount, Math.max(0, Economy.maxHearts - hearts));
  }


  static readonly freezeCost: number = 200;
  static readonly maxFreezes: number = 2;
  static readonly initialFreezes: number = 2;
  static readonly streakMakeupCost: number = 50;

  static advanceStreak(streak: number, freezes: number, gapDays: number, isMonday: boolean): StreakAdvanceResult {
    if (gapDays <= 0) {
      return new StreakAdvanceResult(streak, freezes, 0);
    }
    if (gapDays === 1) {
      const topped = (isMonday && freezes < Economy.maxFreezes) ? freezes + 1 : freezes;
      return new StreakAdvanceResult(streak + 1, topped, 0);
    }
    const missed = gapDays - 1;
    if (freezes >= missed) {
      return new StreakAdvanceResult(streak + 1, freezes - missed, missed);
    }
    return new StreakAdvanceResult(1, freezes, 0);
  }

  static streakMilestoneReward(streakAfter: number): number {
    switch (streakAfter) {
      case 3:
        return 30;
      case 7:
        return 80;
      case 14:
        return 150;
      case 30:
        return 300;
      case 60:
        return 500;
      case 100:
        return 800;
      default:
        return 0;
    }
  }

  static readonly dailyRewardTable: number[] = [5, 5, 8, 12, 15, 20, 25, 30];

  static dailyRewardForStreak(streak: number): number {
    const idx = Math.min(Math.max(0, streak), Economy.dailyRewardTable.length - 1);
    return Economy.dailyRewardTable[idx];
  }

  static readonly dailyGoalOptions: number[] = [20, 50, 100, 200];
  static readonly defaultDailyGoal: number = 50;

  static readonly readingListenXp: number = 5;
  static readonly readingFollowupXp: number = 10;
  static readonly readingStoryGoodXp: number = 15;
  static readonly readingStoryBaseXp: number = 5;
  static readonly readingGoodThreshold: number = 0.8;

  static storyQuizXp(accuracy: number): number {
    return accuracy >= Economy.readingGoodThreshold ? Economy.readingStoryGoodXp : Economy.readingStoryBaseXp;
  }
}

export class StreakAdvanceResult {
  streak: number;
  freezes: number;
  freezesConsumed: number;

  constructor(streak: number, freezes: number, freezesConsumed: number) {
    this.streak = streak;
    this.freezes = freezes;
    this.freezesConsumed = freezesConsumed;
  }
}

// ============================================================
// 连胜推进（Streak.swift）
// ============================================================

export class StreakAdvance {
  streak: number;
  streakFreezes: number;
  lastActiveDate: string;
  freezesConsumed: number;

  constructor(streak: number, streakFreezes: number, lastActiveDate: string, freezesConsumed: number) {
    this.streak = streak;
    this.streakFreezes = streakFreezes;
    this.lastActiveDate = lastActiveDate;
    this.freezesConsumed = freezesConsumed;
  }
}

export function advanceStreakDay(streak: number, streakFreezes: number, lastActiveDate: string,
  today: string): StreakAdvance {
  if (lastActiveDate === today) {
    return new StreakAdvance(streak, streakFreezes, today, 0);
  }
  if (lastActiveDate.length === 0) {
    return new StreakAdvance(1, streakFreezes, today, 0);
  }
  const gap = daysBetween(lastActiveDate, today);
  if (gap <= 0) {
    return new StreakAdvance(streak, streakFreezes, lastActiveDate, 0);
  }
  const d = parseDateKey(today);
  const r = Economy.advanceStreak(streak, streakFreezes, gap, d !== null && Economy.isMonday(d));
  return new StreakAdvance(r.streak, r.freezes, today, r.freezesConsumed);
}

// ============================================================
// SRS 莱特纳盒（SRS.swift）
// ============================================================

export class SRS {
  static readonly graduateMinBox: number = 3;
  static readonly graduateMinCorrect: number = 2;

  static review(entry: MistakeEntry, isCorrect: boolean, now: Date = new Date()): MistakeEntry {
    const next: MistakeEntry = cloneEntry(entry);
    next.lastReviewedAt = isoString(now);
    if (!isCorrect) {
      next.box = 1;
      next.correctCount = 0;
      next.nextReviewDate = todayString(now);
      return next;
    }
    next.correctCount = (entry.correctCount ?? 0) + 1;
    const currentBox = entry.box ?? 1;
    if (currentBox === 1) {
      next.box = 2;
      next.nextReviewDate = dateString(1, now);
    } else if (currentBox === 2) {
      next.box = 3;
      next.nextReviewDate = dateString(3, now);
    } else {
      next.box = 3;
      next.nextReviewDate = dateString(7, now);
    }
    return next;
  }

  static isGraduatedState(graduated: boolean | null | undefined, box: number | null | undefined,
    correctCount: number | null | undefined): boolean {
    if (graduated === true) {
      return true;
    }
    return (box ?? 1) >= SRS.graduateMinBox && (correctCount ?? 0) >= SRS.graduateMinCorrect;
  }

  static isGraduated(entry: MistakeEntry): boolean {
    return SRS.isGraduatedState(entry.graduated, entry.box, entry.correctCount);
  }

  static dueEntries(entries: MistakeEntry[], now: Date = new Date()): MistakeEntry[] {
    const today = todayString(now);
    const due = entries.filter((e: MistakeEntry) => {
      if (SRS.isGraduated(e)) {
        return false;
      }
      const next = e.nextReviewDate;
      if (next === undefined || next === null) {
        return true;
      }
      return next <= today;
    });
    return due.sort((a: MistakeEntry, b: MistakeEntry) => {
      const ba = a.box ?? 1;
      const bb = b.box ?? 1;
      if (ba !== bb) {
        return ba - bb;
      }
      const la = a.lastReviewedAt ?? a.addedAt;
      const lb = b.lastReviewedAt ?? b.addedAt;
      return la < lb ? -1 : (la > lb ? 1 : 0);
    });
  }

  static newEntry(lessonId: string, lessonTitle: string | null, question: Question, now: Date = new Date()): MistakeEntry {
    const e: MistakeEntry = {
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      question: question,
      addedAt: isoString(now),
      box: 1,
      correctCount: 0,
      lastReviewedAt: null,
      nextReviewDate: todayString(now)
    };
    return e;
  }
}

export function cloneEntry(e: MistakeEntry): MistakeEntry {
  const c: MistakeEntry = {
    lessonId: e.lessonId,
    lessonTitle: e.lessonTitle,
    question: e.question,
    addedAt: e.addedAt,
    box: e.box,
    correctCount: e.correctCount,
    lastReviewedAt: e.lastReviewedAt,
    nextReviewDate: e.nextReviewDate,
    graduated: e.graduated
  };
  return c;
}
