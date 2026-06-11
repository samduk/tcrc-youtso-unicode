Unicode true
!include "MUI2.nsh"

!define APPNAME "TCRC Youtso Unicode"
!define APPVERSION "1.4.0"
!define REGUN "Software\Microsoft\Windows\CurrentVersion\Uninstall\TCRCTibetanUnicode"
!ifndef WM_FONTCHANGE
  !define WM_FONTCHANGE 0x001D
!endif
!ifndef HWND_BROADCAST
  !define HWND_BROADCAST 0xFFFF
!endif

Name "${APPNAME}"
OutFile "TCRC-Youtso-Unicode-Setup.exe"
InstallDir "$PROGRAMFILES64\TCRC Tibetan Unicode"
InstallDirRegKey HKLM "${REGUN}" "InstallLocation"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
BrandingText "${APPNAME}"

Icon "tcrc_on.ico"
UninstallIcon "tcrc_off.ico"
VIProductVersion "1.4.0.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "FileVersion" "${APPVERSION}"
VIAddVersionKey "ProductVersion" "${APPVERSION}"
VIAddVersionKey "Publisher" "Samdup / TCRC community Unicode project"
VIAddVersionKey "LegalCopyright" "TCRC typeface; Unicode repair by Samdup"

!define MUI_ABORTWARNING
!define MUI_ICON "tcrc_on.ico"
!define MUI_UNICON "tcrc_off.ico"
!define MUI_FINISHPAGE_TEXT \
  "TCRC Youtso Unicode is ready.$\r$\n$\r$\nUse the desktop shortcut to convert old Word, PowerPoint, and Excel documents. Tibetan typing starts automatically. In Excel, select number cells and press Ctrl+Alt+N."
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Open TCRC Document Converter"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchConverter

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Section "Install"
  SetShellVarContext all
  SetRegView 64

  ; Stop only this product's current processes.
  nsExec::ExecToStack 'taskkill /F /IM TCRC-Tibetan-Keyboard.exe'
  Pop $0
  nsExec::ExecToStack 'taskkill /F /IM TCRC-Document-Converter.exe'
  Pop $0

  ; Remove files and duplicate startup entries from earlier versions.
  Delete "$SMSTARTUP\TCRC Tibetan Keyboard.lnk"
  Delete /REBOOTOK "$PROGRAMFILES64\TCRC Tibetan Unicode\AutoHotkey64.exe"
  Delete /REBOOTOK "$INSTDIR\AutoHotkey64.exe"
  RMDir /r "$SMPROGRAMS\TCRC Youtso Tibetan Unicode"
  DeleteRegValue HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
    "TCRC Youtso Excel Numbers (TrueType)"
  System::Call 'gdi32::RemoveFontResource(t "$FONTS\TCRC-Youtso-Excel-Numbers.ttf")'
  Delete /REBOOTOK "$FONTS\TCRC-Youtso-Excel-Numbers.ttf"

  SetOutPath "$INSTDIR"
  File /oname=TCRC-Tibetan-Keyboard.exe "AutoHotkey64.exe"
  File /oname=TCRC-Document-Converter.exe "AutoHotkey64.exe"
  File "TCRC-Tibetan-Unicode-Keyboard.ahk"
  File "TCRC-Document-Converter.ahk"
  File "convert-document.ps1"
  File "convert-docx.ps1"
  File "convert-pptx.ps1"
  File "convert-xlsx.ps1"
  File "tcrc_to_unicode_map.json"
  File "README.txt"
  File "tcrc_on.ico"
  File "tcrc_off.ico"

  ; Scripts for Adobe Photoshop, Illustrator, and InDesign.
  SetOutPath "$INSTDIR\adobe"
  File "TCRC-to-Unicode-Photoshop-Illustrator.jsx"
  File "TCRC-to-Unicode-InDesign.jsx"
  SetOutPath "$INSTDIR"

  ; Install and notify Windows about the font.
  SetOutPath "$FONTS"
  File "TCRC-Youtso-Unicode-fixed.ttf"
  WriteRegStr HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
    "TCRC Youtso Unicode (TrueType)" \
    "TCRC-Youtso-Unicode-fixed.ttf"
  System::Call 'gdi32::AddFontResource(t "$FONTS\TCRC-Youtso-Unicode-fixed.ttf") i.r0'
  SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=5000

  ; Undo the global Microsoft Himalaya substitution written by old releases.
  ReadRegStr $0 HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" \
    "Microsoft Himalaya"
  StrCmp $0 "TCRC Youtso Unicode" 0 font_substitution_done
  ReadRegStr $1 HKLM "${REGUN}" "PreviousMicrosoftHimalayaSubstitute"
  StrCmp $1 "" 0 restore_font_substitution
  DeleteRegValue HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" \
    "Microsoft Himalaya"
  Goto font_substitution_done
  restore_font_substitution:
  WriteRegStr HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" \
    "Microsoft Himalaya" \
    "$1"
  font_substitution_done:
  DeleteRegValue HKLM "${REGUN}" "PreviousMicrosoftHimalayaSubstitute"

  ; Start menu and desktop: one obvious application for document conversion.
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut \
    "$SMPROGRAMS\${APPNAME}\TCRC Document Converter.lnk" \
    "$INSTDIR\TCRC-Document-Converter.exe" \
    '"$INSTDIR\TCRC-Document-Converter.ahk"' \
    "$INSTDIR\tcrc_on.ico"
  CreateShortcut \
    "$SMPROGRAMS\${APPNAME}\Tibetan Keyboard.lnk" \
    "$INSTDIR\TCRC-Tibetan-Keyboard.exe" \
    '"$INSTDIR\TCRC-Tibetan-Unicode-Keyboard.ahk"' \
    "$INSTDIR\tcrc_on.ico"
  CreateShortcut \
    "$SMPROGRAMS\${APPNAME}\User Guide.lnk" \
    "$INSTDIR\README.txt"
  CreateShortcut \
    "$SMPROGRAMS\${APPNAME}\Uninstall.lnk" \
    "$INSTDIR\uninstall.exe"
  CreateShortcut \
    "$DESKTOP\TCRC Document Converter.lnk" \
    "$INSTDIR\TCRC-Document-Converter.exe" \
    '"$INSTDIR\TCRC-Document-Converter.ahk"' \
    "$INSTDIR\tcrc_on.ico"

  ; Optional shortcut from Word files. The visible converter still asks the
  ; user to confirm conversion and never overwrites the original.
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.doc\shell\TCRCConvertLegacy" \
    "" \
    "Convert TCRC document to Unicode"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.doc\shell\TCRCConvertLegacy" \
    "Icon" \
    "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.doc\shell\TCRCConvertLegacy\command" \
    "" \
    '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk" "%1"'

  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.docx\shell\TCRCConvertLegacy" \
    "" \
    "Convert TCRC document to Unicode"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.docx\shell\TCRCConvertLegacy" \
    "Icon" \
    "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.docx\shell\TCRCConvertLegacy\command" \
    "" \
    '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk" "%1"'


  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.ppt\shell\TCRCConvertLegacy" \
    "" \
    "Convert TCRC document to Unicode"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.ppt\shell\TCRCConvertLegacy" \
    "Icon" \
    "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.ppt\shell\TCRCConvertLegacy\command" \
    "" \
    '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk" "%1"'

  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.pptx\shell\TCRCConvertLegacy" \
    "" \
    "Convert TCRC document to Unicode"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.pptx\shell\TCRCConvertLegacy" \
    "Icon" \
    "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.pptx\shell\TCRCConvertLegacy\command" \
    "" \
    '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk" "%1"'

  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.xls\shell\TCRCConvertLegacy" \
    "" \
    "Convert TCRC document to Unicode"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.xls\shell\TCRCConvertLegacy" \
    "Icon" \
    "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.xls\shell\TCRCConvertLegacy\command" \
    "" \
    '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk" "%1"'

  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.xlsx\shell\TCRCConvertLegacy" \
    "" \
    "Convert TCRC document to Unicode"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.xlsx\shell\TCRCConvertLegacy" \
    "Icon" \
    "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM \
    "Software\Classes\SystemFileAssociations\.xlsx\shell\TCRCConvertLegacy\command" \
    "" \
    '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk" "%1"'

  ; Start the keyboard once per login.
  WriteRegStr HKLM \
    "Software\Microsoft\Windows\CurrentVersion\Run" \
    "TCRCTibetanKeyboard" \
    '"$INSTDIR\TCRC-Tibetan-Keyboard.exe" "$INSTDIR\TCRC-Tibetan-Unicode-Keyboard.ahk"'

  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${REGUN}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${REGUN}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${REGUN}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegStr HKLM "${REGUN}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${REGUN}" "DisplayIcon" "$INSTDIR\tcrc_on.ico"
  WriteRegStr HKLM "${REGUN}" "Publisher" "Samdup / TCRC community project"
  WriteRegStr HKLM "${REGUN}" "DisplayVersion" "${APPVERSION}"
  WriteRegDWORD HKLM "${REGUN}" "NoModify" 1
  WriteRegDWORD HKLM "${REGUN}" "NoRepair" 1

  IfSilent install_done
  Exec '"$INSTDIR\TCRC-Tibetan-Keyboard.exe" "$INSTDIR\TCRC-Tibetan-Unicode-Keyboard.ahk"'
  install_done:
SectionEnd

Function LaunchConverter
  Exec '"$INSTDIR\TCRC-Document-Converter.exe" "$INSTDIR\TCRC-Document-Converter.ahk"'
FunctionEnd

Section "Uninstall"
  SetShellVarContext all
  SetRegView 64

  nsExec::ExecToStack 'taskkill /F /IM TCRC-Tibetan-Keyboard.exe'
  Pop $0
  nsExec::ExecToStack 'taskkill /F /IM TCRC-Document-Converter.exe'
  Pop $0

  DeleteRegValue HKLM \
    "Software\Microsoft\Windows\CurrentVersion\Run" \
    "TCRCTibetanKeyboard"
  DeleteRegKey HKLM \
    "Software\Classes\SystemFileAssociations\.doc\shell\TCRCConvertLegacy"
  DeleteRegKey HKLM \
    "Software\Classes\SystemFileAssociations\.docx\shell\TCRCConvertLegacy"
  DeleteRegKey HKLM \
    "Software\Classes\SystemFileAssociations\.ppt\shell\TCRCConvertLegacy"
  DeleteRegKey HKLM \
    "Software\Classes\SystemFileAssociations\.pptx\shell\TCRCConvertLegacy"
  DeleteRegKey HKLM \
    "Software\Classes\SystemFileAssociations\.xls\shell\TCRCConvertLegacy"
  DeleteRegKey HKLM \
    "Software\Classes\SystemFileAssociations\.xlsx\shell\TCRCConvertLegacy"

  Delete "$DESKTOP\TCRC Document Converter.lnk"
  Delete "$SMSTARTUP\TCRC Tibetan Keyboard.lnk"
  RMDir /r "$SMPROGRAMS\${APPNAME}"

  DeleteRegValue HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
    "TCRC Youtso Unicode (TrueType)"
  System::Call 'gdi32::RemoveFontResource(t "$FONTS\TCRC-Youtso-Unicode-fixed.ttf")'
  SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=5000
  Delete /REBOOTOK "$FONTS\TCRC-Youtso-Unicode-fixed.ttf"

  ; Remove the separate number font left by versions before 1.4.0.
  DeleteRegValue HKLM \
    "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" \
    "TCRC Youtso Excel Numbers (TrueType)"
  System::Call 'gdi32::RemoveFontResource(t "$FONTS\TCRC-Youtso-Excel-Numbers.ttf")'
  Delete /REBOOTOK "$FONTS\TCRC-Youtso-Excel-Numbers.ttf"

  RMDir /r /REBOOTOK "$INSTDIR"
  DeleteRegKey HKLM "${REGUN}"
SectionEnd
