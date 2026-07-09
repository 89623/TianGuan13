#!/usr/bin/env node
// resync 后置步骤：抑制「纯重排」噪音。
//
// extract / labels 会按工具自己的顺序重写目录 JSON。若某文件的内容集合（对象的 key→value
// 映射，或数组的元素集合）与 HEAD 完全一致、仅顺序不同，就把它还原成 HEAD 版本——避免每次
// resync 产生上百行毫无意义的 reorder diff（典型：手维护的 strings/i18n/en/_*.json）。
// 只还原「语义无变化」的文件；有真实增/删/改的文件原样保留。
//
// 用法：node tools/i18n/suppress-reorder.mjs [路径…]（默认扫 strings/i18n/en 与 dm_labels.json）
import { execSync } from 'node:child_process';
import fs from 'node:fs';

const paths = process.argv.slice(2);
const targets = paths.length ? paths : ['strings/i18n/en', 'tools/i18n/dm_labels.json'];

// 归一化：对象 → 排序后的 [k,v] 对；数组 → 排序后的元素。其它结构返回 null（不处理）。
function canon(text) {
  let o;
  try { o = JSON.parse(text); } catch { return null; }
  if (Array.isArray(o)) return JSON.stringify([...o].sort());
  if (o && typeof o === 'object') {
    return JSON.stringify(Object.keys(o).sort().map((k) => [k, o[k]]));
  }
  return null;
}

let modified;
try {
  modified = execSync(`git diff --name-only -- ${targets.join(' ')}`, { encoding: 'utf8' })
    .split('\n')
    .filter((f) => f.endsWith('.json'));
} catch {
  process.exit(0);
}

let reverted = 0;
for (const f of modified) {
  if (!fs.existsSync(f)) continue;
  let head;
  try { head = execSync(`git show HEAD:${f}`, { encoding: 'utf8' }); } catch { continue; }
  const a = canon(head);
  const b = canon(fs.readFileSync(f, 'utf8'));
  if (a !== null && a === b) {
    execSync(`git checkout HEAD -- ${f}`);
    reverted++;
  }
}
console.log(`   抑制纯重排：还原了 ${reverted} 个语义无变化的目录文件（仅顺序不同）。`);
