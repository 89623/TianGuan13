#!/usr/bin/env bun
// NovaSector 全量汉化：术语表工具 —— 候选发现 + 与 Tolgee 同步。
//
//   bun tools/i18n/mt/glossary-sync.ts suggest [n]   # 从英文目录里挑「高频、尚未入术语表」的候选词
//   bun tools/i18n/mt/glossary-sync.ts push          # 本地术语表 -> Tolgee 词汇表
//   bun tools/i18n/mt/glossary-sync.ts pull          # Tolgee 词汇表 -> 本地术语表
//
// Tolgee 同步需环境变量：TOLGEE_API_URL、TOLGEE_API_KEY、TOLGEE_ORG_ID、TOLGEE_GLOSSARY_ID。
// 注：Tolgee 词汇表 API 端点随版本变化，下面按 v2 习惯写，首次使用请对照你的 Tolgee 版本核对。

import fs from 'node:fs';
import path from 'node:path';

const LOCALE = process.env.I18N_LOCALE ?? 'zh-Hans';
const ROOT = path.resolve(import.meta.dir, '../../..');
const GLOSSARY_PATH = path.join(import.meta.dir, `glossary.${LOCALE}.json`);

function loadGlossary(): Record<string, string> {
  return fs.existsSync(GLOSSARY_PATH) ? JSON.parse(fs.readFileSync(GLOSSARY_PATH, 'utf8')) : {};
}
function saveGlossary(g: Record<string, string>) {
  const sorted: Record<string, string> = {};
  for (const k of Object.keys(g).sort()) sorted[k] = g[k];
  fs.writeFileSync(GLOSSARY_PATH, JSON.stringify(sorted, null, 2) + '\n');
}

// 句首常见英文词（非术语），从候选里剔除。
const STOPWORDS = new Set(
  (
    'You The This That Your There These Those They Their It Its For Use Used Using Can ' +
    'Will When While With And Or But Not No Yes If Is Are Was Were Has Have Had Allows Allow ' +
    'Contains Contain Make Makes Made Get Gets Put Puts See Now Then Here What Which Who Why How ' +
    'Press Click Drag Drop Hold Take Add Remove Open Close Turn Set Each Some Any All One Two'
  )
    .split(' ')
    .map((s) => s.toLowerCase()),
);

/** 从英文目录里发现「多次出现、首字母大写或多词、尚未入术语表」的候选术语。 */
function cmdSuggest(limit: number) {
  const glossary = loadGlossary();
  const known = new Set(Object.keys(glossary).map((s) => s.toLowerCase()));
  const enDir = path.join(ROOT, 'strings/i18n/en');
  const freq = new Map<string, number>();
  for (const file of fs.readdirSync(enDir).filter((f) => f.endsWith('.json'))) {
    const cat: Record<string, string> = JSON.parse(fs.readFileSync(path.join(enDir, file), 'utf8'));
    for (const value of Object.values(cat)) {
      // 候选：连续 1-3 个首字母大写的词（专有名词/装置名），或带连字符的术语。
      const matches = value.match(/\b([A-Z][a-zA-Z0-9]+(?:[ -][A-Z][a-zA-Z0-9]+){0,2})\b/g) ?? [];
      for (const m of matches) {
        // 多词短语或全大写缩写更可能是术语；单个普通句首词剔除。
        const multiword = /[ -]/.test(m);
        const acronym = /^[A-Z0-9]{2,}$/.test(m);
        if (m.length < 3 || known.has(m.toLowerCase())) continue;
        if (!multiword && !acronym && STOPWORDS.has(m.toLowerCase())) continue;
        freq.set(m, (freq.get(m) ?? 0) + 1);
      }
    }
  }
  const ranked = [...freq.entries()].sort((a, b) => b[1] - a[1]).slice(0, limit);
  console.log(`候选术语（高频、未入表），共 ${ranked.length}：`);
  for (const [term, count] of ranked) console.log(`  ${count}\t${term}`);
  console.log('\n挑选后加入 ' + path.relative(ROOT, GLOSSARY_PATH) + '（英文->中文；保持英文则 value 同 key），再 push。');
}

function tolgeeConfig() {
  const url = process.env.TOLGEE_API_URL;
  const key = process.env.TOLGEE_API_KEY;
  const org = process.env.TOLGEE_ORG_ID;
  const glossaryId = process.env.TOLGEE_GLOSSARY_ID;
  if (!url || !key || !org || !glossaryId) {
    console.error('需要 TOLGEE_API_URL / TOLGEE_API_KEY / TOLGEE_ORG_ID / TOLGEE_GLOSSARY_ID');
    process.exit(1);
  }
  return { url, key, org, glossaryId };
}

async function cmdPush() {
  const { url, key, org, glossaryId } = tolgeeConfig();
  const glossary = loadGlossary();
  // TODO: 端点随 Tolgee 版本核对。v2 习惯：POST .../glossaries/{id}/terms
  const base = `${url}/v2/organizations/${org}/glossaries/${glossaryId}`;
  let ok = 0;
  for (const [en, zh] of Object.entries(glossary)) {
    const res = await fetch(`${base}/terms`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'X-API-Key': key },
      body: JSON.stringify({ text: en, description: '', translations: { [LOCALE]: zh } }),
    });
    if (res.ok) ok++;
    else console.error(`  push 失败 ${en}: ${res.status}`);
  }
  console.log(`推送 ${ok}/${Object.keys(glossary).length} 个术语到 Tolgee`);
}

async function cmdPull() {
  const { url, key, org, glossaryId } = tolgeeConfig();
  const base = `${url}/v2/organizations/${org}/glossaries/${glossaryId}`;
  const res = await fetch(`${base}/terms?size=10000`, { headers: { 'X-API-Key': key } });
  if (!res.ok) {
    console.error(`pull 失败: ${res.status}`);
    process.exit(1);
  }
  const data: any = await res.json();
  const terms: any[] = data?._embedded?.glossaryTerms ?? data?.terms ?? [];
  const glossary = loadGlossary();
  for (const t of terms) {
    const en = t.text ?? t.name;
    const zh = t.translations?.[LOCALE]?.text ?? t.translations?.[LOCALE];
    if (en && zh) glossary[en] = zh;
  }
  saveGlossary(glossary);
  console.log(`从 Tolgee 拉取 ${terms.length} 个术语，已并入 ${path.relative(ROOT, GLOSSARY_PATH)}`);
}

const [cmd, arg] = process.argv.slice(2);
if (cmd === 'suggest') cmdSuggest(Number(arg ?? 40));
else if (cmd === 'push') await cmdPush();
else if (cmd === 'pull') await cmdPull();
else {
  console.error('用法: glossary-sync.ts suggest [n] | push | pull');
  process.exit(1);
}
