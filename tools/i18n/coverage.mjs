#!/usr/bin/env node
// 翻译覆盖率报告：extract 之后，哪些 en/ 已抽取的 key 还没翻到 zh-Hans/。
//
// 主信号 —— 缺失（missing）：zh-Hans 里根本没有该 key。这就是 extract 之后「该翻什么」的清单。
// 次信号 —— 未译（zh == en）：有 key 但译文原样等于英文；扣掉 keep-english 白名单后的余量（有
//           噪音：专有名词/代号/单字母/数字常故意保留英文，仅供参考）。
//
// 退出码恒为 0（纯报告，不阻断 resync）。
import fs from 'node:fs';
import path from 'node:path';

const EN = 'strings/i18n/en';
const ZH = 'strings/i18n/zh-Hans';
const KEEP = 'tools/i18n/mt/keep-english.zh-Hans.json';

let keep = new Set();
try {
  const k = JSON.parse(fs.readFileSync(KEEP, 'utf8'));
  keep = new Set(Array.isArray(k) ? k : Object.keys(k));
} catch { /* 白名单可选 */ }

let files = [];
try { files = fs.readdirSync(EN).filter((f) => f.endsWith('.json')); } catch { process.exit(0); }

let totKeys = 0, totMissing = 0, totUntranslated = 0;
const rows = [];
for (const f of files) {
  let en;
  try { en = JSON.parse(fs.readFileSync(path.join(EN, f), 'utf8')); } catch { continue; }
  if (!en || typeof en !== 'object' || Array.isArray(en)) continue;
  let zh = {};
  try { zh = JSON.parse(fs.readFileSync(path.join(ZH, f), 'utf8')); } catch { /* 整档缺失 */ }
  let n = 0, missing = 0, untrans = 0;
  for (const [k, ev] of Object.entries(en)) {
    if (typeof ev !== 'string') continue;
    n++;
    if (!(k in zh)) missing++;
    else if (zh[k] === ev && !keep.has(ev) && !keep.has(k)) untrans++;
  }
  totKeys += n; totMissing += missing; totUntranslated += untrans;
  if (missing + untrans > 0) rows.push({ f, n, missing, untrans });
}

rows.sort((a, b) => (b.missing + b.untrans) - (a.missing + a.untrans));
console.log(`   翻译覆盖率（en 共 ${totKeys} 条）：缺失 ${totMissing} 条，未译(zh==en) ${totUntranslated} 条。`);
console.log('   缺失=extract 后待翻清单；请跑 `bun tools/i18n/mt/i18n-mt.ts`（默认只补缺失）或人工补译。');
for (const r of rows.slice(0, 15)) {
  console.log(`     ${r.f.padEnd(20)} 共${r.n}  缺${r.missing}  未译${r.untrans}`);
}
if (rows.length > 15) console.log(`     …还有 ${rows.length - 15} 个命名空间有缺口。`);
