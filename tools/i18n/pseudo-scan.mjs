#!/usr/bin/env node
// NovaSector i18n —— 伪 locale 爬取分析器。
//
// 配合 `nova-i18n pseudo`（生成 qps-ploc，每个译文值包成 ⟦原文⟧）：在 I18N_SERVER_LOCALE=qps-ploc
// 下跑一圈游戏 / 单元测试，把聊天日志、UI dump、状态栏导出等玩家可见输出喂给本脚本。
//
// 原理：伪 locale 下凡是**接通了翻译通道**的串都会被包成 ⟦…⟧。所以先剥掉 ⟦…⟧ 内的内容，
// 残留的成串英文（≥4 字母）就是「没接进任何翻译通道」的输出——「selected 中文/选项英文」、
// 漏接的 raw browse、新 sink 等长尾，从「玩家截图上报」变成「grep 出来」。
//
// 用法：
//   node tools/i18n/pseudo-scan.mjs <file> [file2 ...]      # 扫描文件
//   <某命令> | node tools/i18n/pseudo-scan.mjs               # 扫描 stdin
//   node tools/i18n/pseudo-scan.mjs --min 5 data/chat.log    # 调英文串最小长度（默认 4）
//
// 注意：会有合理噪音（玩家 ckey、缩写 DNA/APC、代号 XCC-P5831、未本地化的标识符等）——
// 这些本就该留英文。报告按出现次数排序，便于先看高频未接通项。

import fs from 'node:fs';

const OPEN = '⟦'; // ⟦
const CLOSE = '⟧'; // ⟧

const args = process.argv.slice(2);
let minLen = 4;
const files = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--min') {
    minLen = parseInt(args[++i], 10) || 4;
  } else {
    files.push(args[i]);
  }
}

/** 剥掉 ⟦…⟧ 包裹区（含跨行；伪 locale 已翻译的内容都在里面）。未闭合的 ⟦ 一直剥到结尾。 */
function stripWrapped(text) {
  let out = '';
  let depth = 0;
  for (const ch of text) {
    if (ch === OPEN) {
      depth++;
      continue;
    }
    if (ch === CLOSE) {
      if (depth > 0) depth--;
      continue;
    }
    if (depth === 0) out += ch;
  }
  return out;
}

function readInput() {
  if (files.length) {
    return files.map((f) => fs.readFileSync(f, 'utf8')).join('\n');
  }
  return fs.readFileSync(0, 'utf8'); // stdin
}

const raw = readInput();
const bare = stripWrapped(raw);

// 残留英文串：连续 ≥minLen 个 ASCII 字母（容许内部 ' - 连接，如 don't / re-open）。
const wordRe = new RegExp(`[A-Za-z][A-Za-z'\\-]{${minLen - 1},}`, 'g');
const counts = new Map();
for (const m of bare.matchAll(wordRe)) {
  const w = m[0];
  counts.set(w, (counts.get(w) || 0) + 1);
}

const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
const totalHits = sorted.reduce((s, [, n]) => s + n, 0);

console.log(
  `伪 locale 爬取分析：在 ⟦⟧ 包裹**之外**发现 ${sorted.length} 个不同英文串（共 ${totalHits} 次）。`,
);
console.log('这些是「未接进任何翻译通道」的候选（含合理噪音：ckey/缩写/代号/标识符）。按频次降序：\n');
for (const [w, n] of sorted) {
  console.log(`${String(n).padStart(6)}  ${w}`);
}
if (!sorted.length) {
  console.log('（无残留英文——所有可见输出都已接通翻译通道。）');
}
