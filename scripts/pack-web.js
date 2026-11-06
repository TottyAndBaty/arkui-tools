/*
 * Packs the browser build into a self-contained static bundle.
 * web/index.html loads the shared modules through "../shared/", so a plain static host
 * needs them inside the bundle; this copies web/ and shared/ side by side into dist/.
 * Run from the project root: node scripts/pack-web.js [输出目录] [AI 服务地址]
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const OUT = path.resolve(ROOT, process.argv[2] || 'dist');
const ENDPOINT = process.argv[3] || '';
const TMP = `${OUT}.tmp-${process.pid}`;

function copy(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name);
    const to = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copy(from, to);
    } else {
      fs.copyFileSync(from, to);
    }
  }
}

try {
  fs.rmSync(TMP, { recursive: true, force: true });
  copy(path.join(ROOT, 'web'), TMP);
  copy(path.join(ROOT, 'shared'), path.join(TMP, 'shared'));

  if (ENDPOINT) {
    fs.writeFileSync(path.join(TMP, 'config.js'),
      `window.ARKUI_ENDPOINT = ${JSON.stringify(ENDPOINT)};\n`, 'utf8');
  }

  // The old bundle is only discarded once the new one is complete, so a locked or
  // unwritable target leaves the previous dist/ untouched.
  fs.rmSync(OUT, { recursive: true, force: true });
  fs.renameSync(TMP, OUT);
} catch (error) {
  fs.rmSync(TMP, { recursive: true, force: true });
  console.error(`打包失败：${error.message}`);
  console.error('若输出目录正被静态服务器占用（Windows 会锁住目录），先停掉它或换个输出目录。');
  process.exit(1);
}

console.log(`静态包已生成：${OUT}`);
if (ENDPOINT) {
  console.log(`config.js 已写入 AI 服务地址：${ENDPOINT}`);
}
console.log('把该目录内容交给任意静态服务器（作为站点根），或交给 nginx 的 root。');
