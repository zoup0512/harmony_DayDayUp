// 多孩子：头像 / 家长密码弹层 / 「谁在学习？」/ 孩子档案页 / 家长总览页 / 导入归属弹层。
import { LengthMetrics } from '@kit.ArkUI';
import { C, F, R, W, alpha } from '../design/Theme';
import { Economy } from '../domain/Economy';
import { BackupEnvelope } from '../domain/Backup';
import {
  DEFAULT_LEARNER_ID, LEARNER_COLORS, LEARNER_NAME_MAX, LearnerProfile, LearnerStore, learnerColorHex,
  learnerColorLabel, learnerInitial
} from '../stores/LearnerStore';
import { ProgressStore } from '../stores/ProgressStore';
import { ParentLock } from '../services/ParentLock';
import { Family, ImportResult, LearnerSummary, NEW_TARGET, SKIP_TARGET } from '../services/Family';
import { Haptics } from '../services/Feedback';
import { CardBox, ChunkyButton, DuoIcon, ModalCard, Pill, SmallChunkyButton, TitleBar } from '../components/Kit';
import { AppRoute, Router } from './Router';

const NON_DIGIT: RegExp = new RegExp('\\D', 'g');

/** 名字首字 + 档案颜色。 */
@ComponentV2
export struct LearnerAvatar {
  @Param name: string = '';
  @Param color: string = 'green';
  @Param sz: number = 40;

  build() {
    Text(learnerInitial(this.name))
      .width(this.sz)
      .height(this.sz)
      .borderRadius(this.sz / 2)
      .backgroundColor(learnerColorHex(this.color))
      .fontColor('#132C36')
      .fontSize(this.sz * 0.45)
      .fontWeight(W.heavy)
      .textAlign(TextAlign.Center)
  }
}

/** 家长密码弹层；「忘记密码」答对成人算术题后清除密码。 */
@ComponentV2
export struct ParentGate {
  @Param reason: string = '';
  @Event onUnlocked: () => void = () => {
  };
  @Event onCancel: () => void = () => {
  };
  @Local pin: string = '';
  @Local error: string = '';
  @Local challengeQ: string = '';
  private challengeA: number = 0;

  private submit(): void {
    if (this.pin.length === 0) {
      return;
    }
    if (this.challengeQ.length > 0) {
      if (Number(this.pin) !== this.challengeA) {
        this.error = '答案不对，再算一算';
        this.pin = '';
        return;
      }
      ParentLock.clearPin();
      this.onUnlocked();
      return;
    }
    if (!ParentLock.verify(this.pin)) {
      this.error = '密码不对，请家长再试一次';
      this.pin = '';
      Haptics.wrong();
      return;
    }
    ParentLock.unlock();
    Haptics.success();
    this.onUnlocked();
  }

  build() {
    ModalCard({ onBackdrop: () => this.onCancel() }) {
      DuoIcon({ name: 'lock', sz: 34, color: C.secondary })
      Text(this.challengeQ.length > 0 ? '忘记密码' : '请家长输入密码')
        .fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text(this.challengeQ.length > 0 ? `请家长算出 ${this.challengeQ} 答对后会清除家长密码，可以重新设置。` : this.reason)
        .fontSize(F.caption).fontColor(C.inkMuted).textAlign(TextAlign.Center)
      TextInput({ text: this.pin, placeholder: this.challengeQ.length > 0 ? '答案' : '家长密码' })
        .type(this.challengeQ.length > 0 ? InputType.Number : InputType.NUMBER_PASSWORD)
        .maxLength(6)
        .fontSize(F.subhead)
        .fontColor(C.ink)
        .textAlign(TextAlign.Center)
        .backgroundColor(C.surfaceAlt)
        .borderRadius(R.card)
        .height(54)
        .defaultFocus(true)
        .onChange((v: string) => {
          this.pin = v.replace(NON_DIGIT, '');
          // 输错后清空输入框也会回调 onChange('')——只在真的输入时才清掉错误提示
          if (this.pin.length > 0) {
            this.error = '';
          }
        })
        .onSubmit(() => this.submit())
      if (this.error.length > 0) {
        Text(this.error).fontSize(F.caption).fontColor(C.danger)
      }
      ChunkyButton({ label: '确认', variant: this.pin.length === 0 ? 'disabled' : 'primary', onTap: () => this.submit() })
      Row() {
        Text('取消').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).padding(10)
          .onClick(() => this.onCancel())
        Blank()
        if (this.challengeQ.length === 0) {
          Text('忘记密码？').fontSize(F.caption).fontWeight(W.bold).fontColor(C.secondary).padding(10)
            .onClick(() => {
              const c = ParentLock.challenge();
              this.challengeA = c.answer;
              this.challengeQ = c.question;
              this.pin = '';
              this.error = '';
            })
        }
      }
      .width('100%')
    }
  }
}

/** 「谁在学习？」——冷启动自动弹出（只能选人），或由首页头像手动打开（可取消）。 */
@ComponentV2
export struct LearnerPicker {
  @Local gateReason: string = '';
  private gateId: string = '';

  private choose(id: string): void {
    Haptics.tap();
    if (id !== LearnerStore.shared.activeId && ParentLock.lockSwitch && !ParentLock.isUnlocked()) {
      this.gateId = id;
      this.gateReason = '切换到其他孩子的档案需要家长确认';
      return;
    }
    Family.pick(id);
  }

  build() {
    Stack() {
      ModalCard({ maxW: 380, onBackdrop: () => {
        if (!LearnerStore.shared.pickerAuto) {
          LearnerStore.shared.closePicker();
        }
      } }) {
        Text('谁在学习？').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
        Text('点自己的名字，进入自己的进度').fontSize(F.caption).fontColor(C.inkMuted)
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center,
          space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
          ForEach(LearnerStore.shared.list, (p: LearnerProfile) => {
            Column({ space: 6 }) {
              LearnerAvatar({ name: p.name, color: p.color ?? 'green', sz: 52 })
              Text(p.name).fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink).maxLines(2)
                .textAlign(TextAlign.Center)
            }
            .width(118)
            .padding(12)
            .backgroundColor(p.id === LearnerStore.shared.activeId ? alpha(C.primary, 0.12) : C.surface)
            .borderRadius(R.card)
            .border({ width: 2, radius: R.card, color: p.id === LearnerStore.shared.activeId ? C.primary : C.border })
            .onClick(() => this.choose(p.id))
            .accessibilityText(`${p.name}${p.id === LearnerStore.shared.activeId ? '，当前' : ''}`)
          }, (p: LearnerProfile) => p.id)
        }
        .width('100%')
        if (!LearnerStore.shared.pickerAuto) {
          Text('取消').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).padding(10)
            .onClick(() => LearnerStore.shared.closePicker())
        }
      }
      if (this.gateReason.length > 0) {
        ParentGate({
          reason: this.gateReason,
          onUnlocked: () => {
            this.gateReason = '';
            Family.pick(this.gateId);
          },
          onCancel: () => {
            this.gateReason = '';
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}

type EditMode = 'none' | 'create' | 'edit';

/** 孩子档案页：增删改、排序、切换 + 家长密码设置。所有改动先过家长密码。 */
@ComponentV2
export struct LearnersPage {
  @Local rev: number = 0;
  @Local editMode: EditMode = 'none';
  @Local editId: string = '';
  @Local nameDraft: string = '';
  @Local colorDraft: string = 'green';
  @Local editError: string = '';
  @Local deleteId: string = '';
  @Local msg: string = '';
  @Local pinOpen: boolean = false;
  @Local pinDraft: string = '';
  @Local pinConfirm: string = '';
  @Local pinError: string = '';
  @Local gateReason: string = '';
  private gateAction: (() => void) | null = null;
  private unsubLearners: () => void = () => {
  };
  private unsubBack: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubLearners = LearnerStore.shared.onChange(() => {
      this.rev++;
    });
    this.unsubBack = Router.shared.interceptBack(() => {
      if (this.gateReason.length > 0 || this.editMode !== 'none' || this.deleteId.length > 0 || this.pinOpen) {
        this.closeAll();
        return true;
      }
      return false;
    });
  }

  aboutToDisappear(): void {
    this.unsubLearners();
    this.unsubBack();
  }

  private closeAll(): void {
    this.gateReason = '';
    this.gateAction = null;
    this.editMode = 'none';
    this.deleteId = '';
    this.pinOpen = false;
  }

  private guard(reason: string, action: () => void): void {
    if (ParentLock.isUnlocked()) {
      action();
      return;
    }
    this.gateAction = action;
    this.gateReason = reason;
  }

  private get deleting(): LearnerProfile | null {
    return LearnerStore.shared.find(this.deleteId);
  }

  private openCreate(): void {
    this.editMode = 'create';
    this.editId = '';
    this.nameDraft = '';
    this.colorDraft = LEARNER_COLORS[LearnerStore.shared.count % LEARNER_COLORS.length];
    this.editError = '';
  }

  private openEdit(p: LearnerProfile): void {
    this.editMode = 'edit';
    this.editId = p.id;
    this.nameDraft = p.name;
    this.colorDraft = p.color ?? 'green';
    this.editError = '';
  }

  private saveEdit(): void {
    const err = LearnerStore.nameError(this.nameDraft);
    if (err !== null) {
      this.editError = err;
      return;
    }
    const name = this.nameDraft.trim();
    const color = this.colorDraft;
    const mode = this.editMode;
    const id = this.editId;
    this.guard('管理孩子档案需要家长确认', () => {
      this.editMode = 'none';
      if (mode === 'create') {
        const created = LearnerStore.shared.create(name, color);
        Haptics.success();
        Family.switchTo(created.id);
        return;
      }
      if (id === LearnerStore.shared.activeId) {
        ProgressStore.shared.setDisplayName(name);
      } else {
        LearnerStore.shared.rename(id, name);
      }
      LearnerStore.shared.setColor(id, color);
      Haptics.success();
    });
  }

  private switchTo(id: string): void {
    if (ParentLock.lockSwitch) {
      this.guard('切换到其他孩子的档案需要家长确认', () => Family.switchTo(id));
      return;
    }
    Family.switchTo(id);
  }

  private remove(withBackup: boolean): void {
    const p = this.deleting;
    if (p === null) {
      return;
    }
    const id = p.id;
    const name = p.name;
    this.guard(`删除「${name}」需要家长确认`, () => {
      this.deleteId = '';
      if (!withBackup) {
        Family.remove(id);
        return;
      }
      const json = JSON.stringify(Family.exportLearner(id), null, 2);
      Family.saveJson(json, `congcong-backup-${Family.fileSafe(name)}-${Family.fileStamp()}.json`)
        .then((ok: boolean) => {
          if (ok) {
            Family.remove(id);
          } else {
            this.msg = '没有导出存档，档案未删除';
          }
        });
    });
  }

  private savePin(): void {
    if (!ParentLock.isValidPin(this.pinDraft)) {
      this.pinError = '请输入 4–6 位数字';
      return;
    }
    if (this.pinDraft !== this.pinConfirm) {
      this.pinError = '两次输入的密码不一样';
      return;
    }
    ParentLock.setPin(this.pinDraft);
    this.pinOpen = false;
    this.msg = '家长密码已设置';
    Haptics.success();
    this.rev++;
  }

  @Builder
  row(p: LearnerProfile, index: number) {
    Row({ space: 10 }) {
      LearnerAvatar({ name: p.name, color: p.color ?? 'green', sz: 40 })
      Column({ space: 2 }) {
        Text(p.name).fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink).maxLines(2)
        if (p.id === LearnerStore.shared.activeId) {
          Text('当前').fontSize(F.micro).fontWeight(W.bold).fontColor(C.primary)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (p.id !== LearnerStore.shared.activeId) {
        Text('切换').fontSize(F.caption).fontWeight(W.bold).fontColor(C.primary).padding(8)
          .onClick(() => this.switchTo(p.id))
      }
      Text('编辑').fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).padding(8)
        .onClick(() => this.openEdit(p))
      Text('↑').fontSize(F.body).fontWeight(W.bold).padding(8)
        .fontColor(index === 0 ? C.border : C.inkMuted)
        .onClick(() => this.guard('管理孩子档案需要家长确认', () => LearnerStore.shared.move(p.id, -1)))
        .accessibilityText(`把${p.name}上移`)
      Text('↓').fontSize(F.body).fontWeight(W.bold).padding(8)
        .fontColor(index === LearnerStore.shared.count - 1 ? C.border : C.inkMuted)
        .onClick(() => this.guard('管理孩子档案需要家长确认', () => LearnerStore.shared.move(p.id, 1)))
        .accessibilityText(`把${p.name}下移`)
      if (p.id !== DEFAULT_LEARNER_ID) {
        Text('删除').fontSize(F.caption).fontWeight(W.bold).fontColor(C.danger).padding(8)
          .onClick(() => {
            this.deleteId = p.id;
          })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(p.id === LearnerStore.shared.activeId ? alpha(C.primary, 0.08) : C.surface)
    .borderRadius(R.card)
    .border({ width: 2, radius: R.card, color: p.id === LearnerStore.shared.activeId ? C.primary : C.border })
  }

  @Builder
  editDialog() {
    ModalCard({ onBackdrop: () => {
      this.editMode = 'none';
    } }) {
      Text(this.editMode === 'create' ? '添加孩子' : '编辑档案').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      TextInput({ text: this.nameDraft, placeholder: '名字' })
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
          this.editError = '';
        })
      Row({ space: 8 }) {
        ForEach(LEARNER_COLORS, (c: string) => {
          Column()
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor(learnerColorHex(c))
            .border({ width: 3, radius: 17, color: this.colorDraft === c ? C.ink : '#00000000' })
            .onClick(() => {
              this.colorDraft = c;
            })
            .accessibilityText(learnerColorLabel(c))
        }, (c: string) => `${c}-${this.colorDraft === c}`)
      }
      if (this.editError.length > 0) {
        Text(this.editError).fontSize(F.caption).fontColor(C.danger)
      }
      ChunkyButton({ label: this.editMode === 'create' ? '创建并切换' : '保存', onTap: () => this.saveEdit() })
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => {
        this.editMode = 'none';
      } })
    }
  }

  @Builder
  deleteDialog() {
    ModalCard({ onBackdrop: () => {
      this.deleteId = '';
    } }) {
      Text(`删除「${this.deleting?.name ?? ''}」？`).fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
        .textAlign(TextAlign.Center)
      Text('会永久清除这个孩子在本机的全部进度、错题、宝箱和知识卡，无法恢复。')
        .fontSize(F.caption).fontColor(C.inkMuted).textAlign(TextAlign.Center)
      ChunkyButton({ label: '先导出存档，再删除', onTap: () => this.remove(true) })
      ChunkyButton({ label: '直接删除', variant: 'danger', onTap: () => this.remove(false) })
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => {
        this.deleteId = '';
      } })
    }
  }

  @Builder
  pinDialog() {
    ModalCard({ onBackdrop: () => {
      this.pinOpen = false;
    } }) {
      Text('设置家长密码').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text('4–6 位数字。管理孩子、导入存档、重置进度和家长总览都会先问密码。')
        .fontSize(F.caption).fontColor(C.inkMuted).textAlign(TextAlign.Center)
      TextInput({ text: this.pinDraft, placeholder: '新密码' })
        .type(InputType.NUMBER_PASSWORD).maxLength(6).height(50).textAlign(TextAlign.Center)
        .backgroundColor(C.surfaceAlt).borderRadius(R.card).fontColor(C.ink).defaultFocus(true)
        .onChange((v: string) => {
          this.pinDraft = v.replace(NON_DIGIT, '');
          this.pinError = '';
        })
      TextInput({ text: this.pinConfirm, placeholder: '再输一次' })
        .type(InputType.NUMBER_PASSWORD).maxLength(6).height(50).textAlign(TextAlign.Center)
        .backgroundColor(C.surfaceAlt).borderRadius(R.card).fontColor(C.ink)
        .onChange((v: string) => {
          this.pinConfirm = v.replace(NON_DIGIT, '');
          this.pinError = '';
        })
      if (this.pinError.length > 0) {
        Text(this.pinError).fontSize(F.caption).fontColor(C.danger)
      }
      ChunkyButton({ label: '保存', onTap: () => this.savePin() })
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => {
        this.pinOpen = false;
      } })
    }
  }

  @Builder
  lockSection() {
    CardBox() {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          DuoIcon({ name: 'lock', sz: 18, color: C.secondary })
          Text('家长密码').fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink).layoutWeight(1)
          Pill(ParentLock.hasPin ? '已开启' : '未设置', '#FFFFFF', ParentLock.hasPin ? C.primary : C.inkSofter)
        }
        .width('100%')
        Text(ParentLock.hasPin ? '管理孩子、导入存档、重置进度、儿童模式开关和家长总览都需要先输入密码。' :
          '设置后，管理孩子、导入存档、重置进度、儿童模式开关和家长总览都需要家长输入密码。')
          .fontSize(F.caption).fontColor(C.inkMuted)
        Row({ space: 10 }) {
          SmallChunkyButton({ label: ParentLock.hasPin ? '修改密码' : '设置家长密码', icon: 'lock', bgColor: C.secondary,
            shadowColor: C.secondaryDark, onTap: () => {
              const open = (): void => {
                this.pinDraft = '';
                this.pinConfirm = '';
                this.pinError = '';
                this.pinOpen = true;
              };
              if (ParentLock.hasPin) {
                this.guard('修改家长密码需要先输入旧密码', open);
              } else {
                open();
              }
            } }).layoutWeight(1)
          if (ParentLock.hasPin) {
            SmallChunkyButton({ label: '关闭密码', bgColor: C.danger, shadowColor: C.dangerDark, onTap: () => {
              this.guard('关闭家长密码需要先输入密码', () => {
                ParentLock.clearPin();
                this.msg = '家长密码已关闭';
                this.rev++;
              });
            } }).layoutWeight(1)
          }
        }
        .width('100%')
        if (ParentLock.hasPin) {
          Row({ space: 12 }) {
            Text('切换孩子也需要家长密码').fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink).layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: ParentLock.lockSwitch })
              .selectedColor(C.primary)
              .onChange((v: boolean) => {
                this.guard('修改这项设置需要家长确认', () => {
                  ParentLock.setLockSwitch(v);
                  this.rev++;
                });
                if (!ParentLock.isUnlocked()) {
                  this.rev++;
                }
              })
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }

  build() {
    Stack() {
      Column() {
        TitleBar({ title: '孩子档案', onBack: () => Router.shared.pop() })
        Scroll() {
          Column() {
            ForEach([this.rev], (r: number) => {
              Column({ space: 10 }) {
                Text('每个孩子有自己的年级、进度、错题、宝箱和奖励，都保存在这台设备上。')
                  .fontSize(F.caption).fontColor(C.inkMuted).width('100%')
                ForEach(LearnerStore.shared.list, (p: LearnerProfile, i: number) => {
                  this.row(p, i)
                }, (p: LearnerProfile, i: number) => `${p.id}-${i}-${r}`)
                SmallChunkyButton({ label: '添加孩子', icon: 'person', bgColor: C.primary, shadowColor: C.primaryDark,
                  onTap: () => this.openCreate() })
                if (this.msg.length > 0) {
                  Text(this.msg).fontSize(F.caption).fontColor(C.inkMuted).width('100%')
                }
                this.lockSection()
                SmallChunkyButton({ label: '家长总览', icon: 'list', bgColor: C.secondary, shadowColor: C.secondaryDark,
                  onTap: () => Router.shared.push(new AppRoute('parent')) })
              }
              .width('100%')
            }, (r: number) => `learners-${r}`)
            Blank().height(30)
          }
          .padding({ left: 16, right: 16, top: 12 })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(C.bg)

      if (this.editMode !== 'none') {
        this.editDialog()
      }
      if (this.deleteId.length > 0) {
        this.deleteDialog()
      }
      if (this.pinOpen) {
        this.pinDialog()
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
            this.rev++;
          },
          onCancel: () => {
            this.gateAction = null;
            this.gateReason = '';
            this.rev++;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 家长总览：每个孩子今天学了多少、要不要复习，并能单独设每日目标或切换过去。 */
@ComponentV2
export struct ParentOverviewPage {
  @Local unlocked: boolean = false;
  @Local summaries: LearnerSummary[] = [];
  @Local gateReason: string = '';
  @Local msg: string = '';
  private unsubBack: () => void = () => {
  };

  aboutToAppear(): void {
    this.unsubBack = Router.shared.interceptBack(() => {
      if (this.gateReason.length > 0) {
        this.gateReason = '';
        return true;
      }
      return false;
    });
    if (ParentLock.isUnlocked()) {
      this.unlocked = true;
      this.load();
    } else {
      this.gateReason = '家长总览需要先输入家长密码';
    }
  }

  aboutToDisappear(): void {
    this.unsubBack();
  }

  private load(): void {
    this.summaries = LearnerStore.shared.list.map((p: LearnerProfile) => Family.summarize(p));
  }

  private gradeLabel(s: LearnerSummary): string {
    const grade = s.grade > 0 ? `${s.grade} 年级` : '还没选年级';
    return s.lastActiveDate.length > 0 ? `${grade} · 最近学习 ${s.lastActiveDate}` : `${grade} · 还没开始学习`;
  }

  private exportAll(): void {
    Family.saveJson(JSON.stringify(Family.exportFamily(), null, 2), `congcong-family-backup-${Family.fileStamp()}.json`)
      .then((ok: boolean) => {
        this.msg = ok ? '全家存档已导出' : '已取消导出';
      });
  }

  @Builder
  metric(label: string, value: string, tint: string) {
    Column({ space: 2 }) {
      Text(label).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
      Text(value).fontSize(F.body).fontWeight(W.heavy).fontColor(tint)
    }
    .layoutWeight(1)
    .padding(10)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(C.surfaceAlt)
    .borderRadius(R.control)
  }

  @Builder
  card(s: LearnerSummary) {
    CardBox({ stroke: s.active ? C.primary : '' }) {
      Column({ space: 10 }) {
        Row({ space: 10 }) {
          LearnerAvatar({ name: s.profile.name, color: s.profile.color ?? 'green', sz: 44 })
          Column({ space: 2 }) {
            Text(`${s.profile.name}${s.active ? ' · 当前' : ''}`).fontSize(F.subhead).fontWeight(W.heavy)
              .fontColor(C.ink).maxLines(2)
            Text(this.gradeLabel(s)).fontSize(F.micro).fontWeight(W.bold).fontColor(C.inkMuted)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        Row({ space: 8 }) {
          this.metric('今日 XP', `${s.todayXp} / ${s.dailyGoal}`, s.todayXp >= s.dailyGoal ? C.primary : C.ink)
          this.metric('连续学习', `${s.streak} 天`, s.streak > 0 ? C.fox : C.ink)
        }
        .width('100%')
        Row({ space: 8 }) {
          this.metric('本周 XP', `${s.weekXp}`, C.ink)
          this.metric('完成课程', `${s.lessons} 节 · 满星 ${s.perfect}`, C.ink)
        }
        .width('100%')
        Row({ space: 8 }) {
          this.metric('待复习错题', `${s.mistakesDue} 道`, s.mistakesDue > 0 ? C.danger : C.ink)
          this.metric('待收服心魔', `${s.demons} 只`, s.demons > 0 ? C.fox : C.ink)
        }
        .width('100%')
        Row({ space: 6 }) {
          Text('每日目标').fontSize(F.caption).fontWeight(W.bold).fontColor(C.ink).layoutWeight(1)
          ForEach(Economy.dailyGoalOptions, (g: number) => {
            Text(`${g}`)
              .fontSize(F.caption)
              .fontWeight(W.bold)
              .fontColor(s.dailyGoal === g ? '#FFFFFF' : C.ink)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(s.dailyGoal === g ? C.primary : C.surfaceAlt)
              .borderRadius(999)
              .onClick(() => {
                Haptics.tap();
                Family.setDailyGoal(s.profile.id, g);
                this.load();
              })
              .accessibilityText(`${s.profile.name}每日目标 ${g} XP`)
          }, (g: number) => `${s.profile.id}-${g}-${s.dailyGoal}`)
        }
        .width('100%')
        if (!s.active) {
          SmallChunkyButton({ label: `切换到${s.profile.name}`, bgColor: C.secondary, shadowColor: C.secondaryDark,
            onTap: () => Family.switchTo(s.profile.id) })
        }
      }
      .width('100%')
    }
  }

  build() {
    Stack() {
      Column() {
        TitleBar({ title: '家长总览', onBack: () => Router.shared.pop() })
        if (this.unlocked) {
          Scroll() {
            Column({ space: 12 }) {
              ForEach(this.summaries, (s: LearnerSummary) => {
                this.card(s)
              }, (s: LearnerSummary) => `${s.profile.id}-${s.dailyGoal}-${s.todayXp}`)
              SmallChunkyButton({ label: '导出全家存档', icon: 'share', bgColor: C.primary, shadowColor: C.primaryDark,
                onTap: () => this.exportAll() })
              if (this.msg.length > 0) {
                Text(this.msg).fontSize(F.caption).fontColor(C.inkMuted)
              }
              Blank().height(30)
            }
            .padding({ left: 16, right: 16, top: 12 })
          }
          .layoutWeight(1)
          .align(Alignment.Top)
        } else {
          Column({ space: 12 }) {
            Text('这里是家长专用页面。').fontSize(F.body).fontColor(C.inkMuted)
            ChunkyButton({ label: '输入家长密码', onTap: () => {
              this.gateReason = '家长总览需要先输入家长密码';
            } }).width(220)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(C.bg)

      if (this.gateReason.length > 0) {
        ParentGate({
          reason: this.gateReason,
          onUnlocked: () => {
            this.gateReason = '';
            this.unlocked = true;
            this.load();
          },
          onCancel: () => {
            this.gateReason = '';
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}

/** 导入确认：每份存档写到哪个孩子（新建 / 覆盖某个孩子 / 不导入）。 */
@ComponentV2
export struct ImportPlanDialog {
  @Param entries: BackupEnvelope[] = [];
  @Param family: boolean = false;
  @Param exportedAt: string = '';
  @Event onDone: (msg: string) => void = (msg: string) => {
  };
  @Local targets: string[] = [];

  aboutToAppear(): void {
    this.targets = Family.defaultTargets(this.entries, this.family);
  }

  private ownerName(i: number): string {
    const owner = this.entries[i].learner;
    return owner !== undefined && owner !== null ? owner.name : `导入的孩子 ${i + 1}`;
  }

  private targetIds(): string[] {
    return [NEW_TARGET].concat(LearnerStore.shared.list.map((p: LearnerProfile) => p.id)).concat([SKIP_TARGET]);
  }

  private targetLabel(id: string, i: number): string {
    if (id === NEW_TARGET) {
      return `新建档案「${this.ownerName(i)}」`;
    }
    if (id === SKIP_TARGET) {
      return '不导入';
    }
    const p = LearnerStore.shared.find(id);
    return `覆盖「${p?.name ?? ''}」${id === LearnerStore.shared.activeId ? '（当前）' : ''}`;
  }

  private options(i: number): SelectOption[] {
    return this.targetIds().map((id: string) => {
      const o: SelectOption = { value: this.targetLabel(id, i) };
      return o;
    });
  }

  private selectedIndex(i: number): number {
    return Math.max(0, this.targetIds().indexOf(this.targets[i] ?? NEW_TARGET));
  }

  private isOverwrite(id: string): boolean {
    return id !== NEW_TARGET && id !== SKIP_TARGET;
  }

  private setTarget(i: number, index: number): void {
    const value = this.targetIds()[index] ?? NEW_TARGET;
    const next = this.targets.slice();
    next.forEach((t: string, j: number) => {
      // 同一个档案只接收一份存档：被抢占的那份改为新建
      if (j !== i && t === value && this.isOverwrite(value)) {
        next[j] = NEW_TARGET;
      }
    });
    next[i] = value;
    this.targets = next;
  }

  private get overwriteCount(): number {
    return this.targets.filter((t: string) => this.isOverwrite(t)).length;
  }

  private get activeCount(): number {
    return this.targets.filter((t: string) => t !== SKIP_TARGET).length;
  }

  private summaryOf(env: BackupEnvelope): string {
    const platform = env.platform === 'ios' ? 'iPhone / iPad' : (env.platform === 'harmony' ? '鸿蒙' : '网页版');
    return `${platform} · ${Object.keys(env.data.completedLessons).length} 节课 · ${env.data.xp} XP · ` +
      `连胜 ${env.data.streak} 天 · ${env.data.gems} 宝石`;
  }

  private confirm(): void {
    const r: ImportResult = Family.importInto(this.entries, this.targets);
    Haptics.success();
    this.onDone(r.created > 0 ? `已导入 ${r.count} 个孩子的存档（新建 ${r.created} 个档案）` : `已导入 ${r.count} 个孩子的存档`);
  }

  build() {
    ModalCard({ maxW: 380, onBackdrop: () => this.onDone('已取消导入') }) {
      DuoIcon({ name: 'download', sz: 36, color: C.secondary })
      Text(this.family ? `导入全家存档（${this.entries.length} 个孩子）` : '导入存档')
        .fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink).textAlign(TextAlign.Center)
      Text(this.overwriteCount > 0 ? '选「覆盖」的孩子会丢失现有全部进度，建议先导出备份。' : '存档会放进新建的档案，不影响现有孩子。')
        .fontSize(F.caption).fontColor(this.overwriteCount > 0 ? C.danger : C.inkMuted).textAlign(TextAlign.Center)
      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.entries, (env: BackupEnvelope, i: number) => {
            Column({ space: 6 }) {
              Text(env.learner !== undefined && env.learner !== null ? `「${env.learner.name}」的存档` : '未标明孩子的存档')
                .fontSize(F.body).fontWeight(W.heavy).fontColor(C.ink)
              Text(this.summaryOf(env)).fontSize(F.micro).fontColor(C.inkMuted)
              Select(this.options(i))
                .selected(this.selectedIndex(i))
                .value(this.targetLabel(this.targets[i] ?? NEW_TARGET, i))
                .font({ size: F.caption, weight: W.bold })
                .onSelect((index: number) => this.setTarget(i, index))
              if (this.isOverwrite(this.targets[i] ?? NEW_TARGET)) {
                Text(`将覆盖「${LearnerStore.shared.find(this.targets[i])?.name ?? ''}」的全部进度`)
                  .fontSize(F.micro).fontWeight(W.bold).fontColor(C.danger)
              }
            }
            .width('100%')
            .padding(10)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(C.surfaceAlt)
            .borderRadius(R.control)
          }, (env: BackupEnvelope, i: number) => `${i}-${this.targets[i] ?? ''}`)
        }
      }
      .constraintSize({ maxHeight: 320 })
      if (this.exportedAt.length > 0) {
        Text(`导出于 ${this.exportedAt.substring(0, 10)}`).fontSize(F.micro).fontColor(C.inkMuted)
      }
      ChunkyButton({
        label: this.overwriteCount > 0 ? '覆盖并导入' : '导入',
        variant: this.activeCount === 0 ? 'disabled' : (this.overwriteCount > 0 ? 'danger' : 'primary'),
        onTap: () => {
          if (this.activeCount > 0) {
            this.confirm();
          }
        }
      })
      ChunkyButton({ label: '取消', variant: 'ghost', onTap: () => this.onDone('已取消导入') })
    }
  }
}
