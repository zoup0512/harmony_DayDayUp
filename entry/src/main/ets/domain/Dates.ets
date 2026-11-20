// 日期工具 —— SRS.swift / Week.swift / core week.ts 的镜像（本地时区自然日）。

export const DAY_MS: number = 86400000;

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** YYYY-MM-DD（本地时区） */
export function dateKey(date: Date = new Date()): string {
  return `${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`;
}

export function todayString(now: Date = new Date()): string {
  return dateKey(now);
}

export function dateString(daysFromNow: number, now: Date = new Date()): string {
  return dateKey(new Date(now.getFullYear(), now.getMonth(), now.getDate() + daysFromNow));
}

export function isDateKey(key: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) {
    return false;
  }
  const parts = key.split('-').map((s: string) => Number(s));
  const y = parts[0];
  const m = parts[1];
  const d = parts[2];
  if (m < 1 || m > 12 || d < 1 || d > 31) {
    return false;
  }
  const probe = new Date(y, m - 1, d);
  return probe.getFullYear() === y && probe.getMonth() === m - 1 && probe.getDate() === d;
}

export function parseDateKey(key: string): Date | null {
  if (!isDateKey(key)) {
    return null;
  }
  const parts = key.split('-').map((s: string) => Number(s));
  return new Date(parts[0], parts[1] - 1, parts[2]);
}

export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

/** 两个 YYYY-MM-DD 之间相差的自然日；无法解析时返回极大值（与 Swift Int.max 同义）。 */
export function daysBetween(from: string, to: string): number {
  const a = parseDateKey(from);
  const b = parseDateKey(to);
  if (a === null || b === null) {
    return Number.MAX_SAFE_INTEGER;
  }
  return Math.round((b.getTime() - a.getTime()) / DAY_MS);
}

/** 本周周一的 YYYY-MM-DD（周一自身返回当天）。 */
export function weekStartKey(date: Date = new Date()): string {
  const offset = (date.getDay() + 6) % 7;
  return dateKey(new Date(date.getFullYear(), date.getMonth(), date.getDate() - offset));
}

/** weekKey 所在周的 7 个日期键（周一 → 周日）。 */
export function weekDateKeys(key: string, now: Date = new Date()): string[] {
  const parsed = parseDateKey(key);
  const monday: Date = parsed !== null
    ? new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate() - ((parsed.getDay() + 6) % 7))
    : (parseDateKey(weekStartKey(now)) ?? startOfDay(now));
  const out: string[] = [];
  for (let i = 0; i < 7; i++) {
    out.push(dateKey(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i)));
  }
  return out;
}

/** date 在 weekKey 那周的下标（周一=0）；可能 <0 或 >6。 */
export function dayIndexInWeek(weekKey: string, date: Date, now: Date = new Date()): number {
  const monday = parseDateKey(weekKey) ?? parseDateKey(weekStartKey(now)) ?? startOfDay(now);
  return Math.round((startOfDay(date).getTime() - monday.getTime()) / DAY_MS);
}

export function weekStartKeyWeeksAgo(weeksAgo: number, now: Date = new Date()): string {
  const shifted = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7 * Math.max(0, weeksAgo),
    now.getHours(), now.getMinutes());
  return weekStartKey(shifted);
}

export function isoString(date: Date = new Date()): string {
  return date.toISOString();
}

export function weekdayLabel(key: string): string {
  const d = parseDateKey(key);
  if (d === null) {
    return '·';
  }
  return ['日', '一', '二', '三', '四', '五', '六'][d.getDay()];
}

export function formatCountdown(targetMs: number, nowMs: number): string {
  const remaining = Math.max(0, Math.floor((targetMs - nowMs) / 1000));
  const minutes = Math.floor(remaining / 60);
  const seconds = remaining % 60;
  return `${minutes}:${pad2(seconds)}`;
}

export function formatBytes(bytes: number): string {
  if (bytes >= 1000000) {
    return `${(bytes / 1000000).toFixed(1)} MB`;
  }
  if (bytes >= 1000) {
    return `${Math.round(bytes / 1000)} KB`;
  }
  return `${bytes} 字节`;
}
