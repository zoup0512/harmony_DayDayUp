// 我的 / 成就 / 设置（ProfileView / AchievementsView / SettingsView）。
import { C, F, R, S, W, alpha } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { Achievement, Achievements, Cosmetics } from '../domain/Catalog';
import { daysBetween, todayString } from '../domain/Dates';
import { AppAppearance, SettingsStore, appearanceLabel } from '../stores/SettingsStore';
import { ProgressStore } from '../stores/ProgressStore';
import { AssetDownloader } from '../services/AssetDownloader';
import { DataLoader } from '../services/DataLoader';
import { SFXEngine, AudioPlayer } from '../services/Audio';
import { Haptics, StreakReminders, ReminderContext } from '../services/Feedback';
import { Files, AppEnv } from '../services/Files';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { BackupEnvelope, validateAnyBackup } from '../domain/Backup';
import { LearnerStore, LEARNER_NAME_MAX } from '../stores/LearnerStore';
import { ParentLock } from '../services/ParentLock';
import { Family } from '../services/Family';
import { ImportPlanDialog, ParentGate } from './Family';
import {
  BadgeData, ShareCardButton, StreakShareData
} from '../components/ShareCard';
import {
  CardBox, ChunkyButton, DuoIcon, IconBadge, ModalCard, Pill, SmallChunkyButton, TitleBar
} from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { DailyGoalRing, DailyQuestsCard, StreakCalendar, weekCalendar } from '../components/Widgets';
import { AppRoute, Router } from './Router';

/** 设置行：label + @BuilderParam 控件插槽。 */
@ComponentV2
struct SettingRow {
  @Param title: string = '';
  @Param subtitle: string = '';
  @BuilderParam control: () => void;

  build() {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Text(this.title).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
        Text(this.subtitle).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      this.control()
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({ width: 2, color: C.border, radius: R.card })
  }
}

/** 「我的」Tab：连胜日历、每日目标与任务、成就、知识卡册、设置。 */
@ComponentV2
export struct ProfileTab {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;
  @Local editingName: boolean = false;
  @Local nameDraft: string = '';

  @Builder
  nameDialog() {
    ModalCard({ onBackdrop: () => {
      this.editingName = false;
    } }) {
      Mascot({ mood: 'happy', sz: 72 })
      Text('给自己起个名字').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      TextInput({ text: this.nameDraft, placeholder: '昵称' })
        .maxLength(LEARNER_NAME_MAX)
        .fontSize(F.subhead)
        .fontColor(C.ink)
        .textAlign(TextAlign.Center)
        .backgroundColor(C.surfaceAlt)
        .borderRadius(R.card)
        .height(54)
        .defaultFocus(true)
        .onChange((v: string) => {
          this.nameDraft = v;
        })
      ChunkyButton({ label: '保存', variant: this.nameDraft.trim().length === 0 ? 'disabled' : 'primary',
        onTap: () => {
          const name = this.nameDraft.trim();
          if (name.length > 0) {
            this.store.setDisplayName(name);
            Haptics.success();
          }
          this.editingName = false;
        } })
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => {
        this.editingName = false;
      } })
    }
  }

  private unsubStore: () => void = () => {
  };
  private unsubLearners: () => void = () => {
  };

  aboutToDisappear(): void {
    this.unsubStore();
    this.unsubLearners();
  }

  aboutToAppear(): void {
    this.unsubStore = this.store.onChange(() => {
      this.rev++;
    });
    // 增删 / 改名其他孩子不会触发进度变化，孩子数与昵称要单独跟随档案注册表
    this.unsubLearners = LearnerStore.shared.onChange(() => {
      this.rev++;
    });
  }

  @Builder
  stat(icon: string, tint: string, value: string, label: string) {
    Column({ space: 4 }) {
      DuoIcon({ name: icon, sz: 18, color: tint })
      Text(value).fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink)
      Text(label).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
    }
    .layoutWeight(1)
    .padding({ top: 8, bottom: 8 })
    .backgroundColor(alpha(tint, C.dark ? 0.2 : 0.14))
    .borderRadius(R.control)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  profileContents() {
    Row({ space: 8 }) {
      Mascot({ mood: 'happy', sz: 70, allowsTap: true, illustrated: true })
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(this.store.displayName).fontSize(F.subhead).fontWeight(W.heavy).fontColor(C.ink)
            .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
          DuoIcon({ name: 'pencil', sz: 15, color: C.inkSofter })
        }
        .onClick(() => {
          Haptics.tap();
          this.nameDraft = this.store.displayName;
          this.editingName = true;
        })
        .accessibilityText('修改昵称')
        Text(`加入 ${Math.max(1, daysBetween(this.store.joinedDate, todayString()) + 1)} 天`).fontSize(F.caption).fontWeight(W.bold)
          .fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      ShareCardButton({
        label: '分享连胜', filename: 'streak',
        streak: new StreakShareData(this.store.displayStreak,
          weekCalendar(this.store.weekXPEntries()), this.store.todayIndexInWeek())
      })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .linearGradient({ angle: 110, colors: [[alpha(C.primary, 0.08), 0], [alpha(C.primary, 0.21), 1]] })
    .borderRadius(R.large)
    .border({ width: 1, color: alpha(C.primary, 0.3) })

    CardBox() {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          DuoIcon({ name: 'flame', sz: 17, color: C.fox })
          Text(`${this.store.displayStreak} 天连胜`).fontSize(F.subhead).fontWeight(W.heavy)
            .fontColor(C.ink).layoutWeight(1)
          if (this.store.streakFreezes > 0) {
            Pill(`护盾 ×${this.store.streakFreezes}`, '#FFFFFF', C.secondary)
          }
        }
        .width('100%')

        StreakCalendar({
          entries: weekCalendar(this.store.weekXPEntries()),
          todayIndex: this.store.todayIndexInWeek(),
          todayStudied: this.store.studiedToday
        })
      }
      .width('100%')
    }

    Row({ space: 6 }) {
      this.stat('bolt', C.secondary, `${this.store.progress.xp}`, '总经验')
      this.stat('gem', C.beetle, `${this.store.gems}`, '宝石')
      this.stat('checkCircle', C.primary, `${this.store.totalCompletedLessons}`, '完成课')
      this.stat('star', C.bee, `${this.store.perfectedLessonCount}`, '满星课')
    }
    .width('100%')

    CardBox({ pad: 12 }) {
      DailyGoalRing({ sz: 49, captionMode: 'full' })
    }

    DailyQuestsCard()

    CardBox() {
      Row({ space: 12 }) {
        IconBadge('rosette', C.bee, 44, 20)
        Column({ space: 2 }) {
          Text('成就').fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
          Text(`${this.store.unlockedAchievementIds.size} / ${Achievements.all.length} 解锁` +
            (this.store.claimableAchievementCount > 0 ?
              ` · ${this.store.claimableAchievementCount} 可领取` : ''))
            .fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
      }
      .width('100%')
      .onClick(() => {
        Haptics.tap();
        Router.shared.push(new AppRoute('achievements'));
      })
    }

    CardBox() {
      Row({ space: 12 }) {
        IconBadge('sparkles', C.secondary, 44, 20)
        Column({ space: 2 }) {
          Text('知识卡册').fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
          Text(`已收集 ${this.store.knowledgeCardCount} 张 · 集齐单元召唤守护兽`).fontSize(F.micro)
            .fontWeight(W.bold).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
      }
      .width('100%')
      .onClick(() => {
        Haptics.tap();
        Router.shared.push(new AppRoute('cards'));
      })
    }

    CardBox() {
      Row({ space: 12 }) {
        IconBadge('person', C.primary, 44, 20)
        Column({ space: 2 }) {
          Text('孩子档案').fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
          Text(`${LearnerStore.shared.count} 个孩子 · 添加、切换、家长密码`).fontSize(F.micro).fontWeight(W.bold)
            .fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
      }
      .width('100%')
      .onClick(() => {
        Haptics.tap();
        Router.shared.push(new AppRoute('learners'));
      })
    }

    CardBox() {
      Row({ space: 12 }) {
        IconBadge('list', C.secondary, 44, 20)
        Column({ space: 2 }) {
          Text('家长总览').fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
          Text('每个孩子的今日学习、复习和每日目标').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
      }
      .width('100%')
      .onClick(() => {
        Haptics.tap();
        Router.shared.push(new AppRoute('parent'));
      })
    }

    CardBox() {
      Row({ space: 12 }) {
        IconBadge('gear', C.inkMuted, 44, 20)
        Column({ space: 2 }) {
          Text('设置').fontSize(F.body).fontWeight(W.bold).fontColor(C.ink)
          Text('声音、触感、外观、提醒、存档').fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        DuoIcon({ name: 'chevronRight', sz: 18, color: C.inkSofter })
      }
      .width('100%')
      .onClick(() => {
        Haptics.tap();
        Router.shared.push(new AppRoute('settings'));
      })
    }
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          ForEach([this.rev], (r: number) => {
            Column({ space: 14 }) {
              this.profileContents()
            }
            .width('100%')
          }, (r: number) => `${r}`)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .backgroundColor(C.bg)

      if (this.editingName) {
        this.nameDialog()
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 成就页：家庭分组，解锁 ≠ 领取（领奖才发宝石）。 */
@ComponentV2
export struct AchievementsPage {
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
  row(a: Achievement) {
    Row({ space: 12 }) {
      IconBadge(a.icon, this.store.unlockedAchievementIds.has(a.id) ? C.bee : C.inkSofter, 44, 20)
      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(a.name).fontSize(F.body).fontWeight(W.bold)
            .fontColor(this.store.unlockedAchievementIds.has(a.id) ? C.ink : C.inkMuted)
          if (this.store.claimableAchievementIds.has(a.id)) {
            Pill(`+${a.reward}`, '#FFFFFF', C.beetle)
          }
        }
        Text(a.description).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted).maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.store.claimableAchievementIds.has(a.id)) {
        SmallChunkyButton({ label: '领取', bgColor: C.beetle, shadowColor: '#A45FD6',
          onTap: () => {
            const gems = this.store.claimAchievement(a.id);
            if (gems > 0) {
              Haptics.success();
              SFXEngine.shared.play('purchase');
            }
          } }).width(76)
      } else if (this.store.claimedAchievementIds.has(a.id)) {
        DuoIcon({ name: 'checkCircle', sz: 20, color: C.primary })
      } else {
        DuoIcon({ name: 'lock', sz: 17, color: C.inkSofter })
      }
    }
    .padding(14)
    .width('100%')
    .backgroundColor(C.surface)
    .borderRadius(R.card)
    .border({
      width: 2, radius: R.card,
      color: this.store.claimableAchievementIds.has(a.id) ? C.beetle : C.border
    })
  }

  build() {
    Column() {
      TitleBar({ title: '成就', onBack: () => Router.shared.pop() })
      Scroll() {
        Column({ space: 10 }) {
          ForEach(Achievements.all, (a: Achievement) => {
            this.row(a)
          }, (a: Achievement) => `${a.id}-${this.rev}`)
          Blank().height(30)
        }
        .padding({ left: 16, right: 16, top: 10 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 设置页：声音/触感/外观/提醒 + 存档导出导入 + 资源。 */
@ComponentV2
export struct SettingsPage {
  store: ProgressStore = ProgressStore.shared;
  settings: SettingsStore = SettingsStore.shared;
  dl: AssetDownloader = AssetDownloader.shared;
  @Local backupMsg: string = '';
  @Local confirmReset: boolean = false;
  /** 已选好、待家长选择写入目标的存档（单人存档 1 份，全家备份多份）。 */
  @Local pendingImport: BackupEnvelope[] = [];
  @Local pendingFamily: boolean = false;
  @Local pendingExportedAt: string = '';
  /** 家长密码弹层（非空即显示）及通过后要执行的操作。 */
  @Local gateReason: string = '';
  @Local kidsRev: number = 0;
  private gateAction: (() => void) | null = null;
  @Local reminderMsg: string = '';
  /** 提醒开关被权限拒绝回滚时自增，强制 Toggle 按真实状态重绘。 */
  @Local reminderRev: number = 0;
  private unsubBack: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubBack = Router.shared.interceptBack(() => {
      if (this.confirmReset || this.pendingImport.length > 0 || this.gateReason.length > 0) {
        this.confirmReset = false;
        this.pendingImport = [];
        this.gateReason = '';
        this.gateAction = null;
        this.kidsRev++;
        return true;
      }
      return false;
    });
  }

  aboutToDisappear(): void {
    this.unsubBack();
  }

  private guard(reason: string, action: () => void): void {
    if (ParentLock.isUnlocked()) {
      action();
      return;
    }
    this.gateAction = action;
    this.gateReason = reason;
  }

  private rescheduleReminders(): void {
    StreakReminders.reschedule(new ReminderContext(this.store.reminderStreak, this.store.dueMistakes.length),
      this.store.studiedToday);
  }

  private toggleReminder(on: boolean): void {
    if (!on) {
      this.settings.setStreakReminder(false);
      this.reminderMsg = '';
      this.rescheduleReminders();
      return;
    }
    StreakReminders.requestAuthorization().then((granted: boolean) => {
      if (granted) {
        this.settings.setStreakReminder(true);
        this.reminderMsg = '';
        this.rescheduleReminders();
      } else {
        this.settings.setStreakReminder(false);
        this.reminderMsg = '没有通知权限，请在系统设置里允许「聪聪学堂」发送通知';
        this.reminderRev++;
      }
    });
  }

  private pickReminderTime(): void {
    const sel = new Date();
    sel.setHours(this.settings.reminderHour, this.settings.reminderMinute, 0, 0);
    this.getUIContext().showTimePickerDialog({
      selected: sel,
      useMilitaryTime: true,
      onAccept: (v: TimePickerResult) => {
        this.settings.setReminderTime(v.hour ?? this.settings.reminderHour, v.minute ?? this.settings.reminderMinute);
        this.reminderRev++;
        this.rescheduleReminders();
      }
    });
  }

  @Builder
  switchCtl(on: boolean, change: (v: boolean) => void) {
    Toggle({ type: ToggleType.Switch, isOn: on })
      .selectedColor(C.primary)
      .onChange((v: boolean) => change(v))
  }

  @Builder
  timeCtl() {
    Text(this.settings.reminderTimeLabel)
      .fontSize(F.subhead)
      .fontWeight(W.heavy)
      .fontColor(C.secondary)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(C.surfaceAlt)
      .borderRadius(999)
      .onClick(() => this.pickReminderTime())
  }

  @Builder
  appearanceCtl() {
    Row({ space: 6 }) {
      ForEach(['system', 'light', 'dark'] as AppAppearance[], (a: AppAppearance) => {
        Text(appearanceLabel(a))
          .fontSize(F.caption)
          .fontWeight(W.bold)
          .fontColor(this.settings.appearance === a ? '#FFFFFF' : C.ink)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(this.settings.appearance === a ? C.primary : C.surfaceAlt)
          .borderRadius(999)
          .onClick(() => {
            this.settings.setAppearance(a);
            Haptics.tap();
          })
      }, (a: AppAppearance) => a)
    }
  }

  private exportBackup(all: boolean): void {
    const me = LearnerStore.shared.active;
    const json = all ? JSON.stringify(Family.exportFamily(), null, 2) :
      JSON.stringify(this.store.exportBackupEnvelope(), null, 2);
    const name = all ? `congcong-family-backup-${Family.fileStamp()}.json` :
      `congcong-backup-${Family.fileSafe(me.name)}-${Family.fileStamp()}.json`;
    try {
      Family.saveJson(json, name).then((ok: boolean) => {
        if (ok) {
          this.backupMsg = all ? '全家存档已导出' : `「${me.name}」的存档已导出`;
          Haptics.success();
        }
      });
    } catch (e) {
      this.backupMsg = '导出失败：系统文件选择器不可用';
    }
  }

  private importBackup(): void {
    const selectOpts = new picker.DocumentSelectOptions();
    selectOpts.maxSelectNumber = 1;
    selectOpts.fileSuffixFilters = ['存档(.json)|.json'];
    try {
      const docPicker = new picker.DocumentViewPicker(AppEnv.ctx());
      docPicker.select(selectOpts).then((uris: Array<string>) => {
        if (uris.length === 0) {
          return;
        }
        const file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
        let raw = '';
        try {
          const stat = fs.statSync(file.fd);
          const buf = new ArrayBuffer(stat.size);
          fs.readSync(file.fd, buf);
          raw = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
        } finally {
          fs.closeSync(file);
        }
        const v = validateAnyBackup(raw);
        if (v.entries.length === 0) {
          this.backupMsg = `存档无效：${v.error ?? '格式错误'}`;
          return;
        }
        this.pendingFamily = v.family;
        this.pendingExportedAt = v.exportedAt;
        this.pendingImport = v.entries;
      }).catch((err: BusinessError) => {
        this.backupMsg = `导入失败：${err.message ?? err.code}`;
      });
    } catch (e) {
      this.backupMsg = '文件选择不可用';
    }
  }

  @Builder
  resetDialog() {
    ModalCard({ onBackdrop: () => {
      this.confirmReset = false;
    } }) {
      Mascot({ mood: 'sad', sz: 84 })
      Text(`确定要重置「${LearnerStore.shared.active.name}」的学习进度吗？`).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
        .textAlign(TextAlign.Center)
      Text('经验、宝石、连胜、错题本都会清空，此操作无法撤销。建议先导出存档。').fontSize(F.caption)
        .fontColor(C.inkMuted).textAlign(TextAlign.Center)
      ChunkyButton({ label: '重置进度', variant: 'danger', onTap: () => {
        this.confirmReset = false;
        this.guard(`重置「${LearnerStore.shared.active.name}」的进度需要家长确认`, () => {
          this.store.resetProgress();
          Haptics.wrong();
          Router.shared.clear();
        });
      } })
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => {
        this.confirmReset = false;
      } })
    }
  }

  build() {
    Stack() {
    Column() {
      TitleBar({ title: '设置', onBack: () => Router.shared.pop() })
      Scroll() {
        Column({ space: 10 }) {
          Text('学习方式').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          ForEach([this.kidsRev], (kr: number) => {
            SettingRow({ title: '儿童模式（推荐）', subtitle: '答错不扣红心：先封存宝箱，收服心魔后返还；课内有神速题和踮脚题',
              control: (): void => this.switchCtl(this.settings.kidsMode, (v: boolean) => {
                this.guard('切换儿童模式需要家长确认', () => this.settings.setKidsMode(v));
                this.kidsRev++;
              }) })
          }, (kr: number) => `kids-${kr}`)

          Text('声音与触感').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          SettingRow({ title: '音效', subtitle: '答题反馈与庆祝的声音', control: (): void => this.switchCtl(!this.settings.isMuted,
              (v: boolean) => this.settings.setMuted(!v)) })
          SettingRow({ title: '自动朗读', subtitle: '进入新题目时朗读题干', control: (): void => this.switchCtl(this.settings.autoNarrate,
              (v: boolean) => this.settings.setAutoNarrate(v)) })
          SettingRow({ title: '触感振动', subtitle: '答对答错时的轻微振动', control: (): void => this.switchCtl(this.settings.hapticEnabled,
              (v: boolean) => this.settings.setHaptic(v)) })

          Text('外观').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          SettingRow({ title: '主题', subtitle: '跟随系统或固定明暗', control: (): void => this.appearanceCtl() })

          Text('提醒').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          ForEach([this.reminderRev], (rv: number) => {
            Column({ space: 10 }) {
              SettingRow({ title: '连胜提醒', subtitle: `每天 ${this.settings.reminderTimeLabel} 提醒续火`,
                control: (): void => this.switchCtl(this.settings.streakReminderEnabled,
                  (v: boolean) => this.toggleReminder(v)) })
              if (this.settings.streakReminderEnabled) {
                SettingRow({ title: '提醒时间', subtitle: '点右侧时间修改',
                  control: (): void => this.timeCtl() })
              }
              if (this.reminderMsg.length > 0) {
                Text(this.reminderMsg).fontSize(F.micro).fontColor(C.danger).width('100%')
              }
            }
            .width('100%')
          }, (rv: number) => `rem-${rv}`)

          Text('存档').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          CardBox() {
            Column({ space: 10 }) {
              Text('导出/导入学习进度（与 iOS/Web 同一存档格式）。存档记着是哪个孩子的，导入时可选放进哪个档案。')
                .fontSize(F.caption).fontColor(C.inkMuted)
              Row({ space: 10 }) {
                SmallChunkyButton({ label: '导出存档', icon: 'share', bgColor: C.secondary,
                  shadowColor: C.secondaryDark, onTap: () => this.exportBackup(false) }).layoutWeight(1)
                SmallChunkyButton({ label: '导入存档', icon: 'download', bgColor: C.primary,
                  shadowColor: C.primaryDark, onTap: () => this.guard('导入存档会覆盖孩子的进度，需要家长确认',
                    () => this.importBackup()) }).layoutWeight(1)
              }
              if (LearnerStore.shared.count > 1) {
                SmallChunkyButton({ label: '导出全家存档', icon: 'share', bgColor: C.secondary,
                  shadowColor: C.secondaryDark, onTap: () => this.exportBackup(true) })
              }
              if (this.backupMsg.length > 0) {
                Text(this.backupMsg).fontSize(F.micro).fontColor(C.inkMuted).maxLines(3)
              }
            }
            .width('100%')
          }

          Text('资源').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          CardBox() {
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Text(this.dl.indexFetchedAt !== 0 ?
                  `资源目录已刷新 · ${DataLoader.loadSiteIndex().books.length} 本书可下载` :
                  '资源目录未刷新')
                  .fontSize(F.caption).fontColor(C.inkMuted).layoutWeight(1)
                SmallChunkyButton({ label: '刷新', icon: 'downloadCircle', bgColor: C.secondary,
                  shadowColor: C.secondaryDark,
                  active: !this.dl.inFlight.size, onTap: () => {
                    this.dl.refreshSiteIndex().catch(() => {
                    });
                  } }).width(88)
              }
              .width('100%')
            }
          }

          Text('危险区').fontSize(F.caption).fontWeight(W.bold).fontColor(C.danger).width('100%')
            .margin({ top: 6 })
          CardBox() {
            Column({ space: 10 }) {
              Text(`清空「${LearnerStore.shared.active.name}」的全部学习进度（不可恢复，其他孩子不受影响）`)
                .fontSize(F.caption).fontColor(C.inkMuted)
              ChunkyButton({ label: '重置进度', variant: 'danger', onTap: () => {
                Haptics.tap();
                this.confirmReset = true;
              } })
            }
            .width('100%')
          }
          Blank().height(30)
        }
        .padding({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)

      if (this.confirmReset) {
        this.resetDialog()
      }
      if (this.pendingImport.length > 0) {
        ImportPlanDialog({
          entries: this.pendingImport, family: this.pendingFamily, exportedAt: this.pendingExportedAt,
          onDone: (msg: string) => {
            this.pendingImport = [];
            this.backupMsg = msg;
          }
        })
      }
      if (this.gateReason.length > 0) {
        ParentGate({
          reason: this.gateReason,
          onUnlocked: () => {
            const action = this.gateAction;
            this.gateAction = null;
            this.gateReason = '';
            if (action !== null) {
              action();
            }
            this.kidsRev++;
          },
          onCancel: () => {
            this.gateAction = null;
            this.gateReason = '';
            this.kidsRev++;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
