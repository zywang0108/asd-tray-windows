; Inno Setup script for asd-tray-windows.
; Built by the GitHub Actions release workflow.
; Usage: ISCC.exe /DMyAppVersion=0.1.1 setup.iss

#define MyAppName       "ASD Tray for Windows"
#define MyAppExe        "brightness.exe"
#define MyAppPublisher  "zywang0108"
#define MyAppUrl        "https://github.com/zywang0108/asd-tray-windows"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

[Setup]
AppId={{6F9C8F4E-7B5D-4A0F-9E2B-1C2D3E4F5A6B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppUrl}
AppSupportURL={#MyAppUrl}/issues
AppUpdatesURL={#MyAppUrl}/releases
DefaultDirName={%USERPROFILE}\Tools\asdbctl
DefaultGroupName={#MyAppName}
DisableWelcomePage=yes
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
PrivilegesRequired=lowest
OutputBaseFilename=asd-tray-windows-setup-{#MyAppVersion}
OutputDir=dist-setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ChangesEnvironment=yes
Uninstallable=yes
UninstallDisplayIcon={app}\{#MyAppExe}
UninstallDisplayName={#MyAppName}
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "dist\asdbctl.exe";    DestDir: "{app}"; Flags: ignoreversion
Source: "dist\brightness.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\brightness.ahk"; DestDir: "{app}"; Flags: ignoreversion
Source: "dist\README.md";      DestDir: "{app}"; Flags: ignoreversion
Source: "dist\LICENSE";        DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{userstartup}\ASD Brightness Tray"; Filename: "{app}\{#MyAppExe}"; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#MyAppExe}"; Description: "Launch tray now"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/c taskkill /F /IM brightness.exe /T";    Flags: runhidden; RunOnceId: "killbrightness"
Filename: "{cmd}"; Parameters: "/c taskkill /F /IM AutoHotkey64.exe /T";  Flags: runhidden; RunOnceId: "killahk"

[Code]
const
  EnvironmentKey = 'Environment';

procedure EnvAddPath(Path: string);
var
  Paths: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    Paths := '';
  if Pos(';' + UpperCase(Path) + ';', ';' + UpperCase(Paths) + ';') > 0 then exit;
  if (Paths <> '') and (Paths[Length(Paths)] <> ';') then
    Paths := Paths + ';';
  Paths := Paths + Path;
  RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths);
end;

procedure EnvRemovePath(Path: string);
var
  Paths, NewPaths, Item: string;
  SemiPos: Integer;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then exit;
  NewPaths := '';
  while True do begin
    SemiPos := Pos(';', Paths);
    if SemiPos = 0 then begin
      Item := Paths;
      Paths := '';
    end else begin
      Item := Copy(Paths, 1, SemiPos - 1);
      Delete(Paths, 1, SemiPos);
    end;
    if (Item <> '') and (CompareText(Item, Path) <> 0) then begin
      if NewPaths <> '' then NewPaths := NewPaths + ';';
      NewPaths := NewPaths + Item;
    end;
    if (Paths = '') and (SemiPos = 0) then break;
  end;
  RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', NewPaths);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    EnvAddPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    EnvRemovePath(ExpandConstant('{app}'));
end;
