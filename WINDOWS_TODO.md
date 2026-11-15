# Windows app — verified build / install / verify

**Status: complete (2026-11-16).** Built with Flutter **3.47.5** + VS 2022
(**Desktop development with C++**) on Windows 10 22H2. CI also builds with
Flutter **3.41.9** on a `windows-2022` runner.

## Build
- [x] Visual Studio 2022 with the **"Desktop development with C++"** workload
- [x] `flutter doctor` — Windows section green
- [x] `flutter pub get` + `flutter build windows --release`
- [x] Output exists: `build\windows\x64\runner\Release\kabete2026eiteet.exe`
- [x] AVX2 link fix: `windows/runner/avx2_wmem_stub.cpp` (`_Avx2WmemEnabled`)
- [x] Installer compiled: `installer\Output\KNP-Management-System-Setup-2.11.8.exe`
- [x] Installer attached to the `v2.11.8+13` GitHub release

## Install
- [x] Installer runs (per-user test: `/CURRENTUSER /DIR=C:\dev\knp-test`)
- [x] Start Menu + uninstaller installed; build-only `.lib/.exp` excluded
- [x] App launches from the installed folder
- [x] Uninstaller removes the install directory cleanly
- [ ] *(If SmartScreen warns on another PC)* More info → Run anyway

## Verify
- [x] App reaches the login/home flow after relaunch
- [x] **Explore → Notes Library** loads (44 materials, subject filter chips)
- [x] Tap a PDF → **in-app PDF reader** renders the document
- [x] Timetable loads; exam timetable entries are present
- [x] Grades / **GPA tracker** opens
- [x] As an Official: **Access Control** and **Block / Restrict Users** screens open
- [x] Expected desktop limitation: push notifications, FCM, Crashlytics and
      Google Maps are mobile-only and disabled on Windows
- [x] Firestore session rules tested for a Windows session (platform metadata +
      `lastActiveAt` heartbeat; see `test/rules/rules.test.js`)

## Known first-launch behaviour
- A **fresh install** can sit on the splash screen while Firebase initialises
  with no local cache. Relaunching once opens the app normally; later launches
  use the cache and are immediate. Documented in `WINDOWS_BUILD.md`.

## If the build fails
- `font_awesome_flutter` / `IconData` final-class error → use the pinned
  **11.0.0** and `FaIcon` (already applied)
- `flutter_local_notifications_windows` MSVC coroutine error → use **VS 2022**
  (not VS 2025), or run the GitHub Action (`windows-2022` runner)
- Undefined `_Avx2WmemEnabled` → ensure `avx2_wmem_stub.cpp` is in
  `windows/runner/CMakeLists.txt`
