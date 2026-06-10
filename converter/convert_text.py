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

HERE = Path(getattr(sys, "_MEIPASS", Path(__file__).parent))
TABLE = {
    int(cp): text
    for cp, text in json.loads(
        (HERE / "tcrc_to_unicode_map.json").read_text(encoding="utf-8")
    ).items()
}


def convert_text(legacy_text: str) -> str:
    converted = "".join(TABLE.get(ord(ch), ch) for ch in legacy_text)
    return unicodedata.normalize("NFC", converted)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(convert_text(" ".join(sys.argv[1:])))
    else:
        print(convert_text(sys.stdin.read()), end="")
