unit Boss4D.Core.Services.IDEProcessPolicy;

interface

uses
  System.SysUtils;

type
  EBoss4DIDERunning = class(Exception);

  TBoss4DIDEOpenPolicy = (Fail, Defer, Force);
  TBoss4DIDEOpenDecision = (Proceed, Deferred);

  IBoss4DIDEProcessProbe = interface
    ['{D6B45266-23D2-49C4-9417-8FA4D590D8FD}']
    function IsRunning(const AExecutableName: string): Boolean;
  end;

  TBoss4DWindowsIDEProcessProbe = class(TInterfacedObject,
    IBoss4DIDEProcessProbe)
  public
    function IsRunning(const AExecutableName: string): Boolean;
  end;

  TBoss4DIDEProcessPolicy = class
  public
    class function Evaluate(const AProbe: IBoss4DIDEProcessProbe;
      const AExecutableName: string; const APolicy: TBoss4DIDEOpenPolicy):
      TBoss4DIDEOpenDecision; static;
  end;

implementation

uses
  System.IOUtils,
  Winapi.Windows,
  Winapi.TlHelp32;

function TBoss4DWindowsIDEProcessProbe.IsRunning(
  const AExecutableName: string): Boolean;
var
  LSnapshot: THandle;
  LEntry: TProcessEntry32;
  LName: string;
begin
  Result := False;
  LName := TPath.GetFileName(AExecutableName);
  if LName.Trim.IsEmpty then
    raise EArgumentException.Create(
      'O executavel da IDE e obrigatorio.');
  LSnapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if LSnapshot = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    LEntry.dwSize := SizeOf(LEntry);
    if Process32First(LSnapshot, LEntry) then
      repeat
        if SameText(LEntry.szExeFile, LName) then
          Exit(True);
      until not Process32Next(LSnapshot, LEntry);
  finally
    CloseHandle(LSnapshot);
  end;
end;

class function TBoss4DIDEProcessPolicy.Evaluate(
  const AProbe: IBoss4DIDEProcessProbe; const AExecutableName: string;
  const APolicy: TBoss4DIDEOpenPolicy): TBoss4DIDEOpenDecision;
begin
  if not Assigned(AProbe) then
    raise EArgumentNilException.Create('AProbe');
  if not AProbe.IsRunning(AExecutableName) then
    Exit(TBoss4DIDEOpenDecision.Proceed);
  case APolicy of
    TBoss4DIDEOpenPolicy.Defer:
      Result := TBoss4DIDEOpenDecision.Deferred;
    TBoss4DIDEOpenPolicy.Force:
      Result := TBoss4DIDEOpenDecision.Proceed;
  else
    raise EBoss4DIDERunning.CreateFmt(
      'A IDE %s esta aberta. Feche-a, use defer ou force explicitamente.',
      [TPath.GetFileName(AExecutableName)]);
  end;
end;

end.
