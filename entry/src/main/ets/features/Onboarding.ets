// 首次进入（Onboarding）：选年级 → 选课本 → 开始。
import { LengthMetrics } from '@kit.ArkUI';
import { C, F, R, W, alpha } from '../design/Theme';
import { Book } from '../models/Types';
import { ProgressStore } from '../stores/ProgressStore';
import { SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { ChunkyButton, DuoIcon, IconBadge, Pill } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { allBooks, allGrades, bookInstalled } from './Books';

@ComponentV2
export struct Onboarding {
  store: ProgressStore = ProgressStore.shared;
  @Local step: number = 0;
  @Local grade: number = 1;
  @Local bookId: string = '';

  private books(): Book[] {
    return allBooks().filter((b: Book) => b.grade === this.grade);
  }

  private start(book: Book): void {
    Haptics.success();
    SFXEngine.shared.play('complete');
    this.store.setSelectedGrade(book.grade);
    this.store.setActiveBook(book.id);
    this.store.completeOnboarding();
  }

  build() {
    Column({ space: 22 }) {
      Blank().height('6%')
      Mascot({ mood: 'wave', sz: 150, allowsTap: true, illustrated: true })
      Column({ space: 6 }) {
        Text('你好，我是聪聪！').fontSize(F.title).fontWeight(W.heavy).fontColor(C.ink)
        Text('每天一课，把课本知识练扎实').fontSize(F.body).fontWeight(W.medium).fontColor(C.inkMuted)
      }
      .alignItems(HorizontalAlign.Center)

      if (this.step === 0) {
        Column({ space: 16 }) {
          Text('你上几年级？').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink)
          Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) },
            justifyContent: FlexAlign.Center }) {
            ForEach(allGrades(allBooks()).filter((g: number) => g !== 0), (g: number) => {
              Text(`${g} 年级`)
                .fontSize(F.subhead)
                .fontWeight(W.heavy)
                .fontColor(this.grade === g ? '#FFFFFF' : C.ink)
                .padding({ left: 22, right: 22, top: 14, bottom: 14 })
                .backgroundColor(this.grade === g ? C.primary : C.surface)
                .borderRadius(R.card)
                .border({ width: 2, color: this.grade === g ? C.primary : C.border, radius: R.card })
                .onClick(() => {
                  Haptics.tap();
                  SFXEngine.shared.play('tap');
                  this.grade = g;
                })
            }, (g: number) => `${g}`)
          }
          .padding({ left: 32, right: 32 })

          ChunkyButton({ label: '下一步', onTap: () => {
            Haptics.tap();
            this.step = 1;
            const first = this.books()[0];
            this.bookId = first !== undefined ? first.id : '';
          } }).width(240)
        }
      } else {
        Column({ space: 14 }) {
          Text('选一本要学的课本').fontSize(F.subhead).fontWeight(W.bold).fontColor(C.ink)
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.books(), (b: Book) => {
                Row({ space: 12 }) {
                  IconBadge('book', C.primary, 44, 20)
                  Column({ space: 2 }) {
                    Text(b.fullName).fontSize(F.body).fontWeight(W.bold).fontColor(C.ink).maxLines(2)
                    Row({ space: 6 }) {
                      Pill(`${b.unitsCount} 单元`, C.inkMuted, C.surfaceAlt)
                      if (bookInstalled(b.id)) {
                        Pill('已内置', '#FFFFFF', C.primary)
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
                .border({
                  width: 2, radius: R.card,
                  color: this.bookId === b.id ? C.primary : C.border
                })
                .onClick(() => {
                  Haptics.tap();
                  this.bookId = b.id;
                })
              }, (b: Book) => b.id)
            }
          }
          .constraintSize({ maxHeight: 320 })
          .align(Alignment.Top)
          .padding({ left: 24, right: 24 })

          ChunkyButton({
            label: '开始学习', variant: this.bookId.length === 0 ? 'disabled' : 'primary',
            onTap: () => {
              const b = this.books().find((x: Book) => x.id === this.bookId);
              if (b !== undefined) {
                this.start(b);
              }
            }
          }).width(240)
        }
      }
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
    .alignItems(HorizontalAlign.Center)
  }
}
