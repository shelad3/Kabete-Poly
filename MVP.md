# Kabete Poly Digital Ecosystem — Production MVP

> **Document:** Heavy, build-ready MVP derived from the full audit (`AUDIT.md`)
> **Date:** 2026-08-29 · **App:** class-archive-app v2.10.1+2 · **Backend:** Firestore `kabete-94936`
> **Goal:** Ship a stable, secure, *actually-working* horizontal slice — not a demo. Fix the broken/fake/insecure core first, then land the highest-value features.

---

## 1. Why this MVP exists (from the audit)

The audit (`class-archive-app/AUDIT.md`) found the ecosystem is feature-rich but has a broken core:

| # | Problem | Severity |
|---|---------|:--------:|
| A5 | `feature_flag.dart` casts Firestore `Timestamp` → `as DateTime?` → **runtime crash** on real docs | Crash |
| A2/B3 | Push notifications never send (`body` vs `message` field mismatch) | Broken feature |
| A3 | Cube / exam / voting "atomic" transactions read via plain queries → **double-booking, over-seat, double-vote** under concurrency | Data integrity |
| A1 | Payments are a **UI-only mock** — no M-Pesa/Daraja anywhere | Fake (money) |
| B1 | Voting dead for students (rules deny ballot read + candidate update) | Broken feature |
| B2 | **7 missing composite indexes** → FAILED_PRECONDITION (waitlist, attendance, exams, QR, default schedule, lesson verification, exam timetable) | Prod crash |
| B-S1..5 | Students can self-promote to Official; read all signup codes; impersonate messages; `field_indices` anonymously writable | Security |
| Portal | student_portal doesn't compile; QR contract (`uid` vs `uid\|timestamp`) breaks attendance | Broken |
| Demo apps | kabete_poly & student_dashboard are static/mock duplicates of the flagship | Waste |

**MVP principle:** *do the few things that make the product real and trustworthy before adding anything new.* A system where booking/voting aren't atomic and payments are fake is not shipworthy no matter how many screens it has.

---

## 2. MVP scope — what we build

### Phase A — CORRECTNESS & INTEGRITY (the "make it real" core) *(all completed)*
1. ✅ Fix `feature_flag.dart` Timestamp handling (`.toDate()`).
2. ✅ Fix push notifications end-to-end (field alignment + token refresh + harden function).
3. ✅ Make **cube booking**, **exam booking**, and **waitlist position** genuinely atomic via `transaction.get` (firestore transactions only read doc refs, so we restructure: read the cube/house doc and the student's own booking docs, enforce one-active-booking + capacity inside the transaction by reading the *cube* doc's occupancy counter).
4. ✅ Make **voting** atomic and secure:
   - Move salt/ballot-hash generation to a **Cloud Function** so anonymity is real (salt never ships in the APK).
   - Enforce one-ballot-per-student server-side (function checks `ballots/{studentId}:{positionId}:{electionId}` uniqueness + voting window via `request.time` params).
5. ✅ Backend **security-hardened rules** (B-S1..S5) + rules for the new server-side invariants.

### Phase B — DEPLOYABILITY (make it run in prod) *(rules/indexes deployed; functions pending billing)*
6. ✅ Add the **7+ missing composite indexes** to `firestore.indexes.json` — 31 total, deployed.
7. ✅ Deploy `firestore.rules` and `firestore.indexes.json` — LIVE. Functions deployment blocked on project billing (see `docs/deploy-runbook.md`); `confirmPayment` + voting callables tested 16/16 locally against emulator. Document the deploy runbook.
8. ✅ Wire Cloud Functions to replace **fake payment flow**: add a `confirmPayment` (secured by service-account/admin claim) that atomically flips `payments/{id}` → `completed` and marks the associated `cube_booking` as `paid`. Admin-tool "Mark Completed" now calls the real function (validating amount/ref) instead of blindly writing a status.

### Phase C — BROKEN-HIGH-VALUE FIXES  *(all completed)*
9. ✅ Fix **student_portal** so it compiles (remove shadowing `FirebaseOptions`, correct Web appId) and correct its QR to **`uid|timestamp`** so the teacher→student attendance flow works.
10. ✅ Admin tool: fix **inverted duplicate check** in `timetable_upload_tab`, fix **analytics % math**, wire **QR generator** tab, and stop `duplicate_exists` from swallowing errors.
11. ✅ App UX: fix the **lesson reminder** (schedules at class start instead of 20-min-before) + request `SCHEDULE_EXACT_ALARM`; remove dead `KnpTheme`/`data_seeder`/`date_utils`.

### Phase D — CONSOLIDATION (stop the waste)
12. **Archive `kabete_poly` and `student_dashboard`** (static/mock duplicates) with a README pointer to the flagship.
13. Extract shared `kabete_shared` package (regno validator, update client, models, theme) — single source of truth.

---

## 3. Explicit NON-GOALS (this MVP deliberately does NOT do)

- **No real M-Pesa STK push initiation from the app yet** — MVP wiring is the server-side *confirmation* contract (Phase B.7) so the data model is correct and secure. The actual Safaricom Daraja integration is the next sprint after the confirmation contract is proven.
- No new screens/marketing features. No dark-mode sweep (cosmetic, low value, high noise).
- No refactor of the 130-file flagship into a package yet (Phase D.13 is the *only* refactor and is limited to extraction).

---

## 4. Architecture of the secured core

Discipline: **client transactions must not be the only guard.** Where money/seats/votes are at stake, enforcement happens in **Cloud Functions** (server-authoritative) because Firestore security rules alone cannot do multi-doc atomic checks.

```
Student app ──► Firestore ──► Cloud Functions (authoritative)
   │                              ├─ vote(electionId, positionId, candidateId)
   │                              │      → checks: window open (request.time),
   │                              │      → one-vote-per-student (ballots/uid:pos unique),
   │                              │      → writes anonymized ballot (server salt) + increment
   │                              └─ confirmPayment(paymentId, ref, amount)
   │                                     → validates admin claim,
   │                                     → atomically set payment=completed + booking=paid

Admin tool ──► Cloud Functions (same authoritative path, no rules bypass)
```

Booking (cube + exam) stays client-transactional but is fixed to use **real `transaction.get` doc reads** (Phase A.3), which Firestore does guarantee atomically.

---

## 5. Definition of Done (how we know the MVP works)

1. ✅ **`flutter analyze` clean** on class-archive-app (no fatal infos).
2. ✅ **`flutter test` green** (23 pass) incl. unit tests for `feature_flag` Timestamp parsing and `parseLessonStartTime`.
3. ✅ **Firestore rules emulator test** covering: student cannot self-promote, cannot read auth_codes, cannot impersonate a message, `field_indices` write is locked, admin-only payment confirm. *(11/11 pass, `test/rules/rules.test.js`)*
4. ✅ **Composite indexes deployed** (31 total, deployed to prod).
5. ⏳ **Voting e2e:** student casts ballot → function returns → `voting_dashboard` shows tally; double-cast returns a clear "already voted" error; ballot doc contains a hash with no relationship recoverable from the client. **Logic validated locally via emulator tests (16/16)**; production e2e blocked on billing.
6. ⏳ **Payment confirmation e2e:** admin-tool "Mark Completed" calls `confirmPayment` → payment doc `completed` + cube booking `paid` within ~2s; mismatched amount/ref rejected. **Logic validated locally via emulator tests**; production e2e blocked on billing.
7. ⏳ **Push e2e:** an announcement created in-app produces an FCM message to a subscribed device within ~5s. **Trigger logic validated locally via emulator tests**; production e2e blocked on billing.
8. ✅ **student_portal builds** for web (`✓ Built build/web`).

---

## 6. Milestone plan

| Milestone | Deliverables | Est. effort |
|-----------|--------------|:-----------:|
| M1 — Core integrity | A1..A4 (feature_flag, push field, booking atomicity, voting function+rules) | 3–4 days |
| M2 — Deployability | B6..B8 (indexes, rules deploy, functions deploy, payment confirm contract) | 2–3 days |
| M3 — Broken-high-value | C9..C11 (portal compile+QR, admin tool bugs, reminder/exact-alarm) | 2–3 days |
| M4 — Consolidation | D12..D13 (archive demos, extract shared package) | 1–2 days |
| M5 — Proof | tests + rules-emulator + deploy + e2e validation (DoD) | 2 days |

**Total ≈ 2–3 weeks** for a trustworthy, deployable MVP. Next sprint after M5: real Daraja STK-push automation + admin broadcast/read-receipts.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Cloud Functions billing/12-month expiry (Spark) | Functions are low-volume; keep cold-start light; document free-tier limits |
| Moving enforcement server-side changes UX latency | Token + optimistic UI; function returns result synchronously via callable |
| Rules tightening locks out legit users | Full role-matrix test in emulator before deploy; keep owner-scoped reads for own data |
| Admin tool thread-safety | Phase C surfaces only targeted bugs; full thread fix tracked post-MVP |

---

## 8. Acceptance criteria for the deployment runbook
- `firebase deploy --only firestore:rules,firestore:indexes,functions` succeeds cleanly.
  **Status: rules + indexes deployed (2026-09-01). Functions blocked on project
  billing (Blaze) — see `docs/deploy-runbook.md`.** All functions (`sendNotification`,
  `sendClassNotification`, `hasVoted`, `castVote`, `confirmPayment`) are written,
  `node --check` clean, ready to deploy the moment billing is enabled.
- `gcloud`/`firebase` CLI validated config locally before touching prod. ✓ (dry-run + rules emulator 11/11)
- Every changed rule has a one-line rationale in `docs/rules-matrix.md`. ✓ (created)
- Rollback path: `git revert` rules/index/functions + `firebase deploy` (documented). ✓ (`docs/deploy-runbook.md` §3)

*This MVP is the engineering spine that makes every existing and future feature trustworthy. Everything else can grow on top of it safely.*
