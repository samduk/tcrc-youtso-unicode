"""
convert_xlsx.py — turn old TCRC Youtso (legacy) Excel files into Unicode.

Excel stores almost all cell text in ONE shared file inside the .xlsx zip:
xl/sharedStrings.xml. A string is either plain:

    <si><t>the text</t></si>

or "rich" (with per-piece formatting):

    <si><r><rPr><rFont val="TCRC Bod-Yig"/>...</rPr><t>the text</t></r></si>

Which font a PLAIN string uses is stored far away (in the cell's style), so
for plain strings we use a content test instead: if the text contains
non-ASCII characters from the legacy encoding (like ô, ¾, º — which real
English text essentially never contains), it is legacy text and is converted.

Font names in xl/styles.xml are renamed to "TCRC Youtso Unicode".

HOW TO USE
----------
    python convert_xlsx.py "my workbook.xlsx"
    python convert_xlsx.py "C:\\My Sheets" --batch
"""

import argparse
import html
import re
import sys
import zipfile
from pathlib import Path

from convert_docx import CONVERSION_TABLE, LEGACY_FONT_NAMES, convert_text

REPLACEMENT_FONT = "TCRC Youtso Unicode"

# One rich-text run inside a shared string: <r>...</r>.
RUN_PATTERN = re.compile(r"(?s)<r\b[^>]*>.*?</r>")

# Text elements: <t>text</t> (sometimes with attributes like xml:space).
TEXT_PATTERN = re.compile(r"(?s)(<t(?:\s[^>]*)?>)(.*?)(</t>)")


def text_is_legacy(plain_text):
    """Does this text contain unmistakably-legacy characters?

    Only characters in the 0xA0-0xFF range count as proof (ô, ¾, º, Û...).
    Characters like the em-dash (U+2014) are also in the conversion table,
    but they appear in normal English text too, so they alone must never
    trigger a conversion.
    """
    for character in plain_text:
        code = ord(character)
        if 0xA0 <= code <= 0xFF and code in CONVERSION_TABLE:
            return True
    return False


def run_names_legacy_font(run_xml):
    for font_name in LEGACY_FONT_NAMES:
        if 'val="' + font_name + '"' in run_xml:
            return True
    return False


def convert_text_inside(match):
    opening_tag = match.group(1)
    text = match.group(2)
    closing_tag = match.group(3)

    plain_text = html.unescape(text)
    unicode_text = convert_text(plain_text)
    safe_text = html.escape(unicode_text, quote=False)

    return opening_tag + safe_text + closing_tag


def convert_shared_strings_xml(xml):
    """Convert xl/sharedStrings.xml."""

    def convert_one_text(match):
        plain_text = html.unescape(match.group(2))
        if text_is_legacy(plain_text):
            return convert_text_inside(match)
        return match.group(0)

    pieces = []
    position = 0

    # First: rich runs. A run that NAMES a legacy font is converted even if
    # its text happens to be pure ASCII.
    for match in RUN_PATTERN.finditer(xml):
        pieces.append(xml[position:match.start()])
        run = match.group(0)
        if run_names_legacy_font(run):
            run = TEXT_PATTERN.sub(convert_text_inside, run)
        else:
            run = TEXT_PATTERN.sub(convert_one_text, run)
        pieces.append(run)
        position = match.end()
    pieces.append(xml[position:])
    result = "".join(pieces)

    # Second: plain strings (the <t> elements OUTSIDE runs were untouched
    # above only if they sat between runs; process the whole result again
    # with the content test — already-converted text contains no legacy
    # characters, so this is safe).
    result = TEXT_PATTERN.sub(convert_one_text, result)

    # rename fonts in run properties
    for font_name in LEGACY_FONT_NAMES:
        result = result.replace('val="' + font_name + '"',
                                'val="' + REPLACEMENT_FONT + '"')
    return result


def convert_xlsx(source_path):
    """Convert one .xlsx file. Returns the path of the new file."""
    new_name = source_path.stem + " (Unicode)" + source_path.suffix
    target_path = source_path.with_name(new_name)

    with zipfile.ZipFile(source_path) as source_zip:
        with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target_zip:
            for file_name in source_zip.namelist():
                content = source_zip.read(file_name)

                if file_name == "xl/sharedStrings.xml":
                    xml = content.decode("utf-8")
                    target_zip.writestr(file_name, convert_shared_strings_xml(xml))

                elif file_name == "xl/styles.xml":
                    xml = content.decode("utf-8")
                    for font_name in LEGACY_FONT_NAMES:
                        xml = xml.replace('val="' + font_name + '"',
                                          'val="' + REPLACEMENT_FONT + '"')
                    target_zip.writestr(file_name, xml)

                else:
                    target_zip.writestr(file_name, content)

    return target_path


def main():
    parser = argparse.ArgumentParser(
        description="Convert legacy TCRC .xlsx files to Unicode.")
    parser.add_argument("path", help="an .xlsx file, or a folder with --batch")
    parser.add_argument("--batch", action="store_true",
                        help="convert every .xlsx file in the folder")
    arguments = parser.parse_args()

    path = Path(arguments.path)
    files_to_convert = []
    if arguments.batch:
        for file in sorted(path.glob("*.xlsx")):
            if "(Unicode)" not in file.name:
                files_to_convert.append(file)
    else:
        files_to_convert.append(path)

    if len(files_to_convert) == 0:
        sys.exit("No .xlsx files found.")

    for file in files_to_convert:
        try:
            result = convert_xlsx(file)
            print("  converted: " + file.name + "  ->  " + result.name)
        except Exception as error:
            print("  FAILED:    " + file.name + "  (" + str(error) + ")")

    print("")
    print("Done — " + str(len(files_to_convert)) + " file(s) processed.")
    print("Support this project: https://buymeacoffee.com/samchoe2002")


if __name__ == "__main__":
    main()
