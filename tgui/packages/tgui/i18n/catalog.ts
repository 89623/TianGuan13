// THIS IS A NOVA SECTOR UI FILE
// Built-in TGUI catalogs. Runtime locale is supplied by BYOND in config.locale.

import { configAtom, store } from '../events/store';
import en from './en.json';
import zhHans from './zh-Hans.json';

type Catalog = Record<string, string>;

const CATALOGS: Record<string, Catalog> = {
  en: en as Catalog,
  'zh-Hans': zhHans as Catalog,
};

const DEFAULT_LOCALE = 'en';

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

export function translateCurrent(
  key: string,
  args?: Array<string | number>,
): string {
  const locale = store.get(configAtom)?.locale ?? DEFAULT_LOCALE;
  return translate(locale, key, args);
}
