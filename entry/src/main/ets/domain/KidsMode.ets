// 儿童模式规则（鸿蒙端独有，参考 DayDayUp/docs/DESIGN.md §2/§5.2/§5.4/§8）：
// 错误不惩罚只延迟奖励（封存宝箱 + 心魔试炼）、题位编排（神速 / 踮脚）、知识卡与单元守护兽。
// 这里只放纯规则，不依赖 UI / 存储。
import { DemonState, Question } from '../models/Types';
import { Economy } from './Economy';

export class Remedy {
  /** 收服一只心魔需要再答对的同类题数（初始）。 */
  static readonly initialVariants: number = 2;
  /** 每答错一次 +1，上限（防挫败）。 */
  static readonly maxVariants: number = 5;
  /** 连续答错几次弹出「请教时刻」。 */
  static readonly askHelpAfter: number = 3;
  /** 封存宝箱保留天数。 */
  static readonly expiryDays: number = 3;
  /** 每收服一只心魔的额外宝石。 */
  static readonly bonusGemsPerDemon: number = 2;

  static newDemon(questionId: number): DemonState {
    const d: DemonState = {
      questionId: questionId, need: Remedy.initialVariants, variantsDone: 0, corrected: false, wrongStreak: 0
    };
    return d;
  }

  static isSubdued(d: DemonState): boolean {
    return d.corrected && d.variantsDone >= d.need;
  }

  /** 作答后的新状态（不修改入参）。 */
  static afterAnswer(d: DemonState, correct: boolean): DemonState {
    const n: DemonState = {
      questionId: d.questionId, need: d.need, variantsDone: d.variantsDone, corrected: d.corrected,
      wrongStreak: d.wrongStreak
    };
    if (correct) {
      n.wrongStreak = 0;
      if (!n.corrected) {
        n.corrected = true;
      } else {
        n.variantsDone++;
      }
    } else {
      n.wrongStreak++;
      n.need = Math.min(Remedy.maxVariants, n.need + 1);
    }
    return n;
  }

  /** 变种题池：同知识点的其它题；没有就用本课其它题。 */
  static variantPool(questions: Question[], original: Question): Question[] {
    const others = questions.filter((q: Question) => q.id !== original.id);
    const same = others.filter((q: Question) => q.knowledge_point === original.knowledge_point);
    return same.length > 0 ? same : others;
  }
}

/** 一课里的特殊题位：神速题（限时加倍）+ 踮脚题（更难，答错不封宝箱）。 */
export class LessonSlots {
  static readonly speedSeconds: number = 15;
  /** 至少这么多题才编排特殊题位。 */
  static readonly minQuestions: number = 4;

  speedId: number = -1;
  stretchId: number = -1;

  static none(): LessonSlots {
    return new LessonSlots();
  }

  /** 踮脚 = 难度最高的题（须比最低难度高）；神速 = 剩下的选择 / 判断题里最简单的一道。 */
  static pick(questions: Question[]): LessonSlots {
    const s = new LessonSlots();
    if (questions.length < LessonSlots.minQuestions) {
      return s;
    }
    let minD = Number.MAX_VALUE;
    let maxD = -Number.MAX_VALUE;
    questions.forEach((q: Question) => {
      minD = Math.min(minD, q.difficulty);
      maxD = Math.max(maxD, q.difficulty);
    });
    if (maxD > minD) {
      for (let i = questions.length - 1; i >= 0; i--) {
        if (questions[i].difficulty === maxD) {
          s.stretchId = questions[i].id;
          break;
        }
      }
    }
    let bestDiff = Number.MAX_VALUE;
    for (const q of questions) {
      if (q.id === s.stretchId || (q.type !== 'choice' && q.type !== 'true_false')) {
        continue;
      }
      if (q.difficulty < bestDiff) {
        bestDiff = q.difficulty;
        s.speedId = q.id;
      }
    }
    return s;
  }

  /** 题序：基础 … 神速（居中）… 踮脚（倒数第二）→ 以一道基础题收尾。 */
  arrange(questions: Question[]): Question[] {
    const base = questions.filter((q: Question) => q.id !== this.speedId && q.id !== this.stretchId);
    const speed = questions.find((q: Question) => q.id === this.speedId);
    const stretch = questions.find((q: Question) => q.id === this.stretchId);
    const out = base.slice();
    if (speed !== undefined) {
      out.splice(Math.max(0, Math.floor(questions.length / 2) - 1), 0, speed);
    }
    if (stretch !== undefined) {
      out.splice(Math.max(0, out.length - 1), 0, stretch);
    }
    return out;
  }

  /** 神速题限时答对的额外 XP（= 该题再算一遍，即 ×2）。 */
  static speedBonusXp(isWeekend: boolean, isExam: boolean): number {
    return Economy.xpPerCorrect * (isWeekend ? Economy.weekendXpMultiplier : 1) *
      (isExam ? Economy.examXpMultiplier : 1);
  }
}

// ============================================================
// 知识卡 & 单元守护兽
// ============================================================

export class CardTier {
  static label(tier: number): string {
    return tier >= 3 ? '金卡' : (tier === 2 ? '银卡' : '铜卡');
  }

  static color(tier: number): string {
    return tier >= 3 ? '#E5A50A' : (tier === 2 ? '#8A9BB0' : '#C27C4E');
  }

  /** 卡面浅底色。 */
  static tint(tier: number): string {
    return tier >= 3 ? '#FFF4D1' : (tier === 2 ? '#EEF2F7' : '#F8E9DD');
  }
}

export class Guardian {
  name: string;
  glyph: string;
  desc: string;
  color: string;

  constructor(name: string, glyph: string, desc: string, color: string) {
    this.name = name;
    this.glyph = glyph;
    this.desc = desc;
    this.color = color;
  }
}

/** 《山海经》等典籍里的灵兽，儿童化一句话介绍。 */
const GUARDIANS: Guardian[] = [
  new Guardian('白泽', '泽', '什么都知道的神兽，能说出天下所有妖怪的名字。', '#3FA796'),
  new Guardian('麒麟', '麟', '走路不踩小虫子的仁兽，出现就代表好事要来。', '#D9A441'),
  new Guardian('凤凰', '凤', '百鸟之王，羽毛有五种颜色，唱歌特别好听。', '#D9573A'),
  new Guardian('青龙', '龙', '守护东方的神龙，管着春天和万物生长。', '#2E9C6A'),
  new Guardian('白虎', '虎', '守护西方的神兽，勇敢又威风。', '#8A9BB0'),
  new Guardian('朱雀', '雀', '守护南方的火红神鸟，像一团温暖的火焰。', '#E0644B'),
  new Guardian('玄武', '武', '守护北方的龟蛇神兽，非常有耐心。', '#2E3F55'),
  new Guardian('精卫', '卫', '每天衔石子填大海的小鸟，从不放弃。', '#5563D6'),
  new Guardian('九尾狐', '狐', '长着九条尾巴的灵狐，聪明又机灵。', '#E58A3A'),
  new Guardian('陆吾', '吾', '虎身九尾、守护昆仑山的山神。', '#B3743A'),
  new Guardian('英招', '招', '马身人面、背上有翅膀，在天上巡逻。', '#7D8CE0'),
  new Guardian('毕方', '毕', '只有一条腿的火鸟，叫声像自己的名字。', '#D94F3A'),
  new Guardian('重明鸟', '明', '每只眼睛里有两个瞳孔，能赶走坏东西。', '#E5A50A'),
  new Guardian('青鸟', '青', '替西王母送信的小鸟，从不迷路。', '#3E8FD9'),
  new Guardian('旋龟', '龟', '鸟头蛇尾的乌龟，叫声像劈木头。', '#4F8A6E'),
  new Guardian('文鳐鱼', '鳐', '会在夜里飞出水面的鱼，见到它就会丰收。', '#4AA8C9'),
  new Guardian('当康', '康', '长着獠牙的小猪，一叫就预示大丰收。', '#C48A5A'),
  new Guardian('乘黄', '乘', '背上长角的狐狸，骑上它能长寿。', '#D2A24C'),
  new Guardian('貔貅', '貅', '只进不出的瑞兽，特别会守护宝贝。', '#A77BCA'),
  new Guardian('獬豸', '豸', '头上一只角，能分辨谁对谁错。', '#5F6B7A'),
  new Guardian('夔', '夔', '只有一条腿的神兽，吼声像打雷。', '#6B5FA8'),
  new Guardian('鸾鸟', '鸾', '和凤凰一样美丽的神鸟，出现就天下太平。', '#E87AA0'),
  new Guardian('应龙', '应', '长着翅膀的龙，会呼风唤雨。', '#3C9D9B'),
  new Guardian('开明兽', '开', '九个脑袋的神兽，守着昆仑山的大门。', '#8C6D3F')
];

function strHash(s: string): number {
  let h = 5381;
  for (let i = 0; i < s.length; i++) {
    h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
  }
  return h;
}

export class Guardians {
  static readonly all: Guardian[] = GUARDIANS;

  /** 每本书的单元按顺序对应不同灵兽（同一本书内不重复，直到用完一轮）。 */
  static forUnit(bookId: string, unitNumber: number): Guardian {
    const n = GUARDIANS.length;
    const idx = (strHash(bookId) + Math.max(0, unitNumber - 1)) % n;
    return GUARDIANS[idx];
  }
}
