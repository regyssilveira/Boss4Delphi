unit Boss4D.GUI.Process.Windows;

interface

uses
  Boss4D.GUI.Install.Presenter;

type
  TBoss4DGUIWindowsProcessRunner = class(TInterfacedObject,
    IBoss4DGUICancellableProcessRunner)
  public
    function Execute(const ACommandLine, AWorkingDirectory: string;
      const ACancellation: TBoss4DGUICancellationProbe;
      out AOutput: string; out ACancelled: Boolean): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows;

function TBoss4DGUIWindowsProcessRunner.Execute(const ACommandLine,
  AWorkingDirectory: string; const ACancellation: TBoss4DGUICancellationProbe;
  out AOutput: string; out ACancelled: Boolean): Boolean;
var
  LSecurity: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LStartInfo: TStartupInfo;
  LProcessInfo: TProcessInformation;
  LBuffer: array[0..1023] of AnsiChar;
  LAvailable, LBytesRead, LExitCode, LReadSize: DWORD;
  LWorkingDirectory, LCommand: string;
  LWaitResult: DWORD;

  procedure DrainOutput;
  begin
    repeat
      LAvailable := 0;
      if not PeekNamedPipe(LReadPipe, nil, 0, nil, @LAvailable, nil) or
         (LAvailable = 0) then
        Exit;
      if LAvailable > DWORD(SizeOf(LBuffer) - 1) then
        LReadSize := SizeOf(LBuffer) - 1
      else
        LReadSize := LAvailable;
      LBytesRead := 0;
      if not ReadFile(LReadPipe, LBuffer[0], LReadSize, LBytesRead, nil) or
         (LBytesRead = 0) then
        Exit;
      LBuffer[LBytesRead] := #0;
      AOutput := AOutput + string(AnsiString(LBuffer));
    until False;
  end;

begin
  Result := False;
  ACancelled := False;
  AOutput := '';
  LReadPipe := 0;
  LWritePipe := 0;
  FillChar(LSecurity, SizeOf(LSecurity), 0);
  LSecurity.nLength := SizeOf(LSecurity);
  LSecurity.bInheritHandle := True;
  if not CreatePipe(LReadPipe, LWritePipe, @LSecurity, 0) then
    RaiseLastOSError;
  try
    SetHandleInformation(LReadPipe, HANDLE_FLAG_INHERIT, 0);
    FillChar(LStartInfo, SizeOf(LStartInfo), 0);
    LStartInfo.cb := SizeOf(LStartInfo);
    LStartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LStartInfo.hStdOutput := LWritePipe;
    LStartInfo.hStdError := LWritePipe;
    LStartInfo.wShowWindow := SW_HIDE;
    LWorkingDirectory := AWorkingDirectory;
    if LWorkingDirectory = '' then
      LWorkingDirectory := TDirectory.GetCurrentDirectory;
    LCommand := ACommandLine;
    UniqueString(LCommand);
    if not CreateProcess(nil, PChar(LCommand), nil, nil, True,
      CREATE_NO_WINDOW, nil, PChar(LWorkingDirectory), LStartInfo,
      LProcessInfo) then
      RaiseLastOSError;
    try
      CloseHandle(LWritePipe);
      LWritePipe := 0;
      repeat
        DrainOutput;
        if Assigned(ACancellation) and ACancellation() then
        begin
          ACancelled := True;
          TerminateProcess(LProcessInfo.hProcess, ERROR_CANCELLED);
        end;
        LWaitResult := WaitForSingleObject(LProcessInfo.hProcess, 50);
      until LWaitResult <> WAIT_TIMEOUT;
      DrainOutput;
      LExitCode := 1;
      GetExitCodeProcess(LProcessInfo.hProcess, LExitCode);
      Result := (LWaitResult = WAIT_OBJECT_0) and
        (LExitCode = 0) and not ACancelled;
    finally
      CloseHandle(LProcessInfo.hThread);
      CloseHandle(LProcessInfo.hProcess);
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    if LReadPipe <> 0 then
      CloseHandle(LReadPipe);
  end;
  AOutput := AOutput.Trim;
end;

end.
