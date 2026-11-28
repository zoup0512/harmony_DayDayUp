// 熊猫「聪聪」：探险插图或答题表情，共用装扮和反应动画。
import { curves } from '@kit.ArkUI';
import { MascotMood, MascotReaction } from '../models/Types';
import { Cosmetics } from '../domain/Catalog';
import { ProgressStore } from '../stores/ProgressStore';
import { Haptics } from '../services/Feedback';
import { SFXEngine } from '../services/Audio';
import { DuoIcon } from './Kit';

const EEL = '#3A3A3A';
const PANDA = '#2E2E2E';
const WHITE = '#FBFBFB';
const SHADE = '#99E9EDEF';

@ComponentV2
export struct Mascot {
  @Param mood: MascotMood = 'happy';
  @Param sz: number = 120;
  @Param reactTo: MascotReaction | undefined = undefined;
  @Param reactKey: number = 0;
  @Param skin: string = '';
  @Param allowsTap: boolean = false;
  @Param still: boolean = false;
  @Param illustrated: boolean = true;

  @Local equippedSkin: string = ProgressStore.shared.equippedMascotSkin;
  @Local breatheY: number = 0;
  @Local breatheScale: number = 1;
  @Local blink: boolean = false;
  @Local gx: number = 0;
  @Local gy: number = 0;
  @Local rScale: number = 1;
  @Local rRot: number = 0;
  @Local rY: number = 0;
  @Local sweat: boolean = false;
  @Local sweatY: number = -4;
  @Local glow: boolean = false;
  @Local armUp: boolean = false;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timers: number[] = [];
  private alive: boolean = true;
  private unsubscribeSkin?: () => void;

  private get activeSkin(): string {
    return this.skin.length > 0 ? this.skin : this.equippedSkin;
  }

  private get explorerImage(): Resource {
    switch (this.activeSkin) {
      case 'skin_graduate':
        return $r('app.media.learning_hero_graduate');
      case 'skin_party':
      case 'skin_crown':
      case 'skin_wizard':
      case 'skin_astronaut':
      case 'skin_pirate':
      case 'skin_headphones':
      case 'skin_laurel':
        return $r('app.media.learning_hero_barehead');
      default:
        return $r('app.media.learning_hero');
    }
  }

  private get needsCanvas(): boolean {
    return !this.illustrated || (this.activeSkin !== Cosmetics.defaultSkin && this.activeSkin !== 'skin_graduate');
  }

  aboutToAppear(): void {
    if (this.skin.length === 0) {
      this.equippedSkin = ProgressStore.shared.equippedMascotSkin;
      this.unsubscribeSkin = ProgressStore.shared.onChange(() => {
        this.equippedSkin = ProgressStore.shared.equippedMascotSkin;
      });
    }
    if (this.still) {
      return;
    }
    this.timers.push(setTimeout(() => this.startBreathing(), 30));
    if (!this.illustrated) {
      this.scheduleBlink();
      this.scheduleGlance();
    }
    if (this.reactTo !== undefined) {
      this.timers.push(setTimeout(() => this.run(this.reactTo as MascotReaction), 120));
    }
  }

  aboutToDisappear(): void {
    this.alive = false;
    this.unsubscribeSkin?.();
    this.timers.forEach((t: number) => clearTimeout(t));
  }

  @Monitor('reactKey')
  onReactKey(): void {
    if (this.reactTo !== undefined) {
      this.run(this.reactTo as MascotReaction);
    }
  }

  @Monitor('mood', 'blink', 'gx', 'gy', 'skin', 'equippedSkin', 'sz', 'illustrated')
  onRedraw(): void {
    if (this.needsCanvas) {
      this.draw();
    }
  }

  private startBreathing(): void {
    this.getUIContext().animateTo({ duration: 2600, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate },
      () => {
        this.breatheY = -3;
        this.breatheScale = 1.02;
      });
    if (!this.illustrated && this.mood === 'wave') {
      this.getUIContext().animateTo({ duration: 550, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate },
        () => {
          this.armUp = true;
        });
    }
  }

  private scheduleBlink(): void {
    const t = setTimeout(() => {
      if (!this.alive) {
        return;
      }
      this.blink = true;
      this.timers.push(setTimeout(() => {
        this.blink = false;
        this.scheduleBlink();
      }, 120));
    }, 2500 + Math.random() * 3500);
    this.timers.push(t);
  }

  private scheduleGlance(): void {
    const t = setTimeout(() => {
      if (!this.alive) {
        return;
      }
      this.gx = Math.random() < 0.5 ? -2.4 : 2.4;
      this.gy = -0.8 + Math.random() * 2;
      this.timers.push(setTimeout(() => {
        this.gx = 0;
        this.gy = 0;
        this.scheduleGlance();
      }, 700));
    }, 8000 + Math.random() * 7000);
    this.timers.push(t);
  }

  private run(reaction: MascotReaction): void {
    const ui = this.getUIContext();
    if (reaction === 'correct') {
      ui.animateTo({ curve: curves.springMotion(0.3, 0.5) }, () => {
        this.rScale = 1.18;
        this.rY = -6;
      });
      this.timers.push(setTimeout(() => ui.animateTo({ curve: curves.springMotion(0.25, 0.6) }, () => {
        this.rScale = 1;
        this.rY = 0;
      }), 200));
    } else if (reaction === 'wrong') {
      this.sweat = true;
      this.sweatY = -4;
      ui.animateTo({ duration: 1100, curve: Curve.EaseOut }, () => {
        this.sweatY = 14;
      });
      ui.animateTo({ curve: curves.springMotion(0.15, 0.4) }, () => {
        this.rRot = -8;
      });
      this.timers.push(setTimeout(() => ui.animateTo({ curve: curves.springMotion(0.15, 0.4) }, () => {
        this.rRot = 8;
      }), 150));
      this.timers.push(setTimeout(() => ui.animateTo({ curve: curves.springMotion(0.2, 0.6) }, () => {
        this.rRot = 0;
      }), 300));
      this.timers.push(setTimeout(() => {
        this.sweat = false;
      }, 1200));
    } else {
      this.glow = true;
      ui.animateTo({ curve: curves.springMotion(0.3, 0.4) }, () => {
        this.rY = -18;
        this.rScale = 1.1;
      });
      this.timers.push(setTimeout(() => ui.animateTo({ curve: curves.springMotion(0.3, 0.5) }, () => {
        this.rY = 0;
        this.rScale = 1;
      }), 350));
      this.timers.push(setTimeout(() => ui.animateTo({ duration: 300 }, () => {
        this.glow = false;
      }), 1400));
    }
  }

  // ---------------- 绘制 ----------------

  private ellipse(cx: number, cy: number, rx: number, ry: number, fill: string): void {
    const c = this.ctx;
    c.beginPath();
    c.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
    c.fillStyle = fill;
    c.fill();
  }

  private circle(cx: number, cy: number, r: number, fill: string): void {
    this.ellipse(cx, cy, r, r, fill);
  }

  private ring(cx: number, cy: number, r: number, stroke: string, width: number, fill: string = ''): void {
    const c = this.ctx;
    c.beginPath();
    c.arc(cx, cy, r, 0, Math.PI * 2);
    if (fill.length > 0) {
      c.fillStyle = fill;
      c.fill();
    }
    c.strokeStyle = stroke;
    c.lineWidth = width;
    c.stroke();
  }

  private curve(x0: number, y0: number, cx: number, cy: number, x1: number, y1: number, width: number,
    color: string = EEL): void {
    const c = this.ctx;
    c.beginPath();
    c.moveTo(x0, y0);
    c.quadraticCurveTo(cx, cy, x1, y1);
    c.strokeStyle = color;
    c.lineWidth = width;
    c.lineCap = 'round';
    c.stroke();
  }

  private line(x0: number, y0: number, x1: number, y1: number, width: number, color: string): void {
    const c = this.ctx;
    c.beginPath();
    c.moveTo(x0, y0);
    c.lineTo(x1, y1);
    c.strokeStyle = color;
    c.lineWidth = width;
    c.lineCap = 'round';
    c.stroke();
  }

  private poly(s: number, pts: number[][], fill: string): void {
    const c = this.ctx;
    c.beginPath();
    pts.forEach((p: number[], i: number) => {
      if (i === 0) {
        c.moveTo(p[0] * s, p[1] * s);
      } else {
        c.lineTo(p[0] * s, p[1] * s);
      }
    });
    c.closePath();
    c.fillStyle = fill;
    c.fill();
  }

  private rrect(x: number, y: number, w: number, h: number, r: number, fill: string): void {
    const c = this.ctx;
    c.beginPath();
    c.moveTo(x + r, y);
    c.arcTo(x + w, y, x + w, y + h, r);
    c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r);
    c.arcTo(x, y, x + w, y, r);
    c.closePath();
    c.fillStyle = fill;
    c.fill();
  }

  private draw(): void {
    const c = this.ctx;
    const s = this.sz / 120;
    c.clearRect(-20, -20, this.sz + 40, this.sz + 40);
    if (this.illustrated) {
      this.drawExplorerAccessory(s);
      return;
    }
    const waving = this.mood === 'wave' && !this.still;
    this.circle(34 * s, 30 * s, 13 * s, PANDA);
    this.circle(86 * s, 30 * s, 13 * s, PANDA);
    this.ellipse(22 * s, 78 * s, 9 * s, 15 * s, PANDA);
    if (!waving) {
      this.ellipse(98 * s, 78 * s, 9 * s, 15 * s, PANDA);
    }
    this.ellipse(46 * s, 104 * s, 11 * s, 8 * s, PANDA);
    this.ellipse(74 * s, 104 * s, 11 * s, 8 * s, PANDA);
    this.ellipse(60 * s, 82 * s, 34 * s, 30 * s, WHITE);
    this.ellipse(60 * s, 50 * s, 40 * s, 37 * s, WHITE);
    this.ellipse(60 * s, 84 * s, 20 * s, 18 * s, SHADE);
    this.ellipse(44 * s, 50 * s, 12 * s, 15 * s, PANDA);
    this.ellipse(76 * s, 50 * s, 12 * s, 15 * s, PANDA);
    this.circle(45 * s, 48 * s, 8.5 * s, WHITE);
    this.circle(75 * s, 48 * s, 8.5 * s, WHITE);
    if (this.blink && (this.mood === 'happy' || this.mood === 'think' || this.mood === 'wave')) {
      this.curve(32 * s, 48 * s, 44 * s, 52 * s, 56 * s, 48 * s, 3 * s);
      this.curve(64 * s, 48 * s, 76 * s, 52 * s, 88 * s, 48 * s, 3 * s);
    } else {
      this.drawEyes(s);
    }
    c.beginPath();
    c.moveTo(54 * s, 60 * s);
    c.quadraticCurveTo(60 * s, 58 * s, 66 * s, 60 * s);
    c.quadraticCurveTo(66 * s, 66 * s, 60 * s, 68 * s);
    c.quadraticCurveTo(54 * s, 66 * s, 54 * s, 60 * s);
    c.closePath();
    c.fillStyle = PANDA;
    c.fill();
    c.beginPath();
    c.moveTo(60 * s, 68 * s);
    c.lineTo(60 * s, 72 * s);
    c.quadraticCurveTo(64 * s, 76 * s, 68 * s, 74 * s);
    c.moveTo(60 * s, 72 * s);
    c.quadraticCurveTo(56 * s, 76 * s, 52 * s, 74 * s);
    c.strokeStyle = PANDA;
    c.lineWidth = 2 * s;
    c.lineCap = 'round';
    c.stroke();
    if (this.mood === 'embarrassed') {
      this.ellipse(32 * s, 62 * s, 6 * s, 3.5 * s, '#B3FF9AA8');
      this.ellipse(88 * s, 62 * s, 6 * s, 3.5 * s, '#B3FF9AA8');
    }
    this.drawAccessory(s, this.activeSkin);
  }

  private drawExplorerAccessory(s: number): void {
    // 120 × 120 等比画框中的双眼中心、头顶和领巾扣；插图中的脸向右上倾斜。
    const skin = this.activeSkin;
    const c = this.ctx;
    c.save();
    c.scale(s, s);
    switch (skin) {
      case 'skin_glasses':
      case 'skin_sunglasses':
        c.translate(65.8, 38.7);
        c.rotate(-0.25);
        c.scale(0.70, 0.70);
        c.translate(-60, -48);
        break;
      case 'skin_pirate':
        c.translate(65, 40);
        c.rotate(-0.24);
        c.scale(0.72, 0.84);
        c.translate(-60, -48);
        break;
      case 'skin_bowtie':
        c.translate(70, 64);
        c.rotate(-0.16);
        c.scale(0.80, 0.80);
        c.translate(-60, -89);
        break;
      case 'skin_astronaut':
      case 'skin_headphones':
      case 'skin_laurel':
        c.translate(58, 36);
        c.rotate(-0.25);
        c.scale(0.82, 0.82);
        c.translate(-60, -43);
        break;
      default:
        c.translate(56, 27);
        c.rotate(-0.25);
        c.scale(0.66, 0.66);
        c.translate(-60, -26);
        break;
    }
    this.drawAccessory(1, skin);
    c.restore();
  }

  private drawEyes(s: number): void {
    const gx = this.gx;
    const gy = this.gy;
    switch (this.mood) {
      case 'cheer':
        this.curve(36 * s, 48 * s, 44 * s, 40 * s, 52 * s, 48 * s, 3 * s);
        this.curve(68 * s, 48 * s, 76 * s, 40 * s, 84 * s, 48 * s, 3 * s);
        break;
      case 'sad':
        this.circle(44 * s, 50 * s, 4 * s, EEL);
        this.circle(76 * s, 50 * s, 4 * s, EEL);
        this.line(32 * s, 38 * s, 50 * s, 42 * s, 2.5 * s, EEL);
        this.line(88 * s, 38 * s, 70 * s, 42 * s, 2.5 * s, EEL);
        break;
      case 'think':
        this.circle((44 + gx) * s, (48 + gy) * s, 5 * s, EEL);
        this.circle((45.5 + gx) * s, (46.5 + gy) * s, 1.5 * s, '#FFFFFF');
        this.curve(68 * s, 48 * s, 76 * s, 46 * s, 84 * s, 48 * s, 2.5 * s);
        break;
      case 'surprise':
        this.circle(44 * s, 48 * s, 7 * s, EEL);
        this.circle(46 * s, 46 * s, 2 * s, '#FFFFFF');
        this.circle(76 * s, 48 * s, 7 * s, EEL);
        this.circle(78 * s, 46 * s, 2 * s, '#FFFFFF');
        break;
      case 'proud':
        this.circle(44 * s, 48 * s, 5 * s, EEL);
        this.circle(45.5 * s, 46.5 * s, 1.8 * s, '#FFFFFF');
        this.circle(42 * s, 50 * s, 0.9 * s, '#FFFFFF');
        this.circle(76 * s, 48 * s, 5 * s, EEL);
        this.circle(77.5 * s, 46.5 * s, 1.8 * s, '#FFFFFF');
        this.circle(74 * s, 50 * s, 0.9 * s, '#FFFFFF');
        this.curve(32 * s, 38 * s, 40 * s, 34 * s, 50 * s, 40 * s, 2.5 * s);
        this.curve(88 * s, 38 * s, 80 * s, 34 * s, 70 * s, 40 * s, 2.5 * s);
        break;
      case 'embarrassed':
        this.circle((44 + gx) * s, (50 + gy) * s, 3.5 * s, EEL);
        this.circle((76 + gx) * s, (50 + gy) * s, 3.5 * s, EEL);
        break;
      default:
        this.circle((44 + gx) * s, (48 + gy) * s, 5 * s, EEL);
        this.circle((45.5 + gx) * s, (46.5 + gy) * s, 1.5 * s, '#FFFFFF');
        this.circle((76 + gx) * s, (48 + gy) * s, 5 * s, EEL);
        this.circle((77.5 + gx) * s, (46.5 + gy) * s, 1.5 * s, '#FFFFFF');
    }
  }

  private drawAccessory(s: number, skin: string): void {
    const gold = '#FFC800';
    const goldDark = '#E0A800';
    const c = this.ctx;
    switch (skin) {
      case 'skin_graduate':
        this.poly(s, [[42, 16], [78, 16], [76, 26], [44, 26]], '#2E2E2E');
        this.poly(s, [[60, 2], [100, 17], [60, 32], [20, 17]], '#1F1F1F');
        this.curve(96 * s, 18 * s, 103 * s, 25 * s, 100 * s, 34 * s, 2.4 * s, gold);
        this.circle(100 * s, 37 * s, 4 * s, gold);
        break;
      case 'skin_glasses':
        this.ring(45 * s, 48 * s, 12 * s, '#4A3A2A', 2.6 * s);
        this.ring(75 * s, 48 * s, 12 * s, '#4A3A2A', 2.6 * s);
        this.line(57 * s, 47 * s, 63 * s, 47 * s, 2.4 * s, '#4A3A2A');
        break;
      case 'skin_sunglasses':
        this.rrect(31 * s, 39 * s, 27 * s, 19 * s, 7 * s, '#22262B');
        this.rrect(62 * s, 39 * s, 27 * s, 19 * s, 7 * s, '#22262B');
        this.line(58 * s, 45 * s, 62 * s, 45 * s, 4 * s, '#22262B');
        this.line(36 * s, 54 * s, 46 * s, 42 * s, 2.2 * s, '#80FFFFFF');
        break;
      case 'skin_crown':
        this.poly(s, [[30, 28], [40, 10], [50, 22], [60, 6], [70, 22], [80, 10], [90, 28]], gold);
        this.rrect(30 * s, 25 * s, 60 * s, 8 * s, 3 * s, goldDark);
        this.circle(60 * s, 8 * s, 3.2 * s, '#FF6B6B');
        break;
      case 'skin_party':
        this.poly(s, [[60, -4], [44, 28], [76, 28]], '#FF6B9D');
        this.poly(s, [[60, -4], [52, 12], [68, 12]], '#FFD166');
        this.poly(s, [[48, 22], [72, 22], [76, 28], [44, 28]], '#4ECDC4');
        this.circle(60 * s, -6 * s, 5 * s, '#FFFFFF');
        break;
      case 'skin_wizard':
        this.poly(s, [[62, -8], [38, 30], [86, 30]], '#7C3AED');
        this.rrect(34 * s, 26 * s, 56 * s, 9 * s, 4 * s, '#5B21B6');
        this.poly(s, [[58, 4], [60.6, 10], [67, 10], [62, 14], [64, 20], [58, 16], [52, 20], [54, 14], [49, 10],
          [55.4, 10]], gold);
        break;
      case 'skin_astronaut':
        this.ring(60 * s, 48 * s, 46 * s, '#DCE9F0', 4 * s, '#4DBFE3F7');
        c.beginPath();
        c.arc(60 * s, 48 * s, 38 * s, 200 * Math.PI / 180, 250 * Math.PI / 180);
        c.strokeStyle = '#BFFFFFFF';
        c.lineWidth = 5 * s;
        c.lineCap = 'round';
        c.stroke();
        break;
      case 'skin_pirate':
        this.poly(s, [[18, 26], [60, 4], [102, 26], [96, 32], [24, 32]], '#1F2328');
        this.rrect(22 * s, 24 * s, 76 * s, 9 * s, 4 * s, '#8B0000');
        this.circle(60 * s, 17 * s, 5 * s, '#FFFFFF');
        this.circle(45 * s, 48 * s, 11 * s, '#1F2328');
        this.line(24 * s, 40 * s, 92 * s, 44 * s, 2.6 * s, '#1F2328');
        break;
      case 'skin_headphones':
        c.beginPath();
        c.arc(60 * s, 46 * s, 44 * s, 200 * Math.PI / 180, 340 * Math.PI / 180);
        c.strokeStyle = '#1CB0F6';
        c.lineWidth = 6 * s;
        c.lineCap = 'round';
        c.stroke();
        this.rrect(10 * s, 40 * s, 16 * s, 26 * s, 7 * s, '#1899D6');
        this.rrect(94 * s, 40 * s, 16 * s, 26 * s, 7 * s, '#1899D6');
        break;
      case 'skin_laurel':
        for (const dir of [-1, 1]) {
          c.beginPath();
          if (dir > 0) {
            c.arc(60 * s, 52 * s, 42 * s, 300 * Math.PI / 180, 380 * Math.PI / 180);
          } else {
            c.arc(60 * s, 52 * s, 42 * s, 240 * Math.PI / 180, 160 * Math.PI / 180, true);
          }
          c.strokeStyle = '#4C9A2A';
          c.lineWidth = 3.4 * s;
          c.lineCap = 'round';
          c.stroke();
          for (let k = 0; k < 4; k++) {
            const ang = ((dir > 0 ? 310 : 230) + k * (dir > 0 ? 18 : -18)) * Math.PI / 180;
            this.ellipse((60 + Math.cos(ang) * 42) * s, (52 + Math.sin(ang) * 42) * s, 5 * s, 3 * s, '#6ABE30');
          }
        }
        break;
      case 'skin_bowtie':
        this.poly(s, [[44, 88], [56, 82], [56, 96], [44, 94]], '#E5484D');
        this.poly(s, [[76, 88], [64, 82], [64, 96], [76, 94]], '#E5484D');
        this.circle(60 * s, 89 * s, 4.6 * s, '#B8353A');
        break;
      default:
        break;
    }
  }

  private tapReaction(): void {
    Haptics.tap();
    SFXEngine.shared.play('tap');
    const pool: MascotReaction[] = ['correct', 'correct', 'levelup'];
    this.run(pool[Math.floor(Math.random() * pool.length)]);
  }

  build() {
    Stack() {
      if (this.glow) {
        Circle()
          .width(this.sz * 1.4)
          .height(this.sz * 1.4)
          .fill(Color.Transparent)
          .radialGradient({
            center: [this.sz * 0.7, this.sz * 0.7],
            radius: this.sz * 0.7,
            colors: [['#8CFFC800', 0], ['#00FFC800', 1]]
          })
          .transition(TransitionEffect.OPACITY)
      }
      if (this.illustrated) {
        Image(this.explorerImage).width(this.sz).height(this.sz).objectFit(ImageFit.Contain)
      }
      if (this.needsCanvas) {
        Canvas(this.ctx)
          .width(this.sz)
          .height(this.sz)
          .onReady(() => this.draw())
      }
      if (!this.illustrated && this.mood === 'wave' && !this.still) {
        Ellipse()
          .width(this.sz * 18 / 120)
          .height(this.sz * 30 / 120)
          .fill(PANDA)
          .rotate({ angle: this.armUp ? -26 : 6, centerX: '50%', centerY: '0%' })
          .position({ x: this.sz * 89 / 120, y: this.sz * 63 / 120 })
      }
      if (this.sweat) {
        DuoIcon({ name: 'drop', sz: this.sz * 0.1, color: '#7EC4F0' })
          .position({ x: this.sz * 0.77, y: this.sz * 0.15 + this.sweatY })
      }
    }
    .width(this.sz)
    .height(this.sz)
    .scale({ x: this.rScale * this.breatheScale, y: this.rScale * this.breatheScale })
    .translate({ y: this.rY + this.breatheY })
    .rotate({ angle: this.rRot })
    .onClick(() => {
      if (this.allowsTap) {
        this.tapReaction();
      }
    })
    .accessibilityText('聪聪')
  }
}
