# Firestore Rules Matrix — rationale per hardened rule

Project: `kabete-94936` · File: `firestore.rules` · Emulator-tested (11/11 pass)

Role ladder: `Student` < `Leader` < `Teacher` < `Official` (admin).
`isAdmin() == isAuthenticated() && role == 'Official'`.
`isTeacherOrAbove()` = Teacher | Official. `isLeaderOrAbove()` adds Leader.

## Hardened rules (MVP audit B-S1..S5)
| Path | Rule | Why |
|---|---|---|
| `users/{id}` create | `uid == auth.uid` + hasAll role/name/email | No forging another user's profile; self-registration only |
| `users/{id}` update | owner + non-admin may only change safe self fields (`affectedKeys().hasOnly(...)`) | Blocks student self-promotion to Teacher/Official/Admin (roles not in safe list) |
| `users/{id}` read | owner or Leader+ | Blocks students bulk-harvesting the directory (PII) |
| `messages/{id}` create | `senderId == auth.uid` | Blocks impersonating another sender |
| `messages/{id}` update/delete | owner-scoped | No editing/deleting others' messages |
| `auth_codes/{id}` read | `isAdmin()` | Registration codes are sensitive; students must not enumerate them |
| `auth_codes/{id}` create | `isAdmin()` | Only admins mint codes |
| `auth_codes/{id}` update | any auth user, only `isUsed/usedBy/useCount/usedAt` | Redemption requires shared write but can't alter the code itself |
| `field_indices/{id}` create | `uid == auth.uid` | Uniqueness index owned by its creator (registration txn) |
| `field_indices/{id}` update | owner + only `registered` key | Only the registrant flips their own `registered`; can't change uid |
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

## Test coverage (test/rules/rules.test.js, 11 cases)
1. Student self-promote denied; safe-field update allowed
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

## Deploy state
- LIVE: rules + indexes (deployed 2026-09-01).
- Pending: all rules are already enforcing; vote/confirm functions require billing
  (see `docs/deploy-runbook.md`).