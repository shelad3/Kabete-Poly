# KNP Management System

### A Digital Classroom Platform for Kabete National Polytechnique

**Author:** Sheldon Ramu  
**Role:** Solo Developer  
**Age:** 21  
**Course:** Electrical Engineering — Level 5, Modular 2  
**Development Started:** February 15, 2026  
**Latest Version:** 2.9.0+1  

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Background & Motivation](#2-background--motivation)
3. [Platform Architecture](#3-platform-architecture)
4. [Core Features](#4-core-features)
5. [User Roles & Permissions](#5-user-roles--permissions)
6. [Technology Stack](#6-technology-stack)
7. [Firestore Data Model](#7-firestore-data-model)
8. [Security & Access Control](#8-security--access-control)
9. [Development Journey](#9-development-journey)
10. [Challenges & Solutions](#10-challenges--solutions)
11. [Future Roadmap](#11-future-roadmap)
12. [Conclusion](#12-conclusion)

---

## 1. Introduction

The KNP Management System is a mobile application built specifically for Kabete National Polytechnique. It replaces the old paper-based way of sharing lecture notes, lab reports, and class schedules with something that works in real time. Students can access their lessons from their phones, teachers can post materials directly to their classes, and everyone gets notified when something new goes up.

Beyond the academic core, the platform now covers the full student journey: hostel booking with live availability and receipts, exam registration, student leader voting, payment tracking, school ID cards, in-class quizzes, and a campus event gallery.

The app runs on Android (129 Dart files, ~31,600 lines) and is supported by a Python/PyQt6 desktop admin tool for staff (21 files, ~5,900 lines) that handles grade entry, report cards, timetable upload, payments, exam timetables, and feature flags.

---

## 2. Background & Motivation

I started this project in mid-February after noticing how much class time was wasted on logistics. Someone would print notes, distribute them, lose them, ask for another copy, and so on. Teachers would send timetable changes through WhatsApp groups where messages got buried within minutes. Lab schedules changed and half the class would show up at the wrong time.

The college had no central digital system. Every class relied on a mix of WhatsApp, Google Drive links that expired, and printed timetables that nobody could read after the first week. I wanted to build something that consolidated everything into one place — accessible from a phone, updated in real time, and organized by class.

There was also a personal angle. I am studying electrical engineering, not computer science. Everything I learned to build this — Flutter, Firebase, state management, UI design, deployment — I picked up along the way. The project became a way to prove to myself that you do not need a formal background in software to build something useful.

---

## 3. Platform Architecture

The app follows a standard Flutter + Firebase architecture. The front end is entirely written in Dart using Flutter's widget tree. The back end consists of Firebase services: Firestore for the database, Firebase Auth for authentication, Firebase Cloud Messaging for push notifications, and Cloudinary for file storage (PDFs, images).

State management is handled through Provider with ChangeNotifier classes. Each major domain — authentication, class selection, notifications, feature flags — has its own provider that widgets consume via the provider package. Services are plain Dart singletons; providers wrap them for UI reactivity. This keeps the widget tree clean and avoids the boilerplate that comes with more complex state management solutions.

Critical writes use `FirebaseFirestore.instance.runTransaction()` for atomicity: cube booking creation (double-booking + capacity check in one transaction), voting (single ballot per election + position), and exam registration (seat-capacity enforcement).

The app uses Google Maps Flutter for the campus map. The map runs on a VirtualDisplay surface (`useAndroidViewSurface = false`), which decouples the map's touch handling from the parent scroll widget.

### Architecture Diagram (Simplified)

```
Flutter UI Layer (Widgets)
    │
    ├── Provider (State Management)
    │       ├── AuthProvider
    │       ├── ClassProvider
    │       ├── ThemeNotifier
    │       ├── UnreadBadgeProvider
    │       ├── FeatureFlagProvider
    │       └── ConnectivityProvider
    │
    ├── Firebase Services
    │       ├── Firebase Auth (Login/Registration)
    │       ├── Cloud Firestore (Database, real-time + transactions)
    │       └── Firebase Messaging (Push Notifications)
    │
    └── External Services
            ├── Cloudinary (File Storage)
            ├── Google Maps (Campus Map)
            └── GitHub Releases (APK hosting for auto-updates)
```

---

## 4. Core Features

### 4.1 Lesson Archive

Teachers can post completed lessons with topic, subtopic, notes content, a summary, and a practical report section. Each lesson supports multiple PDF or document attachments. Students in the same class see these lessons in a scrollable feed on the Explore tab.

The lesson card shows the topic, subtopic, teacher name, and date. Tapping it opens a detail view with tabbed sections for Notes, Summary, Report, and NB columns. Teachers can edit or delete their own lessons.

### 4.2 Schedule & Timetable

Every class has a timetable split into four views:
- **Mandatory tab** — shows the official recurring timetable (set by the administration at the start of the term)
- **Target Timeline tab** — shows upcoming one-off events like guest lectures, lab sessions, or changed schedules
- **Exams tab** — the exam timetable, grouped by date with type color-coding (final = red, midterm = orange, CAT = green, practical = blue)
- **Map tab** — interactive campus map with pinned locations for classrooms, labs, and lecturer offices

Teachers can schedule upcoming theory or practical classes through a bottom sheet menu. When they do, the system automatically creates a schedule entry and sends a push notification to everyone in that class.

### 4.3 Hostel Booking System

Students browse houses (boys/girls tabs), view cubicle availability in real time via Firestore streams, and book a cubicle. Key details:

- **Transactional booking** — `createBooking()` runs inside a Firestore transaction: it checks for an existing active booking AND counts current occupancy before writing. This closes the double-booking race and prevents capacity overflow. `BookingConflictException` is thrown on conflict.
- **Booking receipts** — a dedicated receipt screen after successful confirmation
- **Reserved houses** — houses flagged `reservedForNewStudents` are hidden from returning students
- **Guest houses view** — prospective students see house/cube occupancy without signing in
- **Waitlist** — students join a waitlist when a house is full; entries are streamed in My Bookings
- **Status lifecycle** — pending → confirmed → checked-in → completed, with cancellation; the `'completed'` status counts as occupied

### 4.4 Payments

The booking fee flow (KES 5,000) is integrated after booking confirmation:

- **Payment Method screen** — method selection (M-Pesa, card, bank/cash), phone number entry, and a payment summary
- **Payment Status screen** — animated waiting state with a 5-minute timeout
- Admin tool **Payment Dashboard** — summary stats (total/paid/pending/refunded), status filter, color-coded table, and manual mark-completed/refunded overrides

### 4.5 Exam Booking

Students register for exams against a seat capacity. `ExamBookingService.register()` runs atomically — the transaction checks remaining seats before writing, so oversubscription is impossible.

### 4.6 Student Leader Voting

Position-based elections (Chairperson, Secretary, etc.):

- **Voting dashboard** — lists elections with status-driven actions (active → vote, published → results)
- **Vote cast** — position-by-position candidate selection
- **Results** — bar charts with winner indicators
- **Privacy** — `castVote()` stores a SHA-256 ballot hash (student + election + position + salt) instead of the student ID, so votes are anonymous yet unforgeable. Casting is atomic in a transaction — one vote per position.
- **Admin management** — create, activate, close, and publish elections from a dedicated admin screen

### 4.7 Feature Flags

A remote-configurable feature toggle system:

- 12 flags seeded with defaults (quiz, grades, hostel, exams, voting, payments, etc.), all `enabled: true`
- Each flag supports a schedule window and role restrictions
- UI is gated declaratively with the `FeatureGate` widget and `checkFeatureEnabled()`
- Managed from both an in-app admin screen and the admin tool's Feature Flags tab

### 4.8 Quizzes

In-class quizzes with scoring. Teachers create quizzes with multiple-choice questions; students take them and see results immediately.

### 4.9 School ID Card

A digital ID card showing the student photo, regNo, full name, gender, nationality, and a green/gold KNP-themed layout with the Kenyan courts seal and school logo. `UserProfile` carries `gender` and `nationality` fields.

### 4.10 Discussion Forums

Each class gets its own set of forum channels. By default, every class starts with two channels: "Global" (announcements, admin-only posting) and "Public Chat Room" (open discussion). Teachers and class leaders can create additional channels.

Messages appear in real time through Firestore stream listeners. Announcement channels restrict posting to teachers and admins, while chat channels are open to everyone in the class. Channel management — creating, renaming, and deleting — is available to teachers and admins.

### 4.11 Notifications & Alerts

The app uses Firebase Cloud Messaging for push notifications. When a teacher schedules a class or posts a lesson, a notification goes out to all enrolled students. Admins can broadcast alerts targeted at specific users, registration numbers, or entire classes.

The notification center is split into tabs (Class Notifications / Admin Alerts / Updates) with unread badge counters. Admin alerts are per-student (filtered by `studentId`), so a targeted alert is never broadcast to the whole school.

### 4.12 Campus Map

An interactive Google Map marks the locations of lecture halls, labs, and administrative offices across the Kabete campus. Users can tap on markers to see location details. The map is also integrated with the timetable — tapping a schedule entry can navigate directly to the map with the relevant room highlighted.

### 4.13 QR Attendance & Lesson Verification

Students get a time-based QR code (`uid|rounded_timestamp`) displayed with `FLAG_SECURE` (screenshots blocked) and a 60-second expiry. Teachers scan with the companion scanner app: the system validates timestamp freshness, class enrollment, and rejects duplicate scans. Lesson verification tracks which students attended which lessons.

### 4.14 Event Gallery

A campus events gallery with photos hosted on Cloudinary. Visible to guests as well as authenticated users.

### 4.15 Automatic Updates

The app checks for new versions on every launch by reading the `app_updates/latest` document from Firestore (public read). When a newer version is found, it downloads the APK with a progress indicator (MB counter + `Content-Length` integrity check) and opens the system installer. Legacy versions still check the GitHub releases API — both paths resolve to the same release asset.

### 4.16 Role-Based Registration

New users go through a structured registration flow. After signing up, they select their role — Student, Teacher, Leader, or Official — and then choose their specific designation from a categorized dropdown list. Students select their class cohort. Teachers select their department from eight options. Leaders select their position type. Officials select their office.

Elevated roles (Teacher, Leader, Official) require an access key during registration to prevent unauthorized signups.

---

## 5. User Roles & Permissions

| Role | Capabilities |
|---|---|
| **Guest** | Browse campus info, view house/cube occupancy, browse gallery — no login |
| **Student** | View lessons, view schedule, post in chat channels, view grades, book hostels, register for exams, vote, take quizzes, submit help requests |
| **Leader** (Class Rep, Prefect) | Everything a Student can do, plus create forum channels, post announcements |
| **Teacher** | Post lessons, schedule classes, create quizzes, manage grades, verify lesson attendance, manage forum channels, edit/delete own content |
| **Official** (Admin) | Full access: manage all users, send global alerts, manage bookings/payments/elections/exam timetables/feature flags, delete any content, view admin dashboard with stats |

Permissions are enforced both client-side (UI visibility) and server-side (Firestore security rules).

---

## 6. Technology Stack

### Frontend
- **Flutter** — Cross-platform UI framework (Android primary target, iOS compatible)
- **Dart** — Programming language
- **Provider** — State management
- **Google Maps Flutter** — Campus map integration

### Backend & Services
- **Firebase Auth** — Email/password and Google Sign-In authentication
- **Cloud Firestore** — NoSQL document database, real-time sync, transactions
- **Firebase Cloud Messaging** — Push notifications
- **Firebase Analytics** — Usage tracking
- **Cloudinary** — File upload and storage for PDFs and images
- **GitHub Releases** — APK hosting for auto-updates (Firestore `app_updates` drives the check)

### Key Flutter Packages
- `cloud_firestore` — Firestore database access
- `firebase_auth` — Authentication
- `firebase_messaging` — Push notifications
- `google_maps_flutter` — Campus map
- `provider` — State management
- `crypto` — SHA-256 ballot hashing for voting privacy
- `file_picker` — Document selection
- `url_launcher` — Opening external links and files
- `shared_preferences` — Local storage for settings
- `intl` — Date and time formatting
- `shimmer` — Loading placeholders
- `permission_handler` — Runtime permission requests

### Build & Deployment
- **Android APK** — Built with Flutter's Gradle toolchain
- **GitHub Releases** — APK distribution for auto-updates
- **Git** — Version control

---

## 7. Firestore Data Model

The database is organized into the following collections (41 total):

**Academic Core:**
- **users** — User profiles with role, enrolled classes, contact info, gender, nationality
- **classes** — Class cohorts; `classes/{id}/timetable/` subcollection holds schedule entries
- **timetable** — Class schedule entries (legacy / flattened)
- **grades** — Per-student per-subject CAT1, CAT2, Exam scores
- **lessons** — Lesson content with attachments, filtered by classId
- **schedules** — Timetable entries (both recurring and one-off), linked to classId
- **attendance** — Scanned attendance records
- **lesson_verifications** — Lesson attendance verification records
- **exam_timetable** — Exam schedule entries with type (final/midterm/CAT/practical)
- **exams** — Exams available for registration, with seat capacity
- **exam_bookings** — Student exam registrations

**Hostel & Payments:**
- **houses** — Hostel houses with category, max occupancy, reservedForNewStudents
- **cubes** — Individual cubicles linked to houses
- **cube_bookings** — Booking records with status + paymentStatus
- **waitlist** — Waitlist entries for full houses
- **payments** — Payment records with method and status

**Engagement:**
- **forum_channels** — Discussion channels per class, with name and type
- **messages** — Forum messages linked to channelId
- **notifications** — Push notification records (class notifications + admin alerts)
- **alerts** — Administrative alerts with target types (all, user, class, regNo)
- **events** — Campus events with Cloudinary image URLs
- **photos** — Gallery photos
- **quizzes** / **questions** / **quiz_submissions** — Quiz engine data
- **elections** / **positions** / **candidates** / **ballots** — Voting system data

**Infrastructure & Admin:**
- **auth_codes** — Access keys for elevated role registration
- **auth_code_usage** — Usage audit for access codes
- **feature_flags** — Remote feature toggles with schedule/roles
- **field_indices** — Registration index (public read/create)
- **help_requests** — Student support tickets
- **error_reports** — Bug reports from users
- **feedback** — General app feedback
- **class_change_requests** — Requests to switch class cohorts
- **sessions** — Active user sessions
- **active_qr_sessions** — QR attendance sessions
- **lesson_templates** / **schedule_templates** — Reusable lesson/schedule templates
- **school_info** — Institution info shown in guest mode

Most read operations are limited to 100-200 documents to keep queries fast. Real-time streams are used for feeds, messages, and notifications so updates appear instantly.

---

## 8. Security & Access Control

### Firestore Security Rules

The security rules follow a role-based model. A helper function looks up the user's role from the `users` collection and grants access accordingly:

- **Lessons** — Readable by any authenticated user, writable only by teachers and admins
- **Forum channels** — Readable by all, creatable by leaders and above, editable by teachers and above, deletable only by admins
- **Messages** — Readable and creatable by all authenticated users, editable only by the sender
- **Alerts** — Only admins can send; all authenticated users can read
- **Auth codes** — Readable only by authenticated users
- **Houses, cubes** — Public read (guest browsing), admin/official write
- **cube_bookings** — Authenticated read/create/update, admin delete
- **app_updates** — Public read (update checks run before login)
- **field_indices** — Public read/create (registration runs before the auth user exists)

### Critical Writes Are Transactional

| Operation | Mechanism |
|-----------|-----------|
| Cube booking | `runTransaction` — double-booking + capacity count in one atomic transaction |
| Vote casting | `runTransaction` — one ballot per election + position, SHA-256 hash stored |
| Exam registration | `runTransaction` — seat-capacity check before write |

### Voting Privacy

Ballots store a `sha256(studentId + electionId + positionId + salt)` hash, never the student ID. Votes are anonymous to anyone reading the database while remaining cryptographically verifiable.

### Authentication

The app supports two sign-in methods:
- Email and password (with Firebase Email/Password Auth)
- Google Sign-In

Registration collects additional profile data (full name, phone number, role, class cohort, gender, nationality) which is stored in the `users` collection.

### Client-Side Safety

While the Firestore rules are the primary security layer, the app also hides UI elements that the user does not have permission to use. Feature gates hide disabled features at the widget level. For example, the floating action button for posting lessons only appears for teachers, and disabled feature flags remove their entry cards from the Explore screen.

---

## 9. Development Journey

I started working on this project on February 15, 2026. At that point I had been studying electrical engineering for about a year and a half and had written maybe a hundred lines of Dart in my life. The first version was a bare-bones lesson viewer that pulled documents from Firestore and displayed them in a list. It crashed if you looked at it wrong.

The timetable feature came next, and it was honestly the hardest part. Representing recurring weekly classes alongside one-off events in a NoSQL database took several redesigns. I ended up storing a `isDefault` boolean on each schedule entry — recurring classes have day-of-week values, while dynamic ones have specific dates. The app merges both types and sorts them at query time.

The forum system was added because students kept asking for a place to discuss lessons within the app instead of jumping to WhatsApp. Real-time messaging through Firestore streams turned out to be simpler than I expected — Firestore handles the WebSocket connections under the hood, so I just needed to wire up the UI.

The map integration was the most technically challenging part. The Flutter Google Maps plugin uses Android's native MapView under the hood, and that native view does not play well with Flutter's gesture system inside scrollable pages. After two weeks of trial and error, the fix was setting `useAndroidViewSurface = false`, which switches from the default Hybrid Composition to VirtualDisplay mode.

Notifications were added later when the college administration asked if the app could broadcast alerts. Firebase Cloud Messaging made this straightforward, though getting notification permissions right on newer Android versions required some additional handling with the `permission_handler` package.

The automatic update system came from a practical need — I did not want to keep sending APK files through WhatsApp every time I pushed a fix. The app now checks a Firestore `app_updates/latest` document on startup and downloads updates from the GitHub release asset.

The hostel booking system was a turning point. What started as a simple "book a lab workstation" feature grew into a full module: houses, cubicles, live availability streams, transaction-safe booking, receipts, reserved houses for new students, a guest view, and a waitlist. It taught me to think in terms of race conditions and atomicity — the double-booking bug, where two students could grab the same cubicle simultaneously, was fixed by moving the check-and-write into a single Firestore transaction.

The latest phase added payment flow, student leader voting, exam booking, exam timetable, school ID cards, feature flags, and a full admin-tool overhaul. The admin tool grew from 4 tabs to 8, including a 6-step timetable upload wizard that parses PDF and CSV files, lets staff preview and select entries grouped by class, detects duplicates against Firestore, and batches the upload.

---

## 10. Challenges & Solutions

### Gesture Conflicts with Google Maps

**Problem:** The map widget inside the schedule screen's TabBarView would interpret horizontal swipes as tab-switching gestures. Panning the map would accidentally switch to the Target Timeline tab.

**Solution:** Set `NeverScrollableScrollPhysics` on the TabBarView's internal PageView and on the outer PageView that controls the bottom navigation. Users now tap tab headers or bottom nav items to switch instead of swiping.

### Double-Booking Race Condition

**Problem:** Two students could book the same cubicle at the same time. The check-then-write was non-atomic, so the capacity count and double-booking check could both pass before either write landed.

**Solution:** `CubeService.createBooking()` now runs the entire check-and-write inside `FirebaseFirestore.instance.runTransaction()`. Either the whole booking succeeds atomically or `BookingConflictException` is thrown. The same pattern was applied to voting and exam registration.

### Offline Handling

**Problem:** The app would hang indefinitely on the splash screen when there was no internet connection. Firebase calls had no timeouts, and exceptions were silently swallowed, causing authenticated users to be redirected to the login screen when offline.

**Solution:** Added timeouts to all Firebase calls (10 seconds for auth, 15 seconds for Firestore). Enabled Firestore's offline persistence with unlimited cache size. Added a fallback path that uses the AuthProvider's cached profile when Firestore is unavailable. The splash screen now shows a "No connection" message with a retry button instead of hanging silently.

### Update "Unable to Parse the Package"

**Problem:** Users updating in-app hit Android's "unable to parse the package" error.

**Solution:** The `downloadUrl` in `app_updates/latest` had pointed at the GitHub release *page* (an HTML page). The app was downloading HTML and saving it as `.apk`. The fix was pointing `downloadUrl` at the direct release asset URL (`.../releases/download/v2.9.0+1/app-release.apk`).

### Notification Broadcast Leak

**Problem:** A targeted admin alert was being sent to every student instead of just the intended recipient.

**Solution:** Added a `studentId` field to the notification model and `getNotificationsStream()` now accepts an optional `studentId` filter, scoping reads to the owner.

### Lesson Visibility Across Classes

**Problem:** Teachers would post lessons but students in the same class could not see them. The lesson query filters by `classId` with strict equality, and the posting screen did not show which class the teacher was currently posting to.

**Solution:** Added a visible class context banner at the top of the lesson posting form. Changed the lesson ID generation from a timestamp string (which could collide) to Firestore's auto-generated document IDs.

### File Attachments

**Problem:** Each lesson or schedule entry could only have one attached file.

**Solution:** Migrated the attachment fields from single strings to lists of strings in both the Lesson and ScheduleItem models. The UI now shows all attached files with individual remove buttons.

---

## 11. Future Roadmap

1. **M-Pesa integration (Daraja API)** — Currently the payment flow records the fee and payment status manually. Cloud Functions calling Safaricom's STK Push API would make payments fully automatic, with callbacks updating Firestore.

2. **Auto-expiry of pending bookings** — A scheduled Cloud Function to expire stale pending bookings and promote waitlist entries automatically.

3. **iOS Release** — The app currently targets Android only. An iOS build requires a Mac build environment and some platform-specific adjustments for notifications and maps.

4. **Robust Offline-First Mode** — While basic offline persistence is enabled, the app could benefit from queued writes that sync when connectivity returns.

5. **Timetable Conflict Detection** — Auto-detect overlapping room/lecturer assignments in the admin tool.

6. **Web Version** — Flutter's web support could make the app accessible from desktop browsers (the student portal already shares the same Firebase project).

---

## 12. Conclusion

The KNP Management System started as a personal project to solve a practical problem — the chaos of managing class materials, schedules, and communication at a technical polytechnic. Over five months, it grew from a simple lesson viewer into a full-featured platform: real-time messaging, push notifications, interactive maps, automatic updates, hostel booking with transactional integrity, payments, student leader voting, exam booking, quizzes, and a school ID card — all backed by a desktop admin tool that digitizes the administration side.

Building it taught me that software development is less about knowing everything upfront and more about being willing to figure things out as you go. I ran into problems I did not know how to solve — race conditions, NoSQL data modeling, notification permissions, native view conflicts — and I solved them by reading documentation, testing things, and sometimes starting over.

The app is used by students and teachers at Kabete National Polytechnique. It is not perfect, but it improves the way our classes share information, book hostels, take exams, and stay informed — and that was the whole point.

---

*Document prepared by Sheldon Ramu*  
*Kabete National Polytechnique — Electrical Engineering Department*  
*Version 2.9.0+1 — July 2026*
