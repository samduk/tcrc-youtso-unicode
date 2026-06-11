# Building TCRC Youtso Unicode

## Requirements

The installer can be built on Linux, WSL, or macOS.

- `bash`
- `curl`
- `unzip`
- `zip`
- `sha256sum`
- NSIS (`makensis`)

Ubuntu or Debian:

```bash
sudo apt install nsis curl unzip zip
```

## Build

From the repository root:

```bash
bash tools/build_installer.sh
```

Output:

```text
build/installer/TCRC-Youtso-Unicode-Setup.exe
```

The build script:

1. deletes the previous staging directory;
2. copies only declared product files;
3. downloads the pinned AutoHotkey runtime;
4. verifies the runtime SHA-256 checksum;
5. compiles the NSIS installer.

Cleaning the staging directory is important. It prevents deleted or renamed
files from accidentally remaining inside a later installer.

## Components

| Component | Purpose |
|---|---|
| `fonts/TCRC-Youtso-Unicode-fixed.ttf` | repaired Unicode font |
| `keyboard/TCRC-Tibetan-Unicode-Keyboard.ahk` | system-wide keyboard |
| `converter/TCRC-Document-Converter.ahk` | visible Windows converter UI |
| `converter/convert-document.ps1` | Office conversion controller |
| `converter/convert-docx.ps1` | fast `.docx` Open XML conversion engine |
| `converter/convert-pptx.ps1` | `.pptx` Open XML conversion engine |
| `converter/convert-xlsx.ps1` | `.xlsx` Open XML conversion engine |
| `installer/installer.nsi` | installer and uninstaller |

The installed AutoHotkey runtime is product-local. Users do not install
AutoHotkey separately.

## Tests

Run the cross-platform conversion tests:

```bash
python3 -m unittest discover -s tests -v
```

PowerShell syntax check:

```bash
pwsh -NoProfile -Command '
  $errors=$null
  [Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path "converter/convert-document.ps1"),
    [ref]$null,
    [ref]$errors
  ) > $null
  if ($errors.Count) { $errors; exit 1 }
'
```

Final installer, Microsoft Word, and Microsoft Excel checks must run on
Windows 11. The `windows-test` folder contains the automated test script and
instructions.

## Release

1. Build and test the installer.
2. Confirm its version metadata and SHA-256 checksum.
3. Create a Git tag matching the installer version.
4. Upload `TCRC-Youtso-Unicode-Setup.exe` to the GitHub release.

Users should receive the installer only. Source scripts and runtime files are
already contained inside it.
