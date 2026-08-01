@echo off
rem ===========================================================================
rem  Build the LOVE-on-Web (Emscripten) bundle into web_build\.
rem  Requirements: Node.js + npm. No npx (npx can trigger Windows Script Host
rem  errors on this package), no Python needed.
rem
rem  ASSET TRIMMING: the repo's assets\ holds ~3,000 extracted Chapter 1 PNGs
rem  (~31 MB) but the game only loads ~20 sprite folders. The build stages
rem  ONLY those referenced folders, so game.love and the web build stay small
rem  and load fast. The repo's full assets\ is untouched. If you add a sprite
rem  folder to src\assets.lua, add it to the SPRITES list below as well.
rem
rem  The game is packaged into game.love FIRST and love.js is fed that single
rem  .love file. Feeding love.js a directory on Windows produces backslash
rem  file paths ("\main.lua") and the game fails to boot with "File main.lua
rem  does not exist on disk". A .love file is a zip archive, so paths inside
rem  it are always forward-slash and correct.
rem
rem  Your desktop LOVE install is detected to run the game locally; the web
rem  build itself uses love.wasm (LOVE compiled to WebAssembly), which
rem  desktop LOVE cannot produce. Add --run to auto-launch the desktop game.
rem ===========================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0"

set OUT=%~1
if "%OUT%"=="" set OUT=web_build
set AUTORUN=0
if "%~2"=="--run" set AUTORUN=1
set TITLE=DELTA SCRATCH - Chapter 1
set MEMORY=268435456
set LOVEJS=.lovejs

rem Sprite folders referenced by src\assets.lua (keep in sync!).
set SPRITES=spr_krisd spr_krisu spr_krisl spr_krisr spr_susied spr_dummynpc spr_darklancer spr_krisb_idle spr_susieb_idle spr_ralseib_idle spr_jigsawry_idle spr_jigsawry_hurt spr_jigsawry_spared IMAGE_LOGO_CENTER IMAGE_MENU bg_battleback1

echo.
echo === Delta Scratch web build ===

echo [1/5] Detecting your LOVE install (desktop)...
set LOVEEXE=
where love >nul 2>nul && set LOVEEXE=love
if not defined LOVEEXE if exist "%LOCALAPPDATA%\Programs\LOVE\love.exe" set "LOVEEXE=%LOCALAPPDATA%\Programs\LOVE\love.exe"
if not defined LOVEEXE if exist "%ProgramFiles%\LOVE\love.exe" set "LOVEEXE=%ProgramFiles%\LOVE\love.exe"
if not defined LOVEEXE if exist "%ProgramFiles(x86)%\LOVE\love.exe" set "LOVEEXE=%ProgramFiles(x86)%\LOVE\love.exe"
if not defined LOVEEXE (
    for /f "tokens=2,* skip=2" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\LOVE_is1" /v InstallLocation 2^>nul') do if exist "%%B\love.exe" set "LOVEEXE=%%B\love.exe"
)
if not defined LOVEEXE (
    for /f "tokens=2,* skip=2" %%A in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\LOVE" /v InstallLocation 2^>nul') do if exist "%%B\love.exe" set "LOVEEXE=%%B\love.exe"
)
if defined LOVEEXE (
    echo       Found: !LOVEEXE!
) else (
    echo       Not found - desktop launch/game.love hint skipped. ^(install from https://love2d.org^)
)

echo [2/5] Checking love.js build tool...
if not exist "%LOVEJS%\node_modules\love.js\index.js" (
    echo       Installing love.js@11.4.1 into .lovejs\ ... first run only.
    if not exist "%LOVEJS%" mkdir "%LOVEJS%"
    call npm install --prefix "%LOVEJS%" love.js@11.4.1
    if errorlevel 1 (
        echo       npm install FAILED. Is Node.js installed and on PATH? ^(node --version^)
        exit /b 1
    )
)

echo [3/5] Staging trimmed project...
if exist "%TEMP%\delta_scratch_stage" rmdir /s /q "%TEMP%\delta_scratch_stage"
mkdir "%TEMP%\delta_scratch_stage"
copy /y "main.lua" "conf.lua" "config.lua" "favicon.svg" "icon.png" "bigicon.png" "%TEMP%\delta_scratch_stage\" >nul
robocopy "src" "%TEMP%\delta_scratch_stage\src" /e /nfl /ndl /njh /njs >nul
if errorlevel 8 exit /b 1
robocopy "vendor" "%TEMP%\delta_scratch_stage\vendor" /e /nfl /ndl /njh /njs >nul
if errorlevel 8 exit /b 1
rem Copy fonts/placeholders, but NOT the ~3k unused chapter-1 PNGs...
robocopy "assets" "%TEMP%\delta_scratch_stage\assets" /e /XD "chapter-1" /nfl /ndl /njh /njs >nul
if errorlevel 8 exit /b 1
mkdir "%TEMP%\delta_scratch_stage\assets\chapter-1\sprites"
rem ...then copy only the sprite folders the game references.
for %%s in (%SPRITES%) do (
    if exist "assets\chapter-1\sprites\%%s" (
        robocopy "assets\chapter-1\sprites\%%s" "%TEMP%\delta_scratch_stage\assets\chapter-1\sprites\%%s" /e /nfl /ndl /njh /njs >nul
    ) else (
        echo       WARNING: sprite folder missing: %%s (placeholder will be used)
    )
)

echo [4/5] Packaging game.love + building with LOVE 11.4 (Emscripten)...
rem Compress-Archive only accepts .zip, and .love files ARE zip files,
rem so package as game.zip then rename it to game.love.
if exist game.love del /q game.love
if exist game.zip del /q game.zip
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path '%TEMP%\delta_scratch_stage\*' -DestinationPath 'game.zip' -Force; Move-Item -Force 'game.zip' 'game.love'"
if not exist game.love (
    echo       Packaging game.love FAILED.
    exit /b 1
)
echo       game.love ready - drag it onto love.exe, or run: "!LOVEEXE!" game.love

node "%LOVEJS%\node_modules\love.js\index.js" -c -t "%TITLE%" -m %MEMORY% "game.love" "%OUT%"
if errorlevel 1 (
    echo       love.js build FAILED.
    exit /b 1
)

echo [5/5] Linking favicon + release artifacts...
copy /y "favicon.svg" "%OUT%\" >nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%OUT%\index.html'; $h=Get-Content -Raw $p; if ($h -notmatch 'rel=.icon.'){ $h=$h.Replace('<title>','<link rel=\"icon\" href=\"favicon.svg\">'+[Environment]::NewLine+'    <title>'); [IO.File]::WriteAllText($p,$h) }"

rem --- release artifacts (config.build) ---
if not exist "build\release" mkdir "build\release"
copy /y "game.love" "build\release\deltarune.love" >nul
echo Release archive: build\release\deltarune.love
if defined LOVEEXE (
    rem Fuse love.exe + game.love into a self-contained exe (official LOVE trick).
    for %%F in ("!LOVEEXE!") do set "LOVEDIR=%%~dpF"
    copy /b "!LOVEEXE!" + "%CD%\game.love" "build\release\deltarune.exe" >nul
    copy /y "!LOVEDIR!*.dll" "build\release\" >nul
    echo Release exe: build\release\deltarune.exe - double-click to play!
)

echo.
echo Web build written to: %OUT%
echo Serve it with:  python -m http.server 8000 -d %OUT%
if defined LOVEEXE (
    if "%AUTORUN%"=="1" (
        echo Launching desktop version with your LOVE...
        start "" "!LOVEEXE!" .
    ) else (
        set /p RUN=Launch the desktop game now with your LOVE? [Y/N] 
        if /i "!RUN!"=="Y" start "" "!LOVEEXE!" .
    )
)
endlocal
