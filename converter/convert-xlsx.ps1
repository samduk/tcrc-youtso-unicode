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

$runPattern = [regex]'(?s)<r\b[^>]*>.*?</r>'
$textPattern = [regex]'(?s)(<t(?:\s[^>]*)?>)(.*?)(</t>)'

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

function Test-TextIsLegacy([string]$plainText) {
    # only 0xA0-0xFF characters are PROOF of legacy text; an em-dash etc.
    # appears in normal English and must never trigger a conversion
    foreach ($character in $plainText.ToCharArray()) {
        $code = [int]$character
        if (($code -ge 0xA0) -and ($code -le 0xFF) -and $table.ContainsKey($code)) {
            return $true
        }
    }
    return $false
}

function Convert-TextElement($match, [bool]$force) {
    $plainText = [System.Net.WebUtility]::HtmlDecode($match.Groups[2].Value)
    if (-not $force -and -not (Test-TextIsLegacy $plainText)) {
        return $match.Value
    }
    $unicodeText = Convert-LegacyText $plainText
    $safeText = $unicodeText.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
    return $match.Groups[1].Value + $safeText + $match.Groups[3].Value
}

function Convert-TextsIn([string]$xml, [bool]$force) {
    $builder = New-Object System.Text.StringBuilder
    $position = 0
    foreach ($match in $textPattern.Matches($xml)) {
        [void]$builder.Append($xml.Substring($position, $match.Index - $position))
        [void]$builder.Append((Convert-TextElement $match $force))
        $position = $match.Index + $match.Length
    }
    [void]$builder.Append($xml.Substring($position))
    return $builder.ToString()
}

function Convert-SharedStringsXml([string]$xml) {
    # first the rich runs: a run NAMING a legacy font is converted even
    # if its text happens to be pure ASCII
    $builder = New-Object System.Text.StringBuilder
    $position = 0
    foreach ($match in $runPattern.Matches($xml)) {
        [void]$builder.Append($xml.Substring($position, $match.Index - $position))
        $run = $match.Value
        $namesLegacyFont = $false
        foreach ($fontName in $legacyFonts) {
            if ($run.Contains('val="' + $fontName + '"')) { $namesLegacyFont = $true }
        }
        [void]$builder.Append((Convert-TextsIn $run $namesLegacyFont))
        $position = $match.Index + $match.Length
    }
    [void]$builder.Append($xml.Substring($position))
    $result = $builder.ToString()

    # then everything else (plain strings) with the content test;
    # already-converted text contains no legacy characters, so this
    # second pass cannot damage it
    $result = Convert-TextsIn $result $false

    foreach ($fontName in $legacyFonts) {
        $result = $result.Replace('val="' + $fontName + '"',
                                  'val="' + $replacementFont + '"')
    }
    return $result
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
    $sharedStrings = Read-ZipEntry $zip "xl/sharedStrings.xml"
    if ($null -ne $sharedStrings) {
        Update-ZipEntry $zip "xl/sharedStrings.xml" (Convert-SharedStringsXml $sharedStrings)
    }
    $stylesXml = Read-ZipEntry $zip "xl/styles.xml"
    if ($null -ne $stylesXml) {
        foreach ($fontName in $legacyFonts) {
            $stylesXml = $stylesXml.Replace('val="' + $fontName + '"',
                                            'val="' + $replacementFont + '"')
        }
        Update-ZipEntry $zip "xl/styles.xml" $stylesXml
    }
}
finally {
    $zip.Dispose()
}

Write-Output $targetPath
exit 0
