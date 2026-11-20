// 分享卡（ShareCardView.swift）：离屏截图 → PNG → 系统分享面板。
import { image } from '@kit.ImageKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { C, F, W, alpha } from '../design/Theme';
import { weekdayLabel } from '../domain/Dates';
import { AppEnv, Files } from '../services/Files';
import { DuoIcon } from './Kit';
import { Mascot } from './Mascot';
import { CalendarDay } from './Widgets';

const SLOGAN = '每天进步一点点 · 课本学习';

export class BadgeData {
  icon: string;
  tint: string;
  headline: string;
  title: string;
  subtitle: string;

  constructor(icon: string, tint: string, headline: string, title: string, subtitle: string) {
    this.icon = icon;
    this.tint = tint;
    this.headline = headline;
    this.title = title;
    this.subtitle = subtitle;
  }
}

export class StreakShareData {
  streak: number;
  week: CalendarDay[];
  todayIndex: number;

  constructor(streak: number, week: CalendarDay[], todayIndex: number) {
    this.streak = streak;
    this.week = week;
    this.todayIndex = todayIndex;
  }
}

/** 「分享」胶囊按钮：点击时渲染卡片并调起系统分享。 */
@ComponentV2
export struct ShareCardButton {
  @Param label: string = '分享';
  @Param filename: string = 'share';
  @Param badge: BadgeData | undefined = undefined;
  @Param streak: StreakShareData | undefined = undefined;
  @Local busy: boolean = false;

  @Builder
  streakCard() {
    Column({ space: 14 }) {
      Mascot({ mood: 'cheer', sz: 96, still: true }).margin({ top: 26 })
      Row({ space: 8 }) {
        DuoIcon({ name: 'flame', sz: 52, color: C.bee })
        Text(`${this.streak?.streak ?? 0}`).fontSize(88).fontWeight(W.black).fontColor('#FFFFFF')
      }

      Text('天连胜！').fontSize(26).fontWeight(W.heavy).fontColor('#FFFFFF')
      Row({ space: 8 }) {
        ForEach(this.streak?.week ?? [], (d: CalendarDay, i: number) => {
          Column({ space: 5 }) {
            Text(i === (this.streak?.todayIndex ?? -1) ? '今' : weekdayLabel(d.dateKey)).fontSize(11).fontWeight(W.heavy)
              .fontColor('#D9FFFFFF')
            Stack() {
              Circle().width(30).height(30).fill(d.studied ? C.bee : '#38FFFFFF')
              if (d.studied) {
                DuoIcon({ name: 'flame', sz: 13, color: '#FFFFFF' })
              }
            }
          }
        }, (d: CalendarDay, i: number) => `${i}`)
      }
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor('#1FFFFFFF')
      .borderRadius(16)

      Blank()
      Text(SLOGAN).fontSize(14).fontWeight(W.heavy).fontColor('#E6FFFFFF').margin({ bottom: 22 })
    }
    .width(360)
    .height(480)
    .padding({ left: 24, right: 24 })
    .linearGradient({ direction: GradientDirection.Bottom, colors: [[C.feather, 0], [C.treeFrog, 1]] })
  }

  @Builder
  badgeCard() {
    Column({ space: 16 }) {
      Mascot({ mood: 'proud', sz: 84, still: true }).margin({ top: 26 })
      Stack() {
        Circle().width(116).height(116).fill(alpha(this.badge?.tint ?? C.bee, 0.22)).stroke(this.badge?.tint ?? C.bee)
          .strokeWidth(4)
        DuoIcon({ name: this.badge?.icon ?? 'star', sz: 52, color: this.badge?.tint ?? C.bee })
      }

      Text(this.badge?.headline ?? '').fontSize(26).fontWeight(W.black).fontColor('#FFFFFF')
      Text(this.badge?.title ?? '').fontSize(18).fontWeight(W.heavy).fontColor(this.badge?.tint ?? C.bee).maxLines(2)
        .textAlign(TextAlign.Center).padding({ left: 28, right: 28 })
      Text(this.badge?.subtitle ?? '').fontSize(14).fontWeight(W.bold).fontColor('#BFFFFFFF').maxLines(2)
        .textAlign(TextAlign.Center).padding({ left: 28, right: 28 })
      Blank()
      Text(SLOGAN).fontSize(14).fontWeight(W.heavy).fontColor('#CCFFFFFF').margin({ bottom: 22 })
    }
    .width(360)
    .height(480)
    .padding({ left: 24, right: 24 })
    .linearGradient({ direction: GradientDirection.Bottom, colors: [['#131F24', 0], ['#202F36', 1]] })
  }

  private async share(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    try {
      const snap = this.getUIContext().getComponentSnapshot();
      const pixel: image.PixelMap = this.streak !== undefined ?
        await snap.createFromBuilder(() => {
          this.streakCard();
        }, 320) :
        await snap.createFromBuilder(() => {
          this.badgeCard();
        }, 320);
      const packer = image.createImagePacker();
      const data = await packer.packToData(pixel, { format: 'image/png', quality: 100 });
      packer.release();
      const path = `${AppEnv.cacheDir()}/${this.filename}.png`;
      Files.writeBytes(path, data);
      const shared = new systemShare.SharedData({
        utd: utd.UniformDataType.PNG,
        uri: fileUri.getUriFromPath(path),
        title: this.label
      });
      const controller = new systemShare.ShareController(shared);
      await controller.show(AppEnv.ctx(), {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE
      });
    } catch (e) {
      console.warn(`[ShareCard] share failed ${JSON.stringify(e)}`);
    } finally {
      this.busy = false;
    }
  }

  build() {
    Row({ space: 6 }) {
      DuoIcon({ name: 'share', sz: 14, color: C.primary })
      Text(this.label).fontSize(F.caption).fontWeight(W.bold).fontColor(C.primary)
    }
    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
    .backgroundColor(alpha(C.primary, 0.12))
    .borderRadius(999)
    .border({ width: 2, color: alpha(C.primary, 0.4), radius: 999 })
    .onClick(() => {
      this.share();
    })
  }
}
