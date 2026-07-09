#!/usr/bin/env bun
// NovaSector 全量汉化：术语表候选发现。
//
//   bun tools/i18n/mt/glossary-sync.ts suggest [n]   # 从英文目录里挑「高频、尚未入术语表」的候选词
//
// 术语表本体：tools/i18n/mt/glossary.zh-Hans.json（英文->中文；保持英文则 value 同 key）。
// 人工校对走「在线本地化平台」——译文是 strings/i18n/<locale>/*.json 扁平 JSON，可导入任意
// 平台（Crowdin / Lokalise / Weblate / Tolgee Cloud 等），平台自带术语表/词汇表功能，故这里
// 不再内置具体平台的同步（旧版的自托管 Tolgee push/pull 已移除）。

import fs from 'node:fs';
import path from 'node:path';

const LOCALE = process.env.I18N_LOCALE ?? 'zh-Hans';
const ROOT = path.resolve(import.meta.dir, '../../..');
const GLOSSARY_PATH = path.join(import.meta.dir, `glossary.${LOCALE}.json`);

function loadGlossary(): Record<string, string> {
  return fs.existsSync(GLOSSARY_PATH) ? JSON.parse(fs.readFileSync(GLOSSARY_PATH, 'utf8')) : {};
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
  console.log('\n挑选后加入 ' + path.relative(ROOT, GLOSSARY_PATH) + '（英文->中文；保持英文则 value 同 key）。');
}

const [cmd, arg] = process.argv.slice(2);
if (cmd === 'suggest') cmdSuggest(Number(arg ?? 40));
else {
  console.error('用法: glossary-sync.ts suggest [n]');
  process.exit(1);
}
