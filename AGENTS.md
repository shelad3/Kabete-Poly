# Agent Context

## Current Version
- pubspec: `2.9.0+1`
- Release: https://github.com/shelad3/Kabete-Poly/releases/tag/v2.9.0%2B1
- APK: 66.7 MB at `build/app/outputs/flutter-apk/app-release.apk`

## Project Stats
- Dart files: 127 | Dart lines: ~32,700
- Admin tool: 22 Python files | ~6,100 lines
- Firestore collections: 41
- Cloud Functions: 5 (`sendNotification`, `sendClassNotification`, `hasVoted`, `castVote`, `confirmPayment`)
- Function emulator tests: 16/16, Rules emulator tests: 11/11

## Infrastructure
- Firebase project: `kabete-94936`
- Cloudinary cloud: `dpa8tbxdj`, upload preset: `Kabete_uploads`
- In-app update source: Firestore `app_updates/latest` (NOT GitHub API)
  - Document: `app_updates/latest` → `{version, downloadUrl, releaseNotes}`
  - `downloadUrl` must point to a DIRECT APK asset URL (e.g. GitHub release asset `.../releases/download/vX.Y.Z+1/app-release.apk`), NOT a release page
- Legacy versions still check: `https://api.github.com/repos/shelad3/Kabete-Poly/releases/latest`

## Key Firestore Rules (hardened 2026-09-01 — LIVE in prod)
- Full rationale + test matrix in `docs/rules-matrix.md`; 11-case emulator test in `test/rules/rules.test.js` (run with JDK 21, see `docs/deploy-runbook.md`).
- `users` create requires own `uid`; non-admin update limited to safe self fields (role promotion needs `Official`) — student self-promotion blocked.
- `messages` create requires `senderId == auth.uid` (impersonation blocked); update/delete owner-scoped.
- `auth_codes`, `feature_flags`: read/write admin/Official only.
- `field_indices`: create requires own `uid`, update owner + only `registered` key.
- `payments`: create own + `status=='pending'`; update admin-only (confirm/refund); delete: false.
- `elections/*/ballots`: client create `false` — ballots written only by `castVote` Cloud Function.
- `houses`, `cubes`, `school_info`, `events`, `app_updates`: public read (guests/updates).
- `cube_bookings`: create own + pending; update teacher+ or own cancel. Double-book/seat checks in transactions.
- Cloud Functions (`hasVoted`/`castVote`/`confirmPayment`/push) are written but **NOT deployed — project needs billing (Blaze) enabled**.

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
- M5 added 10 more (31 total, deployed 2026-09-01): `exams(classId,startDate DESC)`, `attendance(studentId,classId,date DESC)`, `active_qr_sessions(classId,isActive,activatedAt DESC)`, `waitlist(studentId,term,year,position)` + `waitlist(cubeId,term,year,status)`, `schedules(classId,isDefault)`, `lesson_verifications(isConfirmed,date DESC)`, `grades(classId,term,academicYear)`, `exam_timetable(date,startTime)`

## Remaining Known Bugs / UX Issues
- **Blocker:** Cloud Functions not deployable until project billing (Blaze) enabled on `kabete-94936` — blocks voting/payment-confirm/push e2e. See `docs/deploy-runbook.md`.

## Key Service Notes
- `VotingService.hasVoted`/`castVote` call Cloud Functions `hasVoted`/`castVote` (server-side anonymous ballots); `getTurnout` counts `elections/{id}/ballots` docs. `hasVoted` swallows `FirebaseFunctionsException`→false.
- `confirmPayment` Cloud Function (admin-only callable) = the payment confirmation contract: validates amount ±0.01, rejects finalized, atomically sets `payments/{id}=completed` + linked `cube_bookings/{bookingId}.paymentStatus=paid`.
- `VotingService.castVote` stores SHA-256 ballot hash (student+election+position+salt) server-side, not client-side.
- Admin tool now has 9 tabs (QR Generator wired 2026-09-01).
- `CubeService.createBooking` runs inside `FirebaseFirestore.instance.runTransaction()` — atomic double-booking + capacity check. Throws `BookingConflictException`. `_activeStatuses` includes `'completed'`.
- `UpdateService` reads `app_updates/latest` from Firestore, clears `update_available` flag after download completes (not after install confirmation).
- `StorageService` wraps Cloudinary for all new uploads. Legacy image URLs may still reference Firebase Storage.
- `GuestHousesWidget` shows occupancy via public-read Firestore queries.
- Exam registration (`ExamBookingService.register`) is atomic via `runTransaction` with seat-capacity check.
- Feature flags (`FeatureFlagService`) seed 12 defaults on first load; `FeatureGate` widget gates UI at build time.
- Admin tool (`admin-tool/`) — 9 tabs. Activate venv with `source admin-tool/venv/bin/activate`.
- APK auto-update downloads via `OpenFile` → system installer; a `downloadUrl` pointing at HTML (release page) causes "unable to parse the package".
