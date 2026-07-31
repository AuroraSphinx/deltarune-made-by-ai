@echo off
setlocal
cd /d "%~dp0"
title DELTA SCRATCH Builder

echo ========================================
echo        DELTA SCRATCH BUILD SYSTEM
echo ========================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\build.ps1"
set "BUILD_EXIT=%ERRORLEVEL%"

echo.
if "%BUILD_EXIT%"=="0" (
    echo Build finished successfully.
    if exist "%~dp0build" start "" "%~dp0build"
) else (
    echo Build failed with exit code %BUILD_EXIT%.
    echo The PowerShell error above is the real failure reason.
)

echo.
if /I not "%~1"=="--no-pause" pause
exit /b %BUILD_EXIT%
