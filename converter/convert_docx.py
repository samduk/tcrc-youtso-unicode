"""
convert_docx.py — turn old TCRC Youtso (legacy) Word documents into Unicode.

WHAT THIS DOES
--------------
Old TCRC documents store Tibetan letters on top of English character codes
(that is why they look like "ºGô-zXôhü" on a modern computer).
This script replaces every legacy character with the correct Unicode Tibetan
character(s) and switches the font to "Microsoft Himalaya", which every
Windows computer already has. After that, the document is normal Unicode:
searchable, copyable, readable on phones — forever.

The original file is NEVER modified. A new file is saved next to it with
" (Unicode)" added to the name.

HOW TO USE
----------
    python convert_docx.py "my document.docx"          # one file
    python convert_docx.py "C:\\My Documents" --batch  # every .docx in a folder

You need Python 3.8+ only — no extra packages.
"""

import argparse
import html
import json
import re
import sys
import unicodedata
import zipfile
from pathlib import Path

# ---------------------------------------------------------------------------
# 1. Load the conversion table (legacy character -> Unicode Tibetan string).
#    This table was built by visually matching every glyph of the old font
#    with the Unicode font — see tools/build_mapping.py for the full story.
# ---------------------------------------------------------------------------
HERE = Path(__file__).parent
TABLE = {
    int(codepoint): unicode_text
    for codepoint, unicode_text in json.loads(
        (HERE / "tcrc_to_unicode_map.json").read_text(encoding="utf-8")
    ).items()
}

# Font names the old documents use. If you find a document with another
# TCRC legacy font name, just add it to this list.
LEGACY_FONT_NAMES = ["TCRC Bod-Yig", "TCRC Youtsoweb", "TCRC Youtso"]

# Every Windows computer has this Unicode Tibetan font built in.
REPLACEMENT_FONT = "Microsoft Himalaya"


def convert_text(legacy_text: str) -> str:
    """Convert one string of legacy characters to Unicode Tibetan."""
    converted = "".join(TABLE.get(ord(ch), ch) for ch in legacy_text)
    # NFC normalization puts combining vowel signs in the canonical order.
    return unicodedata.normalize("NFC", converted)


def convert_docx(source: Path) -> Path:
    """Convert one .docx file. Returns the path of the new file."""
    target = source.with_name(source.stem + " (Unicode)" + source.suffix)

    with zipfile.ZipFile(source) as zin:
        document_xml = zin.read("word/document.xml").decode("utf-8")

        # A .docx is a zip of XML files. Text lives in "runs" (<w:r>...</w:r>),
        # and each run says which font it uses. We only convert runs that use
        # one of the legacy fonts, so English text etc. is left alone.
        pieces = re.split(r"(<w:r\b[^>]*>.*?</w:r>)", document_xml, flags=re.S)
        text_tag = re.compile(r"(<w:t(?:\s[^>]*)?>)(.*?)(</w:t>)", re.S)

        def convert_run_text(match):
            opening, text, closing = match.groups()
            unicode_text = convert_text(html.unescape(text))
            return opening + html.escape(unicode_text, quote=False) + closing

        for i, piece in enumerate(pieces):
            if piece.startswith("<w:r") and any(f in piece for f in LEGACY_FONT_NAMES):
                pieces[i] = text_tag.sub(convert_run_text, piece)

        document_xml = "".join(pieces)
        for legacy_font in LEGACY_FONT_NAMES:
            document_xml = document_xml.replace(legacy_font, REPLACEMENT_FONT)

        # Write the new .docx: same files as the original, with our two
        # changed XML parts swapped in.
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.namelist():
                if item == "word/document.xml":
                    zout.writestr(item, document_xml)
                elif item == "word/styles.xml":
                    styles = zin.read(item).decode("utf-8")
                    for legacy_font in LEGACY_FONT_NAMES:
                        styles = styles.replace(legacy_font, REPLACEMENT_FONT)
                    zout.writestr(item, styles)
                else:
                    zout.writestr(item, zin.read(item))

    return target


def main():
    parser = argparse.ArgumentParser(description="Convert legacy TCRC .docx to Unicode.")
    parser.add_argument("path", help="a .docx file, or a folder with --batch")
    parser.add_argument("--batch", action="store_true", help="convert every .docx in the folder")
    args = parser.parse_args()

    path = Path(args.path)
    files = sorted(path.glob("*.docx")) if args.batch else [path]
    files = [f for f in files if "(Unicode)" not in f.name]

    if not files:
        sys.exit("No .docx files found.")

    for f in files:
        try:
            result = convert_docx(f)
            print(f"  converted: {f.name}  ->  {result.name}")
        except Exception as error:
            print(f"  FAILED:    {f.name}  ({error})")

    print(f"\nDone — {len(files)} file(s) processed.")
    print("Support this project: https://buymeacoffee.com/samchoe2002")


if __name__ == "__main__":
    main()
