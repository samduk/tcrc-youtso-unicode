"""
Build the font used for calculable Tibetan-looking numbers in Microsoft Excel.

Excel can calculate with the characters 0 through 9. Unicode Tibetan digits
are text in Excel, so formulas such as SUM do not treat them as numbers.

This font solves the display part without changing the stored cell value:

* ASCII digit 0 uses the same glyph as Unicode Tibetan digit zero.
* ASCII digit 1 uses the same glyph as Unicode Tibetan digit one.
* The same rule continues through digit 9.

The resulting Excel cell still contains an ordinary numeric value. Only the
way the number is drawn changes.
"""

import sys
from pathlib import Path

from fontTools.ttLib import TTFont


FONT_FAMILY = "TCRC Youtso Excel Numbers"
POSTSCRIPT_NAME = "TCRCYoutsoExcelNumbers"
VERSION_TEXT = "Version 1.20; Excel numeric display"


def set_windows_name(font, name_id, value):
    """Set one English Windows name-table entry."""

    font["name"].setName(
        value,
        name_id,
        platformID=3,
        platEncID=1,
        langID=0x0409,
    )


def rename_font(font):
    """Give the generated font a name that is distinct in Windows and Office."""

    replacement_names = {
        1: FONT_FAMILY,
        2: "Regular",
        3: FONT_FAMILY + "; " + VERSION_TEXT,
        4: FONT_FAMILY,
        5: VERSION_TEXT,
        6: POSTSCRIPT_NAME,
        16: FONT_FAMILY,
        17: "Regular",
    }

    for name_record in font["name"].names:
        replacement = replacement_names.get(name_record.nameID)
        if replacement is None:
            continue

        encoding = name_record.getEncoding()
        name_record.string = replacement.encode(encoding)

    set_windows_name(font, 1, FONT_FAMILY)
    set_windows_name(font, 2, "Regular")
    set_windows_name(font, 3, FONT_FAMILY + "; " + VERSION_TEXT)
    set_windows_name(font, 4, FONT_FAMILY)
    set_windows_name(font, 5, VERSION_TEXT)
    set_windows_name(font, 6, POSTSCRIPT_NAME)

    # These optional names help newer Office versions group the font correctly.
    set_windows_name(font, 16, FONT_FAMILY)
    set_windows_name(font, 17, "Regular")


def map_ascii_digits_to_tibetan_glyphs(font):
    """Make ASCII digits display with the existing Tibetan digit outlines."""

    unicode_cmap = font.getBestCmap()

    for digit in range(10):
        ascii_codepoint = ord("0") + digit
        tibetan_codepoint = 0x0F20 + digit
        tibetan_glyph = unicode_cmap[tibetan_codepoint]

        for cmap_table in font["cmap"].tables:
            if cmap_table.isUnicode():
                cmap_table.cmap[ascii_codepoint] = tibetan_glyph


def build_font(source_path, target_path):
    """Create the Excel number font from the repaired Unicode font."""

    font = TTFont(source_path)

    rename_font(font)
    map_ascii_digits_to_tibetan_glyphs(font)

    font["head"].fontRevision = 1.20
    font.save(target_path)


def main():
    if len(sys.argv) != 3:
        sys.exit(
            "usage: python build_excel_number_font.py "
            "<source-font.ttf> <target-font.ttf>"
        )

    source_path = Path(sys.argv[1])
    target_path = Path(sys.argv[2])

    build_font(source_path, target_path)
    print("Excel number font written to " + str(target_path))


if __name__ == "__main__":
    main()
