#!/usr/bin/env node
// i18n 漏翻日志聚合分类器。
//
// 输入：一份或多份运行期漏翻日志（miss_log.dm 产出的 data/logs/<round>/i18n_misses.log，
// 行格式 `[ts] n=N src=SRC | text`）。跨回合聚合出现次数（同一串取每份日志内最大 n 再求和），
// 按 AGENTS.md「目录已译却显英文」排查规律自动归类：
//   [已译未接通]  串在 en 目录且 zh 已译 → 显示路径绕过了翻译层，去落地点补反查/接 sink
//   [在目录未译]  串在 en 目录但 zh==en → 待译或 keep-english 白名单，跑 MT / 人工判断
//   [目录片段]    串是某条 en 目录值的子串 → AC 最短匹配拆碎/部分替换，落地点先整串反查
//   [没进目录]    en 目录里找不到 → 抽取器漏抽（config 数据/构造参数/插值句），补抽取源
//
// 用法：
//   node tools/i18n/miss-scan.mjs data/logs/<round>/i18n_misses.log [more.log ...]
//   cat *.log | node tools/i18n/miss-scan.mjs          # 也可从 stdin 读
//   node tools/i18n/miss-scan.mjs --min 3 <logs>       # 只看总次数 ≥3 的
//   node tools/i18n/miss-scan.mjs --json <logs>        # 机器可读输出
//   node tools/i18n/miss-scan.mjs --emit-pending <logs>
//       把「在目录未译」桶导出成 MT 优先清单（tools/i18n/mt/.pending/miss-priority.json，
//       {"obj.json": [key...]}），再用 I18N_ONLY_KEYS 只翻玩家实际看到的那批：
//       I18N_ONLY_KEYS=tools/i18n/mt/.pending/miss-priority.json bun tools/i18n/mt/i18n-mt.ts

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

const args = process.argv.slice(2);
let minCount = 1;
let asJson = false;
let emitPending = false;
const files = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--min') minCount = Number(args[++i]) || 1;
  else if (args[i] === '--json') asJson = true;
  else if (args[i] === '--emit-pending') emitPending = true;
  else files.push(args[i]);
}

// ---- 读日志，跨文件聚合 ----
const LINE_RE = /n=(\d+) src=(\w+) \| (.*)$/;
/** text -> { count, sources:Set } */
const misses = new Map();

function ingest(content) {
  /** 本份日志内每串的最大 n（阈值行 1/10/100/1000 取最大） */
  const perFile = new Map();
  for (const line of content.split('\n')) {
    const m = LINE_RE.exec(line);
    if (!m) continue;
    const [, n, src, text] = m;
    const prev = perFile.get(text);
    const count = Number(n);
    if (!prev || count > prev.count) perFile.set(text, { count, src });
    else prev.src = prev.src || src;
  }
  for (const [text, { count, src }] of perFile) {
    const entry = misses.get(text) ?? { count: 0, sources: new Set() };
    entry.count += count;
    entry.sources.add(src);
    misses.set(text, entry);
  }
}

if (files.length) {
  for (const f of files) ingest(fs.readFileSync(f, 'utf8'));
} else {
  ingest(fs.readFileSync(0, 'utf8'));
}
if (!misses.size) {
  console.error('没有解析到任何 miss 行（确认输入是 i18n_misses.log）');
  process.exit(1);
}

// ---- 加载目录 ----
const enDir = path.join(repoRoot, 'strings', 'i18n', 'en');
const zhDir = path.join(repoRoot, 'strings', 'i18n', 'zh-Hans');
/** en value -> { key, ns, translated } （同值多 key 时任取一，够定位） */
const enValues = new Map();
const fragmentsHaystack = [];
for (const file of fs.readdirSync(enDir).filter((f) => f.endsWith('.json'))) {
  const en = JSON.parse(fs.readFileSync(path.join(enDir, file), 'utf8'));
  const zhPath = path.join(zhDir, file);
  const zh = fs.existsSync(zhPath) ? JSON.parse(fs.readFileSync(zhPath, 'utf8')) : {};
  for (const [key, value] of Object.entries(en)) {
    if (typeof value !== 'string') continue;
    if (!enValues.has(value)) {
      enValues.set(value, { key, ns: file, translated: zh[key] !== undefined && zh[key] !== value });
    }
    if (value.length >= 12) fragmentsHaystack.push(value);
  }
}
// 片段检索用大 haystack（\x00 分隔防跨值误命中）
const haystack = fragmentsHaystack.join('\x00');

// ---- 归类 ----
const buckets = {
  已译未接通: [], // 在目录且已译 → 路径绕过，落地点补反查
  在目录未译: [], // 在目录但 zh==en → MT/白名单判断
  目录片段: [], // 是某目录值的子串 → AC 拆碎，整串反查
  没进目录: [], // 抽取器漏抽 → 补抽取源/手维护文件
};
for (const [text, { count, sources }] of misses) {
  if (count < minCount) continue;
  const row = { text, count, sources: [...sources].join(','), catalog: null };
  const hit = enValues.get(text);
  if (hit) {
    row.catalog = `${hit.ns}#${hit.key}`;
    buckets[hit.translated ? '已译未接通' : '在目录未译'].push(row);
  } else if (text.length >= 8 && haystack.includes(text)) {
    buckets['目录片段'].push(row);
  } else {
    buckets['没进目录'].push(row);
  }
}
for (const rows of Object.values(buckets)) rows.sort((a, b) => b.count - a.count);

// ---- 输出 ----
if (emitPending) {
  // 「在目录未译」桶 → MT 优先清单 {"<ns>.json": [key...]}，供 I18N_ONLY_KEYS 消费。
  const pending = {};
  for (const row of buckets['在目录未译']) {
    const [ns, key] = row.catalog.split('#');
    (pending[ns] ??= []).push(key);
  }
  const outDir = path.join(repoRoot, 'tools', 'i18n', 'mt', '.pending');
  fs.mkdirSync(outDir, { recursive: true });
  const outPath = path.join(outDir, 'miss-priority.json');
  fs.writeFileSync(outPath, JSON.stringify(pending, null, 2) + '\n');
  const total = Object.values(pending).reduce((sum, keys) => sum + keys.length, 0);
  console.log(`已导出 ${total} 条优先待译 key → ${path.relative(repoRoot, outPath)}`);
  console.log(
    '翻译：I18N_ONLY_KEYS=tools/i18n/mt/.pending/miss-priority.json bun tools/i18n/mt/i18n-mt.ts',
  );
  process.exit(0);
}
if (asJson) {
  console.log(JSON.stringify(buckets, null, 2));
  process.exit(0);
}
const HINTS = {
  已译未接通: '译文就绪但显示路径绕过翻译层 → 找到落地点补 lang_reverse_text/lang_fallback_apply/接 sink',
  在目录未译: '在 en 目录但 zh 未译 → bun tools/i18n/mt/i18n-mt.ts 跑 MT，或确认属 keep-english 白名单',
  目录片段: '是某条目录值的子串（AC 最短匹配拆碎/部分替换）→ 该文本落地点先整串反查再进 fallback',
  没进目录: '抽取器没抽到（config 数据/new 构造参数/#define/运行期插值）→ 扩抽取源或手维护 _<feature>.json',
};
for (const [name, rows] of Object.entries(buckets)) {
  if (!rows.length) continue;
  console.log(`\n=== ${name}（${rows.length} 条）===`);
  console.log(`    ${HINTS[name]}`);
  for (const row of rows) {
    const loc = row.catalog ? `  [${row.catalog}]` : '';
    console.log(`  ${String(row.count).padStart(5)}×  (${row.sources})${loc}  ${row.text}`);
  }
}
const total = Object.values(buckets).reduce((sum, rows) => sum + rows.length, 0);
console.log(`\n共 ${total} 条唯一漏翻（阈值 ≥${minCount} 次）`);
