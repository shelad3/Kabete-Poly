# KNP Admin Tool — Run from Source

Desktop app for managing timetable entries, grades, and classes in the KNP Management System.

---

## Quick Start (One Command)

### Windows
Double-click `setup.bat` or run in terminal:
```batch
setup.bat
```

### Linux
```bash
chmod +x setup.sh && ./setup.sh
```

The script handles everything: detects your OS, creates a virtual environment, installs dependencies, and launches the app. No need to know `python` vs `python3` or worry about paths.

On first launch you'll be prompted for:
1. **Firebase service account JSON** — download from Firebase Console > Project Settings > Service Accounts > Generate new key
2. **Firebase Web API Key** — Firebase Console > Project Settings > General > Web API Key

These are saved to `~/.config/KabeteAdminTool/settings.json` (Linux) or `%APPDATA%\KabeteAdminTool\settings.json` (Windows).

---

## Requirements

- **Windows:** 10/11, Python 3.12+
- **Linux:** any distro with X11/Wayland, Python 3.12+, `libxcb-cursor0`
- Internet connection (Firebase Auth + Firestore)

---

## What It Does

- Login — Firebase Auth email/password (blocks student accounts)
- Grade Editor — select class + subject + term, edit student CAT1/CAT2/Exam, batch save
- Timetable Editor — select class, add/delete entries with day, time, unit, room, lecturer, color
- Class Manager — add or delete classes
- Migrate Timetable — upload bulk timetable JSON to Firestore

---

## Compile to .exe

```batch
build_exe.bat
```

Output: `dist\KabeteAdminTool.exe`

See [ADMIN_TOOL_GUIDE.md](ADMIN_TOOL_GUIDE.md) for security audit info and antivirus notes.
