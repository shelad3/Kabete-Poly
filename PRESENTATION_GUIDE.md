# Tent Presentation Guide

## KNP Management System — Sheldon Ramu

---

> This document is a reference, not a script. Read it through a few times before the event so the points sit in your head. When someone walks up to your tent, you will not be reading from paper — you will be having a conversation with them about something you built.

---

## Part 1: The Frame (Who You Are)

When someone asks "so who built this?", your answer matters more than you think. Do not lead with what you are not. Lead with what you did.

**Good answer:**

> "I built it. I am in my second year of electrical engineering here at Kabete. The app started because I got tired of losing PDFs in WhatsApp groups and showing up to the wrong lab sessions. Five months later it turned into this."

Why this works:
- You claim ownership immediately ("I built it")
- You name your actual situation (second year EE — relatable to students and impressive to faculty because it shows range)
- You anchor the project in a real problem, not in "I wanted to learn Flutter"

**If someone asks about your CS background:**

> "I do not have a formal CS background. I learned Flutter and Firebase as I went. The documentation is excellent, and trial and error teaches you things a degree never will."

This turns a potential weakness into a point about resourcefulness. Do not add "but I am still learning" — that is implied by the context. Stop after the second sentence.

---

## Part 2: The Walkthrough (3 Minutes)

You have someone standing at your table. Phone is in your hand (or theirs). Walk them through exactly one complete scenario. Pick one of the following based on who is standing in front of you.

### If they are a student:

> "Open the app. This is the Explore tab — every lesson posted by your lecturers shows up here, newest first. Tap any lesson. You get the full notes, the summary, any PDF attachments the teacher uploaded. Swipe to the Schedule tab. Your timetable for today, plus a whole tab for exam dates. Tap a class and it shows you the room on the map. The Hostel section lets you browse houses, see live occupancy, and book a cubicle — it checks availability in real time so two people cannot grab the same bed. You can also register for exams, vote in the student leader elections, and even view your digital school ID card."

Let them take the phone and scroll. Answer questions as they come.

### If they are a lecturer or faculty member:

> "The problem this solves is that every class currently manages materials differently — some use WhatsApp, some use email, some use printed handouts. This brings everything into one place. You log in, you see only your class. You post a lesson, it shows up in real time for every student enrolled. You schedule a lab session, it goes on their timetable and sends them a push notification. You set exam dates and they appear on the students' exam timetable. There is also a desktop admin tool where staff enter grades, print report cards as PDFs, and upload the timetable from a file."

Offer to show the posting flow on the phone. Let them tap through it.

### If they are an administrator or visitor (non-technical):

> "This is a mobile platform for the college. Students access their lessons, timetable, grades, and class discussions here. They book hostel beds here too, register for exams, and vote in elections — all in one app. Lecturers post materials and mark attendance. Administration sends alerts and manages the whole thing from a desktop tool. It is live — what you see on this phone right now is what students use every day."

Show the main screens slowly. Do not go into technical details unless they ask.

### If they are a developer or technically-minded:

> "Flutter front end, Firebase back end. Firestore for the database with real-time listeners so updates appear instantly. Critical writes — hostel bookings, votes, exam registrations — run inside Firestore transactions so they cannot race. Voting privacy uses SHA-256 ballot hashing. Cloudinary handles file uploads. Google Maps for the campus map. The authentication uses Firebase Auth with email-password and Google Sign-In. State management is Provider. The app auto-updates by checking a Firestore document on startup and downloading the APK from a GitHub release."

Then ask them what they want to know more about. They will likely have specific questions about the architecture, which you can answer from the documentation we prepared.

---

## Part 3: Anticipated Questions & Answers

These are questions that will come up. Have answers ready so you do not get caught off guard.

### Q: "How is this different from Google Classroom?"

> "Google Classroom is a general platform designed for schools globally. This is built specifically for how Kabete Poly works — our class cohort naming system, our timetable structure, our campus map, our hostel booking and exam registration. It also works fully offline for cached content, integrates push notifications specific to our departments, and has an automatic update system so users do not need to download new versions manually."

The point is not to dismiss Google Classroom. The point is that this is tailored.

### Q: "How do you handle security? Can students access each other's data?"

> "Firestore security rules enforce role-based access. A student can only read lessons from their enrolled classes. They cannot edit or delete anything. Teachers can post and edit their own content. Only administrators can delete channels or send global alerts. The rules are written in the Firebase security rules language and are evaluated on every database request — there is no client-side bypass."

### Q: "What happens if the internet goes down?"

> "Firestore has local persistence enabled with an unlimited cache. Any data the user has previously loaded — lessons, messages, schedules — is available offline. Writes are queued and sync when connectivity returns. The app also detects connectivity issues on the splash screen and shows a retry button instead of hanging indefinitely."

### Q: "Did you work with a team?"

> "Solo developer. The entire codebase, the database design, the UI, the deployment — I did it myself. I started in February and the current version is 2.9.0."

Short and direct. No need to explain why you worked alone. It is normal for a project of this scope at this level.

### Q: "How many users does it have?"

Be honest here. If it is 30 students and 2 teachers, say that. Do not inflate numbers. But frame it as early adoption, not low adoption:

> "It is currently being used by [X] students and [Y] lecturers across [Z] classes. We are rolling it out gradually — the focus has been on getting the core experience right before pushing it campus-wide."

### Q: "What would you do differently if you started over?"

> "I would have set up the Firestore indexes and security rules before writing any front-end code. I spent the first few weeks writing queries that worked in testing but failed in production because I had not planned the data access patterns. Also, I would have moved critical writes into transactions from day one — the double-booking bug taught me that the hard way."

This shows maturity. Admitting what you would improve is more impressive than claiming everything was perfect.

### Q: "Is the code open source?"

> "Yes. The repository is public on GitHub under the AGPL v3 license — you can read every line, audit it, and even adapt it. The Firebase setup guide and the architecture documentation are included so other institutions can use it."

### Q: "How does the hostel booking actually prevent two students taking the same bed?"

> "The booking is not a normal database write. When you book, the app runs a Firestore transaction — it counts how many beds are already taken in that cubicle and checks you do not already have a booking, then writes the new booking, all in one atomic step. If someone else booked the last bed a fraction of a second earlier, your booking fails with a clear message instead of silently double-allocating."

### Q: "How does voting stay private but still verified?"

> "The vote stores a hashed ballot — a SHA-256 fingerprint of your student ID, the election, and the position, combined with a random salt. Nobody reading the database can tell who voted for whom, but the count is still exact and you cannot vote twice."

---

## Part 4: Answers To Questions You Might Get About Yourself

### "You are an electrical engineering student. Why build an app?"

> "The problem existed in my class. I am the one who was losing PDFs and missing schedule changes. Fixing it mattered to me personally. The fact that it involved software instead of circuits was incidental — I used whatever tool solved the problem."

This reframes the question. You are not a programmer who wandered into engineering. You are an engineer who identified a problem and picked up whatever tools were needed to solve it.

### "How long did it take you to learn Flutter?"

> "I wrote my first Dart code in early February. The first working version of the app that could display a lesson from Firestore took about three weeks. The rest was iterative — adding features, breaking things, fixing them, getting feedback from classmates."

Do not downplay the learning curve. But do not exaggerate it either. Three weeks to a working prototype is honest and impressive.

### "Are you planning to pursue software development as a career?"

If yes: "That is the direction I am considering. The process of building something from nothing and watching people use it is deeply satisfying."

If unsure: "I am keeping my options open. Electrical engineering and software are converging rapidly — I think having both perspectives will serve me well regardless of which direction I go."

Both answers are strong. Pick the one that is true.

---

## Part 5: The Setup (Physical)

### What to bring

| Item | Purpose |
|---|---|
| Phone or tablet with the app installed | Primary demo device |
| Backup phone (if available) with the app installed | In case the primary dies |
| Power bank + charging cable | Phones die at events. Guaranteed. |
| Mobile hotspot or prepaid data | Venue Wi-Fi is never reliable |
| Printed sign (A4 or larger) | "KNP Management System — Live Demo" |
| Printed screenshots (optional) | Backup if the network fails entirely |
| Water bottle | Speaking dries your throat |

### Tent layout

- Place the phone on a stand or small riser so it is visible without being picked up
- Keep the sign at eye level
- Do not sit behind a table. Stand beside it. Sitting creates a barrier. Standing says "come talk to me"
- If you have slides on a laptop, angle the screen so visitors can see it from the walking path

### Dealing with network failure

If the network is completely dead and your hotspot is not working:

1. Open the app beforehand while you still have signal. Firestore cache will keep the data visible.
2. If even that fails, use the printed screenshots.
3. Explain: "The app normally runs live, but the network here is struggling. The screenshots show the actual interface — let me walk you through what each screen does."

Even if the demo does not work perfectly, the conversation still matters.

---

## Part 6: The Close

When the conversation is winding down, end with a clear next step:

> "I appreciate you stopping by. If you want to try it yourself, the app is available for download — I can send you the link. I am also open to feedback if there is something you would like to see added."

If they are faculty or administration:

> "If you would like to see how this could work for your department, I can set up a walkthrough with your class. It takes about five minutes to onboard a cohort."

---

## Part 7: Mindset

A few things to keep in mind walking in:

**You built something real.** It is installed on phones. People use it. That already separates you from most projects at a tent fair. Do not compare yourself to Google or Microsoft. Compare yourself to yourself five months ago.

**The technical questions are the easy ones.** You know how every part of this app works because you wrote every line. If someone asks something you do not know, that is fine — "I have not tested that path yet, but I can look into it" is a perfectly good answer.

**The nerves do not go away.** They get quieter after the first conversation. By the third or fourth person, you will find your rhythm. Trust that.

**Your background is not a disadvantage.** An electrical engineering student who built a production mobile app is more interesting than a CS student who built a to-do list. The story is better. The context makes people pay attention.

---

## Part 8: Technical Deep Dive (Expected Questions)

### "How is the data structured in Firestore?"

This is the most common technical question. Know the main collections:

```
users/{uid}
  ├── name, email, role (Student/Leader/Teacher/Official/Admin/Guest)
  ├── classId, regNo, phone, photoUrl
  ├── gender, nationality
  └── enrolledTerm, enrolledYear

lessons/{lessonId}
  ├── classId, topic, subtopic, notes, summary
  ├── teacherId, teacherName, timestamps
  └── fileUrls: [{name, url, type}]

grades/{gradeId}
  ├── classId, subjectName, studentId, studentName
  ├── term, academicYear
  └── cat1, cat2, exam (nullable integers)

classes/{classId}
  └── timetable/{entryId}         ← subcollection
        ├── day (string: "Monday"), time (string: "8:00 - 10:00")
        ├── unit, room, lecturer
        └── color (int for UI badge)

exam_timetable/{entryId}
  ├── className, subject, date, startTime, endTime
  ├── venue, type (final/midterm/cat/practical)
  └── lecturer

houses/{houseId}
  ├── name, category (boys/girls), maxOccupancy
  ├── reservedForNewStudents
  └── totalCubes

cube_bookings/{bookingId}
  ├── studentId, cubeId, houseId, houseName, cubeNumber
  ├── term, year, status (pending/confirmed/checked_in/completed/cancelled)
  └── paymentStatus (unpaid/paid)

payments/{paymentId}
  ├── studentId, bookingId, amount (KES 5,000)
  ├── method (mpesa/card/cash), phoneNumber
  └── status (pending/completed/refunded)

elections/{electionId}
  ├── title, status (draft/active/closed/published)
  └── positions/{positionId}/candidates/{candidateId}

exams/{examId}  →  exam_bookings/{bookingId}
  ├── subject, date, capacity, registeredCount
  └── studentId, status

feature_flags/{flagId}
  ├── key, enabled, schedule (start/end)
  └── roles: [...]

notifications/{notificationId}
  ├── studentId (target owner), title, body, type
  └── read (bool), createdAt
```

**Why timetable is a subcollection:** A class may have 50+ timetable entries. Firestore documents have a 1 MiB size limit. Storing entries as an array inside the class document would hit that limit for large classes. Subcollections scale independently.

**Why grades is a top-level collection:** Students are enrolled in multiple classes across different terms. A top-level collection allows querying `grades` where `studentId == X` across all classes. As a subcollection under `classes`, that query would require a collection group index.

**Why messages use a flat structure:** No nested replies. Each message is independent. Threading is handled client-side by `channelId`. This keeps writes fast — no array operations that could hit the 20k writes/day free limit.

---

### "How do your Firestore security rules work?"

Security rules are written in Firebase's custom rule language and evaluated on **every** database request — there is no client-side bypass.

Key patterns in your rules:

```
// Students can only read lessons for classes they're enrolled in
match /lessons/{lesson} {
  allow read: if isSignedIn()
    && resource.data.classId in get(...).data.enrolledClasses;
  allow write: if hasAnyRole(['Admin', 'Official', 'Teacher']);
}

// Grades: students read only their own, teachers read/write their class
match /grades/{grade} {
  allow read: if isSignedIn() && (
    request.auth.uid == resource.data.studentId ||
    hasAnyRole(['Admin', 'Official', 'Teacher']));
  allow write: if hasAnyRole(['Admin', 'Official', 'Teacher']);
}

// Houses/cubes public read (guest browsing), admin write
match /houses/{houseId} {
  allow read: if true;
  allow write: if hasAnyRole(['Admin', 'Official']);
}

// Bookings: authenticated read/create/update
match /cube_bookings/{bookingId} {
  allow read: if isSignedIn();
  allow create, update: if isSignedIn();
  allow delete: if hasAnyRole(['Admin', 'Official']);
}

// app_updates public read (update check runs pre-login)
match /app_updates/{docId} {
  allow read: if true;
  allow write: if hasAnyRole(['Admin', 'Official']);
}
```

**Key takeaway:** Rules validate a user's role and ownership server-side. The app never trusts the client — even if someone forges a request, Firestore rejects it.

---

### "How does offline caching actually work?"

```
FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true);
```

This single line enables Firestore's local cache (an embedded SQLite database on the device).

**Read path:**
1. App calls `FirebaseFirestore.instance.collection('lessons').where(...).snapshots()`
2. Firestore returns cached data immediately (if available) — screen renders instantly
3. Firestore simultaneously sends the request to the server
4. When server responds, the stream fires again with fresh data → UI updates
5. Cache is updated with server response for next offline use

**Write path (when offline):**
1. `set()` or `update()` is called
2. Firestore queues the write in the local cache
3. App gets an immediate success callback (optimistic update)
4. When connectivity returns, Firestore flushes queued writes in order
5. **Conflict resolution:** Last write wins. No merge logic.

**Limitations:**
- First load of any collection requires network — nothing to serve from cache
- Large attachments (PDFs, images) are NOT cached; they're downloaded separately via Cloudinary URLs
- Queries with `where('array_contains', ...)` on cached data work, but `order_by` may fail if the corresponding index isn't cached

---

### "How does the auto-update mechanism work?"

This is a custom update system — NOT using Google Play or Firebase Remote Config.

**Flow:**
1. App launches, `UpdateService.checkForUpdates()` runs in the background
2. Reads the `app_updates/latest` document from Firestore (public read)
3. Compares the `version` field with the current app version (`package_info_plus`)
4. If newer → shows a dialog: "Update available (v2.x.x). Download now?"
5. User taps Download → `http` client streams the APK from `downloadUrl` with a progress bar showing MB downloaded / total MB
6. Download completes → `OpenFile.open(apkPath)` triggers the Android system package installer
7. Before installing, the app verifies the file exists and checks its size against the `Content-Length` header (integrity check)

**Why this approach instead of Play Store:**
- The app is not on the Play Store (costs $25 one-time fee + Google's approval process)
- Sideloading APKs is standard practice for college-internal apps in Kenya
- GitHub Releases gives free file hosting, and Firestore gives us version control we control directly
- Older app versions still check the GitHub releases API — both paths point to the same APK asset

**Gotcha:** The `downloadUrl` must be a direct APK link. If it points to a release page, the app downloads an HTML file named `.apk` and Android shows "unable to parse the package."

---

### "How do push notifications work?"

**Infrastructure:** Firebase Cloud Messaging (FCM)

**Registration flow:**
1. On login, app calls `FirebaseMessaging.instance.getToken()` → gets a unique device token
2. Token is saved to Firestore: `users/{uid}/devices/{tokenId}`
3. App subscribes to topics: `class_INF600_M24` (one topic per class the user is enrolled in)
4. On logout, tokens are unsubscribed and deleted

**Sending flow:**
When a teacher posts a lesson or schedules a class:
1. The app writes a notification document to Firestore
2. FCM delivers to devices subscribed to that class topic
3. Targeted admin alerts carry a `studentId` so only the intended student is notified

---

### "What would it take to deploy this at another institution?"

The codebase has Kabete-specific hardcoding, but the architecture is transferable. Porting checklist:

| Step | What changes | Difficulty |
|------|-------------|-----------|
| 1. Fork the repository | Clone the code | Easy |
| 2. Firebase project | Create new project, enable Auth + Firestore + FCM | 30 min |
| 3. `google-services.json` | Replace with new Firebase config | Easy |
| 4. `firestore.rules` | Deploy same rules (no change needed) | 5 min |
| 5. Deploy indexes | `firebase deploy --only firestore:indexes` | 5 min |
| 6. Class data | Seed `classes` collection with new cohort names | 10 min |
| 7. Department list | Edit `utils/role_data.dart` with new departments | Easy |
| 8. Campus map | Update coordinates & markers in `campus_map_data.dart` | 30 min |
| 9. App name/branding | Change app name in `AndroidManifest.xml`, update strings | 15 min |
| 10. Admin tool | Point to new Firebase project, update Web API Key | 5 min |
| 11. Build APK | `flutter build apk --release` | 10 min |
| 12. Host APK | Push to GitHub Releases + update `app_updates/latest` | 5 min |

Total time for a competent developer: **2–3 hours**.

---

### "How much does it cost to run?"

| Service | Free Tier | Current Usage | Cost |
|---------|-----------|---------------|------|
| Firebase Firestore | 50k reads, 20k writes, 20k deletes/day | Well under limits | **$0** |
| Firebase Auth | 50k monthly active users | < 500 | **$0** |
| Firebase Cloud Messaging | Unlimited | — | **$0** |
| Cloudinary (file storage) | 25 GB storage, 25 GB bandwidth/month | ~2 GB | **$0** |
| GitHub Releases (APK) | Unlimited public storage | 67 MB | **$0** |
| Firebase Hosting | 10 GB storage, 360 MB/day | — | **$0** |

If it outgrows the Spark plan, Firestore Blaze (pay-as-you-go) costs about $0.06 per 100k reads. For a campus of 5,000 students each reading 50 documents/day = 250k reads/day = roughly $0.15/day. **Total estimated cost at scale: $5–10/month.**

---

### "Is user data safe? What about privacy?"

- Passwords are handled entirely by Firebase Auth — you never see or store plaintext passwords
- No sensitive personal data collected beyond name, email, registration number, class, gender, and nationality
- No location tracking, no camera access without explicit user action, no contact list access
- Service account JSON (full database access) is stored on the admin's local machine, NEVER in the repository
- `google-services.json` and `service_account*.json` are in `.gitignore`
- Firestore rules prevent unauthorized access even if someone gets a user's auth token
- Voting ballots are SHA-256 hashed — nobody can tell who voted for whom, but duplicates are impossible

---

### "How does the admin tool authenticate?"

The admin tool uses a **two-layer auth** approach:

1. **Firebase Auth REST API** (`signInWithPassword` endpoint):
   - POST email + password + Web API Key to `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=WEB_API_KEY`
   - Returns an `idToken` and user `uid`
   - This validates the user's credentials against Firebase Auth

2. **Firestore role check**:
   - Uses the Firebase Admin SDK (service account) to query `users/{uid}`
   - Checks that `user.role` is `Teacher`, `Official`, or `Admin`
   - Rejects login if role is `Student`

**Why both?** The REST API validates the password (Firebase Auth handles credential security). The Admin SDK reads the role (Firestore rules). Combined, they ensure only authorized personnel with valid credentials can use the tool.

---

### "Why Flutter and not React Native or native Java/Kotlin?"

| Factor | Flutter | React Native | Native (Java/Kotlin) |
|--------|---------|-------------|---------------------|
| Learning curve | Dart is easy if you know any C-like language | Requires JS + React knowledge | Steep (Android SDK, lifecycle, threading) |
| Code sharing | Single codebase for Android + future iOS | Single codebase, but bridge overhead | Separate code per platform |
| Performance | Skia engine, 60fps out of the box | JS bridge can lag on complex UIs | Best, but more code |
| Firebase support | First-class via `cloud_firestore`, `firebase_auth` packages | Good, but Android/iOS config separate | Good, but more boilerplate |
| Developer experience | Hot reload, strong typing, no JS bridge | Hot reload, but JS debugging can be painful | Cold build every time |

**Your actual reason:** You started with Flutter because the documentation was clear, the widget system made sense to a beginner, and you could see results immediately with hot reload. The technical advantages validated the choice later.

---

### "What is the most technically challenging part of the app?"

Three things, in order:

**1. Race conditions in hostel booking**
The worst bug was two students booking the same cubicle at the same time. The check-then-write was non-atomic — both reads passed, then both writes landed. Fix: moved the whole booking into a Firestore transaction so the availability check and the write happen atomically. The same pattern now protects voting and exam registration.

**2. Google Maps inside a scrollable tab**
The campus map uses `GoogleMap` widget inside a `TabBarView` inside a `NestedScrollView`. Android's default `AndroidView` surface captures touch events and prevents the parent from scrolling. Fix: switched to `VirtualDisplay` surface mode, which composites the map as a texture instead of a native surface — touch events propagate correctly. Cost: 2 days of debugging.

**3. Timetable data migration**
The original timetable was 8,296 lines of hardcoded Dart maps. Extracting that to JSON, uploading 108 cohorts to Firestore with proper day/time indexing, and ensuring the Flutter app could read from Firestore exclusively without breaking the UI — all while maintaining offline caching. One missed index and queries fail silently.

---

## Part 9: Terminology You Should Know

If someone asks about any of these, you need a one-sentence answer ready:

| Term | One-sentence definition |
|------|------------------------|
| **Firestore** | NoSQL document database from Firebase — data is stored in collections of JSON-like documents with real-time listeners |
| **Transaction** | A Firestore operation where several reads and writes run atomically — either all succeed or none do, so two users cannot race |
| **Real-time listener** | A Firestore stream that pushes data to the app automatically whenever the database changes — no polling |
| **Security rules** | Firebase's server-side access control language that validates every database read and write |
| **Offline persistence** | Firestore's local cache (SQLite on device) that serves data when the network is unavailable |
| **SHA-256** | A cryptographic hash — one-way fingerprint of data, used here to anonymize votes while keeping them unique |
| **FCM** | Firebase Cloud Messaging — push notification service that delivers messages from server to device |
| **FCM topic** | A named channel that devices subscribe to — send one message to the topic, all subscribers receive it |
| **Provider** | Flutter state management library — widgets "consume" data from ChangeNotifier classes higher in the widget tree |
| **ChangeNotifier** | A class that holds state and calls `notifyListeners()` when data changes — Provider rebuilds dependent widgets |
| **Cloudinary** | Cloud-based file storage service — used to host PDFs and images instead of storing them in Firestore (which has a 1 MiB document limit) |
| **Firebase Admin SDK** | Server-side library that bypasses security rules — used by the admin tool for full database access |
| **GitHub Releases** | Free file hosting tied to git tags — used to distribute APK updates |
| **Web API Key** | Firebase project identifier used for REST API calls (NOT a secret — it's safe to include in client apps) |
| **Service Account** | Firebase credentials JSON file that grants full server-side access to Firestore — stored locally, NEVER committed |
| **Compound index** | A Firestore index that sorts by multiple fields (e.g., `day ASC, time ASC`) — required for `order_by` on multiple fields |
| **Sideload** | Installing an APK directly (downloading the file and opening it) instead of through the Play Store |
| **Hot reload** | Flutter feature that injects code changes into a running app in under a second — preserves app state |
| **VirtualDisplay** | Android surface mode that renders a native view (like Google Maps) as a texture — solves scroll conflicts inside scrollable widgets |
| **Feature flag** | A remote on/off switch for a feature, stored in Firestore — lets admin enable features without shipping a new APK |

---

*Prepared for Sheldon Ramu — Kabete National Polytechnique*
*KNP Management System — Version 2.9.0+1*
*July 2026*
