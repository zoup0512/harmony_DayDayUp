// 读取与 apps/web/public/data/ 同构的数据目录：
//   filesDir/cstf/data/index.json
//   filesDir/cstf/data/books/<bookId>/{outline,passages,stories}.json
//   filesDir/cstf/data/books/<bookId>/lessons/<lessonId>.json
// 内置 seed（rawfile/seed-data.zip）首启解压到同一棵树，离线也能体验第一本书。
import { BookPassages, BookStories, Lesson, Outline, SiteIndex, Unit } from '../models/Types';
import { ExamSlot } from '../domain/Catalog';
import { AppEnv, Files } from './Files';
import { zlib } from '@kit.BasicServicesKit';

export class DataLoader {
  private static outlineCache: Map<string, Outline> = new Map<string, Outline>();
  private static lessonCache: Map<string, Lesson> = new Map<string, Lesson>();

  static clearCache(): void {
    DataLoader.outlineCache.clear();
    DataLoader.lessonCache.clear();
  }

  static bookDir(bookId: string): string {
    return `${AppEnv.dataRoot()}/books/${bookId}`;
  }

  static loadSiteIndex(): SiteIndex {
    const local = Files.readText(`${AppEnv.dataRoot()}/index.json`);
    if (local !== null) {
      try {
        return JSON.parse(local) as SiteIndex;
      } catch (e) {
        // 回落到内置索引
      }
    }
    return DataLoader.loadSeedIndex();
  }

  static loadSeedIndex(): SiteIndex {
    const bytes = AppEnv.ctx().resourceManager.getRawFileContentSync('seed-index.json');
    return JSON.parse(Files.decodeUtf8(bytes)) as SiteIndex;
  }

  /** 这本书还没下载时抛出「教材 xx 尚未下载」。 */
  static loadOutline(bookId: string): Outline {
    const cached = DataLoader.outlineCache.get(bookId);
    if (cached !== undefined) {
      return cached;
    }
    const text = Files.readText(`${DataLoader.bookDir(bookId)}/outline.json`);
    if (text === null) {
      throw new Error(`教材 ${bookId} 尚未下载`);
    }
    const o = JSON.parse(text) as Outline;
    DataLoader.outlineCache.set(bookId, o);
    return o;
  }

  static tryOutline(bookId: string): Outline | null {
    try {
      return DataLoader.loadOutline(bookId);
    } catch (e) {
      return null;
    }
  }

  static lessonPath(bookId: string, lessonId: string): string {
    return `${DataLoader.bookDir(bookId)}/lessons/${lessonId}.json`;
  }

  static loadLesson(bookId: string, lessonId: string): Lesson {
    const key = `${bookId}/${lessonId}`;
    const cached = DataLoader.lessonCache.get(key);
    if (cached !== undefined) {
      return cached;
    }
    const text = Files.readText(DataLoader.lessonPath(bookId, lessonId));
    if (text === null) {
      throw new Error(`课程 ${lessonId} 不存在`);
    }
    const l = JSON.parse(text) as Lesson;
    DataLoader.lessonCache.set(key, l);
    return l;
  }

  static tryLesson(bookId: string, lessonId: string): Lesson | null {
    try {
      return DataLoader.loadLesson(bookId, lessonId);
    } catch (e) {
      return null;
    }
  }

  static lessonExists(bookId: string, lessonId: string): boolean {
    return Files.exists(DataLoader.lessonPath(bookId, lessonId));
  }

  static loadPassages(bookId: string): BookPassages | null {
    const text = Files.readText(`${DataLoader.bookDir(bookId)}/passages.json`);
    if (text === null) {
      return null;
    }
    try {
      return JSON.parse(text) as BookPassages;
    } catch (e) {
      return null;
    }
  }

  static loadStories(bookId: string): BookStories | null {
    const text = Files.readText(`${DataLoader.bookDir(bookId)}/stories.json`);
    if (text === null) {
      return null;
    }
    try {
      return JSON.parse(text) as BookStories;
    } catch (e) {
      return null;
    }
  }

  static questionCount(bookId: string, lessonId: string): number {
    return DataLoader.tryLesson(bookId, lessonId)?.questions.length ?? 0;
  }

  /** 单元挑战节点：outline 声明了 examLessonId 且本地课程文件存在。 */
  static examSlots(outline: Outline, bookId: string): ExamSlot[] {
    const slots: ExamSlot[] = [];
    outline.units.forEach((unit: Unit) => {
      const examId = unit.examLessonId;
      if (examId === undefined || examId === null) {
        return;
      }
      const lesson = DataLoader.tryLesson(bookId, examId);
      if (lesson === null) {
        return;
      }
      slots.push(new ExamSlot(examId, lesson.title, unit.unit_number, unit.title, lesson.questions.length));
    });
    return slots;
  }

  /** 故事插图本地路径；缺失返回 null（调用方降级为色块）。 */
  static storyImagePath(bookId: string, storyId: string, imagePath: string | null | undefined): string | null {
    const root = AppEnv.dataRoot();
    const candidates: string[] = [];
    if (imagePath !== null && imagePath !== undefined && imagePath.length > 0) {
      candidates.push(`${root}/${imagePath.startsWith('/') ? imagePath.substring(1) : imagePath}`);
    }
    candidates.push(`${root}/story-images/${bookId}/${storyId}.jpg`);
    return candidates.find((p: string) => Files.exists(p)) ?? null;
  }

  /** 某书 lessons 目录里任一含拼音字母音频引用（新版拼音资源）。 */
  static hasPinyinReferences(bookId: string): boolean {
    const dir = `${DataLoader.bookDir(bookId)}/lessons`;
    return Files.listNames(dir).filter((n: string) => n.endsWith('.json')).some((n: string) => {
      const t = Files.readText(`${dir}/${n}`);
      return t !== null && t.includes('.pinyin-');
    });
  }

  static firstLessonId(bookId: string): string | null {
    const names = Files.listNames(`${DataLoader.bookDir(bookId)}/lessons`).filter((n: string) => n.endsWith('.json')).sort();
    return names.length > 0 ? names[0].substring(0, names[0].length - 5) : null;
  }
}

/**
 * 首启（及应用升级）时把内置 seed-data.zip 解压进沙箱。
 * 只补缺失文件：已下载的教材、音频与学习记录在升级时原样保留。
 */
export class SeedInstaller {
  static async installIfNeeded(): Promise<void> {
    try {
      const bytes = AppEnv.ctx().resourceManager.getRawFileContentSync('seed-data.zip');
      const version = Files.sha256OfBytes(bytes);
      const root = AppEnv.cstfRoot();
      Files.mkdirs(root);
      const stampPath = `${root}/seed-version.txt`;
      if ((Files.readText(stampPath) ?? '').trim() === version) {
        return;
      }
      const zipPath = `${AppEnv.cacheDir()}/seed-data.zip`;
      Files.writeBytes(zipPath, bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
      const stage = `${root}/.seed-install-${Files.uuid()}`;
      Files.mkdirs(stage);
      try {
        await zlib.decompressFile(zipPath, stage);
        for (const rel of Files.listFilesRecursive(stage)) {
          const dest = `${root}/${rel}`;
          if (Files.exists(dest)) {
            continue;
          }
          Files.move(`${stage}/${rel}`, dest);
        }
        Files.writeTextAtomic(stampPath, version);
      } finally {
        Files.remove(stage);
        Files.remove(zipPath);
      }
    } catch (e) {
      console.error(`[SeedInstaller] unzip failed: ${JSON.stringify(e)}`);
    }
  }
}
