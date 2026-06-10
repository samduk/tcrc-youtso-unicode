# TCRC Youtso Unicode — ཡུ་མཚོ།

**A complete revival of the beloved TCRC Youtso Tibetan font for the modern computer: Unicode font + familiar TCRC keyboard + automatic conversion of old documents + one-click Windows installer.**

[![Buy Me A Coffee](https://img.shields.io/badge/Support%20Samdup's%20work-Buy%20Me%20a%20Coffee-yellow?logo=buymeacoffee)](https://buymeacoffee.com/samchoe2002)
![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-blue)
![Made with Python](https://img.shields.io/badge/tools-Python-3776AB?logo=python&logoColor=white)

---

## Why this project exists

The original **TCRC Youtso** font, created by the Tibetan Computing Resource Centre
around 2000–2003, served the Tibetan community faithfully for more than two decades.
Countless books, prayers, school materials, and official documents were typed with it.

**The original software was not bad — it was ahead of its time.** It was built
*before* Unicode Tibetan was widely supported, so it had to store Tibetan letters
on top of English character codes. That clever workaround was the only option then.
But computers moved on, and what was once a solution became a source of daily
frustration. A revamp and upgrade of this treasured project is simply
**the need of the hour.**

### Problems ordinary users face every day with the legacy font

| # | Problem | Who it hurts |
|---|---------|--------------|
| 1 | Old documents open as random symbols (`ºGô-zXôhü...`) on any computer without the exact old font | Anyone receiving or archiving old files |
| 2 | Text cannot be searched, copied, or read on phones, web, or e-mail | Students, offices, monasteries |
| 3 | The old installer (.exe from 2003) will not run on modern 64-bit Windows | Every new computer owner |
| 4 | Word silently switches to a fallback font; Photoshop shows letters without stacks | Designers, publishers |
| 5 | Typists trained on the TCRC keyboard layout have to relearn typing from zero on other systems | Experienced typists — the people who type the most |

### What this project does about it (the USP)

This is the **only** package that fixes all five problems at once, while keeping
the **exact same typeface people love and the exact same keyboard layout people
already know**:

1. **Repaired Unicode font** — the original TCRC Youtso Unicode font with its
   internals modernized (419 broken glyph names fixed, font tables upgraded from
   the 1990s format to the current standard) so Windows, Word, and Photoshop
   accept it as a first-class Tibetan font.
2. **The same TCRC keyboard, now typing Unicode** — space = tsheg, the *link*
   key builds stacks, shad-after-nga rules — everything works the way TCRC
   typists' fingers remember, but the output is standard Unicode that works
   everywhere, forever.
3. **Automatic rescue of old documents** — open a legacy document in Word and
   the app offers to convert it to Unicode on the spot. In any other program,
   select garbled text and press `Ctrl+Alt+U`. The conversion table was built
   by visually matching every single glyph of the old font against the new one,
   then verified letter-by-letter against real documents.
4. **One double-click installer** — font, keyboard, and converter install
   together; a clean uninstaller removes every trace.

---

## Install (for users)

1. Download `TCRC-Tibetan-Unicode-Setup.exe` from the [Releases](../../releases) page.
2. Double-click it. (Windows SmartScreen may warn because the installer is not
   code-signed — click **More info → Run anyway**.)
3. Sign out of Windows and back in once.
4. Type! `Ctrl+Alt+T` switches Tibetan typing on/off.

Full instructions, including the one-time Word and Photoshop settings, are in
[docs/user-guide.md](docs/user-guide.md).

## Convert old documents (Python, no installation of the app needed)

```bash
pip install -r requirements.txt

# one file
python converter/convert_docx.py "my old document.docx"

# a whole folder at once
python converter/convert_docx.py "C:\My Documents" --batch
```

Each converted file is saved next to the original with ` (Unicode)` added to its
name — originals are never touched.

## Project structure

```
tcrc-youtso-unicode/
├── fonts/        the repaired Unicode font (and provenance notes)
├── keyboard/     the TCRC-layout keyboard (AutoHotkey v2 script)
├── converter/    Python legacy→Unicode converter + the mapping table
├── tools/        Python scripts that built everything (font repair,
│                 glyph matching, icon generation) — fully commented
├── installer/    NSIS installer source + icons
└── docs/         user guide
```

**Why is the keyboard not Python?** Python cannot reliably intercept keystrokes
system-wide on Windows. The keyboard uses AutoHotkey v2 — a small, free, open
source tool made exactly for this. Everything else in the project is Python.

## Building the installer from source

```bash
# Linux/WSL/macOS (NSIS is cross-platform)
bash tools/build_installer.sh
```

The script downloads the AutoHotkey runtime, stages all files, and compiles
`TCRC-Tibetan-Unicode-Setup.exe` with NSIS.

## How the legacy conversion table was made (the interesting part)

The old font stores Tibetan glyphs on English codes, and there was no published
mapping. So `tools/build_mapping.py`:

1. renders **every glyph of the old font** and **every glyph of the Unicode
   font** to small images,
2. finds each old glyph's visual twin in the Unicode font,
3. inverts the Unicode font's internal stacking rules to turn each matched
   glyph back into a sequence of Unicode characters,
4. and the result was verified against real documents, character by character
   (words like ལྡན, ལྷ, བླ, གླིང, པདྨ confirmed the ambiguous cases).

## Credits

- **Tibetan Computer Resource Centre (TCRC)** — creators of the original
  Youtso typeface and keyboard (© 2000–2003). This project stands on their
  shoulders; the typeface remains their work and their copyright.
- Revival, Unicode repair, converter, and packaging — **Samdup**.

## Support this work ☕

This revival is independent, unpaid work for the community. If it saved your
documents or your typing speed, consider supporting Samdup:

**[buymeacoffee.com/samchoe2002](https://buymeacoffee.com/samchoe2002)**

## License

The **code** in this repository (converter, tools, keyboard script, installer
source) is released under the [MIT License](LICENSE).

The **Youtso typeface** (glyph outlines) remains © Tibetan Computing Resource
Centre. The repaired font is distributed here in the same spirit of free
community use as the original; if TCRC requests changes to its distribution,
they will be honored.
