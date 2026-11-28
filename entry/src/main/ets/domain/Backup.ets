// 存档备份信封 v1（与 Web / iOS 双端互通）—— Backup.swift / core backup.ts 的镜像。
import { LessonResult, MistakeEntry, Question, UserProgress } from '../models/Types';
import { Economy } from './Economy';
import { Cosmetics, normalizeReadingIds, normalizeReadingMap } from './Catalog';
import { isoString, todayString } from './Dates';

export const BACKUP_SCHEMA: string = 'cstf-backup';
export const BACKUP_VERSION: number = 1;

export interface LessonResultPayload {
  stars: number;
  accuracy: number;
  completedAt: string;
}

export interface MistakePayload {
  lessonId: string;
  questionId: number;
  box?: number | null;
  correctCount?: number | null;
  nextReviewDate?: string | null;
  graduated?: boolean | null;
  question?: Question | null;
}

export interface EquippedPayload {
  mascotSkin: string;
  uiTheme: string;
  lessonBackdrop: string;
}

export interface DataPayload {
  xp: number;
  streak: number;
  lastActiveDate: string;
  streakFreezes: number;
  gems: number;
  lifetimeGems: number;
  hearts: number;
  dailyGoal: number;
  joinedDate?: string | null;
  completedLessons: Record<string, LessonResultPayload>;
  completedReadings: Record<string, string>;
  perfectedLessons?: Record<string, boolean> | null;
  mistakesBank: MistakePayload[];
  claimedChests: Record<string, boolean>;
  claimedStreakRewards: Record<string, boolean>;
  claimedQuests: Record<string, boolean>;
  lastDailyRewardDate: string;
  unlockedAchievements: Record<string, boolean>;
  claimedAchievements?: Record<string, boolean> | null;
  ownedCosmetics: Record<string, boolean>;
  equipped: EquippedPayload;
  xpHistory: Record<string, number>;
  leagueTier?: string | null;
  leagueWeekKey?: string | null;
}

/** 存档归属的孩子（v1 内可选的顶层元数据，与 core BackupLearner 一致；旧端忽略）。 */
export interface BackupLearner {
  id: string;
  name: string;
  color?: string | null;
}

export interface BackupEnvelope {
  schema: string;
  version: number;
  exportedAt: string;
  platform: string;
  learner?: BackupLearner | null;
  data: DataPayload;
}

export class BackupValidation {
  envelope: BackupEnvelope | null;
  error: string | null;

  constructor(envelope: BackupEnvelope | null, error: string | null) {
    this.envelope = envelope;
    this.error = error;
  }
}

type JsonObj = Record<string, Object>;

function isObj(v: Object | undefined | null): boolean {
  return v !== undefined && v !== null && typeof v === 'object' && !Array.isArray(v);
}

function intOf(o: JsonObj, key: string): number | null {
  const v = o[key];
  if (typeof v === 'number' && Number.isFinite(v as number) && Math.round(v as number) === (v as number)) {
    return v as number;
  }
  return null;
}

function strOf(o: JsonObj, key: string): string | null {
  const v = o[key];
  return typeof v === 'string' ? (v as string) : null;
}

function flagsOf(o: JsonObj, key: string): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  const v = o[key];
  if (!isObj(v)) {
    return out;
  }
  const m = v as JsonObj;
  for (const k of Object.keys(m)) {
    if (m[k] === true) {
      out[k] = true;
    }
  }
  return out;
}

function defaultPayload(): DataPayload {
  const d: DataPayload = {
    xp: 0, streak: 0, lastActiveDate: '', streakFreezes: Economy.initialFreezes, gems: 0, lifetimeGems: 0,
    hearts: Economy.maxHearts, dailyGoal: Economy.defaultDailyGoal, joinedDate: null,
    completedLessons: {}, completedReadings: {}, perfectedLessons: null, mistakesBank: [],
    claimedChests: {}, claimedStreakRewards: {}, claimedQuests: {}, lastDailyRewardDate: '',
    unlockedAchievements: {}, claimedAchievements: null, ownedCosmetics: {},
    equipped: { mascotSkin: Cosmetics.defaultSkin, uiTheme: Cosmetics.defaultTheme, lessonBackdrop: Cosmetics.defaultBackdrop },
    xpHistory: {}, leagueTier: null, leagueWeekKey: null
  };
  return d;
}

/** 宽容解码：坏类型 → 默认值，非法条目丢弃。 */
function decodePayload(c: JsonObj): DataPayload {
  const d = defaultPayload();
  const setNonNeg = (key: string): number | null => {
    const v = intOf(c, key);
    return v !== null && v >= 0 ? v : null;
  };
  d.xp = setNonNeg('xp') ?? d.xp;
  d.streak = setNonNeg('streak') ?? d.streak;
  d.lastActiveDate = strOf(c, 'lastActiveDate') ?? d.lastActiveDate;
  d.streakFreezes = setNonNeg('streakFreezes') ?? d.streakFreezes;
  d.gems = setNonNeg('gems') ?? d.gems;
  d.lifetimeGems = setNonNeg('lifetimeGems') ?? d.lifetimeGems;
  d.hearts = setNonNeg('hearts') ?? d.hearts;
  d.dailyGoal = setNonNeg('dailyGoal') ?? d.dailyGoal;
  d.joinedDate = strOf(c, 'joinedDate');

  const lessons = c['completedLessons'];
  if (isObj(lessons)) {
    const m = lessons as JsonObj;
    for (const k of Object.keys(m)) {
      const r = m[k];
      if (!isObj(r)) {
        continue;
      }
      const ro = r as JsonObj;
      const stars = ro['stars'];
      const acc = ro['accuracy'];
      const at = ro['completedAt'];
      if (typeof stars === 'number' && typeof acc === 'number' && typeof at === 'string') {
        const p: LessonResultPayload = { stars: stars as number, accuracy: acc as number, completedAt: at as string };
        d.completedLessons[k] = p;
      }
    }
  }

  const readings = c['completedReadings'];
  if (isObj(readings)) {
    const m = readings as JsonObj;
    const raw: Record<string, string> = {};
    for (const k of Object.keys(m)) {
      if (typeof m[k] === 'string') {
        raw[k] = m[k] as string;
      }
    }
    d.completedReadings = normalizeReadingMap(raw);
  }

  if (isObj(c['perfectedLessons'])) {
    d.perfectedLessons = flagsOf(c, 'perfectedLessons');
  }

  const mistakes = c['mistakesBank'];
  if (Array.isArray(mistakes)) {
    for (const item of mistakes as Object[]) {
      if (!isObj(item)) {
        continue;
      }
      const mo = item as JsonObj;
      const lessonId = strOf(mo, 'lessonId');
      const questionId = intOf(mo, 'questionId');
      if (lessonId === null || questionId === null) {
        continue;
      }
      const q = mo['question'];
      const mp: MistakePayload = {
        lessonId: lessonId,
        questionId: questionId,
        box: intOf(mo, 'box'),
        correctCount: intOf(mo, 'correctCount'),
        nextReviewDate: strOf(mo, 'nextReviewDate'),
        graduated: typeof mo['graduated'] === 'boolean' ? (mo['graduated'] as boolean) : null,
        question: isObj(q) && typeof (q as JsonObj)['question'] === 'string' ? (q as Question) : null
      };
      d.mistakesBank.push(mp);
    }
  }

  d.claimedChests = flagsOf(c, 'claimedChests');
  d.claimedStreakRewards = flagsOf(c, 'claimedStreakRewards');
  d.claimedQuests = flagsOf(c, 'claimedQuests');
  d.lastDailyRewardDate = strOf(c, 'lastDailyRewardDate') ?? '';
  d.unlockedAchievements = flagsOf(c, 'unlockedAchievements');
  if (c['claimedAchievements'] !== undefined) {
    d.claimedAchievements = flagsOf(c, 'claimedAchievements');
  }
  d.ownedCosmetics = flagsOf(c, 'ownedCosmetics');

  const eq = c['equipped'];
  if (isObj(eq)) {
    const eo = eq as JsonObj;
    const ms = strOf(eo, 'mascotSkin');
    const ut = strOf(eo, 'uiTheme');
    const lb = strOf(eo, 'lessonBackdrop');
    if (ms !== null && ut !== null && lb !== null) {
      d.equipped = { mascotSkin: ms, uiTheme: ut, lessonBackdrop: lb };
    }
  }

  const hist = c['xpHistory'];
  if (isObj(hist)) {
    const m = hist as JsonObj;
    for (const k of Object.keys(m)) {
      const v = intOf(m, k);
      if (v !== null && v >= 0) {
        d.xpHistory[k] = v;
      }
    }
  }
  d.leagueTier = strOf(c, 'leagueTier');
  d.leagueWeekKey = strOf(c, 'leagueWeekKey');
  return d;
}

export function validateBackup(raw: string): BackupValidation {
  let top: Object | null = null;
  try {
    top = JSON.parse(raw) as Object;
  } catch (e) {
    return new BackupValidation(null, '备份内容不是 JSON 对象');
  }
  if (!isObj(top)) {
    return new BackupValidation(null, '备份内容不是 JSON 对象');
  }
  const t = top as JsonObj;
  if (t['schema'] !== BACKUP_SCHEMA) {
    return new BackupValidation(null, '这不是本应用的备份文件');
  }
  const version = intOf(t, 'version');
  if (version === null || version < 1) {
    return new BackupValidation(null, '备份版本号缺失或不合法');
  }
  if (!isObj(t['data'])) {
    return new BackupValidation(null, '备份缺少 data 字段');
  }
  let platform = strOf(t, 'platform') ?? 'web';
  if (platform !== 'ios' && platform !== 'web' && platform !== 'harmony') {
    platform = 'web';
  }
  const env: BackupEnvelope = {
    schema: BACKUP_SCHEMA,
    version: version,
    exportedAt: strOf(t, 'exportedAt') ?? '',
    platform: platform,
    learner: learnerOf(t['learner']),
    data: decodePayload(t['data'] as JsonObj)
  };
  return new BackupValidation(env, null);
}

const LEARNER_ID_RE: RegExp = new RegExp('^[a-zA-Z0-9-]{1,64}$');

/** 归属元数据坏了不致命：丢掉，导入端按「未标明孩子」处理。 */
function learnerOf(v: Object | undefined | null): BackupLearner | null {
  if (!isObj(v)) {
    return null;
  }
  const o = v as JsonObj;
  const id = strOf(o, 'id');
  const name = (strOf(o, 'name') ?? '').trim();
  if (id === null || !LEARNER_ID_RE.test(id) || name.length === 0) {
    return null;
  }
  return { id: id, name: name.substring(0, 20), color: strOf(o, 'color') };
}

// ============================================================
// 全家备份：一个文件装多个孩子的单人信封（core FAMILY_BACKUP_SCHEMA 的镜像）
// ============================================================

export const FAMILY_BACKUP_SCHEMA: string = 'cstf-family-backup';
export const FAMILY_BACKUP_VERSION: number = 1;

export interface FamilyBackupEnvelope {
  schema: string;
  version: number;
  exportedAt: string;
  platform: string;
  learners: BackupEnvelope[];
}

export function makeFamilyEnvelope(learners: BackupEnvelope[], exportedAt: Date = new Date()): FamilyBackupEnvelope {
  return {
    schema: FAMILY_BACKUP_SCHEMA, version: FAMILY_BACKUP_VERSION, exportedAt: isoString(exportedAt),
    platform: 'harmony', learners: learners
  };
}

export class AnyBackupValidation {
  family: boolean;
  entries: BackupEnvelope[];
  exportedAt: string;
  /** 致命原因（entries 为空时） */
  error: string | null;
  /** 全家备份里被跳过的条目数 */
  skipped: number;

  constructor(family: boolean, entries: BackupEnvelope[], exportedAt: string, error: string | null, skipped: number) {
    this.family = family;
    this.entries = entries;
    this.exportedAt = exportedAt;
    this.error = error;
    this.skipped = skipped;
  }
}

/** 单人存档与全家备份都收；全家备份里坏条目跳过、重复孩子 id 降级为未标明，一个都读不出才拒收。 */
export function validateAnyBackup(raw: string): AnyBackupValidation {
  let top: Object | null = null;
  try {
    top = JSON.parse(raw) as Object;
  } catch (e) {
    return new AnyBackupValidation(false, [], '', '备份内容不是 JSON 对象', 0);
  }
  if (!isObj(top) || (top as JsonObj)['schema'] !== FAMILY_BACKUP_SCHEMA) {
    const single = validateBackup(raw);
    return single.envelope === null ? new AnyBackupValidation(false, [], '', single.error, 0) :
      new AnyBackupValidation(false, [single.envelope], single.envelope.exportedAt, null, 0);
  }
  const t = top as JsonObj;
  const version = intOf(t, 'version');
  if (version === null || version < 1) {
    return new AnyBackupValidation(true, [], '', '备份版本号缺失或不合法', 0);
  }
  const list = t['learners'];
  if (!Array.isArray(list)) {
    return new AnyBackupValidation(true, [], '', '全家备份缺少 learners 列表', 0);
  }
  const entries: BackupEnvelope[] = [];
  const seen = new Set<string>();
  let skipped = 0;
  (list as Object[]).forEach((item: Object) => {
    const v = validateBackup(JSON.stringify(item));
    if (v.envelope === null) {
      skipped++;
      return;
    }
    const env = v.envelope;
    const owner = env.learner;
    if (owner !== undefined && owner !== null) {
      if (seen.has(owner.id)) {
        env.learner = null;
      } else {
        seen.add(owner.id);
      }
    }
    entries.push(env);
  });
  if (entries.length === 0) {
    return new AnyBackupValidation(true, [], '', '全家备份里没有可导入的孩子', skipped);
  }
  return new AnyBackupValidation(true, entries, strOf(t, 'exportedAt') ?? '', null, skipped);
}

function flagMap(ids: string[]): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  ids.forEach((id: string) => {
    out[id] = true;
  });
  return out;
}

function trueKeys(r: Record<string, boolean> | null | undefined): string[] {
  if (r === null || r === undefined) {
    return [];
  }
  return Object.keys(r).filter((k: string) => r[k] === true).sort();
}

export function makeEnvelope(p: UserProgress, exportedAt: Date = new Date()): BackupEnvelope {
  const data = defaultPayload();
  data.xp = Math.max(0, p.xp);
  data.streak = Math.max(0, p.streak);
  data.lastActiveDate = p.lastActiveDate;
  data.streakFreezes = Math.max(0, p.streakFreezes ?? Economy.initialFreezes);
  data.gems = Math.max(0, p.gems ?? 0);
  data.lifetimeGems = Math.max(0, p.lifetimeGems ?? (p.gems ?? 0));
  data.hearts = Math.min(Math.max(0, p.hearts ?? Economy.maxHearts), Economy.maxHearts);
  data.dailyGoal = Math.max(0, p.dailyGoal ?? Economy.defaultDailyGoal);
  data.joinedDate = p.joinedDate;
  const perfected: string[] = [];
  for (const id of Object.keys(p.completedLessons)) {
    const r = p.completedLessons[id];
    const payload: LessonResultPayload = {
      stars: Math.min(Math.max(1, r.stars), 3),
      accuracy: Math.min(Math.max(0, r.accuracy), 1),
      completedAt: r.completedAt
    };
    data.completedLessons[id] = payload;
    if (r.stars >= 3) {
      perfected.push(id);
    }
  }
  const readDate = (p.joinedDate !== undefined && p.joinedDate !== null && p.joinedDate.length > 0) ? p.joinedDate :
    todayString(exportedAt);
  const raw: Record<string, string> = {};
  (p.completedReadings ?? []).forEach((id: string) => {
    if (raw[id] === undefined) {
      raw[id] = readDate;
    }
  });
  data.completedReadings = normalizeReadingMap(raw);
  if (perfected.length > 0) {
    data.perfectedLessons = flagMap(perfected);
  }
  data.mistakesBank = p.mistakesBank.map((e: MistakeEntry) => {
    const mp: MistakePayload = {
      lessonId: e.lessonId, questionId: e.question.id, box: e.box, correctCount: e.correctCount,
      nextReviewDate: e.nextReviewDate, graduated: e.graduated, question: e.question
    };
    return mp;
  });
  data.claimedChests = flagMap(trueKeys(p.claimedChests));
  data.claimedStreakRewards = flagMap((p.claimedStreakRewards ?? []).map((n: number) => `${n}`));
  data.claimedQuests = flagMap(p.claimedQuests ?? []);
  data.lastDailyRewardDate = p.lastDailyRewardDate ?? '';
  data.unlockedAchievements = flagMap(p.unlockedAchievements ?? []);
  data.claimedAchievements = flagMap(p.claimedAchievements ?? []);
  data.ownedCosmetics = flagMap(p.ownedCosmetics ?? []);
  data.equipped = {
    mascotSkin: p.equippedMascotSkin ?? Cosmetics.defaultSkin,
    uiTheme: p.equippedTheme ?? Cosmetics.defaultTheme,
    lessonBackdrop: p.equippedBackdrop ?? Cosmetics.defaultBackdrop
  };
  const hist = p.xpHistory ?? {};
  for (const k of Object.keys(hist)) {
    if (hist[k] >= 0) {
      data.xpHistory[k] = hist[k];
    }
  }
  data.leagueTier = p.leagueTier;
  data.leagueWeekKey = p.leagueWeekKey;
  const env: BackupEnvelope = {
    schema: BACKUP_SCHEMA, version: BACKUP_VERSION, exportedAt: isoString(exportedAt), platform: 'harmony', data: data
  };
  return env;
}

export function encodeBackup(env: BackupEnvelope): string {
  return JSON.stringify(env, null, 2);
}

export function userProgressFromEnvelope(env: BackupEnvelope,
  questionLookup: (lessonId: string, questionId: number) => Question | null,
  keepLeagueSalt: string | null | undefined, keepReviewHeartDate: string | null | undefined,
  now: Date = new Date()): UserProgress {
  const d = env.data;
  const today = todayString(now);
  const completed: Record<string, LessonResult> = {};
  for (const id of Object.keys(d.completedLessons)) {
    const r = d.completedLessons[id];
    const lr: LessonResult = {
      lessonId: id,
      stars: Math.min(Math.max(1, r.stars), 3),
      accuracy: Math.min(Math.max(0, r.accuracy), 1),
      completedAt: r.completedAt
    };
    completed[id] = lr;
  }
  const bank: MistakeEntry[] = [];
  for (const m of d.mistakesBank) {
    const question = m.question ?? questionLookup(m.lessonId, m.questionId);
    if (question === null || question === undefined) {
      continue;
    }
    const e: MistakeEntry = {
      lessonId: m.lessonId,
      lessonTitle: null,
      question: question,
      addedAt: env.exportedAt,
      box: (m.box === null || m.box === undefined) ? null : Math.min(Math.max(1, m.box), 3),
      correctCount: (m.correctCount === null || m.correctCount === undefined) ? null : Math.max(0, m.correctCount),
      lastReviewedAt: null,
      nextReviewDate: m.nextReviewDate,
      graduated: m.graduated
    };
    bank.push(e);
  }
  const hearts = Math.min(Math.max(0, d.hearts), Economy.maxHearts);
  const history: Record<string, number> = {};
  for (const k of Object.keys(d.xpHistory)) {
    if (d.xpHistory[k] >= 0) {
      history[k] = d.xpHistory[k];
    }
  }
  const todayXp = history[today];
  const p: UserProgress = {
    xp: Math.max(0, d.xp),
    streak: Math.max(0, d.streak),
    lastActiveDate: d.lastActiveDate,
    completedLessons: completed,
    mistakesBank: bank,
    hearts: hearts,
    nextHeartAt: hearts < Economy.maxHearts ? now.getTime() + Economy.heartRegenSeconds * 1000 : null,
    gems: Math.max(0, d.gems),
    lifetimeGems: Math.max(Math.max(0, d.lifetimeGems), Math.max(0, d.gems)),
    dailyGoal: d.dailyGoal > 0 ? d.dailyGoal : Economy.defaultDailyGoal,
    streakFreezes: Math.max(0, d.streakFreezes),
    freezesMigrated: true,
    joinedDate: d.joinedDate,
    completedReadings: normalizeReadingIds(Object.keys(d.completedReadings)),
    claimedChests: flagMap(trueKeys(d.claimedChests)),
    claimedStreakRewards: trueKeys(d.claimedStreakRewards).map((k: string) => parseInt(k))
      .filter((n: number) => !isNaN(n)).sort((a: number, b: number) => a - b),
    lastDailyRewardDate: d.lastDailyRewardDate.length === 0 ? null : d.lastDailyRewardDate,
    unlockedAchievements: trueKeys(d.unlockedAchievements),
    claimedAchievements: trueKeys(d.claimedAchievements),
    ownedCosmetics: trueKeys(d.ownedCosmetics),
    equippedMascotSkin: d.equipped.mascotSkin,
    equippedTheme: d.equipped.uiTheme,
    equippedBackdrop: d.equipped.lessonBackdrop,
    xpHistory: history,
    todayXp: todayXp !== undefined ? todayXp : 0,
    lastXpDate: todayXp !== undefined ? today : null,
    claimedQuests: trueKeys(d.claimedQuests),
    lastReviewHeartDate: keepReviewHeartDate,
    leagueSalt: keepLeagueSalt,
    leagueTier: d.leagueTier,
    leagueWeekKey: d.leagueWeekKey
  };
  return p;
}
