import * as THREE from 'three';
import { HL, HW, GOAL_HW, GOAL_H, GOAL_D, BALL_R, G, clamp, lerp, rand, gauss, dist2, angDiff } from './consts.js';
import { PlayerModel, makeRing } from './player_model.js';

// 4-4-2: (x من -1 مرمانا إلى +1 مرمى الخصم، z من -1 إلى 1)
const FORMATION = [
  ['GK', -0.96, 0],
  ['DEF', -0.62, -0.66], ['DEF', -0.7, -0.22], ['DEF', -0.7, 0.22], ['DEF', -0.62, 0.66],
  ['MID', -0.27, -0.68], ['MID', -0.33, -0.2], ['MID', -0.33, 0.2], ['MID', -0.27, 0.68],
  ['FWD', 0.02, -0.2], ['FWD', 0.06, 0.2],
];
const NUMBERS = [1, 2, 4, 5, 3, 7, 8, 6, 11, 9, 10];

export const DIFF = {
  easy: { speed: 0.88, react: 0.32, tackle: 0.6, save: 0.4, err: 1.5, pass: 0.22, userSave: 0.68 },
  normal: { speed: 0.97, react: 0.22, tackle: 1.15, save: 0.56, err: 1.0, pass: 0.32, userSave: 0.62 },
  hard: { speed: 1.06, react: 0.14, tackle: 1.9, save: 0.7, err: 0.7, pass: 0.42, userSave: 0.56 },
};

const ROLE_NAMES = { GK: 'حارس', DEF: 'مدافع', MID: 'وسط', FWD: 'مهاجم' };

class Player {
  constructor(team, idx, model, ring) {
    const [role, nx, nz] = FORMATION[idx];
    this.team = team;
    this.idx = idx;
    this.role = role;
    this.isGK = role === 'GK';
    this.nx = nx;
    this.nz = nz;
    this.number = NUMBERS[idx];
    this.model = model;
    this.ring = ring;
    this.x = 0; this.z = 0; this.vx = 0; this.vz = 0;
    this.face = team.side > 0 ? Math.PI / 2 : -Math.PI / 2;
    this.kickCd = 0;
    this.stun = 0;
    this.decT = 0;
    this.holdT = 0;
    this.stat = rand(0.95, 1.05);
    this.tx = 0; this.tz = 0;
    this.plan = null;
    this.slide = 0;
    this.turnRate = 0;
  }
  get speed() { return Math.hypot(this.vx, this.vz); }
  fwdX() { return Math.sin(this.face); }
  fwdZ() { return Math.cos(this.face); }
}

export class Match {
  constructor(scene, cfg, audio, hud) {
    this.scene = scene;
    this.cfg = cfg;
    this.audio = audio;
    this.hud = hud;
    this.diff = DIFF[cfg.diff] || DIFF.normal;
    this.time = 0;
    this.clock = 0; // ثواني المباراة (0 - 90*60)
    this.realDur = (cfg.mins || 4) * 60;
    this.half = 1;
    this.timeScale = 1;
    this.excite = 0.15;
    this.events = [];
    this.stats = { shots: [0, 0], onTarget: [0, 0], poss: [0, 0], passes: [0, 0] };

    const mkTeam = (t, side, isUser) => ({ ...t, side, isUser, score: 0, players: [] });
    this.teams = [mkTeam(cfg.home, 1, true), mkTeam(cfg.away, -1, false)];
    this.teams[0].opp = this.teams[1];
    this.teams[1].opp = this.teams[0];
    this.players = [];
    for (const team of this.teams) {
      for (let i = 0; i < 11; i++) {
        const gk = i === 0;
        const kit = gk
          ? { shirt: team.gk, trim: '#111111', shorts: '#1a1a1a', socks: team.gk, number: 1, keeper: true, numColor: '#111' }
          : { shirt: team.c1, trim: team.c2, shorts: team.shorts, socks: team.c1, number: NUMBERS[i], pattern: team.pattern, numColor: team.num };
        kit.scale = rand(0.95, 1.06);
        const model = new PlayerModel(kit);
        scene.add(model.root);
        const ring = makeRing(team.isUser ? 0xffe14d : 0xff5a5a);
        ring.visible = false;
        scene.add(ring);
        const p = new Player(team, i, model, ring);
        team.players.push(p);
        this.players.push(p);
      }
    }
    // الحكم
    this.ref = new PlayerModel({ shirt: '#111111', trim: '#e6e600', shorts: '#111111', socks: '#111111', number: '', numColor: '#000' });
    this.ref.root.position.set(0, 0, 10);
    this.refPos = { x: 0, z: 10, vx: 0, vz: 0, face: 0 };
    scene.add(this.ref.root);

    // الكرة
    this.ball = {
      x: 0, y: BALL_R, z: 0, vx: 0, vy: 0, vz: 0,
      owner: null, lastTeam: null, lastPlayer: null, passTarget: null, shot: null, cross: false,
      mesh: makeBallMesh(),
    };
    scene.add(this.ball.mesh);
    this.ball.mesh.castShadow = true;

    this.user = { team: this.teams[0], cp: null, switchT: 0 };
    this.auto = !!cfg.auto;
    this.state = 'intro';
    this.stateT = 0;
    this.sp = null;
    this.setupKickoff(this.teams[0], true);
    this.state = 'intro';
  }

  // ---------- أدوات ----------
  other(team) { return team.opp; }
  ownGoalX(team) { return -team.side * HL; }
  oppGoalX(team) { return team.side * HL; }

  formationPos(p, phase) {
    const team = p.team;
    const side = team.side;
    const b = this.ball;
    const bp = b.owner ? b.owner : b;
    const ballN = (bp.x * side) / HL; // تقدم الكرة من منظور الفريق
    const has = b.owner && b.owner.team === team;
    let nx = p.nx, nz = p.nz;
    if (phase === 'kickoff') {
      return { x: side * Math.min(-0.04, nx * 0.92) * HL, z: nz * HW * 0.82 };
    }
    let shift = ballN * 0.5 + (has ? 0.2 : -0.06);
    let x = nx + shift;
    if (p.role === 'DEF') x = clamp(x, -0.9, has ? 0.25 : 0.05);
    if (p.role === 'MID') x = clamp(x, -0.75, 0.65);
    if (p.role === 'FWD') x = clamp(x + (has ? 0.12 : 0), -0.25, 0.92);
    const bz = bp.z / HW;
    let z = nz * (has ? 0.92 : 0.7) + bz * (has ? 0.18 : 0.35);
    // الهجوم لا يتجاوز آخر مدافع (تسلل مبسط)
    let wx = side * x * HL;
    if (p.role !== 'DEF') {
      const lastDef = this.lastDefenderX(team.opp);
      if ((wx - lastDef) * side > -0.6) wx = lastDef - side * 0.6;
      if ((bp.x - lastDef) * side > 0) wx = side > 0 ? Math.min(wx, bp.x) : Math.max(wx, bp.x);
    }
    return { x: clamp(wx, -HL + 1, HL - 1), z: clamp(z * HW, -HW + 1.5, HW - 1.5) };
  }

  lastDefenderX(team) {
    // أعمق لاعب ميدان (غير الحارس) باتجاه مرماه
    let best = team.side * HL;
    for (const p of team.players) {
      if (p.isGK) continue;
      if (p.x * team.side < best * team.side) best = p.x;
    }
    return best;
  }

  predictBall(t) {
    const b = this.ball;
    const k = b.y > BALL_R + 0.05 ? 0.15 : 0.55;
    const f = (1 - Math.exp(-k * t)) / k;
    return { x: b.x + b.vx * f, z: b.z + b.vz * f };
  }

  timeToBall(p) {
    const b = this.ball;
    if (b.owner) return dist2(p.x, p.z, b.owner.x, b.owner.z) / 7;
    const sp = 7.2;
    for (let t = 0; t <= 3; t += 0.1) {
      const q = this.predictBall(t);
      if (dist2(p.x, p.z, q.x, q.z) <= sp * t + 0.6) return t;
    }
    return 3 + dist2(p.x, p.z, b.x, b.z) / sp;
  }

  nearestOpp(p, x = p.x, z = p.z) {
    let best = null, bd = 1e9;
    for (const o of p.team.opp.players) {
      const d = dist2(x, z, o.x, o.z);
      if (d < bd) { bd = d; best = o; }
    }
    return { o: best, d: bd };
  }

  // ---------- الحركة ----------
  steer(p, dvx, dvz, dt, acc = 16) {
    const ax = dvx - p.vx, az = dvz - p.vz;
    const a = Math.hypot(ax, az);
    const max = acc * dt;
    if (a > max) { p.vx += (ax / a) * max; p.vz += (az / a) * max; }
    else { p.vx = dvx; p.vz = dvz; }
  }

  moveTo(p, tx, tz, speed, dt) {
    const dx = tx - p.x, dz = tz - p.z;
    const d = Math.hypot(dx, dz);
    const s = d < 0.25 ? 0 : Math.min(speed, d * 2.4);
    this.steer(p, d > 0.001 ? (dx / d) * s : 0, d > 0.001 ? (dz / d) * s : 0, dt);
  }

  // ---------- الركلات ----------
  kick(p, vx, vy, vz, kind) {
    const b = this.ball;
    b.owner = null;
    b.vx = vx; b.vy = vy; b.vz = vz;
    b.y = Math.max(b.y, BALL_R);
    b.lastTeam = p.team;
    b.lastPlayer = p;
    b.passTarget = null;
    b.shot = null;
    b.cross = false;
    p.kickCd = 0.32;
    p.holdT = 0;
    const power = Math.hypot(vx, vy, vz) / 32;
    if (kind !== 'throw') {
      p.model.setAnim('kick', { restart: true, kickLeg: Math.random() < 0.8 ? 1 : -1 });
      this.audio.kick(power);
    } else p.model.setAnim('throw', { restart: true });
    // واجه اتجاه الركلة
    p.face = Math.atan2(vx, vz);
  }

  pass(p, mate, lofted = false, kind = 'pass') {
    const b = this.ball;
    const d0 = dist2(p.x, p.z, mate.x, mate.z);
    // نقود الكرة أمام المستلم
    const lead = d0 / (lofted ? 20 : 17);
    let tx = mate.x + mate.vx * lead * 0.85, tz = mate.z + mate.vz * lead * 0.85;
    if (lofted && kind !== 'cross') { tx += mate.team.side * 2.5; }
    tx = clamp(tx, -HL + 0.5, HL - 0.5);
    tz = clamp(tz, -HW + 0.5, HW - 0.5);
    const dx = tx - b.x, dz = tz - b.z;
    const d = Math.hypot(dx, dz) || 1;
    const errA = gauss() * (p.team.isUser && !this.auto ? 0.03 : 0.045 * this.diff.err);
    const ca = Math.cos(errA), sa = Math.sin(errA);
    const ux = (dx / d) * ca - (dz / d) * sa, uz = (dx / d) * sa + (dz / d) * ca;
    if (kind === 'throw') {
      const T = 0.65 + d / 26;
      const vh = d / T;
      this.kick(p, ux * vh, (0.5 * G * T * T - 1.6) / T, uz * vh, 'throw');
    } else if (lofted) {
      const T = 0.85 + d / 26;
      const vh = (d / T) * 1.04;
      this.kick(p, ux * vh, (0.5 * G * T * T) / T, uz * vh, 'pass');
      b.cross = true;
    } else {
      const v0 = clamp(d * 0.55 * 1.2 + 5.5, 9, 27);
      this.kick(p, ux * v0, 0.4, uz * v0, 'pass');
    }
    b.passTarget = mate;
    this.stats.passes[this.teams.indexOf(p.team)]++;
    // المستخدم ينتقل للمستلم تلقائياً
    if (mate.team === this.user.team && !this.auto) this.setControlled(mate);
  }

  shoot(p, power, aimZ) {
    const b = this.ball;
    const team = p.team;
    const gx = this.oppGoalX(team);
    const keeper = team.opp.players[0];
    const isUser = team.isUser && !this.auto;
    let tz = aimZ;
    if (tz === null || tz === undefined) {
      // الذكاء الاصطناعي يختار الزاوية البعيدة عن الحارس
      const s = keeper.z > 0.2 ? -1 : keeper.z < -0.2 ? 1 : Math.random() < 0.5 ? -1 : 1;
      tz = s * rand(1.6, 3.3);
    }
    const dGoal = dist2(b.x, b.z, gx, 0);
    const pressure = this.nearestOpp(p).d;
    const errScale = (isUser ? 0.75 : this.diff.err) * (0.5 + dGoal / 28 + (pressure < 1.5 ? 0.6 : 0) + Math.max(0, power - 0.85) * 2);
    tz += gauss() * 1.4 * errScale;
    let ty = 0.25 + power * 1.55 + rand(-0.2, 0.5);
    if (power > 0.86) ty += (power - 0.86) * rand(4, 14);
    if (dGoal > 30) ty += rand(0, 0.6);
    const tx = gx + team.side * 0.3;
    const dx = tx - b.x, dz = tz - b.z;
    const d = Math.hypot(dx, dz);
    const speed = 15 + power * 17;
    const t = d / speed * 1.03;
    const vy = (ty - b.y + 0.5 * G * t * t) / t;
    this.kick(p, (dx / d) * speed, vy, (dz / d) * speed, 'shot');
    b.shot = { team, t: this.time };
    this.stats.shots[this.teams.indexOf(team)]++;
    this.excite = Math.max(this.excite, 0.55);
    this.planSave(keeper);
  }

  planSave(k) {
    const b = this.ball;
    // محاكاة مسار الكرة حتى خط الحارس
    let x = b.x, y = b.y, z = b.z, vx = b.vx, vy = b.vy, vz = b.vz, t = 0;
    const kx = k.x;
    const dirSign = Math.sign(kx - x);
    let hit = null;
    for (let i = 0; i < 300; i++) {
      const dt = 1 / 120;
      vy -= G * dt;
      x += vx * dt; y += vy * dt; z += vz * dt; t += dt;
      if (y < BALL_R) { y = BALL_R; vy = -vy * 0.5; vx *= 0.9; vz *= 0.9; }
      if (Math.sign(kx - x) !== dirSign) { hit = { z, y, t }; break; }
    }
    if (!hit) { k.plan = null; return; }
    const onTarget = Math.abs(hit.z) < GOAL_HW + 0.15 && hit.y < GOAL_H + 0.1;
    const idx = this.teams.indexOf(b.shot?.team ?? k.team.opp);
    if (onTarget) this.stats.onTarget[idx]++;
    const userKeeper = k.team.isUser;
    const base = userKeeper ? this.diff.userSave : this.diff.save;
    const reach = Math.abs(hit.z - k.z);
    const sp = Math.hypot(b.vx, b.vy, b.vz);
    let pSave = base - Math.max(0, reach - 1.1) * 0.12 - Math.max(0, sp - 21) * 0.022 + (hit.t - 0.55) * 0.4;
    if (hit.y > 1.9 && reach > 2.2) pSave -= 0.12;
    if (reach < 0.9 && hit.y < 1.9) pSave += 0.25;
    const save = onTarget && Math.random() < clamp(pSave, 0.06, 0.96);
    const react = this.diff.react * (userKeeper ? 0.9 : 1) + rand(0, 0.08);
    const wrong = !save && onTarget;
    k.plan = {
      t0: this.time,
      react,
      z: save ? hit.z : wrong ? lerp(k.z, hit.z, rand(0.2, 0.55)) : clamp(hit.z, -GOAL_HW, GOAL_HW),
      y: hit.y,
      save,
      onTarget,
      catch: save && sp < 22 && hit.y < 1.7 && Math.random() < 0.6,
      dove: false,
      eta: hit.t,
    };
  }

  // ---------- الافتكاك ----------
  tryTackle(p, slide) {
    const b = this.ball;
    const o = b.owner;
    p.model.setAnim(slide ? 'tackle' : 'stand_tackle', { restart: true });
    if (slide) { p.slide = 0.55; p.vx = p.fwdX() * 8; p.vz = p.fwdZ() * 8; }
    if (!o) {
      // كرة حرة قريبة
      if (dist2(p.x, p.z, b.x, b.z) < (slide ? 2.4 : 1.4) && b.y < 1) {
        const dir = p.face;
        b.vx = Math.sin(dir) * 7; b.vz = Math.cos(dir) * 7; b.vy = 0.5;
        b.lastTeam = p.team; b.lastPlayer = p; b.passTarget = null;
        this.audio.kick(0.3);
      }
      p.stun = slide ? 0.9 : 0.35;
      return false;
    }
    if (o.team === p.team) return false;
    const d = dist2(p.x, p.z, o.x, o.z);
    const reach = slide ? 2.7 : 1.6;
    if (d > reach) { p.stun = slide ? 1.0 : 0.4; return false; }
    // من الأمام أسهل
    const dx = (p.x - o.x) / (d || 1), dz = (p.z - o.z) / (d || 1);
    const front = dx * o.fwdX() + dz * o.fwdZ();
    const userDef = p.team.isUser && !this.auto;
    let chance = (slide ? 0.6 : 0.52) + front * 0.18 + (userDef ? 0.12 : 0) - (o.team.isUser && !this.auto ? 0.06 : 0);
    if (Math.random() < chance) {
      o.stun = 0.75;
      o.model.setAnim('stand_tackle', { restart: true });
      if (!slide && Math.random() < 0.65) {
        b.owner = p;
        b.lastTeam = p.team; b.lastPlayer = p;
        this.onPossession(p);
      } else {
        b.owner = null;
        const a = p.face + rand(-0.8, 0.8);
        b.vx = Math.sin(a) * rand(5, 9); b.vz = Math.cos(a) * rand(5, 9); b.vy = rand(0.5, 2);
        b.lastTeam = p.team; b.lastPlayer = p; b.passTarget = null;
        o.kickCd = 0.5;
      }
      this.audio.kick(0.35);
      return true;
    }
    p.stun = slide ? 1.1 : 0.45;
    return false;
  }

  onPossession(p) {
    const b = this.ball;
    b.passTarget = null;
    b.shot = null;
    b.cross = false;
    p.holdT = 0;
    p.decT = rand(0.15, 0.35);
    for (const q of this.players) if (q.isGK) q.plan = null;
    if (p.team === this.user.team && !this.auto && !p.isGK) this.setControlled(p);
  }

  setControlled(p) {
    if (this.user.cp === p) return;
    this.user.cp = p;
    this.user.switchT = this.time;
  }

  switchPlayer() {
    // أقرب لاعب للكرة غير الحالي (ويُفضّل من بين الكرة والمرمى)
    const b = this.ball.owner || this.ball;
    let best = null, bd = 1e9;
    for (const p of this.user.team.players) {
      if (p.isGK || p === this.user.cp) continue;
      let d = dist2(p.x, p.z, b.x, b.z);
      if ((p.x - b.x) * this.user.team.side < 0) d *= 0.8;
      if (d < bd) { bd = d; best = p; }
    }
    if (best) this.setControlled(best);
  }

  // ---------- الركلات الثابتة ----------
  setupKickoff(team, instant) {
    const b = this.ball;
    Object.assign(b, { x: 0, y: BALL_R, z: 0, vx: 0, vy: 0, vz: 0, owner: null, passTarget: null, shot: null, cross: false });
    for (const p of this.players) {
      const f = this.formationPos(p, 'kickoff');
      p.x = f.x; p.z = f.z; p.vx = 0; p.vz = 0;
      p.face = p.team.side > 0 ? Math.PI / 2 : -Math.PI / 2;
      p.plan = null; p.stun = 0; p.kickCd = 0;
      p.model.setAnim('idle');
      // الخصم خارج الدائرة
      if (p.team !== team) {
        const d = Math.hypot(p.x, p.z);
        if (d < 9.6) { const s = 9.6 / (d || 1); p.x *= s; p.z *= s; if (p.x * p.team.side > -1) p.x = -p.team.side * 9.6; }
      }
    }
    const fwds = team.players.filter((p) => p.role === 'FWD');
    fwds[0].x = -team.side * 0.45; fwds[0].z = 0;
    fwds[1].x = -team.side * 0.6; fwds[1].z = 6;
    this.startSetPiece('kickoff', team, 0, 0, fwds[0]);
    if (team === this.user.team) this.setControlled(fwds[0]);
    else this.setControlled(this.user.team.players.find((p) => p.role === 'FWD'));
    this.refPos.x = 0; this.refPos.z = 12;
  }

  startSetPiece(type, team, x, z, taker) {
    const b = this.ball;
    Object.assign(b, { x, y: BALL_R, z, vx: 0, vy: 0, vz: 0, owner: null, passTarget: null, shot: null, cross: false });
    if (!taker) {
      if (type === 'goalkick') taker = team.players[0];
      else {
        let bd = 1e9;
        for (const p of team.players) {
          if (p.isGK) continue;
          const d = dist2(p.x, p.z, x, z);
          if (d < bd) { bd = d; taker = p; }
        }
      }
    }
    this.sp = { type, team, x, z, taker, t: 0 };
    this.state = type === 'kickoff' ? 'kickoff' : 'setpiece';
    this.stateT = 0;
    for (const p of this.players) p.plan = null;
    if (team === this.user.team && !this.auto && !taker.isGK) this.setControlled(taker);
    const names = { throw: 'رمية تماس', corner: 'ركنية', goalkick: 'ضربة مرمى' };
    if (names[type]) this.hud.toast(names[type] + ' · ' + team.name);
    if (type !== 'kickoff') this.audio.whistle(1);
  }

  takerSpot(sp) {
    // يقف الراكل خلف الكرة باتجاه الملعب
    const t = sp.team;
    if (sp.type === 'throw') return { x: sp.x, z: sp.z + Math.sign(sp.z) * 0.4, face: Math.sign(sp.z) > 0 ? Math.PI : 0 };
    if (sp.type === 'corner') {
      const fx = -Math.sign(sp.x), fz = -Math.sign(sp.z);
      return { x: sp.x - fx * 0.9, z: sp.z - fz * 0.6, face: Math.atan2(fx * 0.5, fz) };
    }
    if (sp.type === 'goalkick') return { x: sp.x - t.side * 1.4, z: sp.z, face: t.side > 0 ? Math.PI / 2 : -Math.PI / 2 };
    return { x: sp.x - t.side * 0.45, z: sp.z, face: t.side > 0 ? Math.PI / 2 : -Math.PI / 2 };
  }

  executeSetPiece(dirX, dirZ, strong) {
    const sp = this.sp;
    const p = sp.taker;
    const team = sp.team;
    const mates = team.players.filter((q) => q !== p && !q.isGK);
    const pick = (fn) => mates.map((m) => ({ m, s: fn(m) })).sort((a, b) => b.s - a.s)[0].m;
    const byDir = (m) => {
      if (dirX === null) return 0;
      const dx = m.x - p.x, dz = m.z - p.z, d = Math.hypot(dx, dz) || 1;
      return ((dx * dirX + dz * dirZ) / d) * 3 - d / 25;
    };
    let mate;
    if (sp.type === 'corner') {
      const gx = this.oppGoalX(team);
      mate = pick((m) => -dist2(m.x, m.z, gx - team.side * 9, rand(-5, 5)) + byDir(m) + rand(0, 4));
      this.pass(p, mate, true, 'cross');
    } else if (sp.type === 'throw') {
      mate = pick((m) => -Math.abs(dist2(m.x, m.z, p.x, p.z) - 12) + byDir(m) * 2 - this.nearestOpp(m).d * -0.5 + rand(0, 2));
      this.pass(p, mate, false, 'throw');
    } else if (sp.type === 'goalkick') {
      mate = pick((m) => (m.role === 'DEF' ? (strong ? -5 : 2) : 0) + byDir(m) * 2 + this.nearestOpp(m).d * 0.4 + rand(0, 3) - Math.abs(dist2(m.x, m.z, p.x, p.z) - (strong ? 45 : 20)) * 0.1);
      this.pass(p, mate, dist2(mate.x, mate.z, p.x, p.z) > 22);
    } else {
      mate = pick((m) => -dist2(m.x, m.z, p.x, p.z) + byDir(m) * 2);
      this.pass(p, mate, false);
      this.hud.toast('');
    }
    this.sp = null;
    this.state = 'play';
    this.stateT = 0;
  }

  // ---------- حلقة التحديث ----------
  update(rawDt, input) {
    const dt = Math.min(rawDt, 1 / 20) * this.timeScale * (this.cfg.speed || 1);
    this.time += dt;
    this.stateT += dt;
    this.excite = Math.max(0.12, this.excite - dt * 0.12);

    switch (this.state) {
      case 'intro':
        if (this.stateT > 3.2 || input.anyPressed) { this.state = 'kickoff'; this.stateT = 0; this.hud.banner(''); }
        this.animateModels(dt);
        return;
      case 'goal':
        this.updateGoal(dt);
        return;
      case 'half':
        if (this.stateT > 3.5) {
          this.hud.banner('');
          this.half = 2;
          this.setupKickoff(this.teams[1]);
        }
        this.animateModels(dt);
        return;
      case 'end':
        for (const p of this.players) {
          const won = p.team.score > p.team.opp.score;
          this.moveTo(p, p.x, p.z, 0, dt);
          if (won) p.model.setAnim('celebrate'); else if (p.team.score < p.team.opp.score) p.model.setAnim('sad');
        }
        this.integratePlayers(dt);
        this.animateModels(dt);
        return;
    }

    // الوقت
    if (this.state === 'play' || this.state === 'setpiece') {
      const prev = this.clock;
      this.clock += (dt / this.realDur) * 90 * 60;
      if (prev < 45 * 60 && this.clock >= 45 * 60 && this.half === 1) {
        this.clock = 45 * 60;
        this.audio.whistle(2, true);
        this.state = 'half';
        this.stateT = 0;
        this.hud.banner('نهاية الشوط الأول', `${this.teams[0].score} - ${this.teams[1].score}`);
        return;
      }
      if (this.clock >= 90 * 60) {
        this.clock = 90 * 60;
        this.finish();
        return;
      }
    }

    // الاستحواذ للإحصاءات
    if (this.ball.owner) this.stats.poss[this.teams.indexOf(this.ball.owner.team)] += dt;

    if (this.state === 'kickoff' || this.state === 'setpiece') this.updateSetPiece(dt, input);
    else this.updatePlay(dt, input);

    this.integratePlayers(dt);
    if (this.state === 'play') this.updateBall(dt);
    else this.syncBallSetPiece();
    this.updateRef(dt);
    this.animateModels(dt);
  }

  updateSetPiece(dt, input) {
    const sp = this.sp;
    sp.t += dt;
    const spot = this.takerSpot(sp);
    const userTakes = sp.team === this.user.team && !this.auto;
    for (const p of this.players) {
      if (p === sp.taker) {
        this.moveTo(p, spot.x, spot.z, 8, dt);
        if (dist2(p.x, p.z, spot.x, spot.z) < 0.4) p.face += angDiff(p.face, spot.face) * Math.min(1, dt * 8);
        if (sp.type === 'throw') p.model.setAnim('throw');
        continue;
      }
      let f;
      if (sp.type === 'corner' && !p.isGK) f = this.cornerPos(p, sp);
      else if (p.isGK) f = { x: this.ownGoalX(p.team) + p.team.side * 0.8, z: 0 };
      else if (sp.type === 'kickoff') f = this.formationPos(p, 'kickoff');
      else f = this.formationPos(p);
      if (sp.type === 'kickoff' && p.team.players.indexOf(p) >= 9 && p.team === sp.team) f = { x: p.x, z: p.z };
      this.moveTo(p, f.x, f.z, 6.5, dt);
      // واجه الكرة
      if (p.speed < 0.5) p.face += angDiff(p.face, Math.atan2(this.ball.x - p.x, this.ball.z - p.z)) * Math.min(1, dt * 5);
    }
    const ready = sp.t > (sp.type === 'kickoff' ? 0.6 : 1.3) && dist2(sp.taker.x, sp.taker.z, spot.x, spot.z) < 0.6;
    if (!ready) {
      if (userTakes) this.hud.hint('');
      return;
    }
    if (userTakes && !sp.taker.isGK) {
      this.hud.hint(sp.type === 'corner' ? 'اضغط «تمرير» لعرضية' : 'اضغط «تمرير»');
      const mv = input.move;
      const mag = Math.hypot(mv.x, mv.y);
      const dx = mag > 0.2 ? mv.x / mag : null, dz = mag > 0.2 ? -mv.y / mag : null;
      if (input.a.released || input.b.released) {
        this.hud.hint('');
        this.executeSetPiece(dx, dz, input.b.released);
      }
    } else if (sp.t > (sp.type === 'kickoff' ? 1.4 : 2.2)) {
      this.executeSetPiece(null, null, Math.random() < 0.4);
    }
  }

  cornerPos(p, sp) {
    const att = p.team === sp.team;
    const gx = sp.x > 0 ? HL : -HL;
    const s = Math.sign(gx);
    const slots = att
      ? [[-11, -4], [-8, 2], [-6, -1], [-13, 6], [-7, 5], [-16, 0], [-25, -8], [-30, 10], [-40, 0], [-10, -9]]
      : [[-2, -3], [-3, 3], [-6, -2], [-6, 2], [-9, 0], [-8, -5], [-8, 5], [-13, 0], [-20, -6], [-20, 6]];
    const i = (p.idx - 1) % slots.length;
    const [ox, oz] = slots[i];
    return { x: gx + s * ox, z: oz * (sp.z > 0 ? 1 : -1) * 0.9 };
  }

  syncBallSetPiece() {
    const b = this.ball;
    const sp = this.sp;
    if (!sp) return;
    if (sp.type === 'throw') {
      const t = sp.taker;
      b.x = t.x + t.fwdX() * 0.05; b.z = t.z + t.fwdZ() * 0.05; b.y = 2.25;
    } else { b.x = sp.x; b.z = sp.z; b.y = BALL_R; }
  }

  updatePlay(dt, input) {
    const b = this.ball;
    for (const team of this.teams) this.teamAI(team, dt);
    if (!this.auto) this.userControl(dt, input);

    // تبديل تلقائي أثناء الدفاع إن ابتعد اللاعب كثيراً
    const cp = this.user.cp;
    if (!this.auto && cp && (!b.owner || b.owner.team !== this.user.team) && this.time - this.user.switchT > 1.5) {
      const bp = b.owner || b;
      const dCp = dist2(cp.x, cp.z, bp.x, bp.z);
      if (dCp > 14) {
        let best = cp, bd = dCp;
        for (const p of this.user.team.players) {
          if (p.isGK) continue;
          const d = dist2(p.x, p.z, bp.x, bp.z);
          if (d < bd - 7) { bd = d; best = p; }
        }
        if (best !== cp) this.setControlled(best);
      }
    }
  }

  userControl(dt, input) {
    const cp = this.user.cp;
    if (!cp) return;
    const b = this.ball;
    const mv = input.move;
    const mag = Math.min(1, Math.hypot(mv.x, mv.y));
    const dx = mag > 0.08 ? mv.x / mag : 0, dz = mag > 0.08 ? -mv.y / mag : 0;
    const hasBall = b.owner === cp;
    let sp = (input.sprint ? 8.3 : 6.2) * (hasBall ? 0.9 : 1);
    if (cp.stun > 0) sp *= 0.25;
    if (cp.slide > 0) return;
    const accel = hasBall ? 13 : 18;
    this.steer(cp, dx * sp * mag, dz * sp * mag, dt, accel);
    if (mag > 0.08 && cp.speed < 0.6) cp.face += angDiff(cp.face, Math.atan2(dx, dz)) * Math.min(1, dt * 14);

    const dirX = mag > 0.2 ? dx : cp.fwdX(), dirZ = mag > 0.2 ? dz : cp.fwdZ();
    if (hasBall) {
      if (input.a.released) {
        const lofted = input.a.heldFor > 0.28;
        const mate = this.pickPassTarget(cp, dirX, dirZ, lofted);
        if (mate) this.pass(cp, mate, lofted);
      } else if (input.b.down) {
        this.hud.power(Math.min(1, input.b.held / 0.85));
      } else if (input.b.released) {
        const power = Math.min(1, input.b.heldFor / 0.85);
        this.hud.power(null);
        // التصويب: أعلى الشاشة = القائم البعيد (z سالب)
        const aimZ = mag > 0.25 ? clamp(-mv.y, -1, 1) * 3.1 : null;
        const gx = this.oppGoalX(cp.team);
        if (Math.abs(cp.x - gx) < 40) this.shoot(cp, Math.max(0.25, power), aimZ);
        else {
          // بعيد عن المرمى: كرة طويلة للأمام
          const mate = this.pickPassTarget(cp, dirX, dirZ, true);
          if (mate) this.pass(cp, mate, true);
        }
      }
    } else {
      this.hud.power(null);
      if (input.a.pressed) {
        if (b.owner && b.owner.team === cp.team) {
          // زميل (الحارس) يملك الكرة: اطلبها
        } else this.switchPlayer();
      }
      if (input.b.pressed) {
        const o = b.owner;
        const d = o ? dist2(cp.x, cp.z, o.x, o.z) : dist2(cp.x, cp.z, b.x, b.z);
        this.tryTackle(cp, input.sprint && d > 1.3);
      }
    }
  }

  pickPassTarget(p, dirX, dirZ, lofted) {
    let best = null, bs = -1e9;
    for (const m of p.team.players) {
      if (m === p) continue;
      const dx = m.x - p.x, dz = m.z - p.z;
      const d = Math.hypot(dx, dz) || 1;
      const cos = (dx * dirX + dz * dirZ) / d;
      if (cos < 0.2 && !m.isGK) continue;
      let s = cos * 4 - d / (lofted ? 40 : 22) + this.nearestOpp(m).d * 0.08;
      if (m.isGK) s -= 3;
      if (s > bs) { bs = s; best = m; }
    }
    return best;
  }

  // ---------- ذكاء الفريق ----------
  teamAI(team, dt) {
    const b = this.ball;
    const has = b.owner && b.owner.team === team;
    const oppHas = b.owner && b.owner.team !== team;
    const userTeam = team === this.user.team && !this.auto;
    const spd = userTeam ? 1 : this.diff.speed;
    let chaser = null, cover = null;
    if (!has) {
      const ranked = team.players.filter((p) => !p.isGK && p.stun <= 0).map((p) => ({ p, t: this.timeToBall(p) })).sort((a, c) => a.t - c.t);
      chaser = ranked[0]?.p;
      cover = ranked[1]?.p;
      if (b.passTarget && b.passTarget.team === team && !b.owner) { cover = chaser === b.passTarget ? cover : chaser; chaser = b.passTarget; }
    }
    for (const p of team.players) {
      if (p.kickCd > 0) p.kickCd -= dt;
      if (p.stun > 0) p.stun -= dt;
      if (p.slide > 0) { p.slide -= dt; p.vx *= Math.exp(-dt * 3); p.vz *= Math.exp(-dt * 3); continue; }
      if (userTeam && p === this.user.cp) continue;
      // قد تتغير الحيازة أثناء الحلقة (تمريرة/افتكاك)
      const has = b.owner && b.owner.team === team;
      const oppHas = b.owner && b.owner.team !== team;
      const maxRun = 7.2 * spd * p.stat * (p.stun > 0 ? 0.3 : 1);
      if (p.isGK) { this.keeperAI(p, dt); continue; }
      if (p === b.owner) { this.carrierAI(p, dt, maxRun); continue; }
      if (p === chaser) {
        if (oppHas) {
          const o = b.owner;
          const tx = o.x + o.vx * 0.25 - this.ownGoalDir(team) * 0.6, tz = o.z + o.vz * 0.25;
          this.moveTo(p, tx, tz, maxRun, dt);
          const d = dist2(p.x, p.z, o.x, o.z);
          if (!userTeam || this.auto) {
            const rate = this.diff.tackle;
            if (d < 1.45 && p.stun <= 0 && Math.random() < rate * dt) this.tryTackle(p, false);
            else if (d < 2.4 && d > 1.5 && p.stun <= 0 && Math.random() < rate * 0.12 * dt) this.tryTackle(p, true);
          } else if (d < 1.4 && p.stun <= 0 && Math.random() < 0.9 * dt) this.tryTackle(p, false);
        } else {
          const t = Math.min(this.timeToBall(p), 3);
          const q = this.predictBall(t);
          this.moveTo(p, q.x, q.z, maxRun, dt);
        }
        continue;
      }
      let f = this.formationPos(p);
      if (oppHas && p === cover) {
        // تغطية: بين حامل الكرة ومرمانا
        const o = b.owner;
        const gx = this.ownGoalX(team);
        f = { x: lerp(o.x, gx, 0.18), z: lerp(o.z, 0, 0.18) };
      } else if (oppHas && (p.role === 'DEF' || p.role === 'MID')) {
        // رقابة: أقرب مهاجم في منطقته
        let mk = null, md = 11;
        for (const o of team.opp.players) {
          if (o.isGK || o === b.owner) continue;
          const d = dist2(o.x, o.z, f.x, f.z);
          if (d < md) { md = d; mk = o; }
        }
        if (mk) {
          const gx = this.ownGoalX(team);
          const gd = dist2(mk.x, mk.z, gx, 0) || 1;
          f = { x: lerp(f.x, mk.x + ((gx - mk.x) / gd) * 1.6, 0.6), z: lerp(f.z, mk.z + ((0 - mk.z) / gd) * 1.6, 0.6) };
        }
      } else if (has && (p.role === 'FWD' || p.role === 'MID')) {
        // تحركات بدون كرة
        const o = b.owner;
        const wob = Math.sin(this.time * 0.6 + p.idx * 1.7);
        f = { x: f.x + team.side * (p.role === 'FWD' ? 3 : 1.5) * (1 + wob * 0.5), z: f.z + wob * 3 };
        // ابتعد عن الحامل حتى لا تتكدسوا
        const d = dist2(f.x, f.z, o.x, o.z);
        if (d < 8) { f.x += ((f.x - o.x) / (d || 1)) * (8 - d); f.z += ((f.z - o.z) / (d || 1)) * (8 - d); }
      }
      const d = dist2(p.x, p.z, f.x, f.z);
      this.moveTo(p, f.x, f.z, d > 7 ? maxRun * 0.92 : d > 2 ? 4.8 : 2.5, dt);
    }
  }

  ownGoalDir(team) { return -team.side; }

  carrierAI(p, dt, maxRun) {
    const b = this.ball;
    const team = p.team;
    const side = team.side;
    const gx = this.oppGoalX(team);
    p.holdT += dt;
    p.decT -= dt;
    const dGoal = dist2(p.x, p.z, gx, 0);
    const near = this.nearestOpp(p);
    if (p.decT <= 0 && p.kickCd <= 0) {
      p.decT = rand(0.22, 0.45);
      const angOK = Math.abs(p.z) < 18 || dGoal < 15;
      const shootChance = dGoal < 13 ? 0.8 : dGoal < 20 ? 0.5 : dGoal < 28 ? 0.16 : 0;
      if (angOK && Math.random() < shootChance && (near.d > 1.4 || Math.random() < 0.4)) {
        this.shoot(p, clamp(0.5 + dGoal / 45 + rand(-0.08, 0.1), 0.45, 0.9), null);
        return;
      }
      const best = this.bestPass(p);
      let urge = (near.d < 2.0 ? 0.6 : near.d < 4 ? 0.16 : 0.03) + (p.holdT > 3 ? 0.25 : 0) + this.diff.pass * 0.12;
      if (best && best.s < 0.4) urge *= 0.5;
      if (dGoal < 30 && near.d > 3) urge *= 0.4;
      if (best && Math.random() < urge && best.s > -0.5) {
        const d = dist2(p.x, p.z, best.m.x, best.m.z);
        const lofted = d > 26 || (best.lane < 1.2 && d > 12);
        this.pass(p, best.m, lofted);
        return;
      }
    }
    // المراوغة نحو المرمى مع تفادي الخصوم
    let dx = gx - p.x, dz = clamp(-p.z * 0.4, -10, 10) + (dGoal < 25 ? -p.z * 0.6 : 0);
    let d = Math.hypot(dx, dz) || 1;
    dx /= d; dz /= d;
    for (const o of team.opp.players) {
      const ox = o.x - p.x, oz = o.z - p.z;
      const od = Math.hypot(ox, oz);
      if (od > 7 || od < 0.01) continue;
      const ahead = (ox * dx + oz * dz) / od;
      if (ahead < -0.2) continue;
      const w = ((7 - od) / 7) * (0.6 + ahead);
      // ابتعد جانبياً عن الخصم (عمودي على اتجاه الهجوم)
      const px = -dz, pz = dx; // العمودي
      const lat = ox * px + oz * pz > 0 ? -1 : 1;
      dx += px * lat * w * 1.1 - (ox / od) * w * 0.3;
      dz += pz * lat * w * 1.1 - (oz / od) * w * 0.3;
    }
    void side;
    // ابقَ داخل الملعب
    if (Math.abs(p.z) > HW - 4) dz -= Math.sign(p.z) * 1.5;
    d = Math.hypot(dx, dz) || 1;
    this.moveTo(p, p.x + (dx / d) * 5, p.z + (dz / d) * 5, maxRun * 0.86, dt);
  }

  bestPass(p) {
    const team = p.team;
    const side = team.side;
    const gx = this.oppGoalX(team);
    let best = null;
    for (const m of team.players) {
      if (m === p || m.isGK) continue;
      const d = dist2(p.x, p.z, m.x, m.z);
      if (d < 5 || d > 45) continue;
      const fwd = ((m.x - p.x) * side) / 30;
      const open = Math.min(this.nearestOpp(m).d, 8) / 8;
      let lane = 99;
      for (const o of team.opp.players) {
        lane = Math.min(lane, segDist(o.x, o.z, p.x, p.z, m.x, m.z));
      }
      const lanePen = lane < 1.2 ? -1.5 : lane < 2.5 ? -0.4 : 0;
      const goal = (1 - dist2(m.x, m.z, gx, 0) / 80) * 0.6;
      const s = fwd * 1.4 + open * 0.9 + lanePen + goal - (d > 32 ? (d - 32) / 15 : 0) + rand(0, 0.25);
      if (!best || s > best.s) best = { m, s, lane };
    }
    return best;
  }

  keeperAI(k, dt) {
    const b = this.ball;
    const team = k.team;
    const gx = this.ownGoalX(team);
    const side = team.side;
    const faceField = side > 0 ? Math.PI / 2 : -Math.PI / 2;
    if (b.owner === k) {
      k.holdT += dt;
      k.model.setAnim('hold');
      this.moveTo(k, gx + side * 6, k.z * 0.9, 3, dt);
      if (k.holdT > 1.4) {
        // التوزيع
        let best = null, bs = -1e9;
        for (const m of team.players) {
          if (m === k) continue;
          const s = Math.min(this.nearestOpp(m).d, 10) + (m.x - k.x) * side * 0.08 + rand(0, 3);
          if (s > bs) { bs = s; best = m; }
        }
        k.model.setAnim('idle');
        const d = dist2(k.x, k.z, best.x, best.z);
        this.pass(k, best, d > 25);
      }
      return;
    }
    if (k.plan) {
      const pl = k.plan;
      const el = this.time - pl.t0;
      if (el > pl.react) {
        const dz = pl.z - k.z;
        if (!pl.dove && Math.abs(dz) > 0.7 && pl.onTarget) {
          pl.dove = true;
          // اتجاه الارتماء بالنسبة لجسم الحارس
          const lx = Math.cos(k.face), lz = -Math.sin(k.face);
          k.model.setAnim('dive', { restart: true, diveDir: Math.sign(dz * lz + 0 * lx) || 1 });
        }
        const sp = pl.dove ? 7.5 : 5;
        this.steer(k, 0, clamp(dz * 6, -sp, sp), dt, 40);
      }
      k.face += angDiff(k.face, faceField) * Math.min(1, dt * 8);
      if (el > pl.eta + 1.0) k.plan = null;
      return;
    }
    // التمركز على خط الكرة والمرمى
    const bx = b.owner ? b.owner.x : b.x, bz = b.owner ? b.owner.z : b.z;
    const inBox = Math.abs(bx - gx) < 16.5 && Math.abs(bz) < 20.16;
    const others = team.players.filter((p) => !p.isGK);
    const myT = this.timeToBall(k);
    const theirBest = Math.min(...team.opp.players.map((p) => this.timeToBall(p)));
    if (!b.owner && inBox && myT < theirBest - 0.1 && b.y < 2.5 && !others.some((p) => p.team === team && b.owner === p)) {
      const q = this.predictBall(Math.min(myT, 1.5));
      this.moveTo(k, q.x, q.z, 7, dt);
      return;
    }
    const dx = bx - gx, dz = bz;
    const d = Math.hypot(dx, dz) || 1;
    const out = clamp(d * 0.09, 0.6, 5.5);
    const tx = gx + (dx / d) * out, tz = clamp((dz / d) * out * 1.3, -GOAL_HW + 0.4, GOAL_HW - 0.4);
    this.moveTo(k, tx, tz, 5.5, dt);
    if (k.speed < 0.6) {
      k.face += angDiff(k.face, Math.atan2(bx - k.x, bz - k.z)) * Math.min(1, dt * 6);
      if (Math.abs(bx - gx) < 35 && k.model.anim === 'idle') k.model.setAnim('keeper_ready');
    }
  }

  // ---------- الدمج الفيزيائي للاعبين ----------
  integratePlayers(dt) {
    const ps = this.players;
    for (const p of ps) {
      p.x += p.vx * dt;
      p.z += p.vz * dt;
      const sp = p.speed;
      if (sp > 0.6 && p.slide <= 0 && p.model.anim !== 'dive') {
        const want = Math.atan2(p.vx, p.vz);
        const turn = angDiff(p.face, want);
        const rate = this.ball.owner === p ? 7 : 11;
        const step = clamp(turn, -rate * dt, rate * dt);
        p.face += step;
        p.turnRate = step / dt;
      } else p.turnRate *= 0.8;
      p.x = clamp(p.x, -HL - 4, HL + 4);
      p.z = clamp(p.z, -HW - 3.5, HW + 3.5);
    }
    // التباعد البسيط
    for (let i = 0; i < ps.length; i++) {
      for (let j = i + 1; j < ps.length; j++) {
        const a = ps[i], c = ps[j];
        const dx = c.x - a.x, dz = c.z - a.z;
        const d2 = dx * dx + dz * dz;
        if (d2 < 0.64 && d2 > 1e-6) {
          const d = Math.sqrt(d2);
          const push = (0.8 - d) * 0.5;
          a.x -= (dx / d) * push; a.z -= (dz / d) * push;
          c.x += (dx / d) * push; c.z += (dz / d) * push;
        }
      }
    }
  }

  // ---------- الكرة ----------
  updateBall(dt) {
    const b = this.ball;
    if (b.owner) {
      const p = b.owner;
      // دحرجة أمام القدم
      const touch = 0.42 + Math.max(0, Math.sin(p.model.phase * 0.5)) * Math.min(0.5, p.speed * 0.07);
      const tx = p.x + p.fwdX() * touch, tz = p.z + p.fwdZ() * touch;
      if (p.isGK) {
        b.x = p.x + p.fwdX() * 0.3; b.z = p.z + p.fwdZ() * 0.3; b.y = 1.05;
      } else {
        b.x += (tx - b.x) * Math.min(1, dt * 18);
        b.z += (tz - b.z) * Math.min(1, dt * 18);
        b.y = BALL_R;
      }
      b.vx = p.vx; b.vz = p.vz; b.vy = 0;
      this.spinBall(dt);
      return;
    }
    const steps = 3;
    const h = dt / steps;
    for (let s = 0; s < steps; s++) {
      const px = b.x, py = b.y;
      b.vy -= G * h;
      b.x += b.vx * h; b.y += b.vy * h; b.z += b.vz * h;
      if (b.y <= BALL_R) {
        b.y = BALL_R;
        if (b.vy < -1.2) { b.vy = -b.vy * 0.52; b.vx *= 0.92; b.vz *= 0.92; }
        else b.vy = 0;
      }
      if (b.y <= BALL_R + 0.01 && b.vy === 0) {
        const k = Math.exp(-0.55 * h);
        b.vx *= k; b.vz *= k;
        const sp = Math.hypot(b.vx, b.vz);
        if (sp < 0.35) { b.vx *= 0.9; b.vz *= 0.9; }
      } else {
        const k = Math.exp(-0.06 * h);
        b.vx *= k; b.vz *= k; b.vy *= k;
      }
      this.goalFrame(px, py);
      if (this.state !== 'play') return;
    }
    this.spinBall(dt);
    this.checkPickup();
    this.checkSaves();
  }

  spinBall(dt) {
    const b = this.ball;
    const sp = Math.hypot(b.vx, b.vz);
    if (sp > 0.05) {
      const axis = new THREE.Vector3(b.vz, 0, -b.vx).normalize();
      b.mesh.rotateOnWorldAxis(axis, (sp / BALL_R) * dt);
    }
    b.mesh.position.set(b.x, b.y, b.z);
  }

  goalFrame(px, py) {
    const b = this.ball;
    for (const s of [-1, 1]) {
      const gx = s * HL;
      // القوائم
      for (const pz of [-GOAL_HW, GOAL_HW]) {
        const dx = b.x - gx, dz = b.z - pz;
        const d = Math.hypot(dx, dz);
        if (d < 0.17 && b.y < GOAL_H) {
          const nx = dx / d, nz = dz / d;
          const vn = b.vx * nx + b.vz * nz;
          if (vn < 0) { b.vx -= 1.7 * vn * nx; b.vz -= 1.7 * vn * nz; b.x = gx + nx * 0.18; b.z = pz + nz * 0.18; this.hitWood(); }
        }
      }
      // العارضة
      if (Math.abs(b.z) < GOAL_HW) {
        const dx = b.x - gx, dy = b.y - GOAL_H;
        const d = Math.hypot(dx, dy);
        if (d < 0.17) {
          const nx = dx / d, ny = dy / d;
          const vn = b.vx * nx + b.vy * ny;
          if (vn < 0) { b.vx -= 1.6 * vn * nx; b.vy -= 1.6 * vn * ny; b.x = gx + nx * 0.18; b.y = GOAL_H + ny * 0.18; this.hitWood(); }
        }
      }
      // هدف؟
      const crossed = (px - gx) * s < 0 && (b.x - gx) * s >= 0;
      if (crossed && Math.abs(b.z) < GOAL_HW && b.y < GOAL_H) {
        this.scoreGoal(s > 0 ? this.teams[0] : this.teams[1], s);
        return;
      }
    }
    // خروج الكرة
    if (Math.abs(b.z) > HW + BALL_R) {
      const team = b.lastTeam ? b.lastTeam.opp : this.teams[0];
      this.startSetPiece('throw', team, clamp(b.x, -HL + 1, HL - 1), Math.sign(b.z) * HW);
      return;
    }
    if (Math.abs(b.x) > HL + BALL_R) {
      const s = Math.sign(b.x);
      // من أي فريق يدافع عن هذا المرمى؟
      const defending = s > 0 ? this.teams[1] : this.teams[0];
      if (b.lastTeam === defending) this.startSetPiece('corner', defending.opp, s * HL, Math.sign(b.z || 1) * HW);
      else this.startSetPiece('goalkick', defending, s * (HL - 5.5), b.z > 0 ? 4 : -4);
      if (b.shot) this.audio.ooh();
    }
  }

  hitWood() {
    if (this.time - (this._woodT || 0) < 0.3) return;
    this._woodT = this.time;
    this.audio.post();
    this.audio.ooh();
    this.excite = Math.max(this.excite, 0.8);
    this.hud.toast('القائم! 😱');
  }

  checkPickup() {
    const b = this.ball;
    let best = null, bd = 1e9;
    for (const p of this.players) {
      if (p.kickCd > 0 || p.stun > 0.3) continue;
      const d = dist2(p.x, p.z, b.x, b.z);
      const boxOk = p.isGK && Math.abs(b.x - this.ownGoalX(p.team)) < 16.5 && Math.abs(b.z) < 20.16;
      const r = p.isGK && boxOk ? 1.15 : b.passTarget === p ? 0.95 : 0.75;
      const hMax = p.isGK && boxOk ? 2.5 : 0.95;
      if (d < r && b.y < hMax && d < bd) { bd = d; best = p; }
      // رأسية
      if (!p.isGK && b.y > 1.25 && b.y < 2.4 && d < 0.75 && b.vy < 3) this.header(p);
    }
    if (!best || this.state !== 'play') return;
    const sp = Math.hypot(b.vx, b.vy, b.vz);
    if (!best.isGK && b.passTarget !== best && (b.shot ? sp > 14 : sp > 23) && Math.random() < 0.5) {
      // ارتداد عن اللاعب
      b.vx *= -0.3; b.vz = b.vz * 0.3 + rand(-3, 3); b.vy = Math.abs(b.vy) * 0.3 + 1;
      b.lastTeam = best.team; b.lastPlayer = best;
      best.kickCd = 0.3;
      b.shot = null;
      return;
    }
    b.owner = best;
    b.lastTeam = best.team;
    b.lastPlayer = best;
    this.onPossession(best);
  }

  header(p) {
    const b = this.ball;
    if (p.kickCd > 0) return;
    const team = p.team;
    const gx = this.oppGoalX(team);
    const dGoal = dist2(p.x, p.z, gx, 0);
    p.model.setAnim('header', { restart: true });
    if (dGoal < 15) {
      b.y = Math.max(b.y, 1.8);
      const tz = rand(-GOAL_HW + 0.4, GOAL_HW - 0.4);
      const dx = gx - b.x, dz = tz - b.z, d = Math.hypot(dx, dz);
      const speed = rand(13, 18);
      const t = d / speed;
      const ty = rand(0.3, 2.2);
      this.kick(p, (dx / d) * speed, (ty - b.y + 0.5 * G * t * t) / t, (dz / d) * speed, 'shot');
      p.model.setAnim('header', { restart: true });
      b.shot = { team, t: this.time };
      this.stats.shots[this.teams.indexOf(team)]++;
      this.planSave(team.opp.players[0]);
      this.hud.toast('رأسية!');
    } else {
      // إبعاد
      const a = Math.atan2(team.side, -b.z * 0.02) + rand(-0.6, 0.6);
      this.kick(p, Math.sin(a) * 12, 4, Math.cos(a) * 12, 'clear');
      p.model.setAnim('header', { restart: true });
    }
  }

  checkSaves() {
    const b = this.ball;
    for (const team of this.teams) {
      const k = team.players[0];
      const pl = k.plan;
      if (!pl || !pl.save || b.owner) continue;
      // عبرت الكرة خط الحارس؟
      const rel = (b.x - k.x) * team.side; // سالب = خلف الحارس (نحو المرمى)
      if (rel < 0.25 && Math.abs(b.z - k.z) < 2.2 && b.y < GOAL_H + 0.4) {
        k.plan = null;
        if (pl.catch) {
          b.owner = k;
          b.lastTeam = team; b.lastPlayer = k;
          k.holdT = 0;
          this.hud.toast('تصدي رائع 🧤');
        } else {
          b.vx = team.side * Math.abs(b.vx) * rand(0.25, 0.45);
          b.vz = Math.sign(b.z - k.z || 1) * rand(4, 9);
          b.vy = rand(2, 5);
          b.lastTeam = team; b.lastPlayer = k;
          b.shot = null;
          k.kickCd = 0.5;
          this.hud.toast('أنقذها الحارس! 🧤');
          this.audio.ooh();
        }
        this.audio.kick(0.4);
        this.excite = Math.max(this.excite, 0.75);
      }
    }
  }

  scoreGoal(team, s) {
    team.score++;
    const b = this.ball;
    const scorer = b.lastPlayer && b.lastPlayer.team === team ? b.lastPlayer : null;
    const ownGoal = !scorer;
    this.events.push({ team: this.teams.indexOf(team), min: Math.floor(this.clock / 60) + 1, num: scorer?.number ?? 0, own: ownGoal });
    this.state = 'goal';
    this.stateT = 0;
    this.goalTeam = team;
    this.scorer = scorer || team.players.find((p) => p.role === 'FWD');
    this.timeScale = 0.35;
    this.excite = 1;
    this.audio.goal();
    this.audio.net();
    const goal = this.world?.goals[String(s)];
    if (goal) { goal.bulge = 1; goal.hitZ = b.z; goal.hitY = b.y; }
    this.hud.setScore(this.teams[0].score, this.teams[1].score);
    this.hud.banner('هــدف!', ownGoal ? `هدف عكسي · ${team.name}` : `${team.name} · رقم ${scorer.number}`, true);
    for (const p of this.players) p.plan = null;
  }

  updateGoal(dt) {
    const b = this.ball;
    const t = this.stateT;
    if (t > 0.5) this.timeScale = Math.min(1, this.timeScale + dt * 1.2);
    // الكرة داخل الشبكة
    if (!b.owner) {
      b.vy -= G * dt;
      b.x += b.vx * dt; b.y += b.vy * dt; b.z += b.vz * dt;
      const s = Math.sign(b.x);
      if (Math.abs(b.x) > HL + GOAL_D - 0.2) { b.x = s * (HL + GOAL_D - 0.2); b.vx *= -0.2; }
      if (b.y < BALL_R) { b.y = BALL_R; b.vy = Math.abs(b.vy) * 0.4; b.vx *= 0.8; b.vz *= 0.8; }
      if (b.y > GOAL_H - 0.2) { b.y = GOAL_H - 0.2; b.vy = -Math.abs(b.vy) * 0.3; }
      b.z = clamp(b.z, -GOAL_HW + 0.2, GOAL_HW - 0.2);
      b.vx *= Math.exp(-dt * 2); b.vz *= Math.exp(-dt * 2);
      this.spinBall(dt);
    }
    const sc = this.scorer;
    const team = this.goalTeam;
    const cornerX = team.side * (HL - 3), cornerZ = sc.z > 0 ? HW - 3 : -HW + 3;
    for (const p of this.players) {
      if (p.team === team) {
        if (p === sc) this.moveTo(p, cornerX, cornerZ, 7, dt);
        else if (!p.isGK) this.moveTo(p, sc.x - (sc.x - p.x) * 0.15, sc.z - (sc.z - p.z) * 0.15, 6.5, dt);
        else this.moveTo(p, p.x, p.z, 0, dt);
        if (t > 0.6) p.model.setAnim('celebrate');
      } else {
        this.moveTo(p, p.x, p.z, 0, dt);
        if (t > 0.8) p.model.setAnim('sad');
      }
    }
    this.integratePlayers(dt);
    this.updateRef(dt);
    this.animateModels(dt);
    if (t > 4.5) {
      this.timeScale = 1;
      this.hud.banner('');
      for (const p of this.players) p.model.setAnim('idle');
      this.setupKickoff(team.opp);
    }
  }

  finish() {
    this.state = 'end';
    this.stateT = 0;
    this.audio.whistle(3, true);
    this.ball.owner = null;
    const [h, a] = [this.teams[0].score, this.teams[1].score];
    const tot = this.stats.poss[0] + this.stats.poss[1] || 1;
    this.hud.end({
      home: h, away: a,
      result: h > a ? 'win' : h < a ? 'loss' : 'draw',
      events: this.events,
      possession: Math.round((this.stats.poss[0] / tot) * 100),
      shots: this.stats.shots,
      onTarget: this.stats.onTarget,
      passes: this.stats.passes,
    });
  }

  updateRef(dt) {
    const r = this.refPos;
    const b = this.ball.owner || this.ball;
    const tx = clamp(b.x - 8, -HL + 10, HL - 10), tz = clamp(b.z + 10, -HW + 4, HW - 4);
    const dx = tx - r.x, dz = tz - r.z, d = Math.hypot(dx, dz);
    const s = d < 1 ? 0 : Math.min(6, d * 0.8);
    r.vx += ((d ? (dx / d) * s : 0) - r.vx) * Math.min(1, dt * 3);
    r.vz += ((d ? (dz / d) * s : 0) - r.vz) * Math.min(1, dt * 3);
    r.x += r.vx * dt; r.z += r.vz * dt;
    const sp = Math.hypot(r.vx, r.vz);
    if (sp > 0.5) r.face = Math.atan2(r.vx, r.vz);
    else r.face += angDiff(r.face, Math.atan2(b.x - r.x, b.z - r.z)) * Math.min(1, dt * 4);
    this.ref.root.position.set(r.x, 0, r.z);
    this.ref.root.rotation.y = r.face;
    this.ref.update(dt, sp);
  }

  animateModels(dt) {
    const cp = this.user.cp;
    for (const p of this.players) {
      const m = p.model;
      m.root.position.set(p.x, 0, p.z);
      m.root.rotation.y = p.face;
      m.update(dt, p.speed, p.turnRate);
      const show = !this.auto && p === cp && this.state !== 'end' && this.state !== 'intro';
      p.ring.visible = show;
      if (show) {
        p.ring.position.set(p.x, 0.03, p.z);
        p.ring.rotation.y = p.face;
      }
    }
    if (this.state !== 'play') this.ball.mesh.position.set(this.ball.x, this.ball.y, this.ball.z);
  }

  /** نقطة تركيز الكاميرا */
  focus() {
    const b = this.ball;
    if (this.state === 'goal') return { x: this.scorer.x * 0.6 + b.x * 0.4, z: this.scorer.z * 0.6 + b.z * 0.4, close: true };
    return { x: b.x, z: b.z, close: false };
  }

  get controlledInfo() {
    const cp = this.user.cp;
    return cp ? `${cp.number} · ${ROLE_NAMES[cp.role]}` : '';
  }
}

function segDist(px, pz, ax, az, bx, bz) {
  const dx = bx - ax, dz = bz - az;
  const l2 = dx * dx + dz * dz || 1;
  const t = clamp(((px - ax) * dx + (pz - az) * dz) / l2, 0, 1);
  return Math.hypot(px - (ax + t * dx), pz - (az + t * dz));
}

function makeBallMesh() {
  // كرة بنقش خماسي كلاسيكي مرسوم على قماش
  const c = document.createElement('canvas');
  c.width = 512;
  c.height = 256;
  const g = c.getContext('2d');
  g.fillStyle = '#f7f7f7';
  g.fillRect(0, 0, 512, 256);
  g.fillStyle = '#151515';
  const pent = (cx, cy, r) => {
    g.beginPath();
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * Math.PI * 2 - Math.PI / 2;
      g.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
    }
    g.closePath();
    g.fill();
  };
  for (let row = 0; row < 3; row++) {
    for (let i = 0; i < 6; i++) {
      const cx = (i + (row % 2) * 0.5) * (512 / 6);
      const cy = 40 + row * 88;
      pent(cx, cy, row === 1 ? 26 : 20);
    }
  }
  g.strokeStyle = 'rgba(0,0,0,0.25)';
  g.lineWidth = 2;
  for (let i = 0; i < 12; i++) { g.beginPath(); g.moveTo(i * 43, 0); g.lineTo(i * 43 + 20, 256); g.stroke(); }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  const m = new THREE.Mesh(new THREE.SphereGeometry(BALL_R, 24, 16), new THREE.MeshStandardMaterial({ map: t, roughness: 0.35 }));
  return m;
}
