# TCRC Youtso Unicode — Windows setup

## 1. Install the font
1. Uninstall any old "TCRC Youtso Unicode" (Settings → Personalization → Fonts).
2. Right-click `TCRC-Youtso-Unicode-fixed.ttf` → **Install for all users**.
3. No .exe needed — the old installer was just packaging around the font.

## 2. Install the keyboard (TCRC layout, Unicode output)
1. Install AutoHotkey v2 from https://www.autohotkey.com (free).
2. Double-click `TCRC-Tibetan-Unicode-Keyboard.ahk`. A green "H" appears in the system tray.
3. **Ctrl+Alt+T** toggles Tibetan typing on/off.
4. To start it automatically with Windows: press Win+R, type `shell:startup`, copy a shortcut to the .ahk file there.

### Typing logic (same as TCRC chart)
- Space = tsheg ་ (press twice = tsheg + space; after ga the tsheg is removed)
- `a` = link/halent: next consonant becomes subjoined → `k a y` = ཀྱ
- `/` = shad ། (typing it after nga auto-inserts the tsheg)
- `b k '` = བཀའ, `b s a k a y o d` = བསྐྱོད

A few rare punctuation keys are marked `[verify]` in the script — test them and report anything that outputs the wrong sign.

## 3. Make TCRC Youtso the automatic Tibetan font
The keyboard types Unicode text; each app chooses the display font. Windows'
built-in fallback for Tibetan is "Microsoft Himalaya". The installer adds a
system font substitution (Himalaya → TCRC Youtso Unicode) — sign out and back
in once for it to take effect.

## 4. Microsoft Office (Word)
Word manages its own complex-script font, so do this once:
1. Home tab → open the Font dialog (small arrow, or Ctrl+D).
2. Under "Complex scripts", set Font: **TCRC Youtso Unicode**.
3. Click **Set As Default** → "All documents based on Normal template" → OK.
From then on Tibetan typed in Word uses TCRC Youtso automatically.

## 4. Photoshop — important
Photoshop will NOT stack Tibetan until you enable complex-script layout:
1. Edit → Preferences → Type → Choose Text Engine Options: **Middle Eastern and South Asian**.
2. Restart Photoshop.
3. Paragraph panel menu (☰) → **World-Ready Layout**.
Without this, even a perfect Unicode font shows unstacked letters.

## 5. Converting old legacy documents
The app watches Word: when you open a document containing legacy
TCRC Bod-Yig text, it asks "Convert to Unicode now?" — click Yes,
check the result, save. The text becomes standard Unicode
(viewable in Microsoft Himalaya, Monlam, TCRC Youtso Unicode...).

For any other program (Photoshop, posters, e-mail...): select the
garbled legacy text and press **Ctrl+Alt+U** — it is replaced with
Unicode in place.

## 6. Tibetan numbers, the numpad, and Excel
- The **numeric keypad** types Tibetan digits ༠-༩ when Tibetan mode is on
  (Ctrl+Alt+T toggles; turn it off to type normal digits for calculations).
- **Ctrl+Alt+N**: select a number (e.g. 900000) and press it — the number
  becomes Tibetan digits with Indian-style grouping: ༩,༠༠,༠༠༠.
- **Excel and math**: Excel can only calculate with real (western) numbers.
  Tibetan digit characters are text to Excel. The trick to have BOTH:
  1. Type real numbers in the cells (Tibetan mode off) — all formulas work.
  2. Select the cells → right-click → Format Cells → Custom, and enter:
     `[$-2000451]#,##0`
     This keeps the values as real numbers but DISPLAYS them as Tibetan
     digits. For Indian-style grouping use:
     `[>=10000000][$-2000451]#\,##\,##\,##0;[>=100000][$-2000451]#\,##\,##0;[$-2000451]#,##0`
  3. Set the cell font to TCRC Youtso Unicode so the digits look right.
  (If your Excel version ignores the format and shows western digits,
  use Ctrl+Alt+N on labels/headings instead — values stay calculable.)

## Files
- `TCRC-Youtso-Unicode-fixed.ttf` — repaired Unicode font (419 broken glyph names fixed, OS/2 table modernized v0→v4, Tibetan Unicode range declared)
- `TCRC-Tibetan-Unicode-Keyboard.ahk` — TCRC-layout Unicode keyboard
- `render_test.png`, `keyboard_test.png` — rendering proofs
