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
import io
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

# reuse the conversion table and text converter from the docx module
from convert_docx import CONVERSION_TABLE, LEGACY_FONT_NAMES, convert_text

REPLACEMENT_FONT = "TCRC Youtso Unicode"

A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
NS = {"a": A_NS}

# The parts of a .pptx that contain slide text.
PART_PATTERN = re.compile(
    r"^ppt/(slides|slideLayouts|slideMasters|notesSlides|notesMasters)/[^/]+\.xml$")


def register_namespaces(xml):
    """Preserve the document's existing namespace prefixes."""
    for _, namespace in ET.iterparse(io.StringIO(xml), events=("start-ns",)):
        prefix, uri = namespace
        ET.register_namespace(prefix or "", uri)


def font_from_properties(properties):
    """Return the Latin/complex-script font named by DrawingML properties."""
    if properties is None:
        return None
    for tag_name in ("latin", "cs", "ea"):
        font = properties.find("a:" + tag_name, NS)
        if font is not None and font.get("typeface"):
            return font.get("typeface")
    return None


def text_has_legacy_signature(text):
    """Detect re-fonted legacy text without treating normal punctuation as proof."""
    return any(
        0xA0 <= ord(character) <= 0xFF
        and ord(character) in CONVERSION_TABLE
        for character in text
    )


def text_looks_legacy_without_font(text):
    """Conservative fallback when the font is inherited from another part."""
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


def paragraph_default_font(paragraph, parent_map):
    """Resolve the run font inherited from paragraph/list defaults."""
    paragraph_properties = paragraph.find("a:pPr", NS)
    if paragraph_properties is not None:
        font = font_from_properties(paragraph_properties.find("a:defRPr", NS))
        if font:
            return font
        level = int(paragraph_properties.get("lvl", "0"))
    else:
        level = 0

    parent = parent_map.get(paragraph)
    while parent is not None and parent.tag != "{" + A_NS + "}txBody":
        parent = parent_map.get(parent)
    if parent is None:
        return None

    list_style = parent.find("a:lstStyle", NS)
    if list_style is None:
        return None
    level_properties = list_style.find(
        "a:lvl" + str(level + 1) + "pPr", NS
    )
    if level_properties is None:
        return None
    return font_from_properties(level_properties.find("a:defRPr", NS))


def convert_part_xml(xml):
    """Convert one slide/layout/master/notes XML part."""
    register_namespaces(xml)
    root = ET.fromstring(xml)
    parent_map = {child: parent for parent in root.iter() for child in parent}

    for paragraph in root.findall(".//a:p", NS):
        inherited_font = paragraph_default_font(paragraph, parent_map)
        for run in paragraph.findall("a:r", NS):
            run_properties = run.find("a:rPr", NS)
            run_font = font_from_properties(run_properties) or inherited_font
            text_nodes = run.findall("a:t", NS)
            run_text = "".join(node.text or "" for node in text_nodes)

            should_convert = run_font in LEGACY_FONT_NAMES
            if run_font == REPLACEMENT_FONT and text_has_legacy_signature(run_text):
                should_convert = True
            if run_font is None and text_looks_legacy_without_font(run_text):
                should_convert = True

            if should_convert:
                for text_node in text_nodes:
                    text_node.text = convert_text(text_node.text or "")

    for element in root.iter():
        if element.get("typeface") in LEGACY_FONT_NAMES:
            element.set("typeface", REPLACEMENT_FONT)

    return ET.tostring(root, encoding="unicode")


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
