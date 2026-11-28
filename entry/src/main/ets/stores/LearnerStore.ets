// 多孩子学习档案注册表（与 Web 版 learnerProfiles 同一套概念）。
// filesDir/cstf/learners.json 记录孩子列表与当前孩子；默认孩子沿用老路径 cstf/progress.json、
// cstf/prefs.json（老用户零迁移），其他孩子各自一个目录 cstf/learners/<id>/。
import { AppEnv, Files } from '../services/Files';

export const DEFAULT_LEARNER_ID: string = 'default';
export const LEARNER_COLORS: string[] = ['green', 'sky', 'orange', 'pink', 'purple', 'teal'];
export const LEARNER_NAME_MAX: number = 20;
const ID_RE: RegExp = new RegExp('^[a-zA-Z0-9-]{1,64}$');

export interface LearnerProfile {
  id: string;
  name: string;
  color?: string | null;
}

interface LearnersFile {
  version: number;
  activeId: string;
  learners: LearnerProfile[];
}

interface NameOnly {
  displayName?: string | null;
}

export function learnerColorHex(color: string | null | undefined): string {
  switch (color) {
    case 'sky':
      return '#1CB0F6';
    case 'orange':
      return '#FF9600';
    case 'pink':
      return '#FF86D0';
    case 'purple':
      return '#CE82FF';
    case 'teal':
      return '#2BC4B4';
    default:
      return '#58CC02';
  }
}

export function learnerColorLabel(color: string): string {
  switch (color) {
    case 'sky':
      return '蓝色';
    case 'orange':
      return '橙色';
    case 'pink':
      return '粉色';
    case 'purple':
      return '紫色';
    case 'teal':
      return '青色';
    default:
      return '绿色';
  }
}

/** 名字首字（头像用）。 */
export function learnerInitial(name: string): string {
  const chars = Array.from(name.trim());
  return chars.length > 0 ? chars[0] : '?';
}

export class LearnerStore {
  static readonly shared: LearnerStore = new LearnerStore();

  private data: LearnersFile = {
    version: 1, activeId: DEFAULT_LEARNER_ID, learners: [{ id: DEFAULT_LEARNER_ID, name: '小学员' }]
  };
  private loaded: boolean = false;
  private listeners: Array<() => void> = [];

  /** 「谁在学习？」选择层：冷启动且不止一个孩子时自动弹出（auto），也可手动打开。 */
  pickerOpen: boolean = false;
  pickerAuto: boolean = false;

  private get filePath(): string {
    return `${AppEnv.cstfRoot()}/learners.json`;
  }

  onChange(cb: () => void): () => void {
    this.listeners.push(cb);
    return () => {
      this.listeners = this.listeners.filter((x: () => void) => x !== cb);
    };
  }

  emit(): void {
    this.listeners.forEach((cb: () => void) => cb());
  }

  load(): void {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    const raw = Files.readText(this.filePath);
    if (raw !== null) {
      try {
        const parsed = JSON.parse(raw) as LearnersFile;
        const seen = new Set<string>();
        const learners = (Array.isArray(parsed.learners) ? parsed.learners : []).filter((p: LearnerProfile) => {
          const ok = p !== null && typeof p.id === 'string' && ID_RE.test(p.id) && typeof p.name === 'string' &&
            p.name.trim().length > 0 && !seen.has(p.id);
          if (ok) {
            seen.add(p.id);
          }
          return ok;
        });
        if (!learners.some((p: LearnerProfile) => p.id === DEFAULT_LEARNER_ID)) {
          learners.unshift({ id: DEFAULT_LEARNER_ID, name: this.legacyName() });
        }
        const active = typeof parsed.activeId === 'string' && learners.some((p: LearnerProfile) => p.id === parsed.activeId) ?
          parsed.activeId : DEFAULT_LEARNER_ID;
        this.data = { version: 1, activeId: active, learners: learners };
      } catch (e) {
        this.data.learners[0].name = this.legacyName();
      }
    } else {
      // 老用户首次升级：默认档案沿用原昵称，不写文件（等第一次真正修改时再落盘）。
      this.data.learners[0].name = this.legacyName();
    }
    if (this.data.learners.length > 1) {
      this.pickerOpen = true;
      this.pickerAuto = true;
    }
  }

  private legacyName(): string {
    const raw = Files.readText(`${AppEnv.cstfRoot()}/progress.json`);
    if (raw !== null) {
      try {
        const name = (JSON.parse(raw) as NameOnly).displayName;
        if (typeof name === 'string' && name.trim().length > 0) {
          return name.trim().substring(0, LEARNER_NAME_MAX);
        }
      } catch (e) {
        // 坏档按默认名处理
      }
    }
    return '小学员';
  }

  private persist(): void {
    try {
      Files.writeTextAtomic(this.filePath, JSON.stringify(this.data));
    } catch (e) {
      console.error('[LearnerStore] save failed');
    }
    this.emit();
  }

  get activeId(): string {
    return this.data.activeId;
  }

  get list(): LearnerProfile[] {
    return this.data.learners.slice();
  }

  get count(): number {
    return this.data.learners.length;
  }

  get active(): LearnerProfile {
    return this.find(this.data.activeId) ?? this.data.learners[0];
  }

  find(id: string): LearnerProfile | null {
    return this.data.learners.find((p: LearnerProfile) => p.id === id) ?? null;
  }

  dirOf(id: string): string {
    return id === DEFAULT_LEARNER_ID ? AppEnv.cstfRoot() : `${AppEnv.cstfRoot()}/learners/${id}`;
  }

  progressPath(id: string): string {
    return `${this.dirOf(id)}/progress.json`;
  }

  prefsPath(id: string): string {
    return `${this.dirOf(id)}/prefs.json`;
  }

  /** 返回错误文案；null 表示合法。 */
  static nameError(name: string): string | null {
    const v = name.trim();
    return v.length === 0 || v.length > LEARNER_NAME_MAX ? `请输入 1–${LEARNER_NAME_MAX} 个字的名字` : null;
  }

  create(name: string, color: string | null = null): LearnerProfile {
    const id = Files.uuid().toLowerCase();
    const profile: LearnerProfile = {
      id: id, name: name.trim().substring(0, LEARNER_NAME_MAX),
      color: color !== null && LEARNER_COLORS.includes(color) ? color :
        LEARNER_COLORS[this.data.learners.length % LEARNER_COLORS.length]
    };
    this.data.learners.push(profile);
    this.persist();
    return profile;
  }

  rename(id: string, name: string): void {
    const p = this.find(id);
    if (p === null || LearnerStore.nameError(name) !== null) {
      return;
    }
    p.name = name.trim();
    this.persist();
  }

  setColor(id: string, color: string): void {
    const p = this.find(id);
    if (p === null || !LEARNER_COLORS.includes(color)) {
      return;
    }
    p.color = color;
    this.persist();
  }

  move(id: string, delta: number): void {
    const list = this.data.learners;
    const from = list.findIndex((p: LearnerProfile) => p.id === id);
    const to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) {
      return;
    }
    const tmp = list[from];
    list[from] = list[to];
    list[to] = tmp;
    this.persist();
  }

  /** 删除非默认孩子及其整个数据目录；删的是当前孩子时回到默认孩子（调用方负责重载进度）。 */
  remove(id: string): boolean {
    if (id === DEFAULT_LEARNER_ID || this.find(id) === null) {
      return false;
    }
    this.data.learners = this.data.learners.filter((p: LearnerProfile) => p.id !== id);
    const wasActive = this.data.activeId === id;
    if (wasActive) {
      this.data.activeId = DEFAULT_LEARNER_ID;
    }
    Files.remove(this.dirOf(id));
    this.persist();
    return wasActive;
  }

  setActive(id: string): void {
    if (this.find(id) === null) {
      return;
    }
    this.data.activeId = id;
    this.pickerOpen = false;
    this.pickerAuto = false;
    this.persist();
  }

  openPicker(): void {
    this.pickerOpen = this.count > 1;
    this.pickerAuto = false;
    this.emit();
  }

  closePicker(): void {
    this.pickerOpen = false;
    this.pickerAuto = false;
    this.emit();
  }
}
