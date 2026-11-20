// Duolingo 风设计系统（DuoColors / DuoFont / DuoLayout / Motion 的鸿蒙版）。
// 颜色是响应式的：Palette.dark / theme 一变，所有读到 C.xxx 的组件自动重绘。
import { curves } from '@kit.ArkUI';
import { UiThemeData } from '../domain/Catalog';

function hexToRgb(hex: string): number[] {
  const h = hex.replace('#', '');
  const v = h.length === 8 ? h.substring(2) : h;
  return [parseInt(v.substring(0, 2), 16), parseInt(v.substring(2, 4), 16), parseInt(v.substring(4, 6), 16)];
}

function toHex2(n: number): string {
  const v = Math.max(0, Math.min(255, Math.round(n)));
  return (v < 16 ? '0' : '') + v.toString(16).toUpperCase();
}

/** '#RRGGBB' + 不透明度 → '#AARRGGBB' */
export function alpha(hex: string, a: number): string {
  const rgb = hexToRgb(hex);
  return `#${toHex2(a * 255)}${toHex2(rgb[0])}${toHex2(rgb[1])}${toHex2(rgb[2])}`;
}

/** HSB 亮度下调（DuoColors.darken）。 */
export function darken(hex: string, amount: number = 0.14): string {
  const rgb = hexToRgb(hex).map((x: number) => x / 255);
  const max = Math.max(rgb[0], rgb[1], rgb[2]);
  if (max <= 0) {
    return hex;
  }
  const scale = Math.max(0, max - amount) / max;
  return `#${toHex2(rgb[0] * scale * 255)}${toHex2(rgb[1] * scale * 255)}${toHex2(rgb[2] * scale * 255)}`;
}

@ObservedV2
export class Palette {
  static readonly shared: Palette = new Palette();

  @Trace dark: boolean = false;
  @Trace theme: UiThemeData | null = null;

  // 品牌固定色
  readonly feather: string = '#58CC02';
  readonly treeFrog: string = '#58A700';
  readonly maskGreen: string = '#89E219';
  readonly macaw: string = '#1CB0F6';
  readonly whale: string = '#1899D6';
  readonly iguana: string = '#BBE7FC';
  readonly sea: string = '#14D4F4';
  readonly danger: string = '#FF4B4B';
  readonly dangerDark: string = '#EA2B2B';
  readonly bee: string = '#FFC800';
  readonly fox: string = '#FF9600';
  readonly beetle: string = '#CE82FF';
  readonly eel: string = '#4B4B4B';
  readonly navy: string = '#131F24';
  readonly white: string = '#FFFFFF';

  private a(light: string, dark: string): string {
    return this.dark ? dark : light;
  }

  get primary(): string {
    return this.theme?.primary ?? this.feather;
  }

  get primaryDark(): string {
    return this.theme?.primaryDark ?? this.treeFrog;
  }

  get secondary(): string {
    return this.theme?.accent ?? this.macaw;
  }

  get secondaryDark(): string {
    const t = this.theme;
    return t !== null ? darken(t.accent) : this.whale;
  }

  get ink(): string {
    return this.a('#4B4B4B', '#FFFFFF');
  }

  get inkLight(): string {
    return this.a('#707070', '#93A7AF');
  }

  get inkMuted(): string {
    return this.inkLight;
  }

  get inkSofter(): string {
    return this.a('#AFAFAF', '#52656D');
  }

  get bg(): string {
    return this.a('#FFFFFF', '#131F24');
  }

  get bgSofter(): string {
    return this.a('#E5E5E5', '#37464F');
  }

  get surface(): string {
    return this.a('#FFFFFF', '#202F36');
  }

  get surfaceAlt(): string {
    return this.a('#F7F7F7', '#37464F');
  }

  get border(): string {
    return this.a('#E5E5E5', '#37464F');
  }

  get lockedNodeTop(): string {
    return this.a('#E5E5E5', '#37464F');
  }

  get lockedNodeLedge(): string {
    return this.a('#C4C4C4', '#202F36');
  }
}

export const C: Palette = Palette.shared;

/** 字号阶梯（DuoFont），单位 fp，随系统字体大小缩放。 */
export class F {
  static readonly display: number = 34;
  static readonly title: number = 28;
  static readonly heading: number = 22;
  static readonly subhead: number = 18;
  static readonly body: number = 16;
  static readonly button: number = 17;
  static readonly caption: number = 13;
  static readonly micro: number = 11;
}

/** 字重：heavy=800 / bold=700 / medium=500 / black=900 */
export class W {
  static readonly black: number = 900;
  static readonly heavy: number = 800;
  static readonly bold: number = 700;
  static readonly medium: number = 500;
}

export class R {
  static readonly control: number = 12;
  static readonly card: number = 16;
  static readonly large: number = 20;
}

export class S {
  static readonly xs: number = 4;
  static readonly s: number = 8;
  static readonly m: number = 12;
  static readonly l: number = 16;
  static readonly xl: number = 24;
  static readonly xxl: number = 32;
}

/** SwiftUI spring(response, dampingFraction) 的直接对应。 */
export class Motion {
  static press(): ICurve {
    return curves.springMotion(0.15, 0.7);
  }

  static reveal(): ICurve {
    return curves.springMotion(0.35, 0.72);
  }

  static bounce(): ICurve {
    return curves.springMotion(0.3, 0.55);
  }
}

export const UNIT_PALETTE: string[][] = [
  ['#58CC02', '#46A302'], ['#1CB0F6', '#1899D6'], ['#CE82FF', '#A560E8'],
  ['#FF9600', '#E08600'], ['#00CD9C', '#00B589'], ['#EE5DA9', '#C94A8C']
];

export function unitColors(unitNumber: number): string[] {
  const n = UNIT_PALETTE.length;
  return UNIT_PALETTE[(((unitNumber - 1) % n) + n) % n];
}
