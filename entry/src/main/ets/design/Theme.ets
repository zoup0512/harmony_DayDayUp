// Duolingo 风设计系统（DuoColors / DuoFont / DuoLayout / Motion 的鸿蒙版）。
// 颜色是响应式的：Palette.dark / theme 一变，所有读到 C.xxx 的组件自动重绘。
import { curves } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { resourceManager } from '@kit.LocalizationKit';
import { UiThemeData } from '../domain/Catalog';

export type ToneName =
  'ink' | 'ink_muted' | 'ink_softer' | 'bg' | 'bg_softer' | 'surface' | 'surface_alt' | 'border' |
  'study_header' | 'reward_surface' | 'reward_border' | 'locked_node_top' | 'locked_node_ledge' |
  'tab_bar_bg' | 'tab_active_ink' | 'reward_button_bg' | 'reward_button_fg' | 'path_locked_top' |
  'path_done_top' | 'path_locked_ledge' | 'path_done_ledge' | 'path_locked_icon' | 'path_done_icon' |
  'path_trail' | 'unit_banner_label' | 'unit_banner_title' | 'unit_banner_action' | 'unit_banner_chip' |
  'unit_banner_gradient_end' | 'unit_banner_shadow' | 'lesson_figure_bg' | 'option_wrong_ink';

const TONE_NAMES: ToneName[] = [
  'ink', 'ink_muted', 'ink_softer', 'bg', 'bg_softer', 'surface', 'surface_alt', 'border', 'study_header',
  'reward_surface', 'reward_border', 'locked_node_top', 'locked_node_ledge', 'tab_bar_bg', 'tab_active_ink',
  'reward_button_bg', 'reward_button_fg', 'path_locked_top', 'path_done_top', 'path_locked_ledge',
  'path_done_ledge', 'path_locked_icon', 'path_done_icon', 'path_trail', 'unit_banner_label',
  'unit_banner_title', 'unit_banner_action', 'unit_banner_chip', 'unit_banner_gradient_end',
  'unit_banner_shadow', 'lesson_figure_bg', 'option_wrong_ink'
];

function argbToHex(v: number): string {
  const h = (v >>> 0).toString(16).toUpperCase().padStart(8, '0');
  return h.startsWith('FF') ? `#${h.substring(2)}` : `#${h}`;
}

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

/** 把 fg 按比例 t 叠到不透明底色 bg 上，得到不透明的 '#RRGGBB'（避免半透明填充透出下层色块）。 */
export function mix(fg: string, bg: string, t: number): string {
  const a = hexToRgb(fg);
  const b = hexToRgb(bg);
  return `#${toHex2(b[0] + (a[0] - b[0]) * t)}${toHex2(b[1] + (a[1] - b[1]) * t)}${toHex2(b[2] + (a[2] - b[2]) * t)}`;
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
  private lightTones: Map<string, string> = new Map<string, string>();
  private darkTones: Map<string, string> = new Map<string, string>();

  load(ctx: common.Context): void {
    const rm = ctx.resourceManager;
    const lightCfg = rm.getOverrideConfiguration();
    lightCfg.colorMode = resourceManager.ColorMode.LIGHT;
    const darkCfg = rm.getOverrideConfiguration();
    darkCfg.colorMode = resourceManager.ColorMode.DARK;
    const lightRm = rm.getOverrideResourceManager(lightCfg);
    const darkRm = rm.getOverrideResourceManager(darkCfg);
    TONE_NAMES.forEach((n: ToneName) => {
      this.lightTones.set(n, argbToHex(lightRm.getColorByNameSync(n)));
      this.darkTones.set(n, argbToHex(darkRm.getColorByNameSync(n)));
    });
  }

  tone(name: ToneName): string {
    return (this.dark ? this.darkTones : this.lightTones).get(name) ?? '#FF00FF';
  }

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

  get primary(): string {
    return this.theme?.primary ?? '#61C63F';
  }

  get primaryDark(): string {
    return this.theme?.primaryDark ?? '#3F9734';
  }

  get secondary(): string {
    return this.theme?.accent ?? this.macaw;
  }

  get secondaryDark(): string {
    const t = this.theme;
    return t !== null ? darken(t.accent) : this.whale;
  }

  get ink(): string {
    return this.tone('ink');
  }

  get inkLight(): string {
    return this.tone('ink_muted');
  }

  get inkMuted(): string {
    return this.inkLight;
  }

  get inkSofter(): string {
    return this.tone('ink_softer');
  }

  get bg(): string {
    const t = this.theme;
    if (t !== null && (t.isDark || !this.dark)) {
      return t.bg;
    }
    return this.tone('bg');
  }

  /** 设置主题与明暗；有变化时返回 true（调用方据此整体重建界面）。 */
  apply(theme: UiThemeData | null, dark: boolean): boolean {
    const effectiveDark = dark || (theme?.isDark ?? false);
    const changed = this.theme !== theme || this.dark !== effectiveDark;
    this.theme = theme;
    this.dark = effectiveDark;
    return changed;
  }

  get bgSofter(): string {
    return this.tone('bg_softer');
  }

  get surface(): string {
    return this.tone('surface');
  }

  get surfaceAlt(): string {
    return this.tone('surface_alt');
  }

  get border(): string {
    return this.tone('border');
  }

  get studyHeader(): string {
    return this.theme === null ? this.tone('study_header') : alpha(this.primary, this.dark ? 0.22 : 0.30);
  }

  get rewardSurface(): string {
    return this.tone('reward_surface');
  }

  get rewardBorder(): string {
    return this.tone('reward_border');
  }

  get lockedNodeTop(): string {
    return this.tone('locked_node_top');
  }

  get lockedNodeLedge(): string {
    return this.tone('locked_node_ledge');
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
  static readonly micro: number = 12;
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

export const CONTENT_MAX_W: number = 680;

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
