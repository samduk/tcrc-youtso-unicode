# convert-docx.ps1 - fast file-based legacy TCRC -> Unicode conversion.
#
# This is a PowerShell port of convert_docx.py, used by the keyboard app
# for instant conversion of big Word documents (PowerShell is built into
# every Windows computer, so users need to install nothing).
#
# Usage:  powershell -ExecutionPolicy Bypass -File convert-docx.ps1 -Path "doc.docx"
# Result: a new file "doc (Unicode).docx" next to the original.
#         The original file is never modified.

param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------------------------------------------------------------
# Load the conversion table (legacy character code -> Unicode Tibetan text).
# ---------------------------------------------------------------------------
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$mapFile = Join-Path $scriptFolder "tcrc_to_unicode_map.json"
$json = Get-Content -Raw -Encoding UTF8 $mapFile | ConvertFrom-Json

$table = @{}
foreach ($property in $json.PSObject.Properties) {
    $table[[int]$property.Name] = $property.Value
}

$legacyFonts = @("TCRC Bod-Yig", "TCRC Youtsoweb", "TCRC Youtso")
$replacementFont = "TCRC Youtso Unicode"
# characters that appear in legacy Tibetan text but almost never in English
$signatureChars = @("ü", "Û", "ô", "Å", "¾", "º", "Ç", "¿", "¼", "½")

# ---------------------------------------------------------------------------
# Helper functions.
# ---------------------------------------------------------------------------
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
    # NFC normalization puts Tibetan vowel signs into the standard order.
    return $builder.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Test-RunNeedsConversion([string]$runXml) {
    foreach ($fontName in $legacyFonts) {
        if ($runXml.Contains($fontName)) { return $true }
    }
    # re-fonted legacy text: new font name but legacy characters inside
    if ($runXml.Contains($replacementFont)) {
        foreach ($signature in $signatureChars) {
            if ($runXml.Contains($signature)) { return $true }
        }
    }
    return $false
}

$textPattern = [regex]'(?s)(<w:t(?:\s[^>]*)?>)(.*?)(</w:t>)'
$runPattern = [regex]'(?s)<w:r\b[^>]*>.*?</w:r>'

function Convert-Run([string]$runXml) {
    $builder = New-Object System.Text.StringBuilder
    $position = 0
    foreach ($match in $textPattern.Matches($runXml)) {
        [void]$builder.Append($runXml.Substring($position, $match.Index - $position))
        $openingTag = $match.Groups[1].Value
        $text = $match.Groups[2].Value
        $closingTag = $match.Groups[3].Value

        # XML stores & as &amp; etc. - decode, convert, encode again
        $plainText = [System.Net.WebUtility]::HtmlDecode($text)
        $unicodeText = Convert-LegacyText $plainText
        $safeText = $unicodeText.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")

        [void]$builder.Append($openingTag + $safeText + $closingTag)
        $position = $match.Index + $match.Length
    }
    [void]$builder.Append($runXml.Substring($position))
    return $builder.ToString()
}

function Convert-DocumentXml([string]$xml) {
    $builder = New-Object System.Text.StringBuilder
    $position = 0
    foreach ($match in $runPattern.Matches($xml)) {
        [void]$builder.Append($xml.Substring($position, $match.Index - $position))
        $run = $match.Value
        if (Test-RunNeedsConversion $run) {
            $run = Convert-Run $run
        }
        [void]$builder.Append($run)
        $position = $match.Index + $match.Length
    }
    [void]$builder.Append($xml.Substring($position))
    $result = $builder.ToString()

    # change the font names (quoted, so "TCRC Youtso" cannot wrongly
    # match inside "TCRC Youtso Unicode")
    foreach ($fontName in $legacyFonts) {
        $result = $result.Replace('"' + $fontName + '"', '"' + $replacementFont + '"')
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
# Main: copy the original, then convert the copy in place.
# ---------------------------------------------------------------------------
$sourceFile = Get-Item -LiteralPath $Path
$targetName = $sourceFile.BaseName + " (Unicode)" + $sourceFile.Extension
$targetPath = Join-Path $sourceFile.DirectoryName $targetName

Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetPath -Force

$zip = [System.IO.Compression.ZipFile]::Open($targetPath, "Update")
try {
    $documentXml = Read-ZipEntry $zip "word/document.xml"
    if ($null -ne $documentXml) {
        Update-ZipEntry $zip "word/document.xml" (Convert-DocumentXml $documentXml)
    }

    $stylesXml = Read-ZipEntry $zip "word/styles.xml"
    if ($null -ne $stylesXml) {
        foreach ($fontName in $legacyFonts) {
            $stylesXml = $stylesXml.Replace('"' + $fontName + '"', '"' + $replacementFont + '"')
        }
        Update-ZipEntry $zip "word/styles.xml" $stylesXml
    }
}
finally {
    $zip.Dispose()
}

Write-Output $targetPath
exit 0
