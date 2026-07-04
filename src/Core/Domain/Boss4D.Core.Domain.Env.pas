unit Boss4D.Core.Domain.Env;

interface

uses
  Boss4D.Core.Domain.Consts;

function GetBossHome: string;
function GetCacheDir: string;
function GetModulesDir: string;
function GetCurrentDir: string;
function GetBossFile: string;
function GetGlobalConfigPath: string;

implementation

uses
  System.SysUtils, System.IOUtils;

function GetBossHome: string;
var
  LHome: string;
begin
  LHome := GetEnvironmentVariable('BOSS_HOME');
  if LHome.IsEmpty then
  begin
    {$IFDEF MSWINDOWS}
    LHome := GetEnvironmentVariable('USERPROFILE');
    {$ELSE}
    LHome := GetEnvironmentVariable('HOME');
    {$ENDIF}
    if LHome.IsEmpty then
      LHome := TPath.GetHomePath; // Fallback para diretorio home padrao do Delphi
    
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
  Result := TDirectory.GetCurrentDirectory;
end;

function GetBossFile: string;
begin
  Result := TPath.Combine(GetCurrentDir, FILE_PACKAGE);
end;

function GetGlobalConfigPath: string;
begin
  Result := TPath.Combine(GetBossHome, BOSS_CONFIG_FILE);
end;

end.
