#!/usr/bin/env bun
// NovaSector 全量汉化：增量、混译检测的翻译驱动。
//
// 思路：逐 key 判定状态（已译 / 缺失 / 未译 / 中英混杂），只把「待译」的那批喂给 Codex，
// 翻完合并回 zh-Hans。避免整文件重译，且能把 obj.json 这种里中英混杂的条目挑出来重做。
//
// 命令：
//   bun tools/i18n/mt/i18n-mt.ts pending [ns...]      # 只报告各文件待译数量与样例（不调用 Codex）
//   bun tools/i18n/mt/i18n-mt.ts terms [ns...]        # 只报告译文与术语表不一致的条目
//   bun tools/i18n/mt/i18n-mt.ts translate [ns...]    # 计算待译 -> Codex 翻译 -> 合并回 zh-Hans
//   bun tools/i18n/mt/i18n-mt.ts translate-terms [ns...] # 只让 Codex 修正术语不一致的条目
//
// 环境：I18N_LOCALE（默认 zh-Hans）。translate 需要 codex CLI（禁用 MCP 运行）。
// Codex 输出默认写入 tools/i18n/mt/.pending/*.codex.log，终端只显示批次进度。
// 默认串行跑完整个待译队列：始终只启动 1 个 Codex 调用，结束后再进入下一批。

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

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw == null || raw === '') {
    return fallback;
  }
  const parsed = Number(raw);
  return Number.isFinite(parsed) && parsed >= 0 ? Math.floor(parsed) : fallback;
}

function envFlag(name: string): boolean {
  return /^(1|true|yes|on)$/i.test(process.env[name] ?? '');
}

const MAX_CODEX_CALLS = envInt(
  'I18N_MAX_CODEX_CALLS',
  envInt('I18N_MAX_AGENTS', envInt('I18N_MAX_BATCHES', 0)),
);
const CODEX_DELAY_MS = envInt('I18N_CODEX_DELAY_MS', 0);
const CONTINUE_ON_FAIL = envFlag('I18N_CONTINUE_ON_FAIL');
const FULL_GLOSSARY = envFlag('I18N_FULL_GLOSSARY');
const CODEX_OUTPUT_POLL_MS = envInt('I18N_CODEX_OUTPUT_POLL_MS', 2000);
const CODEX_OUTPUT_KILL_MS = envInt('I18N_CODEX_OUTPUT_KILL_MS', 5000);

type Catalog = Record<string, string>;
type WorkMode = 'pending' | 'terms';
type TranslatedBatch = {
  catalog: Catalog;
  glossaryAdded: number;
  reused?: boolean;
};
type TermMismatch = {
  term: string;
  expected: string;
};
type GlossaryTerm = TermMismatch & {
  sourcePattern: RegExp;
};
type TermReportEntry = {
  en: string;
  zh: string;
  missing: TermMismatch[];
};
type TermReport = Record<string, Record<string, TermReportEntry>>;

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

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function sourceTermPattern(term: string): RegExp {
  const prefix = /^[A-Za-z0-9]/.test(term) ? '(^|[^A-Za-z0-9])' : '';
  const suffix = /[A-Za-z0-9]$/.test(term) ? '(?=$|[^A-Za-z0-9])' : '';
  return new RegExp(`${prefix}${escapeRegExp(term)}${suffix}`, 'u');
}

function glossaryTerms(): GlossaryTerm[] {
  return Object.entries(glossary)
    .filter(([term, expected]) => term.length >= 2 && expected.length > 0)
    .sort((a, b) => b[0].length - a[0].length)
    .map(([term, expected]) => ({
      term,
      expected,
      sourcePattern: sourceTermPattern(term),
    }));
}

let termsByLength = glossaryTerms();

const LOWERCASE_TERM_ALLOWLIST = new Set([
  'ahelp',
  'airlock',
  'alifil',
  'antagonist',
  'arrivals',
  'bitrunner',
  'bluespace',
  'borg',
  'brussite',
  'buildmode',
  'ckey',
  'corpo',
  'deadchat',
  'departures',
  'digi',
  'disabler',
  'eigenstate',
  'embershrooms',
  'flechette',
  'freon',
  'gondola',
  'griff',
  'hardlight',
  'headcrab',
  'healium',
  'hemoparasite',
  'holonet',
  'honk',
  'lavaland',
  'lavaloop',
  'maintenance',
  'medicell',
  'medigun',
  'mercuryblast',
  'meteorslug',
  'minebot',
  'mothroach',
  'neuroware',
  'nitrium',
  'nizaya',
  'persocom',
  'piledriver',
  'plasma',
  'readmin',
  'robust',
  'rubbernecker',
  'seraka',
  'shakiri',
  'tacoyaki',
  'taser',
  'tegu',
  'tepache',
  'thoughtfeeder',
  'tinumium',
  'traitor',
  'tritium',
  'voltvine',
  'zaukerite',
]);

const SINGLE_WORD_TERM_ALLOWLIST = new Set([
  'Nanotrasen',
  'Sol',
  'SolFed',
  'Syndicate',
]);

const GENERIC_GLOSSARY_REJECTS = new Set([
  'abandoned',
  'advanced',
  'aft',
  'agent',
  'alien',
  'ash',
  'ashen',
  'auxiliary',
  'back',
  'backstage',
  'bad',
  'bar',
  'base',
  'basic',
  'bathrooms',
  'bay',
  'biolab',
  'big',
  'black',
  'block',
  'blue',
  'board',
  'bottom',
  'botany',
  'bow',
  'box',
  'bridge',
  'brig',
  'bright',
  'brown',
  'cafeteria',
  'cargo',
  'caves',
  'central',
  'chapel',
  'clean',
  'closed',
  'cold',
  'command',
  'common',
  'construction',
  'crate',
  'cubicles',
  'custodial',
  'customs',
  'dark',
  'deep',
  'derelict',
  'delta',
  'dirty',
  'disposals',
  'division',
  'dock',
  'dormitories',
  'dormitory',
  'dorms',
  'down',
  'east',
  'electrical',
  'empty',
  'engine',
  'engineering',
  'exosuit',
  'facility',
  'female',
  'first',
  'floor',
  'fore',
  'fourth',
  'fluffy',
  'full',
  'gateway',
  'genetical',
  'glass',
  'good',
  'gold',
  'gray',
  'graveyard',
  'greater',
  'green',
  'grey',
  'hall',
  'halls',
  'hallway',
  'heavy',
  'high',
  'hot',
  'hotel',
  'human',
  'hydroponics',
  'inside',
  'lab',
  'large',
  'lawful',
  'left',
  'lesser',
  'library',
  'light',
  'little',
  'lobby',
  'long',
  'lounge',
  'low',
  'lower',
  'magazine',
  'maint',
  'male',
  'medbay',
  'medical',
  'metal',
  'mining',
  'new',
  'normal',
  'north',
  'office',
  'old',
  'open',
  'operatives',
  'orange',
  'ordnance',
  'outpost',
  'pale',
  'pharmacy',
  'pink',
  'poke',
  'port',
  'power',
  'prison',
  'public',
  'purple',
  'red',
  'research',
  'restroom',
  'restrooms',
  'right',
  'ripper',
  'robotics',
  'round',
  'satellite',
  'science',
  'secure',
  'security',
  'service',
  'server',
  'shared',
  'ship',
  'short',
  'silver',
  'small',
  'softdrinks',
  'south',
  'spa',
  'special',
  'stairwell',
  'starboard',
  'storage',
  'supply',
  'room',
  'second',
  'target',
  'telecommunications',
  'tent',
  'third',
  'thermodynamic',
  'toolbox',
  'top',
  'tunnel',
  'up',
  'upper',
  'vendor',
  'virology',
  'wall',
  'walkway',
  'warm',
  'waystation',
  'welding',
  'west',
  'white',
  'window',
  'wood',
  'worn',
  'yellow',
]);

function saveGlossary() {
  const sorted: Record<string, string> = {};
  for (const k of Object.keys(glossary).sort()) sorted[k] = glossary[k];
  fs.writeFileSync(GLOSSARY_PATH, `${JSON.stringify(sorted, null, 2)}\n`);
}

function isGlossaryAdditionCandidate(en: string): boolean {
  const term = en.trim();
  if (term.length < 3 || term !== en || /[{}<>]/.test(term)) {
    return false;
  }

  const words = term.match(/[A-Za-z]+/g) ?? [];
  const lowerWords = words.map((word) => word.toLowerCase());
  if (lowerWords.some((word) => GENERIC_GLOSSARY_REJECTS.has(word))) {
    return false;
  }

  if (/^[a-z]+$/.test(term)) {
    return LOWERCASE_TERM_ALLOWLIST.has(term);
  }

  if (/^[A-Z0-9]{2,}$/.test(term)) {
    return true;
  }

  if (/[0-9.+_/()-]/.test(term)) {
    return true;
  }

  if (/^[A-Z][A-Za-z]+(?:[ '-][A-Z][A-Za-z]+)+$/.test(term)) {
    return true;
  }

  if (/^[A-Z][a-z]+$/.test(term)) {
    return SINGLE_WORD_TERM_ALLOWLIST.has(term);
  }

  if (/^[A-Z][A-Za-z]*[a-z][A-Z][A-Za-z]*$/.test(term)) {
    return true;
  }

  return false;
}

/** 把 Codex 这批新发现的固定词合并进术语表（仅新增，不覆盖已有人工译名），并落盘。 */
function mergeGlossaryAdditions(additions: Record<string, string>): number {
  let added = 0;
  for (const [en, zh] of Object.entries(additions)) {
    if (!en || !zh || en in glossary) continue;
    if (!isGlossaryAdditionCandidate(en)) continue;
    glossary[en] = zh;
    added++;
  }
  if (added) {
    keepEnglish = keepEnglishTerms();
    termsByLength = glossaryTerms();
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

function jsonFileEquals(file: string, expected: unknown): boolean {
  if (!fs.existsSync(file)) {
    return false;
  }
  try {
    return (
      JSON.stringify(JSON.parse(fs.readFileSync(file, 'utf8'))) ===
      JSON.stringify(expected)
    );
  } catch {
    return false;
  }
}

function writableTarget(file: string): boolean {
  try {
    if (fs.existsSync(file)) {
      fs.accessSync(file, fs.constants.W_OK);
    } else {
      fs.accessSync(path.dirname(file), fs.constants.W_OK);
    }
    return true;
  } catch {
    return false;
  }
}

function ensureWritableTarget(file: string, label: string): boolean {
  if (writableTarget(file)) {
    return true;
  }
  const rel = path.relative(ROOT, file);
  console.error(
    `  ⚠ ${label} 不可写：${rel}。请先修权限，例如：chmod u+w ${rel}`,
  );
  return false;
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

function termMismatches(
  enVal: string,
  zhVal: string | undefined,
): TermMismatch[] {
  if (zhVal == null || zhVal === '' || zhVal === enVal) {
    return [];
  }

  const missing: TermMismatch[] = [];
  for (const { term, expected, sourcePattern } of termsByLength) {
    if (!sourcePattern.test(enVal) || zhVal.includes(expected)) {
      continue;
    }
    missing.push({ term, expected });
  }
  return missing;
}

/** 计算译文里术语表不一致的集合（key -> 英文源），并返回详细报告。 */
function computeTermReport(file: string): Record<string, TermReportEntry> {
  const en = readCatalog(path.join(EN_DIR, file));
  const zh = readCatalog(path.join(DST_DIR, file));
  const report: Record<string, TermReportEntry> = {};
  for (const key of Object.keys(en)) {
    const zhVal = zh[key];
    const missing = termMismatches(en[key], zhVal);
    if (missing.length) {
      report[key] = {
        en: en[key],
        zh: zhVal ?? '',
        missing,
      };
    }
  }
  return report;
}

function computeTermPending(file: string): Catalog {
  const report = computeTermReport(file);
  const pending: Catalog = {};
  for (const [key, entry] of Object.entries(report)) {
    pending[key] = entry.en;
  }
  return pending;
}

function writeTermReport(report: TermReport) {
  fs.mkdirSync(PENDING_DIR, { recursive: true });
  const outPath = path.join(PENDING_DIR, `glossary-mismatches.${LOCALE}.json`);
  fs.writeFileSync(outPath, `${JSON.stringify(report, null, 2)}\n`);
  return outPath;
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

function cmdTerms(args: string[]) {
  let total = 0;
  const fullReport: TermReport = {};
  for (const file of namespaceFiles(args)) {
    const report = computeTermReport(file);
    const n = Object.keys(report).length;
    total += n;
    fullReport[file] = report;
    const sample = Object.entries(report)
      .slice(0, 2)
      .map(([key, entry]) => {
        const terms = entry.missing
          .slice(0, 3)
          .map(({ term, expected }) => `${term}->${expected}`)
          .join(', ');
        return `${key} [${terms}]`;
      });
    console.log(
      `${file}: 术语不一致 ${n}${n ? `  e.g. ${sample.join(' | ')}` : ''}`,
    );
  }
  const outPath = writeTermReport(fullReport);
  console.log(`合计术语不一致 ${total} 条（locale=${LOCALE}）`);
  console.log(`详情：${path.relative(ROOT, outPath)}`);
}

function batchGlossaryEntries(batch: Catalog): [string, string][] {
  if (FULL_GLOSSARY) {
    return Object.entries(glossary);
  }

  const selected = new Map<string, string>();
  for (const value of Object.values(batch)) {
    for (const { term, expected, sourcePattern } of termsByLength) {
      if (sourcePattern.test(value)) {
        selected.set(term, expected);
      }
    }
  }
  return [...selected.entries()];
}

function glossaryHint(batch: Catalog): string {
  const entries = batchGlossaryEntries(batch);
  if (entries.length === 0) {
    return '- （本批没有命中术语表；仍需保留 {0}/{1} 占位符、HTML/DM 宏和大写缩写）';
  }
  return entries.map(([en, zh]) => `- ${en} => ${zh}`).join('\n');
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

async function sleep(ms: number): Promise<void> {
  if (ms <= 0) {
    return;
  }
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function runCodex(
  prompt: string,
  logPath: string,
  successProbe?: () => boolean,
): Promise<boolean> {
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
      let outputReady = false;
      let killTimer: ReturnType<typeof setTimeout> | null = null;
      const probeTimer = successProbe
        ? setInterval(() => {
            if (!outputReady && successProbe()) {
              outputReady = true;
              child.kill('SIGTERM');
              killTimer = setTimeout(
                () => child.kill('SIGKILL'),
                CODEX_OUTPUT_KILL_MS,
              );
            }
          }, CODEX_OUTPUT_POLL_MS)
        : null;
      child.on('close', (code) => {
        if (probeTimer) clearInterval(probeTimer);
        if (killTimer) clearTimeout(killTimer);
        resolve(outputReady || code === 0);
      });
      child.on('error', () => {
        if (probeTimer) clearInterval(probeTimer);
        if (killTimer) clearTimeout(killTimer);
        resolve(outputReady);
      });
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

    let outputReady = false;
    let killTimer: ReturnType<typeof setTimeout> | null = null;
    const probeTimer = successProbe
      ? setInterval(() => {
          if (!outputReady && successProbe()) {
            outputReady = true;
            log.write(
              `\n=== detected complete output; terminating Codex wrapper ===\n`,
            );
            child.kill('SIGTERM');
            killTimer = setTimeout(
              () => child.kill('SIGKILL'),
              CODEX_OUTPUT_KILL_MS,
            );
          }
        }, CODEX_OUTPUT_POLL_MS)
      : null;

    child.stdout.pipe(log, { end: false });
    child.stderr.pipe(log, { end: false });
    child.on('close', (code) => {
      if (probeTimer) clearInterval(probeTimer);
      if (killTimer) clearTimeout(killTimer);
      log.write(`\n=== exit ${code} ===\n`);
      log.end();
      resolve(outputReady || code === 0);
    });
    child.on('error', (err) => {
      if (probeTimer) clearInterval(probeTimer);
      if (killTimer) clearTimeout(killTimer);
      log.write(`\n=== spawn error: ${err.message} ===\n`);
      log.end();
      resolve(outputReady);
    });
  });
}

function shortIdBatch(batch: Catalog): {
  codexBatch: Catalog;
  idToKeys: string[][];
} {
  const codexBatch: Catalog = {};
  const idToKeys: string[][] = [];
  const valueToId = new Map<string, number>();
  for (const key of Object.keys(batch)) {
    const value = batch[key];
    const existingId = valueToId.get(value);
    if (existingId != null) {
      idToKeys[existingId].push(key);
      continue;
    }
    const numericId = idToKeys.length;
    const id = String(numericId);
    valueToId.set(value, numericId);
    idToKeys.push([key]);
    codexBatch[id] = value;
  }
  return { codexBatch, idToKeys };
}

function mapTranslatedBatch(
  raw: Catalog,
  idToKeys: string[][],
  batch: Catalog,
): Catalog {
  const translated: Catalog = {};
  for (const [id, value] of Object.entries(raw)) {
    const numericId = Number(id);
    const keys =
      Number.isInteger(numericId) && numericId >= 0
        ? idToKeys[numericId]
        : [id];
    for (const key of keys ?? []) {
      if (!(key in batch)) {
        continue;
      }
      translated[key] = value;
    }
  }
  return translated;
}

function reusableCatalog(
  inPath: string,
  keysPath: string,
  outPath: string,
  codexBatch: Catalog,
  idToKeys: string[][],
  batch: Catalog,
): Catalog | null {
  if (
    !jsonFileEquals(inPath, codexBatch) ||
    !jsonFileEquals(keysPath, idToKeys) ||
    !fs.existsSync(outPath)
  ) {
    return null;
  }

  let raw: Catalog;
  try {
    raw = readCatalog(outPath);
  } catch {
    return null;
  }

  const expectedIds = Object.keys(codexBatch).sort();
  const actualIds = Object.keys(raw).sort();
  if (JSON.stringify(expectedIds) !== JSON.stringify(actualIds)) {
    return null;
  }

  const catalog = mapTranslatedBatch(raw, idToKeys, batch);
  if (Object.keys(catalog).length !== Object.keys(batch).length) {
    return null;
  }

  return catalog;
}

function reusableTranslatedBatch(
  inPath: string,
  keysPath: string,
  outPath: string,
  addPath: string,
  codexBatch: Catalog,
  idToKeys: string[][],
  batch: Catalog,
): TranslatedBatch | null {
  const catalog = reusableCatalog(
    inPath,
    keysPath,
    outPath,
    codexBatch,
    idToKeys,
    batch,
  );
  if (!catalog) {
    return null;
  }

  const glossaryAdded = fs.existsSync(addPath)
    ? mergeGlossaryAdditions(readCatalog(addPath))
    : 0;
  return { catalog, glossaryAdded, reused: true };
}

async function translateBatch(
  file: string,
  idx: number,
  batch: Catalog,
  mode: WorkMode,
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
  const keysPath = path.join(
    PENDING_DIR,
    file.replace(/\.json$/, `.${idx}.keys.json`),
  );
  const logPath = path.join(
    PENDING_DIR,
    file.replace(/\.json$/, `.${idx}.codex.log`),
  );
  const { codexBatch, idToKeys } = shortIdBatch(batch);

  const reusable = reusableTranslatedBatch(
    inPath,
    keysPath,
    outPath,
    addPath,
    codexBatch,
    idToKeys,
    batch,
  );
  if (reusable) {
    return reusable;
  }

  fs.rmSync(outPath, { force: true });
  fs.rmSync(addPath, { force: true });
  fs.rmSync(keysPath, { force: true });
  fs.rmSync(logPath, { force: true });
  fs.writeFileSync(inPath, `${JSON.stringify(codexBatch)}\n`);
  fs.writeFileSync(keysPath, `${JSON.stringify(idToKeys)}\n`);

  const task =
    mode === 'terms'
      ? '这些条目的现有译文与术语表不一致；请重新给出自然中文译文，并严格套用术语表。'
      : '把每个值翻译为目标语言。';
  const prompt =
    `你是 Space Station 13 游戏文本的专业本地化译者，目标语言：${LOCALE}。${task}` +
    `读取 ${path.relative(ROOT, inPath)}（紧凑 JSON：临时数字 ID -> 唯一英文源；数字 ID 不是目录 key，可能映射到多个真实 key），把每个值翻译为目标语言，写入 ` +
    `${path.relative(ROOT, outPath)}：` +
    `(1) 临时数字 ID 完全不变，不要输出真实目录 key；(2) 逐字保留 {0}/{1}… 占位符、HTML 标签、DM 文本宏（如 \\improper、\\the）；` +
    `(3) 严格遵循术语表（保持英文的词不要翻译，其余英文务必译为中文，不要中英混杂）；` +
    `(4) 大写缩写（APC/RCD/AI 等）保留英文；(5) 只输出/写入紧凑合法 JSON，键序与输入一致，不要 Markdown。` +
    `(6) 凡是术语表里没有的「固定专名/术语」才追加到 ${path.relative(ROOT, addPath)}：` +
    `只包括品牌、阵营/组织、物种、舰船/站点/地图名、唯一装备/武器/药剂/材料、型号、缩写、必须保留英文的命令或程序名。` +
    `不要追加普通单词、多义词、颜色、大小、方向、形容词、泛称名词、可随语境翻译的词（例如 white/black/large/small/left/right/agent/vendor/crate 等）。` +
    `不确定是否固定，就不要加入术语表。本批没有合格新增术语就写 {}。` +
    `以下术语表只列本批命中的术语；若需要完整术语表可用 I18N_FULL_GLOSSARY=1 运行。术语表：\n${glossaryHint(batch)}`;

  const ok = await runCodex(prompt, logPath, () =>
    Boolean(
      reusableCatalog(inPath, keysPath, outPath, codexBatch, idToKeys, batch),
    ),
  );
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
  const catalog = mapTranslatedBatch(readCatalog(outPath), idToKeys, batch);
  if (Object.keys(catalog).length === 0 && Object.keys(batch).length > 0) {
    console.error(
      `  ⚠ Codex 输出没有可映射的临时数字 ID：${path.relative(ROOT, outPath)}`,
    );
    return null;
  }
  return {
    catalog,
    glossaryAdded,
  };
}

async function cmdTranslate(
  args: string[],
  mode: WorkMode = 'pending',
): Promise<boolean> {
  fs.mkdirSync(PENDING_DIR, { recursive: true });
  fs.mkdirSync(DST_DIR, { recursive: true });
  let codexCallsStarted = 0;
  for (const file of namespaceFiles(args)) {
    const pending =
      mode === 'terms' ? computeTermPending(file) : computePending(file);
    const keys = Object.keys(pending);
    if (keys.length === 0) {
      console.log(
        `${file}: 无${mode === 'terms' ? '术语不一致' : '待译'}，跳过`,
      );
      continue;
    }
    const dstFile = path.join(DST_DIR, file);
    if (
      !ensureWritableTarget(dstFile, '译文文件') ||
      !ensureWritableTarget(GLOSSARY_PATH, '术语表')
    ) {
      return false;
    }
    const batches = Math.ceil(keys.length / CHUNK);
    console.log(
      `${file}: ${mode === 'terms' ? '术语不一致' : '待译'} ${keys.length}，分 ${batches} 批（每批 ${CHUNK}）`,
    );
    console.log(
      `Codex: reasoning=${CODEX_REASONING}` +
        (CODEX_MODEL ? `, model=${CODEX_MODEL}` : '') +
        (CODEX_STDIO === 'inherit'
          ? ', stdout=inherit'
          : ', stdout=.pending/*.codex.log') +
        (MAX_CODEX_CALLS > 0
          ? `, calls=${codexCallsStarted}/${MAX_CODEX_CALLS}`
          : ', calls=unlimited'),
    );
    for (let start = 0, idx = 0; start < keys.length; start += CHUNK, idx++) {
      if (MAX_CODEX_CALLS > 0 && codexCallsStarted >= MAX_CODEX_CALLS) {
        console.log(
          `达到本次 Codex 调用上限 I18N_MAX_CODEX_CALLS=${MAX_CODEX_CALLS}。重跑同一命令会从剩余待译继续；需要不限量可设 I18N_MAX_CODEX_CALLS=0。`,
        );
        return true;
      }
      const batch: Catalog = {};
      for (const key of keys.slice(start, start + CHUNK))
        batch[key] = pending[key];
      const batchNo = idx + 1;
      const callNo = codexCallsStarted + 1;
      const callLabel =
        MAX_CODEX_CALLS > 0
          ? `call ${callNo}/${MAX_CODEX_CALLS}`
          : `call ${callNo}`;
      const timer = startProgress(
        file,
        idx,
        batches,
        `${callLabel} 批 ${batchNo}/${batches} Codex 翻译 ${Object.keys(batch).length} 条`,
      );
      codexCallsStarted++;
      const translatedBatch = await translateBatch(file, idx, batch, mode);
      if (!translatedBatch) {
        finishProgress(
          timer,
          file,
          idx,
          batches,
          `批 ${batchNo}/${batches} 失败`,
        );
        if (!CONTINUE_ON_FAIL) {
          console.error(
            '已停止，避免继续启动新的 Codex 调用。处理登录/额度/日志里的错误后，重跑同一命令会从剩余待译继续；若确实要跳过失败继续，设 I18N_CONTINUE_ON_FAIL=1。',
          );
          return false;
        }
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
        translatedBatch.reused
          ? `批 ${batchNo}/${batches} 复用 .pending 输出，合并 ${applied}`
          : `批 ${batchNo}/${batches} 合并 ${applied}`,
      );
      if (translatedBatch.glossaryAdded) {
        console.log(
          `  术语表 +${translatedBatch.glossaryAdded}（已并入 ${path.relative(ROOT, GLOSSARY_PATH)}）`,
        );
      }
      await sleep(CODEX_DELAY_MS);
    }
  }
  console.log(`完成。请抽检后提交 strings/i18n/${LOCALE}。`);
  return true;
}

const [cmd, ...rest] = process.argv.slice(2);
if (cmd === 'pending') cmdPending(rest);
else if (cmd === 'terms' || cmd === 'term-pending') cmdTerms(rest);
else if (cmd === 'translate-terms' || cmd === 'repair-terms') {
  const ok = await cmdTranslate(rest, 'terms');
  if (!ok) {
    process.exit(1);
  }
} else if (cmd === 'translate' || cmd === undefined) {
  const ok = await cmdTranslate(rest);
  if (!ok) {
    process.exit(1);
  }
} else {
  console.error(
    '用法: i18n-mt.ts pending|terms|translate|translate-terms [namespace...]',
  );
  process.exit(1);
}
