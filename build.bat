@echo off
setlocal

set BOOT_SRC=DeltaruneBuild\deltarune.exe
set BOOT=%TEMP%\deltarune-boot.exe
set RELEASE_DIR=%TEMP%\deltarune-release
set DEBUG_DIR=%TEMP%\deltarune-debug
set SET_ICON=powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\set-exe-icon.ps1"

if not exist "%BOOT_SRC%" (
    echo ERROR: Bootstrap not found at %BOOT_SRC%
    exit /b 1
)
if not exist icon.ico (
    echo ERROR: icon.ico not found
    exit /b 1
)
if not exist "vendor\kristal_legacy\battle.lua" (
    echo ERROR: Kristal-derived battle runtime is missing from vendor\kristal_legacy
    exit /b 1
)

echo === Cleaning previous builds ===
if exist deltarune.love del deltarune.love >nul
if exist deltarune.exe del deltarune.exe >nul
if exist debug-deltarune.love del debug-deltarune.love >nul
if exist debug-deltarune.exe del debug-deltarune.exe >nul
if exist icon.png del icon.png >nul
if exist "%BOOT%" del "%BOOT%" >nul
if exist "%RELEASE_DIR%" rmdir /s /q "%RELEASE_DIR%"
if exist "%DEBUG_DIR%" rmdir /s /q "%DEBUG_DIR%"

echo === Setting icon on bootstrap ===
copy /Y "%BOOT_SRC%" "%BOOT%" >nul
%SET_ICON% -Exe "%BOOT%" -Ico "icon.ico"
if errorlevel 1 (
    echo ERROR: Failed to set icon on bootstrap
    exit /b 1
)
echo   Icon set on bootstrap

echo === Extracting icon.png from icon.ico ===
powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; $bmp = [System.Drawing.Icon]::ExtractAssociatedIcon((Resolve-Path 'icon.ico').Path).ToBitmap(); $bmp.Save((Join-Path (Get-Location) 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()"
if errorlevel 1 (
    echo ERROR: Failed to extract icon.png
    exit /b 1
)

echo === Building release ===
mkdir "%RELEASE_DIR%\assets\fonts" >nul
copy /Y main.lua "%RELEASE_DIR%\" >nul
copy /Y conf.lua "%RELEASE_DIR%\" >nul
copy /Y icon.png "%RELEASE_DIR%\" >nul
copy /Y THIRD_PARTY_NOTICES.md "%RELEASE_DIR%\" >nul
xcopy /Y /E /I /Q src "%RELEASE_DIR%\src\" >nul
xcopy /Y /E /I /Q vendor "%RELEASE_DIR%\vendor\" >nul
copy /Y assets\placeholders.lua "%RELEASE_DIR%\assets\" >nul
copy /Y assets\README.md "%RELEASE_DIR%\assets\" >nul
copy /Y assets\fonts\8bit.ttf "%RELEASE_DIR%\assets\fonts\" >nul

powershell -NoProfile -Command "Compress-Archive -Path '%RELEASE_DIR%\*' -DestinationPath 'deltarune.love.zip' -Force" >nul
ren deltarune.love.zip deltarune.love
copy /b "%BOOT%" + deltarune.love deltarune.exe >nul
echo   Built: deltarune.exe

echo === Building debug ===
mkdir "%DEBUG_DIR%\assets\fonts" >nul
copy /Y main.lua "%DEBUG_DIR%\" >nul
copy /Y conf.lua "%DEBUG_DIR%\" >nul
copy /Y icon.png "%DEBUG_DIR%\" >nul
copy /Y THIRD_PARTY_NOTICES.md "%DEBUG_DIR%\" >nul
xcopy /Y /E /I /Q src "%DEBUG_DIR%\src\" >nul
xcopy /Y /E /I /Q vendor "%DEBUG_DIR%\vendor\" >nul
copy /Y assets\placeholders.lua "%DEBUG_DIR%\assets\" >nul
copy /Y assets\README.md "%DEBUG_DIR%\assets\" >nul
copy /Y assets\fonts\8bit.ttf "%DEBUG_DIR%\assets\fonts\" >nul

powershell -NoProfile -Command "(Get-Content '%DEBUG_DIR%\conf.lua' -Raw) -replace 't\.console = false','t.console = true' | Set-Content '%DEBUG_DIR%\conf.lua'" >nul

powershell -NoProfile -Command "Compress-Archive -Path '%DEBUG_DIR%\*' -DestinationPath 'debug-deltarune.love.zip' -Force" >nul
ren debug-deltarune.love.zip debug-deltarune.love
copy /b "%BOOT%" + debug-deltarune.love debug-deltarune.exe >nul
echo   Built: debug-deltarune.exe

echo === Cleanup ===
if exist "%RELEASE_DIR%" rmdir /s /q "%RELEASE_DIR%"
if exist "%DEBUG_DIR%" rmdir /s /q "%DEBUG_DIR%"
if exist deltarune.love.zip del deltarune.love.zip >nul 2>&1
if exist debug-deltarune.love.zip del debug-deltarune.love.zip >nul 2>&1
if exist icon.png del icon.png >nul 2>&1
if exist "%BOOT%" del "%BOOT%" >nul

echo === Done ===
echo The .exe files need love.dll, lua51.dll, mpg123.dll, msvcp120.dll, msvcr120.dll, OpenAL32.dll, and SDL2.dll next to them at runtime.
