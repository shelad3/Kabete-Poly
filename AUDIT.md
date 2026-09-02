# Kabete Poly Digital Ecosystem — Full Code Audit

> Date: 2026-08-29 · App version audited: v2.10.1+2
> Scope: class-archive-app (Flutter + Admin tool + backend) · mark_scanner · student_portal · student_dashboard · kabete_poly

This is the raw audit of every feature/file across the ecosystem, categorised as
**WORKING / PARTIAL / PLACEHOLDER / LIKELY-TO-FAIL**, plus a recommended fix order.

---

# 1. CLASS ARCHIVE APP (Flutter, v2.10.1+2, 130 dart files)

## Headline truths (the most important findings)

### P-A1. PAYMENTS ARE FAKE — UI-only mock, M-Pesa/Daraja does not exist
- `payment_service.initiatePayment()` only writes one Firestore doc `payments/{id}` with `status:'pending'`. No HTTP, no Daraja/STK push anywhere in the entire repo (searched: `daraja|safaricom|lipa|stkpush|paybill|MPESA|checkoutRequestID` = 0 matches across lib/, functions/, admin-tool/).
- The comment in `payment_service.dart` claims "a Cloud Function completes the STK push" — **no such function exists.** `functions/index.js` has only a notification callable + trigger.
- The status screen spins "Processing…" forever; `markCompleted` is never called by app/admin tool. Payment is fictional. Admin can manually flip a cube booking to `paid`, so hostel flow works only via manual admin action.

### P-A2. PUSH NOTIFICATIONS ARE NOT WIRED END-TO-END
- Device token plumbing is real (FCM token saved to `users/{uid}.fcmTokens`).
- Sending is broken in 2 places:
  1. `functions/index.js` `sendClassNotification` reads `body`; the app writes `message`. → `body` undefined → function returns early, **nothing ever sent**.
  2. The HTTPS callable `sendNotification` is **never called** from the app (no `httpsCallable` import anywhere).
- No topic subscriptions; `onTokenRefresh` never re-saves the new token (stale tokens accumulate).

### P-A3. CORE BOOKING/VOTING TANSACTIONS ARE NOT ATOMIC (race conditions)
The three services that claim to be atomic (`cube_service`, `exam_booking_service`, `voting_service`) all wrap logic in `runTransaction` but do their **reads with plain `Query.get()`/`doc.get()`**, NOT `transaction.get()`. In the Dart SDK, queries inside a transaction callback do **not** participate in snapshot/conflict detection. Result:
- Two concurrent cube bookings can both pass the "available" check → **double-booking / over-capacity.**
- Two concurrent exam registrations can both pass the seat check → **over-subscribed seats.**
- Two rapid `castVote` calls both pass `hasVoted` → **two ballots / double count.**
- Waitlist `position` computed outside a transaction → duplicate positions.

### P-A4. VOTING SECRECY IS FALSE (and voting is broken by rules — see backend P-B1)
- The SHA-256 salt `'kabete_poly_voting_salt_2026'` is **hardcoded in the client** → anyone with the APK can brute-force `studentId → ballotHash`. Ballots are not anonymous.
- In addition the backend rules deny students read on `ballots` and deny update on candidate `voteCount`, so **students cannot vote at all** in production (backend section).

### P-A5. `feature_flag.dart` WILL CRASH ON REAL FIRESTORE DOCS
`fromJson` casts `createdAt`/`lastModifiedAt`/`schedule.autoDisableAt` with `as DateTime?` — but Firestore returns **Timestamp** objects. A direct `as DateTime?` on a non-null Timestamp throws `_TypeError`. Since `seedDefaultsIfEmpty` stores `serverTimestamp()`, the moment a seeded/edited flag is read (or the live listener fires) → crash. Other models (election, quiz) correctly use `.toDate()`. **This is the most likely silent crash in the models layer.**

---

## Services / providers — status table

| File | Status | Key finding |
|---|---|---|
| payment_service.dart | PLACEHOLDER / FAKE | P-A1 |
| push_notification_service.dart | PARTIAL | P-A2 token written, send dead, no re-save on refresh |
| notification_service.dart | PARTIAL/LIKELY-TO-FAIL | Manual lesson reminder bug: passes original `minute` not `reminderMinute` → fires at class start not 20-min-before; `SCHEDULE_EXACT_ALARM` permission never requested (silently fails on Android 12+); reminder-id hash collisions |
| cube_service.dart | PARTIAL/LIKELY-TO-FAIL | P-A3 non-atomic booking/waitlist; `_activeStatuses` includes `'completed'` (a completed booking blocks re-booking all term) |
| exam_booking_service.dart | PARTIAL/LIKELY-TO-FAIL | P-A3 non-atomic seat check; cancel can drive `registeredCount` negative |
| voting_service.dart | PARTIAL / NOT SECURE | P-A3 + P-A4 |
| update_service.dart | WORKING (caveats) | Firestore `app_updates/latest`; `isDirectApk` only checks `.apk` suffix (accepts http://, no checksum); no actual GitHub fallback in code (AGENTS.md claims one — stale) |
| firestore_service.dart | PARTIAL | offline persistence enabled ✅; `updateUserProfile` unique-index across 3 non-atomic ops (stale index risk); `getAdminStats` swallows errors → zeros; `getScheduleStream` unbounded fetch |
| class_provider.dart | PARTIAL | `refreshClasses` has empty `catch(_){}` silent failure; classes fetched once, no live listener |
| grade_service.dart | WORKING (+1 gap) | `getGradesForClass` with term+year filters needs a composite index **not in indexes.json** → FAILED_PRECONDITION risk |
| feature_flag_service.dart | LIKELY-TO-FAIL | P-A5 model cast bug |
| auth_provider.dart | PARTIAL | **Hardcoded admin backdoor**: email `sheldonramu8@gmail.com` auto-promoted to `Official` (client-side). Offline Official/Teacher silently downgraded to Student. Profile not live-listened (role/class edits don't update). Regno/phone/email `field_indices` can be orphaned `__pending__` forever if process dies mid-registration |
| auth_code_service.dart | PARTIAL/RACY | `markCodeUsed` not transactional (over-use); `single_use` expiresAt == now → usable only within one clock tick (broken) |
| quiz_service.dart | PARTIAL | `submitQuiz` blind add → double-submit double-counts |
| forum_service.dart | PARTIAL | messages unbounded (no pagination) |
| house/lesson_verification/connectivity/tutorial/screenshot/analytics/crash/unread_badge/qr_session/storage | mostly WORKING | storage_service: Cloudinary preset appears unsigned → any user can upload arbitrary files; screenshot_service empty catches (benign) |

## Models — field-name consistency
- **feature_flag.dart** — P-A5 (Timestamp cast crash). *Most dangerous.*
- **class_notification.dart** — writes `message`, push function reads `body` (P-A2).
- **cube_booking vs waitlist_entry** — default `term/year` diverge (current term vs 0).
- **grade_record.dart** — legacy `examMax` default 40 vs new 100 (mixed docs → inconsistent %).
- Others internally consistent.

## UI screens/widgets — status
- **No placeholders anywhere** (zero TODO/FIXME/`coming soon`/stub found). Every screen is implemented.
- All screens = WORKING except the notable risks below.
- **`lesson_detail_sheet.dart` (schedule/)** — the "Set Reminder" dialog only shows a SnackBar; it does NOT schedule anything (unlike `mandatory_timetable_tab` which really schedules). UX "looks done but nothing happens."
- **`voting/results_screen.dart`** — `isWinner = ci.key == 0` assumes results sorted by count; wrong if unsorted.
- **`school_id_card_screen.dart`** — loose `dynamic user` typing (fragile).
- **Dead code:** `utils/data_seeder.dart` (unused), `utils/date_utils.dart` (`parseFirestoreDate` unused + unsafe `DateTime.now()` fallback), `theme/knp_theme.dart` (dead duplicate).

## Theme claims — HALF TRUE
- **"KNP Green Theme" is misleading.** `knp_theme.dart` (green `0xFF276E15`) is **dead code**. The ACTIVE theme is `app_theme.dart` **navy/indigo** `0xFF1A237E`. Green only appears in isolated hardcoded spots. Bug in knp_theme if ever used: AppBar `foregroundColor: Colors.green` on green background = low contrast.
- **Material 3 dark mode** = real M3 theme ✅, but inconsistent — many screens hardcode light colors (`Colors.white`, `black87`, `grey[200]`), and `main.dart` wraps everything in a static navy gradient. Dark mode works but mixed/incorrect across many screens. `themeMode` hard-locked to `light` in knp/light branches.

---

# 2. ADMIN TOOL (Python / PyQt6, 21 files)

| File | Status | Key finding |
|---|---|---|
| main.py | WORKING (blocking) | 8 tabs ✓; **synchronous Firestore/HTTP on GUI thread** (freezes during login/refresh/import); hardcoded relative migrate path |
| migrate.py / migrate_timetable.py | WORKING | CLI JSON→Firestore; **duplicate implementation of the same thing** |
| config_manager.py | WORKING | SA path + Web API key in **plaintext** `~/.config/KabeteAdminTool` (gitignored) — no OS keychain |
| firebase_auth_client.py | WORKING | sync REST login; refresh token never used |
| firestore_client.py | WORKING (silent-swallow) | service-account admin access (bypasses rules); **`duplicate_exists` swallows ALL errors → reports "not a duplicate" on any failure**; Firestore singleton shared across GUI + worker threads (thread-unsafe) |
| models.py | PARTIAL | exam max default 100 vs 40 inconsistency; DEFAULT_FLAGS = 12 ✓ |
| grade_editor.py | WORKING | real CSV import + duplicate detection; GUI blocking |
| csv_parser.py / csv_import_dialog.py | WORKING | real parsers + dup preview |
| timetable_editor.py | PARTIAL | **`refresh_classes()` wipes the current table** (wrong behavior) |
| timetable_upload_tab.py | PARTIAL | real 6-step wizard; **BIG BUG: inverted duplicate check** — correctly-mapped classes get `continue` and are NEVER duplicate-checked; uploads unmapped classes; Firestore calls in background threads on shared singleton |
| pdf_parser.py | WORKING | real pdfplumber KNP-grid parsing (detailed) |
| report_card_generator.py | WORKING | real fpdf PDFs in proper QThread; `fpdf` optional-import → runtime crash if missing |
| payment_dashboard.py | LIKELY-TO-FAIL | **NO M-Pesa reconciliation** — manual "Mark Completed" (accepts any free-text ref) / "Mark Refunded"; nothing validates or contacts Safaricom |
| feature_flag_manager.py | WORKING | edit/toggle/seed 12 flags; dialog always writes auto-enable/disable schedule even when not intended |
| analytics_dashboard.py | PARTIAL | real Firestore data BUT **math bug**: raw summed scores (e.g. 88) treated as percentages → A/B/C/D/E distribution and % labels wrong (can exceed 100) |
| qr_generator.py | WORKING | real A4 8/page QR PDF; **not wired into main window tabs** (only via `python src/qr_generator.py`) |
| verification_dialog.py | PARTIAL | **dead code** — never imported/called |
| preview_table_widget.py / exam_timetable_tab.py | WORKING | |

**Lint:** ~133 pre-existing ruff errors, mostly F541 (f-strings without placeholders) + F401 (unused imports).

---

# 3. BACKEND (firestore.rules, index, functions)

## Security vulnerabilities (CRITICAL → MEDIUM)

### B-S1. Privilege escalation via `users` self-update
`users` update: `if isAuthenticated() && isOwner()`. A student can set **any field on their own doc including `role: 'Official'`** → becomes admin. Must restrict which fields non-admins may change.

### B-S2. `field_indices` is PUBLIC-WRITABLE (registration DoS + uniqueness bypass)
- `allow create: if true` (unauthenticated!) → anyone can pre-reserve phone/regNo/email keys → **blocks real registration**.
- `update: if isAuthenticated()` → any authenticated user can overwrite another user's index uid.
- `read: if true` → enumerate keys.

### B-S3. `auth_codes` readable by ALL authenticated users → signup-code theft
Any student can list all codes + their roles, then redeem an unused `Official`/`Teacher` code → self-register as admin. Read must be `isAdmin()` only.

### B-S4. `messages` create allows impersonation
`create: if isAuthenticated()` — no `senderId == auth.uid` enforcement → students can post as anyone.

### B-S5. `payments` update allowed for Teacher (not just Official)
Teachers can confirm/refund payments. Should be `isAdmin()`/service-account.

### B-M (other)
- `notifications` whole-collection read leaks other students' targeted notices.
- `elections/ballots` has `read: if false` → **breaks hasVoted** (see P-B1).
- One-shot rules (vote, booking, exam seat, waitlist) enforced **only in client** — no `request.time` guards anywhere.
- Storage rules: `profiles/*` and `lessons/*` uploads **not bound to auth.uid** (student can overwrite others' photos); any auth user can upload to `events/*`.
- `exams` has no delete rule (deleted via default deny).

## Production blockers — things BROKEN, not just insecure

### B-P1. VOTING IS NON-FUNCTIONAL FOR STUDENTS
`hasVoted()` reads `ballots` (denied) and `castVote` updates candidate `voteCount` (admin-only) → **students get PERMISSION_DENIED and cannot vote.**

### B-P2. MISSING COMPOSITE INDEXES → FAILED_PRECONDITION
Missing for: **waitlist (all queries)**, **attendance (grade report)**, **exams (available list)**, **active_qr_sessions (QR check-in)**, **schedules (isDefault)**, **lesson_verifications (isConfirmed)**, **exam_timetable (admin tool)**. These features crash in production.

### B-P3. NOTIFICATION TRIGGER NEVER FIRES
Function reads `body`; app writes `message` (P-A2).

### B-P4. Legit ops denied for lower roles
- Forum default-channel create requires `isLeaderOrAbove` → **Student opening forum = PERMISSION_DENIED**.
- Admin dashboard/tickets screens granted to Teacher but read rules require `isAdmin()` (Official) → Teachers get denied.

### AGENTS.md drift
- Claims `auth_code_usage` index + "legacy GitHub fallback" in app — neither exists.

---

# 4. COMPANION APPS

| App | Verdict | Details |
|---|---|---|
| **kabete_mark_scanner** | ⭐ WORKING (real, production-grade) | Real Firebase + ML Kit (`google_mlkit_text_recognition` — real inference), real offline queue (SharedPreferences FIFO + FNV-1a idempotency), real regno_validator, real roster verify + Firestore grades write. 4 meaningful tests. Only real app among the 4 companions. |
| **student_portal** | ❌ DOES NOT COMPILE | `main.dart` defines a **local `class FirebaseOptions`** that shadows firebase_core's type → compile type error. Also uses the **Android** appId on Web. QR screen encodes **uid only** via qrserver.com, but mark_scanner requires **`uid\|timestamp` ≤60s** → every attendance scan rejected. Real Firestore reads otherwise. No tests. |
| **student_dashboard** | ⚠️ PLACEHOLDER / MOCK | `firestore_service.dart` is **fully in-memory** (no cloud_firestore import). `auth_service` hardcodes STU001/STU002 with plaintext `password123`. Chat/notes/lessons/timetable all mock. Only `update_service` touches Firestore (`app_updates/student_dashboard` — different doc id than flagship's `app_updates/latest`). Real Crashlytics. Duplicates flagship features. 1 smoke test. |
| **kabete_poly** | ⚠️ PLACEHOLDER / STATIC DEMO | **No Firebase/HTTP at all.** All data hardcoded: results, fees, courses, timetable, payslip, messages, news. `virtual_assistant` = canned keyword replies (no AI). `auth_provider` mock w/ initAuth bug (parses prefs into empty `{}` map, never jsonDecodes; rememberMe writes `''`). Unused deps. Test is **stale/non-compiling** (mistaken class name) |

## Cross-app QR contract BREAK (critical integration bug)
`student_portal` → sends `uid`; `mark_scanner` → requires `uid|timestamp` within 60s. **The teacher→student QR attendance flow cannot work end-to-end today.**

## Cross-app update-doc conflict
`app_updates/latest` (flagship) vs `app_updates/student_dashboard` (student_dashboard). If both target the same APK audience they'd fight.

---

# 5. RECOMMENDED EXECUTION PLAN

Ordered by risk → reward. **Bold = security/production-blocking.**

## Phase 0 — CRITICAL fixes (do first, 1–2 days each unless noted)
1. **Backend security (B-S1..B-S5)** — `users` field-restricted update, `field_indices` locked down, `auth_codes` admin-read, `messages` sender==auth.uid, `payments` admin-only.
2. **Fix voting end-to-end (B-P1, P-A4)** — either enforce via Cloud Function (recommended: server-validated ballots, hide salt server-side) OR relax rules to let `hasVoted` work + one-shot via rules/function. This is both broken and insecure; do it properly server-side.
3. **Deploy missing indexes (B-P2)** — add waitlist/attendance/exams/active_qr_sessions/schedules/lesson_verifications/exam_timetable and `grade_service`'s term+year index, deploy, re-verify.
4. **Fix push notifications (P-A2/B-P3)** — make function read `message` (or app write `body`), then verify end-to-end; add token re-save on refresh; remove unsused callable.
5. **Fix `feature_flag.dart` Timestamp cast (P-A5)** — use `.toDate()`. Prevents silent crash.
6. **Make booking/exam/voting truly atomic (P-A3)** — replace in-txn plain queries with `transaction.get` (only doc refs work; restructure to read docs, not queries), or move to Cloud Functions. This is the core money/booking invariant.

## Phase 1 — correctness & reliability
7. `auth_code_service` single-use expiry + transactional use-count; `class_provider` error surfacing; `quiz_service` dedupe; waitlist position atomicity.
8. Admin tool: fix inverted duplicate check (timetable_upload_tab), fix analytics % math, fix timetable_editor refresh-wipe, wire QR generator tab, move blocking calls off GUI thread, `duplicate_exists` stop swallowing errors, remove dead verification_dialog.
9. App: fix manual reminder (notification_service), request `SCHEDULE_EXACT_ALARM`, dark-mode color sweep, remove dead KnpTheme + resolve green-vs-navy claim.
10. Decide and act on the **QR contract** (B) and **app_updates doc id** (B) between apps.

## Phase 2 — architecture consolidation (as in TODO P2)
11. **Delete/archive `kabete_poly` and `student_dashboard`** — both are static/demo duplicates of flagship. Keep `mark_scanner` (real) and fix `student_portal` or fold into flagship web (`student_portal` doesn't even compile).
12. Extract shared `kabete_shared` package (update client, regno validator, theme, models) — reduce copy-paste.
13. Refactor top-5 biggest flagship screens (line-count) into composable widgets with tests.

## Phase 3 — new features worth adding (beyond TODO list)
- **Real M-Pesa (Daraja STK push)** with a **Cloud Function callback** that atomically confirms payment → marks cube booking paid (replace the current manual mock). Cloud Functions are the missing backbone for payments + atomicity.
- **Server-side enforcement of booking/vote/waitlist invariants via Firestore Triggers** (or transactions in functions) — the cloud is the only safe place for these.
- **Admin audit log collection (append-only, service-account write)** for traceability (TODO P4-07).
- **Cloud Function-based voting (hide salt server-side, emit anonymized ballot hash).**
- **Index/rule emulator test suite** (TODO P3-03) to lock in all the above so regressions are caught in CI.
- **Student Portal: fix compile + add `uid|timestamp` QR** so the web surface actually works.

## Cross-cutting: docs
Update AGENTS.md (drift: missing-index claims, legacy-GitHub-fallback claim, version 2.9.0→2.10.1), the Presentation/Proposal stats, and this audit is the source of truth for the next release.

---

*End of audit. All findings above came from reading the actual source; file/line specifics are available in the exploration dumps if you want to open any by name.*
