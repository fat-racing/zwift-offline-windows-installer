#define AppName "Zwift Offline"
#define AppVersion "1.0.164452"
#define AppPublisher "Community package"

[Setup]
AppId={{2E0E3EF9-38A2-41BD-969E-966368759E2E}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={commonappdata}\ZwiftOffline
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
DisableWelcomePage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
OutputDir=..\dist
OutputBaseFilename=ZwiftOfflineSetup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
UninstallDisplayName={#AppName}
CloseApplications=yes
RestartApplications=no
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce
Name: "fullgarage"; Description: "Unlock all available equipment"; GroupDescription: "Optional features:"; Flags: checkedonce
Name: "bots"; Description: "Install bots and RoboPacers (may reduce performance)"; GroupDescription: "Optional features:"; Flags: unchecked

[Dirs]
Name: "{app}"; Permissions: users-modify
Name: "{app}\storage"; Permissions: users-modify
Name: "{app}\ssl"; Permissions: users-modify

[Files]
Source: "payload\zoffline.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "payload\ssl\*"; DestDir: "{app}\ssl"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Install-ZwiftOffline.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Start-ZwiftOffline.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Uninstall-ZwiftOffline.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\SOURCE.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE-zoffline.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\screenshots\*"; DestDir: "{app}\docs\screenshots"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\storage\unlock_all_equipment.txt"; DestDir: "{app}\storage"; Tasks: fullgarage; Flags: ignoreversion
Source: "payload\storage\enable_bots.txt"; DestDir: "{app}\storage"; Tasks: bots; Flags: ignoreversion
Source: "payload\storage\bot_teams.txt"; DestDir: "{app}\storage"; Tasks: bots; Flags: ignoreversion
Source: "payload\storage\bots\*"; DestDir: "{app}\storage\bots"; Tasks: bots; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "payload\storage\robopacers\*"; DestDir: "{app}\storage\robopacers"; Tasks: bots; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Zwift Offline"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Start-ZwiftOffline.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\zoffline.exe"
Name: "{autodesktop}\Zwift Offline"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Start-ZwiftOffline.ps1"""; WorkingDir: "{app}"; IconFilename: "{app}\zoffline.exe"; Tasks: desktopicon

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Start-ZwiftOffline.ps1"""; Description: "Launch Zwift Offline"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Uninstall-ZwiftOffline.ps1"" -InstallDir ""{app}"""; Flags: runhidden waituntilterminated; RunOnceId: "ZwiftOfflineCleanup"

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
  PowerShell: String;
  Parameters: String;
begin
  if CurStep = ssPostInstall then
  begin
    PowerShell := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
    Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' +
      ExpandConstant('{app}\Install-ZwiftOffline.ps1') + '" -InstallDir "' +
      ExpandConstant('{app}') + '"';
    if (not Exec(PowerShell, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode)) or
       (ResultCode <> 0) then
      RaiseException('Zwift Offline configuration failed. See install.log in the installation folder.');
  end;
end;
