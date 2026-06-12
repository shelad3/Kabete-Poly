# KNP Management System

### A Digital Classroom Platform for Kabete National Polytechnique

**Author:** Sheldon Ramu  
**Role:** Solo Developer  
**Age:** 21  
**Course:** Electrical Engineering — Level 5, Modular 2  
**Development Started:** February 15, 2026  
**Latest Version:** 2.2.0  

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

The app runs on Android and handles about five main jobs: storing and retrieving lessons, managing class schedules (timetables), hosting discussion forums for each class, sending push notifications for alerts and updates, and showing a campus map for locating rooms and offices.

---

## 2. Background & Motivation

I started this project in mid-February after noticing how much class time was wasted on logistics. Someone would print notes, distribute them, lose them, ask for another copy, and so on. Teachers would send timetable changes through WhatsApp groups where messages got buried within minutes. Lab schedules changed and half the class would show up at the wrong time.

The college had no central digital system. Every class relied on a mix of WhatsApp, Google Drive links that expired, and printed timetables that nobody could read after the first week. I wanted to build something that consolidated everything into one place — accessible from a phone, updated in real time, and organized by class.

There was also a personal angle. I am studying electrical engineering, not computer science. Everything I learned to build this — Flutter, Firebase, state management, UI design, deployment — I picked up along the way. The project became a way to prove to myself that you do not need a formal background in software to build something useful.

---

## 3. Platform Architecture

The app follows a standard Flutter + Firebase architecture. The front end is entirely written in Dart using Flutter's widget tree. The back end consists of Firebase services: Firestore for the database, Firebase Auth for authentication, Firebase Cloud Messaging for push notifications, and Cloudinary for file storage (PDFs, images).

State management is handled through Provider with ChangeNotifier classes. Each major domain — authentication, class selection, notifications — has its own provider that widgets consume via the provider package. This keeps the widget tree clean and avoids the boilerplate that comes with more complex state management solutions.

The app uses Google Maps Flutter for the campus map. This was a challenge because the Android view system has known issues with gesture conflicts inside scrollable pages. The fix involved switching from the default AndroidView surface to a VirtualDisplay surface, which decouples the map's touch handling from the parent scroll widget.

### Architecture Diagram (Simplified)

```
Flutter UI Layer (Widgets)
    │
    ├── Provider (State Management)
    │       ├── AuthProvider
    │       ├── ClassProvider
    │       ├── ThemeNotifier
    │       └── UnreadBadgeProvider
    │
    ├── Firebase Services
    │       ├── Firebase Auth (Login/Registration)
    │       ├── Cloud Firestore (Database)
    │       └── Firebase Messaging (Push Notifications)
    │
    └── External Services
            ├── Cloudinary (File Storage)
            ├── Google Maps (Campus Map)
            └── GitHub API (Auto-updates)
```

---

## 4. Core Features

### 4.1 Lesson Archive

Teachers can post completed lessons with topic, subtopic, notes content, a summary, and a practical report section. Each lesson supports multiple PDF or document attachments. Students in the same class see these lessons in a scrollable feed on the Explore tab.

The lesson card shows the topic, subtopic, teacher name, and date. Tapping it opens a detail view with tabbed sections for Notes, Summary, Report, and NB columns. Teachers can edit or delete their own lessons.

### 4.2 Schedule & Timetable

Every class has a timetable split into three views:
- **Mandatory tab** — shows the official recurring timetable (set by the administration at the start of the term)
- **Target Timeline tab** — shows upcoming one-off events like guest lectures, lab sessions, or changed schedules
- **Map tab** — interactive campus map with pinned locations for classrooms, labs, and lecturer offices

Teachers can schedule upcoming theory or practical classes through a bottom sheet menu. When they do, the system automatically creates a schedule entry and sends a push notification to everyone in that class.

### 4.3 Discussion Forums

Each class gets its own set of forum channels. By default, every class starts with two channels: "Global" (announcements, admin-only posting) and "Public Chat Room" (open discussion). Teachers and class leaders can create additional channels.

Messages appear in real time through Firestore stream listeners. Announcement channels restrict posting to teachers and admins, while chat channels are open to everyone in the class. Channel management — creating, renaming, and deleting — is available to teachers and admins.

### 4.4 Notifications & Alerts

The app uses Firebase Cloud Messaging for push notifications. When a teacher schedules a class or posts a lesson, a notification goes out to all enrolled students. Admins can broadcast alerts targeted at specific users, registration numbers, or entire classes.

The bottom navigation bar shows a badge with the total count of unread notifications and alerts. The badge updates in real time and resets when the user opens the Alerts tab.

### 4.5 Campus Map

An interactive Google Map marks the locations of lecture halls, labs, and administrative offices across the Kabete campus. Users can tap on markers to see location details. The map is also integrated with the timetable — tapping a schedule entry can navigate directly to the map with the relevant room highlighted.

### 4.6 Automatic Updates

The app checks for new versions by querying the GitHub releases API. When a newer version is found, it downloads the APK in the background with a progress indicator and opens the system installer. This means users do not need to manually download updates from a website.

### 4.7 Role-Based Registration

New users go through a structured registration flow. After signing up, they select their role — Student, Teacher, Leader, or Official — and then choose their specific designation from a categorized dropdown list. Students select their class cohort. Teachers select their department from eight options. Leaders select their position type. Officials select their office.

Elevated roles (Teacher, Leader, Official) require an access key during registration to prevent unauthorized signups.

---

## 5. User Roles & Permissions

| Role | Capabilities |
|---|---|
| **Student** | View lessons, view schedule, post in chat channels, view grades, submit help requests |
| **Leader** (Class Rep, Prefect) | Everything a Student can do, plus create forum channels, post announcements |
| **Teacher** | Post lessons, schedule classes, create quizzes, manage forum channels, edit/delete own content |
| **Official** (Admin) | Full access: manage all users, send global alerts, delete any content, view admin dashboard with stats |

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
- **Cloud Firestore** — NoSQL document database, real-time sync
- **Firebase Cloud Messaging** — Push notifications
- **Firebase Analytics** — Usage tracking
- **Cloudinary** — File upload and storage for PDFs and images
- **GitHub API** — Automatic update checking and APK distribution

### Key Flutter Packages
- `cloud_firestore` — Firestore database access
- `firebase_auth` — Authentication
- `firebase_messaging` — Push notifications
- `google_maps_flutter` — Campus map
- `provider` — State management
- `file_picker` — Document selection
- `url_launcher` — Opening external links and files
- `shared_preferences` — Local storage for settings
- `intl` — Date and time formatting
- `shimmer` — Loading placeholders
- `permission_handler` — Runtime permission requests

### Build & Deployment
- **Android APK** — Built with Flutter's Gradle toolchain
- **ProGuard/R8** — Code minification and obfuscation for release builds
- **GitHub Releases** — APK distribution for auto-updates
- **Git** — Version control

---

## 7. Firestore Data Model

The database is organized into the following collections:

- **users** — User profiles with role, enrolled classes, contact info
- **lessons** — Lesson content with attachments, filtered by classId
- **schedules** — Timetable entries (both recurring and one-off), linked to classId
- **forum_channels** — Discussion channels per class, with name and type
- **messages** — Forum messages linked to channelId
- **notifications** — Push notification records linked to classId
- **alerts** — Administrative alerts with target types (all, user, class, regNo)
- **auth_codes** — Access keys for elevated role registration
- **help_requests** — Student support tickets
- **error_reports** — Bug reports from users
- **feedback** — General app feedback
- **class_change_requests** — Requests to switch class cohorts

Most read operations are limited to 100-200 documents to keep queries fast. Real-time streams are used for feeds, messages, and notifications so updates appear instantly.

---

## 8. Security & Access Control

### Firestore Security Rules

The security rules follow a role-based model. A helper function looks up the user's role from the `users` collection and grants access accordingly:

- **Lessons** — Readable by any authenticated user, writable only by teachers and admins
- **Forum channels** — Readable by all, creatable by leaders and above, editable by teachers and above, deletable only by admins
- **Messages** — Readable and creatable by all authenticated users, editable only by the sender
- **Alerts** — Only admins can send; all authenticated users can read
- **Auth codes** — Readable only by authenticated users (previously public)

### Authentication

The app supports two sign-in methods:
- Email and password (with Firebase Email/Password Auth)
- Google Sign-In

Registration collects additional profile data (full name, phone number, role, class cohort) which is stored in the `users` collection.

### Client-Side Safety

While the Firestore rules are the primary security layer, the app also hides UI elements that the user does not have permission to use. For example, the floating action button for posting lessons only appears for teachers. The channel management menu only shows for authorized roles. This prevents confusion as much as it prevents access.

---

## 9. Development Journey

I started working on this project on February 15, 2026. At that point I had been studying electrical engineering for about a year and a half and had written maybe a hundred lines of Dart in my life. The first version was a bare-bones lesson viewer that pulled documents from Firestore and displayed them in a list. It crashed if you looked at it wrong.

The timetable feature came next, and it was honestly the hardest part. Representing recurring weekly classes alongside one-off events in a NoSQL database took several redesigns. I ended up storing a `isDefault` boolean on each schedule entry — recurring classes have day-of-week values, while dynamic ones have specific dates. The app merges both types and sorts them at query time.

The forum system was added because students kept asking for a place to discuss lessons within the app instead of jumping to WhatsApp. Real-time messaging through Firestore streams turned out to be simpler than I expected — Firestore handles the WebSocket connections under the hood, so I just needed to wire up the UI.

The map integration was the most technically challenging part. The Flutter Google Maps plugin uses Android's native MapView under the hood, and that native view does not play well with Flutter's gesture system inside scrollable pages. After two weeks of trial and error, the fix was setting `useAndroidViewSurface = false`, which switches from the default Hybrid Composition to VirtualDisplay mode. This decouples the map's touch handling from the parent scroll view.

Notifications were added later when the college administration asked if the app could broadcast alerts. Firebase Cloud Messaging made this straightforward, though getting notification permissions right on newer Android versions required some additional handling with the `permission_handler` package.

The automatic update system came from a practical need — I did not want to keep sending APK files through WhatsApp every time I pushed a fix. The app now checks a GitHub release endpoint on startup and downloads updates if available.

---

## 10. Challenges & Solutions

### Gesture Conflicts with Google Maps

**Problem:** The map widget inside the schedule screen's TabBarView would interpret horizontal swipes as tab-switching gestures. Panning the map would accidentally switch to the Target Timeline tab.

**Solution:** Set `NeverScrollableScrollPhysics` on the TabBarView's internal PageView and on the outer PageView that controls the bottom navigation. Users now tap tab headers or bottom nav items to switch instead of swiping. This eliminated the gesture conflict entirely.

### Offline Handling

**Problem:** The app would hang indefinitely on the splash screen when there was no internet connection. Firebase calls had no timeouts, and exceptions were silently swallowed, causing authenticated users to be redirected to the login screen when offline.

**Solution:** Added timeouts to all Firebase calls (10 seconds for auth, 15 seconds for Firestore). Enabled Firestore's offline persistence with unlimited cache size. Added a fallback path that uses the AuthProvider's cached profile when Firestore is unavailable. The splash screen now shows a "No connection" message with a retry button instead of hanging silently.

### Lesson Visibility Across Classes

**Problem:** Teachers would post lessons but students in the same class could not see them. The lesson query filters by `classId` with strict equality, and the posting screen did not show which class the teacher was currently posting to.

**Solution:** Added a visible class context banner at the top of the lesson posting form that reads "Posting to: [ClassName]". Changed the lesson ID generation from a timestamp string (which could collide) to Firestore's auto-generated document IDs.

### File Attachments

**Problem:** Each lesson or schedule entry could only have one attached file. Teachers wanted to upload multiple PDFs — for example, a lesson note file and a separate lab report.

**Solution:** Migrated the attachment fields from single strings to lists of strings in both the Lesson and ScheduleItem models. Updated the file picker to accept multiple files simultaneously. The UI now shows all attached files with individual remove buttons.

---

## 11. Future Roadmap

1. **iOS Release** — The app currently targets Android only. An iOS build requires a Mac build environment and some platform-specific adjustments for notifications and maps.

2. **Offline-First Mode** — While basic offline persistence is enabled, the app could benefit from a more robust offline mode that queues writes when disconnected and syncs when connectivity returns.

3. **Quiz Engine** — The quiz feature currently navigates to a quiz list screen but the full quiz-taking experience (timed assessments, auto-grading, score tracking) is still in development.

4. **Grade Portal** — Students can view a grade report screen, but integration with the college's grading system would require an API or a shared data source.

5. **Web Version** — Flutter's web support could make the app accessible from desktop browsers, which may be useful for lecturers who prefer typing on a laptop.

6. **Dark Mode Refinements** — The app supports dark mode through a ThemeNotifier, but some screens still have hardcoded light colors that need to be migrated to theme-aware values.

---

## 12. Conclusion

The KNP Management System started as a personal project to solve a practical problem — the chaos of managing class materials, schedules, and communication at a technical polytechnic. Over four months, it grew from a simple lesson viewer into a full-featured platform with real-time messaging, push notifications, interactive maps, and automatic updates.

Building it taught me that software development is less about knowing everything upfront and more about being willing to figure things out as you go. I ran into problems I did not know how to solve — gesture conflicts, NoSQL data modeling, notification permissions — and I solved them by reading documentation, testing things, and sometimes starting over.

The app is currently used by students and teachers at Kabete National Polytechnique. It is not perfect, but it improves the way our classes share information, and that was the whole point.

---

*Document prepared by Sheldon Ramu*  
*Kabete National Polytechnique — Electrical Engineering Department*  
*Version 2.2.0 — June 2026*
