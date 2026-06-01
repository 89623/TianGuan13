// NovaSector 全量汉化 (i18n) 的跨文件定义。
// 详见 modular_nova/modules/i18n/readme.md。

/// 受支持的界面语言（locale 代码，遵循 BCP-47）。
#define LANGUAGE_LOCALE_EN "en"
#define LANGUAGE_LOCALE_ZH_HANS "zh-Hans"

/// 缺省 locale（找不到玩家/服务器设置时回退到它，也是英文源串的 locale）。
#define DEFAULT_UI_LOCALE LANGUAGE_LOCALE_EN

/// i18n 目录文件位于 STRING_DIRECTORY ("strings") 下的此子目录：
/// strings/i18n/<locale>/<namespace>.json，内容为扁平的 {"key": "模板"}。
#define I18N_SUBDIRECTORY "i18n"

/// 全服 locale 下的本地化 + 格式化。用于广播类文本（visible_message 等，
/// 一条字符串展示给多名观察者，无法按单人 locale 区分）。
/// args 为参数 /list（与模板里的 {0}/{1}… 对应），无参数时传 null。
#define LANG(key, args) (lang_format(key, args))

/// 按单个接收者（user）的 locale 本地化 + 格式化。用于定向文本
/// （to_chat(单人, …)、balloon_alert(viewer, …)）。user 为 null 时回退到全服 locale。
#define LANGU(user, key, args) (lang_format_for(user, key, args))
