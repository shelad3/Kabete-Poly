<div align="center">
  <h1>KNP Management System</h1>
  <p><strong>A Digital Classroom Platform for Kabete National Polytechnique</strong></p>
  <br>
  <p>
    <img src="https://img.shields.io/badge/version-2.9.0-blue" alt="Version">
    <img src="https://img.shields.io/badge/platform-Android-brightgreen" alt="Platform">
    <img src="https://img.shields.io/badge/Framework-Flutter-02569B?logo=flutter" alt="Flutter">
    <img src="https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase" alt="Firebase">
  </p>
  <br>
</div>

---

## Overview

KNP Management System is a mobile application built for Kabete National Polytechnique that replaces paper-based lesson distribution, WhatsApp timetable confusion, and scattered grade records with a single, real-time digital platform.

- **Students:** Browse lessons, view timetables, check grades, book hostel cubicles, register for exams, participate in class forums & quizzes, vote in student leader elections
- **Teachers:** Post lesson materials, schedule classes, manage grades, create quizzes, verify lesson attendance
- **Admins:** Manage classes, timetable entries, user roles & alerts, houses/cubicles, payments, exam timetables, feature flags via a Python desktop tool

Built entirely by **Sheldon Ramu** (Electrical Engineering student) — Flutter, Firebase, and Python were all learned during development.

---

## Features

| Feature | Description |
|---------|-------------|
| **Lesson Archive** | Teachers upload notes + PDF attachments per class. Students browse newest-first. |
| **Real-time Timetable** | Weekly class schedules that update instantly via Firestore. Offline cached. 4 tabs: Mandatory / Target Timeline / Exams / Map. |
| **Exam Timetable** | Categorized exams (final/midterm/CAT/practical) grouped by date, with admin CRUD. |
| **Grades Portal** | CAT1, CAT2, and Exam results published by teachers. Students see only their own. |
| **Class Forums** | Per-class discussion channels (Global announcements + Public chat). |
| **Push Notifications** | FCM-based alerts for new lessons, schedule changes, and grade posts, split into class notifications + admin alerts with badges. |
| **Hostel Booking** | Browse houses, live cubicle availability, transactional booking (atomic double-booking + capacity check), receipts, waitlist. |
| **Payments** | Booking fee flow: method selection (M-Pesa/card/cash), phone number, animated status screen, admin payment dashboard. |
| **Exam Booking** | Students register for exams with seat-capacity limits enforced atomically. |
| **Student Leader Voting** | Position-based elections with SHA-256 ballot hashing, live results with charts, admin election management. |
| **Quizzes** | In-class quizzes with scoring, results, and teacher-created questions. |
| **School ID Card** | Digital ID with photo, regNo, gender, nationality, school seal. |
| **Feature Flags** | 12 remote-configurable feature toggles with schedule support, managed from app + admin tool. |
| **Campus Map** | Google Maps with pinned lecture halls, labs, and faculty offices. |
| **QR Attendance** | Time-based QR codes (60s expiry, FLAG_SECURE anti-screenshot) verified against class rosters. |
| **Event Gallery** | Campus events with Cloudinary-hosted photos. |
| **Auto-update** | Checks Firestore `app_updates/latest` on startup, downloads new APK with progress bar. |
| **Faculty Directory** | Contact information for all lecturers and staff. |
| **Offline Mode** | Firestore persistence caches lessons, timetable, and messages after first load. |

---

## Tech Stack

```
Frontend         Flutter 3.x / Dart 3.x
Backend          Firebase (Firestore, Auth, Cloud Messaging, Storage)
File Storage     Cloudinary
Maps             Google Maps SDK (Android)
State Mgmt       Provider + ChangeNotifier
Admin Tool       Python 3.12+ / PyQt6 / Firebase Admin SDK / pdfplumber / pandas
Auth             Firebase Auth (email/password + Google Sign-In)
Updates          Firestore app_updates/latest → GitHub Release asset download
```

---

## Project Structure

```
lib/
├── main.dart                          # App entry point, providers, MaterialApp
├── models/                            # 22 data models (UserProfile, Lesson, GradeRecord,
│                                      #   CubeBooking, Payment, Election, Exam, FeatureFlag...)
├── screens/                           # 66 UI screens
│   ├── splash_screen.dart             # Custom branded splash with auto-login
│   ├── login_screen.dart              # Email/password login
│   ├── registration_screen.dart       # Multi-step registration with role selection
│   ├── home_screen.dart               # Main scaffold with bottom nav tabs
│   ├── guest_home_screen.dart         # Limited view for unauthenticated users
│   ├── onboarding_screen.dart         # First-launch walkthrough
│   ├── settings_screen.dart           # Profile, theme, notifications, version info
│   ├── admin/                         # Admin-only screens (17)
│   ├── cubes/                         # Hostel booking screens (5)
│   ├── payment/                       # Payment method + status screens (2)
│   ├── voting/                        # Voting dashboard, cast, results (3)
│   ├── exam_booking/                  # Exam registration (1)
│   ├── quiz/                          # Quiz engine (4)
│   ├── grades/                        # Grade report + manage (2)
│   ├── schedule/                      # Campus map + lesson detail (2)
│   ├── tabs/                          # Mandatory + Exam timetable tabs (2)
│   ├── users/                         # Users tab + actions (2)
│   └── ...                            # Explore, Forums, Gallery, School ID Card, etc.
├── services/                          # 24 services & providers
│   ├── auth_provider.dart             # Auth state management
│   ├── class_provider.dart            # Available classes from Firestore
│   ├── firestore_service.dart         # CRUD operations
│   ├── cube_service.dart              # Transactional bookings + waitlist
│   ├── voting_service.dart            # SHA-256 ballot hashing + atomic castVote
│   ├── exam_booking_service.dart      # Atomic exam registration
│   ├── payment_service.dart           # Payment CRUD + admin override
│   ├── feature_flag_service.dart      # Firestore-backed feature toggles
│   ├── update_service.dart            # Firestore update check + APK download
│   └── ...
├── providers/                         # ChangeNotifier providers
├── theme/                             # App theming (KNP brand, light, dark)
├── utils/                             # Helpers (campus map data, role data, date utils)
└── widgets/                           # Reusable widgets (drawer, shimmer, feature gate)

android/                               # Android platform configuration
├── app/src/main/
│   ├── AndroidManifest.xml
│   ├── res/values/styles.xml          # Launch theme (splash background color)
│   └── ...

admin-tool/                            # Desktop admin application (Python)
├── main.py                            # PyQt6 GUI entry point — 8 tabs
├── requirements.txt                   # Python dependencies
├── src/
│   ├── firestore_client.py            # Firebase Admin SDK wrapper (all collections)
│   ├── firebase_auth_client.py        # Firebase Auth REST API client
│   ├── grade_editor.py                # Grade entry table widget
│   ├── timetable_editor.py            # Timetable CRUD widget
│   ├── timetable_upload_tab.py        # 6-step wizard (mode select → file → parse → preview → verify → upload)
│   ├── pdf_parser.py                  # PDF timetable parsing (class + exam)
│   ├── csv_parser.py                  # CSV timetable parsing (class + exam)
│   ├── preview_table_widget.py        # Grouped, selectable, duplicate-aware preview
│   ├── verification_dialog.py         # Conflict detection (venue/lecturer/duplicate)
│   ├── exam_timetable_tab.py          # Exam timetable CRUD
│   ├── payment_dashboard.py           # Payment summary + manual overrides
│   ├── feature_flag_manager.py        # Toggle/edit/seed feature flags
│   ├── report_card_generator.py       # Batch PDF report cards (fpdf2)
│   ├── analytics_dashboard.py         # Grade distribution charts (matplotlib)
│   ├── qr_generator.py                # Printable A4 QR card PDFs
│   ├── csv_import_dialog.py           # Bulk CSV import with duplicate detection
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

# Output: build/app/outputs/flutter-apk/app-release.apk (~67 MB)
```

---

## How the Auto-Update System Works

The app checks for new versions on every launch without using Google Play Store.

```
App starts
  │
  └── UpdateService.checkForUpdate()
        │
        ├── GET app_updates/latest from Firestore
        │     (public read — runs before login)
        │
        ├── Compare version vs current version (from package_info_plus)
        │     │
        │     ├── Same version → do nothing
        │     │
        │     └── Newer version → show dialog
        │           │
        │           └── User taps "Download"
        │                 │
        │                 ├── Stream APK from downloadUrl
        │                 ├── Show progress (MB downloaded / total MB)
        │                 ├── Verify file size against Content-Length header
        │                 └── Open system installer via OpenFile plugin
```

> **Important:** `downloadUrl` must point to a **direct APK file** (e.g. a GitHub release asset like `https://github.com/shelad3/Kabete-Poly/releases/download/v2.9.0+1/app-release.apk`), NOT the release page. Pointing at a release page makes the app download HTML as a `.apk` and Android fails with "unable to parse the package".

### To publish a new update:

```bash
# 1. Bump version in pubspec.yaml
#    version: x.y.z+build

# 2. Build the APK
flutter build apk --release

# 3. Create a GitHub Release with the APK attached as an asset
gh release create v2.9.0+1                             \
    "build/app/outputs/flutter-apk/app-release.apk"    \
    --repo shelad3/Kabete-Poly                          \
    --title "v2.9.0+1"                                  \
    --notes "Description of changes"

# 4. Update the Firestore document app_updates/latest:
#    { version: "2.9.0",
#      downloadUrl: "https://github.com/shelad3/Kabete-Poly/releases/download/v2.9.0%2B1/app-release.apk",
#      releaseNotes: "..." }
#    (easiest via admin-tool Python SDK script, see AGENTS.md)
```

The app will detect the new version on next launch. Legacy app versions still check `api.github.com/repos/shelad3/Kabete-Poly/releases/latest` and will see the same release.

---

## Firebase Configuration

### Firestore Indexes

Deploy indexes after any query changes:

```bash
firebase deploy --only firestore:indexes
```

Current indexes cover: messages, notifications, lessons, schedules, auth_codes, auth_code_usage, alerts, lesson_verifications, cubes, cube_bookings (#1–#3), houses, exam_bookings, payments.

### Security Rules

```bash
firebase deploy --only firestore:rules
```

Rules enforce:
- Students read only their own grades and enrolled classes' data
- Teachers can write lessons, grades, and schedule entries
- Officials (admins) have full access
- `houses`, `cubes`, `field_indices`, `app_updates` are public-read
- `cube_bookings` authenticated read/create/update
- No client-side bypass — rules evaluated on every request

### Required Firebase Services

| Service | Purpose |
|---------|---------|
| Firebase Auth | Email/password + Google Sign-In |
| Cloud Firestore | All app data (lessons, users, grades, messages, timetable, bookings, payments, elections, exams, feature flags) |
| Firebase Cloud Messaging | Push notifications (class topics) |
| Firebase Storage | Legacy images (new uploads go to Cloudinary) |
| Firebase Hosting (optional) | Landing page or admin dashboard |

---

## Windows/Linux Admin Tool

A standalone desktop application for managing timetable entries, grades, classes, payments, exam timetables, and feature flags.

### Run from Source

```bash
cd admin-tool
python -m venv venv
source venv/bin/activate      # Linux/Mac
venv\Scripts\activate         # Windows
pip install -r requirements.txt
python main.py
```

### Build .exe

```batch
build_exe.bat
# Output: dist\KabeteAdminTool.exe
```

### The 8 Tabs

| Tab | Function |
|-----|----------|
| Grade Entry | Enter/edit CAT1/CAT2/Exam per student + CSV bulk import |
| Timetable Editor | Create/edit class schedules + CSV bulk import |
| Timetable Upload | 6-step wizard: mode (class/exam) → file (PDF/CSV) → parse → preview & select → verify duplicates → batch upload |
| Report Cards | Select class/term/year → generate PDF report cards for all students |
| Exam Timetable | CRUD exam entries with type color-coding (final/midterm/CAT/practical) |
| Payments | Summary stats, status filter, color-coded table, manual mark-completed/refunded |
| Feature Flags | List/toggle/edit/seed the 12 feature flags |
| Analytics | Grade distribution charts, subject averages, pass/fail rates |

Also includes: **QR Code Generator** → A4 PDF with all student QR cards (8 per page).

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.9.0+1 | Jul 2026 | Admin tool overhaul (timetable upload wizard, exam timetable, payments, feature flags), school ID card, feature flags, payments flow, student leader voting, exam booking, exam timetable tab |
| 2.8.7+1 | Jun 2026 | Notification overhaul, target timeline, explore restructure, house error handling |
| 2.8.6+1 | Jun 2026 | Firestore auto-update (moved from GitHub API) |
| 2.8.4+1 | Jun 2026 | Cube booking fixes, event gallery Cloudinary, attachment open fixes |
| 2.8.3+1 | Jun 2026 | Notification overhaul, target timeline, explore restructure, house error handling |
| 2.8.2 | Jun 2026 | Full cube booking overhaul — houses, term-based booking, 8k fee, auto-generate cubes |
| 2.8.1 | Jun 2026 | Houses rename, gallery in guest mode, optional event photos, explore spacing |
| 2.8.0 | Jun 2026 | QR activation, lesson verification, modular grading, gallery, community tab |
| 2.7.1 | Jun 2026 | Native splash collage (10 campus photos), bug fixes |
| 2.7.0 | Jun 2026 | Eliminate splash flash, admin tool fixes, timetable PDF extraction |
| 2.6.0 | Jun 2026 | Remove hardcoded TimetableData; classes from Firestore only |
| 2.5.0 | Jun 2026 | Timetable migrated to Firestore-only |
| 2.4.3 | Jun 2026 | Grades permission fix, timetable composite index deployed |
| 2.4.2 | Jun 2026 | Download progress MB counter, HEAD content-length integrity check |
| 2.4.0 | Jun 2026 | Grades module, push notifications, forum channels |
| 2.3.0 | May 2026 | Class forums, messaging, campus map |
| 2.2.0 | May 2026 | Timetable tab, auto-update system, Windows admin tool |
| 2.1.0 | Apr 2026 | Lesson archive, file uploads, role-based auth |
| 2.0.0 | Apr 2026 | Registration + login, guest mode, Firebase integration |
| 1.0.0 | Feb 2026 | Prototype with hardcoded data |

---

## License

GNU AGPL v3 — see [LICENSE](LICENSE).

---

## Contact

**Sheldon Ramu** — Electrical Engineering, Kabete National Polytechnique  
GitHub: [@shelad3](https://github.com/shelad3)  
Project: [github.com/shelad3/Kabete-Poly](https://github.com/shelad3/Kabete-Poly)  
Download: [github.com/shelad3/Kabete-Poly/releases](https://github.com/shelad3/Kabete-Poly/releases)
