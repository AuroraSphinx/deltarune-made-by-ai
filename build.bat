@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title DELTA SCRATCH Builder

set "ROOT=%CD%"
set "BUILD=%ROOT%\build"
set "OUT=%BUILD%\release"
set "STAGE=%TEMP%\delta-scratch-stage-%RANDOM%-%RANDOM%"
set "LOVE_EXE="
set "LOVE_DIR="

echo ========================================
echo        DELTA SCRATCH BUILD SYSTEM
echo ========================================
echo.
echo Native one-process batch build.
echo.

if not exist "main.lua" (
    echo ERROR: main.lua is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if not exist "conf.lua" (
    echo ERROR: conf.lua is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if not exist "src\game.lua" (
    echo ERROR: src\game.lua is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if not exist "vendor\kristal_legacy\battle.lua" (
    echo ERROR: vendor\kristal_legacy\battle.lua is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if not exist "assets\fonts\DeterminationMonoWebRegular-Z5oq.ttf" (
    echo ERROR: Determination Mono is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if not exist "assets\fonts\DeterminationSansWebRegular-369X.ttf" (
    echo ERROR: Determination Sans is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if not exist "assets\ui\title-logo.png" (
    echo ERROR: assets\ui\title-logo.png is missing.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
where tar.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Windows tar.exe was not found.
    echo This builder requires Windows 10 or Windows 11.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)

if defined LOVE_EXE if exist "%LOVE_EXE%" set "LOVE_EXE=%LOVE_EXE%"
if not defined LOVE_EXE if exist "%ProgramFiles%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%ProgramFiles(x86)%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles(x86)%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%LOCALAPPDATA%\Programs\LOVE\love.exe" set "LOVE_EXE=%LOCALAPPDATA%\Programs\LOVE\love.exe"
if not defined LOVE_EXE if exist "%LOCALAPPDATA%\LOVE\love.exe" set "LOVE_EXE=%LOCALAPPDATA%\LOVE\love.exe"
if not defined LOVE_EXE for /F "delims=" %%L in ('where love.exe 2^>nul') do if not defined LOVE_EXE set "LOVE_EXE=%%~fL"
if not defined LOVE_EXE if exist "%ROOT%\DeltaruneBuild\deltarune.exe" set "LOVE_EXE=%ROOT%\DeltaruneBuild\deltarune.exe"
if defined LOVE_EXE for %%L in ("%LOVE_EXE%") do set "LOVE_DIR=%%~dpL"

echo === Cleaning old output ===
if exist "%BUILD%" rmdir /s /q "%BUILD%"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%OUT%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Could not create %OUT%
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
mkdir "%STAGE%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Could not create temporary build folder.
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)

echo === Staging game files ===
copy /Y "main.lua" "%STAGE%\main.lua" >nul
if errorlevel 1 (
    echo ERROR: Could not stage main.lua.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
copy /Y "conf.lua" "%STAGE%\conf.lua" >nul
if errorlevel 1 (
    echo ERROR: Could not stage conf.lua.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
if exist "THIRD_PARTY_NOTICES.md" copy /Y "THIRD_PARTY_NOTICES.md" "%STAGE%\THIRD_PARTY_NOTICES.md" >nul
xcopy /E /I /Y /Q "src" "%STAGE%\src\" >nul
if errorlevel 2 (
    echo ERROR: Could not stage src.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
xcopy /E /I /Y /Q "vendor" "%STAGE%\vendor\" >nul
if errorlevel 2 (
    echo ERROR: Could not stage vendor.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
xcopy /E /I /Y /Q "assets" "%STAGE%\assets\" >nul
if errorlevel 2 (
    echo ERROR: Could not stage assets.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)

echo === Building deltarune.love ===
pushd "%STAGE%"
tar.exe -a -c -f "%OUT%\deltarune.zip" *
set "TAR_EXIT=!ERRORLEVEL!"
popd
if not "!TAR_EXIT!"=="0" (
    echo ERROR: tar.exe failed with exit code !TAR_EXIT!.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b !TAR_EXIT!
)
move /Y "%OUT%\deltarune.zip" "%OUT%\deltarune.love" >nul
if errorlevel 1 (
    echo ERROR: Could not create deltarune.love.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)

tar.exe -t -f "%OUT%\deltarune.love" | findstr /X /C:"main.lua" >nul
if errorlevel 1 (
    echo ERROR: deltarune.love has an invalid archive root. main.lua is not at the top level.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)
tar.exe -t -f "%OUT%\deltarune.love" | findstr /X /C:"src/game.lua" >nul
if errorlevel 1 (
    echo ERROR: deltarune.love is missing src/game.lua.
    rmdir /s /q "%STAGE%" >nul 2>&1
    if /I not "%~1"=="--no-pause" pause
    exit /b 1
)

if defined LOVE_EXE (
    echo === Fusing deltarune.exe ===
    copy /B "!LOVE_EXE!"+"%OUT%\deltarune.love" "%OUT%\deltarune.exe" >nul
    if errorlevel 1 (
        echo ERROR: Could not fuse deltarune.exe.
        rmdir /s /q "%STAGE%" >nul 2>&1
        if /I not "%~1"=="--no-pause" pause
        exit /b 1
    )
    for %%D in ("!LOVE_DIR!*.dll") do if exist "%%~fD" copy /Y "%%~fD" "%OUT%\" >nul
    if exist "!LOVE_DIR!license.txt" copy /Y "!LOVE_DIR!license.txt" "%OUT%\LOVE-LICENSE.txt" >nul
) else (
    echo WARNING: love.exe was not found. deltarune.love was built, but deltarune.exe was skipped.
)

rmdir /s /q "%STAGE%" >nul 2>&1

echo.
echo ========================================
echo BUILD COMPLETE
echo ========================================
echo %OUT%\deltarune.love
if defined LOVE_EXE echo %OUT%\deltarune.exe
echo.

if /I not "%~1"=="--no-pause" (
    start "" "%OUT%"
    timeout /t 2 /nobreak >nul
)
exit /b 0
