# convert-xlsx.ps1 - fast file-based legacy TCRC -> Unicode conversion
# for Excel .xlsx files. PowerShell port of convert_xlsx.py.
#
# Excel keeps almost all cell text in xl/sharedStrings.xml. Rich runs name
# their font directly; plain strings do not, so for those we use a content
# test: text containing 0xA0-0xFF legacy characters (ô, ¾, º...) is legacy.
#
# Usage:  powershell -ExecutionPolicy Bypass -File convert-xlsx.ps1 -Path "book.xlsx"
# Result: a new file "book (Unicode).xlsx" next to the original.

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$mapFile = Join-Path $scriptFolder "tcrc_to_unicode_map.json"
$json = Get-Content -Raw -Encoding UTF8 $mapFile | ConvertFrom-Json

$table = @{}
foreach ($property in $json.PSObject.Properties) {
    $table[[int]$property.Name] = $property.Value
}

$legacyFonts = @("TCRC Bod-Yig", "TCRC Youtsoweb", "TCRC Youtso")
$replacementFont = "TCRC Youtso Unicode"

$spreadsheetNamespace = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"

function Convert-LegacyText([string]$text) {
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $text.ToCharArray()) {
        $code = [int]$character
        if ($table.ContainsKey($code)) {
            [void]$builder.Append($table[$code])
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Test-TextHasLegacySignature([string]$text) {
    $mappedHighCharacters = 0
    $nonSpaceLength = 0
    foreach ($character in $text.ToCharArray()) {
        $code = [int]$character
        if (-not [char]::IsWhiteSpace($character)) {
            $nonSpaceLength++
        }
        if (($code -ge 0xA0) -and ($code -le 0xFF) -and $table.ContainsKey($code)) {
            $mappedHighCharacters++
        }
    }
    return (
        $mappedHighCharacters -ge 2 -and
        ($mappedHighCharacters * 2) -ge [Math]::Max($nonSpaceLength, 1)
    )
}

function Test-TextHasAnyLegacyCharacter([string]$text) {
    # Used when the run's font is already TCRC Youtso Unicode: the text is
    # known to be Tibetan, so a single leftover legacy character (a stray
    # 1/4 sign from an earlier partial conversion) is enough proof.
    foreach ($character in $text.ToCharArray()) {
        $code = [int]$character
        if (($code -ge 0xA0) -and ($code -le 0xFF) -and $table.ContainsKey($code)) {
            return $true
        }
    }
    return $false
}

function Test-TextIsNumericOnly([string]$text) {
    # Is this text just a number, like " 644,936.00 " or "2023-24"?
    $hasDigit = $false
    foreach ($character in $text.ToCharArray()) {
        if ([char]::IsDigit($character)) {
            $hasDigit = $true
        } elseif (" .,-+%/()'".IndexOf($character) -lt 0) {
            return $false
        }
    }
    return $hasDigit
}

function Convert-DigitsToTibetan([string]$text) {
    $builder = New-Object System.Text.StringBuilder
    foreach ($character in $text.ToCharArray()) {
        if ($character -ge "0" -and $character -le "9") {
            [void]$builder.Append([char](0x0F20 + [int][string]$character))
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString()
}

function Get-ConversionMode([string]$text) {
    # "full"   - real legacy Tibetan text: convert every character
    # "digits" - a pure number (price, year): only digits become Tibetan
    # "none"   - letters AND digits together (an address): leave untouched
    if (Test-TextHasAnyLegacyCharacter $text) { return "full" }
    if (Test-TextIsNumericOnly $text) { return "digits" }
    $hasLetter = $false
    $hasDigit = $false
    foreach ($character in $text.ToCharArray()) {
        if ([char]::IsLetter($character)) { $hasLetter = $true }
        if ([char]::IsDigit($character)) { $hasDigit = $true }
    }
    if ($hasLetter -and $hasDigit) { return "none" }
    return "full"
}

function Convert-ByMode([string]$text, [string]$mode) {
    if ($mode -eq "full") { return Convert-LegacyText $text }
    if ($mode -eq "digits") { return Convert-DigitsToTibetan $text }
    return $text
}

function Get-SpreadsheetNamespaceManager($document) {
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $namespaceManager.AddNamespace("s", $spreadsheetNamespace)
    return ,$namespaceManager
}

function Get-RichRunFont($properties, $namespaceManager) {
    if ($null -eq $properties) { return $null }
    $font = $properties.SelectSingleNode("s:rFont", $namespaceManager)
    if ($null -eq $font) { return $null }
    return $font.GetAttribute("val")
}

function Convert-StringContainer(
    $container,
    [bool]$force,
    [bool]$allowFallback
) {
    $namespaceManager = Get-SpreadsheetNamespaceManager $container.OwnerDocument
    $runs = $container.SelectNodes("s:r", $namespaceManager)
    if ($runs.Count -gt 0) {
        foreach ($run in $runs) {
            $properties = $run.SelectSingleNode("s:rPr", $namespaceManager)
            $runFont = Get-RichRunFont $properties $namespaceManager
            $textNodes = $run.SelectNodes("s:t", $namespaceManager)
            $runText = ""
            foreach ($textNode in $textNodes) {
                $runText += $textNode.InnerText
            }

            $shouldConvert = $legacyFonts -contains $runFont
            if (
                $runFont -eq $replacementFont -and
                (Test-TextHasAnyLegacyCharacter $runText)
            ) {
                $shouldConvert = $true
            }
            if ([string]::IsNullOrWhiteSpace($runFont) -and $force) {
                $shouldConvert = $true
            }
            if (
                [string]::IsNullOrWhiteSpace($runFont) -and
                $allowFallback -and
                (Test-TextHasLegacySignature $runText)
            ) {
                $shouldConvert = $true
            }
            if ($shouldConvert) {
                $mode = Get-ConversionMode $runText
                foreach ($textNode in $textNodes) {
                    $textNode.InnerText = Convert-ByMode $textNode.InnerText $mode
                }
            }

            if ($null -ne $properties) {
                $font = $properties.SelectSingleNode("s:rFont", $namespaceManager)
                if (
                    $null -ne $font -and
                    $legacyFonts -contains $font.GetAttribute("val")
                ) {
                    $font.SetAttribute("val", $replacementFont)
                }
            }
        }
        return
    }

    $textNodes = $container.SelectNodes("s:t", $namespaceManager)
    $text = ""
    foreach ($textNode in $textNodes) {
        $text += $textNode.InnerText
    }
    if ($force -or ($allowFallback -and (Test-TextHasLegacySignature $text))) {
        $mode = Get-ConversionMode $text
        foreach ($textNode in $textNodes) {
            $textNode.InnerText = Convert-ByMode $textNode.InnerText $mode
        }
    }
}

function Get-CellStyleFlags($stylesDocument) {
    $flags = New-Object System.Collections.ArrayList
    if ($null -eq $stylesDocument) { return $flags }
    $namespaceManager = Get-SpreadsheetNamespaceManager $stylesDocument

    $fontFlags = New-Object System.Collections.ArrayList
    foreach ($font in $stylesDocument.SelectNodes(
        "/s:styleSheet/s:fonts/s:font",
        $namespaceManager
    )) {
        $name = $font.SelectSingleNode("s:name", $namespaceManager)
        $value = if ($null -eq $name) { "" } else { $name.GetAttribute("val") }
        if ($legacyFonts -contains $value) {
            [void]$fontFlags.Add("legacy")
        } elseif (-not [string]::IsNullOrWhiteSpace($value)) {
            [void]$fontFlags.Add("normal")
        } else {
            [void]$fontFlags.Add("unknown")
        }
    }

    foreach ($cellFormat in $stylesDocument.SelectNodes(
        "/s:styleSheet/s:cellXfs/s:xf",
        $namespaceManager
    )) {
        $fontId = 0
        if (
            -not [int]::TryParse(
                $cellFormat.GetAttribute("fontId"),
                [ref]$fontId
            ) -or
            $fontId -lt 0 -or
            $fontId -ge $fontFlags.Count
        ) {
            [void]$flags.Add("unknown")
        } else {
            [void]$flags.Add($fontFlags[$fontId])
        }
    }
    return $flags
}

function Get-CellStyleFlag($cell, $styleFlags) {
    $styleId = 0
    if (
        -not [int]::TryParse($cell.GetAttribute("s"), [ref]$styleId) -or
        $styleId -lt 0 -or
        $styleId -ge $styleFlags.Count
    ) {
        return "unknown"
    }
    return $styleFlags[$styleId]
}

function Rename-StyleFonts($stylesDocument) {
    if ($null -eq $stylesDocument) { return }
    $namespaceManager = Get-SpreadsheetNamespaceManager $stylesDocument
    foreach ($name in $stylesDocument.SelectNodes("//s:name", $namespaceManager)) {
        if ($legacyFonts -contains $name.GetAttribute("val")) {
            $name.SetAttribute("val", $replacementFont)
        }
    }
}

function Update-ZipEntry($zip, [string]$entryName, [string]$newContent) {
    $entry = $zip.GetEntry($entryName)
    if ($null -eq $entry) { return }
    $stream = $entry.Open()
    $stream.SetLength(0)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($stream, $utf8NoBom)
    $writer.Write($newContent)
    $writer.Close()
}

function Read-ZipEntry($zip, [string]$entryName) {
    $entry = $zip.GetEntry($entryName)
    if ($null -eq $entry) { return $null }
    $stream = $entry.Open()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    $content = $reader.ReadToEnd()
    $reader.Close()
    return $content
}

# ---------------------------------------------------------------------------
$sourceFile = Get-Item -LiteralPath $Path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $targetName = $sourceFile.BaseName + " (Unicode)" + $sourceFile.Extension
    $targetPath = Join-Path $sourceFile.DirectoryName $targetName
} else {
    $targetPath = [IO.Path]::GetFullPath($OutputPath)
}
if ($sourceFile.Extension -ine ".xlsx") {
    throw "The Excel conversion engine only accepts .xlsx input."
}
if ($sourceFile.FullName -ieq $targetPath) {
    throw "The output path must be different from the source path."
}

Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetPath -Force

$zip = [System.IO.Compression.ZipFile]::Open($targetPath, "Update")
try {
    $stylesDocument = $null
    $stylesXml = Read-ZipEntry $zip "xl/styles.xml"
    if ($null -ne $stylesXml) {
        $stylesDocument = New-Object System.Xml.XmlDocument
        $stylesDocument.PreserveWhitespace = $true
        $stylesDocument.LoadXml($stylesXml)
    }
    $styleFlags = Get-CellStyleFlags $stylesDocument

    $sharedDocument = $null
    $sharedXml = Read-ZipEntry $zip "xl/sharedStrings.xml"
    if ($null -ne $sharedXml) {
        $sharedDocument = New-Object System.Xml.XmlDocument
        $sharedDocument.PreserveWhitespace = $true
        $sharedDocument.LoadXml($sharedXml)
    }

    $worksheetNames = @()
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '^xl/worksheets/[^/]+\.xml$') {
            $worksheetNames += $entry.FullName
        }
    }

    $worksheetDocuments = @{}
    $sharedReferences = @{}
    foreach ($worksheetName in $worksheetNames) {
        $worksheetXml = Read-ZipEntry $zip $worksheetName
        if ($null -eq $worksheetXml) { continue }

        $worksheetDocument = New-Object System.Xml.XmlDocument
        $worksheetDocument.PreserveWhitespace = $true
        $worksheetDocument.LoadXml($worksheetXml)
        $worksheetDocuments[$worksheetName] = $worksheetDocument
        $namespaceManager = Get-SpreadsheetNamespaceManager $worksheetDocument

        foreach ($cell in $worksheetDocument.SelectNodes("//s:c", $namespaceManager)) {
            $styleFlag = Get-CellStyleFlag $cell $styleFlags
            $cellType = $cell.GetAttribute("t")

            if ($cellType -eq "s") {
                $value = $cell.SelectSingleNode("s:v", $namespaceManager)
                $index = 0
                if (
                    $null -eq $value -or
                    -not [int]::TryParse($value.InnerText, [ref]$index)
                ) {
                    continue
                }
                if (-not $sharedReferences.ContainsKey($index)) {
                    $sharedReferences[$index] = @{
                        legacy = New-Object System.Collections.ArrayList
                        normal = New-Object System.Collections.ArrayList
                        unknown = New-Object System.Collections.ArrayList
                    }
                }
                [void]$sharedReferences[$index][$styleFlag].Add($value)
            }
            elseif ($cellType -eq "inlineStr") {
                $inlineString = $cell.SelectSingleNode("s:is", $namespaceManager)
                if ($null -ne $inlineString) {
                    Convert-StringContainer `
                        $inlineString `
                        ($styleFlag -eq "legacy") `
                        ($styleFlag -eq "unknown")
                }
            }
        }
    }

    if ($null -ne $sharedDocument) {
        $namespaceManager = Get-SpreadsheetNamespaceManager $sharedDocument
        $sharedStrings = @($sharedDocument.SelectNodes(
            "/s:sst/s:si",
            $namespaceManager
        ))

        for ($index = 0; $index -lt $sharedStrings.Count; $index++) {
            $sharedString = $sharedStrings[$index]
            $references = if ($sharedReferences.ContainsKey($index)) {
                $sharedReferences[$index]
            } else {
                @{
                    legacy = New-Object System.Collections.ArrayList
                    normal = New-Object System.Collections.ArrayList
                    unknown = New-Object System.Collections.ArrayList
                }
            }

            $hasLegacy = $references.legacy.Count -gt 0
            $hasOther = (
                $references.normal.Count -gt 0 -or
                $references.unknown.Count -gt 0
            )

            if ($hasLegacy -and $hasOther) {
                $convertedCopy = $sharedString.CloneNode($true)
                Convert-StringContainer $convertedCopy $true $false
                [void]$sharedDocument.DocumentElement.AppendChild($convertedCopy)
                $newIndex = $sharedDocument.SelectNodes(
                    "/s:sst/s:si",
                    $namespaceManager
                ).Count - 1
                foreach ($value in $references.legacy) {
                    $value.InnerText = [string]$newIndex
                }
                Convert-StringContainer `
                    $sharedString `
                    $false `
                    (
                        $references.unknown.Count -gt 0 -and
                        $references.normal.Count -eq 0
                    )
            } else {
                Convert-StringContainer `
                    $sharedString `
                    $hasLegacy `
                    ($references.unknown.Count -gt 0)
            }
        }

        $uniqueCount = $sharedDocument.SelectNodes(
            "/s:sst/s:si",
            $namespaceManager
        ).Count
        $sharedDocument.DocumentElement.SetAttribute(
            "uniqueCount",
            [string]$uniqueCount
        )
        Update-ZipEntry $zip "xl/sharedStrings.xml" $sharedDocument.OuterXml
    }

    foreach ($worksheetName in $worksheetDocuments.Keys) {
        Update-ZipEntry `
            $zip `
            $worksheetName `
            $worksheetDocuments[$worksheetName].OuterXml
    }

    if ($null -ne $stylesDocument) {
        Rename-StyleFonts $stylesDocument
        Update-ZipEntry $zip "xl/styles.xml" $stylesDocument.OuterXml
    }
}
finally {
    $zip.Dispose()
}

Write-Output $targetPath
exit 0
