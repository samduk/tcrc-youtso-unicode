import importlib.util
import shutil
import subprocess
import tempfile
import unittest
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

from fontTools.ttLib import TTFont


REPO_ROOT = Path(__file__).resolve().parents[1]
CONVERTER_PATH = REPO_ROOT / "converter" / "convert_docx.py"
AHK_PATH = REPO_ROOT / "keyboard" / "TCRC-Tibetan-Unicode-Keyboard.ahk"
GUI_PATH = REPO_ROOT / "converter" / "TCRC-Document-Converter.ahk"
CONTROLLER_PATH = REPO_ROOT / "converter" / "convert-document.ps1"
MAIN_FONT_PATH = REPO_ROOT / "fonts" / "TCRC-Youtso-Unicode-fixed.ttf"

spec = importlib.util.spec_from_file_location("convert_docx", CONVERTER_PATH)
converter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)


def legacy_run(text, font="TCRC Youtso"):
    return (
        '<w:r><w:rPr><w:rFonts w:ascii="' + font + '"/></w:rPr>'
        "<w:t>" + text + "</w:t></w:r>"
    )


def story_xml(body):
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/'
        'wordprocessingml/2006/main"><w:body>'
        + body
        + "</w:body></w:document>"
    )


def write_test_docx(path, legacy_text):
    story_parts = [
        "word/document.xml",
        "word/header1.xml",
        "word/footer1.xml",
        "word/footnotes.xml",
        "word/endnotes.xml",
        "word/comments.xml",
    ]
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for part_name in story_parts:
            run = legacy_run(legacy_text)
            if part_name == "word/document.xml":
                run = (
                    "<w:p><w:r><w:t>before</w:t></w:r>"
                    "<w:txbxContent><w:p>"
                    + run
                    + "</w:p></w:txbxContent></w:p>"
                )
            archive.writestr(part_name, story_xml(run))
        archive.writestr(
            "word/styles.xml",
            '<w:styles xmlns:w="x"><w:rFonts w:ascii="TCRC Youtso"/>'
            "</w:styles>",
        )
        archive.writestr("customXml/item1.xml", legacy_run(legacy_text))
    return story_parts


class ConverterTests(unittest.TestCase):
    def test_converts_every_word_story_and_text_box(self):
        # Include the reported fraction plus rarer cp1252 characters.
        legacy_text = "¼ƒ„‰ˆ—Ÿ"
        expected = converter.convert_text(legacy_text)
        story_parts = [
            "word/document.xml",
            "word/header1.xml",
            "word/footer1.xml",
            "word/footnotes.xml",
            "word/endnotes.xml",
            "word/comments.xml",
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            source = Path(temp_dir) / "legacy.docx"
            write_test_docx(source, legacy_text)

            target = converter.convert_docx(source)

            with zipfile.ZipFile(target) as archive:
                for part_name in story_parts:
                    converted_xml = archive.read(part_name).decode("utf-8")
                    self.assertIn(expected, converted_xml, part_name)
                    self.assertNotIn(legacy_text, converted_xml, part_name)
                    self.assertIn("TCRC Youtso Unicode", converted_xml, part_name)
                    ET.fromstring(converted_xml)

                styles_xml = archive.read("word/styles.xml").decode("utf-8")
                self.assertIn("TCRC Youtso Unicode", styles_xml)

                untouched_xml = archive.read("customXml/item1.xml").decode("utf-8")
                self.assertIn(legacy_text, untouched_xml)

    def test_finishes_partially_converted_unicode_font_run(self):
        # The high character triggers conversion; ASCII legacy glyphs in the
        # same run must be completed too.
        legacy_text = "G¼ƒ„‰ˆ—Ÿ"
        run = legacy_run(legacy_text, font="TCRC Youtso Unicode")
        converted_xml = converter.convert_story_xml(story_xml(run))

        self.assertIn(converter.convert_text(legacy_text), converted_xml)
        self.assertNotIn(legacy_text, converted_xml)

    def test_plain_ascii_in_unicode_font_is_not_reinterpreted(self):
        run = legacy_run("Normal English text", font="TCRC Youtso Unicode")
        original_xml = story_xml(run)

        self.assertEqual(converter.convert_story_xml(original_xml), original_xml)

    def test_non_tcrc_high_punctuation_is_not_reinterpreted(self):
        run = legacy_run("English ¼ — text", font="Arial")
        original_xml = story_xml(run)

        self.assertEqual(converter.convert_story_xml(original_xml), original_xml)

    def test_keyboard_is_not_coupled_to_document_conversion(self):
        ahk_text = AHK_PATH.read_text(encoding="utf-8")
        self.assertIn("^!t::ToggleTibetan()", ahk_text)
        self.assertIn("ApplyUnicodeFont()", ahk_text)
        self.assertIn("EnsureUnicodeFont()", ahk_text)
        self.assertIn('ComObjActive("Word.Application")', ahk_text)
        self.assertIn('ComObjActive("Excel.Application")', ahk_text)
        self.assertIn('ComObjActive("PowerPoint.Application")', ahk_text)
        self.assertIn("word.Selection.Font.NameBi := UnicodeFont", ahk_text)
        self.assertIn("EnsureUnicodeFont()\n    SendText text", ahk_text)
        self.assertNotIn("SetTimer", ahk_text)
        self.assertNotIn("LegacyMap", ahk_text)
        self.assertNotIn("convert-docx.ps1", ahk_text)
        self.assertLess(len(ahk_text.splitlines()), 350)

    def test_excel_number_mode_is_explicit(self):
        ahk_text = AHK_PATH.read_text(encoding="utf-8")

        self.assertIn("^!n::FormatExcelNumberCells()", ahk_text)
        self.assertIn('WinActive("ahk_exe EXCEL.EXE")', ahk_text)
        self.assertIn("TCRC Youtso Unicode", ahk_text)
        self.assertIn('TypeDigit("1", 0x0F21)', ahk_text)

    def test_main_font_draws_ascii_digits_as_tibetan(self):
        cmap = TTFont(MAIN_FONT_PATH).getBestCmap()

        for digit in range(10):
            ascii_codepoint = ord("0") + digit
            tibetan_codepoint = 0x0F20 + digit
            self.assertEqual(
                cmap[ascii_codepoint],
                cmap[tibetan_codepoint],
            )

    def test_converter_ui_is_explicit_and_preserves_the_source(self):
        gui_text = GUI_PATH.read_text(encoding="utf-8")
        self.assertIn("Convert to Unicode", gui_text)
        self.assertIn("original document is never changed", gui_text)
        self.assertIn("convert-document.ps1", gui_text)
        self.assertNotIn("ComObjActive", gui_text)
        self.assertNotIn("SetTimer", gui_text)

    def test_document_controller_reports_success(self):
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell is None:
            self.skipTest("PowerShell is not installed")

        legacy_text = "¼ƒ„‰ˆ—Ÿ"
        with tempfile.TemporaryDirectory() as temp_dir:
            source = Path(temp_dir) / "legacy.docx"
            status_file = Path(temp_dir) / "status.txt"
            write_test_docx(source, legacy_text)

            subprocess.run(
                [
                    powershell,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(CONTROLLER_PATH),
                    "-Path",
                    str(source),
                    "-StatusFile",
                    str(status_file),
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            target = Path(temp_dir) / "legacy (Unicode).docx"
            self.assertTrue(target.exists())
            status = status_file.read_text(encoding="utf-8")
            self.assertEqual(status.splitlines()[0], "OK")
            self.assertEqual(Path(status.splitlines()[1]), target)
            self.assertTrue(source.exists())

    def test_controller_does_not_replace_output_when_conversion_fails(self):
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell is None:
            self.skipTest("PowerShell is not installed")

        with tempfile.TemporaryDirectory() as temp_dir:
            source = Path(temp_dir) / "broken.docx"
            target = Path(temp_dir) / "broken (Unicode).docx"
            status_file = Path(temp_dir) / "status.txt"
            source.write_bytes(b"not a Word document")
            target.write_bytes(b"known-good-output")

            result = subprocess.run(
                [
                    powershell,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(CONTROLLER_PATH),
                    "-Path",
                    str(source),
                    "-StatusFile",
                    str(status_file),
                ],
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_bytes(), b"known-good-output")
            self.assertEqual(
                status_file.read_text(encoding="utf-8").splitlines()[0],
                "ERROR",
            )

    def test_powershell_converter_matches_python_converter(self):
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell is None:
            self.skipTest("PowerShell is not installed")

        legacy_text = "¼ƒ„‰ˆ—Ÿ"
        with tempfile.TemporaryDirectory() as temp_dir:
            python_source = Path(temp_dir) / "python.docx"
            powershell_source = Path(temp_dir) / "powershell.docx"
            story_parts = write_test_docx(python_source, legacy_text)
            shutil.copyfile(python_source, powershell_source)

            python_target = converter.convert_docx(python_source)
            subprocess.run(
                [
                    powershell,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(REPO_ROOT / "converter" / "convert-docx.ps1"),
                    "-Path",
                    str(powershell_source),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            powershell_target = Path(temp_dir) / "powershell (Unicode).docx"

            with (
                zipfile.ZipFile(python_target) as python_zip,
                zipfile.ZipFile(powershell_target) as powershell_zip,
            ):
                for part_name in story_parts + ["word/styles.xml"]:
                    self.assertEqual(
                        python_zip.read(part_name),
                        powershell_zip.read(part_name),
                        part_name,
                    )


if __name__ == "__main__":
    unittest.main()
