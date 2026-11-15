# Building the Windows app

This project is a Flutter app. The Windows platform files are already included
(`windows/`), so you only need the toolchain on the Windows machine.

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

## Notes / limitations

- Uses the same Firebase project (`kabete-94936`); Firestore, Auth, Storage and
  Cloud Functions work on Windows desktop.
- **Mobile-only features are hidden/disabled on Windows** (no Windows support):
  FCM push notifications, Crashlytics, local notifications, Google Maps.
- If you cannot build locally, push the repo to GitHub — the workflow
  `.github/workflows/windows-build.yml` builds the exe on a Windows runner and
  uploads it as an artifact on every push.
