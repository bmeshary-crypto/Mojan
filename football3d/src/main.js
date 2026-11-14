import * as THREE from 'three';
import { HL, HW, clamp, IS_MOBILE } from './consts.js';
import { buildWorld } from './world.js';
import { Match } from './match.js';
import { Audio } from './audio.js';
import { Input } from './input.js';
import { makeTeam } from './teams.js';

// ---------- الإعدادات من الرابط ----------
// على الجوال يحقن التطبيق الإعدادات في window.MOJAN_FB_CFG، وعلى الويب تأتي في الرابط بعد #
const params = new URLSearchParams(window.MOJAN_FB_CFG || (location.hash || '').replace(/^#/, '') || location.search.slice(1));
const crestBase = params.get('assets') ?? '../images/';
const homeId = params.get('home') || 'eagle';
const awayId = params.get('away') || 'lion';
const custom = homeId === 'custom'
  ? {
      name: params.get('hname') || 'فريقي',
      c1: params.get('hc1') || '#2F7BFF',
      c2: params.get('hc2') || '#ffffff',
      shorts: params.get('hsh') || '#ffffff',
      pattern: +(params.get('hpat') || 0),
      names: (params.get('names') || '').split('|'),
    }
  : null;
const home = makeTeam(homeId, crestBase, null, custom);
const away = makeTeam(awayId, crestBase, home);
if (window.MOJAN_FB_CRESTS) {
  home.crest = window.MOJAN_FB_CRESTS.home || home.crest;
  away.crest = window.MOJAN_FB_CRESTS.away || away.crest;
}
const cfg = {
  home,
  away,
  diff: params.get('diff') || 'normal',
  mins: +(params.get('mins') || 4),
  auto: params.get('auto') === '1',
  speed: +(params.get('speed') || 1),
  sound: params.get('sound') !== '0',
};

// ---------- الجسر مع تطبيق Flutter ----------
function send(obj) {
  const msg = JSON.stringify({ src: 'mojan-football', ...obj });
  try {
    if (window.FootballChannel && window.FootballChannel.postMessage) { window.FootballChannel.postMessage(msg); return; }
  } catch (_) {}
  try { if (window.parent && window.parent !== window) window.parent.postMessage(msg, '*'); } catch (_) {}
}

// ---------- الشاشة الأفقية (تدوير ذاتي على الجوال الطولي) ----------
const app = document.getElementById('app');
let rotated = false;
let VW = 0, VH = 0;
function layout() {
  const w = window.innerWidth, h = window.innerHeight;
  rotated = h > w * 1.05;
  if (rotated) {
    VW = h; VH = w;
    app.style.width = h + 'px';
    app.style.height = w + 'px';
    app.style.transform = `translateX(${w}px) rotate(90deg)`;
  } else {
    VW = w; VH = h;
    app.style.width = w + 'px';
    app.style.height = h + 'px';
    app.style.transform = 'none';
  }
}
function toLocal(cx, cy) {
  if (!rotated) return { x: cx, y: cy };
  return { x: cy, y: window.innerWidth - cx };
}
layout();
if (params.get('nohud') === '1') document.body.classList.add('clean');

// ---------- المشهد ----------
const canvas = document.getElementById('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: !IS_MOBILE || devicePixelRatio < 2.5, powerPreference: 'high-performance' });
let pr = Math.min(devicePixelRatio || 1, IS_MOBILE ? 1.6 : 2);
renderer.setPixelRatio(pr);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.outputColorSpace = THREE.SRGBColorSpace;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(36, 16 / 9, 0.5, 1400);
const world = buildWorld(scene, renderer, [home.c1, home.c2], [away.c1, away.c2]);

function resize() {
  layout();
  renderer.setSize(VW, VH, false);
  canvas.style.width = VW + 'px';
  canvas.style.height = VH + 'px';
  camera.aspect = VW / VH;
  // نوسّع الرؤية على الشاشات الضيقة
  camera.fov = camera.aspect < 1.5 ? 44 : 36;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
window.addEventListener('orientationchange', () => setTimeout(resize, 200));
resize();

// ---------- واجهة اللعب ----------
const $ = (id) => document.getElementById(id);
$('hn').textContent = home.name;
$('an').textContent = away.name;
$('hc').src = home.crest;
$('ac').src = away.crest;
$('hk').style.background = `linear-gradient(135deg, ${home.c1} 50%, ${home.c2} 50%)`;
$('ak').style.background = `linear-gradient(135deg, ${away.c1} 50%, ${away.c2} 50%)`;
for (const img of [$('hc'), $('ac'), $('ihc'), $('iac')]) img.onerror = () => { img.style.visibility = 'hidden'; };
$('ihc').src = home.crest;
$('iac').src = away.crest;
$('ihn').textContent = home.name;
$('ian').textContent = away.name;

let bannerT = 0, toastT = 0;
const hud = {
  setScore(h, a) {
    $('hs').textContent = h;
    $('as').textContent = a;
    $('score').classList.remove('pop');
    void $('score').offsetWidth;
    $('score').classList.add('pop');
  },
  banner(text, sub = '', big = false) {
    const b = $('banner');
    if (!text) { b.classList.remove('show'); return; }
    $('bt').textContent = text;
    $('bs').textContent = sub;
    b.classList.toggle('big', big);
    b.classList.add('show');
    bannerT = 0;
  },
  toast(text) {
    const t = $('toast');
    if (!text) { t.classList.remove('show'); return; }
    t.textContent = text;
    t.classList.add('show');
    toastT = 2.2;
  },
  hint(text) {
    const h = $('hint');
    h.textContent = text;
    h.classList.toggle('show', !!text);
  },
  power(v) {
    const p = $('power');
    if (v === null) { p.classList.remove('show'); return; }
    p.classList.add('show');
    $('pfill').style.width = Math.round(v * 100) + '%';
    $('pfill').style.background = v > 0.86 ? '#ff4d4d' : v > 0.6 ? '#ffd23f' : '#5cf2b5';
  },
  end(r) {
    showEnd(r);
  },
};

const audio = new Audio(cfg.sound);
const match = new Match(scene, cfg, audio, hud);
match.world = world;
const input = new Input(app, toLocal);
window.__fb = { match, cfg };

// ---------- الكاميرا ----------
let camMode = 0; // 0 بث تلفزيوني، 1 قريبة
const camPos = new THREE.Vector3(0, 40, 80);
const camLook = new THREE.Vector3();
const tmpP = new THREE.Vector3(), tmpL = new THREE.Vector3();
$('cam').addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); camMode = (camMode + 1) % 2; });

function updateCamera(dt) {
  const f = match.focus();
  if (match.state === 'intro') {
    const t = match.stateT;
    const a = -0.6 + t * 0.32;
    tmpP.set(Math.sin(a) * 85, 34 - t * 3, Math.cos(a) * 85);
    tmpL.set(0, 0, 0);
    camPos.copy(tmpP);
    camLook.copy(tmpL);
  } else {
    const close = f.close || camMode === 1;
    const narrow = camera.aspect < 1.5 ? 1.2 : 1;
    const fx = clamp(f.x * 0.94, -HL + 12, HL - 12);
    const fz = clamp(f.z, -HW, HW);
    if (close) {
      tmpP.set(fx - (f.close ? 4 : 0), 12 * narrow, fz * 0.45 + 22 * narrow);
      tmpL.set(fx, 0.6, fz * 0.8);
    } else {
      tmpP.set(fx * 0.97, 21 * narrow, fz * 0.32 + 36 * narrow);
      tmpL.set(fx, 0, fz * 0.62 - 1);
    }
    const k = 1 - Math.exp(-dt * (match.state === 'goal' ? 1.8 : 3.2));
    camPos.lerp(tmpP, k);
    camLook.lerp(tmpL, k);
  }
  const o = window.__fb?.camOverride;
  if (o) { camPos.set(...o.pos); camLook.set(...o.look); }
  camera.position.copy(camPos);
  camera.lookAt(camLook);
}

// ---------- الإيقاف ----------
let paused = false;
$('pause').addEventListener('pointerdown', (e) => { e.preventDefault(); e.stopPropagation(); setPaused(true); });
$('resume').addEventListener('click', () => setPaused(false));
$('quit').addEventListener('click', () => {
  send({ event: 'quit', home: match.teams[0].score, away: match.teams[1].score });
  if (!window.FootballChannel && window.parent === window) location.reload();
});
function setPaused(v) {
  paused = v;
  $('pausePanel').classList.toggle('show', v);
}
document.addEventListener('visibilitychange', () => { if (document.hidden && match.state !== 'end') setPaused(true); });

// ---------- نهاية المباراة ----------
function showEnd(r) {
  setTimeout(() => {
    const p = $('endPanel');
    $('eh').textContent = r.home;
    $('ea').textContent = r.away;
    $('ehn').textContent = home.name;
    $('ean').textContent = away.name;
    $('ehc').src = home.crest;
    $('eac').src = away.crest;
    $('etitle').textContent = r.result === 'win' ? 'فوز! 🏆' : r.result === 'draw' ? 'تعادل' : 'خسارة';
    const sc = (i) => r.events.filter((e) => e.team === i).map((e) => `${e.own ? 'عكسي' : e.name || '#' + e.num} ${e.min}'`).join(' · ') || '—';
    $('egoals').innerHTML = `<div>${sc(0)}</div><div>${sc(1)}</div>`;
    $('estats').innerHTML = [
      ['الاستحواذ', r.possession + '%', 100 - r.possession + '%'],
      ['التسديدات', r.shots[0], r.shots[1]],
      ['على المرمى', r.onTarget[0], r.onTarget[1]],
      ['التمريرات', r.passes[0], r.passes[1]],
    ].map(([n, a, b]) => `<div class="row"><b>${a}</b><span>${n}</span><b>${b}</b></div>`).join('');
    p.classList.add('show');
    $('controls').style.display = 'none';
    send({ event: 'end', ...r });
  }, 2200);
}
$('done').addEventListener('click', () => {
  send({ event: 'close' });
  if (!window.FootballChannel && window.parent === window) location.reload();
});

// تشغيل الصوت بأول لمسة
app.addEventListener('pointerdown', () => audio.unlock(), { capture: true });
window.addEventListener('keydown', () => audio.unlock());

// ---------- الحلقة ----------
let last = performance.now();
let fpsAcc = 0, fpsN = 0, qualityChecked = false, elapsed = 0;
$('intro').classList.add('show');
setTimeout(() => $('intro').classList.remove('show'), 3000);
let lastState = '';
const SIM = +(params.get('sim') || 0); // للاختبار فقط

function frame(now) {
  requestAnimationFrame(frame);
  let dt = (now - last) / 1000;
  last = now;
  if (dt > 0.25) dt = 0.25;
  elapsed += dt;
  input.poll();
  if (input.camPressed) camMode = (camMode + 1) % 2;
  if (!paused) {
    if (SIM) for (let i = 0; i < SIM; i++) match.update(1 / 30, input);
    else match.update(dt, input);
    if (match.state !== lastState) {
      if (lastState === 'intro') { $('intro').classList.remove('show'); audio.whistle(1); }
      if (match.state === 'kickoff' && lastState === 'goal') audio.whistle(1);
      lastState = match.state;
    }
  }
  updateCamera(dt);
  world.update(dt, elapsed, match.excite);
  audio.update(dt, match.excite, elapsed);

  // الواجهة
  const m = Math.min(90, Math.floor(match.clock / 60));
  const s = Math.floor(match.clock % 60);
  $('clock').textContent = `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  const cp = match.user.cp;
  const attacking = cp && match.ball.owner === cp;
  const teamHas = match.ball.owner && match.ball.owner.team === match.user.team;
  $('la').textContent = attacking || match.state !== 'play' ? 'تمرير' : teamHas ? 'تمرير' : 'تبديل';
  $('lb').textContent = attacking || match.state !== 'play' ? 'تسديد' : 'افتكاك';
  $('who').textContent = match.state === 'play' || match.state === 'setpiece' ? match.controlledInfo : '';
  if (toastT > 0) { toastT -= dt; if (toastT <= 0) hud.toast(''); }

  renderer.render(scene, camera);

  // جودة تلقائية: نخفف الدقة إذا كان الجهاز بطيئاً
  if (!qualityChecked && elapsed > 1.5) {
    fpsAcc += dt; fpsN++;
    if (fpsAcc > 2.5) {
      const fps = fpsN / fpsAcc;
      qualityChecked = true;
      if (fps < 40 && pr > 1) {
        pr = 1;
        renderer.setPixelRatio(pr);
        resize();
      }
      if (fps < 26) {
        world.sun.shadow.mapSize.set(1024, 1024);
        world.sun.shadow.map?.dispose();
        world.sun.shadow.map = null;
      }
    }
  }
  input.endFrame();
}
requestAnimationFrame(frame);
send({ event: 'ready' });
