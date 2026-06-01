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
// Codex 输出默认写入 tools/i18n/mt/.pending/*.codex.log，终端只显示批次进度。

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dir, '../../..');
const LOCALE = process.env.I18N_LOCALE ?? 'zh-Hans';
const EN_DIR = path.join(ROOT, 'strings/i18n/en');
const DST_DIR = path.join(ROOT, `strings/i18n/${LOCALE}`);
const GLOSSARY_PATH = path.join(import.meta.dir, `glossary.${LOCALE}.json`);
const PENDING_DIR = path.join(import.meta.dir, '.pending');
const CODEX_REASONING = process.env.I18N_CODEX_REASONING ?? 'low';
const CODEX_MODEL = process.env.I18N_CODEX_MODEL;
const CODEX_STDIO = process.env.I18N_CODEX_STDIO ?? 'log';
const PROGRESS_WIDTH = Number(process.env.I18N_PROGRESS_WIDTH ?? 28);

type Catalog = Record<string, string>;
type TranslatedBatch = {
  catalog: Catalog;
  glossaryAdded: number;
};

const glossary: Record<string, string> = fs.existsSync(GLOSSARY_PATH)
  ? JSON.parse(fs.readFileSync(GLOSSARY_PATH, 'utf8'))
  : {};
// 术语表里「保持英文」的词（value === key，如 datum/Nanotrasen 缩写），允许留在译文里。
function keepEnglishTerms(): string[] {
  return Object.entries(glossary)
    .filter(([k, v]) => k === v)
    .map(([k]) => k)
    .sort((a, b) => b.length - a.length);
}

let keepEnglish = keepEnglishTerms();

function saveGlossary() {
  const sorted: Record<string, string> = {};
  for (const k of Object.keys(glossary).sort()) sorted[k] = glossary[k];
  fs.writeFileSync(GLOSSARY_PATH, `${JSON.stringify(sorted, null, 2)}\n`);
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
    keepEnglish = keepEnglishTerms();
    saveGlossary();
  }
  return added;
}

const CJK = /[㐀-鿿]/;

/** 去掉占位符 / HTML 标签 / DM 文本宏 / 保持英文的术语，剩下的才用于判定「是否还有英文」。 */
function stripNoise(s: string): string {
  let t = s
    .replace(/\{\d+\}/g, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&[a-zA-Z0-9#]+;/g, ' ')
    .replace(/\\[A-Za-z]+/g, ' ')
    .replace(/\b(?:boxed_message|purple_box|blue_box|red_box|green_box)/g, ' ')
    .replace(/\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+(?=[A-Z])/g, ' ')
    .replace(/\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b/g, ' ')
    .replace(/\b[a-z][a-z0-9]*(?:-[a-z0-9]+)+\b/g, ' ')
    .replace(/\/[A-Za-z0-9_./-]+/g, ' ')
    .replace(
      /\b[A-Za-z0-9_./-]+\.(?:png|jpg|jpeg|gif|webp|svg|dmi|ogg|wav|mp3|json|css|js|ts|tsx|html)\b/g,
      ' ',
    )
    .replace(
      /\.(?:png|jpg|jpeg|gif|webp|svg|dmi|ogg|wav|mp3|json|css|js|ts|tsx|html)\b/g,
      ' ',
    )
    .replace(/\b[a-z]+=[A-Za-z0-9_-]+\b/g, ' ');
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
  if (args.length)
    return args.map((a) => (a.endsWith('.json') ? a : `${a}.json`));
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
    const sample = Object.entries(pending)
      .slice(0, 2)
      .map(([k, v]) => `${k}=${JSON.stringify(v).slice(0, 40)}`);
    console.log(`${file}: 待译 ${n}${n ? `  e.g. ${sample.join(' | ')}` : ''}`);
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

function progressLine(
  file: string,
  done: number,
  total: number,
  detail: string,
  frame = '',
): string {
  const ratio = total > 0 ? done / total : 1;
  const filled = Math.round(ratio * PROGRESS_WIDTH);
  const bar = `${'#'.repeat(filled)}${'-'.repeat(Math.max(PROGRESS_WIDTH - filled, 0))}`;
  const percent = Math.round(ratio * 100)
    .toString()
    .padStart(3, ' ');
  const spinner = frame ? ` ${frame}` : '';
  return `${file} [${bar}] ${done}/${total} ${percent}%${spinner} ${detail}`;
}

let lastProgressLength = 0;

function writeProgress(line: string, final = false) {
  if (!process.stdout.isTTY) {
    console.log(line);
    return;
  }

  const padded = line.padEnd(lastProgressLength);
  process.stdout.write(`\r${padded}`);
  lastProgressLength = line.length;
  if (final) {
    process.stdout.write('\n');
    lastProgressLength = 0;
  }
}

function startProgress(
  file: string,
  done: number,
  total: number,
  detail: string,
): ReturnType<typeof setInterval> | null {
  if (!process.stdout.isTTY) {
    writeProgress(progressLine(file, done, total, detail));
    return null;
  }

  const frames = ['-', '\\', '|', '/'];
  let frame = 0;
  writeProgress(progressLine(file, done, total, detail, frames[frame]));
  return setInterval(() => {
    frame = (frame + 1) % frames.length;
    writeProgress(progressLine(file, done, total, detail, frames[frame]));
  }, 250);
}

function finishProgress(
  timer: ReturnType<typeof setInterval> | null,
  file: string,
  done: number,
  total: number,
  detail: string,
) {
  if (timer) {
    clearInterval(timer);
  }
  writeProgress(progressLine(file, done, total, detail), true);
}

function tailFile(file: string, lines = 30): string {
  if (!fs.existsSync(file)) {
    return '';
  }
  return fs.readFileSync(file, 'utf8').split(/\r?\n/).slice(-lines).join('\n');
}

async function runCodex(prompt: string, logPath: string): Promise<boolean> {
  const args = [
    'exec',
    '-c',
    'mcp_servers={}',
    '-c',
    `model_reasoning_effort="${CODEX_REASONING}"`,
    '-s',
    'workspace-write',
    '--color',
    'never',
  ];

  if (CODEX_MODEL) {
    args.push('-m', CODEX_MODEL);
  }

  args.push(prompt);

  if (CODEX_STDIO === 'inherit') {
    return await new Promise((resolve) => {
      const child = spawn('codex', args, {
        cwd: ROOT,
        env: { ...process.env, NO_COLOR: '1' },
        stdio: 'inherit',
      });
      child.on('close', (code) => resolve(code === 0));
      child.on('error', () => resolve(false));
    });
  }

  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  const log = fs.createWriteStream(logPath, { flags: 'a' });
  log.write(
    [
      `\n=== ${new Date().toISOString()} ===`,
      `cwd: ${ROOT}`,
      `codex ${args.slice(0, -1).join(' ')} <prompt>`,
      '',
    ].join('\n'),
  );

  return await new Promise((resolve) => {
    const child = spawn('codex', args, {
      cwd: ROOT,
      env: { ...process.env, NO_COLOR: '1' },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    child.stdout.pipe(log, { end: false });
    child.stderr.pipe(log, { end: false });
    child.on('close', (code) => {
      log.write(`\n=== exit ${code} ===\n`);
      log.end();
      resolve(code === 0);
    });
    child.on('error', (err) => {
      log.write(`\n=== spawn error: ${err.message} ===\n`);
      log.end();
      resolve(false);
    });
  });
}

async function translateBatch(
  file: string,
  idx: number,
  batch: Catalog,
): Promise<TranslatedBatch | null> {
  const inPath = path.join(
    PENDING_DIR,
    file.replace(/\.json$/, `.${idx}.json`),
  );
  const outPath = path.join(
    PENDING_DIR,
    file.replace(/\.json$/, `.${idx}.${LOCALE}.json`),
  );
  const addPath = path.join(
    PENDING_DIR,
    file.replace(/\.json$/, `.${idx}.glossary.json`),
  );
  const logPath = path.join(
    PENDING_DIR,
    file.replace(/\.json$/, `.${idx}.codex.log`),
  );
  fs.rmSync(outPath, { force: true });
  fs.rmSync(addPath, { force: true });
  fs.rmSync(logPath, { force: true });
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

  const ok = await runCodex(prompt, logPath);
  if (!ok) {
    const logHint =
      CODEX_STDIO === 'inherit'
        ? 'Codex 输出已直接打印到终端'
        : `日志：${path.relative(ROOT, logPath)}`;
    console.error(`\n  ⚠ Codex 执行失败，${logHint}`);
    const tail = tailFile(logPath);
    if (tail) {
      console.error(tail);
    }
    return null;
  }

  let glossaryAdded = 0;
  // 合并 Codex 这批新发现的固定词到术语表（仅新增，后续批次/文件即可复用，保持译名一致）。
  if (fs.existsSync(addPath)) {
    glossaryAdded = mergeGlossaryAdditions(readCatalog(addPath));
  }

  if (!fs.existsSync(outPath)) {
    console.error(`  ⚠ Codex 未产出 ${path.relative(ROOT, outPath)}`);
    return null;
  }
  return {
    catalog: readCatalog(outPath),
    glossaryAdded,
  };
}

async function cmdTranslate(args: string[]) {
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
    console.log(
      `${file}: 待译 ${keys.length}，分 ${batches} 批（每批 ${CHUNK}）`,
    );
    console.log(
      `Codex: reasoning=${CODEX_REASONING}` +
        (CODEX_MODEL ? `, model=${CODEX_MODEL}` : '') +
        (CODEX_STDIO === 'inherit'
          ? ', stdout=inherit'
          : ', stdout=.pending/*.codex.log'),
    );
    const dstFile = path.join(DST_DIR, file);
    for (let start = 0, idx = 0; start < keys.length; start += CHUNK, idx++) {
      const batch: Catalog = {};
      for (const key of keys.slice(start, start + CHUNK))
        batch[key] = pending[key];
      const batchNo = idx + 1;
      const timer = startProgress(
        file,
        idx,
        batches,
        `批 ${batchNo}/${batches} Codex 翻译 ${Object.keys(batch).length} 条`,
      );
      const translatedBatch = await translateBatch(file, idx, batch);
      if (!translatedBatch) {
        finishProgress(
          timer,
          file,
          idx,
          batches,
          `批 ${batchNo}/${batches} 失败`,
        );
        continue;
      }
      const translated = translatedBatch.catalog;
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
      fs.writeFileSync(dstFile, `${JSON.stringify(sorted, null, 2)}\n`);
      finishProgress(
        timer,
        file,
        batchNo,
        batches,
        `批 ${batchNo}/${batches} 合并 ${applied}`,
      );
      if (translatedBatch.glossaryAdded) {
        console.log(
          `  术语表 +${translatedBatch.glossaryAdded}（已并入 ${path.relative(ROOT, GLOSSARY_PATH)}）`,
        );
      }
    }
  }
  console.log(`完成。请抽检后提交 strings/i18n/${LOCALE}。`);
}

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === 'pending') cmdPending(rest);
else if (cmd === 'translate' || cmd === undefined) await cmdTranslate(rest);
else {
  console.error('用法: i18n-mt.ts pending|translate [namespace...]');
  process.exit(1);
}
