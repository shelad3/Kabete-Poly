@echo off
REM Build standalone KabeteAdminTool.exe with PyInstaller
REM Requires Python 3.12+ and pip on Windows

echo === Installing dependencies ===
pip install -r requirements.txt
pip install pyinstaller

echo === Building executable ===
pyinstaller ^
    --onefile ^
    --windowed ^
    --name "KabeteAdminTool" ^
    --paths src ^
    --collect-all firebase_admin ^
    --collect-all PyQt6 ^
    --hidden-import PyQt6.sip ^
    --hidden-import PyQt6.QtSvg ^
    --hidden-import firebase_admin.credentials ^
    --hidden-import firebase_admin.firestore ^
    --hidden-import google.cloud ^
    --hidden-import google.api_core ^
    --hidden-import grpc ^
    --hidden-import cachetools ^
    --collect-data firebase_admin ^
    --collect-data PyQt6 ^
    main.py

echo === Done! ===
echo Executable at: dist\KabeteAdminTool.exe
echo.
echo NOTE: Users will need their Firebase service account JSON and Web API Key
echo on first launch. These are NOT bundled in the .exe.
echo.
echo If the .exe crashes on launch, run it from Command Prompt to see the error:
echo    dist\KabeteAdminTool.exe
