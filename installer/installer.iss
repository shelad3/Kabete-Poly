#define AppName "KNP Management System"
#define AppVersion "2.11.8"
#define AppBuild "13"
#define AppPublisher "Kabete National Polytechnic"
#define AppExeName "kabete2026eiteet.exe"
#define RepoURL "https://github.com/shelad3/Kabete-Poly"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
AppId={{87E16E6D-AC02-484F-AAA9-AE95E694575B}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#RepoURL}
AppSupportURL={#RepoURL}/issues
AppUpdatesURL={#RepoURL}/releases
AppComments=Windows desktop edition of the Kabete National Polytechnic campus app.
VersionInfoVersion={#AppVersion}.{#AppBuild}
VersionInfoCompany=com.nativecodex
VersionInfoDescription=KNP Management System Windows Desktop Setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
VersionInfoCopyright=Copyright (C) 2026 com.nativecodex. All rights reserved.
DefaultDirName={autopf}\KNP Management System
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes
UninstallDisplayName={#AppName} {#AppVersion}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=Output
OutputBaseFilename=KNP-Management-System-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
LicenseFile=..\LICENSE
InfoBeforeFile=before.rtf
InfoAfterFile=after.rtf
WizardStyle=modern
WizardImageFile=assets\wizard-100.bmp,assets\wizard-150.bmp,assets\wizard-200.bmp
WizardSmallImageFile=assets\small-100.bmp,assets\small-150.bmp,assets\small-200.bmp
WizardImageStretch=yes
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog commandline
ShowLanguageDialog=no
CloseApplications=yes
RestartApplications=no
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.lib,*.exp,*.pdb,*.ilk"

[Icons]
Name: "{autoprograms}\{#AppName}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Comment: "Launch {#AppName}"
Name: "{autoprograms}\{#AppName}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon; Comment: "Launch {#AppName}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Messages]
SetupAppTitle=Setup - {#AppName}
SetupWindowTitle=Setup - {#AppName} {#AppVersion}
WelcomeLabel1=Welcome to the {#AppName} Setup Wizard
WelcomeLabel2=This wizard will install {#AppName} {#AppVersion} on your computer.%n%n{#AppName} brings your lesson notes, timetable, grades, hostel bookings and campus services together in one secure Windows desktop app.%n%nClick Next to continue.
SelectDirDesc=Where should {#AppName} be installed?
SelectDirLabel3=Setup will install {#AppName} into the following folder.
SelectDirBrowseLabel=To continue, click Next. If you would like to select a different folder, click Browse.
ReadyLabel1=Setup is ready to install {#AppName}.
ReadyLabel2a=Click Install to begin the installation, or click Back to review or change any settings.
FinishedHeadingLabel=Completing the {#AppName} Setup Wizard
FinishedLabel={#AppName} has been installed successfully.%n%nLaunch it from the Start Menu or the desktop shortcut, then sign in with your Kabete Polytechnic account.
ConfirmUninstall=Are you sure you want to completely remove %1 and all of its components?
UninstalledAll=%1 was successfully removed from your computer.

[CustomMessages]
CreateDesktopIcon=Create a &desktop shortcut
