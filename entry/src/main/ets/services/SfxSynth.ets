// 合成音效（SFXEngine.swift 的 FM 铃声合成器移植）：离线渲染成 16-bit PCM WAV。

export const SFX_SAMPLE_RATE: number = 22050;

class SynthEvent {
  startTime: number = 0;
  duration: number = 0.3;
  frequency: number = 440;
  endFrequency: number = 0;
  volume: number = 0.25;
  attack: number = 0.004;
  waveform: number = 0; // 0 sine, 1 triangle, 2 noise
  modRatio: number = 0;
  modDepth: number = 0;
}

function ev(start: number, duration: number, freq: number, volume: number, modRatio: number = 0,
  modDepth: number = 0): SynthEvent {
  const e = new SynthEvent();
  e.startTime = start;
  e.duration = duration;
  e.frequency = freq;
  e.volume = volume;
  e.modRatio = modRatio;
  e.modDepth = modDepth;
  return e;
}

function glide(start: number, duration: number, freq: number, endFreq: number, volume: number, attack: number,
  waveform: number): SynthEvent {
  const e = ev(start, duration, freq, volume);
  e.endFrequency = endFreq;
  e.attack = attack;
  e.waveform = waveform;
  return e;
}

function click(start: number, volume: number): SynthEvent {
  const e = ev(start, 0.005, 1000, volume);
  e.attack = 0.0004;
  e.waveform = 2;
  return e;
}

function detuned(events: SynthEvent[], cents: number = 7, gain: number = 0.32): SynthEvent[] {
  const ratio = Math.pow(2, cents / 1200);
  return events.map((e: SynthEvent) => {
    const d = ev(e.startTime, e.duration, e.frequency * ratio, e.volume * gain, e.modRatio, e.modDepth);
    d.endFrequency = e.endFrequency * ratio;
    d.attack = e.attack;
    d.waveform = e.waveform;
    return d;
  });
}

function buildEvents(name: string): SynthEvent[] {
  switch (name) {
    case 'correct': {
      const bells = [ev(0, 0.42, 739.99, 0.30, 3.01, 180), ev(0.11, 0.55, 932.33, 0.34, 3.01, 200),
        ev(0.11, 0.35, 1864.66, 0.08, 4.5, 60)];
      return bells.concat(detuned(bells)).concat([click(0, 0.12)]);
    }
    case 'wrong':
      return [glide(0, 0.32, 329.63, 277.18, 0.26, 0.008, 1), glide(0, 0.34, 164.81, 138.59, 0.18, 0.01, 0)];
    case 'tap': {
      const e = ev(0, 0.04, 2400, 0.10);
      e.attack = 0.0005;
      return [e];
    }
    case 'complete': {
      const arp = [ev(0, 0.6, 523.25, 0.28, 3.01, 160), ev(0.12, 0.6, 659.25, 0.28, 3.01, 160),
        ev(0.24, 0.6, 783.99, 0.28, 3.01, 160), ev(0.36, 0.6, 1046.5, 0.28, 3.01, 160)];
      return arp.concat(detuned(arp, 7, 0.28)).concat([ev(0.36, 0.8, 2093, 0.14, 4.2, 80), click(0, 0.10)]);
    }
    case 'star': {
      const bells = [ev(0, 0.28, 1760, 0.28, 3.5, 100), ev(0.08, 0.32, 2637, 0.22, 3.5, 90)];
      return bells.concat(detuned(bells, 6, 0.30)).concat([click(0, 0.09)]);
    }
    case 'heartLoss':
      return [ev(0, 0.35, 523.25, 0.24, 2.8, 140), glide(0.05, 0.38, 440, 220, 0.18, 0.005, 1)];
    case 'combo':
      return [ev(0, 0.34, 523.25, 0.26, 3.01, 150), ev(0.07, 0.34, 659.25, 0.26, 3.01, 150),
        ev(0.14, 0.34, 783.99, 0.26, 3.01, 150)];
    case 'unlock':
      return [ev(0, 0.9, 1046.5, 0.22, 3.5, 120), ev(0.02, 0.9, 2093, 0.11, 3.5, 120),
        ev(0.04, 0.9, 1046.5 * 3.01, 0.0733, 3.5, 120), ev(0.06, 1.0, 523.25, 0.10, 2.01, 80)];
    case 'progressTick':
      return [ev(0, 0.08, 1760, 0.12, 3.01, 60)];
    case 'pairMatch':
      return [ev(0, 0.20, 659.25, 0.22, 3.01, 110), ev(0.07, 0.30, 880.0, 0.26, 3.01, 130)];
    case 'purchase':
      return [click(0, 0.10), ev(0, 0.18, 987.77, 0.24, 4.0, 90), ev(0.09, 0.34, 1318.51, 0.26, 4.0, 110)];
    case 'questClaim':
      return [ev(0, 0.20, 783.99, 0.26, 3.01, 140), ev(0.08, 0.32, 1046.5, 0.28, 3.01, 150)];
    case 'chestOpen':
      return [ev(0, 0.5, 523.25, 0.26, 3.01, 150), ev(0.08, 0.5, 659.25, 0.26, 3.01, 150),
        ev(0.16, 0.5, 783.99, 0.26, 3.01, 150), ev(0.24, 0.5, 1046.5, 0.26, 3.01, 150),
        ev(0.24, 0.7, 2093, 0.12, 4.5, 70), ev(0.32, 0.6, 3135.96, 0.07, 5.0, 50)];
    default:
      return [];
  }
}

/** 渲染一条音效为 WAV 字节；pitchStep 半音升调（连对升调）。 */
export function renderSfxWav(name: string, pitchStep: number): ArrayBuffer {
  const events = buildEvents(name);
  const step = Math.max(0, Math.min(pitchStep, 8));
  const ratio = Math.pow(2, step / 12);
  let end = 0;
  for (const e of events) {
    e.frequency *= ratio;
    e.endFrequency *= ratio;
    end = Math.max(end, e.startTime + e.duration);
  }
  const sr = SFX_SAMPLE_RATE;
  const total = Math.ceil((end + 0.02) * sr);
  const mix = new Float32Array(total);
  for (const e of events) {
    const startSample = Math.floor(e.startTime * sr);
    const count = Math.floor(e.duration * sr);
    const attackSamples = Math.max(1, Math.floor(e.attack * sr));
    let phase = 0;
    let modPhase = 0;
    let noise = 0x9E3779B9;
    for (let i = 0; i < count; i++) {
      const idx = startSample + i;
      if (idx >= total) {
        break;
      }
      const t = i / sr;
      const progress = t / e.duration;
      const freq = e.endFrequency > 0 ? e.frequency * Math.pow(e.endFrequency / e.frequency, progress) : e.frequency;
      const env = i < attackSamples ? e.volume * i / attackSamples :
        e.volume * Math.exp(-4 * (t - e.attack) / (e.duration - e.attack));
      let sample = 0;
      if (e.modRatio > 0) {
        const modEnv = e.modDepth * Math.exp(-3 * progress);
        const carrier = freq + modEnv * Math.sin(modPhase * 2 * Math.PI);
        sample = env * Math.sin(phase * 2 * Math.PI);
        phase += carrier / sr;
        modPhase += freq * e.modRatio / sr;
      } else {
        if (e.waveform === 1) {
          const p = phase - Math.floor(phase);
          sample = env * (2 * Math.abs(2 * p - 1) - 1);
        } else if (e.waveform === 2) {
          noise ^= noise << 13;
          noise ^= noise >>> 17;
          noise ^= noise << 5;
          sample = env * (((noise >>> 0) / 4294967295) * 2 - 1);
        } else {
          sample = env * Math.sin(phase * 2 * Math.PI);
        }
        phase += freq / sr;
      }
      mix[idx] += sample;
    }
  }
  const dataBytes = total * 2;
  const buf = new ArrayBuffer(44 + dataBytes);
  const v = new DataView(buf);
  const writeStr = (off: number, s: string) => {
    for (let i = 0; i < s.length; i++) {
      v.setUint8(off + i, s.charCodeAt(i));
    }
  };
  writeStr(0, 'RIFF');
  v.setUint32(4, 36 + dataBytes, true);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true);
  v.setUint16(22, 1, true);
  v.setUint32(24, sr, true);
  v.setUint32(28, sr * 2, true);
  v.setUint16(32, 2, true);
  v.setUint16(34, 16, true);
  writeStr(36, 'data');
  v.setUint32(40, dataBytes, true);
  for (let i = 0; i < total; i++) {
    const s = Math.max(-1, Math.min(1, mix[i] * 0.55 * 1.6));
    v.setInt16(44 + i * 2, Math.round(s * 32767), true);
  }
  return buf;
}
