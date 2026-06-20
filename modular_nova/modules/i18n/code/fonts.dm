// i18n: CJK pixel font for maptext (balloon alerts, screentips, runechat, etc.)
//
// The core maptext fonts (Grand9K Pixel / Pixellari / TinyUnicode / Spess Font) only
// contain Latin glyphs. When Chinese text is rendered in maptext, BYOND falls back to a
// system font and renders it soft/blurry. We bundle a pixel CJK font and make it the
// PRIMARY maptext font (interface/skin.dmf) so the CJK renders in it.
//
// Fusion Pixel 12px (OFL-1.1, https://github.com/TakWolf/fusion-pixel-font), zh_hans,
// monospaced. Contains BOTH CJK and Latin glyphs. License: modular_nova/modules/i18n/fonts/OFL.txt
//
// SIZING (the crucial part — pixel fonts only render crisp at their native px or integer
// multiples). BYOND maptext takes font-size in PT and renders em_px = pt * 4/3 (96dpi):
// 6pt->8px, 9pt->12px, 12pt->16px, 18pt->24px. This font's design grid is 12px
// (unitsPerEm=1200, 100 units/px), so it is pixel-perfect at em_px = 12px (9pt) and at
// integer multiples (24px = 18pt). USE 9pt in skin.dmf for 1:1 crisp CJK.
//   - Do NOT use explicit px font-size: BYOND anti-aliases px maptext -> blurry (it wants pt).
//   - The earlier 8px variant was crisp only at 6pt, but 8px CJK is too few pixels (rough);
//     12px@9pt gives clear, legible CJK.
//
// NOTE: BYOND maptext does NOT do per-glyph fallback across a comma-separated font-family
// list — it renders glyphs from the FIRST font and substitutes a hardcoded system font for
// any the first font lacks (the 2nd+ entries are ignored). So this font must be FIRST; since
// it has Latin glyphs too, all maptext (CJK + Latin) renders in it.
/datum/font/fusion_pixel_12px
	name = "Fusion Pixel 12px Mono zh_hans"
	font_family = 'modular_nova/modules/i18n/fonts/fusion_pixel_12px_zh_hans.ttf'
