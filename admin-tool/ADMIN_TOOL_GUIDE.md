KNP Management System — Windows Admin Tool
============================================
Author: Sheldon Ramu — Kabete National Polytechnique
Language: Python 3.12+  |  GUI Framework: PyQt6  |  Database: Firebase
Source code: https://github.com/shelad3/KNP-Management-System
License: MIT

---

TABLE OF CONTENTS
  1. What Is This Tool?
  2. How To Run It (Without Compiling)
  3. How To Compile It Into a .exe
  4. Security & Malware Verification
  5. Firewall & Antivirus Notes
  6. FAQ

---

1. WHAT IS THIS TOOL?
---------------------
The Windows Admin Tool is a desktop application for managing timetable
and grade data in the KNP Management System (the Flutter mobile app).

It can:

  - Log in with any Firebase Auth account that has Teacher or Official role
  - Browse / add / delete timetable entries for any class
  - Enter and save student grades (CAT1, CAT2, Exam) per class, subject, and term
  - Migrate bulk timetable data from a JSON file into Firestore
  - Add or remove classes from the system

It does NOT:

  - Access any files on your computer outside its own config folder
  - Send data anywhere except to the Firebase project it is configured for
  - Collect personal information, browsing history, or system data
  - Connect to the internet except to Firebase and Google's authentication servers

---

2. HOW TO RUN IT (WITHOUT COMPILING)
-------------------------------------
If you have Python installed, you can run the source directly.
This is the safest way — you see exactly what the code does.

Requirements:
  - Windows 10 or 11
  - Python 3.12 or newer (from python.org)
  - A Firebase service account JSON file (see Section 4)
  - Your Firebase Web API Key

Steps:

  a) Install Python from https://www.python.org/downloads/
     During installation, check "Add Python to PATH".

  b) Download the source code:
     https://github.com/shelad3/KNP-Management-System/archive/refs/heads/master.zip

  c) Extract the ZIP and open a Command Prompt (cmd) in the
     admin-tool folder:
         cd path\to\KNP-Management-System-main\admin-tool

  d) Create and activate a virtual environment (recommended):
         python -m venv venv
         venv\Scripts\activate

  e) Install dependencies:
         pip install -r requirements.txt

  f) Run the tool:
         python main.py

  g) On first launch, you will be prompted to:
        - Browse and select your Firebase service account JSON file
        - Enter your Firebase Web API Key
     These are stored locally in:
         %APPDATA%\KabeteAdminTool\settings.json
     They never leave your machine.

---

3. HOW TO COMPILE IT INTO A .exe
---------------------------------
Compiling produces a single .exe file that runs on any Windows PC
WITHOUT requiring Python to be installed.

Steps:

  a) Follow steps (a) through (e) from Section 2 above.

  b) Run the build script:
         build_exe.bat

     This will:
        - Install PyInstaller (if not already installed)
        - Package the app into a single .exe located at:
            dist\KabeteAdminTool.exe

  c) The .exe is portable. Copy it to any Windows 10/11 PC and
     double-click to run.

  d) On first launch, the user will be prompted for the Firebase
     service account JSON file and Web API Key (same as running
     from source).

What the build command does (technical detail):

    pyinstaller --onefile --windowed --name "KabeteAdminTool" ^
        --paths src ^
        --collect-all firebase_admin ^
        --collect-all PyQt6 ^
        --hidden-import PyQt6.sip ^
        main.py

    --onefile        : Bundle everything into a single .exe
    --windowed       : No console window (runs as a GUI app)
    --paths src      : Include the src/ module directory
    --collect-all    : Force inclusion of all Firebase and PyQt6 submodules
    --hidden-import  : Explicitly include modules PyInstaller might miss

Total file size: approximately 80–100 MB (includes Python + all libraries).

---

4. SECURITY & MALWARE VERIFICATION
-----------------------------------
This section addresses the question:
"How do I know this tool is safe to run on my computer?"

  a) Read the source code.
     Every line of code is visible at:
         https://github.com/shelad3/KNP-Management-System

     The admin tool lives in the admin-tool/ folder. You or your
     institution's IT staff can inspect every import, every
     network request, and every file access before running it.

  b) No hidden network connections.
     The tool only connects to:
        - identitytoolkit.googleapis.com  (Firebase Auth — login)
        - firestore.googleapis.com        (Firebase database — read/write data)
        - oauth2.googleapis.com           (Firebase token refresh)
     That is it. No tracking, no analytics, no telemetry.
     This can be verified with Wireshark or any network monitor.

  c) No filesystem access outside its config folder.
     Configuration is stored in:
         %APPDATA%\KabeteAdminTool\settings.json
     The tool does not read, write, or modify any other files
     on your system.

  d) No admin/elevated privileges required.
     The .exe runs as a standard user. It does not request
     administrator access. If Windows Defender flags it, this
     is because PyInstaller-packaged apps sometimes trigger
     false positives (see Section 5).

  e) You can build it yourself.
     The safest approach: do not download a pre-compiled .exe
     from anywhere. Follow Section 3 and compile it yourself
     from the published source code. This guarantees the
     .exe matches the source exactly — no hidden payload.

  f) Dependency integrity.
     All libraries (PyQt6, firebase-admin, requests, etc.) are
     downloaded from PyPI (the official Python package index)
     during pip install. PyPI packages are vetted and signed.
     You can verify checksums against the PyPI record.

---

5. FIREWALL & ANTIVIRUS NOTES
------------------------------
PyInstaller-packaged Python applications are known to trigger
false positives in some antivirus software. Here is why:

  - PyInstaller embeds the Python interpreter inside the .exe
  - The .exe contains compressed bytecode + all library code
  - Antivirus heuristics sometimes flag "compressed executable
    containing interpreted code" as suspicious

If your antivirus flags KabeteAdminTool.exe:

  a) Check the alert details. If it says "PyInstaller" or
     "Python bundled executable", it is a false positive.

  b) Submit the file for analysis on VirusTotal to confirm
     no legitimate detections exist.

  c) To eliminate all doubt: delete the .exe and run from
     source instead (Section 2). Source code does not need
     antivirus bypasses.

  d) If your institution requires whitelisting, add the
     compiled .exe to the antivirus exclusion list.

Firewall: The tool needs outbound HTTPS access (port 443) to:
  - *.googleapis.com
  - *.firebaseio.com
  - identitytoolkit.googleapis.com
If your network uses a proxy, the tool uses the system proxy
settings automatically (via the requests library).

---

6. FAQ
------

Q: Can I use this without internet?
A: No. The tool requires internet to authenticate and
   communicate with Firestore. There is no offline mode.

Q: Can multiple people use the same .exe?
A: Yes. Copy the .exe to any PC. Each user enters their own
   Firebase credentials on first launch.

Q: Does the tool store passwords?
A: Never. Firebase Auth handles all credential verification.
   The tool only stores the ID token (short-lived session),
   not the password.

Q: Can a student use this tool?
A: No. The tool checks the user's role in Firestore.
   Only Teacher, Official, and Admin roles are allowed.
   Students are rejected at login.

Q: What happens if the service account JSON is stolen?
A: The service account grants full read/write access to
   Firestore. Treat it like a database password. Store it
   securely and do not share it. Revoke and regenerate it
   from the Firebase Console if compromised.

Q: Is the source code available after compilation?
A: The .exe contains the compiled Python bytecode, which is
   readable but not easily editable. The canonical source is
   the GitHub repository. Always refer to the GitHub source
   for auditing.

Q: Can I deploy this to other staff members without giving
   them the service account?
A: Each user must provide their own service account and Web
   API Key on first launch. Alternatively, pre-configure the
   settings.json file in %APPDATA%\KabeteAdminTool\ and
   distribute the .exe with the config pre-filled.

---

Contact
-------
Author: Sheldon Ramu
GitHub: https://github.com/shelad3/KNP-Management-System
