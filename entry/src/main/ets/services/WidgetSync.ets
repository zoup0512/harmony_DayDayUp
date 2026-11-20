// 桌面卡片快照（iOS WidgetKit 小组件的鸿蒙服务卡片版）：每次存档顺手刷新卡片数据。
import { preferences } from '@kit.ArkData';
import { formBindingData, formProvider } from '@kit.FormKit';
import { common } from '@kit.AbilityKit';
import { UserProgress } from '../models/Types';
import { advanceStreakDay, Economy } from '../domain/Economy';
import { daysBetween, todayString } from '../domain/Dates';
import { AppEnv } from './Files';

export interface WidgetSnapshot {
  schema: number;
  streak: number;
  effectiveStreak: number;
  streakFreezes: number;
  studiedToday: boolean;
  lastActiveDate: string;
  hearts: number;
  dailyGoal: number;
  todayXp: number;
  lastXpDate: string;
  savedAtDay: string;
}

/** 卡片上实际显示的字段（由快照 + 当前时刻派生）。 */
export interface WidgetCardData {
  streak: number;
  studiedToday: boolean;
  todayXp: number;
  dailyGoal: number;
  message: string;
  mood: string;
}

const PREF_NAME = 'cstf_widget';
const KEY_SNAPSHOT = 'snapshot';
const KEY_FORMS = 'formIds';

export class WidgetSync {
  private static lastJson: string = '';

  static snapshotOf(p: UserProgress, now: Date = new Date()): WidgetSnapshot {
    const today = todayString(now);
    let effective = p.streak;
    if (p.lastActiveDate !== today) {
      const adv = advanceStreakDay(p.streak, p.streakFreezes ?? 0, p.lastActiveDate, today);
      effective = adv.streak === p.streak + 1 ? p.streak : 0;
    }
    const s: WidgetSnapshot = {
      schema: 1,
      streak: p.streak,
      effectiveStreak: effective,
      streakFreezes: p.streakFreezes ?? 0,
      studiedToday: p.lastActiveDate === today,
      lastActiveDate: p.lastActiveDate,
      hearts: p.hearts ?? Economy.maxHearts,
      dailyGoal: p.dailyGoal ?? Economy.defaultDailyGoal,
      todayXp: p.lastXpDate === today ? (p.todayXp ?? 0) : 0,
      lastXpDate: p.lastXpDate ?? '',
      savedAtDay: today
    };
    return s;
  }

  /** 与 iOS StreakDisplay 一致的派生逻辑。 */
  static cardData(s: WidgetSnapshot | null, now: Date = new Date()): WidgetCardData {
    const hour = now.getHours();
    const idleMood = hour >= 20 ? 'crying' : (hour >= 12 ? 'worried' : 'calm');
    if (s === null) {
      const empty: WidgetCardData = {
        streak: 0, studiedToday: false, todayXp: 0, dailyGoal: 50, message: '来点燃小火苗吧', mood: idleMood
      };
      return empty;
    }
    const today = todayString(now);
    const studied = s.lastActiveDate.length > 0 && s.lastActiveDate === today;
    let effective = 0;
    if (studied) {
      effective = s.streak;
    } else if (s.lastActiveDate.length > 0) {
      const gap = daysBetween(s.lastActiveDate, today);
      effective = gap <= 1 ? s.streak : (s.streakFreezes >= gap - 1 ? s.streak : 0);
    }
    const mood = studied ? 'happy' : idleMood;
    let message = effective > 0 ? '今天也来学一课吧' : '来点燃小火苗吧';
    if (studied) {
      message = '今天学过啦，真棒！';
    } else if (mood === 'crying') {
      message = '火苗快熄灭啦！';
    } else if (mood === 'worried') {
      message = '小火苗在等你哦';
    }
    const d: WidgetCardData = {
      streak: effective,
      studiedToday: studied,
      todayXp: s.lastXpDate === today ? s.todayXp : 0,
      dailyGoal: s.dailyGoal,
      message: message,
      mood: mood
    };
    return d;
  }

  private static prefs(ctx: common.Context): preferences.Preferences {
    return preferences.getPreferencesSync(ctx, { name: PREF_NAME });
  }

  static push(p: UserProgress): void {
    try {
      const ctx = AppEnv.ctx();
      const json = JSON.stringify(WidgetSync.snapshotOf(p));
      if (json === WidgetSync.lastJson) {
        return;
      }
      WidgetSync.lastJson = json;
      const pref = WidgetSync.prefs(ctx);
      pref.putSync(KEY_SNAPSHOT, json);
      pref.flush();
      WidgetSync.refreshAll(ctx);
    } catch (e) {
      // 卡片只是锦上添花，永远不影响存档主流程
    }
  }

  static loadSnapshot(ctx: common.Context): WidgetSnapshot | null {
    const raw = WidgetSync.prefs(ctx).getSync(KEY_SNAPSHOT, '') as string;
    if (raw.length === 0) {
      return null;
    }
    try {
      return JSON.parse(raw) as WidgetSnapshot;
    } catch (e) {
      return null;
    }
  }

  static formIds(ctx: common.Context): string[] {
    const raw = WidgetSync.prefs(ctx).getSync(KEY_FORMS, '') as string;
    return raw.length === 0 ? [] : raw.split(',');
  }

  static addForm(ctx: common.Context, formId: string): void {
    const ids = WidgetSync.formIds(ctx).filter((id: string) => id !== formId);
    ids.push(formId);
    const pref = WidgetSync.prefs(ctx);
    pref.putSync(KEY_FORMS, ids.join(','));
    pref.flush();
  }

  static removeForm(ctx: common.Context, formId: string): void {
    const pref = WidgetSync.prefs(ctx);
    pref.putSync(KEY_FORMS, WidgetSync.formIds(ctx).filter((id: string) => id !== formId).join(','));
    pref.flush();
  }

  static bindingData(ctx: common.Context): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(WidgetSync.cardData(WidgetSync.loadSnapshot(ctx)));
  }

  static refreshAll(ctx: common.Context): void {
    for (const id of WidgetSync.formIds(ctx)) {
      formProvider.updateForm(id, WidgetSync.bindingData(ctx)).catch(() => {
      });
    }
  }
}
