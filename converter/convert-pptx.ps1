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

$partPattern = [regex]'^ppt/(slides|slideLayouts|slideMasters|notesSlides|notesMasters)/[^/]+\.xml$'
$drawingNamespace = "http://schemas.openxmlformats.org/drawingml/2006/main"

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
    foreach ($character in $text.ToCharArray()) {
        $code = [int]$character
        if (($code -ge 0xA0) -and ($code -le 0xFF) -and $table.ContainsKey($code)) {
            return $true
        }
    }
    return $false
}

function Test-TextLooksLegacyWithoutFont([string]$text) {
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

function Get-DrawingFont($properties, $namespaceManager) {
    if ($null -eq $properties) { return $null }
    foreach ($elementName in @("latin", "cs", "ea")) {
        $fontNode = $properties.SelectSingleNode("a:" + $elementName, $namespaceManager)
        if ($null -ne $fontNode -and $fontNode.HasAttribute("typeface")) {
            return $fontNode.GetAttribute("typeface")
        }
    }
    return $null
}

function Convert-PartXml([string]$xml) {
    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.LoadXml($xml)
    $namespaceManager = New-Object System.Xml.XmlNamespaceManager($document.NameTable)
    $namespaceManager.AddNamespace("a", $drawingNamespace)

    foreach ($paragraph in $document.SelectNodes("//a:p", $namespaceManager)) {
        $paragraphProperties = $paragraph.SelectSingleNode("a:pPr", $namespaceManager)
        $inheritedFont = $null
        $level = 0
        if ($null -ne $paragraphProperties) {
            $inheritedFont = Get-DrawingFont `
                ($paragraphProperties.SelectSingleNode("a:defRPr", $namespaceManager)) `
                $namespaceManager
            if ($paragraphProperties.HasAttribute("lvl")) {
                [void][int]::TryParse(
                    $paragraphProperties.GetAttribute("lvl"),
                    [ref]$level
                )
            }
        }

        if ([string]::IsNullOrWhiteSpace($inheritedFont)) {
            $textBody = $paragraph.ParentNode
            while ($null -ne $textBody -and $textBody.LocalName -ne "txBody") {
                $textBody = $textBody.ParentNode
            }
            if ($null -ne $textBody) {
                $levelProperties = $textBody.SelectSingleNode(
                    "a:lstStyle/a:lvl" + ($level + 1) + "pPr",
                    $namespaceManager
                )
                if ($null -ne $levelProperties) {
                    $inheritedFont = Get-DrawingFont `
                        ($levelProperties.SelectSingleNode("a:defRPr", $namespaceManager)) `
                        $namespaceManager
                }
            }
        }

        foreach ($run in $paragraph.SelectNodes("a:r", $namespaceManager)) {
            $runFont = Get-DrawingFont `
                ($run.SelectSingleNode("a:rPr", $namespaceManager)) `
                $namespaceManager
            if ([string]::IsNullOrWhiteSpace($runFont)) {
                $runFont = $inheritedFont
            }

            $textNodes = $run.SelectNodes("a:t", $namespaceManager)
            $runText = ""
            foreach ($textNode in $textNodes) {
                $runText += $textNode.InnerText
            }

            $shouldConvert = $legacyFonts -contains $runFont
            if (
                $runFont -eq $replacementFont -and
                (Test-TextHasLegacySignature $runText)
            ) {
                $shouldConvert = $true
            }
            if (
                [string]::IsNullOrWhiteSpace($runFont) -and
                (Test-TextLooksLegacyWithoutFont $runText)
            ) {
                $shouldConvert = $true
            }
            if ($shouldConvert) {
                foreach ($textNode in $textNodes) {
                    $textNode.InnerText = Convert-LegacyText $textNode.InnerText
                }
            }
        }
    }

    foreach ($fontNode in $document.SelectNodes("//*[@typeface]")) {
        if ($legacyFonts -contains $fontNode.GetAttribute("typeface")) {
            $fontNode.SetAttribute("typeface", $replacementFont)
        }
    }
    return $document.OuterXml
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
