@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title DELTA SCRATCH Builder

set "NO_PAUSE=0"
if /I "%~1"=="--no-pause" set "NO_PAUSE=1"

set "ROOT=%CD%"
set "BUILD_DIR=%ROOT%\build"
set "RELEASE_OUT=%BUILD_DIR%\release"
set "DEBUG_OUT=%BUILD_DIR%\debug"
set "RELEASE_STAGE=%TEMP%\delta-scratch-release-%RANDOM%"
set "DEBUG_STAGE=%TEMP%\delta-scratch-debug-%RANDOM%"
set "BOOT=%TEMP%\delta-scratch-love-%RANDOM%.exe"
set "SET_ICON=%ROOT%\tools\set-exe-icon.ps1"
set "LOVE_EXE="
set "LOVE_DIR="
set "BUILT_EXE=0"

echo ========================================
echo        DELTA SCRATCH BUILD SYSTEM
echo ========================================
echo.

call :require "main.lua" "main.lua"
if errorlevel 1 goto :failed
call :require "conf.lua" "conf.lua"
if errorlevel 1 goto :failed
call :require "src\game.lua" "src\game.lua"
if errorlevel 1 goto :failed
call :require "vendor\kristal_legacy\battle.lua" "Kristal-derived battle runtime"
if errorlevel 1 goto :failed
call :require "assets\fonts\DeterminationMonoWebRegular-Z5oq.ttf" "Determination Mono font"
if errorlevel 1 goto :failed
call :require "assets\fonts\DeterminationSansWebRegular-369X.ttf" "Determination Sans font"
if errorlevel 1 goto :failed
call :require "assets\ui\title-logo.png" "rasterized title logo"
if errorlevel 1 goto :failed

call :find_love
if defined LOVE_EXE (
    echo Found LOVE runtime:
    echo   %LOVE_EXE%
) else (
    echo WARNING: LOVE was not found automatically.
    echo The .love packages will still be built, but fused .exe files will be skipped.
    echo Install LOVE in its default folder or add love.exe to PATH to build executables.
)
echo.

echo === Cleaning old output ===
if exist "%BUILD_DIR%" rmdir /s /q "%BUILD_DIR%"
if exist "%RELEASE_STAGE%" rmdir /s /q "%RELEASE_STAGE%"
if exist "%DEBUG_STAGE%" rmdir /s /q "%DEBUG_STAGE%"
if exist "%BOOT%" del /q "%BOOT%" >nul 2>&1
mkdir "%RELEASE_OUT%" || goto :failed
mkdir "%DEBUG_OUT%" || goto :failed
mkdir "%RELEASE_STAGE%" || goto :failed
mkdir "%DEBUG_STAGE%" || goto :failed

echo === Staging game files ===
copy /Y "main.lua" "%RELEASE_STAGE%\main.lua" >nul || goto :failed
copy /Y "conf.lua" "%RELEASE_STAGE%\conf.lua" >nul || goto :failed
if exist "THIRD_PARTY_NOTICES.md" copy /Y "THIRD_PARTY_NOTICES.md" "%RELEASE_STAGE%\THIRD_PARTY_NOTICES.md" >nul
xcopy /Y /E /I /Q "src" "%RELEASE_STAGE%\src\" >nul
if errorlevel 2 goto :failed
xcopy /Y /E /I /Q "vendor" "%RELEASE_STAGE%\vendor\" >nul
if errorlevel 2 goto :failed
xcopy /Y /E /I /Q "assets" "%RELEASE_STAGE%\assets\" >nul
if errorlevel 2 goto :failed

xcopy /Y /E /I /Q "%RELEASE_STAGE%" "%DEBUG_STAGE%\" >nul
if errorlevel 2 goto :failed

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%DEBUG_STAGE%\conf.lua'; $s=[IO.File]::ReadAllText($p); $s=$s -replace 't\.console = false','t.console = true'; [IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))"
if errorlevel 1 goto :failed

echo === Building release .love ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%RELEASE_STAGE%\*' -DestinationPath '%RELEASE_OUT%\deltarune.zip' -Force"
if errorlevel 1 goto :failed
move /Y "%RELEASE_OUT%\deltarune.zip" "%RELEASE_OUT%\deltarune.love" >nul || goto :failed

echo === Building debug .love ===
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%DEBUG_STAGE%\*' -DestinationPath '%DEBUG_OUT%\debug-deltarune.zip' -Force"
if errorlevel 1 goto :failed
move /Y "%DEBUG_OUT%\debug-deltarune.zip" "%DEBUG_OUT%\debug-deltarune.love" >nul || goto :failed

if not defined LOVE_EXE goto :success

echo === Preparing LOVE executable ===
copy /Y "%LOVE_EXE%" "%BOOT%" >nul || goto :failed
if exist "icon.ico" if exist "%SET_ICON%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SET_ICON%" -Exe "%BOOT%" -Ico "%ROOT%\icon.ico"
    if errorlevel 1 (
        echo WARNING: Custom icon failed. Building with the normal LOVE icon instead.
        copy /Y "%LOVE_EXE%" "%BOOT%" >nul || goto :failed
    )
)

echo === Fusing release executable ===
copy /B "%BOOT%"+"%RELEASE_OUT%\deltarune.love" "%RELEASE_OUT%\deltarune.exe" >nul
if errorlevel 1 goto :failed

echo === Fusing debug executable ===
copy /B "%BOOT%"+"%DEBUG_OUT%\debug-deltarune.love" "%DEBUG_OUT%\debug-deltarune.exe" >nul
if errorlevel 1 goto :failed

set "DLL_COUNT=0"
for %%D in ("%LOVE_DIR%*.dll") do (
    if exist "%%~fD" (
        copy /Y "%%~fD" "%RELEASE_OUT%\" >nul
        copy /Y "%%~fD" "%DEBUG_OUT%\" >nul
        set /a DLL_COUNT+=1
    )
)
if exist "%LOVE_DIR%license.txt" (
    copy /Y "%LOVE_DIR%license.txt" "%RELEASE_OUT%\LOVE-LICENSE.txt" >nul
    copy /Y "%LOVE_DIR%license.txt" "%DEBUG_OUT%\LOVE-LICENSE.txt" >nul
)
if !DLL_COUNT! EQU 0 (
    echo WARNING: No LOVE runtime DLLs were found beside love.exe.
    echo The fused executables may require LOVE to remain installed.
) else (
    echo Copied !DLL_COUNT! LOVE runtime DLL files into each executable folder.
)
set "BUILT_EXE=1"

goto :success

:success
call :cleanup
echo.
echo ========================================
echo BUILD COMPLETE
echo ========================================
echo Release package:
echo   %RELEASE_OUT%\deltarune.love
if "%BUILT_EXE%"=="1" echo   %RELEASE_OUT%\deltarune.exe
echo Debug package:
echo   %DEBUG_OUT%\debug-deltarune.love
if "%BUILT_EXE%"=="1" echo   %DEBUG_OUT%\debug-deltarune.exe
echo.
if "%NO_PAUSE%"=="0" (
    start "" "%BUILD_DIR%"
    pause
)
exit /b 0

:failed
set "FAIL_CODE=%errorlevel%"
if "%FAIL_CODE%"=="0" set "FAIL_CODE=1"
call :cleanup
echo.
echo ========================================
echo BUILD FAILED
ECHO ========================================
echo Check the error printed above. The window will stay open.
echo.
if "%NO_PAUSE%"=="0" pause
exit /b %FAIL_CODE%

:cleanup
if exist "%RELEASE_STAGE%" rmdir /s /q "%RELEASE_STAGE%"
if exist "%DEBUG_STAGE%" rmdir /s /q "%DEBUG_STAGE%"
if exist "%BOOT%" del /q "%BOOT%" >nul 2>&1
exit /b 0

:require
if exist "%~1" exit /b 0
echo ERROR: Missing %~2 at:
echo   %ROOT%\%~1
exit /b 1

:find_love
if exist "%ProgramFiles%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles%\LOVE\love.exe"
if not defined LOVE_EXE if defined ProgramFiles(x86) if exist "%ProgramFiles(x86)%\LOVE\love.exe" set "LOVE_EXE=%ProgramFiles(x86)%\LOVE\love.exe"
if not defined LOVE_EXE if exist "%LOCALAPPDATA%\Programs\LOVE\love.exe" set "LOVE_EXE=%LOCALAPPDATA%\Programs\LOVE\love.exe"
if not defined LOVE_EXE if exist "%LOCALAPPDATA%\LOVE\love.exe" set "LOVE_EXE=%LOCALAPPDATA%\LOVE\love.exe"
if not defined LOVE_EXE for /F "delims=" %%L in ('where love.exe 2^>nul') do if not defined LOVE_EXE set "LOVE_EXE=%%L"
if not defined LOVE_EXE if exist "%ROOT%\DeltaruneBuild\deltarune.exe" set "LOVE_EXE=%ROOT%\DeltaruneBuild\deltarune.exe"
if defined LOVE_EXE for %%L in ("%LOVE_EXE%") do set "LOVE_DIR=%%~dpL"
exit /b 0
