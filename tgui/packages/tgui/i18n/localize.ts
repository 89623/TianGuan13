// THIS IS A NOVA SECTOR UI FILE
// Shared helpers for automatic TGUI JSX localization.

import { translateCurrent } from './catalog';

const TRANSLATABLE_PROPS = new Set([
  'aria-label',
  'content',
  'displayText',
  'header',
  'label',
  'message',
  'placeholder',
  'title',
  'tooltip',
]);

const OPTION_TEXT_PROPS = new Set(['displayText', 'label', 'text', 'title']);

// 例外清单：这些英文串**绝不**自动翻译。
//
// 自动本地化按「英文原文」查表，无法在运行时区分「字面量 UI 文案」与「正好等于某常见词的
// 动态数据」。绝大多数命中都是期望的（On→开启、None→无…），但偶尔会把本该保持英文的专有
// 名词 / 代码标识符也翻了（典型：admin VV 里显示的变量名 "Type"、ckey 等）。
// 默认空——只在你确实看到某条被误翻时，把它的英文原文加进来即可全局豁免。
const NO_AUTO_TRANSLATE = new Set<string>([]);

function translateText(text: string): string {
  const match = text.match(/^(\s*)([\s\S]*\S)(\s*)$/);
  if (!match) {
    return text;
  }
  const [, leading, body, trailing] = match;
  // 抽取期 (tgui-catalog.mjs normalizeText) 把内部空白折叠成单空格再算 key，
  // 所以运行时也要先折叠才能命中（否则换行/多空格的静态 JSX 文本永远查不到）。
  const lookup = body.replace(/\s+/g, ' ');
  if (NO_AUTO_TRANSLATE.has(lookup)) {
    return text;
  }
  const translated = translateCurrent(lookup);
  // 未命中时 translateCurrent 原样返回 lookup —— 此时保留原始 body（含原排版），不改动。
  return `${leading}${translated === lookup ? body : translated}${trailing}`;
}

export function localizeNode(value: unknown): unknown {
  if (typeof value === 'string') {
    return translateText(value);
  }
  if (Array.isArray(value)) {
    let changed = false;
    const localized = value.map((entry) => {
      const nextEntry = localizeNode(entry);
      changed ||= nextEntry !== entry;
      return nextEntry;
    });
    return changed ? localized : value;
  }
  return value;
}

function localizeOption(option: unknown): unknown {
  if (!option || typeof option !== 'object' || Array.isArray(option)) {
    return localizeNode(option);
  }

  let nextOption = option as Record<string, unknown>;
  for (const propName of OPTION_TEXT_PROPS) {
    const propValue = nextOption[propName];
    if (typeof propValue !== 'string') {
      continue;
    }

    const localized = translateText(propValue);
    if (localized === propValue) {
      continue;
    }

    if (nextOption === option) {
      nextOption = { ...nextOption };
    }
    nextOption[propName] = localized;
  }
  return nextOption;
}

function localizeOptions(value: unknown): unknown {
  if (!Array.isArray(value)) {
    return value;
  }

  let changed = false;
  const localized = value.map((option) => {
    const nextOption = localizeOption(option);
    changed ||= nextOption !== option;
    return nextOption;
  });
  return changed ? localized : value;
}

export function localizeProps(props: unknown): unknown {
  if (!props || typeof props !== 'object' || Array.isArray(props)) {
    return props;
  }

  let nextProps = props as Record<string, unknown>;
  for (const [propName, propValue] of Object.entries(nextProps)) {
    let localized: unknown = propValue;
    if (propName === 'children') {
      localized = localizeNode(propValue);
    } else if (propName === 'options') {
      localized = localizeOptions(propValue);
    } else if (TRANSLATABLE_PROPS.has(propName)) {
      localized = localizeNode(propValue);
    }

    if (localized === propValue) {
      continue;
    }

    if (nextProps === props) {
      nextProps = { ...nextProps };
    }
    nextProps[propName] = localized;
  }

  return nextProps;
}
