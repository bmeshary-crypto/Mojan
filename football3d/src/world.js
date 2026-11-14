import * as THREE from 'three';
import { HL, HW, GOAL_HW, GOAL_H, GOAL_D, IS_MOBILE } from './consts.js';

// ---------- القوام المرسومة بالكود ----------

function pitchTexture(renderer) {
  // الملعب + 10م خارج الخطوط طولاً و7.5م عرضاً
  const EX = 10, EZ = 7.5;
  const TW = 2 * HL + 2 * EX, TD = 2 * HW + 2 * EZ;
  const S = IS_MOBILE ? 14 : 20; // بكسل لكل متر
  const c = document.createElement('canvas');
  c.width = Math.round(TW * S);
  c.height = Math.round(TD * S);
  const g = c.getContext('2d');
  const X = (x) => (x + HL + EX) * S;
  const Z = (z) => (z + HW + EZ) * S;

  g.fillStyle = '#2f6b2a';
  g.fillRect(0, 0, c.width, c.height);
  // خطوط القص (عرضية كالملاعب الحقيقية)
  const n = 20;
  const sw = (2 * HL) / n;
  for (let i = -2; i < n + 2; i++) {
    g.fillStyle = i % 2 === 0 ? '#3a7d32' : '#2f6c29';
    g.fillRect(X(-HL + i * sw), 0, sw * S + 1, c.height);
  }
  // دوائر قص خفيفة بالعرض
  for (let i = 0; i < 12; i++) {
    g.fillStyle = i % 2 ? 'rgba(255,255,255,0.025)' : 'rgba(0,0,0,0.03)';
    g.fillRect(0, Z(-HW - EZ + i * (TD / 12)), c.width, (TD / 12) * S);
  }
  // ضوضاء العشب
  const img = g.getImageData(0, 0, c.width, c.height);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const r = (Math.random() - 0.5) * 22;
    d[i] += r * 0.6;
    d[i + 1] += r;
    d[i + 2] += r * 0.4;
  }
  g.putImageData(img, 0, 0);
  // بقع تآكل قرب المرميين ومنطقة الجزاء
  for (const s of [-1, 1]) {
    for (let k = 0; k < 140; k++) {
      const x = s * (HL - Math.random() * 14);
      const z = (Math.random() - 0.5) * 22;
      g.fillStyle = `rgba(${110 + Math.random() * 40},${100 + Math.random() * 30},60,${0.05 + Math.random() * 0.08})`;
      g.beginPath();
      g.ellipse(X(x), Z(z), (0.3 + Math.random()) * S, (0.2 + Math.random() * 0.6) * S, Math.random() * 3, 0, 7);
      g.fill();
    }
  }

  // الخطوط
  g.strokeStyle = 'rgba(245,248,240,0.92)';
  g.fillStyle = 'rgba(245,248,240,0.92)';
  g.lineWidth = 0.12 * S;
  const rect = (x0, z0, x1, z1) => g.strokeRect(X(x0), Z(z0), (x1 - x0) * S, (z1 - z0) * S);
  rect(-HL, -HW, HL, HW);
  g.beginPath(); g.moveTo(X(0), Z(-HW)); g.lineTo(X(0), Z(HW)); g.stroke();
  g.beginPath(); g.arc(X(0), Z(0), 9.15 * S, 0, Math.PI * 2); g.stroke();
  const spot = (x, z, r = 0.2) => { g.beginPath(); g.arc(X(x), Z(z), r * S, 0, 7); g.fill(); };
  spot(0, 0, 0.25);
  for (const s of [-1, 1]) {
    const gx = s * HL;
    // منطقة الجزاء 16.5 × 40.32
    rect(Math.min(gx, gx - s * 16.5), -20.16, Math.max(gx, gx - s * 16.5), 20.16);
    rect(Math.min(gx, gx - s * 5.5), -9.16, Math.max(gx, gx - s * 5.5), 9.16);
    spot(gx - s * 11, 0);
    // قوس منطقة الجزاء
    const a = Math.acos(5.5 / 9.15);
    g.beginPath();
    if (s > 0) g.arc(X(gx - 11), Z(0), 9.15 * S, Math.PI - a, Math.PI + a);
    else g.arc(X(gx + 11), Z(0), 9.15 * S, -a, a);
    g.stroke();
    // أقواس الركنيات (ربع دائرة داخل الملعب فقط)
    g.save();
    g.beginPath();
    g.rect(X(-HL), Z(-HW), 2 * HL * S, 2 * HW * S);
    g.clip();
    for (const t of [-1, 1]) {
      g.beginPath();
      g.arc(X(gx), Z(t * HW), 1 * S, 0, Math.PI * 2);
      g.stroke();
    }
    g.restore();
  }

  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.anisotropy = renderer.capabilities.getMaxAnisotropy();
  tex.generateMipmaps = true;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  return { tex, w: TW, d: TD };
}

function grassBump() {
  const c = document.createElement('canvas');
  c.width = c.height = 128;
  const g = c.getContext('2d');
  const img = g.createImageData(128, 128);
  for (let i = 0; i < img.data.length; i += 4) {
    const v = 100 + Math.random() * 155;
    img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
    img.data[i + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(220, 140);
  return t;
}

function adTexture() {
  const c = document.createElement('canvas');
  c.width = 2048;
  c.height = 64;
  const g = c.getContext('2d');
  const ads = [
    ['#0b0b2e', '#ffd34d', 'MOJAN'],
    ['#a3123a', '#ffffff', 'موجان أرينا'],
    ['#06395c', '#7ef9ff', 'MOJAN ARENA'],
    ['#1b1b1b', '#5cf2b5', 'سيكو'],
    ['#4a1d96', '#ffffff', 'عجلة السماء'],
    ['#0d5c2e', '#ffffff', 'MOJAN ⚽'],
    ['#7a2a00', '#ffcf7a', 'دوري النجوم'],
    ['#101e3c', '#ff6b85', 'MOJAN'],
  ];
  const w = c.width / ads.length;
  ads.forEach(([bg, fg, txt], i) => {
    const gr = g.createLinearGradient(0, 0, 0, 64);
    gr.addColorStop(0, bg);
    gr.addColorStop(1, '#000');
    g.fillStyle = gr;
    g.fillRect(i * w, 0, w, 64);
    g.fillStyle = fg;
    g.font = 'bold 40px Cairo, Arial, sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(txt, i * w + w / 2, 34);
  });
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = THREE.RepeatWrapping;
  return t;
}

function netTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  g.strokeStyle = 'rgba(255,255,255,0.95)';
  g.lineWidth = 3;
  g.beginPath();
  // شبكة سداسية تقريبية
  g.moveTo(0, 32); g.lineTo(16, 0); g.lineTo(48, 0); g.lineTo(64, 32); g.lineTo(48, 64); g.lineTo(16, 64); g.closePath();
  g.moveTo(0, 32); g.lineTo(-16, 32);
  g.moveTo(64, 32); g.lineTo(80, 32);
  g.stroke();
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

// ---------- الجمهور: InstancedMesh مع اهتزاز في الـ shader ----------

function makeCrowd(scene, homeColors, awayColors, uniforms) {
  const dens = IS_MOBILE ? 1.45 : 1.0;
  const geo = new THREE.BoxGeometry(0.46 * dens, 0.78, 0.34);
  geo.translate(0, 0.39, 0);
  const mat = new THREE.MeshLambertMaterial();
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = uniforms.uTime;
    sh.uniforms.uExcite = uniforms.uExcite;
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nuniform float uTime; uniform float uExcite;')
      .replace(
        '#include <begin_vertex>',
        `#include <begin_vertex>
        float h = fract(sin(float(gl_InstanceID) * 12.9898) * 43758.5453);
        float jump = max(0.0, sin(uTime * (7.0 + h * 5.0) + h * 40.0));
        transformed.y += jump * (0.05 + 0.5 * uExcite) * step(0.25, h + uExcite);
        transformed.x += sin(uTime * 1.3 + h * 20.0) * 0.04;`,
      );
  };
  const tiers = [];
  // كل جهة: مدرج مائل من ارتفاع 1.2 إلى 24 متر
  const sides = [
    { len: 132, cx: 0, cz: -(HW + 9), rot: 0 },
    { len: 132, cx: 0, cz: HW + 9, rot: Math.PI, near: true },
    { len: 92, cx: -(HL + 10), cz: 0, rot: Math.PI / 2 },
    { len: 92, cx: HL + 10, cz: 0, rot: -Math.PI / 2 },
  ];
  const stepX = 0.62 * dens, rowD = 0.9, rows = Math.round(26 / rowD * (IS_MOBILE ? 0.8 : 1));
  let count = 0;
  for (const s of sides) count += Math.floor(s.len / stepX) * rows;
  const mesh = new THREE.InstancedMesh(geo, mat, count);
  const m = new THREE.Matrix4();
  const q = new THREE.Quaternion();
  const col = new THREE.Color();
  const shirts = ['#f2f2f2', '#1c1c1c', '#2b4c8c', '#8c2b2b', '#e0c070', '#3a6e3a', '#6d4c9a', '#d9d9d9', '#444', '#b85c2b'];
  let i = 0;
  const slope = 0.62; // ارتفاع لكل متر
  for (const s of sides) {
    q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), s.rot);
    const cols = Math.floor(s.len / stepX);
    for (let r = 0; r < rows; r++) {
      for (let k = 0; k < cols; k++) {
        const lx = -s.len / 2 + k * stepX + (r % 2) * 0.2;
        const lz = -r * rowD; // للخلف بعيداً عن الملعب
        const y = 1.4 + r * rowD * slope;
        const v = new THREE.Vector3(lx, y, lz).applyQuaternion(q);
        const empty = Math.random() < 0.06;
        m.compose(
          new THREE.Vector3(s.cx + v.x, empty ? -50 : y, s.cz + v.z),
          q,
          new THREE.Vector3(1, 0.85 + Math.random() * 0.3, 1),
        );
        mesh.setMatrixAt(i, m);
        // جمهور كل فريق في جهة مرماه
        const fx = s.cx + v.x;
        const p = Math.random();
        let c;
        if (fx < -20 && p < 0.55) c = Math.random() < 0.7 ? homeColors[0] : homeColors[1];
        else if (fx > 20 && p < 0.55) c = Math.random() < 0.7 ? awayColors[0] : awayColors[1];
        else c = shirts[(Math.random() * shirts.length) | 0];
        col.set(c).multiplyScalar(0.55 + Math.random() * 0.35);
        mesh.setColorAt(i, col);
        i++;
      }
    }
    // كتلة المدرج نفسها
    const depth = rows * rowD + 4;
    const stand = new THREE.Mesh(
      new THREE.BoxGeometry(s.len + 2, 1, depth),
      new THREE.MeshStandardMaterial({ color: 0x2a2f3a, roughness: 0.95 }),
    );
    stand.geometry.translate(0, -0.5, -depth / 2 + 1.5);
    const tilt = new THREE.Group();
    tilt.add(stand);
    stand.rotation.x = -Math.atan(slope) * 0.0;
    // نجعلها سلالم: صندوق مائل
    const ramp = new THREE.Mesh(
      new THREE.PlaneGeometry(s.len + 2, Math.hypot(depth, depth * slope)),
      new THREE.MeshStandardMaterial({ color: 0x30343f, roughness: 0.9 }),
    );
    ramp.rotation.x = -Math.PI / 2 + Math.atan(slope);
    ramp.position.set(0, 1.4 + (depth * slope) / 2 - 0.9, -depth / 2 + 1.2);
    const sg = new THREE.Group();
    sg.add(ramp);
    // جدار أمامي + سقف مع شريط إضاءة
    const front = new THREE.Mesh(new THREE.BoxGeometry(s.len + 2, 1.6, 0.4), new THREE.MeshStandardMaterial({ color: 0x1a1d26 }));
    front.position.set(0, 0.6, 0.6);
    sg.add(front);
    const roofY = 1.4 + rows * rowD * slope + 5;
    const roof = new THREE.Mesh(
      new THREE.BoxGeometry(s.len + 6, 0.6, depth * 0.75),
      new THREE.MeshStandardMaterial({ color: 0x151821, roughness: 0.6, metalness: 0.4 }),
    );
    roof.position.set(0, roofY, -depth * 0.45);
    roof.rotation.x = -0.08;
    if (!s.near) sg.add(roof);
    const strip = new THREE.Mesh(
      new THREE.BoxGeometry(s.len + 6, 0.25, 0.2),
      new THREE.MeshBasicMaterial({ color: 0xcfe6ff }),
    );
    strip.position.set(0, roofY - 0.4, -depth * 0.45 + depth * 0.375);
    if (!s.near) sg.add(strip);
    const back = new THREE.Mesh(
      new THREE.BoxGeometry(s.len + 6, roofY, 0.5),
      new THREE.MeshStandardMaterial({ color: 0x1b1f2a }),
    );
    back.position.set(0, roofY / 2, -depth - 0.5);
    if (!s.near) sg.add(back);
    sg.position.set(s.cx, 0, s.cz);
    sg.rotation.y = s.rot;
    scene.add(sg);
    tiers.push(sg);
  }
  mesh.count = i;
  mesh.instanceMatrix.needsUpdate = true;
  mesh.instanceColor.needsUpdate = true;
  mesh.frustumCulled = false;
  scene.add(mesh);
  return mesh;
}

// ---------- المرمى والشبكة ----------

function makeGoal(scene, side) {
  const g = new THREE.Group();
  const white = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.35, metalness: 0.1 });
  const r = 0.06;
  const post = new THREE.CylinderGeometry(r, r, GOAL_H + r, 12);
  for (const z of [-GOAL_HW, GOAL_HW]) {
    const p = new THREE.Mesh(post, white);
    p.position.set(0, (GOAL_H + r) / 2, z);
    p.castShadow = true;
    g.add(p);
  }
  const bar = new THREE.Mesh(new THREE.CylinderGeometry(r, r, GOAL_HW * 2 + 2 * r, 12), white);
  bar.rotation.x = Math.PI / 2;
  bar.position.set(0, GOAL_H, 0);
  bar.castShadow = true;
  g.add(bar);
  // الإطار الخلفي
  const dark = new THREE.MeshStandardMaterial({ color: 0xdddddd, roughness: 0.6 });
  const thin = 0.025;
  const backTop = new THREE.Mesh(new THREE.CylinderGeometry(thin, thin, GOAL_HW * 2, 6), dark);
  backTop.rotation.x = Math.PI / 2;
  backTop.position.set(side * GOAL_D, GOAL_H * 0.8, 0);
  g.add(backTop);
  for (const z of [-GOAL_HW, GOAL_HW]) {
    const sb = new THREE.Mesh(new THREE.CylinderGeometry(thin, thin, GOAL_H * 0.8, 6), dark);
    sb.position.set(side * GOAL_D, GOAL_H * 0.4, z);
    g.add(sb);
    const top = new THREE.Mesh(new THREE.CylinderGeometry(thin, thin, Math.hypot(GOAL_D, GOAL_H * 0.2), 6), dark);
    top.position.set((side * GOAL_D) / 2, GOAL_H * 0.9, z);
    top.rotation.z = Math.PI / 2 - Math.atan2(GOAL_H * 0.2, GOAL_D) * -side;
    g.add(top);
  }
  // الشبكة
  const nt = netTexture();
  const netMat = new THREE.MeshStandardMaterial({
    map: nt, alphaMap: nt, transparent: true, alphaTest: 0.35, side: THREE.DoubleSide, color: 0xffffff, roughness: 1,
  });
  const mk = (w, h, rx, ry) => {
    const t = nt.clone();
    t.needsUpdate = true;
    t.repeat.set(w * 6, h * 6);
    const m = netMat.clone();
    m.map = t;
    m.alphaMap = t;
    return m;
  };
  const backNetGeo = new THREE.PlaneGeometry(GOAL_HW * 2, GOAL_H * 0.8, 16, 6);
  const backNet = new THREE.Mesh(backNetGeo, mk(GOAL_HW * 2, GOAL_H * 0.8));
  backNet.rotation.y = Math.PI / 2;
  backNet.position.set(side * GOAL_D, GOAL_H * 0.4, 0);
  g.add(backNet);
  const topLen = Math.hypot(GOAL_D, GOAL_H * 0.2);
  const topNet = new THREE.Mesh(new THREE.PlaneGeometry(topLen, GOAL_HW * 2), mk(topLen, GOAL_HW * 2));
  topNet.rotation.x = -Math.PI / 2;
  topNet.rotation.y = Math.atan2(GOAL_H * 0.2, GOAL_D) * side;
  topNet.position.set((side * GOAL_D) / 2, GOAL_H * 0.9, 0);
  g.add(topNet);
  for (const z of [-GOAL_HW, GOAL_HW]) {
    const shape = new THREE.Shape();
    shape.moveTo(0, 0);
    shape.lineTo(side * GOAL_D, 0);
    shape.lineTo(side * GOAL_D, GOAL_H * 0.8);
    shape.lineTo(0, GOAL_H);
    shape.closePath();
    const sg = new THREE.ShapeGeometry(shape);
    // UV بالمتر
    const uv = sg.attributes.uv;
    const pos = sg.attributes.position;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, pos.getX(i) / 2.5, pos.getY(i) / 2.5);
    const sm = mk(1, 1);
    sm.map.repeat.set(6, 6);
    const sideNet = new THREE.Mesh(sg, sm);
    sideNet.position.z = z;
    g.add(sideNet);
  }
  g.position.x = side * HL;
  scene.add(g);
  const base = backNetGeo.attributes.position.array.slice();
  return {
    group: g,
    bulge: 0,
    hitZ: 0,
    hitY: 1,
    update(dt) {
      if (this.bulge <= 0.001) return;
      this.bulge *= Math.exp(-dt * 3.5);
      const p = backNetGeo.attributes.position;
      for (let i = 0; i < p.count; i++) {
        const x = base[i * 3], y = base[i * 3 + 1];
        // في إحداثيات اللوح المحلي x = عرض المرمى
        const dz = x - -this.hitZ * side, dy = y + GOAL_H * 0.4 - this.hitY;
        const f = Math.exp(-(dz * dz + dy * dy) / 1.4);
        p.setZ(i, -f * this.bulge * Math.sin(performance.now() / 60) * 0.3 + f * this.bulge * 0.9);
      }
      p.needsUpdate = true;
    },
  };
}

// ---------- كشافات ----------

function makeFloodlights(scene) {
  const glowC = document.createElement('canvas');
  glowC.width = glowC.height = 128;
  const g = glowC.getContext('2d');
  const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  gr.addColorStop(0, 'rgba(255,255,255,1)');
  gr.addColorStop(0.2, 'rgba(220,235,255,0.7)');
  gr.addColorStop(1, 'rgba(180,210,255,0)');
  g.fillStyle = gr;
  g.fillRect(0, 0, 128, 128);
  const glow = new THREE.CanvasTexture(glowC);
  const pole = new THREE.MeshStandardMaterial({ color: 0x3a3f4a, metalness: 0.6, roughness: 0.4 });
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      const x = sx * (HL + 22), z = sz * (HW + 30);
      const t = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.9, 46, 8), pole);
      t.position.set(x, 23, z);
      scene.add(t);
      const panel = new THREE.Mesh(new THREE.BoxGeometry(9, 5, 0.6), new THREE.MeshBasicMaterial({ color: 0xf4f9ff }));
      panel.position.set(x, 47, z);
      panel.lookAt(0, 0, 0);
      scene.add(panel);
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glow, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.9 }));
      sp.scale.set(34, 34, 1);
      sp.position.set(x, 47, z);
      scene.add(sp);
    }
  }
}

function skyDome(scene) {
  const geo = new THREE.SphereGeometry(600, 32, 16);
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    uniforms: {},
    vertexShader: 'varying vec3 vP; void main(){ vP = position; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `varying vec3 vP;
      void main(){
        float h = normalize(vP).y;
        vec3 top = vec3(0.012,0.025,0.075);
        vec3 hor = vec3(0.10,0.15,0.30);
        vec3 c = mix(hor, top, smoothstep(0.0, 0.5, h));
        // نجوم
        vec3 d = normalize(vP);
        float s = fract(sin(dot(floor(d*300.0), vec3(12.9898,78.233,45.164)))*43758.5453);
        c += vec3(step(0.9985, s) * smoothstep(0.1,0.4,h)) * 0.8;
        gl_FragColor = vec4(c,1.0);
      }`,
  });
  scene.add(new THREE.Mesh(geo, mat));
}

export function buildWorld(scene, renderer, homeColors, awayColors) {
  skyDome(scene);
  scene.fog = new THREE.Fog(0x1a2546, 160, 520);

  const hemi = new THREE.HemisphereLight(0xbcd2ff, 0x203a20, 0.75);
  scene.add(hemi);
  const sun = new THREE.DirectionalLight(0xffffff, 2.3);
  sun.position.set(25, 70, 40);
  sun.castShadow = true;
  const sm = IS_MOBILE ? 1536 : 2048;
  sun.shadow.mapSize.set(sm, sm);
  const sc = sun.shadow.camera;
  sc.left = -64; sc.right = 64; sc.top = 44; sc.bottom = -44; sc.near = 10; sc.far = 160;
  sun.shadow.bias = -0.0004;
  sun.shadow.normalBias = 0.03;
  scene.add(sun);
  scene.add(sun.target);
  const fill = new THREE.DirectionalLight(0xcfe0ff, 0.7);
  fill.position.set(-30, 50, -40);
  scene.add(fill);

  // الأرضية حول الملعب
  const outer = new THREE.Mesh(
    new THREE.PlaneGeometry(400, 400),
    new THREE.MeshStandardMaterial({ color: 0x1f3d1f, roughness: 1 }),
  );
  outer.rotation.x = -Math.PI / 2;
  outer.position.y = -0.02;
  outer.receiveShadow = true;
  scene.add(outer);

  const { tex, w, d } = pitchTexture(renderer);
  const pitch = new THREE.Mesh(
    new THREE.PlaneGeometry(w, d),
    new THREE.MeshStandardMaterial({ map: tex, roughness: 0.92, metalness: 0, bumpMap: grassBump(), bumpScale: 0.6 }),
  );
  pitch.rotation.x = -Math.PI / 2;
  pitch.receiveShadow = true;
  scene.add(pitch);

  // لوحات الإعلانات LED
  const ad = adTexture();
  const adMat = new THREE.MeshBasicMaterial({ map: ad, toneMapped: false });
  const boards = [];
  const addBoard = (len, x, z, ry) => {
    const t = ad.clone();
    t.needsUpdate = true;
    t.repeat.set(len / 80, 1);
    const m = adMat.clone();
    m.map = t;
    const b = new THREE.Mesh(new THREE.BoxGeometry(len, 0.9, 0.12), [
      new THREE.MeshStandardMaterial({ color: 0x111111 }), new THREE.MeshStandardMaterial({ color: 0x111111 }),
      new THREE.MeshStandardMaterial({ color: 0x111111 }), new THREE.MeshStandardMaterial({ color: 0x111111 }),
      m, new THREE.MeshStandardMaterial({ color: 0x111111 }),
    ]);
    b.position.set(x, 0.45, z);
    b.rotation.y = ry;
    b.castShadow = true;
    scene.add(b);
    boards.push(t);
  };
  addBoard(118, 0, -(HW + 4.5), 0);
  addBoard(118, 0, HW + 4.5, Math.PI);
  for (const s of [-1, 1]) {
    for (const zz of [-1, 1]) addBoard(28, s * (HL + 4.5), zz * 21, s > 0 ? -Math.PI / 2 : Math.PI / 2);
  }
  // مقاعد البدلاء
  for (const xx of [-14, 14]) {
    const bench = new THREE.Mesh(new THREE.BoxGeometry(9, 1.6, 1.6), new THREE.MeshStandardMaterial({ color: 0x8fb4d9, transparent: true, opacity: 0.55, roughness: 0.1, metalness: 0.3 }));
    bench.position.set(xx, 0.8, HW + 6.5);
    scene.add(bench);
  }

  const uniforms = { uTime: { value: 0 }, uExcite: { value: 0 } };
  makeCrowd(scene, homeColors, awayColors, uniforms);
  makeFloodlights(scene);
  const goals = { '-1': makeGoal(scene, -1), '1': makeGoal(scene, 1) };

  return {
    sun,
    goals,
    update(dt, t, excite) {
      uniforms.uTime.value = t;
      uniforms.uExcite.value = excite;
      for (const b of boards) b.offset.x = (b.offset.x + dt * 0.02) % 1;
      goals['-1'].update(dt);
      goals['1'].update(dt);
    },
  };
}
