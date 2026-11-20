// 音频：课文/题目朗读队列（AudioPlayer.swift）、合成音效（SFXEngine.swift）、跟读录音。
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { taskpool } from '@kit.ArkTS';
import { SettingsStore } from '../stores/SettingsStore';
import { AppEnv, Files } from './Files';
import { renderSfxWav } from './SfxSynth';

class QueueItem {
  path: string;
  index: number;

  constructor(path: string, index: number) {
    this.path = path;
    this.index = index;
  }
}

/** 单轨朗读队列：play(paths) 依次播放；再次调用会打断当前队列。 */
@ObservedV2
export class AudioPlayer {
  static readonly shared: AudioPlayer = new AudioPlayer();

  @Trace isPlaying: boolean = false;
  /** 当前播放项在 play(paths:) 入参数组里的下标（空位保留占位）。 */
  @Trace nowPlayingIndex: number = -1;
  /** 每次整队自然播完 +1（stop/打断不计）。 */
  @Trace queueCompletionCount: number = 0;
  /** 乌龟慢速开关。 */
  @Trace isSlowMode: boolean = false;
  @Trace currentRunId: number = 0;

  private queue: QueueItem[] = [];
  private player: media.AVPlayer | null = null;
  private file: fs.File | null = null;
  private token: number = 0;
  private playedCount: number = 0;
  private runSlow: boolean = false;

  play(paths: (string | null | undefined)[], slow?: boolean): void {
    if (SettingsStore.shared.isMuted) {
      this.stop();
      return;
    }
    const items: QueueItem[] = [];
    paths.forEach((p: string | null | undefined, i: number) => {
      if (p === null || p === undefined) {
        return;
      }
      const local = this.resolve(p);
      if (local !== null) {
        items.push(new QueueItem(local, i));
      }
    });
    this.stop();
    this.currentRunId++;
    this.queue = items;
    this.runSlow = slow ?? this.isSlowMode;
    this.playNext();
  }

  playOne(path: string | null | undefined, slow?: boolean): void {
    if (path === null || path === undefined) {
      return;
    }
    this.play([path], slow);
  }

  /** 播放一个本地绝对路径（跟读：回放自己的录音）。 */
  playFile(absPath: string): void {
    if (SettingsStore.shared.isMuted) {
      return;
    }
    this.stop();
    this.currentRunId++;
    this.queue = [new QueueItem(absPath, 0)];
    this.runSlow = false;
    this.playNext();
  }

  stop(): void {
    this.token++;
    this.releasePlayer();
    this.queue = [];
    this.playedCount = 0;
    this.isPlaying = false;
    this.nowPlayingIndex = -1;
  }

  /** "/audio/8e/8ec5...opus" → 本地 cstf/audio/8e/8ec5....{m4a|mp3}（不存在返回 null）。
   *  种子包用 iOS 的 .m4a；网页站点下载存 .mp3（.opus 的 mp3 兄弟）。 */
  resolve(path: string): string | null {
    const rel = AudioPlayer.rel(path);
    if (rel === null) {
      return null;
    }
    const stem = rel.replace(/\.(opus|mp3|m4a)$/i, '');
    const candidates: string[] = [`${stem}.m4a`, `${stem}.mp3`, rel];
    for (const c of candidates) {
      const abs = `${AppEnv.audioRoot()}/${c}`;
      if (Files.exists(abs)) {
        return abs;
      }
    }
    return null;
  }

  /** 网页音频路径 → 站点上要抓取的相对路径（.opus → .mp3 兄弟文件）。 */
  static webMp3Rel(path: string): string | null {
    const rel = AudioPlayer.rel(path);
    if (rel === null) {
      return null;
    }
    return rel.replace(/\.opus$/i, '.mp3');
  }

  /** 网页音频路径 → 下载落地到本地的绝对路径（与 webMp3Rel 一致，存 .mp3）。 */
  static localPathFor(path: string): string | null {
    const rel = AudioPlayer.webMp3Rel(path);
    return rel === null ? null : `${AppEnv.audioRoot()}/${rel}`;
  }

  /** "/audio/8e/xx.opus" / "audio/8e/xx.opus?x=1" → "8e/xx.opus"。 */
  private static rel(path: string): string | null {
    let rel = path.split('?')[0];
    if (rel.startsWith('/')) {
      rel = rel.substring(1);
    }
    if (rel.startsWith('audio/')) {
      rel = rel.substring('audio/'.length);
    }
    return rel.length > 0 ? rel : null;
  }

  hasAnyResolvable(paths: (string | null | undefined)[]): boolean {
    return paths.some((p: string | null | undefined) => p !== null && p !== undefined && this.resolve(p) !== null);
  }

  canPlay(path: string | null | undefined): boolean {
    return path !== null && path !== undefined && this.resolve(path) !== null;
  }

  private releasePlayer(): void {
    const p = this.player;
    this.player = null;
    if (p !== null) {
      p.release().catch(() => {
      });
    }
    if (this.file !== null) {
      try {
        fs.closeSync(this.file);
      } catch (e) {
        // ignore
      }
      this.file = null;
    }
  }

  private playNext(): void {
    this.releasePlayer();
    if (this.queue.length === 0) {
      const natural = this.playedCount > 0;
      this.playedCount = 0;
      this.isPlaying = false;
      this.nowPlayingIndex = -1;
      if (natural) {
        this.queueCompletionCount++;
      }
      return;
    }
    const next = this.queue.shift() as QueueItem;
    this.isPlaying = true;
    this.nowPlayingIndex = next.index;
    this.playedCount++;
    const gen = ++this.token;
    media.createAVPlayer().then((p: media.AVPlayer) => {
      if (gen !== this.token) {
        p.release();
        return;
      }
      this.player = p;
      p.on('stateChange', (state: string) => {
        if (gen !== this.token) {
          return;
        }
        if (state === 'initialized') {
          p.audioRendererInfo = {
            usage: audio.StreamUsage.STREAM_USAGE_AUDIOBOOK,
            rendererFlags: 0
          };
          p.prepare();
        } else if (state === 'prepared') {
          if (this.runSlow) {
            p.setSpeed(media.PlaybackSpeed.SPEED_FORWARD_0_75_X);
          }
          p.play();
        } else if (state === 'completed') {
          this.playNext();
        }
      });
      p.on('error', () => {
        if (gen === this.token) {
          this.playNext();
        }
      });
      p.on('audioInterrupt', (info: audio.InterruptEvent) => {
        if (gen === this.token && info.forceType === audio.InterruptForceType.INTERRUPT_FORCE &&
          info.hintType !== audio.InterruptHint.INTERRUPT_HINT_RESUME) {
          this.stop();
        }
      });
      try {
        this.file = fs.openSync(next.path, fs.OpenMode.READ_ONLY);
        p.fdSrc = { fd: this.file.fd };
      } catch (e) {
        this.playNext();
      }
    }).catch(() => {
      if (gen === this.token) {
        this.playNext();
      }
    });
  }
}

export type SfxName = 'correct' | 'wrong' | 'tap' | 'complete' | 'star' | 'heartLoss' | 'combo' | 'unlock' |
  'progressTick' | 'pairMatch' | 'purchase' | 'questClaim' | 'chestOpen';

@Concurrent
function synthesize(name: string, step: number): ArrayBuffer {
  return renderSfxWav(name, step);
}

/** 合成音效：启动时离线渲染为 WAV，交给 SoundPool 低延迟播放。 */
export class SFXEngine {
  static readonly shared: SFXEngine = new SFXEngine();

  private pool: media.SoundPool | null = null;
  private ids: Map<string, number> = new Map<string, number>();
  private pending: Set<string> = new Set<string>();

  async warmUp(): Promise<void> {
    try {
      this.pool = await media.createSoundPool(8, {
        usage: audio.StreamUsage.STREAM_USAGE_GAME,
        rendererFlags: 1
      });
    } catch (e) {
      console.warn(`[SFX] SoundPool unavailable ${JSON.stringify(e)}`);
      return;
    }
    const names: SfxName[] = ['tap', 'correct', 'wrong', 'heartLoss', 'progressTick', 'complete', 'star', 'combo',
      'unlock', 'pairMatch', 'purchase', 'questClaim', 'chestOpen'];
    for (const n of names) {
      await this.ensure(n, 0);
    }
    for (let s = 1; s <= 8; s++) {
      await this.ensure('correct', s);
    }
    for (let s = 1; s <= 3; s++) {
      await this.ensure('pairMatch', s);
    }
  }

  private async ensure(name: SfxName, step: number): Promise<number | undefined> {
    const key = `${name}-${step}`;
    const existing = this.ids.get(key);
    if (existing !== undefined || this.pool === null || this.pending.has(key)) {
      return existing;
    }
    this.pending.add(key);
    try {
      const path = `${AppEnv.cacheDir()}/sfx-v1-${key}.wav`;
      if (!Files.exists(path)) {
        const wav = await taskpool.execute(synthesize, name, step) as ArrayBuffer;
        Files.writeBytes(path, wav);
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const size = fs.statSync(path).size;
      const id = await this.pool.load(file.fd, 0, size);
      this.ids.set(key, id);
      return id;
    } catch (e) {
      console.warn(`[SFX] load ${key} failed ${JSON.stringify(e)}`);
      return undefined;
    } finally {
      this.pending.delete(key);
    }
  }

  play(name: SfxName, pitchStep: number = 0): void {
    if (SettingsStore.shared.isMuted || this.pool === null) {
      return;
    }
    const step = Math.max(0, Math.min(pitchStep, 8));
    const id = this.ids.get(`${name}-${step}`) ?? this.ids.get(`${name}-0`);
    if (id === undefined) {
      this.ensure(name, step);
      return;
    }
    try {
      this.pool.play(id, { loop: 0, rate: 0, leftVolume: 1, rightVolume: 1, priority: 0 }).catch(() => {
      });
    } catch (e) {
      // soundID 失效等同步异常不向上抛（否则会中断调用方的 onTap 流程）
    }
  }
}

/** 跟读录音：AAC/m4a，录完即用即删（只存在于 cacheDir）。 */
export class VoiceRecorder {
  private recorder: media.AVRecorder | null = null;
  private file: fs.File | null = null;

  static dir(): string {
    return `${AppEnv.cacheDir()}/cstf-followup`;
  }

  async start(index: number): Promise<string | null> {
    await this.stop();
    try {
      Files.mkdirs(VoiceRecorder.dir());
      const path = `${VoiceRecorder.dir()}/sentence-${index}.m4a`;
      Files.remove(path);
      this.file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const r = await media.createAVRecorder();
      const config: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: {
          audioBitrate: 48000,
          audioChannels: 1,
          audioCodec: media.CodecMimeType.AUDIO_AAC,
          audioSampleRate: 22050,
          fileFormat: media.ContainerFormatType.CFT_MPEG_4A
        },
        url: `fd://${this.file.fd}`
      };
      await r.prepare(config);
      await r.start();
      this.recorder = r;
      return path;
    } catch (e) {
      console.warn(`[VoiceRecorder] start failed ${JSON.stringify(e)}`);
      await this.stop();
      return null;
    }
  }

  async stop(): Promise<void> {
    const r = this.recorder;
    this.recorder = null;
    if (r !== null) {
      try {
        await r.stop();
      } catch (e) {
        // ignore
      }
      try {
        await r.release();
      } catch (e) {
        // ignore
      }
    }
    if (this.file !== null) {
      try {
        fs.closeSync(this.file);
      } catch (e) {
        // ignore
      }
      this.file = null;
    }
  }
}
