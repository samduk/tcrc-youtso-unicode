; TCRC Tibetan Unicode Keyboard for Windows
; Ctrl+Alt+T toggles Tibetan typing on and off.

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global TibOn := true
global LinkPending := false
global PrevChar := ""
global LastChar := ""
global UnicodeFont := "TCRC Youtso Unicode"
global ExcelNumberFont := "TCRC Youtso Unicode"
global FontAppliedWindow := 0
global ExcelEventApplication := 0
global ExcelEventSink := 0
global PendingExcelFormulaSheets := Map()

global IconOn := A_ScriptDir "\tcrc_on.ico"
global IconOff := A_ScriptDir "\tcrc_off.ico"

if FileExist(IconOn)
    TraySetIcon(IconOn, , true)

A_TrayMenu.Add()
A_TrayMenu.Add(
    "Prepare selected Excel cells for Tibetan numbers",
    FormatExcelNumberCells
)

UpdateKeyboardStatus()

ToggleTibetan(*) {
    global TibOn, LinkPending, PrevChar, LastChar
    TibOn := !TibOn
    LinkPending := false
    PrevChar := ""
    LastChar := ""
    UpdateKeyboardStatus()
    if TibOn
        ApplyUnicodeFont()
    else
        DisconnectExcelEvents()
    TrayTip "TCRC Tibetan Keyboard",
        "Tibetan typing " (TibOn ? "ON" : "OFF")
}

UpdateKeyboardStatus() {
    global TibOn, IconOn, IconOff
    icon := TibOn ? IconOn : IconOff
    if FileExist(icon)
        TraySetIcon(icon)
    A_IconTip := "TCRC Tibetan Keyboard - "
        (TibOn ? "ON" : "OFF") " (Ctrl+Alt+T)"
}

^!t::ToggleTibetan()
^!n::FormatExcelNumberCells()

ApplyUnicodeFont() {
    global UnicodeFont, FontAppliedWindow

    activeWindow := WinExist("A")
    if !activeWindow
        return

    try {
        if WinActive("ahk_exe WINWORD.EXE") {
            word := ComObjActive("Word.Application")
            word.Selection.Font.Name := UnicodeFont
            try word.Selection.Font.NameBi := UnicodeFont
            catch {
            }
        } else if WinActive("ahk_exe EXCEL.EXE") {
            excel := ComObjActive("Excel.Application")
            ConnectExcelEvents(excel)
            try excel.Selection.Font.Name := UnicodeFont
            catch {
            }
        } else if WinActive("ahk_exe POWERPNT.EXE") {
            powerpoint := ComObjActive("PowerPoint.Application")
            selection := powerpoint.ActiveWindow.Selection
            try selection.TextRange.Font.Name := UnicodeFont
            catch {
            }
            try selection.TextRange2.Font.Name := UnicodeFont
            catch {
            }
        } else {
            return
        }
        FontAppliedWindow := activeWindow
    } catch {
        return
    }
}

ConnectExcelEvents(excel) {
    global ExcelEventApplication, ExcelEventSink

    try {
        if (
            IsObject(ExcelEventApplication) and
            ExcelEventApplication.Hwnd = excel.Hwnd
        ) {
            return
        }
    } catch {
    }

    DisconnectExcelEvents()
    try {
        ExcelEventSink := ExcelApplicationEvents()
        ComObjConnect(excel, ExcelEventSink)
        ExcelEventApplication := excel
    } catch {
        ExcelEventApplication := 0
        ExcelEventSink := 0
    }
}

DisconnectExcelEvents() {
    global ExcelEventApplication, ExcelEventSink
    global PendingExcelFormulaSheets

    if IsObject(ExcelEventApplication) {
        try ComObjConnect(ExcelEventApplication)
        catch {
        }
    }
    ExcelEventApplication := 0
    ExcelEventSink := 0
    PendingExcelFormulaSheets := Map()
}

FormatExcelFormulaCells(sheet) {
    global TibOn, UnicodeFont

    if !TibOn
        return
    try {
        ; -4123 is Excel's xlCellTypeFormulas constant.
        formulaCells := sheet.UsedRange.SpecialCells(-4123)
        areas := formulaCells.Areas
        Loop areas.Count {
            area := areas.Item(A_Index)
            try {
                if (area.Font.Name != UnicodeFont)
                    area.Font.Name := UnicodeFont
            } catch {
                try area.Font.Name := UnicodeFont
            }
        }
    } catch {
        ; A sheet without formulas raises an exception from SpecialCells.
    }
}

QueueExcelFormulaSheet(sheet) {
    global TibOn, PendingExcelFormulaSheets

    if !TibOn
        return
    try {
        key := sheet.Parent.Name "|" sheet.CodeName
        PendingExcelFormulaSheets[key] := sheet
    } catch {
        ; Chart sheets do not expose the worksheet properties used here.
    }
}

FormatPendingExcelFormulaSheets() {
    global TibOn, PendingExcelFormulaSheets

    queuedSheets := PendingExcelFormulaSheets
    PendingExcelFormulaSheets := Map()
    if !TibOn
        return
    for _, sheet in queuedSheets
        FormatExcelFormulaCells(sheet)
}

class ExcelApplicationEvents {
    SheetChange(sheet, target, excel) {
        ; A committed value or formula keeps the same font as Tibetan input.
        StampUnicodeFontOnRange(target)
    }

    SheetCalculate(sheet, excel) {
        QueueExcelFormulaSheet(sheet)
    }

    AfterCalculate(excel) {
        ; Apply the font after all synchronous and asynchronous calculation
        ; work is complete, including formulas on inactive worksheets.
        FormatPendingExcelFormulaSheets()
    }

    SheetSelectionChange(sheet, target, excel) {
        ; the user moved to another cell (Tab, Enter, arrows, mouse):
        ; give the new cell the Unicode font immediately, like Word
        ; carries the font forward to whatever you type next
        StampUnicodeFontOnRange(target)
    }
}

StampUnicodeFontOnRange(target) {
    global TibOn, UnicodeFont

    if !TibOn
        return
    try {
        if (target.Font.Name != UnicodeFont)
            target.Font.Name := UnicodeFont
    } catch {
        ; Mixed-font selections can make Font.Name unavailable. Applying the
        ; font to the range still gives the next value a consistent font.
        try target.Font.Name := UnicodeFont
    }
}

EnsureUnicodeFont() {
    global FontAppliedWindow
    ; Excel can assign a different font to every cell. Reapply the Unicode
    ; font before each Tibetan keystroke so Tab, Enter, arrows, or a mouse
    ; click cannot leave the newly selected cell using Aptos.
    if WinActive("ahk_exe EXCEL.EXE") {
        ApplyUnicodeFont()
        return
    }

    activeWindow := WinExist("A")
    if activeWindow != FontAppliedWindow
        ApplyUnicodeFont()
}

FormatExcelNumberCells(*) {
    global ExcelNumberFont

    if !WinActive("ahk_exe EXCEL.EXE") {
        MsgBox(
            "Open Microsoft Excel and select the cells first.`n`n"
                . "Then press Ctrl+Alt+N again.",
            "TCRC Tibetan Numbers",
            "Iconi"
        )
        return
    }

    try {
        excel := ComObjActive("Excel.Application")
        selectedCells := excel.Selection
        selectedCells.Font.Name := ExcelNumberFont
    } catch {
        MsgBox(
            "The selected Excel cells could not be formatted.`n`n"
                . "Select normal worksheet cells and try again.",
            "TCRC Tibetan Numbers",
            "Iconx"
        )
        return
    }

    MsgBox(
        "The selected cells are ready.`n`n"
            . "Type numbers normally. They will look Tibetan, "
            . "but Excel will keep them as real numbers for formulas.",
        "TCRC Tibetan Numbers",
        "Iconi"
    )
}

#HotIf TibOn

Out(text) {
    global PrevChar, LastChar, LinkPending
    EnsureUnicodeFont()
    SendText text
    PrevChar := LastChar
    LastChar := SubStr(text, -1)
    LinkPending := false
}

Con(base, subjoined) {
    global LinkPending

    if (LinkPending && subjoined != "") {
        Out(subjoined)
        return
    }

    Out(base)
}

TypeDigit(westernDigit, tibetanCodepoint) {
    if WinActive("ahk_exe EXCEL.EXE") {
        Out(westernDigit)
        return
    }

    Out(Chr(tibetanCodepoint))
}

TypeExcelOperator(excelOperator, tibetanCharacter) {
    if WinActive("ahk_exe EXCEL.EXE") {
        Out(excelOperator)
        return
    }

    Out(tibetanCharacter)
}

$a:: {
    global LinkPending
    LinkPending := true
}

$Space:: {
    global PrevChar, LastChar
    if (LastChar = Chr(0x0F0B)) {
        if (PrevChar = Chr(0x0F42))
            Send "{BS}"
        Out(" ")
    } else {
        Out(Chr(0x0F0B))
    }
}

$/:: {
    global LastChar

    if WinActive("ahk_exe EXCEL.EXE") {
        Out("/")
        return
    }

    if (LastChar = Chr(0x0F44))
        Out(Chr(0x0F0B) Chr(0x0F0D))
    else
        Out(Chr(0x0F0D))
}

; Consonants
$q::  Con(Chr(0x0F4A), Chr(0x0F9A))
$+q:: Con(Chr(0x0F4B), Chr(0x0F9B))
$w::  Con(Chr(0x0F5D), Chr(0x0FAD))
$+w:: Out(Chr(0x0FAD))
$r::  Con(Chr(0x0F62), Chr(0x0FB2))
$+r:: Out(Chr(0x0F62))
$t::  Con(Chr(0x0F4F), Chr(0x0F9F))
$+t:: Con(Chr(0x0F50), Chr(0x0FA0))
$y::  Con(Chr(0x0F61), Chr(0x0FB1))
$+y:: Out("-")
$p::  Con(Chr(0x0F54), Chr(0x0FA4))
$+p:: Con(Chr(0x0F55), Chr(0x0FA5))
$+a:: Con(Chr(0x0F68), Chr(0x0FB8))
$s::  Con(Chr(0x0F66), Chr(0x0FB6))
$+s:: Con(Chr(0x0F64), Chr(0x0FB4))
$d::  Con(Chr(0x0F51), Chr(0x0FA1))
$+d:: Con(Chr(0x0F5B), Chr(0x0FAB))
$f::  Con(Chr(0x0F44), Chr(0x0F94))
$+f:: Con(Chr(0x0F52), Chr(0x0FA2))
$g::  Con(Chr(0x0F42), Chr(0x0F92))
$+g:: Con(Chr(0x0F43), Chr(0x0F93))
$h::  Con(Chr(0x0F67), Chr(0x0FB7))
$+h:: Out(Chr(0x0FB7))
$j::  Con(Chr(0x0F47), Chr(0x0F97))
$+j:: Con(Chr(0x0F5C), Chr(0x0FAC))
$k::  Con(Chr(0x0F40), Chr(0x0F90))
$+k:: Con(Chr(0x0F41), Chr(0x0F91))
$l::  Con(Chr(0x0F63), Chr(0x0FB3))
$+l:: Out(Chr(0x0F63))
$z::  Con(Chr(0x0F5F), Chr(0x0FAF))
$+z:: Con(Chr(0x0F5E), Chr(0x0FAE))
$x::  Con(Chr(0x0F59), Chr(0x0FA9))
$+x:: Con(Chr(0x0F5A), Chr(0x0FAA))
$c::  Con(Chr(0x0F45), Chr(0x0F95))
$+c:: Con(Chr(0x0F46), Chr(0x0F96))
$v::  Con(Chr(0x0F4C), Chr(0x0F9C))
$+v:: Con(Chr(0x0F4E), Chr(0x0F9E))
$b::  Con(Chr(0x0F56), Chr(0x0FA6))
$+b:: Con(Chr(0x0F57), Chr(0x0FA7))
$n::  Con(Chr(0x0F53), Chr(0x0FA3))
$+n:: Con(Chr(0x0F49), Chr(0x0F99))
$m::  Con(Chr(0x0F58), Chr(0x0FA8))
$+m:: Con(Chr(0x0F65), Chr(0x0FB5))
$'::  Con(Chr(0x0F60), Chr(0x0FB0))
$+':: Out(Chr(0x0F71))

; Vowels
$e::  Out(Chr(0x0F7A))
$+e:: Out(Chr(0x0F7B))
$u::  Out(Chr(0x0F74))
$+u:: Out(Chr(0x0F75))
$i::  Out(Chr(0x0F72))
$+i:: Out(Chr(0x0F73))
$o::  Out(Chr(0x0F7C))
$+o:: Out(Chr(0x0F7D))
$-::  TypeExcelOperator("-", Chr(0x0F80))
$+-:: TypeExcelOperator("_", Chr(0x0F81))

; Subjoined letters
$,::  Out(Chr(0x0FB1))
$+,:: Out(Chr(0x0FB3))
$.::  Out(Chr(0x0FB2))
$+.:: Out(Chr(0x0F62))
$+/:: Out(Chr(0x0F66))

; Digits
$1:: TypeDigit("1", 0x0F21)
$2:: TypeDigit("2", 0x0F22)
$3:: TypeDigit("3", 0x0F23)
$4:: TypeDigit("4", 0x0F24)
$5:: TypeDigit("5", 0x0F25)
$6:: TypeDigit("6", 0x0F26)
$7:: TypeDigit("7", 0x0F27)
$8:: TypeDigit("8", 0x0F28)
$9:: TypeDigit("9", 0x0F29)
$0:: TypeDigit("0", 0x0F20)
$Numpad1:: TypeDigit("1", 0x0F21)
$Numpad2:: TypeDigit("2", 0x0F22)
$Numpad3:: TypeDigit("3", 0x0F23)
$Numpad4:: TypeDigit("4", 0x0F24)
$Numpad5:: TypeDigit("5", 0x0F25)
$Numpad6:: TypeDigit("6", 0x0F26)
$Numpad7:: TypeDigit("7", 0x0F27)
$Numpad8:: TypeDigit("8", 0x0F28)
$Numpad9:: TypeDigit("9", 0x0F29)
$Numpad0:: TypeDigit("0", 0x0F20)
$NumpadDot:: Out(".")

; Punctuation and marks
$`::   Out(Chr(0x0F0C))
$+`::  Out(Chr(0x0F09))
$+1::  Out(Chr(0x0F11))
$+2::  Out(Chr(0x0F04))
$+3::  Out(Chr(0x0F04) Chr(0x0F05))
$+4::  Out(Chr(0x0F39))
$+6::  Out(Chr(0x0FBE))
$+7::  Out(Chr(0x0F3A))
$+8::  TypeExcelOperator("*", Chr(0x0F3B))
$=::   TypeExcelOperator("=", Chr(0x0F83))
$+=::  TypeExcelOperator("+", Chr(0x0F7E))
$\::   Out(Chr(0x0F7F))
$+\::  Out(Chr(0x0F08))
$;::   Out(Chr(0x0F4D))
$+;::  Out(Chr(0x0F14))
$[::   Out(Chr(0x2019))
$+[::  Out(Chr(0x2018))
$]::   Out(",")

#HotIf
