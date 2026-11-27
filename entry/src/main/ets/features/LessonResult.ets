// 课程结算页（LessonResultView.swift）：星级、XP/宝石、连胜推进、成就解锁、宝箱可领提示。
import { curves } from '@kit.ArkUI';
import { C, F, R, S, W, alpha } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { Achievement, Achievements, Chest, ChestSlot, pathLessonMetas } from '../domain/Catalog';
import { DataLoader } from '../services/DataLoader';
import { isoString, weekdayLabel } from '../domain/Dates';
import { LessonRunResult } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { ChunkyButton, DuoIcon } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { Confetti, StarReveal } from '../components/Effects';
import { BadgeData, ShareCardButton } from '../components/ShareCard';
import { CardTier, Remedy } from '../domain/KidsMode';
import { CardReveal } from './Cards';
import { AppRoute, Router } from './Router';

@ComponentV2
export struct LessonResultPage {
  @Param route: AppRoute = new AppRoute('lessonResult');
  store: ProgressStore = ProgressStore.shared;
  @Local earnedBadges: Achievement[] = [];
  @Local chestAvailable: string = '';
  @Local show: boolean = false;

  private get result(): LessonRunResult | null {
    return this.route.result;
  }

  aboutToAppear(): void {
    SFXEngine.shared.play('complete');
    const r = this.result;
    if (r === null) {
      return;
    }
    this.earnedBadges = Achievements.all.filter((a: Achievement) => r.outcome.newAchievementIds.includes(a.id));
    const outline = DataLoader.tryOutline(r.bookId);
    if (outline !== null) {
      const slot = Chest.chestAfter(r.bookId, pathLessonMetas(outline, r.bookId), r.lessonId);
      if (slot !== undefined && !this.store.isChestClaimed(slot.id)) {
        this.chestAvailable = slot.id;
      }
    }
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.7) }, () => {
        this.show = true;
      });
    }, 30);
  }

  private acc(): number {
    const r = this.result;
    if (r === null) {
      return 0;
    }
    return r.correctCount / Math.max(1, r.questionCount);
  }

  @Builder
  stat(icon: string, tint: string, value: string, label: string) {
    Column({ space: 4 }) {
      DuoIcon({ name: icon, sz: 20, color: tint })
      Text(value).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text(label).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
    }
    .layoutWeight(1)
  }

  /** 儿童模式：宝箱封存提示 + 去收服心魔。 */
  @Builder
  sealedBox() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        DuoIcon({ name: 'chest', sz: 34, color: C.inkSofter })
        Column({ space: 2 }) {
          Text('宝箱被心魔封住了').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink)
          Text(`👾 ${this.result?.outcome.demonCount ?? 0} 只心魔待收服`).fontSize(F.caption).fontWeight(W.bold)
            .fontColor(C.fox)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      Text(`收服后返还 ${this.result?.outcome.sealedGems ?? 0} 宝石` +
        `${(this.result?.outcome.cardTier ?? 0) > 0 ? ` + ${CardTier.label(this.result?.outcome.cardTier ?? 1)}「${this.result?.lessonTitle ?? ''}」` : ''}` +
        `，每只心魔再奖 ${Remedy.bonusGemsPerDemon} 宝石。经验已经到账啦！`)
        .fontSize(F.caption).fontColor(C.inkMuted).lineHeight(19)
      ChunkyButton({ label: '去收服心魔', variant: 'secondary', icon: 'sparkles', onTap: () => {
        Haptics.tap();
        Router.shared.replaceTop(AppRoute.remedy(this.result?.outcome.sealedChestId ?? ''));
      } })
    }
    .padding(16)
    .margin({ left: 20, right: 20 })
    .backgroundColor(alpha(C.fox, 0.08))
    .borderRadius(R.card)
    .border({ width: 2, color: alpha(C.fox, 0.35), radius: R.card })
  }

  build() {
    Stack() {
      Column({ space: 0 }) {
        Scroll() {
          Column({ space: S.xl }) {
            Column({ space: 10 }) {
              Mascot({ mood: this.acc() >= 0.8 ? 'cheer' : 'happy', sz: 130, reactTo: 'levelup' })
              StarReveal({ earned: this.result?.outcome.stars ?? 1 })
              Text(this.result?.lessonTitle ?? '').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.inkMuted)
            }
            .margin({ top: 24 })

            Row({ space: 6 }) {
              this.stat('bolt', C.secondary, `+${this.result?.outcome.xpGained ?? 0}`, '经验')
              this.stat('gem', C.beetle, `+${(this.result?.outcome.gemsGained ?? 0) + (this.result?.outcome.milestoneGems ?? 0)}`,
                '宝石')
              this.stat('target', C.primary, `${Math.round(this.acc() * 100)}%`, '正确率')
              this.stat('flame', C.fox, `${this.result?.outcome.streakAfter ?? 0}`, '连胜')
            }
            .padding({ left: 20, right: 20 })

            if ((this.result?.outcome.sealedChestId ?? '').length > 0) {
              this.sealedBox()
            } else if ((this.result?.outcome.cardNew ?? false) || (this.result?.outcome.cardUpgraded ?? false)) {
              Column({ space: 8 }) {
                Text(this.result?.outcome.cardNew ? '获得知识卡！' : '知识卡升级！').fontSize(F.subhead).fontWeight(W.heavy)
                  .fontColor(C.ink)
                CardReveal({
                  title: this.result?.lessonTitle ?? '', caption: '已收进知识卡册',
                  tier: this.result?.outcome.cardTier ?? 1, badge: this.result?.outcome.cardNew ? 'NEW' : '升级'
                })
              }
            } else if ((this.result?.outcome.cardTier ?? 0) > 0) {
              Text(`这张知识卡已收藏（${CardTier.label(this.store.cardTier(this.result?.lessonId ?? ''))}）`)
                .fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
            }

            if ((this.result?.outcome.bonusXp ?? 0) > 0) {
              Text(`⚡ 神速挑战成功 · 额外 +${this.result?.outcome.bonusXp} XP`)
                .fontSize(F.caption).fontWeight(W.heavy).fontColor(C.fox)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(alpha(C.fox, 0.14))
                .borderRadius(999)
            }

            if ((this.result?.outcome.weekendDoubled ?? false) || (this.result?.outcome.examDoubled ?? false)) {
              Text(this.result?.outcome.examDoubled ? '⚔️ 单元挑战 · 双倍 XP 生效' : '⚡ 周末双倍 XP 生效')
                .fontSize(F.caption).fontWeight(W.heavy).fontColor(C.bee)
                .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                .backgroundColor(alpha(C.bee, 0.16))
                .borderRadius(999)
            }

            if ((this.result?.outcome.milestoneGems ?? 0) > 0) {
              Row({ space: 8 }) {
                DuoIcon({ name: 'flame', sz: 18, color: C.fox })
                Text(`连胜 ${this.result?.outcome.streakAfter} 天里程碑 +${this.result?.outcome.milestoneGems} 宝石`)
                  .fontSize(F.caption).fontWeight(W.bold).fontColor(C.fox)
              }
            }

            if ((this.result?.outcome.freezesConsumed ?? 0) > 0) {
              Row({ space: 8 }) {
                DuoIcon({ name: 'snowflake', sz: 18, color: C.secondary })
                Text(`护盾自动补上了 ${this.result?.outcome.freezesConsumed} 天的缺席`).fontSize(F.caption).fontWeight(W.bold)
                  .fontColor(C.secondary)
              }
            }

            if (this.earnedBadges.length > 0) {
              Column({ space: 8 }) {
                Text('解锁成就').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted)
                ForEach(this.earnedBadges, (a: Achievement) => {
                  Row({ space: 10 }) {
                    DuoIcon({ name: a.icon, sz: 20, color: C.bee })
                    Text(a.name).fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
                    Text(`+${a.reward}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.beetle)
                    DuoIcon({ name: 'gem', sz: 12, color: C.beetle })
                  }
                  .padding(14)
                  .width('100%')
                  .backgroundColor(alpha(C.bee, 0.10))
                  .borderRadius(R.card)
                  .border({ width: 2, color: alpha(C.bee, 0.4), radius: R.card })
                }, (a: Achievement) => a.id)
              }
              .padding({ left: 20, right: 20 })
            }

            if (this.chestAvailable.length > 0) {
              Row({ space: 10 }) {
                DuoIcon({ name: 'chest', sz: 22, color: C.bee })
                Text('路径上的宝箱已解锁，回去领取吧！').fontSize(F.caption).fontWeight(W.bold).fontColor(C.bee)
              }
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .backgroundColor(alpha(C.bee, 0.12))
              .borderRadius(999)
            }
          }
        }
        .layoutWeight(1)
        .align(Alignment.Top)

        Column({ space: 12 }) {
          ShareCardButton({
            label: '分享成绩', filename: `result-${this.result?.lessonId ?? 'x'}`,
            badge: new BadgeData('star', C.bee, '又过一课！', this.result?.lessonTitle ?? '',
              `${this.result?.outcome.stars ?? 0} 星 · ${Math.round(this.acc() * 100)}% 正确率`)
          })
          ChunkyButton({ label: '继续', onTap: () => {
            Haptics.tap();
            SFXEngine.shared.play('tap');
            Router.shared.clear();
          } })
        }
        .padding({ left: 20, right: 20, top: 12, bottom: 28 })
        .backgroundColor(C.bg)
        .border({ width: { top: 1 }, color: C.border })
      }
      .width('100%')
      .height('100%')
      .opacity(this.show ? 1 : 0)

      if ((this.result?.outcome.stars ?? 0) >= 3) {
        Confetti({ active: this.show, burstMs: 1400 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
