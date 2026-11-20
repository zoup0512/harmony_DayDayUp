// 庆祝动效：彩纸、星星揭晓、XP 飞字、连击浮层、宝箱弹窗。
import { curves } from '@kit.ArkUI';
import { C, F, R, W, alpha } from '../design/Theme';
import { Chest, ChestRewardTier } from '../domain/Catalog';
import { SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { ChunkyButton, DuoIcon } from './Kit';

const CONFETTI_COLORS: string[] = ['#58CC02', '#1CB0F6', '#FFC800', '#FF4B4B', '#CE82FF', '#FF9600', '#89E219', '#14D4F4'];

class Piece {
  x: number = 0;
  y: number = 0;
  vx: number = 0;
  vy: number = 0;
  rot: number = 0;
  spin: number = 0;
  size: number = 8;
  color: string = '#FFC800';
  round: boolean = false;
  life: number = 0;
  maxLife: number = 3.2;
  born: number = 0;
}

/** 两个喷泉向上喷射彩纸（ConfettiView 的 CAEmitter 版本用 Canvas 粒子重写）。 */
@ComponentV2
export struct Confetti {
  @Param active: boolean = false;
  @Param burstMs: number = 300;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private pieces: Piece[] = [];
  private timer: number = -1;
  private fired: boolean = false;
  private w: number = 360;
  private h: number = 720;
  private elapsed: number = 0;

  @Monitor('active')
  onActive(): void {
    this.maybeFire();
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
  }

  private spawn(t: number): void {
    for (const xf of [0.3, 0.7]) {
      for (let i = 0; i < 3; i++) {
        const p = new Piece();
        p.x = this.w * xf;
        p.y = this.h * 0.25;
        const ang = -Math.PI / 2 + (Math.random() - 0.5) * Math.PI * 0.8;
        const v = 300 + (Math.random() - 0.5) * 200;
        p.vx = Math.cos(ang) * v;
        p.vy = Math.sin(ang) * v;
        p.spin = (Math.random() - 0.5) * 12;
        p.size = 7 + Math.random() * 6;
        p.color = CONFETTI_COLORS[Math.floor(Math.random() * CONFETTI_COLORS.length)];
        p.round = Math.random() < 0.4;
        p.maxLife = 2.7 + Math.random();
        p.born = t;
        this.pieces.push(p);
      }
    }
  }

  private maybeFire(): void {
    if (!this.active || this.fired) {
      return;
    }
    this.fired = true;
    const dt = 1 / 60;
    this.timer = setInterval(() => {
      this.elapsed += dt;
      if (this.elapsed * 1000 < this.burstMs) {
        this.spawn(this.elapsed);
      }
      const c = this.ctx;
      c.clearRect(0, 0, this.w, this.h);
      this.pieces = this.pieces.filter((p: Piece) => this.elapsed - p.born < p.maxLife);
      for (const p of this.pieces) {
        p.vy += 280 * dt;
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.rot += p.spin * dt;
        const age = this.elapsed - p.born;
        c.globalAlpha = Math.max(0, Math.min(1, 1 - (age - p.maxLife * 0.6) / (p.maxLife * 0.4)));
        c.save();
        c.translate(p.x, p.y);
        c.rotate(p.rot);
        c.fillStyle = p.color;
        if (p.round) {
          c.beginPath();
          c.arc(0, 0, p.size / 2, 0, Math.PI * 2);
          c.fill();
        } else {
          c.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.6);
        }
        c.restore();
      }
      c.globalAlpha = 1;
      if (this.elapsed * 1000 > this.burstMs + 4000) {
        clearInterval(this.timer);
        this.timer = -1;
        c.clearRect(0, 0, this.w, this.h);
      }
    }, 16);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .onAreaChange((_o: Area, n: Area) => {
        this.w = Number(n.width);
        this.h = Number(n.height);
      })
      .onReady(() => this.maybeFire())
  }
}

/** 三颗星依次弹出（StarRevealView）。 */
@ComponentV2
export struct StarReveal {
  @Param earned: number = 0;
  @Local revealed: boolean[] = [false, false, false];

  aboutToAppear(): void {
    for (let i = 0; i < 3; i++) {
      const isEarned = i < this.earned;
      const delay = isEarned ? 500 + i * 380 : 500;
      setTimeout(() => {
        if (isEarned) {
          SFXEngine.shared.play('star');
        }
        this.getUIContext().animateTo({ curve: isEarned ? curves.springMotion(0.35, 0.55) : Curve.EaseOut, duration: 300 },
          () => {
            const next = this.revealed.slice();
            next[i] = true;
            this.revealed = next;
          });
      }, delay);
    }
  }

  build() {
    Row({ space: 16 }) {
      ForEach([0, 1, 2], (i: number) => {
        DuoIcon({ name: i < this.earned ? 'star' : 'starOutline', sz: i < this.earned ? 52 : 40,
          color: i < this.earned ? C.bee : C.bgSofter })
          .opacity(this.revealed[i] ? (i < this.earned ? 1 : 0.45) : 0)
          .scale({ x: this.revealed[i] ? 1 : (i < this.earned ? 0 : 0.9), y: this.revealed[i] ? 1 : (i < this.earned ? 0 : 0.9) })
          .rotate({ angle: (i < this.earned && !this.revealed[i]) ? -180 : 0 })
      }, (i: number) => `${i}`)
    }
    .accessibilityText(`获得 ${this.earned} 颗星`)
  }
}

/** 答对时的 +XP 飞字。 */
@ComponentV2
export struct XPFloater {
  @Param amount: number = 10;
  @Event onDone: () => void = () => {
  };
  @Local dy: number = 0;
  @Local op: number = 1;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 1000, curve: Curve.EaseOut }, () => {
        this.dy = -60;
        this.op = 0;
      });
    }, 16);
    setTimeout(() => this.onDone(), 1050);
  }

  build() {
    Row({ space: 4 }) {
      DuoIcon({ name: 'bolt', sz: 14, color: C.secondary })
      Text(`+${this.amount}`).fontSize(16).fontWeight(W.heavy).fontColor(C.secondary)
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor(alpha(C.secondary, 0.15))
    .borderRadius(999)
    .translate({ y: this.dy })
    .opacity(this.op)
    .hitTestBehavior(HitTestMode.None)
  }
}

/** 连击 3/5/10 时的火焰浮层。 */
@ComponentV2
export struct ComboOverlay {
  @Param combo: number = 3;
  @Local sc: number = 0.2;
  @Local op: number = 1;

  aboutToAppear(): void {
    SFXEngine.shared.play('combo');
    Haptics.success();
    setTimeout(() => {
      this.getUIContext().animateTo({ curve: curves.springMotion(0.3, 0.5) }, () => {
        this.sc = 1;
      });
    }, 16);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.op = 0;
        this.sc = 0.8;
      });
    }, 1000);
  }

  build() {
    Column({ space: 4 }) {
      DuoIcon({ name: 'flame', sz: 28, color: '#FFFFFF' })
      Text(`连击 ×${this.combo}`).fontSize(22).fontWeight(W.heavy).fontColor('#FFFFFF')
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .linearGradient({ angle: 135, colors: [[C.bee, 0], [C.fox, 0.5], [C.danger, 1]] })
    .borderRadius(20)
    .shadow({ radius: 0, color: '#66B45A00', offsetY: 8 })
    .scale({ x: this.sc, y: this.sc })
    .opacity(this.op)
    .hitTestBehavior(HitTestMode.None)
  }
}

/** 开宝箱弹窗（ChestModalView）：点击开箱 → 稀有度光环 + 宝石飞散 → 收下。 */
@ComponentV2
export struct ChestModal {
  @Event onClaim: (gems: number) => void = (_g: number) => {
  };
  @Event onDismiss: () => void = () => {
  };
  @Local opened: boolean = false;
  @Local showResult: boolean = false;
  @Local gems: number = 0;
  @Local tier: ChestRewardTier = 'common';
  @Local breathe: number = 0;
  @Local glowScale: number = 1;
  @Local lid: number = 0;
  @Local burst: boolean = false;
  @Local flown: boolean = false;
  @Local confetti: boolean = false;
  private angles: number[] = [];

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 1500, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate },
        () => {
          this.breathe = -4;
          this.glowScale = 1.25;
        });
    }, 30);
  }

  private tierColor(): string {
    return this.tier === 'epic' ? C.beetle : (this.tier === 'rare' ? C.macaw : C.bee);
  }

  private open(): void {
    if (this.opened) {
      return;
    }
    const reward = Chest.rollReward();
    this.gems = reward.gems;
    this.tier = reward.tier;
    SFXEngine.shared.play('chestOpen');
    Haptics.success();
    if (reward.tier === 'epic') {
      Haptics.heartLoss();
    }
    const count = this.tier === 'epic' ? 18 : (this.tier === 'rare' ? 13 : 9);
    this.angles = [];
    for (let i = 0; i < count; i++) {
      this.angles.push(i / count * 2 * Math.PI + (Math.random() - 0.5) * 0.4);
    }
    this.getUIContext().animateTo({ curve: curves.springMotion(0.4, 0.6) }, () => {
      this.opened = true;
      this.lid = 1;
    });
    setTimeout(() => {
      this.burst = true;
      this.confetti = this.tier === 'epic';
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 700, curve: Curve.EaseOut }, () => {
          this.flown = true;
        });
      }, 16);
    }, 150);
    setTimeout(() => {
      this.onClaim(this.gems);
      this.getUIContext().animateTo({ curve: curves.springMotion(0.35, 0.6) }, () => {
        this.showResult = true;
      });
    }, 500);
  }

  @Builder
  chestFigure() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Stack() {
          Column()
            .width(96)
            .height(56)
            .linearGradient({ direction: GradientDirection.Bottom, colors: [['#E0A800', 0], ['#B8860B', 1]] })
            .borderRadius({ topLeft: 4, topRight: 4, bottomLeft: 12, bottomRight: 12 })
          Row({ space: 52 }) {
            Column().width(8).height(56).backgroundColor('#8B5A2B')
            Column().width(8).height(56).backgroundColor('#8B5A2B')
          }

          Stack() {
            Circle().width(6).height(6).fill('#8B5A2B').margin({ top: 4 })
          }
          .width(18)
          .height(20)
          .backgroundColor('#FFDE00')
          .borderRadius(4)
          .translate({ y: -18 })
        }
        .width(96)
        .height(56)
      }
      .padding({ top: 30 })

      if (this.lid > 0.5) {
        Ellipse().width(84).height(16).fill('#FFF3B0').margin({ top: 24 })
      }
      Stack() {
        Row({ space: 52 }) {
          Column().width(8).height(32).backgroundColor('#8B5A2B')
          Column().width(8).height(32).backgroundColor('#8B5A2B')
        }
      }
      .width(102)
      .height(32)
      .linearGradient({ direction: GradientDirection.Bottom, colors: [['#FFC800', 0], ['#E0A800', 1]] })
      .borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 4, bottomRight: 4 })
      .rotate({ x: 1, y: 0, z: 0, angle: -115 * this.lid, centerY: '100%', perspective: 200 })
    }
    .width(110)
    .height(90)
  }

  build() {
    Stack() {
      Column().width('100%').height('100%').backgroundColor('#66000000').onClick(() => {
        if (this.showResult) {
          this.onDismiss();
        }
      })
      Column({ space: 20 }) {
        Stack() {
          if (!this.opened) {
            Circle().width(130).height(130).fill(alpha(C.bee, 0.25)).scale({ x: this.glowScale, y: this.glowScale })
          } else {
            Circle()
              .width(this.tier === 'epic' ? 150 : (this.tier === 'rare' ? 140 : 130))
              .height(this.tier === 'epic' ? 150 : (this.tier === 'rare' ? 140 : 130))
              .fill(alpha(this.tierColor(), this.tier === 'common' ? 0.22 : 0.3))
              .shadow({ radius: this.tier === 'common' ? 0 : 20, color: alpha(this.tierColor(), 0.55) })
            if (this.tier === 'epic') {
              Circle().width(132).height(132).fill(Color.Transparent).stroke(alpha(C.bee, 0.85)).strokeWidth(3)
            }
          }
          this.chestFigure()
          if (this.burst) {
            ForEach(this.angles, (a: number, i: number) => {
              DuoIcon({ name: 'gem', sz: 8 + (i % 4) * 2, color: i % 2 === 0 ? (this.tier === 'epic' ? C.beetle : C.sea) : C.bee })
                .opacity(this.flown ? 0 : 1)
                .translate({
                  x: this.flown ? Math.cos(a) * (46 + (i * 7) % 40) : 0,
                  y: this.flown ? Math.sin(a) * (46 + (i * 7) % 40) * 0.8 - 22 : -6
                })
                .rotate({ angle: this.flown ? 90 + (i * 37) % 150 : 0 })
            }, (a: number, i: number) => `${i}`)
          }
        }
        .width(150)
        .height(130)
        .translate({ y: this.opened ? 0 : this.breathe })
        .onClick(() => this.open())

        if (!this.opened) {
          Text('点击打开宝箱！').fontSize(F.button).fontWeight(W.heavy).fontColor(C.ink)
          ChunkyButton({ label: '打开', variant: 'primary', onTap: () => this.open() })
            .padding({ left: 40, right: 40 })
        } else if (this.showResult) {
          Column({ space: 8 }) {
            if (this.tier !== 'common') {
              Text(this.tier === 'epic' ? '史诗！' : '稀有！')
                .fontSize(F.subhead)
                .fontWeight(W.bold)
                .fontColor(this.tierColor())
                .padding({ left: 14, right: 14, top: 5, bottom: 5 })
                .backgroundColor(alpha(this.tierColor(), 0.14))
                .borderRadius(999)
            }
            Row({ space: 8 }) {
              DuoIcon({ name: 'gem', sz: 30, color: C.beetle })
              Text(`+${this.gems} 宝石`).fontSize(F.title).fontWeight(W.heavy).fontColor(C.beetle)
            }
          }

          ChunkyButton({ label: '收下', variant: 'primary', onTap: () => this.onDismiss() })
            .padding({ left: 40, right: 40 })
        }
      }
      .padding(32)
      .width('80%')
      .backgroundColor(C.surface)
      .borderRadius(R.large)
      .border({ width: 2, color: C.border, radius: R.large })

      if (this.confetti) {
        Confetti({ active: true, burstMs: 900 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
