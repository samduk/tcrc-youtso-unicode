# Controller for the TCRC Document Converter UI.
# Supports modern .docx files directly and old .doc files through Word.

param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$StatusFile
)

$ErrorActionPreference = "Stop"
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$docxConverter = Join-Path $scriptFolder "convert-docx.ps1"
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

function Save-LegacyDocAsDocx(
    [string]$sourcePath,
    [string]$temporaryDocx
) {
    $word = $null
    $document = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $document = $word.Documents.Open(
            $sourcePath,
            $false,
            $true,
            $false
        )
        # 16 = wdFormatDocumentDefault (.docx)
        $document.SaveAs2($temporaryDocx, 16)
    }
    finally {
        if ($null -ne $document) {
            $document.Close($false)
            [Runtime.InteropServices.Marshal]::ReleaseComObject(
                $document
            ) | Out-Null
        }
        if ($null -ne $word) {
            $word.Quit()
            [Runtime.InteropServices.Marshal]::ReleaseComObject(
                $word
            ) | Out-Null
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

if (-not (Test-Path -LiteralPath $docxConverter)) {
    throw "The converter engine is missing. Reinstall the application."
}

$source = Get-Item -LiteralPath $Path
$extension = $source.Extension.ToLowerInvariant()
if ($extension -notin @(".doc", ".docx")) {
    throw "Please select a Microsoft Word .doc or .docx file."
}
if ($source.BaseName.EndsWith(
    " (Unicode)",
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw "This file already appears to be a Unicode copy."
}

$targetPath = Join-Path `
    $source.DirectoryName `
    ($source.BaseName + " (Unicode).docx")

$temporaryDocx = $null
$temporaryOutput = Join-Path `
    $source.DirectoryName `
    ("." + $source.BaseName + ".TCRC-" +
        [guid]::NewGuid().ToString("N") + ".docx")
try {
    $inputDocx = $source.FullName
    if ($extension -eq ".doc") {
        $temporaryDocx = Join-Path `
            ([IO.Path]::GetTempPath()) `
            ("TCRC-" + [guid]::NewGuid().ToString("N") + ".docx")
        Save-LegacyDocAsDocx $source.FullName $temporaryDocx
        $inputDocx = $temporaryDocx
    }

    & $docxConverter `
        -Path $inputDocx `
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
    if ($null -ne $temporaryDocx) {
        Remove-Item -LiteralPath $temporaryDocx -Force `
            -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $temporaryOutput -Force `
        -ErrorAction SilentlyContinue
}

Write-Status "OK" $targetPath
Write-Output $targetPath
exit 0
