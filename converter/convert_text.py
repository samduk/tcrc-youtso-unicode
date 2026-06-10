"""
convert_text.py — convert a piece of legacy TCRC text to Unicode, right
in the terminal. Useful for small snippets, testing, or scripting.

HOW TO USE
----------
    python convert_text.py "ºGô-zXôhü"
    ->  འགོ་བརྗོད།

Or pipe a whole text file through it:

    python convert_text.py < old_text.txt > unicode_text.txt
"""

import json
import sys
import unicodedata
from pathlib import Path


def load_conversion_table():
    # Find the folder this script lives in.
    # (Inside a PyInstaller .exe the data file is unpacked to _MEIPASS.)
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


def convert_text(legacy_text):
    """Convert one string of legacy characters to Unicode Tibetan."""
    converted_pieces = []

    for character in legacy_text:
        character_code = ord(character)          # e.g. 'º' -> 186
        if character_code in CONVERSION_TABLE:
            converted_pieces.append(CONVERSION_TABLE[character_code])
        else:
            converted_pieces.append(character)

    converted = "".join(converted_pieces)

    # NFC normalization puts Tibetan vowel signs into the standard order.
    return unicodedata.normalize("NFC", converted)


if __name__ == "__main__":
    text_was_given_on_the_command_line = len(sys.argv) > 1

    if text_was_given_on_the_command_line:
        legacy_text = " ".join(sys.argv[1:])
        print(convert_text(legacy_text))
    else:
        legacy_text = sys.stdin.read()
        print(convert_text(legacy_text), end="")
