#!/usr/bin/env bash
# Build user-facing and Windows-test release artifacts.
set -euo pipefail

cd "$(dirname "$0")/.."

for command in install sed sha256sum zip; do
    command -v "$command" >/dev/null || {
        echo "Missing required command: $command" >&2
        exit 1
    }
done

bash tools/build_installer.sh

readonly VERSION="$(
    sed -n 's/^!define APPVERSION "\(.*\)"/\1/p' installer/installer.nsi
)"
readonly DIST="dist"
readonly INSTALLER_NAME="TCRC-Youtso-Unicode-Setup.exe"
readonly TEST_DIR="$DIST/TCRC-Windows-Test"

if [[ -z "$VERSION" ]]; then
    echo "Could not read APPVERSION from installer/installer.nsi" >&2
    exit 1
fi

rm -rf "$DIST"
mkdir -p "$TEST_DIR"

install -m 0644 \
    "build/installer/$INSTALLER_NAME" \
    "$DIST/$INSTALLER_NAME"

for file in \
    README.txt \
    RELEASE-NOTES.txt \
    Run-Windows-Test.cmd \
    Test-TCRC-Windows.ps1 \
    tcrc-test.docx \
    "tcrc-test (Unicode).docx"
do
    install -m 0644 "windows-test/$file" "$TEST_DIR/$file"
done
install -m 0644 "$DIST/$INSTALLER_NAME" "$TEST_DIR/$INSTALLER_NAME"

(
    cd "$DIST"
    sha256sum "$INSTALLER_NAME" > SHA256SUMS.txt
)
(
    cd "$TEST_DIR"
    sha256sum \
        "$INSTALLER_NAME" \
        tcrc-test.docx \
        "tcrc-test (Unicode).docx" \
        > SHA256SUMS.txt
)
(
    cd "$DIST"
    zip -qr "TCRC-Windows-Test-${VERSION}.zip" TCRC-Windows-Test
)

echo
echo "Release installer: $DIST/$INSTALLER_NAME"
echo "Windows test:     $DIST/TCRC-Windows-Test-${VERSION}.zip"
echo "Checksums:        $DIST/SHA256SUMS.txt"
