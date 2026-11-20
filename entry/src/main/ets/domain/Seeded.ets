// 跨端确定性随机：rng / quests / league / jump（与 Swift UInt64 环绕运算逐位一致，
// 与 core rng.ts / quests.ts / league.ts / jump.ts 同一份黄金向量）。
import { Question } from '../models/Types';
import { dayIndexInWeek, weekStartKey } from './Dates';

export const U64_MASK: bigint = (1n << 64n) - 1n;

export function mix64(value: bigint): bigint {
  let x = (value + 0x9e3779b97f4a7c15n) & U64_MASK;
  x = ((x ^ (x >> 30n)) * 0xbf58476d1ce4e5b9n) & U64_MASK;
  x = ((x ^ (x >> 27n)) * 0x94d049bb133111ebn) & U64_MASK;
  return x ^ (x >> 31n);
}

export function utf8Bytes(s: string): number[] {
  const bytes: number[] = [];
  for (const ch of Array.from(s)) {
    const code = ch.codePointAt(0) ?? 0;
    if (code < 0x80) {
      bytes.push(code);
    } else if (code < 0x800) {
      bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
    } else if (code < 0x10000) {
      bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    } else {
      bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
    }
  }
  return bytes;
}

export function djb2Hash(s: string): bigint {
  let hash = 5381n;
  for (const byte of utf8Bytes(s)) {
    hash = (hash * 33n + BigInt(byte)) & U64_MASK;
  }
  return hash;
}

// ============================================================
// 每日任务
// ============================================================

export type QuestKind = 'earnXP' | 'finishLessons' | 'reviewMistakes' | 'readTexts';

export class Quest {
  kind: QuestKind;
  target: number;
  reward: number;

  constructor(kind: QuestKind, target: number, reward: number) {
    this.kind = kind;
    this.target = target;
    this.reward = reward;
  }

  get id(): string {
    return `${this.kind}-${this.target}`;
  }

  get title(): string {
    switch (this.kind) {
      case 'earnXP':
        return `获得 ${this.target} 点经验`;
      case 'finishLessons':
        return `完成 ${this.target} 节小课`;
      case 'reviewMistakes':
        return `复习 ${this.target} 道错题`;
      default:
        return `读完 ${this.target} 篇课文或故事`;
    }
  }

  get icon(): string {
    switch (this.kind) {
      case 'earnXP':
        return 'bolt';
      case 'finishLessons':
        return 'seal';
      case 'reviewMistakes':
        return 'cycle';
      default:
        return 'book';
    }
  }
}

const QUEST_POOL: Quest[] = [
  new Quest('earnXP', 30, 10), new Quest('earnXP', 60, 15), new Quest('earnXP', 100, 25),
  new Quest('finishLessons', 1, 10), new Quest('finishLessons', 2, 20), new Quest('finishLessons', 3, 30),
  new Quest('reviewMistakes', 1, 10), new Quest('reviewMistakes', 3, 20),
  new Quest('readTexts', 1, 15), new Quest('readTexts', 2, 25)
];

export function dailyQuests(dateString: string): Quest[] {
  const hash = mix64(djb2Hash(dateString));
  const index = (count: number, salt: bigint): number => {
    if (count <= 0) {
      return 0;
    }
    return Number(mix64((hash + salt) & U64_MASK) % BigInt(count));
  };
  const pick = (kind: QuestKind, salt: bigint): Quest => {
    const options = QUEST_POOL.filter((q: Quest) => q.kind === kind);
    return options[index(options.length, salt)];
  };
  const rest: QuestKind[] = ['finishLessons', 'reviewMistakes', 'readTexts'];
  const firstKind = rest.splice(index(rest.length, 0x11n), 1)[0];
  const secondKind = rest[index(rest.length, 0x22n)];
  return [pick('earnXP', 0x01n), pick(firstKind, 0x33n), pick(secondKind, 0x44n)];
}

// ============================================================
// 本地模拟联赛
// ============================================================

export type LeagueTierId = 'bronze' | 'silver' | 'gold' | 'sapphire' | 'ruby' | 'diamond';

export class LeagueTier {
  id: LeagueTierId;
  name: string;
  order: number;
  color: string;

  constructor(id: LeagueTierId, name: string, order: number, color: string) {
    this.id = id;
    this.name = name;
    this.order = order;
    this.color = color;
  }
}

export class LeagueBot {
  id: string;
  name: string;

  constructor(id: string, name: string) {
    this.id = id;
    this.name = name;
  }
}

export class StandingEntry {
  isUser: boolean;
  botIndex: number;
  xp: number;
  rank: number = 0;

  constructor(isUser: boolean, botIndex: number, xp: number) {
    this.isUser = isUser;
    this.botIndex = botIndex;
    this.xp = xp;
  }
}

export class SettleResult {
  promoted: boolean;
  demoted: boolean;
  gems: number;

  constructor(promoted: boolean, demoted: boolean, gems: number) {
    this.promoted = promoted;
    this.demoted = demoted;
    this.gems = gems;
  }
}

const BOT_NAME_POOL: string[] = [
  '小猴淘淘', '兔子朵朵', '熊猫团团', '小鹿灵灵', '狐狸悠悠', '小象壮壮',
  '企鹅冰冰', '小猫咪咪', '小狗旺旺', '松鼠果果', '小鸟啾啾', '海豚蓝蓝',
  '小马奔奔', '刺猬球球', '考拉抱抱', '小龙腾腾', '河马呼呼', '小羊咩咩',
  '青蛙呱呱', '蜜蜂嗡嗡', '猫头鹰慧慧', '小熊憨憨', '仓鼠豆豆', '鹦鹉花花',
  '小鲸鱼泡泡', '蜗牛慢慢', '小老虎威威', '浣熊乐乐', '长颈鹿高高', '小恐龙吼吼',
  '雪人白白', '星星闪闪', '月亮弯弯', '太阳暖暖', '彩虹七七', '云朵飘飘'
];

export class League {
  static readonly tiers: LeagueTier[] = [
    new LeagueTier('bronze', '青铜联赛', 0, '#CD7F32'),
    new LeagueTier('silver', '白银联赛', 1, '#A8B8C8'),
    new LeagueTier('gold', '黄金联赛', 2, '#FFC800'),
    new LeagueTier('sapphire', '蓝宝石联赛', 3, '#1CB0F6'),
    new LeagueTier('ruby', '红宝石联赛', 4, '#E0115F'),
    new LeagueTier('diamond', '钻石联赛', 5, '#54D7EC')
  ];
  static readonly unlockLessons: number = 10;
  static readonly groupSize: number = 16;
  static readonly botCount: number = 15;
  static readonly promoteZone: number = 5;
  static readonly demoteZone: number = 5;
  static readonly promotionBonusGems: number = 20;

  static tier(id: string): LeagueTier {
    return League.tiers.find((t: LeagueTier) => t.id === id) ?? League.tiers[0];
  }

  static nextTierId(id: LeagueTierId): LeagueTierId {
    const t = League.tier(id);
    return League.tiers[Math.min(t.order + 1, League.tiers.length - 1)].id;
  }

  static prevTierId(id: LeagueTierId): LeagueTierId {
    const t = League.tier(id);
    return League.tiers[Math.max(t.order - 1, 0)].id;
  }

  static weekKeyFor(date: Date = new Date()): string {
    return weekStartKey(date);
  }

  private static seed(weekKey: string, tier: LeagueTierId, salt: string): bigint {
    return mix64(djb2Hash(`${weekKey}#${tier}#${salt}`));
  }

  private static draw(seed: bigint, offset: number, count: number): number {
    if (count <= 0) {
      return 0;
    }
    return Number(mix64((seed + BigInt(offset)) & U64_MASK) % BigInt(count));
  }

  static xpRange(tier: LeagueTierId): number[] {
    switch (tier) {
      case 'bronze':
        return [40, 260];
      case 'silver':
        return [80, 420];
      case 'gold':
        return [120, 600];
      case 'sapphire':
        return [160, 800];
      case 'ruby':
        return [200, 1000];
      default:
        return [240, 1200];
    }
  }

  static botsForWeek(weekKey: string, tier: LeagueTierId, salt: string): LeagueBot[] {
    const s = League.seed(weekKey, tier, salt);
    const pool = BOT_NAME_POOL.slice();
    const bots: LeagueBot[] = [];
    for (let i = 0; i < League.botCount; i++) {
      const idx = League.draw(s, 0x1000 + i, pool.length);
      const name = pool.splice(idx, 1)[0];
      bots.push(new LeagueBot(`bot-${weekKey}-${tier}-${i}`, name));
    }
    return bots;
  }

  static botWeeklyGoal(weekKey: string, tier: LeagueTierId, salt: string, botIndex: number): number {
    const s = League.seed(weekKey, tier, salt);
    const range = League.xpRange(tier);
    return range[0] + League.draw(s, 0x2000 + botIndex, range[1] - range[0] + 1);
  }

  static botXpAt(weekKey: string, tier: LeagueTierId, salt: string, botIndex: number, date: Date): number {
    const s = League.seed(weekKey, tier, salt);
    const goal = League.botWeeklyGoal(weekKey, tier, salt, botIndex);
    const weights: number[] = [];
    for (let d = 0; d < 7; d++) {
      weights.push(1 + League.draw(s, 0x3000 + botIndex * 0x10 + d, 9));
    }
    const totalWeight = weights.reduce((a: number, b: number) => a + b, 0);
    const cum = (d: number): number => {
      let w = 0;
      for (let i = 0; i <= d; i++) {
        w += weights[i];
      }
      return Math.floor((goal * w) / totalWeight);
    };
    const dayIndex = dayIndexInWeek(weekKey, date);
    if (dayIndex < 0) {
      return 0;
    }
    if (dayIndex > 6) {
      return goal;
    }
    const prevCum = dayIndex === 0 ? 0 : cum(dayIndex - 1);
    const todayShare = cum(dayIndex) - prevCum;
    const startHour = 6 + League.draw(s, 0x4000 + botIndex, 5);
    const endHour = 18 + League.draw(s, 0x5000 + botIndex, 6);
    const clamped = Math.min(Math.max(date.getHours() - startHour, 0), endHour - startHour);
    return prevCum + Math.floor((todayShare * clamped) / (endHour - startHour));
  }

  static standings(userXp: number, botXps: number[]): StandingEntry[] {
    const rows: StandingEntry[] = [new StandingEntry(true, -1, userXp)];
    botXps.forEach((xp: number, i: number) => {
      rows.push(new StandingEntry(false, i, xp));
    });
    rows.sort((a: StandingEntry, b: StandingEntry) => {
      if (a.xp !== b.xp) {
        return b.xp - a.xp;
      }
      if (a.isUser !== b.isUser) {
        return a.isUser ? -1 : 1;
      }
      return a.botIndex - b.botIndex;
    });
    rows.forEach((r: StandingEntry, i: number) => {
      r.rank = i + 1;
    });
    return rows;
  }

  static userRank(userXp: number, botXps: number[]): number {
    return League.standings(userXp, botXps).find((r: StandingEntry) => r.isUser)?.rank ?? League.groupSize;
  }

  static rankGems(rank: number): number {
    switch (rank) {
      case 1:
        return 100;
      case 2:
        return 80;
      case 3:
        return 60;
      case 4:
      case 5:
        return 40;
      default:
        return 0;
    }
  }

  static settleRank(rank: number, tierId: LeagueTierId): SettleResult {
    const promoted = rank <= League.promoteZone && tierId !== 'diamond';
    const demoted = rank >= League.groupSize - League.demoteZone + 1 && tierId !== 'bronze';
    return new SettleResult(promoted, demoted, League.rankGems(rank) + (promoted ? League.promotionBonusGems : 0));
  }
}

// ============================================================
// 跳级测试抽题
// ============================================================

export class JumpQuestionSource {
  lessonId: string;
  questions: Question[];

  constructor(lessonId: string, questions: Question[]) {
    this.lessonId = lessonId;
    this.questions = questions;
  }
}

export class JumpSampledQuestion {
  lessonId: string;
  question: Question;

  constructor(lessonId: string, question: Question) {
    this.lessonId = lessonId;
    this.question = question;
  }
}

class SeedRng {
  private state: bigint;

  constructor(seedStr: string) {
    this.state = djb2Hash(seedStr);
  }

  next(): number {
    this.state = (this.state + 1n) & U64_MASK;
    return Number(mix64(this.state) >> 11n) / 9007199254740992;
  }
}

function shuffleInPlace<T>(arr: T[], rng: SeedRng): void {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.min(Math.floor(rng.next() * (i + 1)), i);
    const t = arr[i];
    arr[i] = arr[j];
    arr[j] = t;
  }
}

export class Jump {
  static readonly testSize: number = 15;
  static readonly passAccuracy: number = 0.8;

  static sampleQuestions(sources: JumpQuestionSource[], size: number = Jump.testSize,
    seed: string = 'jump'): JumpSampledQuestion[] {
    if (size <= 0) {
      return [];
    }
    const groups: JumpSampledQuestion[][] = [];
    for (const src of sources) {
      const seen = new Set<number>();
      const group: JumpSampledQuestion[] = [];
      for (const q of src.questions) {
        if (!seen.has(q.id)) {
          seen.add(q.id);
          group.push(new JumpSampledQuestion(src.lessonId, q));
        }
      }
      if (group.length === 0) {
        continue;
      }
      shuffleInPlace(group, new SeedRng(`${seed}#${src.lessonId}`));
      groups.push(group);
    }
    const total = groups.reduce((n: number, g: JumpSampledQuestion[]) => n + g.length, 0);
    const targetSize = Math.min(size, total);
    if (targetSize <= 0) {
      return [];
    }
    shuffleInPlace(groups, new SeedRng(`${seed}#groups`));
    const picked: JumpSampledQuestion[] = [];
    let round = 0;
    while (picked.length < targetSize) {
      let tookAny = false;
      for (const group of groups) {
        if (picked.length >= targetSize) {
          break;
        }
        if (round < group.length) {
          picked.push(group[round]);
          tookAny = true;
        }
      }
      if (!tookAny) {
        break;
      }
      round++;
    }
    shuffleInPlace(picked, new SeedRng(`${seed}#order`));
    return picked;
  }
}
