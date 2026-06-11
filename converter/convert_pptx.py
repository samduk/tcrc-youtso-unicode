"""
convert_pptx.py — turn old TCRC Youtso (legacy) PowerPoint files into Unicode.

Works exactly like convert_docx.py, but for .pptx files. PowerPoint stores
text in DrawingML runs:

    <a:r>
        <a:rPr ...> <a:latin typeface="TCRC Bod-Yig"/> ... </a:rPr>
        <a:t>the text</a:t>
    </a:r>

We convert the text of every run that uses a legacy TCRC font, then change
the font name to "TCRC Youtso Unicode". Slides, slide layouts, slide
masters, and notes pages are all processed.

HOW TO USE
----------
    python convert_pptx.py "my presentation.pptx"
    python convert_pptx.py "C:\\My Slides" --batch
"""

import argparse
import html
import re
import sys
import zipfile
from pathlib import Path

# reuse the conversion table and text converter from the docx module
from convert_docx import CONVERSION_TABLE, LEGACY_FONT_NAMES, convert_text

REPLACEMENT_FONT = "TCRC Youtso Unicode"

# One whole DrawingML run: from <a:r> to </a:r>.
RUN_PATTERN = re.compile(r"(?s)<a:r\b[^>]*>.*?</a:r>")

# The text inside a run: <a:t>text</a:t>.
TEXT_PATTERN = re.compile(r"(?s)(<a:t(?:\s[^>]*)?>)(.*?)(</a:t>)")

# The parts of a .pptx that contain slide text.
PART_PATTERN = re.compile(
    r"^ppt/(slides|slideLayouts|slideMasters|notesSlides|notesMasters)/[^/]+\.xml$")


def run_needs_conversion(run_xml):
    """Does this run contain legacy TCRC text?"""

    # Case 1: the run names one of the legacy fonts.
    for font_name in LEGACY_FONT_NAMES:
        if 'typeface="' + font_name + '"' in run_xml:
            return True

    # Case 2: the run uses the new font name, but legacy characters
    # are still inside the text (a re-fonted, unconverted run).
    if 'typeface="' + REPLACEMENT_FONT + '"' in run_xml:
        for match in TEXT_PATTERN.finditer(run_xml):
            plain_text = html.unescape(match.group(2))
            for character in plain_text:
                code = ord(character)
                # only 0xA0-0xFF characters are PROOF of legacy text
                # (em-dash etc. appear in normal English too)
                if 0xA0 <= code <= 0xFF and code in CONVERSION_TABLE:
                    return True

    return False


def convert_text_inside_run(match):
    opening_tag = match.group(1)
    text = match.group(2)
    closing_tag = match.group(3)

    plain_text = html.unescape(text)
    unicode_text = convert_text(plain_text)
    safe_text = html.escape(unicode_text, quote=False)

    return opening_tag + safe_text + closing_tag


def convert_part_xml(xml):
    """Convert one slide/layout/master/notes XML part."""
    pieces = []
    position = 0

    for match in RUN_PATTERN.finditer(xml):
        pieces.append(xml[position:match.start()])
        run = match.group(0)
        if run_needs_conversion(run):
            run = TEXT_PATTERN.sub(convert_text_inside_run, run)
        pieces.append(run)
        position = match.end()
    pieces.append(xml[position:])
    result = "".join(pieces)

    # rename the fonts (full quoted attribute, so "TCRC Youtso" cannot
    # wrongly match inside "TCRC Youtso Unicode")
    for font_name in LEGACY_FONT_NAMES:
        old_attribute = 'typeface="' + font_name + '"'
        new_attribute = 'typeface="' + REPLACEMENT_FONT + '"'
        result = result.replace(old_attribute, new_attribute)

    return result


def convert_pptx(source_path):
    """Convert one .pptx file. Returns the path of the new file."""
    new_name = source_path.stem + " (Unicode)" + source_path.suffix
    target_path = source_path.with_name(new_name)

    with zipfile.ZipFile(source_path) as source_zip:
        with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target_zip:
            for file_name in source_zip.namelist():
                content = source_zip.read(file_name)
                if PART_PATTERN.match(file_name):
                    xml = content.decode("utf-8")
                    xml = convert_part_xml(xml)
                    target_zip.writestr(file_name, xml)
                else:
                    target_zip.writestr(file_name, content)

    return target_path


def main():
    parser = argparse.ArgumentParser(
        description="Convert legacy TCRC .pptx files to Unicode.")
    parser.add_argument("path", help="a .pptx file, or a folder with --batch")
    parser.add_argument("--batch", action="store_true",
                        help="convert every .pptx file in the folder")
    arguments = parser.parse_args()

    path = Path(arguments.path)
    files_to_convert = []
    if arguments.batch:
        for file in sorted(path.glob("*.pptx")):
            if "(Unicode)" not in file.name:
                files_to_convert.append(file)
    else:
        files_to_convert.append(path)

    if len(files_to_convert) == 0:
        sys.exit("No .pptx files found.")

    for file in files_to_convert:
        try:
            result = convert_pptx(file)
            print("  converted: " + file.name + "  ->  " + result.name)
        except Exception as error:
            print("  FAILED:    " + file.name + "  (" + str(error) + ")")

    print("")
    print("Done — " + str(len(files_to_convert)) + " file(s) processed.")
    print("Support this project: https://buymeacoffee.com/samchoe2002")


if __name__ == "__main__":
    main()
