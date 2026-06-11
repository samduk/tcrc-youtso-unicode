# TCRC Youtso Unicode

TCRC Youtso Unicode brings the familiar TCRC Tibetan typeface and keyboard to
modern Windows. It also includes a simple desktop application for converting
old TCRC Word, PowerPoint, and Excel documents to Unicode.

[![CI](https://github.com/samduk/tcrc-youtso-unicode/actions/workflows/ci.yml/badge.svg)](https://github.com/samduk/tcrc-youtso-unicode/actions/workflows/ci.yml)

## For Windows users

Download **`TCRC-Youtso-Unicode-Setup.exe`** from the
[Releases](../../releases) page and run it.

The installer adds:

- the **TCRC Youtso Unicode** font;
- the **TCRC Youtso Excel Numbers** display font;
- the familiar TCRC Tibetan keyboard;
- a **TCRC Document Converter** shortcut on the desktop;
- an uninstaller in Windows Settings.

No Python, AutoHotkey, or separate font installation is required.

## Convert an old document

1. Double-click **TCRC Document Converter** on the desktop.
2. Choose an old Word, PowerPoint, or Excel file.
3. Select **Convert to Unicode**.

The converter creates a new file named:

```text
Original name (Unicode).<modern Office extension>
```

The original document is never changed. The Unicode copy can use TCRC Youtso
Unicode, Microsoft Himalaya, Monlam, or another Unicode Tibetan font.

You can also drag a supported Office file onto the converter window. Windows
11 users can right-click the file, choose **Show more options**, and select
**Convert TCRC document to Unicode**.

## Type Tibetan

The keyboard starts automatically after installation.

- `Ctrl+Alt+T` switches Tibetan typing on or off.
- Choose **TCRC Youtso Unicode** from the normal font list in Word or another
  application.
- The keyboard produces standard Unicode Tibetan text.

See the [Windows user guide](docs/user-guide.md) for Word and Photoshop setup.

## Use Tibetan numbers in Excel

Excel must store ordinary digits internally to perform calculations. The
included Excel number mode keeps those values numeric while drawing them as
Tibetan digits.

1. Open Excel and select the cells that will contain numbers.
2. Press `Ctrl+Alt+N`.
3. Type numbers normally.
4. Use formulas such as `SUM`, addition, subtraction, multiplication, and
   division.

The cells display Tibetan digits, but Excel still stores real numbers. The
formula bar may show ordinary digits; that is expected and is what makes the
calculations work.

## Product behavior

The application is intentionally conservative:

- it does not monitor Microsoft Office applications in the background;
- it does not replace Microsoft Himalaya or other system fonts;
- it does not overwrite source documents;
- document conversion starts only after the user selects a file.

## Development

The Windows-only package has these focused components:

- `keyboard/TCRC-Tibetan-Unicode-Keyboard.ahk`: keyboard input only;
- `converter/TCRC-Document-Converter.ahk`: visible converter interface;
- `converter/convert-docx.ps1`: Word Open XML conversion engine;
- `converter/convert-pptx.ps1`: PowerPoint Open XML conversion engine;
- `converter/convert-xlsx.ps1`: Excel Open XML conversion engine.

Run the converter tests:

```bash
python3 -m unittest discover -s tests -v
```

Additional build information is in [docs/building.md](docs/building.md).

## Credits

- Original TCRC Youtso typeface and keyboard: Tibetan Computer Resource Centre
  (TCRC), 2000-2003.
- Unicode repair, conversion work, and packaging: Samdup.
- Development assistance: Claude and OpenAI Codex.

## License

The source code is released under the [MIT License](LICENSE).

The original TCRC typeface outlines remain the work of the Tibetan Computer
Resource Centre. See [fonts/README.md](fonts/README.md) for provenance.

## Support

[Support Samdup's work](https://buymeacoffee.com/samchoe2002)
