#ifndef AppVersion
  #error AppVersion must be supplied by build_windows_installer.ps1
#endif
#ifndef AppBuild
  #error AppBuild must be supplied by build_windows_installer.ps1
#endif
#ifndef SourceDir
  #error SourceDir must be supplied by build_windows_installer.ps1
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by build_windows_installer.ps1
#endif

#define AppVersionInfo AppVersion + "." + AppBuild

[Setup]
AppId={{B653B669-E2AB-4D8C-9F65-E642A15D3B45}
AppName=ClashXY
AppPublisher=ClashXY contributors
AppPublisherURL=https://github.com/ltxy12138-ai/ClashXY
AppSupportURL=https://github.com/ltxy12138-ai/ClashXY/issues
AppUpdatesURL=https://github.com/ltxy12138-ai/ClashXY/releases
AppVersion={#AppVersion}
AppVerName=ClashXY {#AppVersion} (build {#AppBuild})
VersionInfoVersion={#AppVersionInfo}
VersionInfoCompany=ClashXY contributors
VersionInfoDescription=ClashXY Windows installer
VersionInfoProductName=ClashXY
VersionInfoProductVersion={#AppVersion}
DefaultDirName={autopf}\ClashXY
DefaultGroupName=ClashXY
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=ClashXY-Setup-x64-{#AppVersion}-build{#AppBuild}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ClashXY.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
AppMutex=Local\ClashXY.Windows.SingleInstance.v1,Local\MyTunnel.Windows.SingleInstance.v1
CloseApplications=yes
RestartApplications=no
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
MinVersion=10.0.17763
#ifdef SignToolName
SignTool={#SignToolName}
SignedUninstaller=yes
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
#ifdef SignToolName
; Sign only the first-party executable with the ClashXY publisher identity.
; Bundled upstream binaries (including Mihomo and Flutter dependencies) retain
; their original provenance and must not be re-signed as ClashXY.
Source: "{#SourceDir}\ClashXY.exe"; DestDir: "{app}"; Flags: ignoreversion signonce
Source: "{#SourceDir}\*"; Excludes: "ClashXY.exe"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#else
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
#endif
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "..\NOTICE.md"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "..\PRIVACY.md"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "..\SECURITY.md"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "..\THIRD_PARTY_NOTICES.md"; DestDir: "{app}\licenses"; Flags: ignoreversion
Source: "..\assets\licenses\mihomo-GPL-3.0.txt"; DestDir: "{app}\licenses"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ClashXY"; Filename: "{app}\ClashXY.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\ClashXY"; Filename: "{app}\ClashXY.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\ClashXY.exe"; Description: "{cm:LaunchProgram,ClashXY}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
