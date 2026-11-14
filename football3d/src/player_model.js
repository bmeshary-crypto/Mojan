import * as THREE from 'three';
import { clamp, lerp } from './consts.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';

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


const BOOTS = ['#111111', '#f2f2f2', '#ff3b30', '#ffd60a', '#0a84ff', '#30d158', '#ff6bd5'];
const sharedVC = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.72 });
const _m = new THREE.Matrix4();
const _c = new THREE.Color();

function lathe(pts, segs = 14) {
  // نرتب النقاط من الأسفل للأعلى حتى تكون الأوجه للخارج
  const sorted = [...pts].sort((a, b) => a[1] - b[1]);
  return new THREE.LatheGeometry(sorted.map(([r, y]) => new THREE.Vector2(r, y)), segs);
}

/** جزء بلون ثابت (ألوان على الرؤوس) مع إزاحة وتحجيم. */
function part(g, color, sx = 1, sz = 1, pos = [0, 0, 0], sy = 1) {
  g = g.index ? g.toNonIndexed() : g.clone();
  for (const k of Object.keys(g.attributes)) if (!['position', 'normal'].includes(k)) g.deleteAttribute(k);
  _m.compose(new THREE.Vector3(...pos), new THREE.Quaternion(), new THREE.Vector3(sx, sy, sz));
  g.applyMatrix4(_m);
  _c.set(color).convertSRGBToLinear();
  const n = g.attributes.position.count;
  const col = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) { col[i * 3] = _c.r; col[i * 3 + 1] = _c.g; col[i * 3 + 2] = _c.b; }
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  return g;
}

function merged(parts, shadow) {
  const m = new THREE.Mesh(mergeGeometries(parts), sharedVC);
  m.castShadow = shadow;
  return m;
}

function torsoGeo() {
  // صدر أعرض وخصر أنحف
  const g = lathe([[0.0, 0.05], [0.15, 0.06], [0.152, 0.14], [0.16, 0.26], [0.18, 0.38], [0.19, 0.47], [0.182, 0.54], [0.15, 0.6], [0.09, 0.635], [0.0, 0.64]], 20);
  g.scale(1.22, 1, 0.72);
  return g;
}

const shirtCache = new Map();
function shirtMaterial(c1, c2, pattern, number, numColor) {
  const key = [c1, c2, pattern, number, numColor].join('|');
  if (shirtCache.has(key)) return shirtCache.get(key);
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = c1;
  g.fillRect(0, 0, 256, 128);
  g.fillStyle = c2;
  if (pattern === 1) for (let i = 0; i < 256; i += 32) g.fillRect(i, 0, 13, 128);
  else if (pattern === 2) g.fillRect(0, 44, 256, 20);
  else if (pattern === 3) { g.fillRect(0, 0, 64, 128); g.fillRect(128, 0, 64, 128); }
  // جوانب بلون ثاني وياقة
  g.fillRect(0, 0, 256, 6);
  g.fillRect(58, 0, 12, 128); g.fillRect(186, 0, 12, 128);
  // الرقم: الظهر عند u≈0.75 والصدر عند u≈0.25 (Lathe يبدأ من +z ويدور)
  if (number !== '' && number !== undefined) {
    g.font = 'bold 54px Arial Black, Arial, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.lineWidth = 5;
    g.strokeStyle = 'rgba(0,0,0,0.45)';
    g.fillStyle = numColor;
    g.save();
    g.translate(128 + 64 * 0, 0);
    g.restore();
    g.strokeText(String(number), 128, 60);
    g.fillText(String(number), 128, 60);
    g.font = 'bold 18px Arial Black, Arial, sans-serif';
    g.fillText(String(number), 20 + 0, 44);
    // شعار صغير على الصدر
    g.fillStyle = c2; g.beginPath(); g.arc(236, 42, 4, 0, 7); g.fill();
  }
  // ظل القماش
  const gr = g.createLinearGradient(0, 0, 0, 128);
  gr.addColorStop(0, 'rgba(255,255,255,0.06)');
  gr.addColorStop(1, 'rgba(0,0,0,0.22)');
  g.fillStyle = gr;
  g.fillRect(0, 0, 256, 128);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  const m = new THREE.MeshStandardMaterial({ map: t, roughness: 0.62, sheen: 0 });
  shirtCache.set(key, m);
  return m;
}

const faceCache = new Map();
function faceMaterial(skin, hair, beard) {
  const key = skin + hair + beard;
  if (faceCache.has(key)) return faceCache.get(key);
  const c = document.createElement('canvas');
  c.width = 256;
  c.height = 128;
  const g = c.getContext('2d');
  g.fillStyle = skin;
  g.fillRect(0, 0, 256, 128);
  // الوجه حول u=0.25 (x=64)
  const shade = (x, y, rx, ry, col) => { g.fillStyle = col; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, 7); g.fill(); };
  // شعر قصير على مؤخرة وأعلى الرأس
  g.fillStyle = hair;
  g.fillRect(0, 0, 256, 30);
  g.fillRect(100, 0, 156, 52);
  g.fillRect(0, 0, 22, 52);
  for (const s of [-1, 1]) {
    shade(64 + s * 11, 58, 6.5, 3.6, '#f4f1ea'); // بياض العين
    shade(64 + s * 11, 58.4, 3, 3.2, '#2a1b10'); // القزحية
    shade(64 + s * 11 + 0.8, 57.6, 0.9, 0.9, '#ffffff');
    g.fillStyle = hair; g.fillRect(64 + s * 11 - 7, 50, 14, 2.6); // الحاجب
    shade(64 + s * 11, 62, 6, 1.2, 'rgba(0,0,0,0.12)');
  }
  shade(64, 69, 3.5, 4, 'rgba(0,0,0,0.12)'); // ظل الأنف
  shade(64, 79, 7.5, 2, '#8a4a3a'); // الفم
  shade(64, 78, 7, 0.8, 'rgba(0,0,0,0.35)');
  if (beard) {
    g.globalAlpha = 0.75;
    g.fillStyle = hair;
    g.beginPath();
    g.ellipse(64, 84, 20, 14, 0, 0, Math.PI);
    g.fill();
    g.fillRect(44, 74, 6, 12); g.fillRect(78, 74, 6, 12);
    g.globalAlpha = 1;
    shade(64, 79, 7.5, 2, '#8a4a3a');
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  const m = new THREE.MeshStandardMaterial({ map: t, roughness: 0.6 });
  faceCache.set(key, m);
  return m;
}

/**
 * لاعب بهيكل عظمي بسيط (مفاصل) وأنيميشن إجرائي: جري، تسديد، افتكاك، ارتماء حارس، احتفال.
 * الأمام = +z في الإحداثيات المحلية.
 */
export class PlayerModel {
  constructor(kit) {
    const scale = kit.scale ?? 1;
    this.root = new THREE.Group();
    this.phase = Math.random() * 6;
    const skin = kit.skin ?? SKINS[(Math.random() * SKINS.length) | 0];
    const hairC = kit.hair ?? HAIRS[(Math.random() * HAIRS.length) | 0];
    const hairStyle = kit.hairStyle ?? ((Math.random() * 4) | 0);
    const beard = kit.beard ?? Math.random() < 0.3;
    const shirt = kit.shirt, trim = kit.trim, shorts = kit.shorts, socks = kit.socks;
    const glove = kit.keeper ? '#f2f2f2' : skin;
    const boots = kit.boots ?? BOOTS[(Math.random() * BOOTS.length) | 0];

    const body = new THREE.Group();
    body.scale.setScalar(scale);
    this.root.add(body);
    this.body = body;
    const hips = new THREE.Group();
    hips.position.y = 0.95;
    body.add(hips);
    this.hips = hips;
    this.hipBase = 0.95;

    // ---- الجذع: قميص بقماش مرسوم (خطوط/رقم) ----
    const torso = new THREE.Mesh(geo('torso2', torsoGeo), shirtMaterial(shirt, trim, kit.pattern ?? 0, kit.number, kit.numColor ?? '#fff'));
    torso.castShadow = true;
    hips.add(torso);
    this.torso = torso;

    // باقي الجسم بألوان على الرؤوس (مادة واحدة مشتركة = أداء أفضل)
    const hipParts = [
      part(lathe([[0.168, 0.14], [0.176, 0.06], [0.182, -0.02], [0.17, -0.07], [0.0, -0.075]]), shorts, 1, 0.74),
      part(new THREE.SphereGeometry(0.062, 12, 8), shirt, 1, 0.85, [-0.2, 0.545, 0]),
      part(new THREE.SphereGeometry(0.062, 12, 8), shirt, 1, 0.85, [0.2, 0.545, 0]),
      part(lathe([[0.052, 0.62], [0.048, 0.7], [0.045, 0.73]]), skin),
      part(new THREE.TorusGeometry(0.056, 0.014, 6, 16).rotateX(Math.PI / 2), trim, 1, 1, [0, 0.635, 0.005]),
    ];
    hips.add(merged(hipParts, true));

    // ---- الرأس: وجه مرسوم + شعر + أذنين ----
    const head = new THREE.Group();
    head.position.y = 0.8;
    hips.add(head);
    this.head = head;
    const skull = new THREE.Mesh(geo('skull', () => new THREE.SphereGeometry(0.108, 24, 18).scale(0.86, 1.06, 0.97)), faceMaterial(skin, hairC, beard));
    skull.castShadow = true;
    head.add(skull);
    const headParts = [
      part(new THREE.SphereGeometry(0.024, 8, 6), skin, 0.6, 1.3, [-0.092, -0.005, -0.005]),
      part(new THREE.SphereGeometry(0.024, 8, 6), skin, 0.6, 1.3, [0.092, -0.005, -0.005]),
      part(new THREE.SphereGeometry(0.016, 8, 6), skin, 1, 1.4, [0, -0.012, 0.1], 1.5),
      part(new THREE.SphereGeometry(0.06, 12, 8), skin, 1.1, 0.7, [0, -0.07, 0.03]), // الفك
    ];
    if (hairStyle === 0) headParts.push(part(new THREE.SphereGeometry(0.114, 18, 10, 0, Math.PI * 2, 0, Math.PI * 0.42), hairC, 0.88, 1.05, [0, 0.012, -0.008]));
    if (hairStyle === 1) headParts.push(part(new THREE.SphereGeometry(0.118, 18, 10, 0, Math.PI * 2, 0, Math.PI * 0.5), hairC, 0.9, 1.15, [0, 0.02, -0.012]));
    if (hairStyle === 2) {
      headParts.push(part(new THREE.SphereGeometry(0.122, 18, 12, 0, Math.PI * 2, 0, Math.PI * 0.62), hairC, 0.93, 1.12, [0, 0.01, -0.02]));
    }
    if (hairStyle === 3) {
      // شعر طويل مربوط
      headParts.push(part(new THREE.SphereGeometry(0.117, 18, 10, 0, Math.PI * 2, 0, Math.PI * 0.48), hairC, 0.9, 1.08, [0, 0.015, -0.01]));
      headParts.push(part(new THREE.SphereGeometry(0.035, 8, 6), hairC, 1, 1, [0, 0.03, -0.118]));
    }
    head.add(merged(headParts, false));

    // ---- الأذرع ----
    this.shoulders = [];
    this.elbows = [];
    for (const s of [-1, 1]) {
      const sh = new THREE.Group();
      sh.position.set(s * 0.225, 0.55, 0);
      hips.add(sh);
      sh.add(merged([
        part(lathe([[0.0, 0.035], [0.058, 0.03], [0.06, -0.05], [0.056, -0.13], [0.0, -0.135]]), shirt), // كمّ
        part(lathe([[0.0, -0.1], [0.05, -0.11], [0.054, -0.16], [0.046, -0.25], [0.04, -0.29]]), kit.keeper ? shirt : skin),
        part(new THREE.TorusGeometry(0.056, 0.007, 4, 14).rotateX(Math.PI / 2), trim, 1, 1, [0, -0.13, 0]),
      ], true));
      const el = new THREE.Group();
      el.position.y = -0.28;
      sh.add(el);
      el.add(merged([
        part(new THREE.SphereGeometry(0.041, 8, 6), kit.keeper ? shirt : skin),
        part(lathe([[0.041, 0], [0.042, -0.06], [0.034, -0.2], [0.03, -0.24]]), kit.keeper ? shirt : skin),
        part(new THREE.CapsuleGeometry(kit.keeper ? 0.05 : 0.032, 0.05, 4, 8), glove, 1, 1, [0, -0.29, 0.005]),
      ], true));
      sh.rotation.z = s * 0.12;
      this.shoulders.push(sh);
      this.elbows.push(el);
    }

    // ---- الأرجل ----
    this.thighs = [];
    this.knees = [];
    for (const s of [-1, 1]) {
      const hp = new THREE.Group();
      hp.position.set(s * 0.098, -0.04, 0);
      hips.add(hp);
      hp.add(merged([
        part(lathe([[0.098, 0.02], [0.102, -0.08], [0.1, -0.17], [0.0, -0.172]]), shorts), // ساق الشورت
        part(lathe([[0.0, -0.12], [0.084, -0.13], [0.08, -0.22], [0.068, -0.33], [0.055, -0.42]]), skin), // الفخذ
      ], true));
      const kn = new THREE.Group();
      kn.position.y = -0.42;
      hp.add(kn);
      kn.add(merged([
        part(new THREE.SphereGeometry(0.053, 10, 8), skin),
        part(lathe([[0.054, 0.0], [0.06, -0.08], [0.064, -0.14], [0.05, -0.27], [0.04, -0.36], [0.038, -0.42]]), socks), // الجورب والسمانة
        part(new THREE.CylinderGeometry(0.056, 0.056, 0.03, 12), trim, 1, 1, [0, -0.04, 0]),
        part(new THREE.SphereGeometry(0.06, 12, 8), boots, 0.95, 0.7, [0, -0.45, 0.06], 2.05), // الحذاء
        part(new THREE.BoxGeometry(0.1, 0.018, 0.25), '#e8e8e8', 1, 1, [0, -0.488, 0.055]), // النعل
      ], true));
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
