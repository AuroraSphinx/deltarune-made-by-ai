@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-kristal.ps1"
if errorlevel 1 (
  echo.
  echo Kristal failed to launch.
  pause
)
