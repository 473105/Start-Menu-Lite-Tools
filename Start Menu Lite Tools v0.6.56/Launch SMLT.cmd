@echo off
setlocal

set "BASE_DIR=%~dp0"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "SMLT_HIDE_CONSOLE=1"
set "SCRIPT_FILE="

if exist "%PS_EXE%" goto FindScript
set "PS_EXE=powershell.exe"

:FindScript
pushd "%BASE_DIR%" >nul 2>nul
if errorlevel 1 goto ScriptMissing
for /f "delims=" %%F in ('dir /b /a:-d /o:-d Start_Menu_Lite_Tools_v*.ps1 2^>nul') do if not defined SCRIPT_FILE set "SCRIPT_FILE=%%F"
popd >nul 2>nul
if defined SCRIPT_FILE goto BuildPath
goto ScriptMissing

:BuildPath
set "SCRIPT_PATH=%BASE_DIR%%SCRIPT_FILE%"
if exist "%SCRIPT_PATH%" goto LaunchSMLT
goto ScriptMissing

:ScriptMissing
echo SMLT script not found beside this launcher.
echo Expected a file matching: Start_Menu_Lite_Tools_v*.ps1
echo Folder: "%BASE_DIR%"
pause
exit /b 2

:LaunchSMLT
start "" /D "%BASE_DIR%" "%PS_EXE%" -NoProfile -STA -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
exit /b 0
