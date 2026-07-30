unit Boss4D.Core.Domain.Env;

interface

function GetBossHome: string;
function GetCacheDir: string;
function GetModulesDir: string;
function GetCurrentDir: string;
function GetBossFile: string;
function GetGlobalConfigPath: string;
function ExecuteCommandLine(const ACommandLine: string; const AWorkingDir: string; out AOutput: string): Boolean;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Platform;

function GetBossHome: string;
var
  LHome: string;
begin
  LHome := GetEnvironmentVariable('BOSS_HOME');
  if LHome.IsEmpty then
  begin
    LHome := Boss4DPlatformEnvironment.HomePath;
    LHome := TPath.Combine(LHome, FOLDER_BOSS_HOME);
  end;
  Result := LHome;
end;

function GetCacheDir: string;
begin
  Result := TPath.Combine(GetBossHome, 'cache');
end;

function GetModulesDir: string;
begin
  Result := TPath.Combine(GetCurrentDir, FOLDER_DEPENDENCIES);
end;

function GetCurrentDir: string;
begin
  Result := Boss4DPlatformEnvironment.CurrentDirectory;
end;

function GetBossFile: string;
begin
  Result := TPath.Combine(GetCurrentDir, FILE_PACKAGE);
end;

function GetGlobalConfigPath: string;
begin
  Result := TPath.Combine(GetBossHome, BOSS_CONFIG_FILE);
end;

function ExecuteCommandLine(const ACommandLine: string;
  const AWorkingDir: string; out AOutput: string): Boolean;
begin
  Result := Boss4DProcessRunner.Execute(
    ACommandLine, AWorkingDir, AOutput);
end;

end.
