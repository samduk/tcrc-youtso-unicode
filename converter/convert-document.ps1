# Controller for the TCRC Document Converter UI.
#
# Supported input:
#   .docx / .doc   (Word;        .doc is upgraded through Word itself)
#   .pptx / .ppt   (PowerPoint;  .ppt is upgraded through PowerPoint)
#   .xlsx / .xls   (Excel;       .xls is upgraded through Excel)
#
# The matching engine script (convert-docx.ps1 / convert-pptx.ps1 /
# convert-xlsx.ps1) does the actual conversion. The original file is
# never modified; the result is "name (Unicode).<modern extension>".

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$StatusFile
)

$ErrorActionPreference = "Stop"
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Status([string]$state, [string]$message) {
    if (-not [string]::IsNullOrWhiteSpace($StatusFile)) {
        [IO.File]::WriteAllText(
            $StatusFile,
            $state + "`r`n" + $message,
            $utf8NoBom
        )
    }
}

# ---------------------------------------------------------------------------
# Upgrading old binary formats (.doc/.ppt/.xls) to Open XML, using the
# Office application itself. Each call saves a temporary modern file.
# ---------------------------------------------------------------------------
function Invoke-OfficeSaveAs(
    [string]$application,    # "Word.Application" etc.
    [string]$sourcePath,
    [string]$temporaryPath,
    [int]$saveFormat         # app-specific format number
) {
    $app = $null
    $document = $null
    try {
        $app = New-Object -ComObject $application
        try { $app.Visible = $false } catch { }
        try { $app.DisplayAlerts = 0 } catch { }

        if ($application -eq "Word.Application") {
            $document = $app.Documents.Open($sourcePath, $false, $true, $false)
            $document.SaveAs2($temporaryPath, $saveFormat)
        }
        elseif ($application -eq "PowerPoint.Application") {
            # PowerPoint does not allow Visible = false; open the file
            # without a window instead (ReadOnly, no Untitled, no Window)
            $document = $app.Presentations.Open($sourcePath, $true, $false, $false)
            $document.SaveAs($temporaryPath, $saveFormat)
        }
        else {
            $document = $app.Workbooks.Open($sourcePath, 0, $true)
            $document.SaveAs($temporaryPath, $saveFormat)
        }
    }
    finally {
        if ($null -ne $document) {
            try { $document.Close($false) } catch { try { $document.Close() } catch { } }
            [Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
        }
        if ($null -ne $app) {
            $app.Quit()
            [Runtime.InteropServices.Marshal]::ReleaseComObject($app) | Out-Null
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

trap {
    Write-Status "ERROR" $_.Exception.Message
    Write-Error $_
    exit 1
}

# ---------------------------------------------------------------------------
# Decide which engine and which steps this file needs.
# ---------------------------------------------------------------------------
$source = Get-Item -LiteralPath $Path
$extension = $source.Extension.ToLowerInvariant()

# extension -> engine script, modern extension, and (for old binary
# formats) which Office application upgrades it and with which format code
$plan = $null
switch ($extension) {
    ".docx" { $plan = @{ Engine = "convert-docx.ps1"; Modern = ".docx"; App = "";                       Format = 0  } }
    ".doc"  { $plan = @{ Engine = "convert-docx.ps1"; Modern = ".docx"; App = "Word.Application";       Format = 16 } }
    ".pptx" { $plan = @{ Engine = "convert-pptx.ps1"; Modern = ".pptx"; App = "";                       Format = 0  } }
    ".ppt"  { $plan = @{ Engine = "convert-pptx.ps1"; Modern = ".pptx"; App = "PowerPoint.Application"; Format = 24 } }
    ".xlsx" { $plan = @{ Engine = "convert-xlsx.ps1"; Modern = ".xlsx"; App = "";                       Format = 0  } }
    ".xls"  { $plan = @{ Engine = "convert-xlsx.ps1"; Modern = ".xlsx"; App = "Excel.Application";      Format = 51 } }
}
# format codes: 16 = wdFormatDocumentDefault, 24 = ppSaveAsOpenXMLPresentation,
#               51 = xlOpenXMLWorkbook

if ($null -eq $plan) {
    throw "Please select a Word, PowerPoint, or Excel file (.doc/.docx/.ppt/.pptx/.xls/.xlsx)."
}

$engineScript = Join-Path $scriptFolder $plan.Engine
if (-not (Test-Path -LiteralPath $engineScript)) {
    throw "The converter engine is missing. Reinstall the application."
}
if ($source.BaseName.EndsWith(" (Unicode)", [StringComparison]::OrdinalIgnoreCase)) {
    throw "This file already appears to be a Unicode copy."
}

$targetPath = Join-Path `
    $source.DirectoryName `
    ($source.BaseName + " (Unicode)" + $plan.Modern)

$temporaryModern = $null
$temporaryOutput = Join-Path `
    $source.DirectoryName `
    ("." + $source.BaseName + ".TCRC-" +
        [guid]::NewGuid().ToString("N") + $plan.Modern)
try {
    $inputFile = $source.FullName

    # old binary format? upgrade it to the modern format first
    if ($plan.App -ne "") {
        $temporaryModern = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ("TCRC-" + [guid]::NewGuid().ToString("N") + $plan.Modern)
        Invoke-OfficeSaveAs $plan.App $source.FullName $temporaryModern $plan.Format
        $inputFile = $temporaryModern
    }

    & $engineScript `
        -Path $inputFile `
        -OutputPath $temporaryOutput |
        Out-Null
    if (
        $LASTEXITCODE -ne 0 -or
        -not (Test-Path -LiteralPath $temporaryOutput)
    ) {
        throw "Conversion did not produce the expected Unicode document."
    }
    Move-Item `
        -LiteralPath $temporaryOutput `
        -Destination $targetPath `
        -Force
}
finally {
    if ($null -ne $temporaryModern) {
        Remove-Item -LiteralPath $temporaryModern -Force `
            -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $temporaryOutput -Force `
        -ErrorAction SilentlyContinue
}

Write-Status "OK" $targetPath
Write-Output $targetPath
exit 0
