#define MyAppName "ClassSync"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#define MyAppPublisher "ClassSync"
#define MyAppExeName "ClassSync.exe"

[Setup]
AppId={{D8F2AA91-F4CC-4BA1-96A1-14790667BE0C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\ClassSync
DefaultGroupName=ClassSync
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=ClassSync-Setup-{#MyAppVersion}
SetupIconFile=..\..\apps\client\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "..\..\apps\client\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ClassSync"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\ClassSync"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch ClassSync"; Flags: nowait postinstall skipifsilent
