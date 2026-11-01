; Inno Setup 6.4+ — Smart Student Attendance distribution script
; Build with: build_setup.bat  (or ISCC.exe installer\TimeTrackEnterprise.iss)

#define MyAppName "TimeTrackEnterprise"
#define MyAppVersion "1.1.20"
#define MyAppPublisher "د. بوزويرة عزيز (shamildev)"
#define MyAppExeName "TimeTrackEnterprise.exe"
#define MyAppCopyright "© 2026 د. بوزويرة عزيز — shamildev. جميع الحقوق محفوظة."
#ifndef SourceExe
  #define SourceExe "..\dist\TimeTrackEnterprise.exe"
#endif

[Setup]
AppId={{B6D3AC6E-7E2A-4A88-9B15-3C0F2D7F4E91}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppCopyright={#MyAppCopyright}
AppComments=صدقة عن والدي المرحوم بوزويرة قادة
VersionInfoVersion=1.1.20.0
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=مثبت {#MyAppName}
VersionInfoCopyright={#MyAppCopyright}
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}
; UsePreviousAppDir keeps existing installations and their data in place.
DefaultDirName={autopf}\TimeTrackEnterprise
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes
PrivilegesRequired=admin
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=TimeTrackEnterprise_Setup_{#MyAppVersion}
SetupIconFile=..\build_assets\TimeTrackEnterprise.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes

[Languages]
Name: "arabic"; MessagesFile: "Arabic.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; DestName: "README.md"; Flags: ignoreversion

[InstallDelete]
; Remove the legacy binary when upgrading in place; keep its data directory.
Type: files; Name: "{app}\SmartAttendance.exe"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "{#MyAppName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall
