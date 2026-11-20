// 判题 —— Grade.swift / core grade.ts 的镜像。
import { Question } from '../models/Types';

const TRUE_VALUES: Set<string> = new Set<string>(['对', '正确', 'true', 't', '✓', '√', 'y', 'yes']);
const FALSE_VALUES: Set<string> = new Set<string>(['错', '错误', 'false', 'f', '✗', '×', 'n', 'no']);

export function normalizeAnswer(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, '')
    .replace(/，/g, ',').replace(/。/g, '.').replace(/（/g, '(').replace(/）/g, ')').replace(/：/g, ':');
}

function normalizeNumeric(s: string): string {
  return normalizeAnswer(s).replace(/[^\d\-./%a-z]/g, '').replace(/^0+(\d)/, '$1');
}

function normalizeText(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, '').replace(/[，。！？：；,.!?:;()（）"'`]/g, '');
}

function normalizeWordOrder(s: string): string {
  return s.trim().replace(/，/g, ',').replace(/\s+/g, '');
}

export function matchingPairs(s: string): Map<string, string> {
  const map = new Map<string, string>();
  const cleaned = s.trim().replace(/，/g, ',').replace(/\s+/g, '');
  if (cleaned.length === 0) {
    return map;
  }
  for (const pair of cleaned.split(',')) {
    const idx = pair.indexOf('-');
    if (idx > 0 && idx < pair.length - 1) {
      map.set(pair.substring(0, idx).toUpperCase(), pair.substring(idx + 1));
    }
  }
  return map;
}

function stripOptionPrefix(text: string): string {
  return text.replace(/^[A-Da-d][.、]\s*/, '');
}

export function correctChoiceLetter(question: Question): string | null {
  const correct = question.answer.trim();
  const options = question.options ?? [];
  let index = options.findIndex((o: string) => o.trim() === correct);
  if (index < 0) {
    index = options.findIndex((o: string) => normalizeAnswer(o) === normalizeAnswer(correct));
  }
  if (index < 0) {
    index = options.findIndex((o: string) => normalizeAnswer(stripOptionPrefix(o)) === normalizeAnswer(correct));
  }
  if (index >= 0) {
    return String.fromCharCode(65 + index);
  }
  const m = correct.match(/^([A-Da-d])(?:$|[.、]\s*)/);
  if (m === null) {
    return null;
  }
  const label = m[1].toUpperCase();
  return label.charCodeAt(0) - 65 < options.length ? label : null;
}

export function gradeAnswer(question: Question, userAnswer: string): boolean {
  if (userAnswer.trim().length === 0) {
    return false;
  }
  const correct = question.answer;
  switch (question.type) {
    case 'true_false': {
      const u = normalizeAnswer(userAnswer);
      const c = normalizeAnswer(correct);
      const userIsTrue = TRUE_VALUES.has(userAnswer.trim()) || TRUE_VALUES.has(u);
      const userIsFalse = FALSE_VALUES.has(userAnswer.trim()) || FALSE_VALUES.has(u);
      const correctIsTrue = TRUE_VALUES.has(correct.trim()) || TRUE_VALUES.has(c);
      if (userIsTrue || userIsFalse) {
        return userIsTrue === correctIsTrue;
      }
      return u === c;
    }
    case 'choice': {
      const label = correctChoiceLetter(question);
      return label !== null && userAnswer.trim().toUpperCase() === label;
    }
    case 'fill_blank':
    case 'calculation':
    case 'word_problem': {
      if (normalizeAnswer(userAnswer) === normalizeAnswer(correct)) {
        return true;
      }
      const un = normalizeNumeric(userAnswer);
      const cn = normalizeNumeric(correct);
      if (un.length > 0 && cn.length > 0 && un === cn) {
        return true;
      }
      const uf = parseFloat(un);
      const cf = parseFloat(cn);
      return !isNaN(uf) && !isNaN(cf) && Math.abs(uf - cf) < 1e-6;
    }
    case 'fill_blank_text':
      return normalizeText(userAnswer) === normalizeText(correct);
    case 'word_order':
      return normalizeWordOrder(userAnswer) === normalizeWordOrder(correct);
    case 'matching': {
      const u = matchingPairs(userAnswer);
      const c = matchingPairs(correct);
      if (u.size !== c.size) {
        return false;
      }
      let ok = true;
      u.forEach((v: string, k: string) => {
        if (c.get(k) !== v) {
          ok = false;
        }
      });
      return ok;
    }
    default:
      return normalizeAnswer(userAnswer) === normalizeAnswer(correct);
  }
}

/** 连词成句的正确答案可读化：中文直接拼接、含拉丁字母时用空格。 */
export function readableWordOrderAnswer(answer: string): string {
  const parts = answer.split(',').map((s: string) => s.trim()).filter((s: string) => s.length > 0);
  if (parts.length === 0) {
    return answer;
  }
  const hasLatin = parts.some((p: string) => /[A-Za-z]/.test(p));
  return parts.join(hasLatin ? ' ' : '');
}

export function instructionText(type: string): string {
  switch (type) {
    case 'true_false':
      return '判断对错';
    case 'choice':
      return '选择正确答案';
    case 'fill_blank':
      return '填写答案';
    case 'calculation':
      return '计算结果';
    case 'fill_blank_text':
      return '填写答案';
    case 'word_order':
      return '组成正确的句子';
    case 'matching':
      return '将配对连线';
    case 'word_problem':
      return '解答应用题';
    default:
      return '作答';
  }
}
