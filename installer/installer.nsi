Unicode true
!define APPNAME "TCRC Youtso Tibetan Unicode"
!define REGUN "Software\Microsoft\Windows\CurrentVersion\Uninstall\TCRCTibetanUnicode"
!define WM_FONTCHANGE 0x001D
!define HWND_BROADCAST 0xFFFF

Name "${APPNAME}"
OutFile "TCRC-Tibetan-Unicode-Setup.exe"
Icon "tcrc_on.ico"
UninstallIcon "tcrc_off.ico"
InstallDir "$PROGRAMFILES64\TCRC Tibetan Unicode"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

Page directory
Page instfiles

Section "Install"
  ; stop a running copy of the keyboard so files can be replaced
  nsExec::ExecToStack 'taskkill /F /IM AutoHotkey64.exe'
  Pop $0
  Sleep 800

  ; --- program files ---
  SetOutPath "$INSTDIR"
  File "AutoHotkey64.exe"
  File "TCRC-Tibetan-Unicode-Keyboard.ahk"
  File "README.txt"
  File "tcrc_on.ico"
  File "tcrc_off.ico"
  File "convert-docx.ps1"
  File "tcrc_to_unicode_map.json"

  ; --- font ---
  SetOutPath "$FONTS"
  File "TCRC-Youtso-Unicode-fixed.ttf"
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "TCRC Youtso Unicode (TrueType)" "TCRC-Youtso-Unicode-fixed.ttf"
  System::Call 'gdi32::AddFontResource(t "$FONTS\TCRC-Youtso-Unicode-fixed.ttf") i.r0'
  SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=5000

  ; --- make Windows use this font wherever it would fall back to Microsoft Himalaya ---
  WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" "Microsoft Himalaya" "TCRC Youtso Unicode"

  ; --- start menu ---
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Tibetan Keyboard.lnk" "$INSTDIR\AutoHotkey64.exe" '"$INSTDIR\TCRC-Tibetan-Unicode-Keyboard.ahk"' "$INSTDIR\tcrc_on.ico" 
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Read Me.lnk" "$INSTDIR\README.txt"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe"
  WriteINIStr "$SMPROGRAMS\${APPNAME}\Support Samdup - Buy Me a Coffee.url" "InternetShortcut" "URL" "https://buymeacoffee.com/samchoe2002"

  ; --- start keyboard automatically at login ---
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "TCRCTibetanKeyboard" '"$INSTDIR\AutoHotkey64.exe" "$INSTDIR\TCRC-Tibetan-Unicode-Keyboard.ahk"'

  ; --- uninstaller ---
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${REGUN}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${REGUN}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${REGUN}" "Publisher" "TCRC (font) / community Unicode repair"
  WriteRegStr HKLM "${REGUN}" "DisplayVersion" "1.10"

  ; --- launch now ---
  Exec '"$INSTDIR\AutoHotkey64.exe" "$INSTDIR\TCRC-Tibetan-Unicode-Keyboard.ahk"'

  MessageBox MB_ICONINFORMATION "Installed!$\n$\nPlease SIGN OUT and back in (or restart) once,$\nso Tibetan text automatically uses TCRC Youtso Unicode.$\n$\nTibetan typing is ON now (TCRC layout).$\nCtrl+Alt+T = switch Tibetan typing on/off.$\n$\nIn Word: just choose the font 'TCRC Youtso Unicode'.$\n$\nIn Photoshop: Edit > Preferences > Type > select$\n'Middle Eastern and South Asian', restart Photoshop,$\nthen Paragraph panel menu > World-Ready Layout.$\n$\nThis project is free. If it helps you, you can support$\nSamdup's work: buymeacoffee.com/samchoe2002"
SectionEnd

Section "Uninstall"
  ; stop the running keyboard app
  nsExec::ExecToStack 'taskkill /F /IM AutoHotkey64.exe'
  Pop $0
  Sleep 800

  ; autostart entry
  DeleteRegValue HKLM "Software\Microsoft\Windows\CurrentVersion\Run" "TCRCTibetanKeyboard"

  ; font: registration, substitution, file (at reboot if currently in use)
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "TCRC Youtso Unicode (TrueType)"
  DeleteRegValue HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" "Microsoft Himalaya"
  System::Call 'gdi32::RemoveFontResource(t "$FONTS\TCRC-Youtso-Unicode-fixed.ttf")'
  SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=5000
  Delete /REBOOTOK "$FONTS\TCRC-Youtso-Unicode-fixed.ttf"

  ; start menu folder (all shortcuts)
  RMDir /r "$SMPROGRAMS\${APPNAME}"

  ; entire program folder: keyboard app, AutoHotkey runtime, icons,
  ; README, uninstaller - everything
  RMDir /r /REBOOTOK "$INSTDIR"

  ; uninstall registration
  DeleteRegKey HKLM "${REGUN}"
SectionEnd
