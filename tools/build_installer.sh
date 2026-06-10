#!/usr/bin/env bash
# Build the complete Windows installer from a clean staging directory.
set -euo pipefail

cd "$(dirname "$0")/.."

for command in curl unzip makensis sha256sum; do
    command -v "$command" >/dev/null || {
        echo "Missing required command: $command" >&2
        exit 1
    }
done

readonly STAGE="build/installer"
readonly AHK_VERSION="2.0.19"
readonly AHK_ARCHIVE="AutoHotkey_${AHK_VERSION}.zip"
readonly AHK_URL="https://github.com/AutoHotkey/AutoHotkey/releases/download/v${AHK_VERSION}/${AHK_ARCHIVE}"
readonly AHK_SHA256="4e0d0e65655066a646a210951320feaef0729a3597177131adaec4066bef5869"

rm -rf "$STAGE"
mkdir -p "$STAGE"

cp installer/installer.nsi installer/tcrc_on.ico installer/tcrc_off.ico \
    "$STAGE/"
cp fonts/TCRC-Youtso-Unicode-fixed.ttf \
    fonts/TCRC-Youtso-Excel-Numbers.ttf \
    "$STAGE/"
cp keyboard/TCRC-Tibetan-Unicode-Keyboard.ahk "$STAGE/"
cp converter/TCRC-Document-Converter.ahk \
    converter/convert-document.ps1 \
    converter/convert-docx.ps1 \
    converter/tcrc_to_unicode_map.json \
    "$STAGE/"
cp docs/user-guide.md "$STAGE/README.txt"

curl -fL --retry 3 --silent --show-error \
    -o "$STAGE/$AHK_ARCHIVE" \
    "$AHK_URL"
printf '%s  %s\n' "$AHK_SHA256" "$STAGE/$AHK_ARCHIVE" |
    sha256sum --check --status
unzip -q "$STAGE/$AHK_ARCHIVE" AutoHotkey64.exe -d "$STAGE"
rm "$STAGE/$AHK_ARCHIVE"

(
    cd "$STAGE"
    makensis installer.nsi
)

echo
echo "Built: $STAGE/TCRC-Youtso-Unicode-Setup.exe"
