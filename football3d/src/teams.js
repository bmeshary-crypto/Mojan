// أندية خيالية بالكامل (نفس شعارات «دوري النجوم») — لا أسماء ولا شعارات حقيقية.
export const CLUBS = {
  eagle: { name: 'النسور', short: 'NSR', c1: '#2F7BFF', c2: '#0B2A6B', shorts: '#ffffff', pattern: 0, gk: '#f2c200' },
  lion: { name: 'الأسود', short: 'ASD', c1: '#FFC21A', c2: '#B3261E', shorts: '#B3261E', pattern: 2, gk: '#2a9d4a' },
  wolf: { name: 'الذئاب', short: 'ZEB', c1: '#8C9AB0', c2: '#1E2A44', shorts: '#1E2A44', pattern: 1, gk: '#ff7a00' },
  tiger: { name: 'النمور', short: 'NMR', c1: '#FF8A1F', c2: '#2A1A0A', shorts: '#2A1A0A', pattern: 1, gk: '#3a7bd5' },
  horse: { name: 'الخيول', short: 'KHL', c1: '#C98A4B', c2: '#4A2A12', shorts: '#ffffff', pattern: 0, gk: '#7d3cff' },
  shark: { name: 'القروش', short: 'QRS', c1: '#1FC6C9', c2: '#0A4048', shorts: '#0A4048', pattern: 2, gk: '#ff3b6b' },
  bull: { name: 'الثيران', short: 'THR', c1: '#E02424', c2: '#FFC93C', shorts: '#ffffff', pattern: 0, gk: '#1d1d1d' },
  cobra: { name: 'الأفاعي', short: 'AFA', c1: '#3DDC6A', c2: '#0E2E18', shorts: '#0E2E18', pattern: 3, gk: '#ffd400' },
  bear: { name: 'الدببة', short: 'DBB', c1: '#B0413E', c2: '#3A0E12', shorts: '#3A0E12', pattern: 1, gk: '#00b3a4' },
  fox: { name: 'الثعالب', short: 'THL', c1: '#FF6A2B', c2: '#F2F2F2', shorts: '#F2F2F2', pattern: 3, gk: '#222f66' },
  falcon: { name: 'الصقور', short: 'SQR', c1: '#F4F4F4', c2: '#0D7A3F', shorts: '#0D7A3F', pattern: 2, gk: '#e8b400' },
  camel: { name: 'الجمال', short: 'JML', c1: '#E8D3A6', c2: '#7A4B1F', shorts: '#7A4B1F', pattern: 0, gk: '#1f6feb' },
};

function rgb(h) {
  const n = parseInt(h.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}
function lum(h) {
  const [r, g, b] = rgb(h);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}
function cdist(a, b) {
  const [r1, g1, b1] = rgb(a), [r2, g2, b2] = rgb(b);
  return Math.hypot(r1 - r2, g1 - g2, b1 - b2);
}

export function makeTeam(id, crestBase, vs) {
  const c = { ...(CLUBS[id] || CLUBS.eagle), id };
  // طقم بديل إذا تشابهت الألوان
  if (vs && cdist(c.c1, vs.c1) < 120) {
    const light = lum(vs.c1) < 0.55;
    c.c2 = c.c1;
    c.c1 = light ? '#F4F4F4' : '#16181d';
    c.shorts = light ? '#F4F4F4' : '#16181d';
    c.pattern = 2;
  }
  c.num = lum(c.c1) > 0.6 ? '#111111' : '#ffffff';
  c.crest = `${crestBase}fc_${id}.webp`;
  return c;
}
