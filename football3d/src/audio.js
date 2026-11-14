// أصوات مولّدة بالكامل (بدون ملفات): جمهور، ركلة، صافرة، هدف، شبكة.
export class Audio {
  constructor(enabled) {
    this.enabled = enabled;
    this.ctx = null;
    this.excite = 0;
  }

  unlock() {
    if (!this.enabled || this.ctx) {
      if (this.ctx?.state === 'suspended') this.ctx.resume();
      return;
    }
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AC();
    } catch (_) {
      return;
    }
    const c = this.ctx;
    this.master = c.createGain();
    this.master.gain.value = 0.8;
    this.master.connect(c.destination);
    // ضوضاء للجمهور
    const len = c.sampleRate * 3;
    const buf = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      let last = 0;
      for (let i = 0; i < len; i++) {
        const w = Math.random() * 2 - 1;
        last = (last + 0.02 * w) / 1.02; // ضوضاء بنية
        d[i] = last * 3.5 + w * 0.15;
      }
    }
    this.noiseBuf = buf;
    const src = c.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    const bp = c.createBiquadFilter();
    bp.type = 'bandpass';
    bp.frequency.value = 700;
    bp.Q.value = 0.6;
    this.crowdGain = c.createGain();
    this.crowdGain.gain.value = 0.0;
    src.connect(bp).connect(this.crowdGain).connect(this.master);
    src.start();
    // همهمة متموجة (هتاف)
    const src2 = c.createBufferSource();
    src2.buffer = buf;
    src2.loop = true;
    src2.playbackRate.value = 0.7;
    const lp = c.createBiquadFilter();
    lp.type = 'bandpass';
    lp.frequency.value = 380;
    lp.Q.value = 1.4;
    this.chantGain = c.createGain();
    this.chantGain.gain.value = 0;
    src2.connect(lp).connect(this.chantGain).connect(this.master);
    src2.start();
  }

  update(dt, excite, t) {
    if (!this.ctx) return;
    this.excite += (excite - this.excite) * Math.min(1, dt * 2);
    const base = 0.12 + this.excite * 0.45;
    this.crowdGain.gain.setTargetAtTime(base, this.ctx.currentTime, 0.2);
    const chant = 0.05 + 0.05 * Math.max(0, Math.sin(t * 2.4)) + this.excite * 0.1;
    this.chantGain.gain.setTargetAtTime(chant, this.ctx.currentTime, 0.2);
  }

  _noiseBurst(dur, freq, type, gain, q = 1) {
    const c = this.ctx;
    const s = c.createBufferSource();
    s.buffer = this.noiseBuf;
    const f = c.createBiquadFilter();
    f.type = type;
    f.frequency.value = freq;
    f.Q.value = q;
    const g = c.createGain();
    const now = c.currentTime;
    g.gain.setValueAtTime(gain, now);
    g.gain.exponentialRampToValueAtTime(0.001, now + dur);
    s.connect(f).connect(g).connect(this.master);
    s.start(now, Math.random() * 2, dur + 0.05);
  }

  kick(power = 0.5) {
    if (!this.ctx) return;
    const c = this.ctx;
    const now = c.currentTime;
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(160, now);
    o.frequency.exponentialRampToValueAtTime(55, now + 0.09);
    g.gain.setValueAtTime(0.35 + power * 0.5, now);
    g.gain.exponentialRampToValueAtTime(0.001, now + 0.12);
    o.connect(g).connect(this.master);
    o.start(now);
    o.stop(now + 0.14);
    this._noiseBurst(0.05, 1800, 'bandpass', 0.25 + power * 0.3, 0.8);
  }

  whistle(times = 1, long = false) {
    if (!this.ctx) return;
    const c = this.ctx;
    for (let i = 0; i < times; i++) {
      const start = c.currentTime + i * 0.45;
      const dur = long && i === times - 1 ? 0.9 : 0.28;
      const g = c.createGain();
      g.gain.setValueAtTime(0, start);
      g.gain.linearRampToValueAtTime(0.16, start + 0.02);
      g.gain.setValueAtTime(0.16, start + dur - 0.05);
      g.gain.linearRampToValueAtTime(0, start + dur);
      g.connect(this.master);
      for (const f of [2950, 3120]) {
        const o = c.createOscillator();
        o.type = 'square';
        o.frequency.value = f;
        const lfo = c.createOscillator();
        lfo.frequency.value = 38;
        const lg = c.createGain();
        lg.gain.value = 90;
        lfo.connect(lg).connect(o.frequency);
        const lpf = c.createBiquadFilter();
        lpf.type = 'lowpass';
        lpf.frequency.value = 4000;
        o.connect(lpf).connect(g);
        o.start(start);
        lfo.start(start);
        o.stop(start + dur);
        lfo.stop(start + dur);
      }
    }
  }

  goal() {
    if (!this.ctx) return;
    const c = this.ctx;
    const s = c.createBufferSource();
    s.buffer = this.noiseBuf;
    s.loop = true;
    const f = c.createBiquadFilter();
    f.type = 'bandpass';
    f.frequency.value = 900;
    f.Q.value = 0.5;
    const g = c.createGain();
    const now = c.currentTime;
    g.gain.setValueAtTime(0.0, now);
    g.gain.linearRampToValueAtTime(1.0, now + 0.35);
    g.gain.exponentialRampToValueAtTime(0.01, now + 5.5);
    s.connect(f).connect(g).connect(this.master);
    s.start(now);
    s.stop(now + 5.6);
    this._noiseBurst(0.5, 5000, 'highpass', 0.25);
  }

  net() {
    if (!this.ctx) return;
    this._noiseBurst(0.35, 3500, 'highpass', 0.3);
  }

  post() {
    if (!this.ctx) return;
    const c = this.ctx;
    const now = c.currentTime;
    for (const f of [820, 1240, 1870]) {
      const o = c.createOscillator();
      const g = c.createGain();
      o.frequency.value = f;
      g.gain.setValueAtTime(0.18, now);
      g.gain.exponentialRampToValueAtTime(0.001, now + 0.7);
      o.connect(g).connect(this.master);
      o.start(now);
      o.stop(now + 0.75);
    }
  }

  ooh() {
    if (!this.ctx) return;
    this._noiseBurst(1.6, 500, 'bandpass', 0.6, 0.8);
  }
}
