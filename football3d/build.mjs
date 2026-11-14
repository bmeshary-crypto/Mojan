// يجمع اللعبة (three.js + الكود) في ملف HTML واحد داخل أصول Flutter.
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const res = await build({
  entryPoints: ['src/main.js'],
  bundle: true,
  minify: !process.argv.includes('--dev'),
  format: 'iife',
  target: ['es2020', 'safari14'],
  write: false,
  legalComments: 'none',
});
const js = res.outputFiles[0].text.replace(/<\/script/gi, '<\\/script');
const html = readFileSync('src/index.html', 'utf8').replace('/*SCRIPT*/', () => js);
mkdirSync('../assets/football', { recursive: true });
writeFileSync('../assets/football/index.html', html);
console.log('built ../assets/football/index.html', (html.length / 1024).toFixed(0) + ' KB');
