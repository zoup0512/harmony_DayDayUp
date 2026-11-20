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
import { makeEnvelope, validateBackup } from '../domain/Backup';
import {
  BadgeData, ShareCardButton, StreakShareData
} from '../components/ShareCard';
import {
  CardBox, ChunkyButton, DuoIcon, IconBadge, Pill, SmallChunkyButton, TitleBar
} from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { StreakCalendar, weekCalendar } from '../components/Widgets';
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

/** 「我的」Tab：连胜日历、每日目标、成就入口、设置入口。 */
@ComponentV2
export struct ProfileTab {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  aboutToAppear(): void {
    this.store.onChange(() => {
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
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      ForEach([this.rev], (r: number) => {
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Mascot({ mood: 'happy', sz: 64, allowsTap: true })
            Column({ space: 2 }) {
              Text(this.store.displayName).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
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
          .padding({ left: 4, right: 4, top: 14 })

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

          Row({ space: 8 }) {
            this.stat('bolt', C.secondary, `${this.store.progress.xp}`, '总经验')
            this.stat('gem', C.beetle, `${this.store.gems}`, '宝石')
            this.stat('checkCircle', C.primary, `${this.store.totalCompletedLessons}`, '完成课')
            this.stat('star', C.bee, `${this.store.perfectedLessonCount}`, '满星课')
          }
          .padding({ left: 4, right: 4 })

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
          Blank().height(30)
        }
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      }, (r: number) => `${r}`)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}

/** 成就页：家庭分组，解锁 ≠ 领取（领奖才发宝石）。 */
@ComponentV2
export struct AchievementsPage {
  store: ProgressStore = ProgressStore.shared;
  @Local rev: number = 0;

  aboutToAppear(): void {
    this.store.onChange(() => {
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

  @Builder
  switchCtl(on: boolean, change: (v: boolean) => void) {
    Toggle({ type: ToggleType.Switch, isOn: on })
      .selectedColor(C.primary)
      .onChange((v: boolean) => change(v))
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

  private exportBackup(): void {
    const env = this.store.exportBackupEnvelope();
    const json = JSON.stringify(env, null, 2);
    const saveOpts = new picker.DocumentSaveOptions();
    saveOpts.newFileNames = ['congcong-backup.json'];
    try {
      const docPicker = new picker.DocumentViewPicker(AppEnv.ctx());
      docPicker.save(saveOpts).then((uris: Array<string>) => {
        if (uris.length === 0) {
          return;
        }
        const file = fs.openSync(uris[0],
          fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
        try {
          fs.writeSync(file.fd, json);
        } finally {
          fs.closeSync(file);
        }
        this.backupMsg = '存档已导出';
        Haptics.success();
      }).catch((err: BusinessError) => {
        this.backupMsg = `导出取消/失败：${err.code}`;
      });
    } catch (e) {
      const path = `${AppEnv.cacheDir()}/congcong-backup.json`;
      Files.writeTextAtomic(path, json);
      this.backupMsg = `存档已导出：${path}`;
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
        const v = validateBackup(raw);
        if (v.envelope === null) {
          this.backupMsg = `存档无效：${v.error ?? '格式错误'}`;
          return;
        }
        this.store.importBackup(v.envelope);
        this.backupMsg = '存档已导入';
        Haptics.success();
      }).catch((err: BusinessError) => {
        this.backupMsg = `导入取消/失败：${err.code}`;
      });
    } catch (e) {
      this.backupMsg = '文件选择不可用';
    }
  }

  build() {
    Column() {
      TitleBar({ title: '设置', onBack: () => Router.shared.pop() })
      Scroll() {
        Column({ space: 10 }) {
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
          SettingRow({ title: '连胜提醒', subtitle: `每天 ${this.settings.reminderTimeLabel} 提醒续火`,
            control: (): void => this.switchCtl(this.settings.streakReminderEnabled, (v: boolean) => {
              this.settings.setStreakReminder(v);
              StreakReminders.reschedule(new ReminderContext(this.store.reminderStreak,
                this.store.dueMistakes.length), this.store.studiedToday);
            }) })

          Text('存档').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).width('100%')
            .margin({ top: 6 })
          CardBox() {
            Column({ space: 10 }) {
              Text('导出/导入学习进度（与 iOS/Web 同一存档格式）').fontSize(F.caption).fontColor(C.inkMuted)
              Row({ space: 10 }) {
                SmallChunkyButton({ label: '导出存档', icon: 'share', bgColor: C.secondary,
                  shadowColor: C.secondaryDark, onTap: () => this.exportBackup() }).layoutWeight(1)
                SmallChunkyButton({ label: '导入存档', icon: 'download', bgColor: C.primary,
                  shadowColor: C.primaryDark, onTap: () => this.importBackup() }).layoutWeight(1)
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
              Text('清空本机全部学习进度（不可恢复）').fontSize(F.caption).fontColor(C.inkMuted)
              ChunkyButton({ label: '重置进度', variant: 'danger', onTap: () => {
                this.store.resetProgress();
                Haptics.wrong();
                Router.shared.clear();
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
  }
}
