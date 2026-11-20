// 成就 / 美妆 / 宝箱 / 学科 / 阅读 id / 聪聪触发器 / 路径课程 —— 对应 iOS Domain/*.swift。
import { Book, MascotMood, MascotReaction, Outline, PathLessonMeta, SubjectId, Unit, KnowledgePoint } from '../models/Types';

// ============================================================
// 成就
// ============================================================

export type AchievementCategory = 'milestone' | 'streak' | 'perfection' | 'shop' | 'review';
export type AchievementMetric = 'lessons' | 'xp' | 'streak' | 'perfect' | 'cosmetics' | 'gems' | 'reviews';

export class AchievementSnapshot {
  xp: number = 0;
  streak: number = 0;
  lifetimeGems: number = 0;
  completedLessonCount: number = 0;
  perfectedLessonCount: number = 0;
  ownedCosmeticCount: number = 0;
  reviewedMistakeCount: number = 0;
}

export class Achievement {
  id: string;
  category: AchievementCategory;
  name: string;
  description: string;
  icon: string;
  color: string;
  goal: number;
  reward: number;
  metric: AchievementMetric;

  constructor(id: string, category: AchievementCategory, name: string, description: string, icon: string,
    color: string, goal: number, reward: number, metric: AchievementMetric) {
    this.id = id;
    this.category = category;
    this.name = name;
    this.description = description;
    this.icon = icon;
    this.color = color;
    this.goal = goal;
    this.reward = reward;
    this.metric = metric;
  }

  progress(s: AchievementSnapshot): number {
    switch (this.metric) {
      case 'lessons':
        return s.completedLessonCount;
      case 'xp':
        return s.xp;
      case 'streak':
        return s.streak;
      case 'perfect':
        return s.perfectedLessonCount;
      case 'cosmetics':
        return Math.max(0, s.ownedCosmeticCount - 3);
      case 'gems':
        return s.lifetimeGems;
      default:
        return s.reviewedMistakeCount;
    }
  }
}

export class AchievementFamily {
  id: string;
  name: string;
  tiers: Achievement[];

  constructor(id: string, name: string, tiers: Achievement[]) {
    this.id = id;
    this.name = name;
    this.tiers = tiers;
  }

  get icon(): string {
    return this.tiers[0].icon;
  }

  highestUnlocked(unlocked: Set<string>): Achievement | undefined {
    let found: Achievement | undefined = undefined;
    for (const t of this.tiers) {
      if (unlocked.has(t.id)) {
        found = t;
      }
    }
    return found;
  }

  nextTier(unlocked: Set<string>): Achievement | undefined {
    return this.tiers.find((t: Achievement) => !unlocked.has(t.id));
  }
}

export class Achievements {
  static readonly all: Achievement[] = [
    new Achievement('first-lesson', 'milestone', '出师告捷', '完成你的第一节课', 'rocket', '#1CB0F6', 1, 20, 'lessons'),
    new Achievement('ten-lessons', 'milestone', '学海十里', '累计完成 10 节课', 'bookmark', '#1CB0F6', 10, 50, 'lessons'),
    new Achievement('fifty-lessons', 'milestone', '百炼成钢', '累计完成 50 节课', 'trophy', '#A855F7', 50, 100, 'lessons'),
    new Achievement('xp-100', 'milestone', '初露锋芒', '累计 100 经验', 'bolt', '#1CB0F6', 100, 20, 'xp'),
    new Achievement('xp-1000', 'milestone', '经验丰富', '累计 1000 经验', 'bolt', '#A855F7', 1000, 50, 'xp'),
    new Achievement('xp-5000', 'milestone', '学霸认证', '累计 5000 经验', 'bolt', '#FFC800', 5000, 100, 'xp'),
    new Achievement('streak-3', 'streak', '三日不辍', '连续学习 3 天', 'flame', '#FF9600', 3, 20, 'streak'),
    new Achievement('streak-7', 'streak', '一周如一日', '连续学习 7 天', 'flame', '#FF9600', 7, 50, 'streak'),
    new Achievement('streak-30', 'streak', '月度坚持', '连续学习 30 天', 'flame', '#FF4B4B', 30, 100, 'streak'),
    new Achievement('streak-100', 'streak', '百日行者', '连续学习 100 天', 'flame', '#FFC800', 100, 100, 'streak'),
    new Achievement('perfect-1', 'perfection', '完美初体验', '首次三星通关一节课', 'star', '#FFC800', 1, 20, 'perfect'),
    new Achievement('perfect-10', 'perfection', '完美十连', '三星通关 10 节课', 'star', '#FFC800', 10, 50, 'perfect'),
    new Achievement('perfect-50', 'perfection', '无暇修行', '三星通关 50 节课', 'crown', '#A855F7', 50, 100, 'perfect'),
    new Achievement('first-cosmetic', 'shop', '时尚启航', '解锁第一件美妆道具', 'sparkles', '#A855F7', 1, 20, 'cosmetics'),
    new Achievement('gem-collector', 'shop', '宝石收藏家', '累计获得 500 颗宝石', 'gem', '#A855F7', 500, 50, 'gems'),
    new Achievement('first-review', 'review', '知错就改', '在错题本中复习一道题', 'medal', '#58CC02', 1, 20, 'reviews')
  ];

  static unlockedIds(s: AchievementSnapshot): string[] {
    return Achievements.all.filter((a: Achievement) => a.progress(s) >= a.goal).map((a: Achievement) => a.id);
  }

  static byId(id: string): Achievement | undefined {
    return Achievements.all.find((a: Achievement) => a.id === id);
  }

  static latchUnlocked(prevLedger: string[], currentUnlockedIds: string[]): string[] {
    const seen = new Set<string>(prevLedger);
    const merged = prevLedger.slice();
    for (const id of currentUnlockedIds) {
      if (!seen.has(id)) {
        seen.add(id);
        merged.push(id);
      }
    }
    return merged;
  }

  private static fam(id: string, name: string, ids: string[]): AchievementFamily {
    const tiers: Achievement[] = [];
    for (const m of ids) {
      const a = Achievements.byId(m);
      if (a !== undefined) {
        tiers.push(a);
      }
    }
    return new AchievementFamily(id, name, tiers);
  }

  static readonly families: AchievementFamily[] = [
    Achievements.fam('lessons', '学习里程', ['first-lesson', 'ten-lessons', 'fifty-lessons']),
    Achievements.fam('xp', '经验积累', ['xp-100', 'xp-1000', 'xp-5000']),
    Achievements.fam('streak', '连胜火焰', ['streak-3', 'streak-7', 'streak-30', 'streak-100']),
    Achievements.fam('perfect', '完美通关', ['perfect-1', 'perfect-10', 'perfect-50']),
    Achievements.fam('cosmetic', '时尚启航', ['first-cosmetic']),
    Achievements.fam('gems', '宝石收藏', ['gem-collector']),
    Achievements.fam('review', '知错就改', ['first-review'])
  ];
}

// ============================================================
// 美妆道具
// ============================================================

export type CosmeticType = 'mascot_skin' | 'ui_theme' | 'lesson_backdrop';
export type CosmeticRarity = 'common' | 'rare' | 'epic' | 'legendary';

export function rarityLabel(r: CosmeticRarity): string {
  switch (r) {
    case 'common':
      return '普通';
    case 'rare':
      return '稀有';
    case 'epic':
      return '史诗';
    default:
      return '传说';
  }
}

export function rarityColor(r: CosmeticRarity): string {
  switch (r) {
    case 'common':
      return '#9CA3AF';
    case 'rare':
      return '#1CB0F6';
    case 'epic':
      return '#A855F7';
    default:
      return '#FFC800';
  }
}

export class CosmeticItem {
  id: string;
  type: CosmeticType;
  name: string;
  description: string;
  cost: number;
  rarity: CosmeticRarity;
  starter: boolean;

  constructor(id: string, type: CosmeticType, name: string, description: string, cost: number,
    rarity: CosmeticRarity, starter: boolean = false) {
    this.id = id;
    this.type = type;
    this.name = name;
    this.description = description;
    this.cost = cost;
    this.rarity = rarity;
    this.starter = starter;
  }
}

export class UiThemeData {
  primary: string;
  primaryDark: string;
  accent: string;
  bg: string;
  isDark: boolean;

  constructor(primary: string, primaryDark: string, accent: string, bg: string, isDark: boolean) {
    this.primary = primary;
    this.primaryDark = primaryDark;
    this.accent = accent;
    this.bg = bg;
    this.isDark = isDark;
  }
}

export class LessonBackdropData {
  stops: string[];
  bg: string;
  needsOverlay: boolean;

  constructor(stops: string[], bg: string, needsOverlay: boolean) {
    this.stops = stops;
    this.bg = bg;
    this.needsOverlay = needsOverlay;
  }
}

export class ThemeEntry {
  item: CosmeticItem;
  data: UiThemeData;

  constructor(item: CosmeticItem, data: UiThemeData) {
    this.item = item;
    this.data = data;
  }
}

export class BackdropEntry {
  item: CosmeticItem;
  data: LessonBackdropData;

  constructor(item: CosmeticItem, data: LessonBackdropData) {
    this.item = item;
    this.data = data;
  }
}

const W = '#FFFFFF';

export class Cosmetics {
  static readonly mascotSkins: CosmeticItem[] = [
    new CosmeticItem('skin_default', 'mascot_skin', '原版聪聪', '最经典的熊猫聪聪', 0, 'common', true),
    new CosmeticItem('skin_graduate', 'mascot_skin', '学士帽', '戴上学士帽的聪聪，学者气质满分', 80, 'common'),
    new CosmeticItem('skin_glasses', 'mascot_skin', '圆框眼镜', '复古圆框眼镜，文艺青年聪聪', 100, 'common'),
    new CosmeticItem('skin_party', 'mascot_skin', '派对锥帽', '彩虹色派对帽，每天都是节日', 150, 'rare'),
    new CosmeticItem('skin_crown', 'mascot_skin', '金色皇冠', '学习路上的小国王/小女王', 250, 'rare'),
    new CosmeticItem('skin_wizard', 'mascot_skin', '法师尖帽', '知识就是魔法', 300, 'epic'),
    new CosmeticItem('skin_astronaut', 'mascot_skin', '宇航员头盔', '向知识的宇宙出发！', 500, 'legendary'),
    new CosmeticItem('skin_sunglasses', 'mascot_skin', '酷炫墨镜', 'Cool 到没朋友的墨镜聪聪', 120, 'common'),
    new CosmeticItem('skin_pirate', 'mascot_skin', '海盗船长', '扬帆出海寻知识宝藏', 220, 'rare'),
    new CosmeticItem('skin_headphones', 'mascot_skin', 'DJ 耳机', '戴上耳机就能听见学习节奏', 180, 'rare'),
    new CosmeticItem('skin_laurel', 'mascot_skin', '桂冠加身', '胜利者才能戴的金色桂冠', 280, 'epic'),
    new CosmeticItem('skin_bowtie', 'mascot_skin', '绅士领结', '戴上领结就是优雅的小学者', 60, 'common')
  ];

  static readonly uiThemes: ThemeEntry[] = [
    new ThemeEntry(new CosmeticItem('theme_default', 'ui_theme', 'Duolingo 绿', '经典清爽的草地绿', 0, 'common', true),
      new UiThemeData('#58CC02', '#58A700', '#1CB0F6', '#F7F7F7', false)),
    new ThemeEntry(new CosmeticItem('theme_ocean', 'ui_theme', '海洋蓝', '像在大海里学习', 200, 'common'),
      new UiThemeData('#1CB0F6', '#1899D6', '#58CC02', '#EFF8FE', false)),
    new ThemeEntry(new CosmeticItem('theme_sakura', 'ui_theme', '樱花粉', '粉嫩可爱的春天', 200, 'common'),
      new UiThemeData('#FF7AB6', '#E5588E', '#FFC800', '#FDF3F8', false)),
    new ThemeEntry(new CosmeticItem('theme_sunshine', 'ui_theme', '阳光黄', '充满活力的金色', 250, 'rare'),
      new UiThemeData('#FFB200', '#E59800', '#FF6B6B', '#FFF9E8', false)),
    new ThemeEntry(new CosmeticItem('theme_galaxy', 'ui_theme', '星空紫', '深邃神秘的宇宙紫', 400, 'epic'),
      new UiThemeData('#A855F7', '#7C3AED', '#FFC800', '#F5EEFF', false)),
    new ThemeEntry(new CosmeticItem('theme_mint', 'ui_theme', '薄荷青', '清新提神的薄荷青绿', 220, 'common'),
      new UiThemeData('#10B981', '#059669', '#FBBF24', '#ECFDF5', false)),
    new ThemeEntry(new CosmeticItem('theme_coral', 'ui_theme', '珊瑚红', '温暖热情的活力珊瑚', 300, 'rare'),
      new UiThemeData('#FF6B6B', '#E5484D', '#1CB0F6', '#FFF4F4', false)),
    new ThemeEntry(new CosmeticItem('theme_aurora', 'ui_theme', '极光', '梦幻的北极极光蓝绿', 500, 'legendary'),
      new UiThemeData('#22D3EE', '#0891B2', '#A855F7', '#ECFEFF', false)),
    new ThemeEntry(new CosmeticItem('theme_midnight', 'ui_theme', '暗夜模式', '护眼的深色界面，傍晚学习不刺眼', 350, 'epic'),
      new UiThemeData('#58CC02', '#3B9A00', '#1CB0F6', '#0F1419', true)),
    new ThemeEntry(new CosmeticItem('theme_obsidian', 'ui_theme', '曜石黑', '极简纯黑配霓虹蓝，潮酷十足', 480, 'legendary'),
      new UiThemeData('#1CB0F6', '#0E7FB8', '#A855F7', '#08090C', true))
  ];

  static readonly lessonBackdrops: BackdropEntry[] = [
    new BackdropEntry(new CosmeticItem('backdrop_default', 'lesson_backdrop', '干净简洁', '默认的纯净背景', 0, 'common', true),
      new LessonBackdropData([], '#F7F7F7', false)),
    new BackdropEntry(new CosmeticItem('backdrop_clouds', 'lesson_backdrop', '蓝天白云', '在云朵里学习', 120, 'common'),
      new LessonBackdropData(['#BFE3F7', '#E6F3FB', W], '#E6F3FB', false)),
    new BackdropEntry(new CosmeticItem('backdrop_forest', 'lesson_backdrop', '森林晨光', '清晨的森林透着阳光', 150, 'common'),
      new LessonBackdropData(['#D7F0CF', '#EDF8E5', W], '#EDF8E5', false)),
    new BackdropEntry(new CosmeticItem('backdrop_sunset', 'lesson_backdrop', '黄昏彩霞', '傍晚的天空是橘粉色', 200, 'rare'),
      new LessonBackdropData(['#FFD7B3', '#FFE9D6', W], '#FFE9D6', false)),
    new BackdropEntry(new CosmeticItem('backdrop_starfield', 'lesson_backdrop', '星空夜', '深邃的紫色星空', 350, 'epic'),
      new LessonBackdropData(['#2A1B5C', '#1A0F3D', '#0F0822'], '#1A0F3D', true)),
    new BackdropEntry(new CosmeticItem('backdrop_sakura', 'lesson_backdrop', '樱花飘落', '粉色花瓣的春日', 220, 'rare'),
      new LessonBackdropData(['#FFE0EC', '#FFF0F6', W], '#FFF0F6', false)),
    new BackdropEntry(new CosmeticItem('backdrop_ocean', 'lesson_backdrop', '深海漫游', '在海底世界学习', 280, 'rare'),
      new LessonBackdropData(['#93C5FD', '#BFDBFE', '#DBEAFE'], '#BFDBFE', false)),
    new BackdropEntry(new CosmeticItem('backdrop_aurora', 'lesson_backdrop', '极光夜', '极地夜空的彩色光带', 480, 'legendary'),
      new LessonBackdropData(['#064E3B', '#047857', '#0E7490', '#312E81'], '#0E7490', true))
  ];

  static readonly defaultSkin: string = 'skin_default';
  static readonly defaultTheme: string = 'theme_default';
  static readonly defaultBackdrop: string = 'backdrop_default';

  static all(): CosmeticItem[] {
    const out: CosmeticItem[] = Cosmetics.mascotSkins.slice();
    Cosmetics.uiThemes.forEach((t: ThemeEntry) => out.push(t.item));
    Cosmetics.lessonBackdrops.forEach((b: BackdropEntry) => out.push(b.item));
    return out;
  }

  static starterIds(): string[] {
    return Cosmetics.all().filter((c: CosmeticItem) => c.starter).map((c: CosmeticItem) => c.id);
  }

  static themeData(id: string): UiThemeData | undefined {
    return Cosmetics.uiThemes.find((t: ThemeEntry) => t.item.id === id)?.data;
  }

  static backdropData(id: string): LessonBackdropData | undefined {
    return Cosmetics.lessonBackdrops.find((b: BackdropEntry) => b.item.id === id)?.data;
  }
}

// ============================================================
// 宝箱
// ============================================================

export type ChestRewardTier = 'common' | 'rare' | 'epic';

export class ChestSlot {
  id: string;
  afterLessonId: string;
  unitNumber: number;
  unitTitle: string;
  indexInUnit: number;

  constructor(id: string, afterLessonId: string, unitNumber: number, unitTitle: string, indexInUnit: number) {
    this.id = id;
    this.afterLessonId = afterLessonId;
    this.unitNumber = unitNumber;
    this.unitTitle = unitTitle;
    this.indexInUnit = indexInUnit;
  }
}

export class ChestReward {
  gems: number;
  tier: ChestRewardTier;

  constructor(gems: number, tier: ChestRewardTier) {
    this.gems = gems;
    this.tier = tier;
  }
}

export class Chest {
  static readonly everyNLessons: number = 5;

  static slots(bookId: string, lessons: PathLessonMeta[], interval: number = Chest.everyNLessons): ChestSlot[] {
    const slots: ChestSlot[] = [];
    const unitCounts = new Map<number, number>();
    for (const l of lessons) {
      const count = (unitCounts.get(l.unitNumber) ?? 0) + 1;
      unitCounts.set(l.unitNumber, count);
      if (count % interval === 0) {
        const indexInUnit = count / interval - 1;
        slots.push(new ChestSlot(`${bookId}-u${l.unitNumber}-chest-${indexInUnit}`, l.id, l.unitNumber, l.unitTitle,
          indexInUnit));
      }
    }
    return slots;
  }

  static chestAfter(bookId: string, lessons: PathLessonMeta[], lessonId: string): ChestSlot | undefined {
    return Chest.slots(bookId, lessons).find((s: ChestSlot) => s.afterLessonId === lessonId);
  }

  static rollReward(): ChestReward {
    const roll = Math.random();
    if (roll < 0.85) {
      return new ChestReward(Math.round(10 + Math.random() * 10), 'common');
    }
    if (roll < 0.95) {
      return new ChestReward(Math.round(21 + Math.random() * 9), 'rare');
    }
    return new ChestReward(Math.round(40 + Math.random() * 10), 'epic');
  }
}

// ============================================================
// 学科配色
// ============================================================

export class SubjectConfig {
  id: SubjectId;
  label: string;
  accent: string;
  accentDark: string;

  constructor(id: SubjectId, label: string, accent: string, accentDark: string) {
    this.id = id;
    this.label = label;
    this.accent = accent;
    this.accentDark = accentDark;
  }
}

export function subjectConfig(id: SubjectId | null | undefined): SubjectConfig {
  switch (id) {
    case 'chinese':
      return new SubjectConfig('chinese', '语文', '#FF4B4B', '#E5484D');
    case 'english':
      return new SubjectConfig('english', '英语', '#1CB0F6', '#1899D6');
    case 'science':
      return new SubjectConfig('science', '科学', '#FFC800', '#E59800');
    default:
      return new SubjectConfig('math', '数学', '#58CC02', '#58A700');
  }
}

export function subjectOf(book: Book): SubjectConfig {
  return subjectConfig(book.subject);
}

// ============================================================
// 阅读 id 规范化（Reading.swift）
// ============================================================

export type ReadingKind = 'listen' | 'followup' | 'story';

export function readingId(kind: ReadingKind, rawId: string): string {
  return `reading:${kind}:${rawId}`;
}

function parseReadingId(id: string): boolean {
  const head = 'reading:';
  if (!id.startsWith(head)) {
    return false;
  }
  const rest = id.substring(head.length);
  const sep = rest.indexOf(':');
  if (sep <= 0 || sep >= rest.length - 1) {
    return false;
  }
  const kind = rest.substring(0, sep);
  return kind === 'listen' || kind === 'followup' || kind === 'story';
}

function looksLikeStoryId(id: string): boolean {
  const idx = id.lastIndexOf('-s');
  if (idx < 0) {
    return false;
  }
  const digits = id.substring(idx + 2);
  return digits.length > 0 && /^[0-9]+$/.test(digits);
}

export function normalizeReadingId(legacyId: string): string {
  const id = legacyId.trim();
  if (id.length === 0) {
    return '';
  }
  if (parseReadingId(id)) {
    return id;
  }
  if (id.startsWith('story-')) {
    const raw = id.substring('story-'.length);
    return raw.length === 0 ? '' : readingId('story', raw);
  }
  if (id.startsWith('passage-')) {
    let raw = id.substring('passage-'.length);
    let kind: ReadingKind = 'listen';
    if (raw.endsWith('-followup')) {
      raw = raw.substring(0, raw.length - '-followup'.length);
      kind = 'followup';
    } else if (raw.endsWith('-listen')) {
      raw = raw.substring(0, raw.length - '-listen'.length);
    }
    return raw.length === 0 ? '' : readingId(kind, raw);
  }
  if (id.endsWith('-followup')) {
    const raw = id.substring(0, id.length - '-followup'.length);
    return raw.length === 0 ? '' : readingId('followup', raw);
  }
  return readingId(looksLikeStoryId(id) ? 'story' : 'listen', id);
}

export function normalizeReadingIds(ids: string[]): string[] {
  const out = new Set<string>();
  for (const raw of ids) {
    const key = normalizeReadingId(raw);
    if (key.length > 0) {
      out.add(key);
    }
  }
  return Array.from(out).sort();
}

function earlierCompletion(a: string, b: string): string {
  if (a.length === 0) {
    return b;
  }
  if (b.length === 0) {
    return a;
  }
  const da = a.substring(0, 10);
  const db = b.substring(0, 10);
  if (da !== db) {
    return da < db ? a : b;
  }
  return a <= b ? a : b;
}

export function normalizeReadingMap(map: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const rawKey of Object.keys(map)) {
    const key = normalizeReadingId(rawKey);
    if (key.length === 0) {
      continue;
    }
    const value = map[rawKey];
    const prev = out[key];
    out[key] = prev !== undefined ? earlierCompletion(prev, value) : value;
  }
  return out;
}

// ============================================================
// 聪聪情绪触发器（MascotTriggers.swift）
// ============================================================

export class MascotTriggerContext {
  isCorrect: boolean = false;
  isPerfectSession: boolean = false;
  attemptCount: number = 1;
  remainingHearts: number = 5;
  combo: number = 0;
  maxCombo: number = 0;
  index: number = 0;
  total: number = 1;
}

export function decideMood(ctx: MascotTriggerContext): MascotMood {
  const isLast = ctx.index + 1 >= ctx.total;
  if (ctx.isCorrect) {
    if (isLast && ctx.isPerfectSession) {
      return 'proud';
    }
    if (ctx.remainingHearts === 1) {
      return 'happy';
    }
    if (ctx.combo >= 5) {
      return 'cheer';
    }
    if (ctx.combo === 1 && Math.random() < 0.1) {
      return 'surprise';
    }
    return 'happy';
  }
  if (ctx.remainingHearts <= 1) {
    return 'embarrassed';
  }
  if (ctx.attemptCount >= 2) {
    return 'sad';
  }
  return 'think';
}

export function decideReaction(ctx: MascotTriggerContext): MascotReaction {
  const isLast = ctx.index + 1 >= ctx.total;
  if (ctx.isCorrect) {
    if (isLast && ctx.isPerfectSession) {
      return 'levelup';
    }
    if (ctx.combo === 3 || ctx.combo === 5 || ctx.combo === 10) {
      return 'levelup';
    }
    return 'correct';
  }
  return 'wrong';
}

function bubbles(mood: MascotMood): string[] {
  switch (mood) {
    case 'happy':
      return ['太棒!', '答对啦!', '继续!', '漂亮!', '对的!'];
    case 'cheer':
      return ['完美!', '好厉害!', '太牛了!', '无敌!', '棒棒哒!'];
    case 'proud':
      return ['你太棒了!', '实力派!', '学霸预定!', '我为你骄傲!'];
    case 'sad':
      return ['别灰心!', '再来一次!', '差一点点!', '下次一定!'];
    case 'think':
      return ['想想看?', '再仔细一点!', '别急!', '慢慢来!'];
    case 'embarrassed':
      return ['小心呀!', '保住红心!', '稳住!', '深呼吸!'];
    case 'wave':
      return ['加油!', '我们一起!'];
    default:
      return ['哇!', '诶?', '厉害厉害!'];
  }
}

export function pickRandom(pool: string[]): string {
  return pool[Math.floor(Math.random() * pool.length)];
}

export function pickBubble(mood: MascotMood): string {
  return pickRandom(bubbles(mood));
}

export type BubbleTone = 'neutral' | 'primary' | 'danger';

export function bubbleTone(mood: MascotMood): BubbleTone {
  if (mood === 'cheer' || mood === 'proud' || mood === 'happy') {
    return 'primary';
  }
  if (mood === 'sad' || mood === 'embarrassed') {
    return 'danger';
  }
  return 'neutral';
}

// ============================================================
// 路径课程（PathLessons.swift）
// ============================================================

export function unitDisplayLabel(unit: Unit): string {
  return unit.label ?? `第 ${unit.unit_number} 单元`;
}

export function pathLessonMetas(outline: Outline, bookId: string,
  questionCount: (lessonId: string) => number = (_id: string) => 0): PathLessonMeta[] {
  const rows: PathLessonMeta[] = [];
  for (const unit of outline.units) {
    unit.knowledge_points.forEach((kp: KnowledgePoint, i: number) => {
      const lessonId = `${bookId}-u${unit.unit_number}-kp${i + 1}`;
      const meta: PathLessonMeta = {
        id: lessonId,
        title: kp.name,
        unitNumber: unit.unit_number,
        unitTitle: unit.title,
        kpIndex: i,
        kpTotal: unit.knowledge_points.length,
        questionCount: questionCount(lessonId),
        unitLabel: unit.label
      };
      rows.push(meta);
    });
  }
  return rows;
}

export function priorLessonMetas(outline: Outline, bookId: string, beforeUnit: number): PathLessonMeta[] {
  const index = outline.units.findIndex((u: Unit) => u.unit_number === beforeUnit);
  if (index < 0) {
    return [];
  }
  const prior = new Set<number>(outline.units.slice(0, index).map((u: Unit) => u.unit_number));
  return pathLessonMetas(outline, bookId).filter((m: PathLessonMeta) => prior.has(m.unitNumber));
}

export class ExamSlot {
  lessonId: string;
  title: string;
  unitNumber: number;
  unitTitle: string;
  questionCount: number;

  constructor(lessonId: string, title: string, unitNumber: number, unitTitle: string, questionCount: number) {
    this.lessonId = lessonId;
    this.title = title;
    this.unitNumber = unitNumber;
    this.unitTitle = unitTitle;
    this.questionCount = questionCount;
  }
}

/** "{bookId}-u{n}-..." → bookId */
export function bookIdFromLessonId(lessonId: string): string | null {
  const idx = lessonId.indexOf('-u');
  if (idx <= 0) {
    return null;
  }
  return lessonId.substring(0, idx);
}

export function isPinyinBook(bookId: string): boolean {
  return bookId === 'chinese-g1up' || bookId === 'chinese-g1down';
}
