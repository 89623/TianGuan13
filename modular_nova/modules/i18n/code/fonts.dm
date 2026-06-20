// i18n: CJK pixel font for maptext (balloon alerts, screentips, runechat, etc.)
//
// The core maptext fonts (Grand9K Pixel / Pixellari / TinyUnicode / Spess Font) only
// contain Latin glyphs. When Chinese text is rendered in maptext, BYOND falls back to a
// system font at the tiny 6pt size and then the map scales it up -> blurry mush.
//
// Fusion Pixel 8px (OFL-1.1, https://github.com/TakWolf/fusion-pixel-font) is a pixel
// font designed to be crisp at 8px = 6pt, and stays pixel-perfect at integer multiples
// (12pt = 16px = 2x, 18pt = 24px = 3x). We register it here so BYOND ships the .ttf to
// clients, then add it to the maptext font-family fallback lists in interface/skin.dmf.
// Latin glyphs still come from the Latin pixel fonts (per-glyph fallback); only CJK
// glyphs fall through to this font. License: modular_nova/modules/i18n/fonts/OFL.txt
/datum/font/fusion_pixel_8px
	name = "Fusion Pixel 8px Mono zh_hans"
	font_family = 'modular_nova/modules/i18n/fonts/fusion_pixel_8px_zh_hans.ttf'
