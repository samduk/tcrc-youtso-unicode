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


def decide_new_glyph_names(font):
    """Work out a proper, unique name for every glyph in the font."""

    old_names = font.getGlyphOrder()

    # First, learn which Unicode character each glyph displays.
    # The font's "cmap" table maps character -> glyph; we flip it around.
    glyph_to_unicode = {}
    cmap = font.getBestCmap()
    for codepoint, glyph_name in sorted(cmap.items()):
        glyph_is_already_known = glyph_name in glyph_to_unicode
        if not glyph_is_already_known:
            glyph_to_unicode[glyph_name] = codepoint

    new_names = []
    names_already_used = set()

    for glyph_id, old_name in enumerate(old_names):

        # The very first glyph (number 0) must always be called ".notdef".
        if glyph_id == 0:
            new_name = ".notdef"

        # The broken glyphs: fontTools shows duplicated names as
        # ".notdef#1", ".notdef#2" and so on. Give them real names.
        elif old_name.split("#")[0] == ".notdef":
            if old_name in glyph_to_unicode:
                codepoint = glyph_to_unicode[old_name]
                new_name = "uni%04X" % codepoint        # e.g. uni0F40
            else:
                new_name = "glyph%05d" % glyph_id       # e.g. glyph00598

        # Healthy glyphs keep their name.
        else:
            new_name = old_name.split("#")[0]

        # Names must be unique — add ".alt" until this one is.
        while new_name in names_already_used:
            new_name = new_name + ".alt"

        names_already_used.add(new_name)
        new_names.append(new_name)

    return new_names


def repair(source_path, target_path):

    # ---- pass 1: read the font and decide every glyph's new name --------
    font = TTFont(source_path)
    new_names = decide_new_glyph_names(font)

    # ---- pass 2: open the font again "lazily" and apply the changes -----
    # Lazy means: tables we do not touch are copied through byte-for-byte,
    # which guarantees the typeface itself cannot be damaged.
    font = TTFont(source_path, lazy=True)

    # The "post" table is where glyph names are stored.
    post_table = font["post"]
    font.glyphOrder = new_names
    if hasattr(post_table, "glyphOrder"):
        post_table.glyphOrder = new_names
    post_table.extraNames = []
    post_table.mapping = {}

    # The OS/2 table is the font's "ID card" for Windows.
    os2_table = font["OS/2"]
    os2_table.version = 4
    # Declare which Unicode ranges the font covers (each range is one bit):
    #   bit 0 = Basic Latin, bit 1 = Latin-1, bit 31 = General Punctuation
    os2_table.ulUnicodeRange1 = (1 << 0) | (1 << 1) | (1 << 31)
    #   bit 70 = Tibetan (bits 64-95 live in ulUnicodeRange2)
    os2_table.ulUnicodeRange2 = 1 << (70 - 64)
    os2_table.ulUnicodeRange3 = 0
    os2_table.ulUnicodeRange4 = 0
    # Declare the Windows-1252 codepage (bit 0).
    os2_table.ulCodePageRange1 = 1
    os2_table.ulCodePageRange2 = 0
    # A few fields that exist only in newer OS/2 versions:
    os2_table.usDefaultChar = 0
    os2_table.usBreakChar = 0x20          # the space character
    os2_table.usMaxContext = 8
    os2_table.sxHeight = 0
    os2_table.sCapHeight = 0
    # Mark the font as a "regular" style (bit 6).
    os2_table.fsSelection = os2_table.fsSelection | 0x40

    # Bump the version so Windows sees this as an update.
    font["name"].setName("Version 1.10; modernized tables", 5, 3, 1, 0x409)
    font["head"].fontRevision = 1.10

    font.save(target_path)
    print("repaired font written to " + target_path)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: python repair_font.py <old.ttf> <fixed.ttf>")
    repair(sys.argv[1], sys.argv[2])
