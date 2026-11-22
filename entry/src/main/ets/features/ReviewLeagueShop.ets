// 错题本 / 复习做题 / 本地联赛 / 商店（ReviewTab / LeagueView / ShopView）。
import { curves } from '@kit.ArkUI';
import { C, F, R, S, W, alpha } from '../design/Theme';
import { Economy, SRS } from '../domain/Economy';
import { formatCountdown, weekdayLabel } from '../domain/Dates';
import { CosmeticItem, Cosmetics, rarityColor, rarityLabel } from '../domain/Catalog';
import { League, LeagueBot, StandingEntry } from '../domain/Seeded';
import { gradeAnswer, instructionText } from '../domain/Grade';
import { renderMathText } from '../domain/MathText';
import { MistakeEntry, Question } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { DataLoader } from '../services/DataLoader';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { CardBox, ChunkyButton, DuoIcon, IconBadge, ModalCard, Pill, ProgressBar, SmallChunkyButton, TitleBar } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { Confetti } from '../components/Effects';
import { AppRoute, Router } from './Router';
import { QuestionPhase, QuestionRenderer } from './Questions';

/** 错题本 Tab。 */
@ComponentV2
export struct ReviewTab {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  private unsubStore: () => void = () => {
  };

  aboutToDisappear(): void {
    this.unsubStore();
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
  }

  private restEntries(): MistakeEntry[] {
    const dueIds = new Set<string>(this.store.dueMistakes.map((e: MistakeEntry) => `${e.lessonId}#${e.question.id}`));
    return this.store.progress.mistakesBank.filter((e: MistakeEntry) =>
      !dueIds.has(`${e.lessonId}#${e.question.id}`) && !SRS.isGraduated(e));
  }

  /** 备份导入等路径会丢 lessonTitle：按 lessonId 回查课本大纲，查不到才显示原始 ID。 */
  private lessonTitleOf(e: MistakeEntry): string {
    const t = e.lessonTitle;
    if (t !== null && t !== undefined && t.length > 0) {
      return t;
    }
    return DataLoader.lessonTitle(e.lessonId) ?? e.lessonId;
  }

  @Builder
  entryRow(e: MistakeEntry) {
    Row({ space: 12 }) {
      IconBadge('book', SRS.isGraduated(e) ? C.primary : C.fox, 42, 18)
      Column({ space: 3 }) {
        Text(renderMathText(e.question.question)).fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          Text(this.lessonTitleOf(e)).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(1)
          if (SRS.isGraduated(e)) {
            Pill('已掌握', '#FFFFFF', C.primary)
          } else {
            Pill(`第 ${e.box ?? 1} 层`, C.fox, alpha(C.fox, 0.12))
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }

  build() {
    Column() {
      ForEach([this.rev], (r: number) => {
      Column() {
      Row({ space: 10 }) {
        Text('错题本').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
        if (this.store.dueMistakes.length > 0) {
          Pill(`待复习 ${this.store.dueMistakes.length}`, '#FFFFFF', C.fox)
        }
      }
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          if (this.store.progress.mistakesBank.length === 0) {
            Column({ space: 14 }) {
              Mascot({ mood: 'cheer', sz: 120 })
              Text('还没有错题，太棒了！').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
              Text('做错的题会自动收集到这里复习').fontSize(F.caption).fontColor(C.inkMuted)
            }
            .margin({ top: 80 })
          } else {
            if (this.store.dueMistakes.length > 0) {
              Text('今天到期').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
              ForEach(this.store.dueMistakes, (e: MistakeEntry) => {
                this.entryRow(e)
              }, (e: MistakeEntry) => `${e.lessonId}-${e.question.id}-${e.nextReviewDate}`)
            }
            if (this.restEntries().length > 0) {
              Text('稍后复习').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
              ForEach(this.restEntries(), (e: MistakeEntry) => {
                this.entryRow(e)
              }, (e: MistakeEntry) => `${e.lessonId}-${e.question.id}`)
            }
            if (this.store.graduatedMistakes.length > 0) {
              Text('已掌握').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
              ForEach(this.store.graduatedMistakes.slice(0, 30), (e: MistakeEntry) => {
                this.entryRow(e)
              }, (e: MistakeEntry) => `g-${e.lessonId}-${e.question.id}`)
            }
          }
          Blank().height(30)
        }
        .padding({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      if (this.store.dueMistakes.length > 0) {
        ChunkyButton({
          label: `开始复习（${this.store.dueMistakes.length} 题 · 答对 ${Economy.reviewHeartMinCorrect} 题 +1 ❤️）`,
          onTap: () => {
            Haptics.tap();
            Router.shared.push(new AppRoute('reviewRunner'));
          }
        }).padding({ left: 20, right: 20, top: 10, bottom: 16 })
      }
      }
      .width('100%')
      .height('100%')
      }, (r: number) => `${r}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 复习做题：复用答题 UI，但不扣红心，只更新 SRS 箱子。 */
@ComponentV2
export struct ReviewRunner {
  store: ProgressStore = ProgressStore.shared;
  @Local queue: MistakeEntry[] = [];
  @Local index: number = 0;
  @Local answer: string = '';
  @Local phase: QuestionPhase = 'answering';
  @Local isCorrect: boolean = false;
  @Local correct: number = 0;
  @Local done: boolean = false;
  @Local earnedHeart: boolean = false;
  @Local sweep: number = 0;

  aboutToAppear(): void {
    this.queue = this.store.dueMistakes.slice(0, 15);
  }

  private current(): MistakeEntry | undefined {
    return this.index < this.queue.length ? this.queue[this.index] : undefined;
  }

  private next(): void {
    if (this.index + 1 >= this.queue.length) {
      const total = this.correct;
      this.store.awardReviewXP(total * Economy.xpPerCorrect, this.queue.length);
      this.earnedHeart = this.store.claimReviewHeartIfEligible(total);
      this.correct = total;
      SFXEngine.shared.play('complete');
      this.done = true;
      return;
    }
    this.index++;
    this.answer = '';
    this.phase = 'answering';
    this.isCorrect = false;
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Stack() {
          DuoIcon({ name: 'xmark', sz: 20, color: C.inkMuted })
        }
        .width(36)
        .height(36)
        .onClick(() => Router.shared.pop())

        ProgressBar({ progress: (this.index + (this.phase === 'checked' ? 1 : 0)) / Math.max(1, this.queue.length),
          sweepTrigger: this.sweep, barHeight: 16, trackColor: C.surfaceAlt })
          .layoutWeight(1)
        Text(`${this.index + 1}/${this.queue.length}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.inkMuted)
      }
      .padding({ left: 18, right: 18, top: 6, bottom: 10 })

      if (this.done) {
        Column({ space: 14 }) {
          Mascot({ mood: 'proud', sz: 120 })
          Text('复习完成！').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
          Text(`答对 ${this.correct}/${this.queue.length} 题 · +${this.correct * Economy.xpPerCorrect} XP`).fontSize(F.body)
            .fontColor(C.inkMuted)
          if (this.earnedHeart) {
            Row({ space: 6 }) {
              DuoIcon({ name: 'heart', sz: 20, color: C.danger })
              Text('+1 红心').fontSize(F.body).fontWeight(W.heavy).fontColor(C.danger)
            }
          }
          ChunkyButton({ label: '完成', onTap: () => Router.shared.pop() }).width(220)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(24)
      } else if (this.current() !== undefined) {
        ForEach([this.current() as MistakeEntry], (e: MistakeEntry) => {
          this.runner(e)
        }, (e: MistakeEntry) => `${this.index}-${e.question.id}`)
      } else {
        Column() {
          LoadingProgress().width(40).color(C.primary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }

  @Builder
  runner(e: MistakeEntry) {
    Column() {
      Scroll() {
        Column({ space: S.xl }) {
          Text(instructionText(e.question.type)).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink).width('100%')
          Text(renderMathText(e.question.question)).fontSize(F.subhead).fontWeight(W.medium).fontColor(C.inkMuted)
            .lineHeight(26).width('100%')
          QuestionRenderer({
            question: e.question, answer: this.answer, phase: this.phase, isCorrect: this.isCorrect,
            qKey: `r-${e.lessonId}-${e.question.id}-${this.index}`, onAnswer: (a: string) => {
              this.answer = a;
            }
          })
        }
        .padding({ left: 20, right: 20, bottom: 24 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)

      if (this.phase === 'checked') {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            DuoIcon({ name: this.isCorrect ? 'checkCircle' : 'xmarkCircle', sz: 22,
              color: this.isCorrect ? C.primary : C.danger })
            Column() {
              Text(this.isCorrect ? '记住了！' : `正确答案：${renderMathText(e.question.answer)}`)
                .fontSize(F.body).fontWeight(W.bold).fontColor(this.isCorrect ? C.primary : C.danger)
              if (!this.isCorrect && e.question.explanation.length > 0) {
                Text(renderMathText(e.question.explanation)).fontSize(F.micro).fontColor(C.inkMuted).maxLines(3)
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          ChunkyButton({ label: '继续', variant: this.isCorrect ? 'primary' : 'danger', onTap: () => this.next() })
        }
        .padding({ left: 20, right: 20, top: 14, bottom: 28 })
        .backgroundColor(alpha(this.isCorrect ? C.primary : C.danger, 0.10))
      } else {
        ChunkyButton({ label: '检查', variant: this.answer.trim().length === 0 ? 'disabled' : 'primary',
          onTap: () => {
            this.isCorrect = gradeAnswer(e.question, this.answer);
            this.phase = 'checked';
            if (this.isCorrect) {
              this.correct++;
              this.sweep++;
              SFXEngine.shared.play('correct', 0);
              Haptics.correct();
              this.store.reviewMistake(e.lessonId, e.question.id, true);
            } else {
              SFXEngine.shared.play('wrong');
              Haptics.wrong();
              this.store.reviewMistake(e.lessonId, e.question.id, false);
            }
          } })
          .padding({ left: 20, right: 20, top: 14, bottom: 28 })
          .backgroundColor(C.bg)
      }
    }
    .layoutWeight(1)
  }
}

/** 排行榜 Tab（LeagueView）：16 人本地榜，周一结算。 */
@ComponentV2
export struct LeagueTab {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  private unsubStore: () => void = () => {
  };

  aboutToDisappear(): void {
    this.unsubStore();
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
  }

  private standings(): StandingEntry[] {
    const now = new Date();
    const weekKey = League.weekKeyFor(now);
    const salt = this.store.leagueSalt ?? '';
    const myXp = this.store.leagueWeeklyXp(now);
    const botXps: number[] = [];
    for (let i = 0; i < League.botCount; i++) {
      botXps.push(League.botXpAt(weekKey, this.store.leagueTierId, salt, i, now));
    }
    return League.standings(myXp, botXps);
  }

  private botName(entry: StandingEntry): string {
    if (entry.isUser) {
      return this.store.displayName;
    }
    const bots = League.botsForWeek(League.weekKeyFor(), this.store.leagueTierId, this.store.leagueSalt ?? '');
    const bot = bots.find((b: LeagueBot) => b.id.endsWith(`-${entry.botIndex}`));
    return bot !== undefined ? bot.name : '同学';
  }

  @Builder
  row(e: StandingEntry, i: number) {
    Row({ space: 10 }) {
      Text(`${i + 1}`).fontSize(F.body).fontWeight(W.heavy)
        .fontColor(e.isUser ? C.primary : (i < League.promoteZone ? C.primary : (i >= League.groupSize - League.demoteZone ? C.danger : C.inkMuted)))
        .width(26)
      Circle().width(32).height(32).fill(e.isUser ? C.primary : alpha(C.secondary, 0.5))
      Column({ space: 1 }) {
        Text(this.botName(e)).fontSize(F.caption).fontWeight(e.isUser ? W.heavy : W.bold)
          .fontColor(e.isUser ? C.primary : C.ink).maxLines(1)
        if (e.isUser) {
          Text('你').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${e.xp}`).fontSize(F.caption).fontWeight(W.heavy).fontColor(C.ink)
      Text('XP').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
    }
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .width('100%')
    .backgroundColor(e.isUser ? alpha(C.primary, 0.10) : C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: e.isUser ? C.primary : C.border, radius: R.card })
  }

  build() {
    Column() {
      ForEach([this.rev], (r: number) => {
      Column() {
      Row({ space: 10 }) {
        DuoIcon({ name: 'trophy', sz: 26, color: C.bee })
        Column({ space: 1 }) {
          Text(League.tier(this.store.leagueTierId).name).fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink)
          Text('每周一结算 · 前 5 名晋级').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 0 }) {
          Text(`${this.store.leagueWeeklyXp()}`).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.primary)
          Text('本周 XP').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
      }
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      if (!this.store.leagueUnlocked) {
        Column({ space: 12 }) {
          Mascot({ mood: 'think', sz: 110 })
          Text(`完成 ${League.unlockLessons} 节课后解锁排行榜`).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
            .textAlign(TextAlign.Center)
          ProgressBar({ progress: this.store.totalCompletedLessons / League.unlockLessons, barHeight: 12 })
            .width(220)
          Text(`${this.store.totalCompletedLessons}/${League.unlockLessons}`).fontSize(F.caption).fontWeight(W.bold)
            .fontColor(C.inkMuted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.standings(), (e: StandingEntry, i: number) => {
              Column({ space: 4 }) {
                this.row(e, i)
                if (i + 1 === League.promoteZone) {
                  Row({ space: 6 }) {
                    DuoIcon({ name: 'arrowUp', sz: 12, color: C.primary })
                    Text('晋级区').fontSize(F.micro).fontWeight(W.bold).fontColor(C.primary)
                  }
                }
                if (i + 1 === League.groupSize - League.demoteZone) {
                  Row({ space: 6 }) {
                    DuoIcon({ name: 'arrowDown', sz: 12, color: C.danger })
                    Text('降级区').fontSize(F.micro).fontWeight(W.bold).fontColor(C.danger)
                  }
                }
              }
            }, (e: StandingEntry, i: number) => `${e.botIndex}-${i}-${e.xp}`)
            Blank().height(24)
          }
          .padding({ left: 16, right: 16 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
      }
      .width('100%')
      .height('100%')
      }, (r: number) => `${r}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 商店 Tab（ShopView）：回心、护盾、装扮。 */
@ComponentV2
export struct ShopTab {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  private unsubStore: () => void = () => {
  };

  aboutToDisappear(): void {
    this.unsubStore();
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
  }

  @Builder
  goodsRow(icon: string, tint: string, name: string, desc: string, price: string, enabled: boolean,
    onBuy: () => void) {
    Row({ space: 12 }) {
      IconBadge(icon, tint, 46, 22)
      Column({ space: 2 }) {
        Text(name).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        Text(desc).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SmallChunkyButton({ label: price, icon: 'gem', bgColor: enabled ? C.secondary : C.inkSofter,
        shadowColor: enabled ? C.secondaryDark : C.inkMuted, active: enabled, onTap: () => onBuy() }).width(92)
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }

  @Builder
  cosmeticRow(item: CosmeticItem) {
    Row({ space: 12 }) {
      Stack() {
        Circle().width(46).height(46).fill(alpha(rarityColor(item.rarity), 0.15))
          .stroke(rarityColor(item.rarity)).strokeWidth(2)
        DuoIcon({ name: 'sparkles', sz: 20, color: rarityColor(item.rarity) })
      }
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(item.name).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
          Pill(rarityLabel(item.rarity), '#FFFFFF', rarityColor(item.rarity))
        }
        Text(item.type === 'mascot_skin' ? '聪聪装扮' : (item.type === 'ui_theme' ? '界面主题' : '课程背景'))
          .fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.store.isEquipped(item.id)) {
        Pill('使用中', '#FFFFFF', C.primary)
      } else if (this.store.isOwned(item.id)) {
        SmallChunkyButton({ label: '使用', bgColor: C.primary, shadowColor: C.primaryDark,
          onTap: () => {
            this.store.equipCosmetic(item);
            Haptics.tap();
            SFXEngine.shared.play('tap');
          } }).width(80)
      } else {
        SmallChunkyButton({ label: `${item.cost}`, icon: 'gem', bgColor: C.secondary, shadowColor: C.secondaryDark,
          onTap: () => {
            if (this.store.buyCosmetic(item)) {
              Haptics.success();
              SFXEngine.shared.play('purchase');
            } else {
              Haptics.wrong();
            }
          } }).width(80)
      }
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: this.store.isEquipped(item.id) ? C.primary : C.border, radius: R.card })
  }

  build() {
    Column() {
      ForEach([this.rev], (r: number) => {
      Column() {
      Row({ space: 10 }) {
        Text('商店').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
        Row({ space: 4 }) {
          DuoIcon({ name: 'gem', sz: 18, color: C.beetle })
          Text(`${this.store.gems}`).fontSize(F.body).fontWeight(W.heavy).fontColor(C.beetle)
        }
      }
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          Text('补给').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
          this.goodsRow('heart', C.danger, '补满红心', `立刻回满 ${Economy.maxHearts} 颗红心`,
            `${Economy.heartRefillCost}`, this.store.hearts < Economy.maxHearts && this.store.gems >= Economy.heartRefillCost,
            (): void => {
              if (this.store.buyHeartRefill()) {
                Haptics.success();
                SFXEngine.shared.play('purchase');
              } else {
                Haptics.wrong();
              }
            })
          this.goodsRow('snowflake', C.secondary, '连胜护盾', `缺勤时自动保住连胜 · 最多 ${Economy.maxFreezes} 个`,
            `${Economy.freezeCost}`, this.store.streakFreezes < Economy.maxFreezes && this.store.gems >= Economy.freezeCost,
            (): void => {
              if (this.store.buyStreakFreeze()) {
                Haptics.success();
                SFXEngine.shared.play('purchase');
              } else {
                Haptics.wrong();
              }
            })
          this.goodsRow('flame', C.fox, '连胜补卡', '断掉的连胜用宝石救回来',
            `${Economy.streakMakeupCost}`, this.store.canOfferMakeup && this.store.gems >= Economy.streakMakeupCost,
            (): void => {
              if (this.store.makeUpYesterdayStreak()) {
                Haptics.success();
                SFXEngine.shared.play('purchase');
              } else {
                Haptics.wrong();
              }
            })

          Text('装扮').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%').margin({ top: 6 })
          ForEach(Cosmetics.all(), (item: CosmeticItem) => {
            this.cosmeticRow(item)
          }, (item: CosmeticItem) => `${item.id}-${this.store.isOwned(item.id)}-${this.store.isEquipped(item.id)}`)
          Blank().height(24)
        }
        .padding({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      }, (r: number) => `${r}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
