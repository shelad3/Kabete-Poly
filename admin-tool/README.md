# KNP Admin Tool — Run from Source

Desktop app for managing timetable entries, grades, and classes in the KNP Management System.

---

## Quick Start

```batch
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

On first launch you'll be prompted for:
1. **Firebase service account JSON** — download from Firebase Console > Project Settings > Service Accounts > Generate new key
2. **Firebase Web API Key** — Firebase Console > Project Settings > General > Web API Key

These are saved to `%APPDATA%\KabeteAdminTool\settings.json`.

---

## Requirements

- Windows 10/11 (Linux/macOS works too but Qt platform plugins vary)
- Python 3.12 or newer
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
