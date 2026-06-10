@echo off
setlocal
set "TESTDIR=%TEMP%\TCRC-Windows-Release-Test"
if exist "%TESTDIR%" rmdir /s /q "%TESTDIR%"
xcopy /e /i /y "%~dp0*" "%TESTDIR%\" >nul
if errorlevel 1 (
  echo Could not copy the test files to %TESTDIR%.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%TESTDIR%\Test-TCRC-Windows.ps1"" -KeepInstalled'"
echo.
echo Test finished. Review the PowerShell window for PASS or error messages.
pause
