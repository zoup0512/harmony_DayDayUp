// 基础 UI 套件：图标、Chunky 3D 按钮、进度条、气泡、弹层卡片。
import { curves } from '@kit.ArkUI';
import { C, F, R, W, alpha, Motion } from '../design/Theme';
import { bubbleTone } from '../domain/Catalog';
import { MascotMood } from '../models/Types';
import { Haptics } from '../services/Feedback';

/** SF Symbol 名 → HarmonyOS HM Symbol（缺失的用自绘 SVG）。 */
export function symbolRes(name: string): Resource | null {
  switch (name) {
    case 'house':
      return $r('sys.symbol.house_fill');
    case 'book':
      return $r('sys.symbol.book_pages_fill');
    case 'bag':
      return $r('sys.symbol.bag_fill');
    case 'person':
      return $r('sys.symbol.person_crop_circle_fill');
    case 'rosette':
      return $r('sys.symbol.rosette');
    case 'books':
      return $r('sys.symbol.books_vertical_fill');
    case 'flame':
      return $r('sys.symbol.flame_fill');
    case 'heart':
      return $r('sys.symbol.heart_fill');
    case 'heartSlash':
      return $r('sys.symbol.heart_slash');
    case 'bolt':
      return $r('sys.symbol.bolt_fill');
    case 'star':
      return $r('sys.symbol.star_fill');
    case 'starOutline':
      return $r('sys.symbol.star');
    case 'crown':
      return $r('sys.symbol.crown_fill');
    case 'check':
      return $r('sys.symbol.checkmark');
    case 'checkCircle':
      return $r('sys.symbol.checkmark_circle_fill');
    case 'xmark':
      return $r('sys.symbol.xmark');
    case 'xmarkCircle':
      return $r('sys.symbol.xmark_circle_fill');
    case 'chevronRight':
      return $r('sys.symbol.chevron_right');
    case 'chevronLeft':
      return $r('sys.symbol.chevron_left');
    case 'speaker':
      return $r('sys.symbol.speaker_wave_2_fill');
    case 'speakerSlash':
      return $r('sys.symbol.speaker_slash_fill');
    case 'mic':
      return $r('sys.symbol.mic_fill');
    case 'micSlash':
      return $r('sys.symbol.mic_slash_fill');
    case 'snowflake':
      return $r('sys.symbol.snowflake');
    case 'gear':
      return $r('sys.symbol.gearshape_fill');
    case 'flag':
      return $r('sys.symbol.flag');
    case 'flagFill':
      return $r('sys.symbol.flag_fill');
    case 'gift':
      return $r('sys.symbol.gift_fill');
    case 'clock':
      return $r('sys.symbol.clock_fill');
    case 'arrowUp':
      return $r('sys.symbol.arrow_up');
    case 'arrowDown':
      return $r('sys.symbol.arrow_down');
    case 'arrowUpRight':
      return $r('sys.symbol.arrow_up_right');
    case 'arrowCounter':
      return $r('sys.symbol.arrow_counterclockwise');
    case 'pencil':
      return $r('sys.symbol.pencil_circle_fill');
    case 'bell':
      return $r('sys.symbol.bell_fill');
    case 'trash':
      return $r('sys.symbol.trash_fill');
    case 'share':
      return $r('sys.symbol.share');
    case 'download':
      return $r('sys.symbol.square_and_arrow_down');
    case 'downloadCircle':
      return $r('sys.symbol.arrow_down_circle');
    case 'play':
      return $r('sys.symbol.play_fill');
    case 'stop':
      return $r('sys.symbol.stop_circle_fill');
    case 'dumbbell':
      return $r('sys.symbol.dumbbell_fill');
    case 'list':
      return $r('sys.symbol.list_bullet_square_fill');
    case 'textBook':
      return $r('sys.symbol.text_book_closed');
    case 'scroll':
      return $r('sys.symbol.doc_plaintext_fill');
    case 'textAlign':
      return $r('sys.symbol.text_alignleft');
    case 'music':
      return $r('sys.symbol.music');
    case 'bubble':
      return $r('sys.symbol.ellipsis_bubble');
    case 'sparkles':
      return $r('sys.symbol.wand_and_stars_fill');
    case 'drop':
      return $r('sys.symbol.drop_fill');
    case 'listNumber':
      return $r('sys.symbol.list_number');
    case 'handTap':
      return $r('sys.symbol.hand_tap_fill');
    case 'warn':
      return $r('sys.symbol.exclamationmark_triangle_fill');
    case 'rocket':
      return $r('sys.symbol.paperplane_fill');
    case 'bookmark':
      return $r('sys.symbol.bookmark_fill');
    case 'medal':
      return $r('sys.symbol.medal');
    case 'seal':
      return $r('sys.symbol.checkmark_square_fill');
    case 'cycle':
      return $r('sys.symbol.arrow_2_circlepath');
    case 'lock':
      return $r('sys.symbol.lock_fill');
    case 'bubbleText':
      return $r('sys.symbol.text_bubble_left_2');
    case 'vibrate':
      return $r('sys.symbol.a_4d_vibration');
    default:
      return null;
  }
}

export function svgRes(name: string): Resource {
  switch (name) {
    case 'trophy':
      return $r('app.media.ic_trophy');
    case 'gem':
      return $r('app.media.ic_gem');
    case 'target':
      return $r('app.media.ic_target');
    case 'chart':
      return $r('app.media.ic_chart');
    case 'bandage':
      return $r('app.media.ic_bandage');
    default:
      return $r('app.media.ic_chest');
  }
}

@ComponentV2
export struct DuoIcon {
  @Param name: string = 'star';
  @Param sz: number = 18;
  @Param color: ResourceColor = '#4B4B4B';

  build() {
    if (symbolRes(this.name) !== null) {
      SymbolGlyph(symbolRes(this.name) as Resource)
        .fontSize(this.sz)
        .fontColor([this.color])
        .fontWeight(FontWeight.Bold)
    } else {
      Image(svgRes(this.name))
        .width(this.sz)
        .height(this.sz)
        .fillColor(this.color)
        .objectFit(ImageFit.Contain)
    }
  }
}

export type ChunkyVariant = 'primary' | 'secondary' | 'reward' | 'danger' | 'ghost' | 'disabled';

/** 3D 「厚底」大按钮（ChunkyButtonStyle）：按下时表面下沉 4vp 贴合底座。 */
@ComponentV2
export struct ChunkyButton {
  @Param label: string = '';
  @Param variant: ChunkyVariant = 'primary';
  @Param icon: string = '';
  @Event onTap: () => void = () => {
  };
  @Local pressed: boolean = false;

  private bgColor(): string {
    switch (this.variant) {
      case 'primary':
        return C.primary;
      case 'secondary':
        return C.secondary;
      case 'reward':
        return C.dark ? '#735C31' : '#FFE194';
      case 'danger':
        return C.danger;
      case 'ghost':
        return C.surface;
      default:
        return C.bgSofter;
    }
  }

  private fgColor(): string {
    switch (this.variant) {
      case 'primary':
        return C.theme === null ? '#163C1A' : '#FFFFFF';
      case 'reward':
        return C.dark ? '#FFF3CC' : '#704810';
      case 'ghost':
        return C.inkLight;
      case 'disabled':
        return C.inkSofter;
      default:
        return '#FFFFFF';
    }
  }

  private ledgeColor(): string {
    switch (this.variant) {
      case 'primary':
        return C.primaryDark;
      case 'secondary':
        return C.secondaryDark;
      case 'reward':
        return C.rewardBorder;
      case 'danger':
        return C.dangerDark;
      case 'ghost':
        return C.border;
      default:
        return C.bgSofter;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column()
        .width('100%')
        .height(50)
        .borderRadius(R.card)
        .backgroundColor(this.pressed ? this.bgColor() : this.ledgeColor())
        .margin({ top: 4 })
      Row({ space: 8 }) {
        if (this.icon.length > 0) {
          DuoIcon({ name: this.icon, sz: 15, color: this.fgColor() })
        }
        Text(this.label)
          .fontSize(F.button)
          .fontWeight(W.heavy)
          .fontColor(this.fgColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')
      .height(50)
      .padding({ left: 24, right: 24 })
      .borderRadius(R.card)
      .backgroundColor(this.bgColor())
      .border(this.variant === 'ghost' ? { width: 2, color: C.border, radius: R.card } : { width: 0, radius: R.card })
      .translate({ y: this.pressed ? 4 : 0 })
      .animation({ curve: Motion.press() })
    }
    .width('100%')
    .height(54)
    .opacity(this.variant === 'disabled' ? 0.6 : 1)
    .hitTestBehavior(this.variant === 'disabled' ? HitTestMode.None : HitTestMode.Default)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      if (this.variant !== 'disabled') {
        this.onTap();
      }
    })
  }
}

/** 小号厚底按钮（ChunkySmallButtonStyle）。 */
@ComponentV2
export struct SmallChunkyButton {
  @Param label: string = '';
  @Param icon: string = '';
  @Param bgColor: string = '#58CC02';
  @Param shadowColor: string = '#58A700';
  @Param active: boolean = true;
  @Event onTap: () => void = () => {
  };
  @Local pressed: boolean = false;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Row()
        .height(36)
        .width('100%')
        .borderRadius(R.control)
        .backgroundColor(this.active ? (this.pressed ? this.bgColor : this.shadowColor) : C.border)
        .margin({ top: 3 })
      Row({ space: 5 }) {
        if (this.icon.length > 0) {
          DuoIcon({ name: this.icon, sz: 13, color: this.active ? '#FFFFFF' : C.inkMuted })
        }
        Text(this.label).fontSize(F.caption).fontWeight(W.heavy).fontColor(this.active ? '#FFFFFF' : C.inkMuted).maxLines(1)
      }
      .width('100%')
      .height(36)
      .justifyContent(FlexAlign.Center)
      .padding({ left: 5, right: 5 })
      .borderRadius(R.control)
      .backgroundColor(this.active ? this.bgColor : C.surfaceAlt)
      .translate({ y: this.pressed ? 3 : 0 })
    }
    .height(39)
    .enabled(this.active)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true;
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => {
      if (this.active) {
        this.onTap();
      }
    })
  }
}

/** 胶囊进度条（StyledProgressBar）：内高光 + 连击金边 + 答对扫光。 */
@ComponentV2
export struct ProgressBar {
  @Param progress: number = 0;
  @Param barHeight: number = 16;
  @Param fillColor: string = '';
  @Param trackColor: string = '';
  @Param sweepTrigger: number = 0;
  @Param comboLevel: number = 0;
  @Local sweepX: number = -0.6;
  @Local pulse: number = 1;
  @Local barWidth: number = 0;

  @Monitor('sweepTrigger')
  onSweep(): void {
    this.sweepX = -0.6;
    this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseInOut }, () => {
      this.sweepX = 1.2;
    });
    if (this.comboLevel >= 3) {
      const amp = Math.min(1.6 + this.comboLevel * 0.05, 2.1);
      this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.pulse = amp;
      });
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 170, curve: Curve.EaseIn }, () => {
          this.pulse = 1;
        });
      }, 180);
    }
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row().width('100%').height(this.barHeight).borderRadius(this.barHeight / 2)
        .backgroundColor(this.trackColor.length > 0 ? this.trackColor : C.bgSofter)
      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(this.barHeight * 0.4)
          .margin({ left: 4, right: 4, top: 2 })
          .borderRadius(this.barHeight)
          .backgroundColor('#4DFFFFFF')
        if (this.sweepTrigger > 0) {
          Row()
            .width('45%')
            .height(this.barHeight)
            .linearGradient({
              direction: GradientDirection.Right,
              colors: [['#00FFFFFF', 0], ['#BFFFFFFF', 0.5], ['#00FFFFFF', 1]]
            })
            .translate({ x: `${this.sweepX * 100}%` })
        }
      }
      .width(`${Math.max(0.0001, Math.min(1, this.progress)) * 100}%`)
      .constraintSize({ minWidth: this.progress > 0 ? this.barHeight : 0 })
      .height(this.barHeight)
      .borderRadius(this.barHeight / 2)
      .clip(true)
      .backgroundColor(this.fillColor.length > 0 ? this.fillColor : C.primary)
      .border(this.comboLevel >= 3 ? { width: 2, color: alpha(C.bee, 0.85), radius: this.barHeight / 2 } :
        { width: 0, radius: this.barHeight / 2 })
      .shadow(this.comboLevel >= 3 ? { radius: 6, color: alpha(C.bee, 0.55) } : { radius: 0, color: Color.Transparent })
      .animation({ curve: curves.springMotion(0.4, 0.6) })
    }
    .width('100%')
    .height(this.barHeight)
    .scale({ y: this.pulse })
    .accessibilityText(`课程进度 ${Math.round(Math.min(1, Math.max(0, this.progress)) * 100)}%`)
  }
}


@ComponentV2
export struct SpeechBubble {
  @Param text: string = '';
  @Param mood: MascotMood = 'happy';
  @Local shown: boolean = false;

  private tone(): string {
    const t = bubbleTone(this.mood);
    return t === 'primary' ? C.primary : (t === 'danger' ? C.danger : C.inkLight);
  }

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.3, 0.6) }, () => {
        this.shown = true;
      });
    }, 10);
  }

  build() {
    Text(this.text)
      .fontSize(F.caption)
      .fontWeight(W.bold)
      .fontColor(this.tone())
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(alpha(this.tone(), 0.10))
      .borderRadius(12)
      .border({ width: 1.5, color: alpha(this.tone(), 0.25), radius: 12 })
      .scale({ x: this.shown ? 1 : 0.5, y: this.shown ? 1 : 0.5 })
      .opacity(this.shown ? 1 : 0)
  }
}

/** 半透明遮罩 + 居中卡片（iOS 的各种 overlay 弹窗）。 */
@ComponentV2
export struct ModalCard {
  @BuilderParam content: () => void;
  @Param maxW: number = 340;
  @Event onBackdrop: () => void = () => {
  };

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#8C000000').onClick(() => this.onBackdrop())
      Column({ space: 14 }) {
        this.content()
      }
      .padding(24)
      .width('86%')
      .constraintSize({ maxWidth: this.maxW })
      .backgroundColor(C.surface)
      .borderRadius(R.large)
      .border({ width: 2, color: C.border, radius: R.large })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}

/** 统一的卡片容器（surface + 2vp 描边）。 */
@ComponentV2
export struct CardBox {
  @BuilderParam content: () => void;
  @Param pad: number = 16;
  @Param stroke: string = '';
  @Param fill: string = '';

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .padding(this.pad)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.fill.length > 0 ? this.fill : C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: this.stroke.length > 0 ? this.stroke : C.border, radius: R.card })
  }
}

/** 顶部导航栏（返回 + 标题 + 右侧插槽），替代 iOS NavigationBar。 */
@ComponentV2
export struct TitleBar {
  @Param title: string = '';
  @Param showBack: boolean = true;
  @BuilderParam trailing: () => void = emptyBuilder;
  @Event onBack: () => void = () => {
  };

  build() {
    Row() {
      Row() {
        if (this.showBack) {
          Row() {
            DuoIcon({ name: 'chevronLeft', sz: 22, color: C.inkMuted })
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            Haptics.tap();
            this.onBack();
          })
          .accessibilityText('返回')
        }
      }
      .width(60)

      Text(this.title)
        .fontSize(F.button)
        .fontWeight(W.heavy)
        .fontColor(C.ink)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Row() {
        this.trailing()
      }
      .width(60)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(52)
    .padding({ left: 4, right: 8 })
    .backgroundColor(C.bg)
    .border({ width: { bottom: 1 }, color: C.border })
  }
}

@Builder
export function emptyBuilder() {
}

/** 小标题（section 标签）。 */
@Builder
export function SectionLabel(text: string) {
  Text(text).fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).letterSpacing(1)
}

/** 圆底图标徽章。 */
@Builder
export function IconBadge(icon: string, tint: string, size: number, iconSize: number) {
  Stack() {
    Circle().width(size).height(size).fill(alpha(tint, 0.16))
    DuoIcon({ name: icon, sz: iconSize, color: tint })
  }
  .width(size)
  .height(size)
}

/** 胶囊标签。 */
@Builder
export function Pill(text: string, fg: string, bg: string) {
  Text(text)
    .fontSize(F.micro)
    .fontWeight(W.heavy)
    .fontColor(fg)
    .padding({ left: 9, right: 9, top: 4, bottom: 4 })
    .backgroundColor(bg)
    .borderRadius(999)
}
