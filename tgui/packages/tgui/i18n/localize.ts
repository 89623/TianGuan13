// THIS IS A NOVA SECTOR UI FILE
// Shared helpers for automatic TGUI JSX localization.

import { translateCurrent } from './catalog';
import policy from './policy.json';

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
// 清单来自三端策略单一来源 strings/i18n/policy.json 的 `no_auto_translate`
// （`tgui-catalog.mjs sync` 复制到本目录供打包）。新增豁免改 policy.json 后跑 sync。
const NO_AUTO_TRANSLATE = new Set<string>(policy.no_auto_translate);

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
  if (translated !== lookup) {
    return `${leading}${translated}${trailing}`;
  }
  // 未命中:精灵配件「备用版」名(生殖器/发型/尾巴/胸罩…)运行期由 `parent_type::name + " (Alt)"`
  // 编译期拼成("Human (Alt)"/"Pair (Alt)"/"Knotted (Alt)"…)，整串永不是字面量、无法抽取(抽出的是
  // 含占位符的模板 "{0} (Alt)"、反查跳过) → 译**基础名**、保留 " (Alt)" 后缀标记。
  const altMatch = lookup.match(/^(.+) \(Alt\)$/);
  if (altMatch) {
    const baseTranslated = translateCurrent(altMatch[1]);
    if (baseTranslated !== altMatch[1]) {
      return `${leading}${baseTranslated} (Alt)${trailing}`;
    }
  }
  // 未命中时保留原始 body（含原排版），不改动。
  return `${leading}${body}${trailing}`;
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
  // 裸字符串选项**一律不翻**：在 tgui-core Dropdown 里「字符串选项的值===显示文本」(m(o)=o)，
  // onSelected 回传的就是这个字符串。若翻成中文，回传中文、而调用方几乎都按英文原文匹配
  // (`aug_options.find(a => displayName(a) === 回传)`、`value === style.name`、或把回传直接当
  // `style_name`/标识符发回服务端) → 匹配失败、选择静默失效（「强化+ 身体部位下拉点了没反应」即此）。
  // 字符串选项的「值」本身就是标识符,不可改。需要既翻显示又能正确回传的下拉,应改用**对象选项**
  // `{value, displayText}`：value 保持英文标识符(下面只翻 displayText)——见 LimbsPage 强化/植入下拉。
  if (typeof option === 'string') {
    return option;
  }
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
