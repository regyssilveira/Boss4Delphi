unit Boss4D.Core.Services.Progress;

interface

uses
  System.SyncObjs, Boss4D.Core.Domain.Progress;

type
  TBoss4DNullProgressReporter = class(TInterfacedObject,
    IBoss4DProgressReporter)
  private
    FConsumedEvents: Integer;
  public
    procedure Report(const AEvent: TBoss4DProgressEvent);
  end;

  TBoss4DProgressReporter = class(TInterfacedObject,
    IBoss4DProgressReporter)
  private
    FOutput: IBoss4DProgressOutput;
    FMode: string;
    FLock: TCriticalSection;
    function FormatPlain(const AEvent: TBoss4DProgressEvent): string;
    function FormatJson(const AEvent: TBoss4DProgressEvent): string;
  public
    constructor Create(const AOutput: IBoss4DProgressOutput;
      const AMode: string);
    destructor Destroy; override;
    procedure Report(const AEvent: TBoss4DProgressEvent);
  end;

implementation

uses
  System.SysUtils, System.JSON, System.DateUtils;

procedure TBoss4DNullProgressReporter.Report(
  const AEvent: TBoss4DProgressEvent);
begin
  TInterlocked.Increment(FConsumedEvents);
end;

constructor TBoss4DProgressReporter.Create(
  const AOutput: IBoss4DProgressOutput; const AMode: string);
begin
  inherited Create;
  if not Assigned(AOutput) then
    raise EArgumentNilException.Create('AOutput');
  FOutput := AOutput;
  FMode := LowerCase(AMode);
  FLock := TCriticalSection.Create;
end;

destructor TBoss4DProgressReporter.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TBoss4DProgressReporter.FormatPlain(
  const AEvent: TBoss4DProgressEvent): string;
var
  LProgress: string;
begin
  LProgress := '';
  if AEvent.Total > 0 then
    LProgress := Format(' [%d/%d]', [AEvent.Current, AEvent.Total]);
  Result := Format('[%s] %s%s', [Boss4DProgressPhaseName(AEvent.Phase),
    AEvent.PackageName, LProgress]);
  if not AEvent.Message.IsEmpty then
    Result := Result + ' - ' + AEvent.Message;
end;

function TBoss4DProgressReporter.FormatJson(
  const AEvent: TBoss4DProgressEvent): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('operationId', AEvent.OperationId);
    LJson.AddPair('package', AEvent.PackageName);
    LJson.AddPair('phase', Boss4DProgressPhaseName(AEvent.Phase));
    LJson.AddPair('current', TJSONNumber.Create(AEvent.Current));
    LJson.AddPair('total', TJSONNumber.Create(AEvent.Total));
    LJson.AddPair('message', AEvent.Message);
    LJson.AddPair('timestamp',
      DateToISO8601(AEvent.Timestamp, False));
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

procedure TBoss4DProgressReporter.Report(
  const AEvent: TBoss4DProgressEvent);
var
  LLine: string;
begin
  FLock.Enter;
  try
    if FMode = 'json' then
      LLine := FormatJson(AEvent)
    else
      LLine := FormatPlain(AEvent);
    if (FMode = 'interactive') and FOutput.IsInteractive and
       not (AEvent.Phase in [Completed, Failed]) then
      FOutput.Write(#13 + LLine)
    else
      FOutput.WriteLine(LLine);
  finally
    FLock.Leave;
  end;
end;

end.
