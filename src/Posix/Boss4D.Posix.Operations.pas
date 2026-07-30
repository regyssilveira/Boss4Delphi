unit Boss4D.Posix.Operations;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DProgressMode = (pmPlain, pmInteractive, pmJson, pmQuiet);

  TBoss4DProgressEvent = record
    OperationId: string;
    PackageName: string;
    Phase: string;
    Current: Integer;
    Total: Integer;
    MessageText: string;
    Timestamp: string;
  end;

  TBoss4DProgressReporter = class
  private
    FMode: TBoss4DProgressMode;
  public
    constructor Create(const AMode: TBoss4DProgressMode);
    procedure Emit(const AEvent: TBoss4DProgressEvent);
  end;

function ParseProgressMode(const AValue: string; const AJson,
  AQuiet: Boolean): TBoss4DProgressMode;
function FormatProgressEvent(const AEvent: TBoss4DProgressEvent;
  const AMode: TBoss4DProgressMode): string;
function NewProgressEvent(const AOperationId, APackageName, APhase,
  AMessage: string; const ACurrent, ATotal: Integer): TBoss4DProgressEvent;
function ClassifyExitCode(const AMessage: string): Integer;
function FindExecutable(const AName: string): string;
function RunDoctor: TStringList;
function DoctorPassed(const AResults: TStrings): Boolean;
procedure InstallCancellationHandler;
procedure RequestCancellation;
procedure ResetCancellation;
procedure CheckCancelled;

implementation

uses
  DateUtils, process, BaseUnix;

var
  GCancelled: Boolean = False;

procedure HandleSignal(ASignal: cint); cdecl;
begin
  if ASignal = SIGINT then GCancelled := True;
end;

function JsonEscape(const AValue: string): string;
begin
  Result := StringReplace(AValue, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function ParseProgressMode(const AValue: string; const AJson,
  AQuiet: Boolean): TBoss4DProgressMode;
begin
  if AQuiet then Exit(pmQuiet);
  if AJson then Exit(pmJson);
  if (AValue = '') or SameText(AValue, 'plain') then Exit(pmPlain);
  if SameText(AValue, 'interactive') then Exit(pmInteractive);
  if SameText(AValue, 'json') then Exit(pmJson);
  if SameText(AValue, 'quiet') then Exit(pmQuiet);
  raise Exception.Create('invalid progress mode: ' + AValue);
end;

function FormatProgressEvent(const AEvent: TBoss4DProgressEvent;
  const AMode: TBoss4DProgressMode): string;
begin
  if AMode = pmQuiet then Exit('');
  if AMode = pmJson then
    Exit('{"operationId":"' + JsonEscape(AEvent.OperationId) +
      '","package":"' + JsonEscape(AEvent.PackageName) +
      '","phase":"' + JsonEscape(AEvent.Phase) +
      '","current":' + IntToStr(AEvent.Current) +
      ',"total":' + IntToStr(AEvent.Total) +
      ',"message":"' + JsonEscape(AEvent.MessageText) +
      '","timestamp":"' + JsonEscape(AEvent.Timestamp) + '"}');
  Result := '[' + AEvent.Phase + ']';
  if AEvent.PackageName <> '' then Result := Result + ' ' + AEvent.PackageName;
  if AEvent.Total > 0 then
    Result := Result + ' ' + IntToStr(AEvent.Current) + '/' +
      IntToStr(AEvent.Total);
  if AEvent.MessageText <> '' then Result := Result + ' - ' +
    AEvent.MessageText;
end;

function NewProgressEvent(const AOperationId, APackageName, APhase,
  AMessage: string; const ACurrent, ATotal: Integer): TBoss4DProgressEvent;
begin
  Result.OperationId := AOperationId;
  Result.PackageName := APackageName;
  Result.Phase := APhase;
  Result.Current := ACurrent;
  Result.Total := ATotal;
  Result.MessageText := AMessage;
  Result.Timestamp := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"',
    LocalTimeToUniversal(Now));
end;

constructor TBoss4DProgressReporter.Create(const AMode: TBoss4DProgressMode);
begin
  inherited Create;
  FMode := AMode;
end;

procedure TBoss4DProgressReporter.Emit(const AEvent: TBoss4DProgressEvent);
var
  LText: string;
begin
  LText := FormatProgressEvent(AEvent, FMode);
  if LText <> '' then WriteLn(LText);
end;

function ClassifyExitCode(const AMessage: string): Integer;
var
  LMessage: string;
begin
  LMessage := LowerCase(AMessage);
  if Pos('cancelled', LMessage) > 0 then Exit(130);
  if (Pos('usage:', LMessage) > 0) or
     (Pos('unknown command', LMessage) > 0) or
     (Pos('invalid progress mode', LMessage) > 0) then Exit(2);
  if Pos('not found:', LMessage) > 0 then Exit(3);
  if (Pos('sha-256', LMessage) > 0) or
     (Pos('digest mismatch', LMessage) > 0) or
     (Pos('signature verification', LMessage) > 0) or
     (Pos('provenance verification', LMessage) > 0) or
     (Pos('unsafe package path', LMessage) > 0) then Exit(4);
  if (Pos('network', LMessage) > 0) or
     (Pos('offline', LMessage) > 0) or
     (Pos('http', LMessage) > 0) then Exit(5);
  Result := 1;
end;

function FindExecutable(const AName: string): string;
begin
  Result := FileSearch(AName, GetEnvironmentVariable('PATH'));
end;

function CommandVersion(const AName: string;
  const AArguments: array of string): string;
var
  LOutput: string;
begin
  if FindExecutable(AName) = '' then Exit('');
  if RunCommand(AName, AArguments, LOutput) then Result := Trim(LOutput)
  else Result := '';
end;

function RunDoctor: TStringList;
var
  LValue, LHome, LProbe: string;
  LFile: TextFile;
begin
  Result := TStringList.Create;
  LValue := CommandVersion('git', ['--version']);
  if LValue = '' then Result.Add('ERROR git: not found')
  else Result.Add('OK git: ' + LValue);
  LValue := CommandVersion('sha256sum', ['--version']);
  if LValue = '' then Result.Add('ERROR sha256sum: not found')
  else Result.Add('OK sha256sum: available');
  LValue := CommandVersion('gpg', ['--version']);
  if LValue = '' then Result.Add('WARN gpg: not found; signed packages unavailable')
  else Result.Add('OK gpg: available');
  LValue := CommandVersion('fpc', ['-iV']);
  if LValue = '' then Result.Add('WARN fpc: not found; source compilation unavailable')
  else Result.Add('OK fpc: ' + LValue);
  LHome := GetEnvironmentVariable('BOSS_HOME');
  if LHome = '' then
    LHome := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
      '.boss';
  try
    ForceDirectories(LHome);
    LProbe := IncludeTrailingPathDelimiter(LHome) + '.doctor-write-test';
    AssignFile(LFile, LProbe);
    Rewrite(LFile);
    CloseFile(LFile);
    DeleteFile(LProbe);
    Result.Add('OK home: writable');
  except
    Result.Add('ERROR home: not writable');
  end;
end;

function DoctorPassed(const AResults: TStrings): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to AResults.Count - 1 do
    if Pos('ERROR ', AResults[I]) = 1 then Exit(False);
end;

procedure InstallCancellationHandler;
begin
  fpSignal(SIGINT, @HandleSignal);
end;

procedure RequestCancellation;
begin
  GCancelled := True;
end;

procedure ResetCancellation;
begin
  GCancelled := False;
end;

procedure CheckCancelled;
begin
  if GCancelled then raise Exception.Create('operation cancelled');
end;

end.
