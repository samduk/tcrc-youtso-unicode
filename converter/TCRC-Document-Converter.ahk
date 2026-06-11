; Visible Windows interface for converting legacy TCRC Office documents
; (Word, PowerPoint, and Excel).

#Requires AutoHotkey v2.0
#SingleInstance Force

global AppTitle := "TCRC Document Converter"
global SourcePath := ""
global LastResult := ""

global MainWindow := Gui("+OwnDialogs +MinSize620x360", AppTitle)
MainWindow.BackColor := "FFFFFF"
MainWindow.MarginX := 24
MainWindow.MarginY := 22
MainWindow.SetFont("s10", "Segoe UI")

MainWindow.SetFont("s18 Bold c17365D", "Segoe UI")
MainWindow.AddText("xm ym w570 Center", "TCRC Document Converter")

MainWindow.SetFont("s10 Norm c303030", "Segoe UI")
MainWindow.AddText(
    "xm y+14 w570 Center",
    "Convert old TCRC Youtso / TCRC Bod-Yig Word, PowerPoint, and Excel files to Unicode."
)
MainWindow.AddText(
    "xm y+4 w570 Center",
    "Your original document is never changed."
)

MainWindow.SetFont("s9 Norm c606060", "Segoe UI")
MainWindow.AddText(
    "xm y+22 w570 Center",
    "Choose a Word, PowerPoint, or Excel file, or drag it onto this window."
)

global PathBox := MainWindow.AddEdit(
    "xm y+10 w450 h28 ReadOnly BackgroundF4F6F8"
)
global BrowseButton := MainWindow.AddButton(
    "x+10 yp-1 w110 h30",
    "Choose file..."
)

global ConvertButton := MainWindow.AddButton(
    "xm y+20 w570 h44 Default Disabled",
    "Convert to Unicode"
)

global OpenAfterConvert := MainWindow.AddCheckbox(
    "xm y+14 Checked",
    "Open the converted document when finished"
)

global StatusText := MainWindow.AddText(
    "xm y+18 w570 h42 Center c505050",
    "Ready."
)

global OpenFolderButton := MainWindow.AddButton(
    "xm y+8 w570 h32 Disabled",
    "Show converted file in folder"
)

BrowseButton.OnEvent("Click", ChooseDocument)
ConvertButton.OnEvent("Click", ConvertDocument)
OpenFolderButton.OnEvent("Click", ShowResultInFolder)
MainWindow.OnEvent("DropFiles", HandleDroppedFiles)
MainWindow.OnEvent("Close", (*) => ExitApp())

if (A_Args.Length > 0)
    SetSourceFile(A_Args[1])

MainWindow.Show("w620 h390")

ChooseDocument(*) {
    selected := FileSelect(
        3,
        "",
        "Choose a legacy TCRC Office document",
        "Office documents (*.doc; *.docx; *.ppt; *.pptx; *.xls; *.xlsx)"
    )
    if (selected != "")
        SetSourceFile(selected)
}

HandleDroppedFiles(guiObj, guiCtrlObj, files, x, y) {
    if (files.Length > 0)
        SetSourceFile(files[1])
}

SetSourceFile(path) {
    global SourcePath, LastResult, PathBox, ConvertButton
    global OpenFolderButton, StatusText

    path := Trim(path, '"')
    attributes := FileExist(path)
    if (attributes = "" || InStr(attributes, "D")) {
        MsgBox "That file could not be found.", AppTitle, "Iconx"
        return
    }

    SplitPath path, , , &extension
    extension := StrLower(extension)
    supported := ["doc", "docx", "ppt", "pptx", "xls", "xlsx"]
    isSupported := false
    for supportedExtension in supported {
        if (extension = supportedExtension)
            isSupported := true
    }
    if (!isSupported) {
        MsgBox(
            "Please choose a Word, PowerPoint, or Excel file`n(.doc/.docx/.ppt/.pptx/.xls/.xlsx).",
            AppTitle,
            "Icon!"
        )
        return
    }

    SourcePath := path
    LastResult := ""
    PathBox.Value := path
    ConvertButton.Enabled := true
    OpenFolderButton.Enabled := false
    StatusText.Value := "Ready to convert."
}

ConvertDocument(*) {
    global SourcePath, LastResult, ConvertButton, BrowseButton
    global OpenFolderButton, OpenAfterConvert, StatusText

    if (SourcePath = "")
        return

    SplitPath SourcePath, , &folder, &extension, &nameOnly
    if InStr(nameOnly, " (Unicode)") {
        MsgBox(
            "This file already appears to be a Unicode copy.",
            AppTitle,
            "Iconi"
        )
        return
    }

    ; old binary formats are saved as their modern equivalent
    modernExtension := StrLower(extension)
    if (modernExtension = "doc")
        modernExtension := "docx"
    else if (modernExtension = "ppt")
        modernExtension := "pptx"
    else if (modernExtension = "xls")
        modernExtension := "xlsx"
    target := folder "\" nameOnly " (Unicode)." modernExtension
    if FileExist(target) {
        answer := MsgBox(
            "A converted copy already exists.`n`n" target
                "`n`nReplace it?",
            AppTitle,
            "YesNo Icon?"
        )
        if (answer != "Yes")
            return
    }

    controller := A_ScriptDir "\convert-document.ps1"
    if !FileExist(controller) {
        MsgBox(
            "The converter installation is incomplete. Reinstall the application.",
            AppTitle,
            "Iconx"
        )
        return
    }

    statusFile := A_Temp "\TCRC-Convert-" A_TickCount ".txt"
    try FileDelete statusFile

    ConvertButton.Enabled := false
    BrowseButton.Enabled := false
    OpenFolderButton.Enabled := false
    StatusText.Value := "Converting... Please wait."
    Sleep 50

    command := 'powershell.exe -NoLogo -NoProfile -NonInteractive '
        . '-ExecutionPolicy Bypass -File "' controller
        . '" -Path "' SourcePath '" -StatusFile "' statusFile '"'

    exitCode := -1
    try exitCode := RunWait(command, A_ScriptDir, "Hide")

    status := ""
    if FileExist(statusFile) {
        try status := FileRead(statusFile, "UTF-8")
        try FileDelete statusFile
    }

    ConvertButton.Enabled := true
    BrowseButton.Enabled := true

    if (exitCode != 0 || SubStr(status, 1, 2) != "OK") {
        message := "The document could not be converted."
        separator := InStr(status, "`n")
        if (separator > 0)
            message .= "`n`n" Trim(SubStr(status, separator + 1), "`r`n ")
        message .= "`n`nClose the file in its Office application and try again."
        StatusText.Value := "Conversion failed."
        MsgBox message, AppTitle, "Iconx"
        return
    }

    separator := InStr(status, "`n")
    LastResult := separator > 0
        ? Trim(SubStr(status, separator + 1), "`r`n ")
        : target
    OpenFolderButton.Enabled := true
    StatusText.Value := "Finished. The Unicode copy is ready."

    if (OpenAfterConvert.Value)
        Run '"' LastResult '"'
}

ShowResultInFolder(*) {
    global LastResult
    if (LastResult != "" && FileExist(LastResult))
        Run 'explorer.exe /select,"' LastResult '"'
}
