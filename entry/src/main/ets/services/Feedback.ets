// 触感反馈（HapticEngine.swift）与连胜提醒（NotificationService.swift）。
import { vibrator } from '@kit.SensorServiceKit';
import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { SettingsStore } from '../stores/SettingsStore';
import { AppEnv } from './Files';

export class Haptics {
  private static pulse(ms: number): void {
    if (!SettingsStore.shared.hapticEnabled) {
      return;
    }
    try {
      vibrator.startVibration({ type: 'time', duration: ms }, { id: 0, usage: 'touch' }).catch(() => {
      });
    } catch (e) {
      // 设备不支持振动时静默
    }
  }

  /** 轻点：选项 / 按钮。 */
  static tap(): void {
    Haptics.pulse(8);
  }

  /** 答对。 */
  static correct(): void {
    Haptics.pulse(18);
  }

  /** 答错：两下短震。 */
  static wrong(): void {
    Haptics.pulse(30);
    setTimeout(() => Haptics.pulse(30), 90);
  }

  /** 完成 / 成就：中等双击。 */
  static success(): void {
    Haptics.pulse(20);
    setTimeout(() => Haptics.pulse(26), 100);
  }

  /** 掉红心：重震。 */
  static heartLoss(): void {
    Haptics.pulse(55);
  }
}

export class ReminderContext {
  streak: number;
  dueMistakes: number;

  constructor(streak: number, dueMistakes: number) {
    this.streak = streak;
    this.dueMistakes = dueMistakes;
  }
}

class ReminderCopy {
  title: string;
  body: string;

  constructor(title: string, body: string) {
    this.title = title;
    this.body = body;
  }
}

/** 7 天滚动提醒窗口 + 文案阶梯（ios-retention-8）。 */
export class StreakReminders {
  static readonly days: number = 7;

  static copy(slot: number, ctx: ReminderContext): ReminderCopy {
    switch (slot) {
      case 0:
        return ctx.streak > 0
          ? new ReminderCopy('别让连胜断掉', `你已经连续学习 ${ctx.streak} 天了，今天再学一节就能保住 🔥`)
          : new ReminderCopy('今天学一点吧', '几分钟就能完成一节小课，聪聪在等你 📚');
      case 1:
        return ctx.dueMistakes > 0
          ? new ReminderCopy('错题本在等你', `错题本有 ${ctx.dueMistakes} 题等你，回来把它们消灭掉吧 ✏️`)
          : new ReminderCopy('温故而知新', '回来复习一节小课，学过的知识才记得牢 ✏️');
      case 2:
        return new ReminderCopy('聪聪想你了', '两天没见啦，回来学一节课陪陪聪聪吧 🐼');
      case 3:
        return new ReminderCopy('宝石在等你', '完成每日任务就能赢宝石，今天的任务还空着呢 💎');
      case 4:
        return new ReminderCopy('小步也是前进', '哪怕只学 5 分钟也很棒，来做一节小课吧 ⭐');
      case 5:
        return new ReminderCopy('明天是最后一条提醒', '聪聪不想变成唠叨鬼，今天回来学一节，我们就继续每天见 📚');
      default:
        return new ReminderCopy('聪聪先不打扰啦', '提醒好像帮不上忙，聪聪先不打扰啦，想我了随时回来 🐼');
    }
  }

  static async requestAuthorization(): Promise<boolean> {
    try {
      await notificationManager.requestEnableNotification(AppEnv.ctx());
    } catch (e) {
      // 用户拒绝或已授权都会走到这里，统一以实际状态为准
    }
    return StreakReminders.isAuthorized();
  }

  static async isAuthorized(): Promise<boolean> {
    try {
      return await notificationManager.isNotificationEnabled();
    } catch (e) {
      return false;
    }
  }

  static async cancel(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (e) {
      // 无挂起提醒
    }
  }

  /** 取消并重建 7 天提醒窗口。已学习则从明天开始。 */
  private static chain: Promise<void> = Promise.resolve();

  /** 串行化：cancel + publish 交错会产生重复或超出系统上限的提醒。 */
  static reschedule(ctx: ReminderContext, studiedToday: boolean, now: Date = new Date()): Promise<void> {
    StreakReminders.chain = StreakReminders.chain.then(() => StreakReminders.doReschedule(ctx, studiedToday, now))
      .catch(() => {
      });
    return StreakReminders.chain;
  }

  private static async doReschedule(ctx: ReminderContext, studiedToday: boolean, now: Date): Promise<void> {
    if (!SettingsStore.shared.streakReminderEnabled) {
      await StreakReminders.cancel();
      return;
    }
    if (!(await StreakReminders.isAuthorized())) {
      return;
    }
    if (!SettingsStore.shared.streakReminderEnabled) {
      return;
    }
    await StreakReminders.cancel();
    const hour = SettingsStore.shared.reminderHour;
    const minute = SettingsStore.shared.reminderMinute;
    const todaySlot = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute);
    const firstOffset = (!studiedToday && todaySlot.getTime() > now.getTime() + 60000) ? 0 : 1;
    const ctxAbility = AppEnv.ctx();
    for (let i = 0; i < StreakReminders.days; i++) {
      const fire = new Date(todaySlot.getFullYear(), todaySlot.getMonth(), todaySlot.getDate() + firstOffset + i, hour,
        minute);
      const copy = StreakReminders.copy(i, ctx);
      const req: reminderAgentManager.ReminderRequestCalendar = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
        dateTime: {
          year: fire.getFullYear(),
          month: fire.getMonth() + 1,
          day: fire.getDate(),
          hour: fire.getHours(),
          minute: fire.getMinutes()
        },
        title: copy.title,
        content: copy.body,
        notificationId: 7100 + i,
        slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        wantAgent: {
          pkgName: ctxAbility.abilityInfo.bundleName,
          abilityName: 'EntryAbility'
        }
      };
      try {
        await reminderAgentManager.publishReminder(req);
      } catch (e) {
        console.warn(`[StreakReminders] publish failed: ${JSON.stringify(e)}`);
      }
    }
  }
}
