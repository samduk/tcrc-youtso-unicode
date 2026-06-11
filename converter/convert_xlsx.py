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
import copy
import io
import sys
import zipfile
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

from convert_docx import CONVERSION_TABLE, LEGACY_FONT_NAMES, convert_text

REPLACEMENT_FONT = "TCRC Youtso Unicode"

S_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS = {"s": S_NS}


def register_namespaces(xml):
    """Preserve the document's existing namespace prefixes."""
    for _, namespace in ET.iterparse(io.StringIO(xml), events=("start-ns",)):
        prefix, uri = namespace
        ET.register_namespace(prefix or "", uri)


def text_has_legacy_signature(text):
    """Conservative fallback for cells whose style does not name a font."""
    mapped_high_characters = sum(
        1
        for character in text
        if 0xA0 <= ord(character) <= 0xFF
        and ord(character) in CONVERSION_TABLE
    )
    if mapped_high_characters < 2:
        return False
    non_space_length = sum(1 for character in text if not character.isspace())
    return mapped_high_characters * 2 >= max(non_space_length, 1)


def text_has_any_legacy_character(text):
    """Used when the run's font is already TCRC Youtso Unicode.

    In that situation we KNOW the text is Tibetan, so even a single
    leftover legacy character (for example a stray ¼ from an earlier,
    partial conversion) is enough proof.
    """
    for character in text:
        code = ord(character)
        if 0xA0 <= code <= 0xFF and code in CONVERSION_TABLE:
            return True
    return False


def font_name(properties):
    if properties is None:
        return None
    font = properties.find("s:rFont", NS)
    return None if font is None else font.get("val")


def text_is_numeric_only(text):
    """Is this text just a number, like ' 644,936.00 ' or '2023-24'?"""
    has_digit = False
    for character in text:
        if character.isdigit():
            has_digit = True
        elif character not in " .,-+%/()' ":
            return False
    return has_digit


def convert_digits_to_tibetan(text):
    """Turn western digits into Tibetan digits, leave everything else."""
    converted_pieces = []
    for character in text:
        if "0" <= character <= "9":
            converted_pieces.append(chr(0x0F20 + int(character)))
        else:
            converted_pieces.append(character)
    return "".join(converted_pieces)


def text_is_probable_latin_text(text):
    """Recognize clear Latin prose without hiding short legacy codes.

    Legacy TCRC text can be entirely ASCII, so a single letter plus a digit is
    not enough evidence that a value is an English address. Require at least
    two multi-letter Latin words before preserving mixed letter/digit text.
    """
    latin_words = []
    current_word = []
    for character in text:
        if character.isascii() and character.isalpha():
            current_word.append(character)
        else:
            if len(current_word) >= 2:
                latin_words.append("".join(current_word))
            current_word = []
    if len(current_word) >= 2:
        latin_words.append("".join(current_word))
    return len(latin_words) >= 2


def conversion_mode(text):
    """Decide HOW a legacy-context string should be converted.

    "full"   - real legacy Tibetan text: convert every character.
    "digits" - a pure number (a price, a year): only the digits become
               Tibetan; commas and decimal points stay where they are.
    "none"   - clear Latin prose containing digits, like an address
               ("V.J. Enterprises, NH -21, HP 175021"): leave untouched.
    """
    if text_has_any_legacy_character(text):
        return "full"
    if text_is_numeric_only(text):
        return "digits"
    has_digit = any(character.isdigit() for character in text)
    if has_digit and text_is_probable_latin_text(text):
        return "none"
    return "full"


def convert_by_mode(text, mode):
    if mode == "full":
        return convert_text(text)
    if mode == "digits":
        return convert_digits_to_tibetan(text)
    return text


def convert_string_container(container, force=False, allow_fallback=False):
    """Convert one shared or inline string using run and cell font metadata."""
    rich_runs = container.findall("s:r", NS)
    if rich_runs:
        for run in rich_runs:
            properties = run.find("s:rPr", NS)
            run_font = font_name(properties)
            text = "".join(node.text or "" for node in run.findall("s:t", NS))
            should_convert = run_font in LEGACY_FONT_NAMES
            if run_font == REPLACEMENT_FONT and text_has_any_legacy_character(text):
                should_convert = True
            if run_font is None and force:
                should_convert = True
            if run_font is None and allow_fallback and text_has_legacy_signature(text):
                should_convert = True

            if should_convert:
                mode = conversion_mode(text)
                for text_node in run.findall("s:t", NS):
                    text_node.text = convert_by_mode(text_node.text or "", mode)
            if properties is not None:
                font = properties.find("s:rFont", NS)
                if font is not None and font.get("val") in LEGACY_FONT_NAMES:
                    font.set("val", REPLACEMENT_FONT)
        return

    text_nodes = container.findall("s:t", NS)
    text = "".join(node.text or "" for node in text_nodes)
    if force or (allow_fallback and text_has_legacy_signature(text)):
        mode = conversion_mode(text)
        for text_node in text_nodes:
            text_node.text = convert_by_mode(text_node.text or "", mode)


def style_font_flags(styles_xml):
    """Return one legacy-font flag per cell style: True, False, or None."""
    if styles_xml is None:
        return []
    register_namespaces(styles_xml)
    root = ET.fromstring(styles_xml)
    fonts = root.find("s:fonts", NS)
    font_flags = []
    if fonts is not None:
        for font in fonts.findall("s:font", NS):
            name = font.find("s:name", NS)
            value = None if name is None else name.get("val")
            if value in LEGACY_FONT_NAMES:
                font_flags.append(True)
            elif value:
                font_flags.append(False)
            else:
                font_flags.append(None)

    style_flags = []
    cell_formats = root.find("s:cellXfs", NS)
    if cell_formats is not None:
        for cell_format in cell_formats.findall("s:xf", NS):
            try:
                font_id = int(cell_format.get("fontId", "0"))
                style_flags.append(font_flags[font_id])
            except (ValueError, IndexError):
                style_flags.append(None)
    return style_flags


def cell_uses_legacy_font(cell, style_flags):
    try:
        style_id = int(cell.get("s", "0"))
        return style_flags[style_id]
    except (ValueError, IndexError):
        return None


def rename_style_fonts(styles_xml):
    if styles_xml is None:
        return None
    register_namespaces(styles_xml)
    root = ET.fromstring(styles_xml)
    for name in root.findall(".//s:name", NS):
        if name.get("val") in LEGACY_FONT_NAMES:
            name.set("val", REPLACEMENT_FONT)
    return ET.tostring(root, encoding="unicode")


def convert_shared_strings_xml(xml, legacy_indices=None, unknown_indices=None):
    """Convert shared strings selected through worksheet style metadata."""
    register_namespaces(xml)
    root = ET.fromstring(xml)
    legacy_indices = set() if legacy_indices is None else set(legacy_indices)
    unknown_indices = set() if unknown_indices is None else set(unknown_indices)

    for index, shared_string in enumerate(root.findall("s:si", NS)):
        convert_string_container(
            shared_string,
            force=index in legacy_indices,
            allow_fallback=index in unknown_indices,
        )

    return ET.tostring(root, encoding="unicode")


def convert_xlsx(source_path):
    """Convert one .xlsx file. Returns the path of the new file."""
    new_name = source_path.stem + " (Unicode)" + source_path.suffix
    target_path = source_path.with_name(new_name)

    with zipfile.ZipFile(source_path) as source_zip:
        contents = {
            file_name: source_zip.read(file_name)
            for file_name in source_zip.namelist()
        }

    styles_name = "xl/styles.xml"
    styles_xml = (
        contents[styles_name].decode("utf-8")
        if styles_name in contents
        else None
    )
    style_flags = style_font_flags(styles_xml)

    shared_name = "xl/sharedStrings.xml"
    shared_root = None
    if shared_name in contents:
        shared_xml = contents[shared_name].decode("utf-8")
        register_namespaces(shared_xml)
        shared_root = ET.fromstring(shared_xml)

    shared_references = defaultdict(lambda: {True: [], False: [], None: []})
    worksheet_roots = {}
    worksheet_names = [
        name
        for name in contents
        if name.startswith("xl/worksheets/") and name.endswith(".xml")
    ]

    for worksheet_name in worksheet_names:
        worksheet_xml = contents[worksheet_name].decode("utf-8")
        register_namespaces(worksheet_xml)
        worksheet = ET.fromstring(worksheet_xml)
        worksheet_roots[worksheet_name] = worksheet

        for cell in worksheet.findall(".//s:c", NS):
            legacy_flag = cell_uses_legacy_font(cell, style_flags)
            if cell.get("t") == "s":
                value = cell.find("s:v", NS)
                if value is not None and value.text is not None:
                    try:
                        index = int(value.text)
                    except ValueError:
                        continue
                    shared_references[index][legacy_flag].append(value)
            elif cell.get("t") == "inlineStr":
                inline_string = cell.find("s:is", NS)
                if inline_string is not None:
                    convert_string_container(
                        inline_string,
                        force=legacy_flag is True,
                        allow_fallback=legacy_flag is None,
                    )

    if shared_root is not None:
        shared_strings = shared_root.findall("s:si", NS)
        for index, shared_string in enumerate(shared_strings):
            references = shared_references[index]
            legacy_refs = references[True]
            other_refs = references[False] + references[None]

            if legacy_refs and other_refs:
                converted_copy = copy.deepcopy(shared_string)
                convert_string_container(converted_copy, force=True)
                shared_root.append(converted_copy)
                new_index = len(shared_root.findall("s:si", NS)) - 1
                for value in legacy_refs:
                    value.text = str(new_index)
                convert_string_container(
                    shared_string,
                    allow_fallback=bool(references[None]) and not references[False],
                )
            else:
                convert_string_container(
                    shared_string,
                    force=bool(legacy_refs),
                    allow_fallback=bool(references[None]),
                )

        shared_root.set(
            "uniqueCount", str(len(shared_root.findall("s:si", NS)))
        )
        contents[shared_name] = ET.tostring(shared_root, encoding="utf-8")

    for worksheet_name, worksheet in worksheet_roots.items():
        contents[worksheet_name] = ET.tostring(worksheet, encoding="utf-8")

    if styles_xml is not None:
        contents[styles_name] = rename_style_fonts(styles_xml).encode("utf-8")

    with zipfile.ZipFile(target_path, "w", zipfile.ZIP_DEFLATED) as target_zip:
        for file_name, content in contents.items():
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
