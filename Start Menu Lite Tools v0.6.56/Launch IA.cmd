@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "BASE_DIR=%~dp0"
set "SELF_CMD=%~f0"
set "SCRIPT_PATH=%BASE_DIR%Icon_Allocator_v1.77.ps1"
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "!PS_EXE!" (
  echo PowerShell not found: !PS_EXE!
  exit /b 1
)

if not exist "!SCRIPT_PATH!" (
  echo Script not found: !SCRIPT_PATH!
  exit /b 2
)

rem Ensure this launcher is running elevated.
"!PS_EXE!" -NoProfile -Command "if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
  "!PS_EXE!" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:SELF_CMD -WorkingDirectory $env:BASE_DIR -Verb RunAs" >nul 2>&1
  if errorlevel 1 (
    echo Elevation was cancelled or failed.
    exit /b 3
  )
  exit /b 0
)

start "" /D "!BASE_DIR!" "!PS_EXE!" -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "!SCRIPT_PATH!"
exit /b 0








































