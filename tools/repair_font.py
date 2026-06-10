"""
repair_font.py — how the original TCRC Youtso Unicode font was repaired.

THE PROBLEM
-----------
The font from 2003 was already a Unicode font, but its internals were so old
that modern applications mistrusted it:

  1. 419 glyphs all shared the broken name ".notdef" — sloppy, and some
     applications reject fonts like that.
  2. The OS/2 table (the font's "ID card" for Windows) was version 0, a
     format from the early 1990s. It did not declare that the font supports
     the Tibetan Unicode range, so font menus could not categorize it.

THE FIX (this script)
---------------------
  1. Give every glyph a proper name (uniXXXX when the glyph maps to a
     Unicode character, glyphNNNNN otherwise).
  2. Upgrade the OS/2 table to version 4 and declare: Basic Latin,
     Latin-1, General Punctuation and Tibetan Unicode ranges, plus the
     Windows-1252 codepage.
  3. Bump the version so Windows treats it as an update.

The glyph outlines, the character map, and the Tibetan stacking rules
(GSUB/GPOS tables) are NOT touched — the typeface stays exactly the same.

HOW TO USE
----------
    pip install fonttools
    python repair_font.py TibetanUnicode.ttf  TCRC-Youtso-Unicode-fixed.ttf
"""

import sys
from fontTools.ttLib import TTFont


def repair(source_path: str, target_path: str) -> None:
    # ---- pass 1: read the font and decide every glyph's new name --------
    font = TTFont(source_path)
    old_names = font.getGlyphOrder()

    # which Unicode codepoint does each glyph display? (from the cmap)
    glyph_to_unicode = {}
    for codepoint, glyph_name in sorted(font.getBestCmap().items()):
        glyph_to_unicode.setdefault(glyph_name, codepoint)

    new_names, taken = [], set()
    for glyph_id, name in enumerate(old_names):
        if glyph_id == 0:
            new = ".notdef"                       # glyph 0 must keep this name
        elif name.split("#")[0] == ".notdef":     # the 419 broken ones
            codepoint = glyph_to_unicode.get(name)
            new = f"uni{codepoint:04X}" if codepoint else f"glyph{glyph_id:05d}"
        else:
            new = name.split("#")[0]
        while new in taken:                       # names must be unique
            new += ".alt"
        taken.add(new)
        new_names.append(new)

    # ---- pass 2: open the font lazily and apply the changes -------------
    # (lazy = tables we don't touch are copied through byte-for-byte,
    #  which guarantees the typeface itself cannot be damaged)
    font = TTFont(source_path, lazy=True)
    post = font["post"]                # the table that stores glyph names
    font.glyphOrder = new_names
    if hasattr(post, "glyphOrder"):
        post.glyphOrder = new_names
    post.extraNames, post.mapping = [], {}

    os2 = font["OS/2"]
    os2.version = 4
    os2.ulUnicodeRange1 = (1 << 0) | (1 << 1) | (1 << 31)  # Latin + punctuation
    os2.ulUnicodeRange2 = 1 << (70 - 64)                   # bit 70 = Tibetan
    os2.ulUnicodeRange3 = 0
    os2.ulUnicodeRange4 = 0
    os2.ulCodePageRange1 = 1                               # Windows-1252
    os2.ulCodePageRange2 = 0
    os2.usDefaultChar, os2.usBreakChar, os2.usMaxContext = 0, 0x20, 8
    os2.sxHeight = os2.sCapHeight = 0
    os2.fsSelection |= 0x40                                # "regular" style

    font["name"].setName("Version 1.10; modernized tables", 5, 3, 1, 0x409)
    font["head"].fontRevision = 1.10

    font.save(target_path)
    print(f"repaired font written to {target_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: python repair_font.py <old.ttf> <fixed.ttf>")
    repair(sys.argv[1], sys.argv[2])
