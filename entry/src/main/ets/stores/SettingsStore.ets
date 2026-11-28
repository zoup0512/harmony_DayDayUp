// 用户偏好（静音 / 自动朗读 / 触感 / 外观 / 连胜提醒）——SettingsStore.swift 的镜像，持久化到 Preferences。
import { preferences } from '@kit.ArkData';
import { AppEnv } from '../services/Files';

export type AppAppearance = 'system' | 'light' | 'dark';

export function appearanceLabel(a: AppAppearance): string {
  switch (a) {
    case 'system':
      return '跟随系统';
    case 'light':
      return '浅色';
    default:
      return '深色';
  }
}

const K_MUTED = 'cstf.muted';
const K_AUTO = 'cstf.autoNarrate';
const K_HAPTIC = 'cstf.hapticEnabled';
const K_APPEARANCE = 'cstf.appearance';
const K_REMINDER = 'cstf.streakReminder';
const K_HOUR = 'cstf.reminderHour';
const K_MINUTE = 'cstf.reminderMinute';
const K_KIDS = 'cstf.kidsMode';
const K_ADVANCE = 'cstf.autoAdvance';

@ObservedV2
export class SettingsStore {
  static readonly shared: SettingsStore = new SettingsStore();
  static readonly defaultReminderHour: number = 20;
  static readonly defaultReminderMinute: number = 0;

  @Trace isMuted: boolean = false;
  @Trace autoNarrate: boolean = true;
  @Trace autoAdvance: boolean = true;
  @Trace hapticEnabled: boolean = true;
  @Trace appearance: AppAppearance = 'light';
  @Trace streakReminderEnabled: boolean = false;
  @Trace reminderHour: number = 20;
  @Trace reminderMinute: number = 0;
  /** 儿童模式（默认开）：答错不扣红心，改为封存宝箱 + 心魔试炼；课内编排神速 / 踮脚题。 */
  @Trace kidsMode: boolean = true;

  /** 系统当前是否深色（EntryAbility 在启动与 onConfigurationUpdate 时写入）。 */
  @Trace systemDark: boolean = false;

  private prefs: preferences.Preferences | null = null;
  private listeners: Array<() => void> = [];

  onChange(cb: () => void): () => void {
    this.listeners.push(cb);
    return () => {
      this.listeners = this.listeners.filter((x: () => void) => x !== cb);
    };
  }

  private emit(): void {
    this.listeners.forEach((cb: () => void) => cb());
  }

  /** 外观设置 + 系统明暗 → 是否使用深色界面。 */
  get prefersDark(): boolean {
    return this.appearance === 'dark' || (this.appearance === 'system' && this.systemDark);
  }

  setSystemDark(v: boolean): void {
    if (this.systemDark !== v) {
      this.systemDark = v;
      this.emit();
    }
  }

  load(): void {
    this.prefs = preferences.getPreferencesSync(AppEnv.ctx(), { name: 'cstf_settings' });
    const p = this.prefs;
    this.isMuted = p.getSync(K_MUTED, false) as boolean;
    this.autoNarrate = p.getSync(K_AUTO, true) as boolean;
    this.autoAdvance = p.getSync(K_ADVANCE, true) as boolean;
    this.hapticEnabled = p.getSync(K_HAPTIC, true) as boolean;
    const raw = p.getSync(K_APPEARANCE, 'light') as string;
    this.appearance = (raw === 'system' || raw === 'dark') ? raw : 'light';
    this.streakReminderEnabled = p.getSync(K_REMINDER, false) as boolean;
    const h = p.getSync(K_HOUR, SettingsStore.defaultReminderHour) as number;
    this.reminderHour = h >= 0 && h <= 23 ? h : SettingsStore.defaultReminderHour;
    const m = p.getSync(K_MINUTE, SettingsStore.defaultReminderMinute) as number;
    this.reminderMinute = m >= 0 && m <= 59 ? m : SettingsStore.defaultReminderMinute;
    this.kidsMode = p.getSync(K_KIDS, true) as boolean;
  }

  setKidsMode(v: boolean): void {
    this.kidsMode = v;
    this.put(K_KIDS, v);
    this.emit();
  }

  private put(key: string, value: boolean | number | string): void {
    if (this.prefs === null) {
      return;
    }
    this.prefs.putSync(key, value);
    this.prefs.flush();
  }

  setMuted(v: boolean): void {
    this.isMuted = v;
    this.put(K_MUTED, v);
  }

  toggleMute(): void {
    this.setMuted(!this.isMuted);
  }

  setAutoNarrate(v: boolean): void {
    this.autoNarrate = v;
    this.put(K_AUTO, v);
  }

  setAutoAdvance(v: boolean): void {
    this.autoAdvance = v;
    this.put(K_ADVANCE, v);
  }

  setHaptic(v: boolean): void {
    this.hapticEnabled = v;
    this.put(K_HAPTIC, v);
  }

  setAppearance(v: AppAppearance): void {
    this.appearance = v;
    this.put(K_APPEARANCE, v);
    this.emit();
  }

  setStreakReminder(v: boolean): void {
    this.streakReminderEnabled = v;
    this.put(K_REMINDER, v);
    this.emit();
  }

  setReminderTime(hour: number, minute: number): void {
    this.reminderHour = hour;
    this.reminderMinute = minute;
    this.put(K_HOUR, hour);
    this.put(K_MINUTE, minute);
    this.emit();
  }

  get reminderTimeLabel(): string {
    const h = this.reminderHour < 10 ? `0${this.reminderHour}` : `${this.reminderHour}`;
    const m = this.reminderMinute < 10 ? `0${this.reminderMinute}` : `${this.reminderMinute}`;
    return `${h}:${m}`;
  }

  // 通用小账本（替代 iOS UserDefaults 的零散键）
  getString(key: string): string {
    return this.prefs === null ? '' : this.prefs.getSync(key, '') as string;
  }

  setString(key: string, value: string): void {
    this.put(key, value);
  }
}
