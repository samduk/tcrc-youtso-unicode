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
# STEP 1: load the conversion table.
#
# The table says, for every legacy character code, which Unicode Tibetan
# text it really means. For example code 186 (the character 'º') means འ.
# The table was built by visually matching every glyph of the old font with
# the Unicode font — see tools/build_mapping.py for the full story.
# ---------------------------------------------------------------------------

def load_conversion_table():
    # Find the folder this script lives in.
    # (When the script is packed into an .exe by PyInstaller, the data file
    #  is unpacked to a temporary folder that PyInstaller calls _MEIPASS.)
    if hasattr(sys, "_MEIPASS"):
        folder = Path(sys._MEIPASS)
    else:
        folder = Path(__file__).parent

    table_file = folder / "tcrc_to_unicode_map.json"
    file_content = table_file.read_text(encoding="utf-8")
    raw_table = json.loads(file_content)

    # JSON keys are text like "186" — turn them into numbers like 186.
    table = {}
    for key_text, unicode_text in raw_table.items():
        key_number = int(key_text)
        table[key_number] = unicode_text
    return table


CONVERSION_TABLE = load_conversion_table()

# Font names that old documents use. If you ever find a document with another
# TCRC legacy font name, just add it to this list.
LEGACY_FONT_NAMES = ["TCRC Bod-Yig", "TCRC Youtsoweb", "TCRC Youtso"]

# Every Windows computer has this Unicode Tibetan font built in,
# so converted documents display correctly everywhere.
REPLACEMENT_FONT = "Microsoft Himalaya"


# ---------------------------------------------------------------------------
# STEP 2: converting text, one character at a time.
# ---------------------------------------------------------------------------

def convert_text(legacy_text):
    """Convert one string of legacy characters to Unicode Tibetan."""
    converted_pieces = []

    for character in legacy_text:
        character_code = ord(character)          # e.g. 'º' -> 186
        if character_code in CONVERSION_TABLE:
            converted_pieces.append(CONVERSION_TABLE[character_code])
        else:
            # Not a legacy Tibetan character (a space, a digit, ...):
            # keep it exactly as it is.
            converted_pieces.append(character)

    converted = "".join(converted_pieces)

    # NFC normalization puts Tibetan vowel signs into the standard order.
    return unicodedata.normalize("NFC", converted)


# ---------------------------------------------------------------------------
# STEP 3: converting one .docx file.
#
# A .docx file is secretly a ZIP archive full of XML text files. The actual
# words live in word/document.xml, inside "runs". A run looks like this:
#
#   <w:r>  <w:rPr>...font name...</w:rPr>  <w:t>the text</w:t>  </w:r>
#
# We only touch runs whose font is a legacy TCRC font, so English text and
# everything else stays untouched.
# ---------------------------------------------------------------------------

# This pattern finds one whole run: from <w:r ...> up to </w:r>.
RUN_PATTERN = re.compile(r"(<w:r\b[^>]*>.*?</w:r>)", re.DOTALL)

# This pattern finds the text inside a run: <w:t ...>text</w:t>.
# It captures three parts: the opening tag, the text, the closing tag.
TEXT_PATTERN = re.compile(r"(<w:t(?:\s[^>]*)?>)(.*?)(</w:t>)", re.DOTALL)


def run_uses_legacy_font(run_xml):
    """Does this run use one of the old TCRC fonts?"""
    for font_name in LEGACY_FONT_NAMES:
        if font_name in run_xml:
            return True
    return False


def convert_text_inside_run(match):
    """Called for every <w:t>text</w:t> found inside a legacy run."""
    opening_tag = match.group(1)
    text = match.group(2)
    closing_tag = match.group(3)

    # XML stores some characters in a special way (& becomes &amp; etc.).
    # Decode that first, convert, then encode again.
    plain_text = html.unescape(text)
    unicode_text = convert_text(plain_text)
    safe_text = html.escape(unicode_text, quote=False)

    return opening_tag + safe_text + closing_tag


def convert_docx(source_path):
    """Convert one .docx file. Returns the path of the new file."""
    new_name = source_path.stem + " (Unicode)" + source_path.suffix
    target_path = source_path.with_name(new_name)

    with zipfile.ZipFile(source_path) as source_zip:

        # --- read and convert the main document XML -----------------------
        document_xml = source_zip.read("word/document.xml").decode("utf-8")

        # Split the XML into pieces: runs and everything between runs.
        # (Because RUN_PATTERN has capturing parentheses, re.split keeps
        #  the runs in the result instead of throwing them away.)
        pieces = re.split(RUN_PATTERN, document_xml)

        converted_pieces = []
        for piece in pieces:
            is_a_run = piece.startswith("<w:r")
            if is_a_run and run_uses_legacy_font(piece):
                converted_piece = TEXT_PATTERN.sub(convert_text_inside_run, piece)
                converted_pieces.append(converted_piece)
            else:
                converted_pieces.append(piece)

        document_xml = "".join(converted_pieces)

        # The text is Unicode now — also change the font name everywhere.
        for font_name in LEGACY_FONT_NAMES:
            document_xml = document_xml.replace(font_name, REPLACEMENT_FONT)

        # --- write the new .docx ------------------------------------------
        # Copy every file from the original zip; swap in our two changed
        # XML files along the way.
        with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target_zip:
            for file_name in source_zip.namelist():

                if file_name == "word/document.xml":
                    target_zip.writestr(file_name, document_xml)

                elif file_name == "word/styles.xml":
                    styles_xml = source_zip.read(file_name).decode("utf-8")
                    for font_name in LEGACY_FONT_NAMES:
                        styles_xml = styles_xml.replace(font_name, REPLACEMENT_FONT)
                    target_zip.writestr(file_name, styles_xml)

                else:
                    original_content = source_zip.read(file_name)
                    target_zip.writestr(file_name, original_content)

    return target_path


# ---------------------------------------------------------------------------
# STEP 4: the command line interface.
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convert legacy TCRC .docx files to Unicode.")
    parser.add_argument("path",
                        help="a .docx file, or a folder if you use --batch")
    parser.add_argument("--batch", action="store_true",
                        help="convert every .docx file in the folder")
    arguments = parser.parse_args()

    path = Path(arguments.path)

    # Build the list of files to convert.
    files_to_convert = []
    if arguments.batch:
        for file in sorted(path.glob("*.docx")):
            already_converted = "(Unicode)" in file.name
            if not already_converted:
                files_to_convert.append(file)
    else:
        files_to_convert.append(path)

    if len(files_to_convert) == 0:
        sys.exit("No .docx files found.")

    for file in files_to_convert:
        try:
            result = convert_docx(file)
            print("  converted: " + file.name + "  ->  " + result.name)
        except Exception as error:
            print("  FAILED:    " + file.name + "  (" + str(error) + ")")

    print("")
    print("Done — " + str(len(files_to_convert)) + " file(s) processed.")
    print("Support this project: https://buymeacoffee.com/samchoe2002")


if __name__ == "__main__":
    main()
