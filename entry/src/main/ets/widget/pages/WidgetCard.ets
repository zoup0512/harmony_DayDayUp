// 桌面连胜卡片（iOS StreakWidget 的服务卡片版）：火苗 + 天数 + 今日 XP 进度。
// 数据键与 WidgetSync.WidgetCardData 对应：streak / studiedToday / todayXp / dailyGoal / message / mood。

@Entry
@Component
struct WidgetCard {
  @LocalStorageProp('streak') streak: number = 0;
  @LocalStorageProp('studiedToday') studiedToday: boolean = false;
  @LocalStorageProp('todayXp') todayXp: number = 0;
  @LocalStorageProp('dailyGoal') dailyGoal: number = 50;
  @LocalStorageProp('message') message: string = '来点燃小火苗吧';
  @LocalStorageProp('mood') mood: string = 'calm';

  private flameColor(): string {
    return this.streak > 0 ? '#FF9600' : '#AFAFAF';
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.flame_fill'))
          .fontSize(28)
          .fontColor([this.flameColor()])
          .fontWeight(FontWeight.Bold)
        Text(`${this.streak}`)
          .fontSize(34)
          .fontWeight(FontWeight.Bolder)
          .fontColor('#4B4B4B')
        Text('天').fontSize(14).fontWeight(FontWeight.Medium).fontColor('#707070')
      }
      .alignItems(VerticalAlign.Center)

      Text(this.message)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#707070')
        .margin({ top: 8 })
        .maxLines(2)

      Blank()

      Row({ space: 6 }) {
        Progress({ value: Math.min(this.todayXp, this.dailyGoal), total: Math.max(1, this.dailyGoal) })
          .color(this.todayXp >= this.dailyGoal ? '#FFC800' : '#58CC02')
          .layoutWeight(1)
          .height(8)
        Text(`${this.todayXp}/${this.dailyGoal}`).fontSize(11).fontWeight(FontWeight.Medium).fontColor('#AFAFAF')
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility'
      });
    })
  }
}
