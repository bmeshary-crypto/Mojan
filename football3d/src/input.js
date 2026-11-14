// عصا تحكم افتراضية + أزرار لمس + لوحة مفاتيح.
function button() {
  return { down: false, pressed: false, released: false, held: 0, heldFor: 0, _t0: 0 };
}

export class Input {
  constructor(root, toLocal) {
    this.move = { x: 0, y: 0 };
    this.sprint = false;
    this.a = button();
    this.b = button();
    this.anyPressed = false;
    this.camPressed = false;
    this.toLocal = toLocal;
    this.keys = new Set();
    this.joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 };
    this.base = root.querySelector('#joy');
    this.knob = root.querySelector('#knob');
    this.zone = root.querySelector('#joyzone');

    const press = (btn) => { if (!btn.down) { btn.down = true; btn.pressed = true; btn._t0 = performance.now(); } this.anyPressed = true; };
    const release = (btn) => { if (btn.down) { btn.down = false; btn.released = true; btn.heldFor = (performance.now() - btn._t0) / 1000; } };
    this._press = press;
    this._release = release;

    const bind = (el, onDown, onUp) => {
      el.addEventListener('pointerdown', (e) => { e.preventDefault(); el.setPointerCapture(e.pointerId); el.classList.add('on'); onDown(); });
      const up = (e) => { e.preventDefault(); el.classList.remove('on'); onUp(); };
      el.addEventListener('pointerup', up);
      el.addEventListener('pointercancel', up);
      el.addEventListener('lostpointercapture', () => { el.classList.remove('on'); onUp(); });
    };
    bind(root.querySelector('#btnA'), () => press(this.a), () => release(this.a));
    bind(root.querySelector('#btnB'), () => press(this.b), () => release(this.b));
    bind(root.querySelector('#btnS'), () => { this.sprintTouch = true; this.anyPressed = true; }, () => { this.sprintTouch = false; });

    // العصا العائمة
    const z = this.zone;
    z.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      if (this.joy.id !== null) return;
      z.setPointerCapture(e.pointerId);
      const p = this.toLocal(e.clientX, e.clientY);
      this.joy = { id: e.pointerId, ox: p.x, oy: p.y, x: 0, y: 0 };
      this.base.style.left = p.x + 'px';
      this.base.style.top = p.y + 'px';
      this.base.classList.add('on');
      this.anyPressed = true;
    });
    z.addEventListener('pointermove', (e) => {
      if (e.pointerId !== this.joy.id) return;
      const p = this.toLocal(e.clientX, e.clientY);
      let dx = p.x - this.joy.ox, dy = p.y - this.joy.oy;
      const R = 58;
      const d = Math.hypot(dx, dy);
      if (d > R) { dx = (dx / d) * R; dy = (dy / d) * R; }
      this.joy.x = dx / R;
      this.joy.y = -dy / R;
      this.knob.style.transform = `translate(${dx}px, ${dy}px)`;
    });
    const end = (e) => {
      if (e.pointerId !== this.joy.id) return;
      this.joy = { id: null, ox: 0, oy: 0, x: 0, y: 0 };
      this.knob.style.transform = 'translate(0,0)';
      this.base.classList.remove('on');
    };
    z.addEventListener('pointerup', end);
    z.addEventListener('pointercancel', end);

    // لوحة المفاتيح
    window.addEventListener('keydown', (e) => {
      if (e.repeat) return;
      const k = e.key.toLowerCase();
      this.keys.add(k);
      this.anyPressed = true;
      if (k === ' ') press(this.b);
      if (k === 'x' || k === 'k') press(this.a);
      if (k === 'z' || k === 'j') press(this.b);
      if (k === 'v') this.camPressed = true;
      if ([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) e.preventDefault();
    });
    window.addEventListener('keyup', (e) => {
      const k = e.key.toLowerCase();
      this.keys.delete(k);
      if (k === ' ') release(this.b);
      if (k === 'x' || k === 'k') release(this.a);
      if (k === 'z' || k === 'j') release(this.b);
    });
    window.addEventListener('blur', () => { this.keys.clear(); release(this.a); release(this.b); });
  }

  poll() {
    let kx = 0, ky = 0;
    const K = this.keys;
    if (K.has('arrowleft') || K.has('a')) kx -= 1;
    if (K.has('arrowright') || K.has('d')) kx += 1;
    if (K.has('arrowup') || K.has('w')) ky += 1;
    if (K.has('arrowdown') || K.has('s')) ky -= 1;
    if (kx || ky) {
      const d = Math.hypot(kx, ky);
      this.move.x = kx / d; this.move.y = ky / d;
    } else {
      this.move.x = this.joy.x; this.move.y = this.joy.y;
    }
    this.sprint = !!this.sprintTouch || K.has('shift');
    const now = performance.now();
    for (const b of [this.a, this.b]) b.held = b.down ? (now - b._t0) / 1000 : 0;
  }

  endFrame() {
    for (const b of [this.a, this.b]) { b.pressed = false; b.released = false; }
    this.anyPressed = false;
    this.camPressed = false;
  }
}
