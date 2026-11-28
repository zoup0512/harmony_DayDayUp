// 家长密码（与 Web 版 parentLock 同一套规则）：全家共用、不随孩子切换的 4–6 位数字。
// 只防孩子误操作：本地只存加盐 sha256；解锁后 10 分钟内（本进程）不再询问。
import { SettingsStore } from '../stores/SettingsStore';
import { Files } from './Files';

const K_PARENT = 'cstf.parentLock';
export const PARENT_UNLOCK_MS: number = 10 * 60000;
const PIN_RE: RegExp = new RegExp('^\\d{4,6}$');

interface ParentConfig {
  salt: string;
  hash: string;
  lockSwitch: boolean;
}

export class AdultChallenge {
  question: string;
  answer: number;

  constructor(question: string, answer: number) {
    this.question = question;
    this.answer = answer;
  }
}

export class ParentLock {
  private static unlockedUntil: number = 0;

  private static read(): ParentConfig | null {
    const raw = SettingsStore.shared.getString(K_PARENT);
    if (raw.length === 0) {
      return null;
    }
    try {
      const c = JSON.parse(raw) as ParentConfig;
      return typeof c.salt === 'string' && typeof c.hash === 'string' ? c : null;
    } catch (e) {
      return null;
    }
  }

  private static write(c: ParentConfig | null): void {
    SettingsStore.shared.setString(K_PARENT, c === null ? '' : JSON.stringify(c));
  }

  private static digest(salt: string, pin: string): string {
    return Files.sha256OfText(`${salt}:${pin}`);
  }

  static isValidPin(pin: string): boolean {
    return PIN_RE.test(pin);
  }

  static get hasPin(): boolean {
    return ParentLock.read() !== null;
  }

  static get lockSwitch(): boolean {
    return ParentLock.read()?.lockSwitch ?? false;
  }

  static setPin(pin: string): boolean {
    if (!ParentLock.isValidPin(pin)) {
      return false;
    }
    const salt = Files.uuid();
    ParentLock.write({ salt: salt, hash: ParentLock.digest(salt, pin), lockSwitch: ParentLock.lockSwitch });
    ParentLock.unlock();
    return true;
  }

  static verify(pin: string): boolean {
    const c = ParentLock.read();
    return c === null || ParentLock.digest(c.salt, pin) === c.hash;
  }

  static clearPin(): void {
    ParentLock.write(null);
    ParentLock.lock();
  }

  static setLockSwitch(on: boolean): void {
    const c = ParentLock.read();
    if (c !== null) {
      ParentLock.write({ salt: c.salt, hash: c.hash, lockSwitch: on });
    }
  }

  static isUnlocked(now: number = Date.now()): boolean {
    return !ParentLock.hasPin || ParentLock.unlockedUntil > now;
  }

  static unlock(now: number = Date.now()): void {
    ParentLock.unlockedUntil = now + PARENT_UNLOCK_MS;
  }

  static lock(): void {
    ParentLock.unlockedUntil = 0;
  }

  /** 「忘记密码」用的成人题：两位数 × 一位数。 */
  static challenge(): AdultChallenge {
    const a = 12 + Math.floor(Math.random() * 87);
    const b = 3 + Math.floor(Math.random() * 7);
    return new AdultChallenge(`${a} × ${b} = ?`, a * b);
  }
}
