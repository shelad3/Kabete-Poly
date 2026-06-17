<div align="center">
  <h1>KNP Management System</h1>
  <p><strong>A Digital Classroom Platform for Kabete National Polytechnique</strong></p>
  <br>
  <p>
    <img src="https://img.shields.io/badge/version-2.7.0-blue" alt="Version">
    <img src="https://img.shields.io/badge/platform-Android-brightgreen" alt="Platform">
    <img src="https://img.shields.io/badge/Framework-Flutter-02569B?logo=flutter" alt="Flutter">
    <img src="https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase" alt="Firebase">
  </p>
  <br>
</div>

---

## Overview

KNP Management System is a mobile application built for Kabete National Polytechnique that replaces paper-based lesson distribution, WhatsApp timetable confusion, and scattered grade records with a single, real-time digital platform.

- **Students:** Browse lessons, view timetables, check grades, participate in class forums
- **Teachers:** Post lesson materials, schedule classes, view student grades
- **Admins:** Manage classes, timetable entries, user roles & alerts via a Windows desktop tool

Built entirely by **Sheldon Ramu** (Electrical Engineering student) over 4 months — Flutter, Firebase, and Python were all learned during development.

---

## Features

| Feature | Description |
|---------|-------------|
| **Lesson Archive** | Teachers upload notes + PDF attachments per class. Students browse newest-first. |
| **Real-time Timetable** | Weekly class schedules that update instantly via Firestore. Offline cached. |
| **Grades Portal** | CAT1, CAT2, and Exam results published by teachers. Students see only their own. |
| **Class Forums** | Per-class discussion channels (Global announcements + Public chat). |
| **Push Notifications** | FCM-based alerts for new lessons, schedule changes, and grade posts. |
| **Campus Map** | Google Maps with pinned lecture halls, labs, and faculty offices. |
| **Auto-update** | Checks GitHub Releases on startup, downloads new APK with progress bar. |
| **Faculty Directory** | Contact information for all lecturers and staff. |
| **Offline Mode** | Firestore persistence caches lessons, timetable, and messages after first load. |

---

## Tech Stack

```
Frontend         Flutter 3.x / Dart 3.x
Backend          Firebase (Firestore, Auth, Cloud Messaging)
File Storage     Cloudinary
Maps             Google Maps SDK (Android)
State Mgmt       Provider + ChangeNotifier
Admin Tool       Python 3.12+ / PyQt6 / Firebase Admin SDK
Auth             Firebase Auth (email/password + Google Sign-In)
Updates          GitHub Releases API
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point, providers, MaterialApp
├── models/                            # Data classes (UserProfile, Lesson, GradeRecord, etc.)
├── screens/                           # UI screens
│   ├── splash_screen.dart             # Custom branded splash with auto-login
│   ├── login_screen.dart              # Email/password login
│   ├── registration_screen.dart       # Multi-step registration with role selection
│   ├── home_screen.dart               # Main scaffold with bottom nav tabs
│   ├── guest_home_screen.dart         # Limited view for unauthenticated users
│   ├── onboarding_screen.dart         # First-launch walkthrough
│   ├── settings_screen.dart           # Profile, theme, notifications, version info
│   ├── admin/                         # Admin-only screens
│   └── ...                            # Explore, Forums, Grades, Schedule, etc.
├── services/                          # Business logic & Firebase integration
│   ├── auth_provider.dart             # Auth state management
│   ├── class_provider.dart            # Available classes from Firestore
│   ├── firestore_service.dart         # CRUD operations
│   ├── update_service.dart            # GitHub release check + APK download
│   └── ...
├── theme/                             # App theming (KNP brand, light, dark)
├── utils/                             # Helpers (campus map data, role data, date utils)
└── widgets/                           # Reusable widgets (drawer, shimmer loading)

android/                               # Android platform configuration
├── app/src/main/
│   ├── AndroidManifest.xml
│   ├── res/values/styles.xml          # Launch theme (splash background color)
│   ├── res/drawable/launch_background.xml
│   └── ...

admin-tool/                            # Windows desktop admin application (Python)
├── main.py                            # PyQt6 GUI entry point
├── build_exe.bat                      # PyInstaller build script
├── requirements.txt                   # Python dependencies
├── src/
│   ├── firestore_client.py            # Firebase Admin SDK wrapper
│   ├── firebase_auth_client.py        # Firebase Auth REST API client
│   ├── grade_editor.py                # Grade entry table widget
│   ├── timetable_editor.py            # Timetable CRUD widget
│   ├── config_manager.py              # Persistent settings (%APPDATA%)
│   ├── migrate_timetable.py           # Bulk timetable upload script
│   └── models.py                      # Data classes
└── ADMIN_TOOL_GUIDE.md               # ICT teacher / security audit guide

tools/
├── export_timetable_data.dart         # (archived) Exported hardcoded data to JSON

firestore.rules                        # Firebase security rules
firestore.indexes.json                 # Composite indexes
firebase.json                          # Firebase project config
```

---

## How to Run (Development)

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | 3.x | [flutter.dev](https://flutter.dev) |
| Dart | 3.x | Bundled with Flutter |
| Android Studio | Latest | With Android SDK 34+ |
| Firebase CLI | Latest | `npm install -g firebase-tools` |

### Setup

```bash
# 1. Clone
git clone https://github.com/shelad3/Kabete-Poly.git
cd Kabete-Poly

# 2. Install Flutter dependencies
flutter pub get

# 3. Add your google-services.json
#    Download from Firebase Console > Project Settings > Your apps > Android
#    Place at: android/app/google-services.json
#    (This file is gitignored — never commit it)

# 4. Run on device/emulator
flutter run
```

> **Note:** Without a valid `google-services.json` pointing to the KNP Firebase project, the app will crash on Firebase init. Contact the project owner for access.

### Firebase Emulators (Optional)

```bash
firebase emulators:start --only firestore,auth
```

Then update `lib/main.dart` to use local emulator hosts during development.

---

## How to Build a Release APK

```bash
# Clean build
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

To generate a signed bundle for Play Store (if ever needed):

```bash
flutter build appbundle --release
```

---

## How the Auto-Update System Works

The app checks for new versions on every launch without using Google Play Store.

```
App starts
  │
  └── UpdateService.checkForUpdate()
        │
        ├── GET https://api.github.com/repos/shelad3/KNP-Management-System/releases/latest
        │
        ├── Compare tag_name vs current version (from package_info_plus)
        │     │
        │     ├── Same version → do nothing
        │     │
        │     └── Newer version → show dialog
        │           │
        │           └── User taps "Download"
        │                 │
        │                 ├── Stream APK from release asset URL
        │                 ├── Show progress (MB downloaded / total MB)
        │                 ├── Verify file size against Content-Length header
        │                 └── Open system installer via OpenFile plugin
```

### To publish a new update:

```bash
# 1. Bump version in pubspec.yaml
#    version: x.y.z+build

# 2. Update version string in lib/screens/splash_screen.dart
#    (if the hardcoded string is present)

# 3. Build the APK
flutter build apk --release

# 4. Create a GitHub Release
gh release create v2.x.x                                \
    "build/app/outputs/flutter-apk/app-release.apk"      \
    --repo shelad3/KNP-Management-System                 \
    --title "v2.x.x"                                     \
    --notes "Description of changes"
```

The app will detect the new version on next launch.

---

## Firebase Configuration

### Firestore Indexes

Deploy indexes after any query changes:

```bash
firebase deploy --only firestore:indexes
```

Current indexes include:
- `timetable` subcollection: `day ASC, time ASC`
- `messages`: `classId ASC, channelId ASC, timestamp ASC`
- `lessons`: `classId ASC, createdAt DESC`

### Security Rules

```bash
firebase deploy --only firestore:rules
```

Rules enforce:
- Students read only their enrolled classes' data
- Teachers can write lessons, grades, and schedule entries
- Officials (admins) have full access
- No client-side bypass — rules evaluated on every request

### Required Firebase Services

| Service | Purpose |
|---------|---------|
| Firebase Auth | Email/password + Google Sign-In |
| Cloud Firestore | All app data (lessons, users, grades, messages, timetable) |
| Firebase Cloud Messaging | Push notifications (class topics) |
| Firebase Hosting (optional) | Landing page or admin dashboard |

---

## Windows Admin Tool

A standalone desktop application for managing timetable entries, grades, and classes.

### Run from Source

```bash
cd admin-tool
python -m venv venv
venv\Scripts\activate      # Windows
pip install -r requirements.txt
python main.py
```

### Build .exe

```batch
build_exe.bat
# Output: dist\KabeteAdminTool.exe
```

### What It Can Do

- Login via Firebase Auth (requires Teacher/Official role)
- Select any class from a dropdown
- View/edit/add/delete timetable entries
- Enter and batch-save student grades (CAT1, CAT2, Exam)
- Add/delete classes
- Migrate bulk timetable data from JSON

See [admin-tool/ADMIN_TOOL_GUIDE.md](admin-tool/ADMIN_TOOL_GUIDE.md) for security audit info, PyInstaller false-positive notes, and IT admin FAQ.

---

## Timetable Data Migration

The original timetable was hardcoded as an 8,296-line Dart map (`TimetableData.cohorts`). As of v2.6.0, all timetable data lives in Firestore.

To upload new timetable data from a JSON file:

```bash
cd admin-tool
source venv/bin/activate    # Linux/Mac
# or venv\Scripts\activate  # Windows

python -m src.migrate_timetable --json path/to/data.json --clear
```

The JSON format:

```json
{
  "CLASS & NAME": {
    "Monday": [
      {"time": "8:00 - 10:00", "unit": "Subject Name", "room": "C1-A", "lecturer": "John Doe", "color": 4282339765}
    ],
    "Tuesday": [...]
  }
}
```

> Class names with `/` are automatically sanitized to ` & ` because Firestore paths do not support `/` in document IDs.

---

## FAQ for Developers

**Q: Why Provider instead of Riverpod/Bloc?**
A: The project started when Provider was the recommended approach in Flutter docs. It is simple, well-understood, and sufficient for this app's complexity. Migration to Riverpod would be straightforward if needed.

**Q: Why Cloudinary instead of Firebase Storage?**
A: Firebase Storage requires the user to be authenticated. Cloudinary allows generating unsigned upload URLs for specific use cases. Also, Cloudinary's free tier (25 GB) was more generous at the time.

**Q: Why is the timetable a subcollection?**
A: A class can have 50+ timetable entries. Firestore documents have a 1 MiB limit. Storing entries as an array inside the class document risks hitting that limit. Subcollections scale independently.

**Q: Why is the admin tool separate instead of a web dashboard?**
A: A web dashboard would require Firebase Hosting + Cloud Functions + a frontend framework. The Python/PyQt6 approach was faster to build for a single admin user. It also works offline (except for Firestore reads).

**Q: How do I add a new class?**
A: Add a document to the `classes` collection in Firestore with a `createdAt` timestamp. The class name is the document ID. The app picks it up automatically on next load.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.7.0 | Jun 2026 | Eliminate splash flash, admin tool fixes, timetable PDF extraction |
| 2.6.0 | Jun 2026 | Remove hardcoded TimetableData; classes from Firestore only |
| 2.5.0 | Jun 2026 | Timetable migrated to Firestore-only; cloud icon removed |
| 2.4.3 | Jun 2026 | Grades permission fix, timetable composite index deployed |
| 2.4.2 | Jun 2026 | Download progress MB counter, HEAD content-length integrity check |
| 2.4.1 | Jun 2026 | Login/guest reactivity fixed via ValueKey on MaterialApp |
| 2.4.0 | Jun 2026 | Grades module, push notifications, forum channels |
| 2.3.0 | May 2026 | Class forums, messaging, campus map |
| 2.2.0 | May 2026 | Timetable tab, auto-update system, Windows admin tool |
| 2.1.0 | Apr 2026 | Lesson archive, file uploads, role-based auth |
| 2.0.0 | Apr 2026 | Registration + login, guest mode, Firebase integration |
| 1.0.0 | Feb 2026 | Prototype with hardcoded data |

---

## License

MIT — see [LICENSE](LICENSE).

---

## Contact

**Sheldon Ramu** — Electrical Engineering, Kabete National Polytechnique  
GitHub: [@shelad3](https://github.com/shelad3)  
Project: [github.com/shelad3/Kabete-Poly](https://github.com/shelad3/Kabete-Poly)  
Download: [github.com/shelad3/KNP-Management-System](https://github.com/shelad3/KNP-Management-System)
