// 按书下载课本数据 + 音频（AssetDownloader 的网页版后端）。
// 网页端站点直接暴露与 public/data 相同的文件树：
//   {site}/data/index.json
//   {site}/data/books/<bookId>/{outline,passages,stories}.json
//   {site}/data/books/<bookId>/lessons/<lessonId>.json
//   {site}/audio/<bucket>/<hash>.mp3（.opus 的 mp3 兄弟文件，见 web src/lib/tts.ts）
// 音频落地到 cstf/audio/<bucket>/<hash>.mp3，由 AudioPlayer.resolve 统一解析。
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { AppEnv, Files } from './Files';
import { DataLoader } from './DataLoader';
import { AudioPlayer } from './Audio';
import { Book, Lesson, Outline, Passage, PassageSentence, Question, Story } from '../models/Types';
import { KnowledgePoint, Unit } from '../models/Types';

/** 一本书的下载计划（原 ManifestEntry 的站点版）。 */
export class BookPlan {
  bookId: string;
  lessonsCount: number;

  constructor(bookId: string, lessonsCount: number) {
    this.bookId = bookId;
    this.lessonsCount = lessonsCount;
  }
}

const SAFE_COMPONENT = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

@ObservedV2
export class AssetDownloader {
  static readonly shared: AssetDownloader = new AssetDownloader();

  /** 资源站点根地址（与网页端同一棵 data 树）；换部署时只改这里。 */
  siteBaseURL: string = 'https://www.52razor.site:8443';

  @Trace bookProgress: Map<string, number> = new Map<string, number>();
  @Trace inFlight: Set<string> = new Set<string>();
  @Trace lastError: string | null = null;
  /** 站点索引最近一次成功拉取时间戳（ms）；0 = 还没拉过。 */
  @Trace indexFetchedAt: number = 0;
  /** 任何一次下载完成都 +1，供页面刷新「已下载」状态。 */
  @Trace revision: number = 0;

  private audioReadyCache: Map<string, boolean> = new Map<string, boolean>();

  /** 这本书的下载计划。lessonCount 取自站点索引（本地 index.json 兜底）。 */
  entry(bookId: string): BookPlan {
    const books = allIndexBooks();
    const meta = books.find((b) => b.id === bookId);
    return new BookPlan(bookId, meta !== undefined ? meta.lessonsCount : 0);
  }

  // ---------------- 站点索引刷新 ----------------

  /** 拉取 {site}/data/index.json 覆盖本地 data/index.json（DataLoader 的站点索引来源）。 */
  async refreshSiteIndex(): Promise<void> {
    const text = await this.fetchText(`${this.siteBaseURL}/data/index.json`);
    Files.mkdirs(AppEnv.dataRoot());
    Files.writeTextAtomic(`${AppEnv.dataRoot()}/index.json`, text);
    DataLoader.clearCache();
    this.indexFetchedAt = Date.now();
  }

  /** 有网时后台静默刷新站点索引；失败忽略（继续用种子）。 */
  refreshSiteIndexInBackground(): void {
    this.refreshSiteIndex().catch(() => {
    });
  }

  // ---------------- 下载状态 ----------------

  isBookDownloaded(bookId: string): boolean {
    return this.hasBookData(bookId) && this.hasBookAudio(bookId);
  }

  hasBookData(bookId: string): boolean {
    return Files.exists(`${DataLoader.bookDir(bookId)}/outline.json`);
  }

  hasBookAudio(bookId: string): boolean {
    const cached = this.audioReadyCache.get(bookId);
    if (cached !== undefined) {
      return cached;
    }
    const ok = Files.exists(this.audioMarkerPath(bookId)) || this.probeBookAudio(bookId);
    this.audioReadyCache.set(bookId, ok);
    return ok;
  }

  private audioMarkerPath(bookId: string): string {
    return `${AppEnv.audioRoot()}/.downloaded/${bookId}`;
  }

  private probeBookAudio(bookId: string): boolean {
    const refs: string[] = [];
    const limit = 8;
    const collect = (p: string | null | undefined): void => {
      if (refs.length < limit && p !== null && p !== undefined && p.length > 0) {
        refs.push(p);
      }
    };
    DataLoader.loadPassages(bookId)?.passages.forEach((p: Passage) => {
      p.sentences.forEach((s: PassageSentence): void => {
        collect(s.audio);
      });
    });
    if (refs.length < limit) {
      DataLoader.loadStories(bookId)?.stories.forEach((s: Story) => {
        s.sentences.forEach((x: PassageSentence): void => {
          collect(x.audio);
        });
      });
    }
    if (refs.length < limit) {
      const first = DataLoader.firstLessonId(bookId);
      const lesson: Lesson | null = first !== null ? DataLoader.tryLesson(bookId, first) : null;
      lesson?.questions.forEach((q: Question) => {
        collect(q.audio?.question);
        collect(q.audio?.explanation);
      });
    }
    if (refs.length === 0) {
      return true;
    }
    return refs.every((r: string) => AudioPlayer.shared.resolve(r) !== null);
  }

  // ---------------- 主流程 ----------------

  /** 下载一本书的全部数据 + 音频；幂等（在飞中重入直接返回）。 */
  async ensureBookDownloaded(bookId: string): Promise<void> {
    if (this.inFlight.has(bookId)) {
      return;
    }
    // @Trace 只代理字段引用——Map/Set 内部变更不触发刷新，必须整体重赋。
    this.inFlight = new Set(this.inFlight).add(bookId);
    this.bookProgress = new Map(this.bookProgress).set(bookId, 0);
    this.lastError = null;
    this.audioReadyCache.clear();
    try {
      const base = `${this.siteBaseURL}/data/books/${bookId}`;
      const dir = DataLoader.bookDir(bookId);
      Files.mkdirs(`${dir}/lessons`);

      // 1. outline（必须）。先只解析不落盘——outline.json 是「已安装」标志，课程全部到位后才写。
      const outlineText = await this.fetchText(`${base}/outline.json`);
      const outline = JSON.parse(outlineText) as Outline;
      this.setProgress(bookId, 0.02);

      // 2. 课文/故事/手册（可选）：只有站点明确 404 才删本地旧文件；网络抖动保留已有内容并中止。
      const extras = ['passages.json', 'stories.json', 'guides.json'];
      for (let n = 0; n < extras.length; n++) {
        const name = extras[n];
        try {
          const text = await this.fetchText(`${base}/${name}`);
          Files.writeTextAtomic(`${dir}/${name}`, text);
        } catch (e) {
          if ((e as Error).message !== 'HTTP 404') {
            throw e as Error;
          }
          Files.remove(`${dir}/${name}`);
        }
        this.setProgress(bookId, 0.02 + (n + 1) * 0.01);
      }

      // 3. 逐课下载 lesson JSON（进度 0.05 → 0.35）
      const lessonIds = lessonIdsOf(outline, bookId);
      const audioRefs = new Set<string>();
      for (let i = 0; i < lessonIds.length; i++) {
        const id = lessonIds[i];
        const text = await this.fetchText(`${base}/lessons/${id}.json`);
        Files.writeTextAtomic(`${dir}/lessons/${id}.json`, text);
        collectAudioFromLesson(JSON.parse(text) as Lesson, audioRefs);
        this.setProgress(bookId, 0.05 + (i + 1) / Math.max(1, lessonIds.length) * 0.30);
      }
      Files.writeTextAtomic(`${dir}/outline.json`, outlineText);
      DataLoader.clearCache();

      // 4. 课文/故事里的音频引用
      collectAudioFromFile(`${dir}/passages.json`, audioRefs);
      collectAudioFromFile(`${dir}/stories.json`, audioRefs);

      // 5. 音频（进度 0.35 → 1）：4 路并发；单条失败不阻塞整本书（TTS 按钮会自动隐藏）。
      const refs = Array.from(audioRefs);
      const pending = refs.filter((ref: string) => {
        const local = AudioPlayer.localPathFor(ref);
        return local !== null && !Files.exists(local) && this.audioURL(ref) !== null;
      });
      let finished = refs.length - pending.length;
      let cursor = 0;
      const worker = async (): Promise<void> => {
        while (cursor < pending.length) {
          const ref = pending[cursor++];
          const local = AudioPlayer.localPathFor(ref) as string;
          try {
            const bytes = await this.fetchBytes(this.audioURL(ref) as string);
            Files.mkdirs(local.substring(0, local.lastIndexOf('/')));
            Files.writeBytes(local, bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
          } catch (e) {
            // 跳过，下次下载会补
          }
          finished++;
          this.setProgress(bookId, 0.35 + finished / Math.max(1, refs.length) * 0.65);
        }
      };
      const workers: Promise<void>[] = [];
      for (let w = 0; w < 4; w++) {
        workers.push(worker());
      }
      await Promise.all(workers);

      Files.writeTextAtomic(this.audioMarkerPath(bookId), `${refs.length}`);
      this.audioReadyCache.clear();
      DataLoader.clearCache();
      this.bookProgress = new Map(this.bookProgress).set(bookId, 1);
      this.revision++;
    } catch (e) {
      this.audioReadyCache.clear();
      const msg = (e as Error).message ?? JSON.stringify(e);
      this.lastError = '下载失败，请检查网络后重试';
      throw new Error(msg);
    } finally {
      const rest = new Set(this.inFlight);
      rest.delete(bookId);
      this.inFlight = rest;
    }
  }

  /** @Trace 只代理字段引用——Map 内部 set 不触发刷新，整体重赋。 */
  private setProgress(bookId: string, value: number): void {
    this.bookProgress = new Map(this.bookProgress).set(bookId, value);
  }

  /** 网页路径 → 站点下载 URL。`.opus` 源取其 `.mp3` 兄弟（Harmony AVPlayer 直接可播）。 */
  audioURL(path: string): string | null {
    const rel = AudioPlayer.webMp3Rel(path);
    if (rel === null || rel.split('/').some((c: string) => !SAFE_COMPONENT.test(c))) {
      return null;
    }
    return `${this.siteBaseURL}/audio/${rel}`;
  }

  // ---------------- HTTP 基础 ----------------

  private async fetchText(url: string): Promise<string> {
    const bytes = await this.fetchBytes(url);
    return Files.decodeUtf8(bytes);
  }

  private fetchBytes(url: string): Promise<Uint8Array> {
    return new Promise<Uint8Array>((resolve: (v: Uint8Array) => void, reject: (e: Error) => void) => {
      const client = http.createHttp();
      client.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000,
        usingCache: false
      }, (err: BusinessErrorLike | undefined, data: http.HttpResponse | undefined) => {
        client.destroy();
        if (err !== undefined || data === undefined) {
          reject(new Error(`网络错误 ${JSON.stringify(err)}`));
          return;
        }
        const code = data.responseCode;
        if (code !== 200) {
          reject(new Error(`HTTP ${code}`));
          return;
        }
        const body = data.result;
        if (body instanceof ArrayBuffer) {
          resolve(new Uint8Array(body));
        } else if (typeof body === 'string') {
          resolve(util.TextEncoder.create('utf-8').encodeInto(body));
        } else {
          reject(new Error('响应格式不支持'));
        }
      });
    });
  }
}

interface BusinessErrorLike {
  code: number;
  message: string;
}

function allIndexBooks(): Book[] {
  try {
    return DataLoader.loadSiteIndex().books;
  } catch (e) {
    return [];
  }
}

function lessonIdsOf(outline: Outline, bookId: string): string[] {
  const ids: string[] = [];
  outline.units.forEach((u: Unit) => {
    u.knowledge_points.forEach((_kp: KnowledgePoint, i: number) => {
      ids.push(`${bookId}-u${u.unit_number}-kp${i + 1}`);
    });
    if (u.examLessonId !== undefined && u.examLessonId !== null) {
      ids.push(u.examLessonId);
    }
  });
  return ids;
}

function collectAudioFromLesson(l: Lesson, out: Set<string>): void {
  l.questions.forEach((q: Question) => {
    const a = q.audio;
    if (a !== undefined && a !== null) {
      const qPath = a.question;
      const ePath = a.explanation;
      if (qPath !== null && qPath !== undefined) {
        out.add(qPath);
      }
      if (ePath !== null && ePath !== undefined) {
        out.add(ePath);
      }
      (a.options ?? []).forEach((p: string | null | undefined) => {
        if (p !== null && p !== undefined) {
          out.add(p);
        }
      });
    }
  });
  const k = l.knowledge?.audio;
  if (k !== undefined && k !== null) {
    [k.point, k.core_concept, k.key_formula, k.tips].forEach((p: string | null | undefined) => {
      if (p !== null && p !== undefined) {
        out.add(p);
      }
    });
    (k.common_mistakes ?? []).forEach((p: string | null | undefined) => {
      if (p !== null && p !== undefined) {
        out.add(p);
      }
    });
  }
}

interface AudioFileShape {
  passages?: Passage[];
  stories?: Story[];
}

function collectAudioFromFile(path: string, out: Set<string>): void {
  const text = Files.readText(path);
  if (text === null) {
    return;
  }
  try {
    const j = JSON.parse(text) as AudioFileShape;
    (j.passages ?? []).forEach((p: Passage) => {
      p.sentences.forEach((s: PassageSentence) => {
        if (s.audio !== null && s.audio !== undefined) {
          out.add(s.audio);
        }
      });
    });
    (j.stories ?? []).forEach((s: Story) => {
      s.sentences.forEach((x: PassageSentence) => {
        if (x.audio !== null && x.audio !== undefined) {
          out.add(x.audio);
        }
      });
    });
  } catch (e) {
    // 文件不是 JSON 或结构不符 —— 跳过
  }
}
