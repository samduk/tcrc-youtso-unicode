# Building everything from source

This page explains, step by step, how to go from the code in this repository
to the things users actually download: the **installer .exe**, and a
**standalone converter .exe** for people who do not have Python.

You do not need to be a programmer. Each section is copy-paste commands.

---

## 1. What gets built from what

| You build | From | Tool used |
|-----------|------|-----------|
| `TCRC-Tibetan-Unicode-Setup.exe` (the main installer) | font + keyboard script + icons + `installer/installer.nsi` | NSIS |
| `convert_docx.exe` (standalone document converter) | `converter/convert_docx.py` | PyInstaller |
| App icons (`tcrc_on.ico`, `tcrc_off.ico`) | `tools/make_icons.py` | Python |
| The repaired font itself | original `TibetanUnicode.ttf` | `tools/repair_font.py` |

The first two are what you publish on the Releases page. The last two are
already built and committed — you only re-run them if you change something.

---

## 2. Build the main installer (.exe)

The installer bundles: the repaired font, the keyboard/converter app, the
AutoHotkey runtime (so users install nothing else), and the icons.

### On Linux, WSL, or macOS (easiest)

```bash
# one-time setup
sudo apt install nsis        # Ubuntu/Debian   (macOS: brew install makensis)

# build
bash tools/build_installer.sh
# result: build/installer/TCRC-Tibetan-Unicode-Setup.exe
```

Yes — NSIS builds Windows .exe installers even on Linux. This is normal and
the result is identical.

### On Windows

1. Install NSIS from https://nsis.sourceforge.io (default options).
2. Download the AutoHotkey v2 zip from https://www.autohotkey.com,
   and copy `AutoHotkey64.exe` out of it.
3. Make a folder anywhere and copy these files into it:
   - `installer/installer.nsi`, `installer/tcrc_on.ico`, `installer/tcrc_off.ico`
   - `fonts/TCRC-Youtso-Unicode-fixed.ttf`
   - `keyboard/TCRC-Tibetan-Unicode-Keyboard.ahk`
   - `docs/user-guide.md` renamed to `README.txt`
   - `AutoHotkey64.exe` from step 2
4. Right-click `installer.nsi` → **Compile NSIS Script**.
5. `TCRC-Tibetan-Unicode-Setup.exe` appears in the same folder.

---

## 3. Turn the Python converter into a standalone .exe

`converter/convert_docx.py` runs anywhere Python runs. But many users do not
have Python — for them, build a single .exe with **PyInstaller**.

Run this **on Windows** (an .exe must be built on Windows):

```bash
# one-time setup
pip install pyinstaller

# build (run from the repository root)
cd converter
pyinstaller --onefile --name tcrc-converter ^
    --add-data "tcrc_to_unicode_map.json;." ^
    convert_docx.py

# result: converter\dist\tcrc-converter.exe
```

What the options mean, in plain words:

- `--onefile` — pack everything (Python itself included) into ONE .exe.
- `--name tcrc-converter` — the name of the .exe.
- `--add-data "tcrc_to_unicode_map.json;."` — also pack the conversion
  table inside the .exe. (On Linux/macOS the separator is `:` instead of `;`.)

The script already knows how to find the table inside a packed .exe
(see the `sys._MEIPASS` line in the code), so it just works:

```bash
tcrc-converter.exe "my old document.docx"
tcrc-converter.exe "C:\My Documents" --batch
```

Heads-up: PyInstaller exes are sometimes flagged by antivirus software as
"unknown". This is a well-known false positive for unsigned PyInstaller
builds, not a problem with the code. Code-signing certificates fix it but
cost money.

---

## 4. Rebuild the icons (only if you change the design)

```bash
pip install -r requirements.txt
python tools/make_icons.py
# writes installer/tcrc_on.ico and installer/tcrc_off.ico
```

## 5. Re-repair the font (only if you start from the original 2003 file)

```bash
pip install fonttools
python tools/repair_font.py TibetanUnicode.ttf fonts/TCRC-Youtso-Unicode-fixed.ttf
```

---

## 6. Publish a release on GitHub

1. Tag the version and push the tag:

   ```bash
   git tag v1.0
   git push origin v1.0
   ```

2. On your repository page: **Releases → Draft a new release**.
3. Choose tag `v1.0`, title it **TCRC Youtso Unicode 1.0**.
4. Drag in the files users should download:
   - `TCRC-Tibetan-Unicode-Setup.exe` (from section 2)
   - `tcrc-converter.exe` (from section 3, optional)
5. Paste a short description and click **Publish release**.

The download link in the README points to the Releases page automatically.

---

*Questions or stuck on a step? Open an Issue on GitHub.*

*If this project helps you, support Samdup's work:*
*https://buymeacoffee.com/samchoe2002*
