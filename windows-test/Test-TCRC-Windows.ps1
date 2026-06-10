param(
    [switch]$KeepInstalled
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$installer = Join-Path $scriptFolder "TCRC-Youtso-Unicode-Setup.exe"
$legacyDocument = Join-Path $scriptFolder "tcrc-test.docx"
$referenceDocument = Join-Path $scriptFolder "tcrc-test (Unicode).docx"

$installFolder = Join-Path $env:ProgramFiles "TCRC Tibetan Unicode"
$keyboardExe = Join-Path $installFolder "TCRC-Tibetan-Keyboard.exe"
$keyboardScript = Join-Path `
    $installFolder `
    "TCRC-Tibetan-Unicode-Keyboard.ahk"
$converterExe = Join-Path $installFolder "TCRC-Document-Converter.exe"
$converterUi = Join-Path $installFolder "TCRC-Document-Converter.ahk"
$controller = Join-Path $installFolder "convert-document.ps1"
$converterEngine = Join-Path $installFolder "convert-docx.ps1"
$fontFile = Join-Path `
    $env:WINDIR `
    "Fonts\TCRC-Youtso-Unicode-fixed.ttf"
$excelNumberFontFile = Join-Path `
    $env:WINDIR `
    "Fonts\TCRC-Youtso-Excel-Numbers.ttf"
$uninstaller = Join-Path $installFolder "uninstall.exe"

$startMenuConverter = Join-Path $env:ProgramData `
    "Microsoft\Windows\Start Menu\Programs\TCRC Youtso Unicode\TCRC Document Converter.lnk"
$desktopConverter = Join-Path `
    ([Environment]::GetFolderPath("CommonDesktopDirectory")) `
    "TCRC Document Converter.lnk"
$docContextMenu = "Registry::HKEY_LOCAL_MACHINE\Software\Classes\SystemFileAssociations\.doc\shell\TCRCConvertLegacy\command"
$docxContextMenu = "Registry::HKEY_LOCAL_MACHINE\Software\Classes\SystemFileAssociations\.docx\shell\TCRCConvertLegacy\command"

$testFolder = Join-Path $env:TEMP "TCRC-Windows-Test"
$testDocument = Join-Path $testFolder "tcrc-test.docx"
$unicodeDocument = Join-Path $testFolder "tcrc-test (Unicode).docx"
$statusFile = Join-Path $testFolder "status.txt"

function Assert-True([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw $message
    }
    Write-Host "[PASS] $message"
}

function Stop-TcrcProcesses {
    Get-Process -Name "TCRC-Tibetan-Keyboard" `
        -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "TCRC-Document-Converter" `
        -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Read-ZipEntryText([string]$archivePath, [string]$entryName) {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entry = $archive.GetEntry($entryName)
        if ($null -eq $entry) {
            throw "Missing ZIP entry: $entryName"
        }
        $reader = New-Object IO.StreamReader($entry.Open())
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $archive.Dispose()
    }
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object `
    Security.Principal.WindowsPrincipal($currentIdentity)
$isAdministrator = $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdministrator) {
    throw "Run this script from an Administrator PowerShell window."
}

Assert-True (Test-Path $installer) "Installer is present"
Assert-True (Test-Path $legacyDocument) "Legacy test document is present"
Assert-True (Test-Path $referenceDocument) "Unicode reference is present"

Write-Host "Installing TCRC Youtso Unicode..."
$installProcess = Start-Process `
    -FilePath $installer `
    -ArgumentList "/S" `
    -Wait `
    -PassThru
Assert-True (
    $installProcess.ExitCode -eq 0
) "Silent installer exited successfully"

try {
    Assert-True (Test-Path $keyboardExe) "Keyboard runtime is installed"
    Assert-True (Test-Path $keyboardScript) "Keyboard script is installed"
    Assert-True (Test-Path $converterExe) "Converter runtime is installed"
    Assert-True (Test-Path $converterUi) "Converter interface is installed"
    Assert-True (Test-Path $controller) "Converter controller is installed"
    Assert-True (
        Test-Path $converterEngine
    ) "Converter engine is installed"
    Assert-True (Test-Path $fontFile) "Unicode font file is installed"
    Assert-True (
        Test-Path $excelNumberFontFile
    ) "Excel number font file is installed"
    Assert-True (
        Test-Path $startMenuConverter
    ) "Converter Start menu shortcut is installed"
    Assert-True (
        Test-Path $desktopConverter
    ) "Converter desktop shortcut is installed"

    foreach ($contextMenuKey in @($docContextMenu, $docxContextMenu)) {
        $command = Get-ItemPropertyValue `
            -LiteralPath $contextMenuKey `
            -Name "(default)"
        Assert-True (
            $command -like "*TCRC-Document-Converter.exe*"
        ) "Word right-click command opens the visible converter"
    }

    $fontRegistration = Get-ItemPropertyValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
        -Name "TCRC Youtso Unicode (TrueType)"
    Assert-True (
        $fontRegistration -eq "TCRC-Youtso-Unicode-fixed.ttf"
    ) "Unicode font is registered with Windows"

    $excelFontRegistration = Get-ItemPropertyValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
        -Name "TCRC Youtso Excel Numbers (TrueType)"
    Assert-True (
        $excelFontRegistration -eq "TCRC-Youtso-Excel-Numbers.ttf"
    ) "Excel number font is registered with Windows"

    $fontSubstitute = Get-ItemPropertyValue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" `
        -Name "Microsoft Himalaya" `
        -ErrorAction SilentlyContinue
    Assert-True (
        $fontSubstitute -ne "TCRC Youtso Unicode"
    ) "Installer does not replace Microsoft Himalaya"

    $startupCommand = Get-ItemPropertyValue `
        -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name "TCRCTibetanKeyboard"
    Assert-True (
        $startupCommand -like "*TCRC-Tibetan-Keyboard.exe*"
    ) "Keyboard is registered to start at login"

    Stop-TcrcProcesses
    $keyboardProcess = Start-Process `
        -FilePath $keyboardExe `
        -ArgumentList "`"$keyboardScript`"" `
        -PassThru
    Start-Sleep -Seconds 2
    Assert-True (
        Get-Process -Id $keyboardProcess.Id -ErrorAction SilentlyContinue
    ) "Keyboard application starts"
    Stop-TcrcProcesses

    Remove-Item $testFolder -Recurse -Force -ErrorAction SilentlyContinue
    New-Item $testFolder -ItemType Directory | Out-Null
    Copy-Item $legacyDocument $testDocument

    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File $controller `
        -Path $testDocument `
        -StatusFile $statusFile | Out-Host
    Assert-True (Test-Path $unicodeDocument) "Legacy document converts"
    Assert-True (
        (Get-Content -LiteralPath $statusFile -First 1) -eq "OK"
    ) "Converter controller reports success"
    Assert-True (Test-Path $testDocument) "Original document is preserved"

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $documentXml = Read-ZipEntryText `
        $unicodeDocument `
        "word/document.xml"
    $referenceXml = Read-ZipEntryText `
        $referenceDocument `
        "word/document.xml"
    Assert-True (
        $documentXml -match "[\u0F00-\u0FFF]"
    ) "Converted document contains Unicode Tibetan"
    Assert-True (
        $documentXml -notmatch 'w:ascii="TCRC Youtso"'
    ) "Converted document no longer uses the legacy font"
    Assert-True (
        $documentXml -ceq $referenceXml
    ) "Converted text and formatting match the verified reference"

    $word = $null
    $document = $null
    try {
        $word = New-Object -ComObject Word.Application
        $word.Visible = $false
        $document = $word.Documents.Open(
            $unicodeDocument,
            $false,
            $true,
            $false
        )
        Assert-True (
            $document.Content.Text -match "[\u0F00-\u0FFF]"
        ) "Microsoft Word opens the Unicode document"
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

    $excel = $null
    $workbook = $null
    $worksheet = $null
    $numberCells = $null
    $resultCell = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false

        $workbook = $excel.Workbooks.Add()
        $worksheet = $workbook.Worksheets.Item(1)
        $numberCells = $worksheet.Range("A1:A3")
        $resultCell = $worksheet.Range("A3")

        $worksheet.Range("A1").Value2 = 125
        $worksheet.Range("A2").Value2 = 75
        $resultCell.Formula = "=SUM(A1:A2)"
        $numberCells.Font.Name = "TCRC Youtso Excel Numbers"
        $excel.CalculateFull()

        Assert-True (
            [double]$resultCell.Value2 -eq 200
        ) "Excel calculates Tibetan-displayed numeric cells"
        Assert-True (
            $numberCells.Font.Name -eq "TCRC Youtso Excel Numbers"
        ) "Excel applies the Tibetan number display font"
    }
    finally {
        if ($null -ne $workbook) {
            $workbook.Close($false)
        }
        if ($null -ne $excel) {
            $excel.Quit()
        }

        foreach ($comObject in @(
            $resultCell,
            $numberCells,
            $worksheet,
            $workbook,
            $excel
        )) {
            if ($null -ne $comObject) {
                [Runtime.InteropServices.Marshal]::ReleaseComObject(
                    $comObject
                ) | Out-Null
            }
        }

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }

    $converterProcess = Start-Process `
        -FilePath $converterExe `
        -ArgumentList "`"$converterUi`" `"$testDocument`"" `
        -PassThru
    Start-Sleep -Seconds 2
    Assert-True (
        Get-Process -Id $converterProcess.Id -ErrorAction SilentlyContinue
    ) "Visible converter application starts"
    Stop-TcrcProcesses

    Write-Host ""
    Write-Host "All automated Windows, Word, and Excel checks passed."
    Write-Host "Manual final check:"
    Write-Host "1. Open TCRC Document Converter from the desktop."
    Write-Host "2. Choose tcrc-test.docx and select Convert to Unicode."
    Write-Host "3. Confirm the result opens and the original is unchanged."
    Write-Host "4. Start the Tibetan Keyboard and test Ctrl+Alt+T."
    Write-Host "5. In Excel, select cells and press Ctrl+Alt+N."
    Write-Host "6. Enter 125 and 75, then confirm SUM returns 200."
}
finally {
    Stop-TcrcProcesses
    if (-not $KeepInstalled -and (Test-Path $uninstaller)) {
        Write-Host "Uninstalling test installation..."
        Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait
    }
}
