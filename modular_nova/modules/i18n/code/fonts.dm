// i18n: CJK pixel font for maptext (balloon alerts, screentips, runechat, etc.)
//
// The core maptext fonts (Grand9K Pixel / Pixellari / TinyUnicode / Spess Font) only
// contain Latin glyphs. When Chinese text is rendered in maptext, BYOND falls back to a
// system font at the tiny 6pt size and then the map scales it up -> blurry mush.
//
// Fusion Pixel 8px (OFL-1.1, https://github.com/TakWolf/fusion-pixel-font) is a pixel
// font designed to be crisp at 8px = 6pt, and stays pixel-perfect at integer multiples
// (12pt = 16px = 2x, 18pt = 24px = 3x). It contains BOTH CJK and Latin glyphs. We register
// it here so BYOND ships the .ttf to clients, then make it the PRIMARY maptext font in
// interface/skin.dmf.
//
// NOTE: BYOND maptext does NOT do per-glyph fallback across a comma-separated font-family
// list — it renders glyphs from the FIRST font and substitutes a hardcoded system font for
// any the first font lacks (the 2nd+ entries are ignored). So listing Fusion as a *fallback*
// after Grand9K did nothing: CJK still went to the blurry system font. Fusion must be the
// FIRST font; since it has Latin too, all maptext (CJK + Latin) renders in it, sharp.
// License: modular_nova/modules/i18n/fonts/OFL.txt
/datum/font/fusion_pixel_8px
	name = "Fusion Pixel 8px Mono zh_hans"
	font_family = 'modular_nova/modules/i18n/fonts/fusion_pixel_8px_zh_hans.ttf'
