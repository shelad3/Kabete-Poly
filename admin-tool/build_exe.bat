@echo off
REM Run this batch file on Windows to build a standalone .exe
REM Requires Python 3.12+ and pip

echo === Installing dependencies ===
pip install -r requirements.txt
pip install pyinstaller

echo === Building executable ===
pyinstaller --onefile --windowed --name "KabeteAdminTool" main.py

echo === Done! ===
echo Executable at: dist\KabeteAdminTool.exe
echo.
echo NOTE: Users will need their Firebase service account JSON and Web API Key
echo on first launch. These are NOT bundled in the .exe.
