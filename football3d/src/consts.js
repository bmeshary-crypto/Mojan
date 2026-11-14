// أبعاد الملعب بالمتر (المعيار الدولي 105×68)
export const L = 105;
export const W = 68;
export const HL = L / 2;
export const HW = W / 2;
export const GOAL_HW = 3.66; // نصف عرض المرمى
export const GOAL_H = 2.44;
export const GOAL_D = 2.0; // عمق الشبكة
export const BALL_R = 0.11;
export const G = 9.81;

export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export const rand = (a = 0, b = 1) => a + Math.random() * (b - a);
export const gauss = () => (Math.random() + Math.random() + Math.random() - 1.5) / 1.5;
export const dist2 = (ax, az, bx, bz) => Math.hypot(ax - bx, az - bz);
export const angDiff = (a, b) => {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return d;
};

export const IS_MOBILE = /android|iphone|ipad|mobile/i.test(navigator.userAgent) || (navigator.maxTouchPoints > 1 && /mac/i.test(navigator.userAgent));
