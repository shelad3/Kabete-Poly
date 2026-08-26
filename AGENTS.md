# Agent Context

## Current Version
- pubspec: `2.9.0+1`
- Release: https://github.com/shelad3/Kabete-Poly/releases/tag/v2.9.0%2B1
- APK: 66.7 MB at `build/app/outputs/flutter-apk/app-release.apk`

## Project Stats
- Dart files: 129 | Dart lines: ~31,644
- Admin tool: 21 Python files | ~5,932 lines
- Firestore collections: 41

## Infrastructure
- Firebase project: `kabete-94936`
- Cloudinary cloud: `dpa8tbxdj`, upload preset: `Kabete_uploads`
- In-app update source: Firestore `app_updates/latest` (NOT GitHub API)
  - Document: `app_updates/latest` → `{version, downloadUrl, releaseNotes}`
  - `downloadUrl` must point to a DIRECT APK asset URL (e.g. GitHub release asset `.../releases/download/vX.Y.Z+1/app-release.apk`), NOT a release page
- Legacy versions still check: `https://api.github.com/repos/shelad3/Kabete-Poly/releases/latest`

## Key Firestore Rules
- `field_indices`: `allow read, create: if true` (public — needed because registration runs before auth user is created)
- `houses`, `cubes`: `allow read: if true` (public — guests can see availability)
- `cube_bookings`: `allow read: if isAuthenticated()`, `allow create, update: if isAuthenticated()`
- `app_updates`: `allow read: if true` (public — update checks run pre-login)
- All other collections: `if isTeacherOrAbove()` or owner-based checks

## Composite Indexes (firestore.indexes.json)
- `messages` (conversationId + createdAt)
- `notifications` (studentId + type + read + createdAt)
- `lessons` (batchId + createdAt)
- `schedules` (batchId + date)
- `auth_codes` (studentId + used + createdAt)
- `auth_code_usage` (codeId + createdAt)
- `alerts` (studentId + read + createdAt)
- `lesson_verifications` (studentId + lessonId)
- `cubes` (houseId + cubeNumber)
- `cube_bookings` #1 (studentId + term + year + houseName) — for getMyBookingsStream
- `cube_bookings` #2 (term + year + houseName + cubeNumber) — for getAllBookingsStream
- `cube_bookings` #3 (cubeId + term + year + status) — for getBookedCountForCube
- `houses` (category + name) — for getHousesByCategoryStream
- `exam_bookings` (studentId + examId) — for getMyRegistrationsStream
- `payments` (studentId + status) — for payment history

## Remaining Known Bugs / UX Issues
- (none currently tracked)

## Key Service Notes
- `CubeService.createBooking` runs inside `FirebaseFirestore.instance.runTransaction()` — atomic double-booking + capacity check. Throws `BookingConflictException`.
- `CubeService._activeStatuses` includes `'completed'` (a completed booking counts as active/occupied).
- `UpdateService` reads `app_updates/latest` from Firestore, clears `update_available` flag after download completes (not after install confirmation).
- `StorageService` wraps Cloudinary for all new uploads. Legacy image URLs may still reference Firebase Storage.
- `CubeService.getBookedCountForCube` uses 4-equality Firestore query (needs index #3 above).
- `HouseListScreen` filters out `reservedForNewStudents` houses for non-new students (checked via `UserProfile.enrolledTerm == currentTerm && enrolledYear == currentYear`).
- `BookingReceiptScreen` shown when user opens "Book a Cubicle" and already has an active booking.
- Guest houses view (`GuestHousesWidget`) shows occupancy via public-read Firestore queries.
- Voting (`VotingService.castVote`) stores SHA-256 ballot hash (student+election+position+salt), not studentId — cast in a transaction.
- Exam registration (`ExamBookingService.register`) is atomic via `runTransaction` with seat-capacity check.
- Feature flags (`FeatureFlagService`) seed 12 defaults on first load; `FeatureGate` widget gates UI at build time.
- Admin tool (`admin-tool/`) — 8 tabs: Grade Entry, Timetable Editor, Timetable Upload, Report Cards, Exam Timetable, Payments, Feature Flags, Analytics. Activate venv with `source admin-tool/venv/bin/activate`.
- APK auto-update downloads via `OpenFile` → system installer; a `downloadUrl` pointing at HTML (release page) causes "unable to parse the package".
