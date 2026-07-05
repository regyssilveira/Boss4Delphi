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
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Consts, Winapi.Windows;

function GetBossHome: string;
var
  LHome: string;
begin
  LHome := GetEnvironmentVariable('BOSS_HOME');
  if LHome.IsEmpty then
  begin
    LHome := GetEnvironmentVariable('USERPROFILE');
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

function ExecuteCommandLine(const ACommandLine: string; const AWorkingDir: string; out AOutput: string): Boolean;
var
  LSA: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LStartInfo: TStartupInfo;
  LProcInfo: TProcessInformation;
  LBuffer: array[0..255] of AnsiChar;
  LBytesRead: DWORD;
  LWorkingDir: string;
  LTempOutput: string;
  LMutableCmd: string;
begin
  Result := False;
  AOutput := '';
  LTempOutput := '';

  LSA.nLength := SizeOf(TSecurityAttributes);
  LSA.bInheritHandle := True;
  LSA.lpSecurityDescriptor := nil;

  if not CreatePipe(LReadPipe, LWritePipe, @LSA, 0) then
    Exit;

  try
    FillChar(LStartInfo, SizeOf(TStartupInfo), 0);
    LStartInfo.cb := SizeOf(TStartupInfo);
    LStartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LStartInfo.hStdOutput := LWritePipe;
    LStartInfo.hStdError := LWritePipe;
    LStartInfo.wShowWindow := SW_HIDE;

    LMutableCmd := ACommandLine;
    UniqueString(LMutableCmd);

    LWorkingDir := AWorkingDir;
    if LWorkingDir.IsEmpty then
      LWorkingDir := TDirectory.GetCurrentDirectory;

    if CreateProcess(nil, PChar(LMutableCmd), nil, nil, True, 0, nil, PChar(LWorkingDir), LStartInfo, LProcInfo) then
    begin
      try
        CloseHandle(LWritePipe);
        LWritePipe := 0;

        repeat
          LBytesRead := 0;
          if ReadFile(LReadPipe, LBuffer[0], SizeOf(LBuffer) - 1, LBytesRead, nil) and (LBytesRead > 0) then
          begin
            LBuffer[LBytesRead] := #0;
            LTempOutput := LTempOutput + string(AnsiString(LBuffer));
          end;
        until LBytesRead = 0;

        WaitForSingleObject(LProcInfo.hProcess, INFINITE);

        var LExitCode: DWORD := 0;
        GetExitCodeProcess(LProcInfo.hProcess, LExitCode);
        Result := LExitCode = 0;
      finally
        CloseHandle(LProcInfo.hProcess);
        CloseHandle(LProcInfo.hThread);
      end;
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    CloseHandle(LReadPipe);
  end;

  AOutput := LTempOutput.Trim;
end;

end.
