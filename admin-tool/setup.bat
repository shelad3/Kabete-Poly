@echo off
REM setup.bat — One-command setup for KNP Admin Tool (Windows)
REM Detects Python, creates venv, installs deps, launches the app.

echo === KNP Admin Tool — Setup ===

where python >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python not found. Install Python 3.12+ from python.org
    pause
    exit /b 1
)

python --version

if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

call venv\Scripts\activate

echo Installing dependencies...
pip install -r requirements.txt

echo.
echo === Launching KNP Admin Tool ===
python main.py
pause
