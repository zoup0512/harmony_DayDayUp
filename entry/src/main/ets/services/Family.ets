// 一个家长、多个孩子：切换 / 删除 / 全家备份 / 指定档案导入 / 家长总览数据。
// 当前孩子始终走 ProgressStore.shared，其他孩子用 ProgressStore.forLearner 的独立实例读写各自目录。
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BackupEnvelope, FamilyBackupEnvelope, makeFamilyEnvelope } from '../domain/Backup';
import { DEFAULT_LEARNER_ID, LearnerProfile, LearnerStore } from '../stores/LearnerStore';
import { ProgressStore } from '../stores/ProgressStore';
import { Router } from '../features/Router';
import { AudioPlayer } from './Audio';
import { AppEnv } from './Files';

export const NEW_TARGET: string = '+new';
export const SKIP_TARGET: string = '+skip';

export class ImportResult {
  created: number = 0;
  count: number = 0;
  touchedActive: boolean = false;
}

export class LearnerSummary {
  profile: LearnerProfile;
  active: boolean = false;
  grade: number = 0;
  todayXp: number = 0;
  dailyGoal: number = 0;
  streak: number = 0;
  weekXp: number = 0;
  lessons: number = 0;
  perfect: number = 0;
  mistakesDue: number = 0;
  demons: number = 0;
  cards: number = 0;
  lastActiveDate: string = '';

  constructor(profile: LearnerProfile) {
    this.profile = profile;
  }
}

export class Family {
  /** 选定孩子：同一个孩子只关闭选择层并补跑启动刷新；不同孩子整体重载进度。 */
  static pick(id: string): void {
    const learners = LearnerStore.shared;
    if (id === learners.activeId) {
      learners.closePicker();
      ProgressStore.shared.refreshForNow();
      return;
    }
    Family.switchTo(id);
  }

  static switchTo(id: string): void {
    try {
      AudioPlayer.shared.stop();
    } catch (e) {
      // 音频未初始化
    }
    Router.shared.clear();
    ProgressStore.shared.switchTo(id);
  }

  /** 删除孩子；删的是当前孩子时切回默认孩子。 */
  static remove(id: string): void {
    if (LearnerStore.shared.remove(id)) {
      Family.switchTo(DEFAULT_LEARNER_ID);
    }
  }

  static exportLearner(id: string): BackupEnvelope {
    return ProgressStore.forLearner(id).exportBackupEnvelope();
  }

  static exportFamily(): FamilyBackupEnvelope {
    return makeFamilyEnvelope(LearnerStore.shared.list.map((p: LearnerProfile) => Family.exportLearner(p.id)));
  }

  /**
   * 默认导入方案：同 id 的本机孩子 → 覆盖它；没写归属的单人存档 → 覆盖当前孩子（与旧版一致）；
   * 其余新建。两份存档默认绝不写进同一个孩子。
   */
  static defaultTargets(entries: BackupEnvelope[], family: boolean): string[] {
    const learners = LearnerStore.shared;
    const used = new Set<string>();
    return entries.map((env: BackupEnvelope) => {
      const owner = env.learner;
      let target = NEW_TARGET;
      if (owner !== undefined && owner !== null) {
        if (learners.find(owner.id) !== null) {
          target = owner.id;
        }
      } else if (!family) {
        target = learners.activeId;
      }
      if (target === NEW_TARGET || used.has(target)) {
        return NEW_TARGET;
      }
      used.add(target);
      return target;
    });
  }

  static importInto(entries: BackupEnvelope[], targets: string[]): ImportResult {
    const learners = LearnerStore.shared;
    const result = new ImportResult();
    const written = new Set<string>();
    entries.forEach((env: BackupEnvelope, i: number) => {
      let id = targets[i] ?? SKIP_TARGET;
      if (id === SKIP_TARGET || written.has(id)) {
        return;
      }
      if (id === NEW_TARGET) {
        const owner = env.learner;
        const name = owner !== undefined && owner !== null ? owner.name : `导入的孩子 ${i + 1}`;
        id = learners.create(name, owner?.color ?? null).id;
        result.created++;
      } else if (learners.find(id) === null) {
        return;
      }
      ProgressStore.forLearner(id).importBackup(env);
      written.add(id);
    });
    result.count = written.size;
    result.touchedActive = written.has(learners.activeId);
    return result;
  }

  static summarize(profile: LearnerProfile): LearnerSummary {
    const store = ProgressStore.forLearner(profile.id);
    const s = new LearnerSummary(profile);
    s.active = profile.id === LearnerStore.shared.activeId;
    s.grade = store.selectedGrade;
    s.todayXp = store.todayXp;
    s.dailyGoal = store.dailyGoal;
    s.streak = store.displayStreak;
    s.weekXp = store.weeklyTotal(0);
    s.lessons = store.totalCompletedLessons;
    s.perfect = store.perfectedLessonCount;
    s.mistakesDue = store.dueMistakes.length;
    s.demons = store.pendingDemonCount;
    s.cards = store.knowledgeCardCount;
    s.lastActiveDate = store.progress.lastActiveDate;
    return s;
  }

  static setDailyGoal(id: string, goal: number): void {
    ProgressStore.forLearner(id).setDailyGoal(goal);
  }

  /** 系统「保存到」选择器写出 JSON；resolve(true) 表示真的写进了文件。 */
  static saveJson(json: string, filename: string): Promise<boolean> {
    const saveOpts = new picker.DocumentSaveOptions();
    saveOpts.newFileNames = [filename];
    const docPicker = new picker.DocumentViewPicker(AppEnv.ctx());
    return docPicker.save(saveOpts).then((uris: Array<string>) => {
      if (uris.length === 0) {
        return false;
      }
      const file = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        fs.writeSync(file.fd, json);
      } finally {
        fs.closeSync(file);
      }
      return true;
    }).catch((err: BusinessError) => {
      console.error(`[Family] save failed ${err.message ?? err.code}`);
      return false;
    });
  }

  static fileStamp(now: Date = new Date()): string {
    const m = now.getMonth() + 1;
    const d = now.getDate();
    return `${now.getFullYear()}-${m < 10 ? '0' : ''}${m}-${d < 10 ? '0' : ''}${d}`;
  }

  static fileSafe(name: string): string {
    return name.replace(new RegExp('[\\\\/:*?"<>|\\s]+', 'g'), '-');
  }
}
