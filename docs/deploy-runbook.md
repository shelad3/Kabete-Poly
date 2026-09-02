# Deploy Runbook — Kabete Poly MVP (M5)

Project: `kabete-94936` · Region: default (nam5) · Repo root: `class-archive-app/`

> Status (2026-09-01): **Firestore rules + indexes are LIVE.** Cloud Functions are
> **BLOCKED** pending billing (see Blocker below).

## Prerequisites
- Node 20+ (`node --version`), JDK 21+ for the rules emulator
  (Firestore emulator v1.20.2 rejects Java < 21). No system JDK 21 was present, so
  tests run with a portable Temurin 21: `JAVA_HOME=/tmp/opencode/jdk-21.0.12.1+1`
  with `PATH` prepended.
- `firebase-tools` (15.5.1) authenticated: `firebase login:list` shows the account.
- `functions/node_modules` installed (`npm install` in `functions/`).
- `test/rules/node_modules` installed (`npm install` in `test/rules/`).

## 0. Validate before touching prod
```bash
# Syntax / lint gates
cd functions && node --check index.js
cd .. && flutter analyze            # 0 errors, 0 warnings
flutter test                        # 23 tests pass
# Rules emulator test (JDK 21 required)
cd test/rules && JAVA_HOME=<jdk21> PATH=<jdk21>/bin:$PATH npx firebase \
  emulators:exec --only firestore 'node --test rules.test.js'
# Expect: 11/11 pass

# Cloud Function emulator test (fires against Firestore emulator)
cd functions && JAVA_HOME=<jdk21> PATH=<jdk21>/bin:$PATH npx firebase \
  emulators:exec --only firestore 'VOTING_SALT=test-salt FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node --test test/*.test.js'
# Expect: 16/16 pass — functions.test.js covers castVote/hasVoted/confirmPayment
#         auth, window, double-cast, amount, atomic flip; push.test.js covers
#         sendNotification + sendClassNotification (messaging stubbed).
# `npm test` in functions/ runs the same suite via the package.json script.
```

## 1. Deploy Firestore rules + indexes
```bash
firebase deploy --only firestore:rules,firestore:indexes
# ✔ rules compiled + released; ✔ indexes deployed (31 total)
```

## 2. Deploy Cloud Functions
```bash
firebase deploy --only functions
```
- `functions/index.js` contains: `sendNotification`, `sendClassNotification`
  (firestore onCreate trigger), `hasVoted`, `castVote`, `confirmPayment`.
- Runtime set in `firebase.json`: `functions.source=functions`, `functions.runtime=nodejs20`.
- `VOTING_SALT` is loaded via `firebase-functions/params` (`defineString`) from
  `functions/.env` — **not** the deprecated `functions.config()` (Runtime Config
  shuts down March 2026, after which any deploy using it fails). The Firebase CLI
  already had `voting.salt` set as legacy runtime config; that is now superseded
  by the `.env` param. Do not change the salt after ballots exist: ballot doc ids
  are `sha256(studentId:electionId:positionId:salt)` and changing it breaks
  double-vote detection.
- Known fixed bug: `confirmPayment` originally read the linked booking AFTER its
  write in the transaction (Firestore rejects read-after-write). Reads are now
  issued before writes; a missing booking doc is skipped (payment still completes).

## ⚠️ BLOCKER — Functions cannot deploy yet
```
Error: Billing account for project '919389680073' is not open.
       Billing must be enabled for activation of service(s)
       'artifactregistry.googleapis.com' + cloudfunctions + cloudbuild.
```
Cloud Functions requires a Blaze (pay-as-you-go) plan. **Action needed (owner):**
Firebase Console → Project `kabete-94936` → Build → Functions → enable billing /
upgrade plan. Until then:
- The voting calls `hasVoted`/`castVote` in the app will fail with
  `FirebaseFunctionsException` (`functions-not-found`). `VotingService.hasVoted`
  catches and returns `false`; `castVote` surfaces the error — safe fallback, no
  data loss.
- `confirmPayment` returns "function not found"; admin-tool must not rely on it
  until deployed.

The one remaining parameter-free deploy path, once billing is open:

```bash
firebase deploy --only functions        # reads VOTING_SALT from functions/.env
```

## 3. Rollback path
- Rules: re-point `firestore.rules` to previous revision via git + redeploy
  `--only firestore:rules`.
- Indexes: revert `firestore.indexes.json` + redeploy (indexes only add, never
  removed atomically — drop excess via Console when safe).
- Functions: `firebase functions:delete <fn>` or revert `index.js` + redeploy.

## 4. Post-deploy verification (DoD)
- Rules matrix rationale: `docs/rules-matrix.md`.
- Voting e2e, payment confirm e2e, push e2e — all require functions to be live,
  so re-run the four e2e checklist items from `MVP.md` §1 after the billing
  blocker clears.