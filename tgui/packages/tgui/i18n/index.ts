// THIS IS A NOVA SECTOR UI FILE
// 轻量、零运行时依赖的 TGUI 本地化助手。
//
// BYOND 内嵌的 CEF 浏览器在运行时无网络，所以生产环境用「内置 JSON 目录」而非在线
// 翻译服务。locale 取自 config.locale（由 code/modules/tgui/tgui.dm 的 get_payload 注入）。
// 这些 JSON 即 Tolgee 平台同步的源/目标 —— Tolgee 仅作管理平台，运行时不需要它的 SDK。
//
// 占位符语义与 DM 端 LANG 一致：{0}/{1}… 按位置替换，允许按中文语序重排。

import { useBackend } from '../backend';
import en from './en.json';
import zhHans from './zh-Hans.json';

type Catalog = Record<string, string>;

const CATALOGS: Record<string, Catalog> = {
  en: en as Catalog,
  'zh-Hans': zhHans as Catalog,
};

const DEFAULT_LOCALE = 'en';

/** 按 locale 查 key，并用位置参数 {0}/{1}… 填充；缺失则回退英文，再缺则返回 key。 */
export function translate(
  locale: string,
  key: string,
  args?: Array<string | number>,
): string {
  const catalog = CATALOGS[locale] ?? CATALOGS[DEFAULT_LOCALE];
  let template = catalog?.[key] ?? CATALOGS[DEFAULT_LOCALE]?.[key] ?? key;
  if (args) {
    for (let i = 0; i < args.length; i++) {
      template = template.split(`{${i}}`).join(String(args[i]));
    }
  }
  return template;
}

/** 在组件内获取翻译函数，locale 取自 config.locale。 */
export function useT(): (key: string, args?: Array<string | number>) => string {
  const { config } = useBackend();
  const locale = config?.locale ?? DEFAULT_LOCALE;
  return (key, args) => translate(locale, key, args);
}
