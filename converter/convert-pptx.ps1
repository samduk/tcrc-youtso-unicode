# convert-pptx.ps1 - fast file-based legacy TCRC -> Unicode conversion
# for PowerPoint .pptx files. PowerShell port of convert_pptx.py.
#
# Usage:  powershell -ExecutionPolicy Bypass -File convert-pptx.ps1 -Path "deck.pptx"
# Result: a new file "deck (Unicode).pptx" next to the original.

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

# DrawingML: a run is <a:r>...</a:r>, its text is <a:t>...</a:t>
$runPattern = [regex]'(?s)<a:r\b[^>]*>.*?</a:r>'
$textPattern = [regex]'(?s)(<a:t(?:\s[^>]*)?>)(.*?)(</a:t>)'
$partPattern = [regex]'^ppt/(slides|slideLayouts|slideMasters|notesSlides|notesMasters)/[^/]+\.xml$'

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

function Test-RunNeedsConversion([string]$runXml) {
    foreach ($fontName in $legacyFonts) {
        if ($runXml.Contains('typeface="' + $fontName + '"')) { return $true }
    }
    # re-fonted legacy text: new font name, legacy characters inside.
    # Only 0xA0-0xFF characters are PROOF of legacy text (an em-dash
    # appears in normal English too and must not trigger).
    if ($runXml.Contains('typeface="' + $replacementFont + '"')) {
        foreach ($textMatch in $textPattern.Matches($runXml)) {
            $plainText = [System.Net.WebUtility]::HtmlDecode($textMatch.Groups[2].Value)
            foreach ($character in $plainText.ToCharArray()) {
                $code = [int]$character
                if (($code -ge 0xA0) -and ($code -le 0xFF) -and $table.ContainsKey($code)) {
                    return $true
                }
            }
        }
    }
    return $false
}

function Convert-Run([string]$runXml) {
    $builder = New-Object System.Text.StringBuilder
    $position = 0
    foreach ($match in $textPattern.Matches($runXml)) {
        [void]$builder.Append($runXml.Substring($position, $match.Index - $position))
        $plainText = [System.Net.WebUtility]::HtmlDecode($match.Groups[2].Value)
        $unicodeText = Convert-LegacyText $plainText
        $safeText = $unicodeText.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
        [void]$builder.Append($match.Groups[1].Value + $safeText + $match.Groups[3].Value)
        $position = $match.Index + $match.Length
    }
    [void]$builder.Append($runXml.Substring($position))
    return $builder.ToString()
}

function Convert-PartXml([string]$xml) {
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

    foreach ($fontName in $legacyFonts) {
        $result = $result.Replace('typeface="' + $fontName + '"',
                                  'typeface="' + $replacementFont + '"')
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
if ($sourceFile.Extension -ine ".pptx") {
    throw "The PowerPoint conversion engine only accepts .pptx input."
}
if ($sourceFile.FullName -ieq $targetPath) {
    throw "The output path must be different from the source path."
}

Copy-Item -LiteralPath $sourceFile.FullName -Destination $targetPath -Force

$zip = [System.IO.Compression.ZipFile]::Open($targetPath, "Update")
try {
    $slideParts = @()
    foreach ($entry in $zip.Entries) {
        if ($partPattern.IsMatch($entry.FullName)) {
            $slideParts += $entry.FullName
        }
    }
    foreach ($slidePart in $slideParts) {
        $xml = Read-ZipEntry $zip $slidePart
        if ($null -ne $xml) {
            Update-ZipEntry $zip $slidePart (Convert-PartXml $xml)
        }
    }
}
finally {
    $zip.Dispose()
}

Write-Output $targetPath
exit 0
