// 蛇形学习路径（PathMapView.swift）：单元横幅、课程节点、宝箱、单元挑战、开始弹窗、吸顶单元条、「回到当前」。
import { curves } from '@kit.ArkUI';
import { C, F, R, W, alpha, unitColors } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { Chest, ChestSlot, ExamSlot } from '../domain/Catalog';
import { LessonStatus, PathLessonMeta } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { DuoIcon } from './Kit';
import { Mascot } from './Mascot';

export type NodeKindTag = 'lesson' | 'chest' | 'exam';

export class PathMapNode {
  id: string;
  title: string;
  unitNumber: number;
  unitTitle: string;
  status: LessonStatus;
  stars: number;
  lessonNumber: number = 0;
  kind: NodeKindTag = 'lesson';
  chestClaimed: boolean = false;
  conquered: boolean = false;
  questionCount: number = 0;
  unitLabel: string | null = null;

  constructor(id: string, title: string, unitNumber: number, unitTitle: string, status: LessonStatus, stars: number) {
    this.id = id;
    this.title = title;
    this.unitNumber = unitNumber;
    this.unitTitle = unitTitle;
    this.status = status;
    this.stars = stars;
  }

  get displayLabel(): string {
    return this.unitLabel ?? `第 ${this.unitNumber} 单元`;
  }
}

/** 由课程元数据 + 进度构建路径节点（PathNodeBuilder）。 */
export function buildPathNodes(bookId: string, lessons: PathLessonMeta[], store: ProgressStore,
  examSlots: ExamSlot[]): PathMapNode[] {
  let foundCurrent = false;
  const chestByAfter = new Map<string, ChestSlot>();
  Chest.slots(bookId, lessons).forEach((s: ChestSlot) => chestByAfter.set(s.afterLessonId, s));
  const examByUnit = new Map<number, ExamSlot>();
  examSlots.forEach((e: ExamSlot) => examByUnit.set(e.unitNumber, e));
  const nodes: PathMapNode[] = [];
  let lessonNumber = 0;
  lessons.forEach((row: PathLessonMeta, i: number) => {
    const stars = store.stars(row.id);
    const completed = stars > 0;
    let status: LessonStatus = 'locked';
    if (completed) {
      status = 'completed';
    } else if (!foundCurrent) {
      status = 'current';
      foundCurrent = true;
    }
    const n = new PathMapNode(row.id, row.title, row.unitNumber, row.unitTitle, status, stars);
    lessonNumber = i > 0 && lessons[i - 1].unitNumber === row.unitNumber ? lessonNumber + 1 : 1;
    n.lessonNumber = lessonNumber;
    n.questionCount = row.questionCount;
    n.unitLabel = row.unitLabel ?? null;
    nodes.push(n);
    const slot = chestByAfter.get(row.id);
    if (slot !== undefined) {
      const c = new PathMapNode(slot.id, '宝箱', slot.unitNumber, slot.unitTitle, completed ? 'completed' : 'locked', 0);
      c.kind = 'chest';
      c.chestClaimed = store.isChestClaimed(slot.id);
      c.unitLabel = row.unitLabel ?? null;
      nodes.push(c);
    }
    const lastOfUnit = i + 1 >= lessons.length || lessons[i + 1].unitNumber !== row.unitNumber;
    const exam = examByUnit.get(row.unitNumber);
    if (lastOfUnit && exam !== undefined) {
      const unitDone = lessons.filter((l: PathLessonMeta) => l.unitNumber === row.unitNumber)
        .every((l: PathLessonMeta) => store.isLessonCompleted(l.id));
      const result = store.progress.completedLessons[exam.lessonId];
      const e = new PathMapNode(exam.lessonId, exam.title, exam.unitNumber, exam.unitTitle,
        result !== undefined ? 'completed' : (unitDone ? 'current' : 'locked'), result !== undefined ? result.stars : 0);
      e.kind = 'exam';
      e.conquered = (result !== undefined ? result.accuracy : 0) >= 0.8;
      e.questionCount = exam.questionCount;
      e.unitLabel = row.unitLabel ?? null;
      nodes.push(e);
    }
  });
  return nodes;
}

const NODE_W: number = 52;
const NODE_H: number = 37;
const RIM: number = 5;
const NODE_HIT_W: number = 72;
const ROW_H: number = 64;
const BANNER_H: number = 72;
const MAP_PADDING: number = 12;
/** 开始弹窗实测前的高度估计（标题 + 副标题 + 按钮 + 内边距 + 尖角）。 */
const POPUP_EST_H: number = 200;
/** 弹窗底边与视口底边至少留出的距离。 */
const POPUP_MARGIN: number = 16;

class Banner {
  unitNumber: number;
  unitTitle: string;
  firstIndex: number;
  label: string;

  constructor(unitNumber: number, unitTitle: string, firstIndex: number, label: string) {
    this.unitNumber = unitNumber;
    this.unitTitle = unitTitle;
    this.firstIndex = firstIndex;
    this.label = label;
  }
}

@ComponentV2
export struct PathMap {
  @Param lessons: PathMapNode[] = [];
  @Param bookKey: string = '';
  @Event onTapNode: (n: PathMapNode) => void = (_n: PathMapNode) => {
  };
  @Event onGuideTap: (unit: number) => void = (_u: number) => {
  };
  @Event onJumpTap: (unit: number) => void = (_u: number) => {
  };

  @Local selected: number = -1;
  @Local toast: string = '';
  @Local shakeIndex: number = -1;
  @Local shakeX: number = 0;
  @Local scrollY: number = 0;
  @Local viewportH: number = 600;
  @Local stageW: number = 340;
  @Local bob: number = 0;
  @Local halo: number = 0;
  @Local pressedId: string = '';
  @Local celebrateId: string = '';
  @Local burst: number = 0;
  @Local popupH: number = 0;
  private scroller: Scroller = new Scroller();
  private lastCurrentId: string = '';

  aboutToAppear(): void {
    this.lastCurrentId = this.currentMainlineId();
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 900, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate },
        () => {
          this.bob = -3;
        });
      this.getUIContext().animateTo({ duration: 1400, curve: Curve.EaseOut, iterations: -1 }, () => {
        this.halo = 1;
      });
    }, 50);
  }

  @Monitor('lessons')
  onLessonsChanged(): void {
    const cur = this.currentMainlineId();
    if (cur === this.lastCurrentId) {
      return;
    }
    const old = this.lastCurrentId;
    this.lastCurrentId = cur;
    const done = this.lessons.find((n: PathMapNode) => n.id === old && n.status === 'completed');
    if (done !== undefined) {
      this.celebrateId = done.id;
      this.burst = 0;
      SFXEngine.shared.play('star');
      Haptics.success();
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 850, curve: Curve.EaseOut }, () => {
          this.burst = 1;
        });
      }, 16);
      setTimeout(() => {
        this.celebrateId = '';
        this.scrollToCurrent(true);
      }, 1150);
    } else {
      this.scrollToCurrent(true);
    }
  }

  @Computed
  get currentLessonIndex(): number {
    return this.lessons.findIndex((n: PathMapNode) => n.kind === 'lesson' && n.status === 'current');
  }

  private currentMainlineId(): string {
    return this.lessons[this.currentLessonIndex]?.id ?? '';
  }

  @Computed
  get bannerOffsets(): number[] {
    const offsets: number[] = [];
    let offset = 0;
    for (let i = 0; i < this.lessons.length; i++) {
      if (i > 0 && this.lessons[i].unitNumber !== this.lessons[i - 1].unitNumber) {
        offset += BANNER_H + 24;
      }
      offsets.push(offset);
    }
    return offsets;
  }

  private posX(index: number): number {
    return NODE_W / 2 + this.stageW * (index % 2 === 0 ? 0.05 : 0.22);
  }

  private posY(index: number): number {
    const step = Math.max(84, Math.min(140, (this.viewportH - BANNER_H - MAP_PADDING * 2) * 0.255));
    return BANNER_H + step * (index + 0.5) + (this.bannerOffsets[index] ?? 0);
  }

  private connector(index: number): string {
    // SVG path commands use physical pixels; placement and stroke lengths use vp.
    const px = this.getUIContext().vp2px(1);
    const start = this.posX(index) * px;
    const end = this.posX(index + 1) * px;
    const height = (this.posY(index + 1) - this.posY(index)) * px;
    return `M ${start} 0 C ${start} ${height / 2} ${end} ${height / 2} ${end} ${height}`;
  }

  private totalHeight(): number {
    return this.lessons.length === 0 ? ROW_H : this.posY(this.lessons.length - 1) + ROW_H;
  }

  private popupTop(index: number): number {
    return this.posY(index) + ROW_H / 2 + 5;
  }

  private popupBottom(index: number): number {
    return this.popupTop(index) + (this.popupH > 0 ? this.popupH : POPUP_EST_H) + POPUP_MARGIN;
  }

  /** 弹窗打开时画布至少长到弹窗底边，否则末尾几课的弹窗滚不出来。 */
  private stageHeight(): number {
    const base = this.totalHeight();
    if (this.selected < 0 || this.selected >= this.lessons.length) {
      return base;
    }
    return Math.max(base, this.popupBottom(this.selected));
  }

  /** 弹窗画在节点下方；底边超出 Scroll 视口时把路径往上滚，保证「开始」按钮整段可见可点。 */
  private ensurePopupVisible(): void {
    const idx = this.selected;
    if (idx < 0 || idx >= this.lessons.length) {
      return;
    }
    // 等画布按新高度布局完再滚，否则 scrollTo 会被旧的内容高度夹住。
    setTimeout(() => {
      if (this.selected !== idx) {
        return;
      }
      const yOffset = this.scroller.currentOffset().yOffset;
      const need = this.popupBottom(idx) + MAP_PADDING - this.viewportH;
      if (need > yOffset + 1) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: need, animation: { duration: 300, curve: Curve.EaseOut } });
      }
    }, 32);
  }

  @Computed
  get banners(): Banner[] {
    const out: Banner[] = [];
    for (let i = 0; i < this.lessons.length; i++) {
      const n = this.lessons[i];
      if (i === 0 || n.unitNumber !== this.lessons[i - 1].unitNumber) {
        out.push(new Banner(n.unitNumber, n.unitTitle, i, n.displayLabel));
      }
    }
    return out;
  }

  private bannerTop(index: number): number {
    return index === 0 ? 0 : (this.posY(index - 1) + this.posY(index) - BANNER_H) / 2;
  }

  private isUnitLocked(unit: number): boolean {
    const ls = this.lessons.filter((n: PathMapNode) => n.kind === 'lesson' && n.unitNumber === unit);
    return ls.length > 0 && ls.every((n: PathMapNode) => n.status === 'locked');
  }

  private scrollToCurrent(animated: boolean): void {
    const idx = this.currentLessonIndex;
    if (idx < 0) {
      return;
    }
    // 靠前的节点算出来的 yOffset 会被 max(0, …) 夹到顶部，同样要滚（「回到当前」从后面单元滚回来）。
    setTimeout(() => {
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: Math.max(0, this.posY(idx) + MAP_PADDING - this.viewportH / 2),
        animation: animated ? { duration: 400, curve: Curve.EaseOut } : false
      });
    }, 300);
  }

  private nodeIcon(n: PathMapNode): string {
    if (n.kind === 'chest') {
      return 'chest';
    }
    if (n.kind === 'exam') {
      return 'trophy';
    }
    return n.status === 'completed' ? 'star' : (n.status === 'current' ? 'pencil' : 'lock');
  }

  private topColor(n: PathMapNode): string {
    if (n.status === 'locked' || n.chestClaimed) {
      return C.tone('path_locked_top');
    }
    if (n.kind !== 'lesson') {
      return n.kind === 'exam' && !n.conquered ? C.beetle : C.bee;
    }
    if (n.status === 'completed') {
      return C.tone('path_done_top');
    }
    return C.primary === C.feather ? '#71CF46' : C.primary;
  }

  private ledgeColor(n: PathMapNode): string {
    if (n.status === 'locked' || n.chestClaimed) {
      return C.tone('path_locked_ledge');
    }
    if (n.kind !== 'lesson') {
      return n.kind === 'exam' && !n.conquered ? '#A45FD6' : '#CC9E00';
    }
    return n.status === 'completed' ? C.tone('path_done_ledge') :
      (C.primary === C.feather ? '#478B30' : C.primaryDark);
  }

  private iconColor(n: PathMapNode): string {
    if (n.status === 'locked' || n.chestClaimed) {
      return C.tone('path_locked_icon');
    }
    return n.status === 'completed' && n.kind === 'lesson' ? C.tone('path_done_icon') : '#FFFFFF';
  }

  private statusLabel(n: PathMapNode): string {
    if (n.kind === 'chest') {
      return n.chestClaimed ? '已领取' : (n.status === 'locked' ? '未解锁' : '可领取');
    }
    return n.status === 'completed' ? '已完成' : (n.status === 'locked' ? '未解锁' :
      (n.kind === 'exam' ? '可挑战' : '当前课程'));
  }

  private nodeCaption(n: PathMapNode): string {
    const kind = n.kind === 'lesson' ? `第 ${n.lessonNumber} 课` : (n.kind === 'exam' ? '单元挑战' : '单元宝箱');
    return `${kind} · ${this.statusLabel(n)}`;
  }

  private unitProgress(unit: number): number {
    const ls = this.lessons.filter((x: PathMapNode) => x.kind === 'lesson' && x.unitNumber === unit);
    return ls.length === 0 ? 0 : ls.filter((x: PathMapNode) => x.status === 'completed').length / ls.length;
  }

  private maxXp(n: PathMapNode): number {
    return Economy.xpForLesson(n.questionCount, true, n.stars < 3, Economy.isWeekend(), n.kind === 'exam');
  }

  private tapNode(n: PathMapNode, index: number): void {
    if (n.status === 'locked') {
      Haptics.wrong();
      this.shakeIndex = index;
      this.getUIContext().keyframeAnimateTo({ iterations: 1 }, [
        { duration: 70, event: () => { this.shakeX = 8; } },
        { duration: 70, event: () => { this.shakeX = -8; } },
        { duration: 70, event: () => { this.shakeX = 6; } },
        { duration: 70, event: () => { this.shakeX = -6; } },
        { duration: 70, event: () => { this.shakeX = 0; } }
      ]);
      this.toast = n.kind === 'exam' ? '完成本单元全部课程，就能开启单元挑战啦' : '先完成前面的课程再解锁哦';
      setTimeout(() => {
        this.toast = '';
      }, 1800);
    } else if (n.kind === 'chest') {
      Haptics.tap();
      if (!n.chestClaimed) {
        SFXEngine.shared.play('tap');
        this.onTapNode(n);
      }
    } else {
      Haptics.tap();
      SFXEngine.shared.play('tap');
      this.getUIContext().animateTo({ curve: curves.springMotion(0.3, 0.55) }, () => {
        this.selected = this.selected === index ? -1 : index;
      });
    }
  }

  private bannerGrid(): string {
    const px = this.getUIContext().vp2px(1);
    const lines: string[] = [];
    for (let x = 14; x < this.stageW; x += 14) {
      lines.push(`M ${x * px} 0 v ${BANNER_H * px}`);
    }
    for (let y = 14; y < BANNER_H; y += 14) {
      lines.push(`M 0 ${y * px} h ${this.stageW * px}`);
    }
    return lines.join(' ');
  }

  @Builder
  bannerView(b: Banner) {
    Stack() {
      Path().commands(this.bannerGrid()).width(this.stageW).height(BANNER_H)
        .fill(Color.Transparent).stroke(alpha(C.rewardBorder, 0.42)).strokeWidth(0.6)
        .borderRadius(R.card).clip(true).hitTestBehavior(HitTestMode.None)
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(b.label).fontSize(F.micro).fontWeight(W.bold).fontColor(C.tone('unit_banner_label'))
          Text(b.unitTitle).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.tone('unit_banner_title'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.isUnitLocked(b.unitNumber)) {
          Text('跳到这里').fontSize(F.micro).fontWeight(W.bold).fontColor(C.tone('unit_banner_title'))
            .padding({ left: 9, right: 9 }).height(38)
            .onClick(() => {
              Haptics.tap();
              SFXEngine.shared.play('tap');
              this.onJumpTap(b.unitNumber);
            })
            .accessibilityText(`跳级测试，跳到${b.label}`)
        }

        Row({ space: 4 }) {
          DuoIcon({ name: 'book', sz: 16, color: C.tone('unit_banner_action') })
          Text('知识手册').fontSize(F.micro).fontWeight(W.bold).fontColor(C.tone('unit_banner_action'))
        }
        .padding({ left: 10, right: 10, top: 8, bottom: 8 })
        .backgroundColor(C.tone('unit_banner_chip'))
        .border({ width: 1, radius: 18, color: C.rewardBorder })
        .onClick(() => {
          Haptics.tap();
          SFXEngine.shared.play('tap');
          this.onGuideTap(b.unitNumber);
        })
        .accessibilityText(`${b.label}知识手册，本单元进度 ${Math.round(this.unitProgress(b.unitNumber) * 100)}%`)
      }
      .width(this.stageW)
      .height(BANNER_H)
      .padding({ left: 16, right: 12 })
    }
    .width(this.stageW)
    .height(BANNER_H)
    .linearGradient({ angle: 110, colors: [[C.rewardSurface, 0], [C.tone('unit_banner_gradient_end'), 1]] })
    .border({ width: 1, radius: R.card, color: C.rewardBorder })
    .shadow({ radius: 1, offsetY: 3, color: C.tone('unit_banner_shadow') })
    .position({ x: 0, y: this.bannerTop(b.firstIndex) })
  }

  @Builder
  nodeView(n: PathMapNode, index: number) {
    Row({ space: 3 }) {
      Stack() {
        if (n.status === 'current') {
          if (!this.lessons.some((x: PathMapNode) => x.status === 'completed')) {
            Ellipse().width(NODE_W + 12).height(NODE_H + 15).fill(Color.Transparent)
              .stroke(alpha(this.topColor(n), 0.55 * (1 - this.halo))).strokeWidth(2)
              .scale({ x: 1 + 0.3 * this.halo, y: 1 + 0.3 * this.halo })
          }
          Ellipse().width(NODE_W + 17).height(NODE_H + 20).fill(Color.Transparent)
            .stroke(alpha(this.topColor(n), 0.8)).strokeWidth(2).strokeDashArray([4, 4])
            .translate({ y: RIM })
        }
        Ellipse().width(NODE_W + 2).height(NODE_H + 2).fill(this.ledgeColor(n)).opacity(0.42)
          .translate({ y: 9 })
        Ellipse().width(NODE_W + 2).height(NODE_H + 2).fill(C.surface).translate({ y: 7 })
        Ellipse().width(NODE_W).height(NODE_H).fill(this.ledgeColor(n)).translate({ y: RIM })
        Stack() {
          Ellipse().width(NODE_W).height(NODE_H).fill(this.topColor(n))
            .stroke(alpha(this.ledgeColor(n), 0.55)).strokeWidth(1.5)
          Ellipse().width(NODE_W - 5).height(NODE_H - 5).fill(Color.Transparent)
            .stroke(alpha('#FFFFFF', 0.42)).strokeWidth(1)
          DuoIcon({ name: this.nodeIcon(n), sz: n.kind === 'exam' ? 20 : 23, color: this.iconColor(n) })
          if ((n.kind === 'chest' && n.chestClaimed) || (n.kind === 'exam' && n.status === 'completed' && !n.conquered)) {
            DuoIcon({ name: 'checkCircle', sz: 12, color: n.kind === 'chest' ? C.primary : '#FFFFFF' })
              .translate({ x: 12, y: 8 })
          }
        }
        .width(NODE_W)
        .height(NODE_H)
        .translate({ y: this.pressedId === n.id ? RIM : 0 })

        if (this.celebrateId === n.id) {
          Ellipse().width(NODE_W + 6).height(NODE_H + 6).fill(Color.Transparent)
            .stroke(alpha(C.bee, 0.8 * (1 - this.burst))).strokeWidth(3)
            .scale({ x: 1 + 0.8 * this.burst, y: 1 + 0.8 * this.burst })
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
            DuoIcon({ name: 'star', sz: 10, color: C.bee })
              .opacity(1 - this.burst)
              .translate({
                x: Math.cos(i / 8 * 2 * Math.PI) * NODE_W * (0.4 + 0.55 * this.burst),
                y: Math.sin(i / 8 * 2 * Math.PI) * NODE_H * (0.4 + 0.55 * this.burst)
              })
          }, (i: number) => `b${i}`)
        }
      }
      .width(NODE_HIT_W)
      .height(ROW_H)
      .translate({ y: n.status === 'current' ? this.bob : 0 })
      .scale({ x: this.celebrateId === n.id ? 1.04 : 1, y: this.celebrateId === n.id ? 1.04 : 1 })

      Column({ space: 2 }) {
        Text(this.nodeCaption(n)).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(1)
        Text(n.title).fontSize(n.status === 'current' ? 15 : F.caption).fontWeight(W.bold)
          .fontColor(n.status === 'locked' ? C.inkMuted : C.ink).maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width(this.stageW - this.posX(index) + NODE_HIT_W / 2)
    .height(ROW_H)
    .padding({ right: index === 0 ? 78 : 0 })
    .position({ x: this.posX(index) - NODE_HIT_W / 2, y: this.posY(index) - ROW_H / 2 })
    .translate({ x: this.shakeIndex === index ? this.shakeX : 0 })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedId = n.id;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedId = '';
      }
    })
    .onClick(() => this.tapNode(n, index))
    .accessibilityGroup(true)
    .accessibilityText(`${this.nodeCaption(n)}，${n.title}` + (n.kind === 'lesson' && n.status === 'completed' ? `，${n.stars} 星` : ''))
  }

  @Builder
  startPopup(index: number) {
    Column() {
      Polygon({ width: 22, height: 11 })
        .points([[11, 0], [22, 11], [0, 11]])
        .fill(this.popupAccent(index))
        .alignSelf(ItemAlign.Start)
        .margin({ left: Math.max(0, this.posX(index) - 23) })
      Column({ space: 12 }) {
        Text(this.lessons[index].kind === 'exam' ? `⚔️ ${this.lessons[index].title}` : this.lessons[index].title)
          .fontSize(F.subhead).fontWeight(W.bold).fontColor('#FFFFFF').maxLines(2)
        Text(this.popupSubtitle(index)).fontSize(F.caption).fontWeight(W.bold).fontColor('#E6FFFFFF')
        if (this.lessons[index].kind === 'exam' && this.lessons[index].status !== 'completed') {
          Text('答对 80% 以上就能征服这个单元，赢得金色奖杯！').fontSize(F.micro).fontWeight(W.bold).fontColor('#D9FFFFFF')
        }
        Text(this.popupButton(index))
          .fontSize(F.button)
          .fontWeight(W.heavy)
          .fontColor(this.popupAccent(index))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 13, bottom: 13 })
          .backgroundColor('#FFFFFF')
          .borderRadius(999)
          .onClick(() => {
            const n = this.lessons[index];
            this.selected = -1;
            this.onTapNode(n);
          })
      }
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .width(this.stageW - 24)
      .backgroundColor(this.popupAccent(index))
      .borderRadius(R.large)
    }
    .position({ x: 12, y: this.popupTop(index) })
    .zIndex(10)
    .onAreaChange((_o: Area, a: Area) => {
      const h = Number(a.height);
      if (h > 0 && Math.abs(h - this.popupH) > 0.5) {
        this.popupH = h;
      }
      this.ensurePopupVisible();
    })
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.85, y: 0.85 })))
  }

  private popupAccent(index: number): string {
    const n = this.lessons[index];
    return n.kind === 'exam' ? C.beetle : (n.status === 'completed' ? C.bee : unitColors(n.unitNumber)[0]);
  }

  private popupSubtitle(index: number): string {
    const n = this.lessons[index];
    if (n.kind === 'exam') {
      return `${n.questionCount} 道题 · ⚔️ 挑战双倍 XP · 最多 +${this.maxXp(n)} XP`;
    }
    const unitNodes = this.lessons.filter((x: PathMapNode) => x.kind === 'lesson' && x.unitNumber === n.unitNumber);
    return `第 ${n.lessonNumber} / ${unitNodes.length} 节` + (n.stars > 0 ? ` · 已获 ${n.stars} 星` : '') +
      (n.questionCount > 0 ? ` · 最多 +${this.maxXp(n)} XP` : '');
  }

  private popupButton(index: number): string {
    const n = this.lessons[index];
    if (n.kind === 'exam') {
      return n.status === 'completed' ? '再战一次' : '开始挑战';
    }
    return n.status === 'completed' ? '再练一次' : '开始';
  }

  private stickyNode(): PathMapNode | null {
    const top = this.scrollY + 8;
    if (top <= BANNER_H + 24) {
      return null;
    }
    const idx = this.lessons.findIndex((_n: PathMapNode, i: number) => this.posY(i) + ROW_H / 2 >= top);
    return idx >= 0 ? this.lessons[idx] : null;
  }

  @Computed
  get returnDirection(): 'up' | 'down' | null {
    const idx = this.currentLessonIndex;
    if (idx < 0) {
      return null;
    }
    const y = this.posY(idx) - this.scrollY;
    if (y <= 40) {
      return 'up';
    }
    return y >= this.viewportH - 40 ? 'down' : null;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.scroller) {
        Column() {
          Stack({ alignContent: Alignment.TopStart }) {
            ForEach(this.lessons, (n: PathMapNode, i: number) => {
              if (i + 1 < this.lessons.length && this.lessons[i + 1].unitNumber === n.unitNumber) {
                Path().commands(this.connector(i)).width(this.stageW).height(this.posY(i + 1) - this.posY(i))
                  .fill(Color.Transparent).stroke(C.tone('path_trail')).strokeWidth(4.5)
                  .strokeDashArray([0.1, 9]).strokeLineCap(LineCapStyle.Round)
                  .position({ x: 0, y: this.posY(i) }).hitTestBehavior(HitTestMode.None)
              }
            }, (n: PathMapNode, i: number) => `link-${n.id}-${i}`)
            if (this.lessons.length > 0) {
              Mascot({ mood: 'happy', sz: 74, still: true, illustrated: true })
                .position({ x: this.stageW - 74, y: BANNER_H + 5 })
                .hitTestBehavior(HitTestMode.None)
                .accessibilityLevel('no-hide-descendants')
            }
            ForEach(this.banners, (b: Banner) => {
              this.bannerView(b)
            }, (b: Banner) => `banner-${b.unitNumber}-${this.bookKey}-${this.isUnitLocked(b.unitNumber)}`)
            ForEach(this.lessons, (n: PathMapNode, i: number) => {
              this.nodeView(n, i)
            }, (n: PathMapNode, i: number) => `${n.id}-${n.status}-${n.stars}-${n.chestClaimed}-${n.conquered}-${i}`)
            if (this.selected >= 0 && this.selected < this.lessons.length) {
              Column()
                .width(this.stageW)
                .height(this.stageHeight())
                .backgroundColor('#01000000')
                .onClick(() => {
                  this.selected = -1;
                })
              this.startPopup(this.selected)
            }
          }
          .width(this.stageW)
          .height(this.stageHeight())
        }
        .width('100%')
        .padding({ top: MAP_PADDING, bottom: MAP_PADDING })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(C.bg)
      .onDidScroll(() => {
        this.scrollY = this.scroller.currentOffset().yOffset - MAP_PADDING;
      })
      .onAreaChange((_o: Area, n: Area) => {
        this.viewportH = Number(n.height);
        this.stageW = Math.max(1, Math.min(540, Number(n.width) - 32));
      })
      .onAppear(() => this.scrollToCurrent(false))

      if (this.stickyNode() !== null) {
        Row({ space: 10 }) {
          Column({ space: 1 }) {
            Text((this.stickyNode() as PathMapNode).displayLabel).fontSize(F.micro).fontWeight(W.bold).fontColor(C.tone('unit_banner_label'))
            Text((this.stickyNode() as PathMapNode).unitTitle).fontSize(F.caption).fontWeight(W.bold).fontColor(C.tone('unit_banner_title'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            DuoIcon({ name: 'book', sz: 16, color: C.tone('unit_banner_title') })
          }
          .width(36)
          .height(32)
          .responseRegion({ x: '-20%', y: '-20%', width: '140%', height: '140%' })
          .onClick(() => {
            Haptics.tap();
            this.onGuideTap((this.stickyNode() as PathMapNode).unitNumber);
          })
          .accessibilityText('知识手册')
        }
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .margin({ left: 16, right: 16, top: 6 })
        .backgroundColor(C.rewardSurface)
        .borderRadius(R.card)
        .shadow({ radius: 6, color: '#1F000000', offsetY: 3 })
        .transition(TransitionEffect.OPACITY)
      }

      if (this.returnDirection !== null) {
        Button({ type: ButtonType.Circle }) {
          Stack() {
            Image($r('app.media.ic_lesson_compass_dial'))
              .width('100%').height('100%')
              .rotate({ angle: this.returnDirection === 'up' ? 0 : 180 })
            Image($r('app.media.ic_lesson_compass_panda'))
              .width('100%').height('100%')
          }
          .width('100%').height('100%')
          .accessibilityLevel('no-hide-descendants')
        }
        .width(56).height(56).padding(0)
        .backgroundColor(Color.Transparent)
        .position({ right: 16, bottom: 16 })
        .onClick(() => {
          Haptics.tap();
          SFXEngine.shared.play('tap');
          this.scrollToCurrent(true);
        })
        .accessibilityText('回到当前课程')
      }

      if (this.toast.length > 0) {
        Text(this.toast)
          .fontSize(F.caption)
          .fontWeight(W.bold)
          .fontColor('#FFFFFF')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(alpha('#4B4B4B', 0.9))
          .borderRadius(999)
          .position({ x: '10%', bottom: 24 })
          .width('80%')
          .textAlign(TextAlign.Center)
          .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .height('100%')
  }
}
