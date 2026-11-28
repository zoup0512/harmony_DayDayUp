// 知识卡册：每学完一课得一张知识卡（1/2/3 星 → 铜/银/金），集齐一个单元召唤单元守护兽。
// 卡背就是这一课的知识小结——收集的同时复习。
import { curves } from '@kit.ArkUI';
import { C, F, R, S, W, alpha } from '../design/Theme';
import { pathLessonMetas } from '../domain/Catalog';
import { CardTier, Guardian, Guardians } from '../domain/KidsMode';
import { renderMathText } from '../domain/MathText';
import { Book, KnowledgeSummary, PathLessonMeta } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { DataLoader } from '../services/DataLoader';
import { Haptics } from '../services/Feedback';
import { SFXEngine } from '../services/Audio';
import { ChunkyButton, DuoIcon, ModalCard, Pill, ProgressBar } from '../components/Kit';
import { activeBook } from './Books';
import { Router } from './Router';

/** 一张知识卡（tier 0 = 未获得，显示剪影）。 */
@ComponentV2
export struct KnowledgeCardView {
  @Param title: string = '';
  @Param caption: string = '';
  @Param tier: number = 0;
  @Param large: boolean = false;
  @Param badge: string = '';

  private glyph(): string {
    const t = this.title.trim();
    return t.length > 0 ? t.substring(0, 1) : '?';
  }

  private stars(): number[] {
    const out: number[] = [];
    for (let i = 0; i < 3; i++) {
      out.push(i);
    }
    return out;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column({ space: this.large ? 12 : 4 }) {
        Row({ space: 3 }) {
          DuoIcon({ name: this.tier > 0 ? 'star' : 'lock', sz: this.large ? 14 : 10,
            color: this.tier > 0 ? CardTier.color(this.tier) : C.inkMuted })
          Text(this.tier > 0 ? CardTier.label(this.tier) : '未收集')
            .fontSize(this.large ? F.caption : F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
        Blank().layoutWeight(1)
        Stack() {
          Circle().width(this.large ? 96 : 38).height(this.large ? 96 : 38)
            .fill(this.tier > 0 ? alpha(CardTier.color(this.tier), 0.22) : alpha(C.inkSofter, 0.16))
          if (this.tier > 0) {
            Text(this.glyph()).fontSize(this.large ? 46 : 22).fontWeight(W.black).fontColor(CardTier.color(this.tier))
          } else {
            DuoIcon({ name: 'lock', sz: this.large ? 34 : 18, color: C.inkSofter })
          }
        }
        Blank().layoutWeight(1)

        Text(this.tier > 0 ? this.title : '???')
          .fontSize(this.large ? F.heading : F.micro)
          .fontWeight(W.heavy)
          .fontColor(this.tier > 0 ? C.ink : C.inkSofter)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .padding({ left: 6, right: 6 })
        if (this.large) {
          Row({ space: 2 }) {
            ForEach(this.stars(), (i: number) => {
              DuoIcon({ name: i < this.tier ? 'star' : 'starOutline', sz: 18,
                color: i < this.tier ? CardTier.color(this.tier) : C.inkSofter })
            }, (i: number) => `${i}`)
          }
          Text(this.caption)
            .fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 10, right: 10 })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.large ? 15 : 7, bottom: this.large ? 16 : 7 })
      .alignItems(HorizontalAlign.Center)

      if (this.badge.length > 0) {
        Text(this.badge).fontSize(F.micro).fontWeight(W.black).fontColor('#FFFFFF')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 }).backgroundColor(C.danger).borderRadius(999)
          .margin({ top: this.large ? 14 : 8, left: 6 })
      }
    }
    .width(this.large ? 220 : '100%')
    .aspectRatio(11 / 15)
    .backgroundColor(this.tier > 0 ? (C.dark ? alpha(CardTier.color(this.tier), 0.15) : CardTier.tint(this.tier)) : C.surfaceAlt)
    .borderRadius(R.card)
    .border({ width: 2, color: this.tier > 0 ? alpha(CardTier.color(this.tier), 0.6) : C.border, radius: R.card })
    .clip(true)
  }
}

/** 翻牌揭晓：卡背 → 正面（结算页 / 解封时用）。 */
@ComponentV2
export struct CardReveal {
  @Param title: string = '';
  @Param caption: string = '';
  @Param tier: number = 1;
  @Param badge: string = '';
  @Local angle: number = 180;
  @Local front: boolean = false;
  @Local sc: number = 0.6;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.6) }, () => {
        this.sc = 1;
      });
      this.getUIContext().animateTo({
        duration: 260, curve: Curve.EaseIn, onFinish: () => {
          this.front = true;
          this.angle = -90;
          SFXEngine.shared.play('combo');
          Haptics.success();
          this.getUIContext().animateTo({ duration: 320, curve: Curve.EaseOut }, () => {
            this.angle = 0;
          });
        }
      }, () => {
        this.angle = 90;
      });
    }, 350);
  }

  build() {
    Stack() {
      if (this.front) {
        KnowledgeCardView({ title: this.title, caption: this.caption, tier: this.tier, large: true, badge: this.badge })
      } else {
        Column({ space: 10 }) {
          DuoIcon({ name: 'sparkles', sz: 54, color: '#FFFFFF' })
          Text('知识卡').fontSize(F.heading).fontWeight(W.black).fontColor('#FFFFFF')
        }
        .width(220)
        .height(300)
        .justifyContent(FlexAlign.Center)
        .linearGradient({ angle: 135, colors: [[C.secondary, 0], [C.beetle, 1]] })
        .borderRadius(R.card)
      }
    }
    .rotate({ y: 1, angle: this.angle })
    .scale({ x: this.sc, y: this.sc })
  }
}

/** 卡背：这一课的知识小结。 */
@ComponentV2
struct CardBack {
  @Param title: string = '';
  @Param knowledge: KnowledgeSummary | undefined = undefined;

  build() {
    Column({ space: 10 }) {
      Text(this.title).fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).maxLines(2)
      if (this.knowledge === undefined) {
        Text('这张卡的知识小结还没下载，先把课本下载好吧').fontSize(F.caption).fontColor(C.inkMuted)
      } else {
        Scroll() {
          Column({ space: 10 }) {
            if ((this.knowledge?.core_concept ?? '').length > 0) {
              Text('核心概念').fontSize(F.micro).fontWeight(W.heavy).fontColor(C.secondary)
              Text(renderMathText(this.knowledge?.core_concept)).fontSize(F.caption).fontColor(C.ink).lineHeight(20)
            }
            if ((this.knowledge?.key_formula ?? '').length > 0) {
              Text('关键方法').fontSize(F.micro).fontWeight(W.heavy).fontColor(C.primary)
              Text(renderMathText(this.knowledge?.key_formula)).fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink)
                .lineHeight(20)
            }
            if ((this.knowledge?.tips ?? '').length > 0) {
              Text('小提示').fontSize(F.micro).fontWeight(W.heavy).fontColor(C.fox)
              Text(renderMathText(this.knowledge?.tips)).fontSize(F.caption).fontColor(C.ink).lineHeight(20)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width(220)
    .height(300)
    .padding(14)
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }
}

class UnitSet {
  unitNumber: number;
  unitTitle: string;
  lessons: PathLessonMeta[] = [];
  guardian: Guardian;

  constructor(unitNumber: number, unitTitle: string, guardian: Guardian) {
    this.unitNumber = unitNumber;
    this.unitTitle = unitTitle;
    this.guardian = guardian;
  }
}

/** 知识卡册（当前课本）。 */
@ComponentV2
export struct CardAlbumPage {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;
  @Local book: Book | null = null;
  @Local units: UnitSet[] = [];
  @Local detail: PathLessonMeta | null = null;
  @Local detailBack: boolean = false;
  @Local detailAngle: number = 0;
  @Local detailKnowledge: KnowledgeSummary | undefined = undefined;
  @Local guardianUnit: UnitSet | null = null;
  private unsubStore: () => void = () => {
  };
  private unsubBack: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
    this.unsubBack = Router.shared.interceptBack(() => {
      if (this.detail !== null || this.guardianUnit !== null) {
        this.detail = null;
        this.guardianUnit = null;
        return true;
      }
      return false;
    });
    this.load();
  }

  aboutToDisappear(): void {
    this.unsubStore();
    this.unsubBack();
  }

  private load(): void {
    const b = activeBook(this.store);
    this.book = b;
    if (b === null) {
      return;
    }
    const o = DataLoader.tryOutline(b.id);
    if (o === null) {
      return;
    }
    const out: UnitSet[] = [];
    pathLessonMetas(o, b.id).forEach((m: PathLessonMeta) => {
      let u = out.find((x: UnitSet) => x.unitNumber === m.unitNumber);
      if (u === undefined) {
        u = new UnitSet(m.unitNumber, m.unitTitle, Guardians.forUnit(b.id, m.unitNumber));
        out.push(u);
      }
      u.lessons.push(m);
    });
    this.units = out;
  }

  private ownedIn(u: UnitSet): number {
    return u.lessons.filter((m: PathLessonMeta) => this.store.cardTier(m.id) > 0).length;
  }

  private guardianUnlocked(u: UnitSet): boolean {
    return u.lessons.length > 0 && this.ownedIn(u) === u.lessons.length;
  }

  private get totalCards(): number {
    return this.units.reduce((n: number, u: UnitSet) => n + u.lessons.length, 0);
  }

  private get ownedCards(): number {
    return this.units.reduce((n: number, u: UnitSet) => n + this.ownedIn(u), 0);
  }

  private get goldCards(): number {
    return this.units.reduce((n: number, u: UnitSet) =>
      n + u.lessons.filter((m: PathLessonMeta) => this.store.cardTier(m.id) >= 3).length, 0);
  }

  private get guardiansUnlocked(): number {
    return this.units.filter((u: UnitSet) => this.guardianUnlocked(u)).length;
  }

  private rows(u: UnitSet): PathLessonMeta[][] {
    const out: PathLessonMeta[][] = [];
    for (let i = 0; i < u.lessons.length; i += 3) {
      out.push(u.lessons.slice(i, i + 3));
    }
    return out;
  }

  private blanks(row: PathLessonMeta[]): number[] {
    const out: number[] = [];
    for (let i = row.length; i < 3; i++) {
      out.push(i);
    }
    return out;
  }

  private openDetail(m: PathLessonMeta): void {
    if (this.store.cardTier(m.id) <= 0) {
      Haptics.tap();
      return;
    }
    Haptics.tap();
    SFXEngine.shared.play('tap');
    const l = DataLoader.tryLesson(this.book?.id ?? '', m.id);
    const k = l?.knowledge;
    this.detailKnowledge = k !== null && k !== undefined ? k : undefined;
    this.detailBack = false;
    this.detailAngle = 0;
    this.detail = m;
  }

  private flip(): void {
    Haptics.tap();
    this.getUIContext().animateTo({
      duration: 180, curve: Curve.EaseIn, onFinish: () => {
        this.detailBack = !this.detailBack;
        this.detailAngle = -90;
        this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.detailAngle = 0;
        });
      }
    }, () => {
      this.detailAngle = 90;
    });
  }

  @Builder
  guardianChip(u: UnitSet) {
    Row({ space: 8 }) {
      Stack() {
        Circle().width(34).height(34).fill(this.guardianUnlocked(u) ? u.guardian.color : alpha(C.inkSofter, 0.25))
        Text(this.guardianUnlocked(u) ? u.guardian.glyph : '?').fontSize(F.body).fontWeight(W.black)
          .fontColor('#FFFFFF')
      }
      Column({ space: 1 }) {
        Text(this.guardianUnlocked(u) ? `守护兽 · ${u.guardian.name}` : '守护兽 · ???').fontSize(F.caption)
          .fontWeight(W.heavy).fontColor(this.guardianUnlocked(u) ? C.ink : C.inkMuted)
        Text(this.guardianUnlocked(u) ? '点我看看' : `集齐本单元 ${u.lessons.length} 张卡召唤`).fontSize(F.micro)
          .fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
    }
    .padding({ left: 6, right: 12, top: 6, bottom: 6 })
    .backgroundColor(this.guardianUnlocked(u) ? alpha(u.guardian.color, 0.12) : C.surfaceAlt)
    .borderRadius(999)
    .onClick(() => {
      if (this.guardianUnlocked(u)) {
        Haptics.tap();
        this.guardianUnit = u;
      }
    })
  }

  @Builder
  unitSection(u: UnitSet) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(`第 ${u.unitNumber} 单元`).fontSize(F.micro).fontWeight(W.heavy).fontColor(C.inkMuted)
          Text(u.unitTitle).fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(`${this.ownedIn(u)}/${u.lessons.length}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.secondary)
      }
      .width('100%')

      this.guardianChip(u)

      ForEach(this.rows(u), (row: PathLessonMeta[]) => {
        Row({ space: 10 }) {
          ForEach(row, (m: PathLessonMeta) => {
            Column() {
              KnowledgeCardView({ title: m.title, caption: `第 ${m.unitNumber} 单元`, tier: this.store.cardTier(m.id) })
            }
            .layoutWeight(1)
            .onClick(() => this.openDetail(m))
          }, (m: PathLessonMeta) => `${m.id}-${this.store.cardTier(m.id)}`)
          ForEach(this.blanks(row), (i: number) => {
            Blank().layoutWeight(1)
          }, (i: number) => `b${i}`)
        }
        .width('100%')
      }, (row: PathLessonMeta[]) => row.map((m: PathLessonMeta) => m.id).join(','))
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  detailModal() {
    ModalCard({ maxW: 300, onBackdrop: () => {
      this.detail = null;
    } }) {
      Stack() {
        if (this.detailBack) {
          CardBack({ title: this.detail?.title ?? '', knowledge: this.detailKnowledge })
        } else {
          KnowledgeCardView({
            title: this.detail?.title ?? '', caption: `第 ${this.detail?.unitNumber ?? 0} 单元`,
            tier: this.store.cardTier(this.detail?.id ?? ''), large: true
          })
        }
      }
      .rotate({ y: 1, angle: this.detailAngle })

      if (this.store.cardTier(this.detail?.id ?? '') < 3) {
        Text('三星通关这一课，就能升级成金卡').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      ChunkyButton({ label: this.detailBack ? '看正面' : '翻到背面 · 知识小结', variant: 'secondary',
        onTap: () => this.flip() })
      ChunkyButton({ label: '收起', variant: 'ghost', onTap: () => {
        this.detail = null;
      } })
    }
  }

  @Builder
  guardianModal() {
    ModalCard({ maxW: 300, onBackdrop: () => {
      this.guardianUnit = null;
    } }) {
      Stack() {
        Circle().width(120).height(120).fill(this.guardianUnit?.guardian.color ?? C.primary)
        Text(this.guardianUnit?.guardian.glyph ?? '').fontSize(56).fontWeight(W.black).fontColor('#FFFFFF')
      }
      Text(this.guardianUnit?.guardian.name ?? '').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
      Text(`第 ${this.guardianUnit?.unitNumber ?? 0} 单元守护兽`).fontSize(F.caption).fontWeight(W.bold)
        .fontColor(C.inkMuted)
      Text(this.guardianUnit?.guardian.desc ?? '').fontSize(F.body).fontColor(C.ink).textAlign(TextAlign.Center)
        .lineHeight(22)
      ChunkyButton({ label: '好的', onTap: () => {
        this.guardianUnit = null;
      } })
    }
  }

  build() {
    Stack() {
      Column() {
        Row({ space: 8 }) {
          Stack() {
            DuoIcon({ name: 'chevronLeft', sz: 20, color: C.ink })
          }
          .width(44).height(44).onClick(() => {
            Haptics.tap();
            Router.shared.pop();
          }).accessibilityText('返回')
          Text('知识卡册').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
        }
        .width('100%').height(52).padding({ left: 10 }).backgroundColor(C.studyHeader)
        ForEach([this.rev], (r: number) => {
          Scroll() {
            Column({ space: S.xl }) {
              if (this.book === null || this.units.length === 0) {
                Column({ space: 12 }) {
                  DuoIcon({ name: 'books', sz: 48, color: C.inkSofter })
                  Text('先选一本课本、下载好课程，就能开始收集知识卡').fontSize(F.body).fontColor(C.inkMuted)
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .margin({ top: 80 })
              } else {
                Column({ space: 8 }) {
                  Row({ space: 8 }) {
                    Column({ space: 4 }) {
                      Text(this.book?.fullName ?? '').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
                        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Row({ space: 8 }) {
                        Text(`${this.ownedCards}`).fontSize(F.display).fontWeight(W.black).fontColor(C.ink)
                        Text(`/ ${this.totalCards} 张知识卡`).fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
                      }
                      .alignItems(VerticalAlign.Bottom)
                    }
                    .alignItems(HorizontalAlign.Start).layoutWeight(1)
                    Image($r('app.media.learning_cards')).width(76).height(64).objectFit(ImageFit.Contain)
                  }
                  .width('100%')
                  ProgressBar({ progress: this.ownedCards / Math.max(1, this.totalCards), barHeight: 7 })
                  Row({ space: 8 }) {
                    Pill(`金卡 ${this.goldCards}`, C.ink, alpha(C.bee, 0.23))
                    Pill(`守护兽 ${this.guardiansUnlocked}/${this.units.length}`, C.ink, alpha(C.primary, 0.15))
                  }
                }
                .alignItems(HorizontalAlign.Start).width('100%').padding(14)
                .backgroundColor(C.rewardSurface).borderRadius(R.card)
                .border({ width: 1, color: C.rewardBorder, radius: R.card })
                Text('每学完一课得一张知识卡。1 星铜卡、2 星银卡、3 星金卡。')
                  .fontSize(F.micro).fontColor(C.inkMuted).lineHeight(17).width('100%')

                ForEach(this.units, (u: UnitSet) => {
                  this.unitSection(u)
                }, (u: UnitSet) => `u${u.unitNumber}`)
              }
              Blank().height(30)
            }
            .padding({ left: 16, right: 16, top: 14 })
          }
          .layoutWeight(1)
          .align(Alignment.Top)
          .scrollBar(BarState.Off)
        }, (r: number) => `cards-${r}`)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(C.bg)

      if (this.detail !== null) {
        this.detailModal()
      }
      if (this.guardianUnit !== null) {
        this.guardianModal()
      }
    }
    .width('100%')
    .height('100%')
  }
}
