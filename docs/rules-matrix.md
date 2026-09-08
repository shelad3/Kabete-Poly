# Firestore Rules Matrix — rationale per hardened rule

Project: `kabete-94936` · File: `firestore.rules` · Emulator-tested (16/16 pass)

Role ladder: `Student` < `Leader` < `Teacher` < `Official` (admin).
`isAdmin() == isAuthenticated() && role == 'Official'`.
`isTeacherOrAbove()` = Teacher | Official. `isLeaderOrAbove()` adds Leader.

## Hardened rules (MVP audit B-S1..S5)
| Path | Rule | Why |
|---|---|---|
| `users/{id}` create | `docId == auth.uid` + hasAll fullName/email/role/registrationNumber/mobileNumber | No forging another user's profile; self-registration only — keys match the app's `UserProfile.toJson()` schema |
| `users/{id}` update | owner + non-admin may only change safe self fields (`affectedKeys().hasOnly(...)` — fullName/mobileNumber/profilePhotoUrl/registrationNumber/enrolledClasses/classChangeCount/enrolledTerm/enrolledYear/fcmTokens/bio/gender/nationality/address/isHostelResident) | Blocks self-promotion to Teacher/Official/Admin (role not in safe list) |
| `users/{id}` read | owner or Leader+ | Blocks students bulk-harvesting the directory (PII) |
| `classes/{id}` read | `true` (public) | Cohort list is needed BEFORE login on the registration screen and by guests (drawer). Docs only hold createdAt + members uids; timetable subcollection stays auth-gated |
| `classes/{id}` create | Leader+, OR self-anchor (`createdBy==auth.uid` + sole member) | A self-registering student can open a cohort doc that only exists as a timetable subcollection; cannot seed arbitrary memberships |
| `classes/{id}` update | Leader+, OR own-uid append to `members` only | Enrolment into an existing cohort is a monotonic append of your own uid — cannot rewrite/remove membership |
| `messages/{id}` create | `senderId == auth.uid` | Blocks impersonating another sender |
| `messages/{id}` update/delete | owner-scoped | No editing/deleting others' messages |
| `auth_codes/{id}` read | `isAdmin()` | Registration codes are sensitive; students must not enumerate them |
| `auth_codes/{id}` create | `isAdmin()` | Only admins mint codes |
| `auth_codes/{id}` update | any auth user, only `isUsed/usedBy/useCount/usedAt` | Redemption requires shared write but can't alter the code itself |
| `field_indices/{id}` create | `uid == auth.uid` | Uniqueness index owned by its creator (registration txn runs AFTER auth user creation) |
| `field_indices/{id}` update | owner + only `registered` key | Only the registrant flips their own `registered`; can't change uid |
| `field_indices/{id}` delete | owner or admin | Author releases own leaked index (failed-registration cleanup + profile field changes); admin can purge |
| `field_indices/{id}` read | authenticated | Registration index used pre-auth-gated flows remains readable after signup |
| `payments/{id}` create | own studentId + `status=='pending'` | Users can initiate but never self-confirm |
| `payments/{id}` update | `isAdmin()` | Confirmation/refund is server/admin-only; students cannot finalize |
| `payments/{id}` delete | `false` | Financial records are never dropped |
| `elections/*/ballots` create | `false` | Client cannot forge ballots — created only by `castVote` Cloud Function (admin SDK bypasses rules) |
| `elections/*/ballots` read | authenticated | Turnout/tally display needs ballot count, no PII stored |
| `lesson_verifications` create | own-uid vote, ≤1 per array | A student can only register their own taught/not-taught vote |
| `alerts/{id}` update | admin, or readBy-append with uid inclusion | Mark-read only; can't rewrite alert content |
| `app_updates/{id}` read | `true` | Update check runs before login |
| `app_updates/{id}` delete | `false` | Keep last-known-good update availability |

## Server-side invariants (not expressible in rules)
- One-vote-per-position + window check + anonymous ballot → `castVote` Cloud Function
  (deterministic sha256 ballot id, salt server-only).
- Payment confirm amount/ref match + atomic `payments`→`cube_bookings` → `confirmPayment`.
- Cube double-booking + one-active-booking + seat capacity → `runTransaction` in
  `CubeService.createBooking` (client, rule comment documents why).
- Seats on `exam_bookings` → `ExamBookingService.register` transaction.

## Test coverage (test/rules/rules.test.js, 16 cases)
1. Student self-promote denied; safe-field (`fullName`/`bio`) update allowed
2. Student auth_codes read denied
3. Admin auth_codes read allowed
4. Message impersonation denied; own-sender allowed
5. field_indices owner-locked (create + update)
6. Student payment confirm denied; pending create allowed
7. Admin payment confirm allowed
8. Cross-student grade read denied
9. Own grade read allowed
10. Student lessons write denied
11. Unauthenticated users read denied
12. Student profile create with app schema (own uid) allowed; other-uid denied
13. Student enrols by appending own uid to class members; can't remove/rename
14. Student releases own field index; can't delete others'
15. Unauthenticated can read classes list; timetable stays auth-gated
16. Full app `register()` flow e2e: field-index reservation transaction + profile create + existing-class enrol + missing-class anchor + cleanup (own profile/index deletes) all succeed for a brand-new user

## Users collection authorisation summary
| Operation | Allowed to | Notes |
|---|---|---|
| read | owner, or Leader+ | Students can't bulk-read the directory |
| create | owner only | Create set is pre-login; keys pinned to app schema |
| update | owner only | Safe-field whitelist; self-promotion blocked |
| delete | owner or admin | Owner delete supports failed-registration cleanup before auth-account removal |

## Deploy state
- LIVE: rules + indexes (rules redeployed 2026-09-08 for registration fix).
- Pending: vote/confirm functions require billing (see `docs/deploy-runbook.md`).