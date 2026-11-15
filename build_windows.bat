@echo off
REM ==========================================================================
REM  KNP Management System - Windows builder
REM  Run this from the project root on a Windows machine with Flutter + Visual
REM  Studio (Desktop C++) installed. Produces a ready-to-run folder.
REM ==========================================================================
setlocal

echo [1/4] Checking Flutter...
where flutter >nul 2>nul
if errorlevel 1 (
  echo.
  echo Flutter was not found on PATH. Install it first:
  echo   https://docs.flutter.dev/get-started/install/windows
  echo Then reopen this window.
  pause
  exit /b 1
)

echo [2/4] Enabling Windows desktop support...
call flutter config --enable-windows-desktop

echo [3/4] Fetching packages...
call flutter pub get
if errorlevel 1 ( echo pub get failed & pause & exit /b 1 )

echo [4/4] Building release...
call flutter build windows --release
if errorlevel 1 ( echo Build failed & pause & exit /b 1 )

echo.
echo ==========================================================================
echo  DONE. Your app is here:
echo    build\windows\x64\runner\Release\
echo  Double-click:  kabete2026eiteet.exe
echo  Keep the whole Release folder together (DLLs + data are required).
echo ==========================================================================
pause
