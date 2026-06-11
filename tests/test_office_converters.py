"""Tests for the PowerPoint and Excel converters."""

import html
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "converter"))

from convert_pptx import convert_part_xml, convert_pptx  # noqa: E402
from convert_xlsx import convert_xlsx          # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[1]
PPTX_POWERSHELL = REPO_ROOT / "converter" / "convert-pptx.ps1"
XLSX_POWERSHELL = REPO_ROOT / "converter" / "convert-xlsx.ps1"

SLIDE_XML = """<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody>
<a:p><a:r><a:rPr lang="en-US"><a:latin typeface="TCRC Bod-Yig"/></a:rPr><a:t>zôh-ˆÛ-¾ô-MãÅ</a:t></a:r></a:p>
<a:p><a:r><a:rPr lang="en-US"><a:latin typeface="Arial"/></a:rPr><a:t>English stays (A) 1/4</a:t></a:r></a:p>
<a:p><a:r><a:rPr lang="en-US"><a:latin typeface="TCRC Youtso Unicode"/></a:rPr><a:t>z¼-z;º-ÁG</a:t></a:r></a:p>
</p:txBody></p:sp></p:spTree></p:cSld></p:sld>"""

SHARED_STRINGS_XML = """<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<si><t>zôh-¾ô-MãÅ</t></si>
<si><t>Plain English text</t></si>
<si><r><rPr><rFont val="TCRC Bod-Yig"/></rPr><t>hq¾-º‚ô¼</t></r><r><rPr><rFont val="Arial"/></rPr><t> (B)</t></r></si>
<si><t>Total — 100% “done”</t></si>
<si><t>café résumé</t></si>
<si><t>G-M 2024</t></si>
<si><t>zôh-¾ô-MãÅ</t></si>
</sst>"""

STYLES_XML = """<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="2">
  <font><name val="TCRC Bod-Yig"/></font>
  <font><name val="Arial"/></font>
</fonts>
<cellXfs count="2">
  <xf fontId="0"/>
  <xf fontId="1"/>
</cellXfs>
</styleSheet>"""

WORKSHEET_XML = """<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
<row r="1">
  <c r="A1" t="s" s="0"><v>0</v></c>
  <c r="A2" t="s" s="1"><v>1</v></c>
  <c r="A3" t="s" s="1"><v>2</v></c>
  <c r="A4" t="s" s="1"><v>3</v></c>
  <c r="A5" t="s" s="1"><v>4</v></c>
  <c r="A6" t="s" s="0"><v>5</v></c>
  <c r="A7" t="s" s="0"><v>6</v></c>
  <c r="A8" t="s" s="1"><v>6</v></c>
  <c r="A9" t="inlineStr" s="0"><is><t>zôh-¾ô-MãÅ</t></is></c>
</row>
</sheetData>
</worksheet>"""


def texts_in(xml, tag):
    pattern = r"<" + tag + r"(?:\s[^>]*)?>([^<]*)</" + tag + r">"
    return [html.unescape(t) for t in re.findall(pattern, xml)]


class PptxConverterTest(unittest.TestCase):

    def make_pptx(self, folder):
        path = folder / "deck.pptx"
        with zipfile.ZipFile(path, "w") as z:
            z.writestr("[Content_Types].xml", "<Types/>")
            z.writestr("ppt/slides/slide1.xml", SLIDE_XML)
        return path

    def test_slide_conversion(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.make_pptx(Path(temp))
            result = convert_pptx(source)
            xml = zipfile.ZipFile(result).read("ppt/slides/slide1.xml").decode("utf-8")

            texts = texts_in(xml, "a:t")
            self.assertEqual(texts[0], "བོད་ཀྱི་ལོ་རྒྱུས")      # legacy font run
            self.assertEqual(texts[1], "English stays (A) 1/4")  # untouched
            self.assertEqual(texts[2], "བར་བཀའ་ཤག")            # re-fonted legacy

            fonts = set(re.findall(r'typeface="([^"]+)"', xml))
            self.assertNotIn("TCRC Bod-Yig", fonts)
            self.assertIn("TCRC Youtso Unicode", fonts)
            self.assertIn("Arial", fonts)

    def test_inherited_paragraph_font_conversion(self):
        xml = """<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody>
<a:p><a:pPr><a:defRPr><a:latin typeface="TCRC Bod-Yig"/></a:defRPr></a:pPr>
<a:r><a:t>zôh-¾ô-MãÅ</a:t></a:r></a:p>
<a:p><a:r><a:t>zôh-¾ô-MãÅ</a:t></a:r></a:p>
<a:p><a:r><a:t>café résumé</a:t></a:r></a:p>
</p:txBody></p:sp></p:spTree></p:cSld></p:sld>"""

        converted = convert_part_xml(xml)
        self.assertIn("བོད་ལོ་རྒྱུས", converted)
        self.assertNotIn("zôh-¾ô-MãÅ", converted)
        self.assertIn("TCRC Youtso Unicode", converted)

    def test_missing_font_fallback_is_conservative(self):
        legacy_xml = """<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><a:p>
<a:r><a:t>zôh-¾ô-MãÅ</a:t></a:r></a:p></p:sld>"""
        latin_xml = legacy_xml.replace("zôh-¾ô-MãÅ", "café résumé")

        self.assertIn("བོད་ལོ་རྒྱུས", convert_part_xml(legacy_xml))
        self.assertIn("café résumé", convert_part_xml(latin_xml))

    def test_powershell_matches_inherited_font_behavior(self):
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell is None:
            self.skipTest("PowerShell is not installed")

        inherited_xml = """<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody>
<a:p><a:pPr><a:defRPr><a:latin typeface="TCRC Bod-Yig"/></a:defRPr></a:pPr>
<a:r><a:t>zôh-¾ô-MãÅ</a:t></a:r></a:p>
<a:p><a:r><a:t>zôh-¾ô-MãÅ</a:t></a:r></a:p>
<a:p><a:r><a:t>café résumé</a:t></a:r></a:p>
</p:txBody></p:sp></p:spTree></p:cSld></p:sld>"""

        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "deck.pptx"
            target = Path(temp) / "converted.pptx"
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr("ppt/slides/slide1.xml", inherited_xml)

            subprocess.run(
                [
                    powershell,
                    "-NoProfile",
                    "-File",
                    str(PPTX_POWERSHELL),
                    "-Path",
                    str(source),
                    "-OutputPath",
                    str(target),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            with zipfile.ZipFile(target) as archive:
                converted = archive.read("ppt/slides/slide1.xml").decode("utf-8")
            self.assertIn("བོད་ལོ་རྒྱུས", converted)
            self.assertIn("café résumé", converted)


class XlsxConverterTest(unittest.TestCase):

    def make_xlsx(self, folder):
        path = folder / "book.xlsx"
        with zipfile.ZipFile(path, "w") as z:
            z.writestr("xl/sharedStrings.xml", SHARED_STRINGS_XML)
            z.writestr("xl/styles.xml", STYLES_XML)
            z.writestr("xl/worksheets/sheet1.xml", WORKSHEET_XML)
        return path

    def test_shared_strings_conversion(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.make_xlsx(Path(temp))
            result = convert_xlsx(source)
            xml = zipfile.ZipFile(result).read("xl/sharedStrings.xml").decode("utf-8")

            texts = texts_in(xml, "t")
            self.assertEqual(texts[0], "བོད་ལོ་རྒྱུས")          # plain legacy string
            self.assertEqual(texts[1], "Plain English text")    # untouched
            self.assertEqual(texts[2], "དཔལ་འབྱོར")            # rich run, legacy font
            self.assertEqual(texts[3], " (B)")                  # rich run, Arial
            # the em-dash and curly quotes must NOT trigger a conversion
            self.assertEqual(texts[4], "Total — 100% “done”")
            self.assertEqual(texts[5], "café résumé")
            self.assertEqual(texts[6], "ག་རྒྱ ༢༠༢༤")

    def test_inline_and_mixed_shared_strings(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.make_xlsx(Path(temp))
            result = convert_xlsx(source)
            with zipfile.ZipFile(result) as archive:
                sheet = archive.read("xl/worksheets/sheet1.xml").decode("utf-8")
                shared = archive.read("xl/sharedStrings.xml").decode("utf-8")

            inline_text = texts_in(sheet, "t")
            self.assertEqual(inline_text, ["བོད་ལོ་རྒྱུས"])

            indices = [int(value) for value in texts_in(sheet, "v")]
            self.assertNotEqual(indices[6], indices[7])

            namespace = {
                "s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
            }
            root = ET.fromstring(shared)
            shared_texts = [
                "".join(node.text or "" for node in item.findall(".//s:t", namespace))
                for item in root.findall("s:si", namespace)
            ]
            self.assertEqual(shared_texts[indices[6]], "བོད་ལོ་རྒྱུས")
            self.assertEqual(shared_texts[indices[7]], "zôh-¾ô-MãÅ")

    def test_refonted_run_with_sparse_leftovers_is_converted(self):
        # a run already marked TCRC Youtso Unicode, containing mostly
        # already-converted text plus a single leftover legacy character:
        # this is the "partially converted earlier" situation and the
        # leftover MUST be converted even though its density is low
        shared = (
            '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<si><r><rPr><rFont val="TCRC Youtso Unicode"/></rPr>'
            '<t>\u0f56\u00bc\u0f0b\u0f56\u0f40\u0f60</t></r></si></sst>'
        )
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "book.xlsx"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("xl/sharedStrings.xml", shared)
            result = convert_xlsx(path)
            xml = zipfile.ZipFile(result).read("xl/sharedStrings.xml").decode("utf-8")
            self.assertNotIn("\u00bc", xml)       # the 1/4 sign is gone
            self.assertIn("\u0f62", xml)          # it became Tibetan RA

    def test_numbers_and_addresses_in_legacy_cells(self):
        # a legacy-styled NUMBER cell becomes Tibetan digits (separators
        # kept), a legacy-styled ADDRESS cell stays untouched, and the
        # comma/slash characters pass through full conversions unchanged
        shared = (
            '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<si><t xml:space="preserve"> 644,936.00 </t></si>'
            '<si><t>V.J. Enterprises, Nagchala, NH -21 Mandi, HP 175021</t></si>'
            '<si><t>zôh, 2023/24</t></si>'
            '<si><t>G(43)</t></si>'
            '<si><t>G-M 2024</t></si>'
            '</sst>'
        )
        styles = (
            '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<fonts count="1"><font><name val="TCRC Bod-Yig"/></font></fonts>'
            '<cellXfs count="1"><xf fontId="0"/></cellXfs></styleSheet>'
        )
        sheet = (
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
            '<sheetData><row r="1">'
            '<c r="A1" t="s" s="0"><v>0</v></c>'
            '<c r="A2" t="s" s="0"><v>1</v></c>'
            '<c r="A3" t="s" s="0"><v>2</v></c>'
            '<c r="A4" t="s" s="0"><v>3</v></c>'
            '<c r="A5" t="s" s="0"><v>4</v></c>'
            '</row></sheetData></worksheet>'
        )
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "book.xlsx"
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("xl/sharedStrings.xml", shared)
                z.writestr("xl/styles.xml", styles)
                z.writestr("xl/worksheets/sheet1.xml", sheet)
            result = convert_xlsx(path)
            xml = zipfile.ZipFile(result).read("xl/sharedStrings.xml").decode("utf-8")
            texts = texts_in(xml, "t")
            self.assertEqual(texts[0], " ༦༤༤,༩༣༦.༠༠ ")   # number -> Tibetan digits
            self.assertEqual(
                texts[1],
                "V.J. Enterprises, Nagchala, NH -21 Mandi, HP 175021")  # address untouched
            # legacy text with comma and slash: Tibetan converted,
            # comma/slash/date kept literal
            self.assertEqual(texts[2], "བོད, ༢༠༢༣/༢༤")
            self.assertEqual(texts[3], "ག(༤༣)")
            self.assertEqual(texts[4], "ག་རྒྱ ༢༠༢༤")

    def test_styles_font_renamed(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.make_xlsx(Path(temp))
            result = convert_xlsx(source)
            styles = zipfile.ZipFile(result).read("xl/styles.xml").decode("utf-8")
            self.assertNotIn("TCRC Bod-Yig", styles)
            self.assertIn("TCRC Youtso Unicode", styles)

    def test_powershell_matches_inline_and_mixed_behavior(self):
        powershell = shutil.which("pwsh") or shutil.which("powershell")
        if powershell is None:
            self.skipTest("PowerShell is not installed")

        with tempfile.TemporaryDirectory() as temp:
            source = self.make_xlsx(Path(temp))
            target = Path(temp) / "converted.xlsx"
            subprocess.run(
                [
                    powershell,
                    "-NoProfile",
                    "-File",
                    str(XLSX_POWERSHELL),
                    "-Path",
                    str(source),
                    "-OutputPath",
                    str(target),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            with zipfile.ZipFile(target) as archive:
                sheet = archive.read("xl/worksheets/sheet1.xml").decode("utf-8")
                shared = archive.read("xl/sharedStrings.xml").decode("utf-8")

            self.assertIn("བོད་ལོ་རྒྱུས", sheet)
            self.assertIn("café résumé", shared)
            self.assertIn("ག་རྒྱ ༢༠༢༤", shared)


if __name__ == "__main__":
    unittest.main()
