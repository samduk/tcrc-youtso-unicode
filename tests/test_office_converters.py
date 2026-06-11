"""Tests for the PowerPoint and Excel converters."""

import html
import re
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "converter"))

from convert_pptx import convert_pptx          # noqa: E402
from convert_xlsx import convert_xlsx          # noqa: E402

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
</sst>"""


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


class XlsxConverterTest(unittest.TestCase):

    def make_xlsx(self, folder):
        path = folder / "book.xlsx"
        with zipfile.ZipFile(path, "w") as z:
            z.writestr("xl/sharedStrings.xml", SHARED_STRINGS_XML)
            z.writestr("xl/styles.xml",
                       '<styleSheet><fonts><font><name val="TCRC Bod-Yig"/>'
                       "</font></fonts></styleSheet>")
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

    def test_styles_font_renamed(self):
        with tempfile.TemporaryDirectory() as temp:
            source = self.make_xlsx(Path(temp))
            result = convert_xlsx(source)
            styles = zipfile.ZipFile(result).read("xl/styles.xml").decode("utf-8")
            self.assertNotIn("TCRC Bod-Yig", styles)
            self.assertIn("TCRC Youtso Unicode", styles)


if __name__ == "__main__":
    unittest.main()
