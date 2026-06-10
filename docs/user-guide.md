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

## Files
- `TCRC-Youtso-Unicode-fixed.ttf` — repaired Unicode font (419 broken glyph names fixed, OS/2 table modernized v0→v4, Tibetan Unicode range declared)
- `TCRC-Tibetan-Unicode-Keyboard.ahk` — TCRC-layout Unicode keyboard
- `render_test.png`, `keyboard_test.png` — rendering proofs
