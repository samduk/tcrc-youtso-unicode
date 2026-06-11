import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class PackagingTests(unittest.TestCase):
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
