// 错题本 / 复习做题 / 本地联赛 / 商店（ReviewTab / LeagueView / ShopView）。
import { curves } from '@kit.ArkUI';
import { C, F, R, S, W, alpha } from '../design/Theme';
import { Economy, SRS } from '../domain/Economy';
import { formatCountdown, weekdayLabel } from '../domain/Dates';
import { CosmeticItem, Cosmetics, rarityColor, rarityLabel } from '../domain/Catalog';
import { League, LeagueBot, StandingEntry } from '../domain/Seeded';
import { gradeAnswer, instructionText } from '../domain/Grade';
import { renderMathText } from '../domain/MathText';
import { DemonState, MistakeEntry, Question, SealedChest } from '../models/Types';
import { CardTier, Remedy } from '../domain/KidsMode';
import { ProgressStore } from '../stores/ProgressStore';
import { SettingsStore } from '../stores/SettingsStore';
import { DataLoader } from '../services/DataLoader';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { CardBox, ChunkyButton, DuoIcon, IconBadge, ModalCard, Pill, ProgressBar, SmallChunkyButton, TabHeader,
  TitleBar } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { Confetti } from '../components/Effects';
import { AppRoute, Router } from './Router';
import { QuestionPhase, QuestionRenderer, stemFontSize } from './Questions';

/** 错题本 Tab。 */
@ComponentV2
export struct ReviewTab {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;
  @Local collapsed: boolean = false;
  private scroller: Scroller = new Scroller();

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
  chestRow(c: SealedChest) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column({ space: 5 }) {
          Pill('封存宝箱', C.ink, alpha(C.bee, 0.28))
          Text(`${c.demons.filter((d: DemonState) => !Remedy.isSubdued(d)).length} 只心魔待收服`)
            .fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
          Text(c.lessonTitle).fontSize(F.caption).fontColor(C.inkMuted)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image($r('app.media.learning_chest')).width(94).height(84).objectFit(ImageFit.Contain)
          .accessibilityLevel('no')
      }
      .width('100%')
      Divider().color(C.rewardBorder)
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Row({ space: 4 }) {
            DuoIcon({ name: 'gem', sz: 15, color: C.beetle })
            Text(`${c.gems} 宝石` + (c.cardTier > 0 ? ` · 1 张${CardTier.label(c.cardTier)}` : ''))
              .fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink)
          }
          Text(`保留到 ${c.expiresOn.substring(5)}`).fontSize(F.micro).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        SmallChunkyButton({ label: '去收服', bgColor: C.primary, shadowColor: C.primaryDark, onTap: () => {
          Haptics.tap();
          Router.shared.push(AppRoute.remedy(c.id));
        } }).width(80)
      }
      .width('100%')
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.rewardSurface)
    .borderRadius(R.card)
    .border({ width: 1.5, color: C.rewardBorder, radius: R.card })
  }

  @Builder
  entryRow(e: MistakeEntry) {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        DuoIcon({ name: 'book', sz: 15, color: C.inkMuted })
        Text(this.lessonTitleOf(e)).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
          .layoutWeight(1).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        if (SRS.isGraduated(e)) {
          Pill('已掌握', C.ink, alpha(C.primary, 0.18))
        } else {
          Pill(`第 ${e.box ?? 1} 层`, C.ink, alpha(C.fox, 0.15))
        }
      }
      .width('100%')
      Text(renderMathText(e.question.question)).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 1, color: C.border, radius: R.card })
  }

  build() {
    Column() {
      ForEach([this.rev], (r: number) => {
      Column() {
      TabHeader({ title: '错题本', collapsed: this.collapsed }) {
        if (this.store.dueMistakes.length > 0) {
          Pill(`待复习 ${this.store.dueMistakes.length}`, C.fox, alpha(C.fox, 0.14))
        }
      }

      Scroll(this.scroller) {
        Column({ space: 12 }) {
          if (this.store.sealedChests.length > 0) {
            Text('心魔录').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).width('100%')
            ForEach(this.store.sealedChests, (c: SealedChest) => {
              this.chestRow(c)
            }, (c: SealedChest) => `${c.id}-${c.demons.filter((d: DemonState) => Remedy.isSubdued(d)).length}`)
          }
          if (this.store.progress.mistakesBank.length === 0 && this.store.sealedChests.length === 0) {
            Column({ space: 14 }) {
              Mascot({ mood: 'cheer', sz: 150, illustrated: true })
              Text('还没有错题，太棒了！').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
              Text('做错的题会自动收集到这里复习').fontSize(F.caption).fontColor(C.inkMuted)
            }
            .margin({ top: 80 })
          } else if (this.store.progress.mistakesBank.length > 0) {
            if (this.store.dueMistakes.length > 0) {
              Text('今天到期').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).width('100%')
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
        .width('100%')
        .padding({ left: 18, right: 18, top: 4 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .onDidScroll(() => {
        this.collapsed = this.scroller.currentOffset().yOffset > 12;
      })

      if (this.store.dueMistakes.length > 0) {
        if (!SettingsStore.shared.kidsMode) {
          Text(`答对 ${Economy.reviewHeartMinCorrect} 题奖励 1 颗红心`).fontSize(F.caption).fontWeight(W.bold)
            .fontColor(C.inkMuted).margin({ top: 8 })
        }
        ChunkyButton({
          label: `开始复习（${this.store.dueMistakes.length} 题）`,
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
  private autoTimer: number = -1;

  aboutToAppear(): void {
    this.queue = this.store.dueMistakes.slice(0, 15);
  }

  aboutToDisappear(): void {
    this.cancelAutoAdvance();
  }

  /** 与课程页一致：答对后约 1.2s 自动下一题，「继续」可提前跳。 */
  private scheduleAutoAdvance(): void {
    this.cancelAutoAdvance();
    const idx = this.index;
    this.autoTimer = setTimeout(() => {
      this.autoTimer = -1;
      if (this.index === idx && this.phase === 'checked' && this.isCorrect && !this.done) {
        this.next();
      }
    }, 1200);
  }

  private cancelAutoAdvance(): void {
    if (this.autoTimer !== -1) {
      clearTimeout(this.autoTimer);
      this.autoTimer = -1;
    }
  }

  private current(): MistakeEntry | undefined {
    return this.index < this.queue.length ? this.queue[this.index] : undefined;
  }

  private next(): void {
    this.cancelAutoAdvance();
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
        .responseRegion({ x: '-20%', y: '-20%', width: '140%', height: '140%' })
        .onClick(() => Router.shared.pop())
        .accessibilityText('关闭')

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
          Column({ space: S.m }) {
            Text(instructionText(e.question.type)).fontSize(F.subhead).fontWeight(W.bold).fontColor(C.inkMuted)
              .width('100%')
            Text(renderMathText(e.question.question)).fontSize(stemFontSize(e.question.question)).fontWeight(W.bold)
              .fontColor(C.ink).lineHeight(stemFontSize(e.question.question) * 1.4).width('100%')
          }
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
              this.scheduleAutoAdvance();
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
  @Local collapsed: boolean = false;
  private scroller: Scroller = new Scroller();

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
      TabHeader({ title: '排行', collapsed: this.collapsed })
      Row({ space: 10 }) {
        Stack() {
          DuoIcon({ name: 'trophy', sz: 26, color: C.fox })
        }
        .width(42).height(44).borderRadius(R.control).backgroundColor(alpha(C.bee, 0.25))
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
      .padding(14)
      .backgroundColor(C.rewardSurface)
      .border({ width: 1.5, color: C.rewardBorder, radius: R.card })
      .borderRadius(R.card)
      .margin({ left: 18, right: 18, top: 2, bottom: 12 })

      if (!this.store.leagueUnlocked) {
        Column({ space: 12 }) {
          Stack({ alignContent: Alignment.BottomEnd }) {
            Mascot({ mood: 'think', sz: 154, illustrated: true })
            IconBadge('lock', C.inkMuted, 30, 15)
          }
          Text(`完成 ${League.unlockLessons} 节课后解锁排行榜`).fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink)
            .textAlign(TextAlign.Center)
          ProgressBar({ progress: this.store.totalCompletedLessons / League.unlockLessons, barHeight: 10 })
            .width(214)
          Text(`${this.store.totalCompletedLessons}/${League.unlockLessons}`).fontSize(F.caption).fontWeight(W.bold)
            .fontColor(C.inkMuted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll(this.scroller) {
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
        .onDidScroll(() => {
          this.collapsed = this.scroller.currentOffset().yOffset > 12;
        })
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
  @Local collapsed: boolean = false;
  private scroller: Scroller = new Scroller();

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
      Stack() {
        DuoIcon({ name: icon, sz: 21, color: tint })
      }
      .width(42).height(42).borderRadius(R.control).backgroundColor(alpha(tint, 0.15))
      Column({ space: 2 }) {
        Text(name).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        Text(desc).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SmallChunkyButton({ label: price, icon: 'gem', bgColor: enabled ? C.primary : C.inkMuted,
        shadowColor: enabled ? C.primaryDark : C.inkSofter, active: enabled, onTap: () => onBuy() }).width(77)
    }
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 1, color: C.border, radius: R.card })
  }

  @Builder
  cosmeticRow(item: CosmeticItem) {
    Row({ space: 12 }) {
      Stack() {
        if (item.type === 'mascot_skin') {
          Mascot({ mood: 'happy', sz: 38, still: true, illustrated: true, skin: item.id })
        } else {
          DuoIcon({ name: item.type === 'ui_theme' ? 'sparkles' : 'book', sz: 20, color: rarityColor(item.rarity) })
        }
      }
      .width(42).height(42).borderRadius(R.control)
      .backgroundColor(alpha(item.type === 'mascot_skin' ? C.primary : rarityColor(item.rarity), 0.12))
      Column({ space: 2 }) {
        Text(item.name).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        Text((item.type === 'mascot_skin' ? '聪聪装扮' : (item.type === 'ui_theme' ? '界面主题' : '课程背景')) +
          ` · ${rarityLabel(item.rarity)}`)
          .fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.store.isEquipped(item.id)) {
        Pill('使用中', C.ink, alpha(C.primary, 0.18))
      } else if (this.store.isOwned(item.id)) {
        SmallChunkyButton({ label: '使用', bgColor: C.primary, shadowColor: C.primaryDark,
          onTap: () => {
            this.store.equipCosmetic(item);
            Haptics.tap();
            SFXEngine.shared.play('tap');
          } }).width(80)
      } else {
        SmallChunkyButton({ label: `${item.cost}`, icon: 'gem',
          active: this.store.gems >= item.cost,
          bgColor: this.store.gems >= item.cost ? C.primary : C.inkMuted,
          shadowColor: this.store.gems >= item.cost ? C.primaryDark : C.inkSofter,
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
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 1, color: this.store.isEquipped(item.id) ? C.primary : C.border, radius: R.card })
  }

  build() {
    Column() {
      ForEach([this.rev], (r: number) => {
      Column() {
      TabHeader({ title: '商店', collapsed: this.collapsed }) {
        Row({ space: 4 }) {
          DuoIcon({ name: 'gem', sz: 18, color: C.beetle })
          Text(`${this.store.gems}`).fontSize(F.body).fontWeight(W.heavy).fontColor(C.beetle)
        }
        .padding({ left: 11, right: 11, top: 5, bottom: 5 })
        .borderRadius(R.control).backgroundColor(alpha(C.beetle, 0.13))
        .accessibilityGroup(true)
        .accessibilityText(`${this.store.gems} 宝石`)
      }

      Scroll(this.scroller) {
        Column({ space: 9 }) {
          Text('补给').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).width('100%')
          if (!SettingsStore.shared.kidsMode) {
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
          }
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

          Text('装扮').fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink).width('100%').margin({ top: 6 })
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
      .onDidScroll(() => {
        this.collapsed = this.scroller.currentOffset().yOffset > 12;
      })
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
