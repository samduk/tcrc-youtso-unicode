#!/usr/bin/env bash
# Build TCRC-Tibetan-Unicode-Setup.exe from source.
# Works on Linux, WSL, and macOS. Needs: curl, unzip, makensis (NSIS).
#   Ubuntu/Debian: sudo apt install nsis
#   macOS:         brew install makensis
set -e
cd "$(dirname "$0")/.."        # repo root

STAGE=build/installer
mkdir -p "$STAGE"
cp installer/installer.nsi installer/tcrc_on.ico installer/tcrc_off.ico "$STAGE/"
cp fonts/TCRC-Youtso-Unicode-fixed.ttf "$STAGE/"
cp keyboard/TCRC-Tibetan-Unicode-Keyboard.ahk "$STAGE/"
cp docs/user-guide.md "$STAGE/README.txt"

# fetch the AutoHotkey v2 runtime that gets bundled inside the installer
AHK_URL=https://github.com/AutoHotkey/AutoHotkey/releases/download/v2.0.19/AutoHotkey_2.0.19.zip
curl -sL -o "$STAGE/ahk.zip" "$AHK_URL"
unzip -o -q "$STAGE/ahk.zip" AutoHotkey64.exe -d "$STAGE"
rm "$STAGE/ahk.zip"

cd "$STAGE"
makensis installer.nsi
echo
echo "Done -> $STAGE/TCRC-Tibetan-Unicode-Setup.exe"
