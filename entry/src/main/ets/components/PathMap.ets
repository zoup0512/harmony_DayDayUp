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

export type NodeKindTag = 'lesson' | 'chest' | 'exam';

export class PathMapNode {
  id: string;
  title: string;
  unitNumber: number;
  unitTitle: string;
  status: LessonStatus;
  stars: number;
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

const OFFSETS: number[] = [0, 35, 45, 35, 0, -35, -45, -35];
const NODE: number = 72;
const STEP_Y: number = 96;
const BANNER_H: number = 72;
const STAGE_W: number = 340;
/** 开始弹窗实测前的高度估计（标题 + 副标题 + 按钮 + 内边距 + 尖角）。 */
const POPUP_EST_H: number = 200;
/** 弹窗底边与视口底边至少留出的距离。 */
const POPUP_MARGIN: number = 16;

class Banner {
  unitNumber: number;
  unitTitle: string;
  y: number;
  label: string;

  constructor(unitNumber: number, unitTitle: string, y: number, label: string) {
    this.unitNumber = unitNumber;
    this.unitTitle = unitTitle;
    this.y = y;
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
          this.bob = -6;
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

  private currentMainlineId(): string {
    return this.lessons.find((n: PathMapNode) => n.status === 'current' && n.kind !== 'exam')?.id ?? '';
  }

  private bannerOffsetBefore(index: number): number {
    let off = 0;
    for (let i = 1; i < Math.min(index + 1, this.lessons.length); i++) {
      if (this.lessons[i].unitNumber !== this.lessons[i - 1].unitNumber) {
        off += BANNER_H + 24;
      }
    }
    return off;
  }

  private posX(index: number): number {
    return STAGE_W / 2 + OFFSETS[index % OFFSETS.length];
  }

  private posY(index: number): number {
    return NODE / 2 + index * STEP_Y + this.bannerOffsetBefore(index) + BANNER_H + 24;
  }

  private totalHeight(): number {
    return this.lessons.length === 0 ? NODE : this.posY(this.lessons.length - 1) + NODE / 2 + 160;
  }

  private popupTop(index: number): number {
    return this.posY(index) + NODE / 2 + 30;
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
      // 画布坐标 y 在视口里的位置 = y + 20（Column 顶部 padding）- yOffset。
      const need = this.popupBottom(idx) + 20 - this.viewportH;
      if (need > yOffset + 1) {
        this.scroller.scrollTo({ xOffset: 0, yOffset: need, animation: { duration: 300, curve: Curve.EaseOut } });
      }
    }, 32);
  }

  private banners(): Banner[] {
    const out: Banner[] = [];
    if (this.lessons.length > 0) {
      const f = this.lessons[0];
      out.push(new Banner(f.unitNumber, f.unitTitle, BANNER_H / 2 + 4, f.displayLabel));
    }
    for (let i = 1; i < this.lessons.length; i++) {
      if (this.lessons[i].unitNumber !== this.lessons[i - 1].unitNumber) {
        out.push(new Banner(this.lessons[i].unitNumber, this.lessons[i].unitTitle,
          (this.posY(i - 1) + this.posY(i)) / 2, this.lessons[i].displayLabel));
      }
    }
    return out;
  }

  private isUnitLocked(unit: number): boolean {
    const ls = this.lessons.filter((n: PathMapNode) => n.kind === 'lesson' && n.unitNumber === unit);
    return ls.length > 0 && ls.every((n: PathMapNode) => n.status === 'locked');
  }

  private scrollToCurrent(animated: boolean): void {
    const id = this.currentMainlineId();
    const idx = this.lessons.findIndex((n: PathMapNode) => n.id === id);
    if (idx < 0) {
      return;
    }
    // 靠前的节点算出来的 yOffset 会被 max(0, …) 夹到顶部，同样要滚（「回到当前」从后面单元滚回来）。
    setTimeout(() => {
      this.scroller.scrollTo({
        xOffset: 0,
        yOffset: Math.max(0, this.posY(idx) + 20 - this.viewportH / 2),
        animation: animated ? { duration: 400, curve: Curve.EaseOut } : false
      });
    }, 300);
  }

  private nodeIcon(n: PathMapNode, index: number): string {
    if (n.kind === 'chest') {
      return 'chest';
    }
    if (n.kind === 'exam') {
      return 'trophy';
    }
    const later = this.lessons.slice(index + 1).some((x: PathMapNode) => x.kind === 'lesson' && x.unitNumber === n.unitNumber);
    if (!later) {
      return 'trophy';
    }
    if (n.status === 'completed' && n.stars > 0) {
      return 'crown';
    }
    return index % 4 === 2 ? 'dumbbell' : 'star';
  }

  private topColor(n: PathMapNode): string {
    if (n.kind === 'chest' && n.chestClaimed) {
      return C.lockedNodeTop;
    }
    if (n.kind === 'exam') {
      return n.status === 'locked' ? C.lockedNodeTop : (n.conquered ? C.bee : C.beetle);
    }
    return n.status === 'completed' ? C.bee : (n.status === 'current' ? unitColors(n.unitNumber)[0] : C.lockedNodeTop);
  }

  private ledgeColor(n: PathMapNode): string {
    if (n.kind === 'chest' && n.chestClaimed) {
      return C.lockedNodeLedge;
    }
    if (n.kind === 'exam') {
      return n.status === 'locked' ? C.lockedNodeLedge : (n.conquered ? '#CC9E00' : '#A45FD6');
    }
    return n.status === 'completed' ? '#CC9E00' : (n.status === 'current' ? unitColors(n.unitNumber)[1] : C.lockedNodeLedge);
  }

  private iconColor(n: PathMapNode): string {
    if (n.kind === 'chest' && n.chestClaimed) {
      return alpha(C.bee, 0.55);
    }
    if (n.kind === 'exam' && n.status !== 'locked' && !n.conquered) {
      return n.status === 'completed' ? C.bee : C.bee;
    }
    return n.status === 'locked' ? C.inkSofter : '#FFFFFF';
  }

  private unitProgress(n: PathMapNode): number {
    const ls = this.lessons.filter((x: PathMapNode) => x.kind === 'lesson' && x.unitNumber === n.unitNumber);
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

  @Builder
  bannerView(b: Banner) {
    Stack() {
      Row().width(STAGE_W - 16).height(BANNER_H).borderRadius(R.card).backgroundColor(unitColors(b.unitNumber)[1])
        .translate({ y: 4 })
      Row() {
        Column({ space: 5 }) {
          if (this.isUnitLocked(b.unitNumber)) {
            Text(`${b.label} · ${b.unitTitle}`).fontSize(F.caption).fontWeight(W.bold).fontColor('#E6FFFFFF')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Row({ space: 5 }) {
              Text('⚡').fontSize(12)
              Text('跳到这里').fontSize(F.caption).fontWeight(W.bold).fontColor(unitColors(b.unitNumber)[0])
            }
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .backgroundColor('#FFFFFF')
            .borderRadius(999)
            .onClick(() => {
              Haptics.tap();
              SFXEngine.shared.play('tap');
              this.onJumpTap(b.unitNumber);
            })
            .accessibilityText(`跳级测试，跳到${b.label}`)
          } else {
            Text(b.label).fontSize(F.micro).fontWeight(W.bold).fontColor('#D9FFFFFF').letterSpacing(1.2)
            Text(b.unitTitle).fontSize(F.subhead).fontWeight(W.bold).fontColor('#FFFFFF').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding({ left: 18, right: 8 })

        Column().width(1).height(BANNER_H - 28).backgroundColor('#40FFFFFF')
        Stack() {
          DuoIcon({ name: 'list', sz: 22, color: '#FFFFFF' })
        }
        .width(64)
        .height(BANNER_H)
        .onClick(() => {
          Haptics.tap();
          SFXEngine.shared.play('tap');
          this.onGuideTap(b.unitNumber);
        })
        .accessibilityText(`${b.label}知识手册`)
      }
      .width(STAGE_W - 16)
      .height(BANNER_H)
      .borderRadius(R.card)
      .backgroundColor(unitColors(b.unitNumber)[0])
    }
    .width(STAGE_W - 16)
    .height(BANNER_H + 4)
    .position({ x: 8, y: b.y - BANNER_H / 2 })
  }

  @Builder
  nodeView(n: PathMapNode, index: number) {
    Column({ space: 6 }) {
      Stack() {
        if (n.status === 'current' && n.kind !== 'exam') {
          if (!this.lessons.some((x: PathMapNode) => x.status === 'completed')) {
            Circle()
              .width(NODE + 8)
              .height(NODE + 8)
              .fill(Color.Transparent)
              .stroke(alpha(C.primary, 0.55 * (1 - this.halo)))
              .strokeWidth(4)
              .scale({ x: 1 + 0.55 * this.halo, y: 1 + 0.55 * this.halo })
          }
          Circle().width(NODE + 18).height(NODE + 18).fill(Color.Transparent).stroke(C.surfaceAlt).strokeWidth(5)
            .strokeDashArray([3, 6]).strokeLineCap(LineCapStyle.Round)
          Progress({ value: Math.max(0.1, this.unitProgress(n) * 100), total: 100, type: ProgressType.Ring })
            .width(NODE + 23)
            .height(NODE + 23)
            .color(unitColors(n.unitNumber)[0])
            .backgroundColor(Color.Transparent)
            .style({ strokeWidth: 5 })
        }
        Circle().width(NODE).height(NODE).fill(this.ledgeColor(n)).translate({ y: 5 })
        Stack() {
          Circle().width(NODE).height(NODE).fill(this.topColor(n))
          if (this.nodeIcon(n, index) === 'crown') {
            Column({ space: 2 }) {
              DuoIcon({ name: 'crown', sz: 18, color: this.iconColor(n) })
              Row({ space: 1 }) {
                ForEach([0, 1, 2], (i: number) => {
                  DuoIcon({ name: i < n.stars ? 'star' : 'starOutline', sz: 7, color: this.iconColor(n) })
                }, (i: number) => `${i}`)
              }
            }
          } else {
            DuoIcon({ name: this.nodeIcon(n, index), sz: n.kind === 'exam' ? 26 : 26, color: this.iconColor(n) })
          }
          if ((n.kind === 'chest' && n.chestClaimed) || (n.kind === 'exam' && n.status === 'completed' && !n.conquered)) {
            DuoIcon({ name: 'checkCircle', sz: 13, color: n.kind === 'chest' ? C.primary : '#FFFFFF' })
              .translate({ x: 14, y: 14 })
          }
        }
        .width(NODE)
        .height(NODE)
        .translate({ y: this.pressedId === n.id ? 5 : 0 })

        if (this.celebrateId === n.id) {
          Circle().width(NODE + 6).height(NODE + 6).fill(Color.Transparent)
            .stroke(alpha(C.bee, 0.8 * (1 - this.burst))).strokeWidth(5)
            .scale({ x: 1 + 0.8 * this.burst, y: 1 + 0.8 * this.burst })
          ForEach([0, 1, 2, 3, 4, 5, 6, 7], (i: number) => {
            DuoIcon({ name: 'star', sz: 11, color: C.bee })
              .opacity(1 - this.burst)
              .translate({
                x: Math.cos(i / 8 * 2 * Math.PI) * NODE * (0.4 + 0.55 * this.burst),
                y: Math.sin(i / 8 * 2 * Math.PI) * NODE * (0.4 + 0.55 * this.burst)
              })
          }, (i: number) => `b${i}`)
        }
      }
      .width(NODE + 24)
      .height(NODE + 24)

      if (n.status === 'current') {
        Text(n.kind === 'exam' ? '挑战' : '开始')
          .fontSize(F.caption)
          .fontWeight(W.bold)
          .letterSpacing(0.6)
          .fontColor(n.kind === 'exam' ? C.beetle : unitColors(n.unitNumber)[0])
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(C.bg)
          .borderRadius(999)
          .border({ width: 2, color: C.border, radius: 999 })
          .margin({ top: -6 })
      }
    }
    .position({ x: this.posX(index) - (NODE + 24) / 2, y: this.posY(index) - (NODE + 24) / 2 })
    .translate({ x: this.shakeIndex === index ? this.shakeX : 0, y: n.status === 'current' ? this.bob : 0 })
    .scale({ x: this.celebrateId === n.id ? 1.04 : 1, y: this.celebrateId === n.id ? 1.04 : 1 })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressedId = n.id;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressedId = '';
      }
    })
    .onClick(() => this.tapNode(n, index))
    .accessibilityText(n.kind === 'chest' ? `宝箱, ${n.status === 'locked' ? '未解锁' : (n.chestClaimed ? '已领取' : '可领取')}` :
      `${n.title}, ${n.status === 'completed' ? '已完成' : (n.status === 'current' ? '当前' : '未解锁')}`)
  }

  @Builder
  startPopup(index: number) {
    Column() {
      Polygon({ width: 22, height: 11 })
        .points([[11, 0], [22, 11], [0, 11]])
        .fill(this.popupAccent(index))
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
      .width(STAGE_W - 48)
      .backgroundColor(this.popupAccent(index))
      .borderRadius(R.large)
    }
    .position({ x: 24, y: this.popupTop(index) })
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
    const no = unitNodes.findIndex((x: PathMapNode) => x.id === n.id) + 1;
    return `第 ${no} / ${unitNodes.length} 节` + (n.questionCount > 0 ? ` · 最多 +${this.maxXp(n)} XP` : '');
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
    const idx = this.lessons.findIndex((_n: PathMapNode, i: number) => this.posY(i) + NODE / 2 >= top);
    return idx >= 0 ? this.lessons[idx] : null;
  }

  private currentViewportY(): number | null {
    const id = this.currentMainlineId();
    const idx = this.lessons.findIndex((n: PathMapNode) => n.id === id);
    return idx < 0 ? null : this.posY(idx) + 20 - this.scrollY;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Scroll(this.scroller) {
        Column() {
          Stack({ alignContent: Alignment.TopStart }) {
            if (this.lessons.length >= 4) {
              Row({ space: 4 }) {
                DuoIcon({ name: 'star', sz: 14, color: C.surfaceAlt })
                DuoIcon({ name: 'star', sz: 16, color: C.surfaceAlt })
                DuoIcon({ name: 'star', sz: 14, color: C.surfaceAlt })
              }
              .position({ x: STAGE_W - 70, y: this.posY(3) - 4 })
            }
            ForEach(this.banners(), (b: Banner) => {
              this.bannerView(b)
            }, (b: Banner) => `banner-${b.unitNumber}-${this.bookKey}-${this.isUnitLocked(b.unitNumber)}`)
            ForEach(this.lessons, (n: PathMapNode, i: number) => {
              this.nodeView(n, i)
            }, (n: PathMapNode, i: number) => `${n.id}-${n.status}-${n.stars}-${n.chestClaimed}-${i}`)
            if (this.selected >= 0 && this.selected < this.lessons.length) {
              Column()
                .width(STAGE_W)
                .height(this.stageHeight())
                .backgroundColor('#01000000')
                .onClick(() => {
                  this.selected = -1;
                })
              this.startPopup(this.selected)
            }
          }
          .width(STAGE_W)
          .height(this.stageHeight())
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(C.bg)
      .onDidScroll(() => {
        this.scrollY = this.scroller.currentOffset().yOffset - 20;
      })
      .onAreaChange((_o: Area, n: Area) => {
        this.viewportH = Number(n.height);
      })
      .onAppear(() => this.scrollToCurrent(false))

      if (this.stickyNode() !== null) {
        Row({ space: 10 }) {
          Column({ space: 1 }) {
            Text((this.stickyNode() as PathMapNode).displayLabel).fontSize(F.micro).fontWeight(W.bold).fontColor('#D9FFFFFF')
            Text((this.stickyNode() as PathMapNode).unitTitle).fontSize(F.caption).fontWeight(W.bold).fontColor('#FFFFFF')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            DuoIcon({ name: 'list', sz: 16, color: '#FFFFFF' })
          }
          .width(36)
          .height(32)
          .onClick(() => {
            Haptics.tap();
            this.onGuideTap((this.stickyNode() as PathMapNode).unitNumber);
          })
        }
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .margin({ left: 16, right: 16, top: 6 })
        .backgroundColor(unitColors((this.stickyNode() as PathMapNode).unitNumber)[0])
        .borderRadius(R.card)
        .shadow({ radius: 6, color: '#1F000000', offsetY: 3 })
        .transition(TransitionEffect.OPACITY)
      }

      if (this.currentViewportY() !== null &&
        ((this.currentViewportY() as number) <= 40 || (this.currentViewportY() as number) >= this.viewportH - 40)) {
        Row({ space: 6 }) {
          DuoIcon({ name: (this.currentViewportY() as number) <= 40 ? 'arrowUp' : 'arrowDown', sz: 13, color: '#FFFFFF' })
          Text('回到当前').fontSize(F.caption).fontWeight(W.bold).fontColor('#FFFFFF')
        }
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor(C.secondary)
        .borderRadius(999)
        .border({ width: 2, color: C.secondaryDark, radius: 999 })
        .shadow({ radius: 6, color: '#2E000000', offsetY: 3 })
        .position({ right: 16, bottom: 28 })
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
