import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
    def test_windows_test_generates_documents_at_runtime(self):
        build_script = (
            REPO_ROOT / "tools" / "build_release.sh"
        ).read_text(encoding="utf-8")
        windows_test = (
            REPO_ROOT / "windows-test" / "Test-TCRC-Windows.ps1"
        ).read_text(encoding="utf-8")

        self.assertFalse(
            (REPO_ROOT / "windows-test" / "tcrc-test.docx").exists()
        )
        self.assertFalse(
            (
                REPO_ROOT
                / "windows-test"
                / "tcrc-test (Unicode).docx"
            ).exists()
        )
        self.assertNotIn("tcrc-test.docx", build_script)
        self.assertNotIn("tcrc-test (Unicode).docx", build_script)
        self.assertIn("New-LegacyTestDocument", windows_test)
        self.assertIn("$expectedUnicode", windows_test)

    def test_release_version_and_merged_font_are_packaged(self):
        installer = (REPO_ROOT / "installer" / "installer.nsi").read_text(
            encoding="utf-8"
        )
        release_notes = (
            REPO_ROOT / "windows-test" / "RELEASE-NOTES.txt"
        ).read_text(encoding="utf-8")
        build_script = (
            REPO_ROOT / "tools" / "build_installer.sh"
        ).read_text(encoding="utf-8")

        self.assertIn('!define APPVERSION "1.4.3"', installer)
        self.assertIn('VIProductVersion "1.4.3.0"', installer)
        self.assertTrue(release_notes.startswith("TCRC Youtso Unicode 1.4.3"))
        self.assertIn('File "TCRC-Youtso-Unicode-fixed.ttf"', installer)
        self.assertNotIn('File "TCRC-Youtso-Excel-Numbers.ttf"', installer)
        self.assertNotIn("fonts/TCRC-Youtso-Excel-Numbers.ttf", build_script)
        install_section = installer.split('Section "Uninstall"', 1)[0]
        self.assertIn(
            '"TCRC Youtso Excel Numbers (TrueType)"',
            install_section,
        )
        self.assertIn(
            'Delete /REBOOTOK "$FONTS\\TCRC-Youtso-Excel-Numbers.ttf"',
            install_section,
        )

    def test_windows_test_verifies_automatic_formula_result_fonts(self):
        windows_test = (
            REPO_ROOT / "windows-test" / "Test-TCRC-Windows.ps1"
        ).read_text(encoding="utf-8")

        self.assertIn('$sumResult.Font.Name = "Arial"', windows_test)
        self.assertIn('$secondSumResult.Font.Name = "Arial"', windows_test)
        self.assertIn('$sheetAverageResult.Font.Name = "Arial"', windows_test)
        self.assertIn('$averageResult.Font.Name = "Arial"', windows_test)
        self.assertIn(
            '$sumResult.Font.Name -eq "TCRC Youtso Unicode"',
            windows_test,
        )
        self.assertIn(
            '$secondSumResult.Font.Name -eq "TCRC Youtso Unicode"',
            windows_test,
        )
        self.assertIn(
            '$sheetAverageResult.Font.Name -eq "TCRC Youtso Unicode"',
            windows_test,
        )
        self.assertIn(
            '$averageResult.Font.Name -eq "TCRC Youtso Unicode"',
            windows_test,
        )
        self.assertIn("$inactiveWorksheet.Range", windows_test)
        self.assertIn('$wscriptShell.SendKeys("^%t")', windows_test)

    def test_installer_uses_product_specific_processes(self):
        installer = (REPO_ROOT / "installer" / "installer.nsi").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("taskkill /F /IM AutoHotkey64.exe", installer)
        self.assertIn("TCRC-Tibetan-Keyboard.exe", installer)
        self.assertIn("TCRC-Document-Converter.exe", installer)

    def test_installer_does_not_write_a_font_substitute(self):
        installer = (REPO_ROOT / "installer" / "installer.nsi").read_text(
            encoding="utf-8"
        )
        writes = re.findall(
            r"WriteRegStr HKLM\s+"
            r'"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes"',
            installer,
        )
        # One conditional restore is allowed for upgrading an older release.
        self.assertLessEqual(len(writes), 1)
        self.assertIn(
            "Undo the global Microsoft Himalaya substitution",
            installer,
        )

    def test_build_starts_from_a_clean_stage_and_verifies_runtime(self):
        build_script = (
            REPO_ROOT / "tools" / "build_installer.sh"
        ).read_text(encoding="utf-8")
        self.assertIn('rm -rf "$STAGE"', build_script)
        self.assertIn("AHK_SHA256", build_script)
        self.assertIn("sha256sum --check --status", build_script)


if __name__ == "__main__":
    unittest.main()
