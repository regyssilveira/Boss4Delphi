unit Boss4D.Adapters.Platform.Windows;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DWindowsProcessRunner = class(TInterfacedObject,
    IBoss4DProcessRunner)
  public
    function Execute(const ACommandLine, AWorkingDirectory: string;
      out AOutput: string): Boolean;
  end;

  TBoss4DWindowsPlatformEnvironment = class(TInterfacedObject,
    IBoss4DPlatformEnvironment)
  public
    function PlatformName: string;
    function HomePath: string;
    function CurrentDirectory: string;
    procedure MakeFileWritable(const APath: string);
    function SupportsWindowsRegistry: Boolean;
    function SupportsGetIt: Boolean;
  end;

  TBoss4DWindowsFileLinkService = class(TInterfacedObject,
    IBoss4DFileLinkService)
  public
    function RemoveDirectoryLink(const ALinkPath: string): Boolean;
    function CreateDirectoryLink(const ATargetPath, ALinkPath: string): Boolean;
  end;

procedure ConfigureWindowsPlatform;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows,
  Boss4D.Core.Platform;

function TBoss4DWindowsProcessRunner.Execute(const ACommandLine,
  AWorkingDirectory: string; out AOutput: string): Boolean;
var
  LSecurity: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LStartInfo: TStartupInfo;
  LProcessInfo: TProcessInformation;
  LBuffer: array[0..255] of AnsiChar;
  LBytesRead, LExitCode: DWORD;
  LWorkingDirectory, LTemporaryOutput, LMutableCommand: string;
begin
  Result := False;
  AOutput := '';
  LTemporaryOutput := '';
  LReadPipe := 0;
  LWritePipe := 0;
  LSecurity.nLength := SizeOf(TSecurityAttributes);
  LSecurity.bInheritHandle := True;
  LSecurity.lpSecurityDescriptor := nil;
  if not CreatePipe(LReadPipe, LWritePipe, @LSecurity, 0) then
    Exit;
  try
    FillChar(LStartInfo, SizeOf(TStartupInfo), 0);
    LStartInfo.cb := SizeOf(TStartupInfo);
    LStartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LStartInfo.hStdOutput := LWritePipe;
    LStartInfo.hStdError := LWritePipe;
    LStartInfo.wShowWindow := SW_HIDE;
    LMutableCommand := ACommandLine;
    UniqueString(LMutableCommand);
    LWorkingDirectory := AWorkingDirectory;
    if LWorkingDirectory.IsEmpty then
      LWorkingDirectory := TDirectory.GetCurrentDirectory;
    if CreateProcess(nil, PChar(LMutableCommand), nil, nil, True, 0, nil,
      PChar(LWorkingDirectory), LStartInfo, LProcessInfo) then
    begin
      try
        CloseHandle(LWritePipe);
        LWritePipe := 0;
        repeat
          LBytesRead := 0;
          if ReadFile(LReadPipe, LBuffer[0], SizeOf(LBuffer) - 1,
            LBytesRead, nil) and (LBytesRead > 0) then
          begin
            LBuffer[LBytesRead] := #0;
            LTemporaryOutput := LTemporaryOutput +
              string(AnsiString(LBuffer));
          end;
        until LBytesRead = 0;
        WaitForSingleObject(LProcessInfo.hProcess, INFINITE);
        LExitCode := 0;
        GetExitCodeProcess(LProcessInfo.hProcess, LExitCode);
        Result := LExitCode = 0;
      finally
        CloseHandle(LProcessInfo.hProcess);
        CloseHandle(LProcessInfo.hThread);
      end;
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    if LReadPipe <> 0 then
      CloseHandle(LReadPipe);
  end;
  AOutput := LTemporaryOutput.Trim;
end;

function TBoss4DWindowsPlatformEnvironment.PlatformName: string;
begin
  Result := 'windows';
end;

function TBoss4DWindowsPlatformEnvironment.HomePath: string;
begin
  Result := GetEnvironmentVariable('USERPROFILE');
  if Result.IsEmpty then
    Result := TPath.GetHomePath;
end;

function TBoss4DWindowsPlatformEnvironment.CurrentDirectory: string;
begin
  Result := TDirectory.GetCurrentDirectory;
end;

procedure TBoss4DWindowsPlatformEnvironment.MakeFileWritable(
  const APath: string);
begin
  if not SetFileAttributes(PChar(APath), FILE_ATTRIBUTE_NORMAL) then
    RaiseLastOSError;
end;

function TBoss4DWindowsPlatformEnvironment.SupportsWindowsRegistry: Boolean;
begin
  Result := True;
end;

function TBoss4DWindowsPlatformEnvironment.SupportsGetIt: Boolean;
begin
  Result := True;
end;

function TBoss4DWindowsFileLinkService.RemoveDirectoryLink(
  const ALinkPath: string): Boolean;
var
  LOutput: string;
begin
  Result := TBoss4DWindowsProcessRunner.Create.Execute(
    'cmd.exe /c rmdir "' + ALinkPath + '"',
    TPath.GetDirectoryName(ALinkPath), LOutput);
end;

function TBoss4DWindowsFileLinkService.CreateDirectoryLink(
  const ATargetPath, ALinkPath: string): Boolean;
var
  LOutput: string;
begin
  Result := TBoss4DWindowsProcessRunner.Create.Execute(
    'cmd.exe /c mklink /J "' + ALinkPath + '" "' + ATargetPath + '"',
    TPath.GetDirectoryName(ALinkPath), LOutput);
end;

procedure ConfigureWindowsPlatform;
begin
  ConfigureBoss4DPlatform(TBoss4DWindowsProcessRunner.Create,
    TBoss4DWindowsPlatformEnvironment.Create,
    TBoss4DWindowsFileLinkService.Create);
end;

end.
