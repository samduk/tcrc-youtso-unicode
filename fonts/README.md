# fonts/

`TCRC-Youtso-Unicode-fixed.ttf` is the original "TCRC Youtso Unicode" font
(© Tibetan Computing Resource Centre, 2000-2003) with repaired internals:

- 419 glyphs that all shared the broken name ".notdef" were given proper names
- the OS/2 table was upgraded from version 0 (early-1990s format) to version 4,
  declaring the Tibetan Unicode range so modern applications recognize it

The typeface itself — every outline, every stack, every spacing rule — is
untouched and remains TCRC's work. See tools/repair_font.py for exactly what
was changed and why.

Since version 1.4.0, the font draws ordinary ASCII digits 0-9 with Tibetan
numeral glyphs. The stored characters remain ASCII digits, so Excel formulas,
sorting, and calculations continue to work. Western digit shapes are not
preserved when text uses TCRC Youtso Unicode.
