#!/usr/bin/env bun
// NovaSector 全量汉化：增量、混译检测的翻译驱动。
//
// 思路：逐 key 判定状态（已译 / 缺失 / 未译 / 中英混杂），只把「待译」的那批喂给 Codex，
// 翻完合并回 zh-Hans。避免整文件重译，且能把 obj.json 这种里中英混杂的条目挑出来重做。
//
// 命令：
//   bun tools/i18n/mt/i18n-mt.ts pending [ns...]      # 只报告各文件待译数量与样例（不调用 Codex）
//   bun tools/i18n/mt/i18n-mt.ts translate [ns...]    # 计算待译 -> Codex 翻译 -> 合并回 zh-Hans
//
// 环境：I18N_LOCALE（默认 zh-Hans）。translate 需要 codex CLI（禁用 MCP 运行）。

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dir, '../../..');
const LOCALE = process.env.I18N_LOCALE ?? 'zh-Hans';
const EN_DIR = path.join(ROOT, 'strings/i18n/en');
const DST_DIR = path.join(ROOT, `strings/i18n/${LOCALE}`);
const GLOSSARY_PATH = path.join(import.meta.dir, `glossary.${LOCALE}.json`);
const PENDING_DIR = path.join(import.meta.dir, '.pending');

type Catalog = Record<string, string>;

let glossary: Record<string, string> = fs.existsSync(GLOSSARY_PATH)
  ? JSON.parse(fs.readFileSync(GLOSSARY_PATH, 'utf8'))
  : {};
// 术语表里「保持英文」的词（value === key，如 datum/Nanotrasen 缩写），允许留在译文里。
let keepEnglish = Object.entries(glossary)
  .filter(([k, v]) => k === v)
  .map(([k]) => k);

function saveGlossary() {
  const sorted: Record<string, string> = {};
  for (const k of Object.keys(glossary).sort()) sorted[k] = glossary[k];
  fs.writeFileSync(GLOSSARY_PATH, JSON.stringify(sorted, null, 2) + '\n');
}

/** 把 Codex 这批新发现的固定词合并进术语表（仅新增，不覆盖已有人工译名），并落盘。 */
function mergeGlossaryAdditions(additions: Record<string, string>): number {
  let added = 0;
  for (const [en, zh] of Object.entries(additions)) {
    if (!en || !zh || en in glossary) continue;
    glossary[en] = zh;
    added++;
  }
  if (added) {
    keepEnglish = Object.entries(glossary).filter(([k, v]) => k === v).map(([k]) => k);
    saveGlossary();
  }
  return added;
}

const CJK = /[㐀-鿿]/;

/** 去掉占位符 / HTML 标签 / DM 文本宏 / 保持英文的术语，剩下的才用于判定「是否还有英文」。 */
function stripNoise(s: string): string {
  let t = s.replace(/\{\d+\}/g, ' ').replace(/<[^>]*>/g, ' ').replace(/\\[A-Za-z]+/g, ' ');
  for (const term of keepEnglish) t = t.split(term).join(' ');
  return t;
}

/** 是否含「应被翻译的英文词」：小写字母 3+（大写缩写如 APC/RCD 通常保留，不算）。 */
function hasEnglishWord(s: string): boolean {
  return /[a-z]{3,}/.test(stripNoise(s));
}

/** 该 key 是否需要（重新）翻译。 */
function needsTranslation(enVal: string, zhVal: string | undefined): boolean {
  if (zhVal == null || zhVal === '') return hasEnglishWord(enVal); // 缺失
  if (zhVal === enVal) return hasEnglishWord(enVal); // 与英文相同 = 未译（纯代码/符号除外）
  const stray = hasEnglishWord(zhVal);
  if (!CJK.test(zhVal) && stray) return true; // 无中文却有英文词 → 未译
  if (CJK.test(zhVal) && stray) return true; // 中英混杂 → 重译
  return false; // 看起来已完整翻译（或纯符号/缩写）
}

function readCatalog(file: string): Catalog {
  return fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : {};
}

function namespaceFiles(args: string[]): string[] {
  if (args.length) return args.map((a) => (a.endsWith('.json') ? a : `${a}.json`));
  return fs.readdirSync(EN_DIR).filter((f) => f.endsWith('.json'));
}

/** 计算某命名空间的待译集合（key -> 英文源）。 */
function computePending(file: string): Catalog {
  const en = readCatalog(path.join(EN_DIR, file));
  const zh = readCatalog(path.join(DST_DIR, file));
  const pending: Catalog = {};
  for (const key of Object.keys(en)) {
    if (needsTranslation(en[key], zh[key])) pending[key] = en[key];
  }
  return pending;
}

function cmdPending(args: string[]) {
  let total = 0;
  for (const file of namespaceFiles(args)) {
    const pending = computePending(file);
    const n = Object.keys(pending).length;
    total += n;
    const sample = Object.entries(pending).slice(0, 2).map(([k, v]) => `${k}=${JSON.stringify(v).slice(0, 40)}`);
    console.log(`${file}: 待译 ${n}` + (n ? `  e.g. ${sample.join(' | ')}` : ''));
  }
  console.log(`合计待译 ${total} 条（locale=${LOCALE}）`);
}

function glossaryHint(): string {
  return Object.entries(glossary)
    .map(([en, zh]) => `- ${en} => ${zh}`)
    .join('\n');
}

// 每批喂给 Codex 的条数（大文件如 obj.json 必须分批，否则超上下文）。
const CHUNK = Number(process.env.I18N_CHUNK ?? 200);

function translateBatch(file: string, idx: number, batch: Catalog): Catalog | null {
  const inPath = path.join(PENDING_DIR, file.replace(/\.json$/, `.${idx}.json`));
  const outPath = path.join(PENDING_DIR, file.replace(/\.json$/, `.${idx}.${LOCALE}.json`));
  const addPath = path.join(PENDING_DIR, file.replace(/\.json$/, `.${idx}.glossary.json`));
  fs.rmSync(outPath, { force: true });
  fs.rmSync(addPath, { force: true });
  fs.writeFileSync(inPath, JSON.stringify(batch, null, 2));

  const prompt =
    `你是 Space Station 13 游戏文本的专业本地化译者，目标语言：${LOCALE}。` +
    `读取 ${path.relative(ROOT, inPath)}（扁平 JSON：key->英文），把每个值翻译为目标语言，写入 ` +
    `${path.relative(ROOT, outPath)}：` +
    `(1) key 完全不变；(2) 逐字保留 {0}/{1}… 占位符、HTML 标签、DM 文本宏（如 \\improper、\\the）；` +
    `(3) 严格遵循术语表（保持英文的词不要翻译，其余英文务必译为中文，不要中英混杂）；` +
    `(4) 大写缩写（APC/RCD/AI 等）保留英文；(5) 只输出/写入合法 JSON，键序与输入一致。` +
    `(6) 凡是术语表里没有的「固定词汇」（品牌名、阵营/组织名、专有装置名），先查术语表用既有译名；` +
    `若术语表没有，就为它定一个译名并把「英文->译名」追加写入 ${path.relative(ROOT, addPath)}` +
    `（扁平 JSON，保持英文则 value 同 key；本批没有就写 {}），以便后续保持一致。术语表：\n${glossaryHint()}`;

  execFileSync('codex', ['exec', '-c', 'mcp_servers={}', '-s', 'workspace-write', prompt], {
    cwd: ROOT,
    stdio: 'inherit',
  });

  // 合并 Codex 这批新发现的固定词到术语表（仅新增，后续批次/文件即可复用，保持译名一致）。
  if (fs.existsSync(addPath)) {
    const added = mergeGlossaryAdditions(readCatalog(addPath));
    if (added) console.log(`  术语表 +${added}（已并入 ${path.relative(ROOT, GLOSSARY_PATH)}）`);
  }

  if (!fs.existsSync(outPath)) {
    console.error(`  ⚠ Codex 未产出 ${path.relative(ROOT, outPath)}`);
    return null;
  }
  return readCatalog(outPath);
}

function cmdTranslate(args: string[]) {
  fs.mkdirSync(PENDING_DIR, { recursive: true });
  fs.mkdirSync(DST_DIR, { recursive: true });
  for (const file of namespaceFiles(args)) {
    const pending = computePending(file);
    const keys = Object.keys(pending);
    if (keys.length === 0) {
      console.log(`${file}: 无待译，跳过`);
      continue;
    }
    const batches = Math.ceil(keys.length / CHUNK);
    console.log(`${file}: 待译 ${keys.length}，分 ${batches} 批（每批 ${CHUNK}）`);
    const dstFile = path.join(DST_DIR, file);
    for (let start = 0, idx = 0; start < keys.length; start += CHUNK, idx++) {
      const batch: Catalog = {};
      for (const key of keys.slice(start, start + CHUNK)) batch[key] = pending[key];
      const translated = translateBatch(file, idx, batch);
      if (!translated) continue;
      // 每批翻完即合并落盘（断点续译：重跑会重新计算待译，已译的不再出现）。
      const merged = readCatalog(dstFile);
      let applied = 0;
      for (const key of Object.keys(translated)) {
        if (key in batch) {
          merged[key] = translated[key];
          applied++;
        }
      }
      const sorted: Catalog = {};
      for (const key of Object.keys(merged).sort()) sorted[key] = merged[key];
      fs.writeFileSync(dstFile, JSON.stringify(sorted, null, 2) + '\n');
      console.log(`  批 ${idx + 1}/${batches}: 合并 ${applied}`);
    }
  }
  console.log('完成。请抽检后提交 strings/i18n/' + LOCALE + '。');
}

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === 'pending') cmdPending(rest);
else if (cmd === 'translate' || cmd === undefined) cmdTranslate(rest);
else {
  console.error('用法: i18n-mt.ts pending|translate [namespace...]');
  process.exit(1);
}
