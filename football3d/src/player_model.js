import * as THREE from 'three';
import { clamp, lerp } from './consts.js';

const geoCache = {};
function geo(key, make) {
  return geoCache[key] || (geoCache[key] = make());
}

function numberTexture(num, color, outline) {
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const g = c.getContext('2d');
  g.font = 'bold 96px Arial Black, Arial, sans-serif';
  g.textAlign = 'center';
  g.textBaseline = 'middle';
  g.lineWidth = 8;
  g.strokeStyle = outline;
  g.strokeText(String(num), 64, 70);
  g.fillStyle = color;
  g.fillText(String(num), 64, 70);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

function shirtTexture(c1, c2, pattern) {
  // قميص بخطوط أو لون واحد مع ياقة
  const c = document.createElement('canvas');
  c.width = 128;
  c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = c1;
  g.fillRect(0, 0, 128, 128);
  if (pattern === 1) {
    g.fillStyle = c2;
    for (let i = 0; i < 128; i += 32) g.fillRect(i, 0, 14, 128);
  } else if (pattern === 2) {
    g.fillStyle = c2;
    g.fillRect(0, 50, 128, 22);
  } else if (pattern === 3) {
    g.fillStyle = c2;
    g.fillRect(0, 0, 64, 128);
  }
  // ياقة وكمّ
  g.fillStyle = c2;
  g.fillRect(0, 0, 128, 7);
  // ظل خفيف للقماش
  const gr = g.createLinearGradient(0, 0, 0, 128);
  gr.addColorStop(0, 'rgba(255,255,255,0.08)');
  gr.addColorStop(1, 'rgba(0,0,0,0.18)');
  g.fillStyle = gr;
  g.fillRect(0, 0, 128, 128);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

const SKINS = ['#f1c9a5', '#e0ac85', '#c68863', '#9a6440', '#6b4229', '#f5d7bd'];
const HAIRS = ['#1a1310', '#2b1d14', '#4a3020', '#0d0d0d', '#7a5230', '#c9a15a'];

/**
 * لاعب بهيكل عظمي بسيط (مفاصل) وأنيميشن إجرائي: جري، تسديد، افتكاك، ارتماء حارس، احتفال.
 * الأمام = +z في الإحداثيات المحلية.
 */
export class PlayerModel {
  constructor(kit) {
    const scale = kit.scale ?? 1;
    this.root = new THREE.Group();
    this.phase = Math.random() * 6;
    const std = (color, rough = 0.75) => new THREE.MeshStandardMaterial({ color, roughness: rough });
    const shirtMat = new THREE.MeshStandardMaterial({ map: shirtTexture(kit.shirt, kit.trim, kit.pattern ?? 0), roughness: 0.65 });
    const sleeveMat = std(kit.shirt, 0.65);
    const shortsMat = std(kit.shorts, 0.7);
    const sockMat = std(kit.socks, 0.8);
    const skin = kit.skin ?? SKINS[(Math.random() * SKINS.length) | 0];
    const skinMat = std(skin, 0.6);
    const hairMat = std(kit.hair ?? HAIRS[(Math.random() * HAIRS.length) | 0], 0.9);
    const bootMat = std(kit.boots ?? '#111111', 0.4);
    const gloveMat = kit.keeper ? std('#f5f5f5', 0.6) : skinMat;

    const body = new THREE.Group();
    body.scale.setScalar(scale);
    this.root.add(body);
    this.body = body;

    const hips = new THREE.Group();
    hips.position.y = 0.95;
    body.add(hips);
    this.hips = hips;
    this.hipBase = 0.95;

    const shadowy = (m) => { m.castShadow = true; return m; };

    // الجذع
    const torso = shadowy(new THREE.Mesh(geo('torso', () => {
      const g = new THREE.CapsuleGeometry(0.16, 0.34, 4, 12);
      g.scale(1.32, 1, 0.78);
      return g;
    }), shirtMat));
    torso.position.y = 0.33;
    hips.add(torso);
    this.torso = torso;
    const shorts = shadowy(new THREE.Mesh(geo('shorts', () => new THREE.CylinderGeometry(0.19, 0.2, 0.24, 12)), shortsMat));
    shorts.position.y = 0.02;
    shorts.scale.z = 0.8;
    hips.add(shorts);

    // الرقم على الظهر
    const num = new THREE.Mesh(
      geo('num', () => new THREE.PlaneGeometry(0.24, 0.24)),
      new THREE.MeshStandardMaterial({ map: numberTexture(kit.number, kit.numColor ?? '#ffffff', 'rgba(0,0,0,0.5)'), transparent: true, roughness: 0.6 }),
    );
    num.position.set(0, 0.38, -0.132);
    num.rotation.y = Math.PI;
    hips.add(num);
    const numF = num.clone();
    numF.scale.setScalar(0.45);
    numF.position.set(0.07, 0.48, 0.132);
    numF.rotation.y = 0;
    hips.add(numF);

    const neck = new THREE.Mesh(geo('neck', () => new THREE.CylinderGeometry(0.05, 0.055, 0.1, 8)), skinMat);
    neck.position.y = 0.66;
    hips.add(neck);
    const head = shadowy(new THREE.Mesh(geo('head', () => {
      const g = new THREE.SphereGeometry(0.112, 16, 12);
      g.scale(0.92, 1.08, 1);
      return g;
    }), skinMat));
    head.position.y = 0.78;
    hips.add(head);
    this.head = head;
    const hairStyle = kit.hairStyle ?? ((Math.random() * 3) | 0);
    const hair = new THREE.Mesh(
      geo('hair' + hairStyle, () => new THREE.SphereGeometry(0.118, 16, 10, 0, Math.PI * 2, 0, Math.PI * (hairStyle === 0 ? 0.45 : hairStyle === 1 ? 0.55 : 0.62))),
      hairMat,
    );
    hair.position.set(0, 0.012, -0.012);
    hair.scale.set(0.95, hairStyle === 2 ? 1.18 : 1.05, 1.02);
    head.add(hair);
    // أنف بسيط لإعطاء اتجاه للوجه
    const nose = new THREE.Mesh(geo('nose', () => new THREE.SphereGeometry(0.02, 6, 4)), skinMat);
    nose.position.set(0, -0.01, 0.105);
    head.add(nose);

    // الأذرع
    this.shoulders = [];
    this.elbows = [];
    for (const s of [-1, 1]) {
      const sh = new THREE.Group();
      sh.position.set(s * 0.235, 0.56, 0);
      hips.add(sh);
      const up = shadowy(new THREE.Mesh(geo('uparm', () => new THREE.CapsuleGeometry(0.052, 0.2, 4, 8)), sleeveMat));
      up.position.y = -0.13;
      sh.add(up);
      const el = new THREE.Group();
      el.position.y = -0.27;
      sh.add(el);
      const fa = new THREE.Mesh(geo('forearm', () => new THREE.CapsuleGeometry(0.043, 0.2, 4, 8)), kit.keeper ? sleeveMat : skinMat);
      fa.position.y = -0.13;
      el.add(fa);
      const hand = new THREE.Mesh(geo('hand' + (kit.keeper ? 'k' : ''), () => new THREE.SphereGeometry(kit.keeper ? 0.065 : 0.048, 8, 6)), gloveMat);
      hand.position.y = -0.27;
      el.add(hand);
      sh.rotation.z = s * 0.12;
      this.shoulders.push(sh);
      this.elbows.push(el);
    }

    // الأرجل
    this.thighs = [];
    this.knees = [];
    for (const s of [-1, 1]) {
      const hp = new THREE.Group();
      hp.position.set(s * 0.1, -0.06, 0);
      hips.add(hp);
      const shortLeg = new THREE.Mesh(geo('shortleg', () => new THREE.CylinderGeometry(0.088, 0.08, 0.17, 10)), shortsMat);
      shortLeg.position.y = -0.06;
      hp.add(shortLeg);
      const th = shadowy(new THREE.Mesh(geo('thigh', () => new THREE.CapsuleGeometry(0.07, 0.28, 4, 8)), skinMat));
      th.position.y = -0.2;
      hp.add(th);
      const kn = new THREE.Group();
      kn.position.y = -0.42;
      hp.add(kn);
      const sh = shadowy(new THREE.Mesh(geo('shin', () => new THREE.CapsuleGeometry(0.058, 0.3, 4, 8)), sockMat));
      sh.position.y = -0.2;
      kn.add(sh);
      const boot = shadowy(new THREE.Mesh(geo('boot', () => {
        const g = new THREE.BoxGeometry(0.095, 0.075, 0.25);
        g.translate(0, 0, 0.045);
        return g;
      }), bootMat));
      boot.position.y = -0.43;
      kn.add(boot);
      this.thighs.push(hp);
      this.knees.push(kn);
    }

    this.anim = 'idle';
    this.animT = 0;
    this.diveDir = 0;
    this.lean = 0;
    this.blend = { lean: 0 };
  }

  setAnim(name, opts = {}) {
    if (this.anim === name && !opts.restart) return;
    this.anim = name;
    this.animT = 0;
    if (opts.diveDir !== undefined) this.diveDir = opts.diveDir;
    if (opts.kickLeg !== undefined) this.kickLeg = opts.kickLeg;
  }

  /** speed بالمتر/ثانية، turn = سرعة الدوران لإمالة الجسم. */
  update(dt, speed, turn = 0) {
    this.animT += dt;
    const t = this.animT;
    const k = clamp(speed / 7.5, 0, 1.15);
    this.phase += dt * (2.2 + speed * 1.25);
    const p = this.phase;
    const [tl, tr] = this.thighs;
    const [kl, kr] = this.knees;
    const [sl, sr] = this.shoulders;
    const [el, er] = this.elbows;
    const H = this.hips;

    // الوضع الافتراضي: الجري / الوقوف
    const amp = 0.12 + 0.72 * k;
    let hipY = this.hipBase + Math.abs(Math.sin(p)) * 0.055 * k - 0.04 * k;
    let leanX = 0.04 + 0.2 * k;
    let rollZ = clamp(-turn * 0.08 * k, -0.25, 0.25);
    tl.rotation.x = -Math.sin(p) * amp;
    tr.rotation.x = Math.sin(p) * amp;
    kl.rotation.x = 0.12 + k * 1.25 * Math.max(0, Math.sin(p + 1.9)) ** 1.3;
    kr.rotation.x = 0.12 + k * 1.25 * Math.max(0, Math.sin(p + 1.9 + Math.PI)) ** 1.3;
    sl.rotation.x = Math.sin(p) * amp * 0.85;
    sr.rotation.x = -Math.sin(p) * amp * 0.85;
    sl.rotation.z = -0.12;
    sr.rotation.z = 0.12;
    el.rotation.x = -(0.25 + k * 1.05);
    er.rotation.x = -(0.25 + k * 1.05);
    tl.rotation.z = 0; tr.rotation.z = 0;
    H.rotation.y = 0;
    let rootLowerX = 0;

    if (speed < 0.3 && this.anim === 'idle') {
      // تنفس واستعداد
      const b = Math.sin(t * 2.2) * 0.012;
      hipY = this.hipBase - 0.02 + b;
      tl.rotation.x = 0.05; tr.rotation.x = -0.05;
      tl.rotation.z = 0.06; tr.rotation.z = -0.06;
      kl.rotation.x = 0.12; kr.rotation.x = 0.12;
      sl.rotation.x = 0.05; sr.rotation.x = 0.05;
      el.rotation.x = -0.35; er.rotation.x = -0.35;
      leanX = 0.06;
    }

    switch (this.anim) {
      case 'kick': {
        // الساق اليمنى: سحب للخلف ثم ضربة
        const leg = this.kickLeg ?? 1;
        const th = leg > 0 ? tr : tl, kn = leg > 0 ? kr : kl, other = leg > 0 ? tl : tr;
        const d = 0.36;
        const u = clamp(t / d, 0, 1);
        if (u < 0.4) {
          const v = u / 0.4;
          th.rotation.x = lerp(0, 0.85, v);
          kn.rotation.x = lerp(0.2, 1.6, v);
        } else {
          const v = (u - 0.4) / 0.6;
          const e = 1 - (1 - v) ** 3;
          th.rotation.x = lerp(0.85, -1.25, e);
          kn.rotation.x = lerp(1.6, 0.1, Math.min(1, e * 1.4));
        }
        other.rotation.x = -0.15;
        sl.rotation.z = -0.7; sr.rotation.z = 0.7;
        sl.rotation.x = leg > 0 ? -0.6 : 0.4;
        sr.rotation.x = leg > 0 ? 0.4 : -0.6;
        leanX = u < 0.4 ? -0.05 : 0.12;
        hipY = this.hipBase - 0.03;
        if (t > d + 0.15) this.anim = 'idle';
        break;
      }
      case 'tackle': {
        // انزلاق
        const u = clamp(t / 0.25, 0, 1);
        hipY = lerp(this.hipBase, 0.3, u);
        leanX = lerp(0.1, -0.95, u);
        rollZ = 0.35;
        tr.rotation.x = -1.45 * u; kr.rotation.x = 0.1;
        tl.rotation.x = -0.6 * u; kl.rotation.x = 1.4 * u;
        sl.rotation.z = -1.1; sr.rotation.z = 0.9;
        sl.rotation.x = 0.6; sr.rotation.x = -0.4;
        rootLowerX = 0;
        if (t > 0.85) {
          const v = clamp((t - 0.85) / 0.3, 0, 1);
          hipY = lerp(0.3, this.hipBase, v);
          leanX = lerp(-0.95, 0.1, v);
          if (v >= 1) this.anim = 'idle';
        }
        break;
      }
      case 'stand_tackle': {
        const u = clamp(t / 0.3, 0, 1);
        const s = Math.sin(u * Math.PI);
        tr.rotation.x = -1.0 * s; kr.rotation.x = 0.2;
        tl.rotation.x = 0.2 * s;
        leanX = 0.25 * s;
        hipY = this.hipBase - 0.12 * s;
        sl.rotation.z = -0.6 * s; sr.rotation.z = 0.6 * s;
        if (t > 0.45) this.anim = 'idle';
        break;
      }
      case 'dive': {
        const u = clamp(t / 0.35, 0, 1);
        const dd = this.diveDir;
        rollZ = -dd * lerp(0, 1.35, u);
        hipY = this.hipBase + Math.sin(u * Math.PI) * 0.35 - u * 0.45;
        sl.rotation.z = -2.7; sr.rotation.z = 2.7;
        sl.rotation.x = -0.3; sr.rotation.x = -0.3;
        el.rotation.x = -0.1; er.rotation.x = -0.1;
        tl.rotation.z = 0.3; tr.rotation.z = -0.3;
        kl.rotation.x = 0.4; kr.rotation.x = 0.4;
        leanX = 0;
        if (t > 1.3) {
          const v = clamp((t - 1.3) / 0.35, 0, 1);
          rollZ = -dd * lerp(1.35, 0, v);
          hipY = lerp(this.hipBase - 0.45, this.hipBase, v);
          if (v >= 1) this.anim = 'idle';
        }
        break;
      }
      case 'keeper_ready': {
        hipY = this.hipBase - 0.13;
        tl.rotation.x = -0.35; tr.rotation.x = -0.35;
        tl.rotation.z = 0.18; tr.rotation.z = -0.18;
        kl.rotation.x = 0.7; kr.rotation.x = 0.7;
        leanX = 0.32;
        sl.rotation.z = -0.55; sr.rotation.z = 0.55;
        sl.rotation.x = -0.5; sr.rotation.x = -0.5;
        el.rotation.x = -0.5; er.rotation.x = -0.5;
        if (speed > 1) this.anim = 'idle';
        break;
      }
      case 'hold': {
        // الحارس يمسك الكرة
        sl.rotation.x = -1.2; sr.rotation.x = -1.2;
        sl.rotation.z = 0.25; sr.rotation.z = -0.25;
        el.rotation.x = -0.9; er.rotation.x = -0.9;
        break;
      }
      case 'throw': {
        const u = clamp(t / 0.7, 0, 1);
        const back = u < 0.6 ? u / 0.6 : 1 - (u - 0.6) / 0.4;
        sl.rotation.x = -2.6 - back * 0.5; sr.rotation.x = -2.6 - back * 0.5;
        sl.rotation.z = 0.1; sr.rotation.z = -0.1;
        el.rotation.x = -0.4 - back * 0.9; er.rotation.x = -0.4 - back * 0.9;
        leanX = -0.25 * back + 0.1;
        tl.rotation.x = 0.1; tr.rotation.x = -0.25;
        break;
      }
      case 'header': {
        const u = clamp(t / 0.4, 0, 1);
        hipY = this.hipBase + Math.sin(u * Math.PI) * 0.45;
        leanX = -0.3 + u * 0.7;
        sl.rotation.z = -0.8; sr.rotation.z = 0.8;
        kl.rotation.x = 0.8; kr.rotation.x = 0.5;
        if (t > 0.5) this.anim = 'idle';
        break;
      }
      case 'celebrate': {
        const j = Math.abs(Math.sin(t * 6));
        hipY = this.hipBase + (speed < 1.5 ? j * 0.28 : Math.abs(Math.sin(p)) * 0.05);
        sl.rotation.x = -2.8 + Math.sin(t * 12) * 0.2; sr.rotation.x = -2.8 - Math.sin(t * 12) * 0.2;
        sl.rotation.z = -0.4; sr.rotation.z = 0.4;
        el.rotation.x = -0.2; er.rotation.x = -0.2;
        if (speed < 1.5) { kl.rotation.x = 0.3 + j * 0.6; kr.rotation.x = 0.3 + j * 0.6; tl.rotation.x = -j * 0.5; tr.rotation.x = -j * 0.5; }
        break;
      }
      case 'sad': {
        hipY = this.hipBase - 0.05;
        leanX = 0.35;
        sl.rotation.x = 0.1; sr.rotation.x = 0.1;
        el.rotation.x = -0.1; er.rotation.x = -0.1;
        this.head.rotation.x = 0.5;
        break;
      }
    }
    if (this.anim !== 'sad') this.head.rotation.x = -leanX * 0.6;

    H.position.y = hipY;
    this.blend.lean += (leanX - this.blend.lean) * Math.min(1, dt * 12);
    H.rotation.x = this.blend.lean;
    H.rotation.z += (rollZ - H.rotation.z) * Math.min(1, dt * (this.anim === 'dive' ? 30 : 10));
    void rootLowerX;
  }
}

export function makeRing(color) {
  const g = new THREE.RingGeometry(0.55, 0.72, 40);
  g.rotateX(-Math.PI / 2);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.9, depthWrite: false }));
  m.position.y = 0.02;
  m.renderOrder = 2;
  // سهم صغير يدل على الاتجاه
  const a = new THREE.Mesh(
    new THREE.ConeGeometry(0.18, 0.4, 3).rotateX(Math.PI / 2).rotateY(0),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.95, depthWrite: false }),
  );
  a.scale.y = 0.15;
  a.position.set(0, 0, 0.95);
  m.add(a);
  return m;
}
