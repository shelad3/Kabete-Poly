# Building the Windows app

This project is a Flutter app. The Windows platform files are already included
(`windows/`), so you only need the toolchain on the Windows machine.

## Known-good configuration

| Component | Version used |
|-----------|--------------|
| Windows | 10 22H2 (19045), 64-bit |
| Flutter | 3.47.5 stable |
| Visual Studio | 2022 Community 17.14 + **Desktop development with C++** |
| Inno Setup | 7.1.0 (`ISCC.exe`) |

CI pins Flutter **3.41.9** on a `windows-2022` runner; both versions build.

## One-time setup on Windows

1. **Flutter SDK** (stable) — https://docs.flutter.dev/get-started/install/windows
   - During install, tick "Add Flutter to PATH".
2. **Visual Studio 2022** (Community is fine) with the workload
   **"Desktop development with C++"** (includes the MSVC toolchain + Windows SDK).
3. Open a new **Command Prompt / PowerShell** and verify:
   ```
   flutter doctor
   ```
   The "Windows" section must show a green check.

## Build (one click)

From this folder, double-click **`build_windows.bat`** — or run:

```
flutter pub get
flutter build windows --release
```

Output:

```
build\windows\x64\runner\Release\
    kabete2026eiteet.exe
    flutter_windows.dll
    data\
    ...
```

Run `kabete2026eiteet.exe`. Keep the **entire Release folder** together — the
exe depends on the DLLs and `data\` beside it. To share it, zip that folder.

## Windows-specific build fixes (already in the repo)

- `font_awesome_flutter` is pinned to **11.0.0** and Google sign-in uses
  `FaIcon` (`lib/screens/login_screen.dart`) — the 10.x `IconData` subclass no
  longer compiles on current Flutter.
- `windows/runner/avx2_wmem_stub.cpp` defines `_Avx2WmemEnabled` and is listed
  first in `windows/runner/CMakeLists.txt`; without it the MSVC link step fails
  against the Firebase C++ SDK.
- `analysis_options.yaml` excludes `build/`, `android/`, `web/` and `windows/`
  so generated code is not analysed.

## Build the installer (Inno Setup 7)

```powershell
& "C:\Program Files\Inno Setup 7\ISCC.exe" installer\installer.iss
# Output: installer\Output\KNP-Management-System-Setup-2.11.8.exe
```

`installer\installer.iss` includes the custom wizard artwork, a "Before we
begin" prerequisites page, license page, Start Menu + optional desktop
shortcut, per-user (`/CURRENTUSER`) or all-users install, launch-on-finish and
a clean uninstaller. Rebuild the artwork with
`installer\make_assets.ps1` (uses the runner icon). Build output is gitignored.

Verified on Windows 10 22H2: silent install, launch, and silent uninstall all
exit `0` and leave no files behind.

## Notes / limitations

- Uses the same Firebase project (`kabete-94936`); Firestore, Auth, Storage and
  Cloud Functions work on Windows desktop.
- **Mobile-only features are hidden/disabled on Windows** (no Windows support):
  FCM push notifications, Crashlytics, local notifications, Google Maps.
- On a **fresh install the first launch can sit on the splash screen while
  Firebase initialises** (no local cache yet). If it does not move after ~30s,
  close and relaunch once; subsequent launches use the cache and open quickly.
- If you cannot build locally, push the repo to GitHub — the workflow
  `.github/workflows/windows-build.yml` builds the exe on a Windows runner and
  uploads it as an artifact on every push.
