# TCRC Youtso Unicode for Windows

## Install

1. Download `TCRC-Youtso-Unicode-Setup.exe`.
2. Double-click the installer.
3. Approve the Windows administrator prompt.
4. Finish the installation.

Windows SmartScreen may warn because the installer is not code-signed. Confirm
that the file came from the official project release before selecting
**More info > Run anyway**.

## Convert old TCRC documents

1. Double-click **TCRC Document Converter** on the desktop.
2. Select **Choose file**.
3. Choose an old Word, PowerPoint, or Excel file.
4. Select **Convert to Unicode**.

You can also drag the document onto the converter window.

The new file is saved next to the original:

```text
Original name (Unicode).<modern Office extension>
```

The original file is never changed. Supported formats are `.doc`, `.docx`,
`.ppt`, `.pptx`, `.xls`, and `.xlsx`. Old binary files require their matching
Microsoft Office application: Word for `.doc`, PowerPoint for `.ppt`, and
Excel for `.xls`.

### Right-click conversion

On Windows 11:

1. Right-click the Word, PowerPoint, or Excel file.
2. Select **Show more options**.
3. Select **Convert TCRC document to Unicode**.
4. Confirm the file in the converter window.

## Type Tibetan

The TCRC keyboard starts automatically when you sign in to Windows.

- `Ctrl+Alt+T` switches Tibetan typing on or off.
- The green tray icon means Tibetan typing is on.
- The dark tray icon means Tibetan typing is off.

The keyboard follows the traditional TCRC layout and produces Unicode Tibetan.
When Tibetan typing turns on, it automatically selects **TCRC Youtso Unicode**
for the current editing position in Microsoft Word, Excel, and PowerPoint. It
also reapplies the font when you start typing after switching between those
applications.

In Excel, the font is reapplied before each Tibetan keystroke. After pressing
`Tab`, `Enter`, an arrow key, or selecting another cell, you can type directly
without choosing TCRC Youtso Unicode again.

## Microsoft Excel numbers

Normal Unicode Tibetan digits are text in Excel. Text cannot be added,
subtracted, or used reliably in formulas.

The installer includes an Excel number mode that keeps the cell value numeric
but displays the digits in Tibetan form.

### Prepare cells

1. Open Microsoft Excel.
2. Select the cells or columns that will contain numbers.
3. Press `Ctrl+Alt+N`.
4. Select **OK** in the confirmation message.
5. Type numbers normally.

You can also right-click the keyboard tray icon and select
**Prepare selected Excel cells for Tibetan numbers**.

### Perform calculations

The prepared cells are real Excel numbers. You can:

- use **AutoSum**;
- enter formulas such as `=A1+A2`;
- multiply with `*`;
- divide with `/`;
- sort and filter numerically.

SUM, AVERAGE, AutoSum, and other formula result cells automatically use
**TCRC Youtso Unicode** while Tibetan typing is on. Results continue to use
that font when Excel recalculates active or inactive worksheets.

Moving to another cell with Tab, Enter, an arrow key, or the mouse also applies
**TCRC Youtso Unicode** to that cell. This remains active until Tibetan typing
is turned off with `Ctrl+Alt+T`.

When Tibetan typing is on, Excel receives ordinary digits and the operators
`+`, `-`, `*`, `/`, and `=`. To enter cell references, click the cells while
building the formula or press `Ctrl+Alt+T` temporarily to type Latin letters.

The worksheet displays Tibetan digits. The formula bar may show ordinary
digits because those are the real numeric values used by Excel. This is
expected.

Do not paste Unicode Tibetan digit characters into calculation cells. Existing
Tibetan digit text must be re-entered as numbers before Excel can calculate
with it.

## Microsoft Word

Current Microsoft 365 versions do not always show a separate
**Complex scripts** font box.

To type with TCRC Youtso:

1. Open Word.
2. Press `Ctrl+Alt+T` if Tibetan typing is off.
3. Type normally. The keyboard selects **TCRC Youtso Unicode** automatically.

For an existing Unicode document, select the Tibetan text and choose
**TCRC Youtso Unicode**.

## Adobe Photoshop

Tibetan shaping requires World-Ready text layout.

1. Open **Edit > Preferences > Type**.
2. Enable the Middle Eastern and South Asian text option, if shown.
3. Restart Photoshop.
4. Open the Paragraph panel menu and choose **World-Ready Layout**.
5. Select **TCRC Youtso Unicode** as the font.

The exact labels can differ between Photoshop versions.

## Troubleshooting

### Conversion failed

- Close the source and output files in Microsoft Office, then try again.
- Confirm that the file uses a supported Office extension.
- For `.doc`, `.ppt`, or `.xls`, confirm that the matching Office application
  is installed.
- Do not select a file that already ends with ` (Unicode)`.

### The converter shortcut is missing

Open the Start menu and search for **TCRC Document Converter**. If it is also
missing there, reinstall the package.

### Tibetan typing does not work

Open the Start menu, search for **Tibetan Keyboard**, and start it. Then press
`Ctrl+Alt+T` and check the tray icon.

### Word uses another Tibetan font

Click the position where you want to type, switch Tibetan typing off and on
with `Ctrl+Alt+T`, then type again. Tibetan mode applies **TCRC Youtso Unicode**
to Word's current editing position. The installer does not replace Microsoft
Himalaya or modify other system fonts.

### Excel shows ordinary digits

Select the cells again and press `Ctrl+Alt+N`. If the keyboard is not running,
open the Start menu and start **Tibetan Keyboard** first.

### Excel formulas do not calculate

The cells probably contain Unicode Tibetan digit text from an older document.
Clear those values, press `Ctrl+Alt+N`, and enter the numbers again. The formula
bar should show ordinary digits even though the worksheet shows Tibetan digits.

## Uninstall

Open **Settings > Apps > Installed apps**, find **TCRC Youtso Unicode**, and
select **Uninstall**.

## Batch conversion from the command line

Command line (Python) versions for batch work:

    python converter/convert_pptx.py "C:\My Slides" --batch
    python converter/convert_xlsx.py "C:\My Sheets" --batch

## Converting Photoshop, Illustrator, and InDesign files

PSD/AI/INDD files can only be converted INSIDE the Adobe application.
Two scripts are installed in the application folder's "adobe" subfolder
(C:\Program Files\TCRC Tibetan Unicode\adobe):

- Photoshop:   File > Scripts > Browse... ->
               TCRC-to-Unicode-Photoshop-Illustrator.jsx
- Illustrator: File > Scripts > Other Script... -> same file
- InDesign:    copy TCRC-to-Unicode-InDesign.jsx into the Scripts Panel
               folder (Window > Utilities > Scripts > right-click User >
               Reveal), then double-click it in the Scripts panel.

The scripts convert text using a legacy TCRC font, then switch it to
TCRC Youtso Unicode. Always run them on a COPY of your file first.
Photoshop additionally needs the World-Ready text engine enabled (see the
Photoshop section above) for stacks to display.
