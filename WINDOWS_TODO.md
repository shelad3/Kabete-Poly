# Windows app — Build / Install / Verify TODO

Project zip: `KNP-Windows-source.zip` (extract on the Windows machine).

## Build
- [ ] Install **Flutter 3.41.9** (stable) and add it to PATH
- [ ] Install **Visual Studio 2022** with the **"Desktop development with C++"** workload
- [ ] Run `flutter doctor` — the **Windows** section must be green
- [ ] Extract `KNP-Windows-source.zip` to a folder
- [ ] Run `build_windows.bat` (or `flutter pub get` then `flutter build windows --release`)
- [ ] Confirm the output exists:
      `build\windows\x64\runner\Release\kabete2026eiteet.exe`
- [ ] *(Alternative, no local toolchain)* push to GitHub → download the
      **KNP-Windows** artifact from the Actions run
- [ ] *(Repackage for sharing)* zip the whole `Release` folder

## Install
- [ ] Keep the **entire** `Release` folder together (exe + DLLs + `data\`)
- [ ] Run `kabete2026eiteet.exe`
- [ ] *(Optional)* Create a desktop shortcut to the exe
- [ ] *(If SmartScreen warns)* More info → Run anyway

## Verify
- [ ] App launches without crashing
- [ ] Log in with a valid account
- [ ] **Explore → Notes Library** loads (44 materials, subject filter chips)
- [ ] Tap a PDF → **in-app PDF reader** renders the document
- [ ] Timetable loads; exam timetable entries are present
- [ ] Grades / **GPA tracker** opens
- [ ] As an Official: **Access Control** and **Block / Restrict Users** screens open
- [ ] Confirm expected desktop limitation: push notifications, FCM,
      Crashlytics and Google Maps are **mobile-only** and disabled on Windows

## If the build fails
- [ ] `font_awesome_flutter` / `IconData` final-class error → use Flutter **3.41.9**
- [ ] `flutter_local_notifications_windows` MSVC coroutine error → use **VS 2022**
      (not VS 2025), or run the GitHub Action (`windows-2022` runner)
- [ ] Share the first error line and I'll adjust
