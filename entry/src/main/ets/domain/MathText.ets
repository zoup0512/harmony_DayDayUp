// 轻量 LaTeX → 纯文本渲染（MathText.swift 的逐行镜像）。

const SYMBOL_COMMANDS: Map<string, string> = new Map<string, string>([
  ['times', '×'], ['div', '÷'], ['cdot', '·'], ['pm', '±'],
  ['le', '≤'], ['leq', '≤'], ['ge', '≥'], ['geq', '≥'],
  ['ne', '≠'], ['neq', '≠'], ['approx', '≈'],
  ['bigcirc', '◯'], ['square', '□'], ['blacksquare', '■'], ['Box', '□'], ['triangle', '△'],
  ['angle', '∠'], ['pi', 'π'], ['circ', '°'], ['rightarrow', '→'], ['leftrightarrow', '↔'],
  ['quad', ' '], ['qquad', ' '], ['left', ''], ['right', '']
]);

const SUPERSCRIPTS: Map<string, string> = new Map<string, string>([
  ['0', '⁰'], ['1', '¹'], ['2', '²'], ['3', '³'], ['4', '⁴'], ['5', '⁵'], ['6', '⁶'], ['7', '⁷'], ['8', '⁸'],
  ['9', '⁹'], ['+', '⁺'], ['-', '⁻'], ['=', '⁼'], ['(', '⁽'], [')', '⁾'], ['n', 'ⁿ']
]);

const SUBSCRIPTS: Map<string, string> = new Map<string, string>([
  ['0', '₀'], ['1', '₁'], ['2', '₂'], ['3', '₃'], ['4', '₄'], ['5', '₅'], ['6', '₆'], ['7', '₇'], ['8', '₈'],
  ['9', '₉'], ['+', '₊'], ['-', '₋'], ['=', '₌'], ['(', '₍'], [')', '₎']
]);

class Parsed {
  text: string;
  next: number;

  constructor(text: string, next: number) {
    this.text = text;
    this.next = next;
  }
}

function isEscaped(chars: string[], index: number): boolean {
  let previous = index - 1;
  let slashes = 0;
  while (previous >= 0 && chars[previous] === '\\') {
    slashes++;
    previous--;
  }
  return slashes % 2 === 1;
}

function findClosingDollar(chars: string[], from: number, isBlock: boolean): number {
  for (let i = from; i < chars.length; i++) {
    if (chars[i] === '$' && !isEscaped(chars, i)) {
      if (!isBlock) {
        return i;
      }
      if (i + 1 < chars.length && chars[i + 1] === '$') {
        return i;
      }
    }
  }
  return -1;
}

function findClosingPair(chars: string[], from: number, closer: string): number {
  for (let i = from; i + 1 < chars.length; i++) {
    if (chars[i] === '\\' && chars[i + 1] === closer && !isEscaped(chars, i)) {
      return i;
    }
  }
  return -1;
}

function parseBraceGroup(chars: string[], start: number): Parsed | null {
  if (start >= chars.length || chars[start] !== '{') {
    return null;
  }
  let depth = 1;
  let i = start + 1;
  while (i < chars.length) {
    if (chars[i] === '\\' && i + 1 < chars.length) {
      i += 2;
      continue;
    }
    if (chars[i] === '{') {
      depth++;
    }
    if (chars[i] === '}') {
      depth--;
      if (depth === 0) {
        return new Parsed(chars.slice(start + 1, i).join(''), i + 1);
      }
    }
    i++;
  }
  return null;
}

function isAsciiDigits(s: string): boolean {
  return s.length > 0 && /^[0-9]+$/.test(s);
}

function renderFraction(numerator: string, denominator: string): string {
  if (isAsciiDigits(numerator) && isAsciiDigits(denominator)) {
    const sup = Array.from(numerator).map((c: string) => SUPERSCRIPTS.get(c) ?? c).join('');
    const sub = Array.from(denominator).map((c: string) => SUBSCRIPTS.get(c) ?? c).join('');
    return sup + '\u2044' + sub;
  }
  return numerator + '/' + denominator;
}

function mapScript(arg: string, isSuperscript: boolean): string {
  if (arg.length === 0) {
    return '';
  }
  const table = isSuperscript ? SUPERSCRIPTS : SUBSCRIPTS;
  let mapped = '';
  for (const ch of Array.from(arg)) {
    const m = table.get(ch);
    if (m === undefined) {
      return (isSuperscript ? '^' : '_') + arg;
    }
    mapped += m;
  }
  return mapped;
}

class Renderer {
  out: string = '';

  renderCommand(chars: string[], start: number): number {
    if (start >= chars.length) {
      return start;
    }
    const c = chars[start];
    if (!/\p{L}/u.test(c)) {
      if (c === '%') {
        this.out += '%';
      } else if (c === ',' || c === ';' || c === ' ') {
        this.out += ' ';
      } else {
        this.out += c;
      }
      return start + 1;
    }
    let end = start;
    while (end < chars.length && /[A-Za-z]/.test(chars[end])) {
      end++;
    }
    const name = chars.slice(start, end).join('');
    if (name === 'frac' || name === 'dfrac' || name === 'tfrac') {
      const num = parseBraceGroup(chars, end);
      const den = num !== null ? parseBraceGroup(chars, num.next) : null;
      if (num !== null && den !== null) {
        this.out += renderFraction(renderMath(num.text), renderMath(den.text));
        return den.next;
      }
      this.out += name;
      return end;
    }
    if (name === 'dot' || name === 'text' || name === 'mathrm') {
      const g = parseBraceGroup(chars, end);
      if (g !== null) {
        const rendered = renderMath(g.text);
        this.out += name === 'dot' ? Array.from(rendered).map((ch: string) => ch + '\u0307').join('') : rendered;
        return g.next;
      }
    }
    const symbol = SYMBOL_COMMANDS.get(name);
    this.out += symbol !== undefined ? symbol : name;
    return end;
  }
}

function parseScriptArgument(chars: string[], start: number): Parsed {
  if (start >= chars.length) {
    return new Parsed('', start);
  }
  if (chars[start] === '{') {
    const g = parseBraceGroup(chars, start);
    if (g !== null) {
      return new Parsed(renderMath(g.text), g.next);
    }
    return new Parsed('', start + 1);
  }
  if (chars[start] === '\\') {
    const r = new Renderer();
    const next = r.renderCommand(chars, start + 1);
    return new Parsed(r.out, next);
  }
  return new Parsed(chars[start], start + 1);
}

function renderMath(latex: string): string {
  const chars = Array.from(latex);
  const r = new Renderer();
  let i = 0;
  while (i < chars.length) {
    const c = chars[i];
    if (c === '\\') {
      i = r.renderCommand(chars, i + 1);
    } else if (c === '^' || c === '_') {
      const isSup = c === '^';
      const p = parseScriptArgument(chars, i + 1);
      r.out += (isSup && p.text === '°') ? '°' : mapScript(p.text, isSup);
      i = p.next;
    } else if (c === '{' || c === '}') {
      i++;
    } else {
      r.out += c;
      i++;
    }
  }
  return r.out;
}

/** 把题干/解析中的 $...$、$$...$$、\(...\)、\[...\] 公式段渲染成可读文本。 */
export function renderMathText(text: string | null | undefined): string {
  if (text === null || text === undefined) {
    return '';
  }
  if (!(text.includes('$') || text.includes('\\(') || text.includes('\\['))) {
    return text;
  }
  const chars = Array.from(text);
  let out = '';
  let i = 0;
  while (i < chars.length) {
    if (chars[i] === '$' && !isEscaped(chars, i)) {
      const isBlock = i + 1 < chars.length && chars[i + 1] === '$';
      const open = isBlock ? 2 : 1;
      const end = findClosingDollar(chars, i + open, isBlock);
      if (end >= 0) {
        out += renderMath(chars.slice(i + open, end).join(''));
        i = end + open;
      } else {
        out += chars.slice(i).join('');
        break;
      }
    } else if (chars[i] === '\\' && !isEscaped(chars, i) && i + 1 < chars.length &&
      (chars[i + 1] === '(' || chars[i + 1] === '[')) {
      const closer = chars[i + 1] === '(' ? ')' : ']';
      const end = findClosingPair(chars, i + 2, closer);
      if (end >= 0) {
        out += renderMath(chars.slice(i + 2, end).join(''));
        i = end + 2;
      } else {
        out += chars.slice(i).join('');
        break;
      }
    } else {
      out += chars[i];
      i++;
    }
  }
  return out;
}
