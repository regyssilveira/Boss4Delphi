unit Boss4D.GUI.TargetProgress;

interface

uses
  Boss4D.Core.Domain.Progress,
  Boss4D.Core.Services.BuildExecutor;

type
  TBoss4DGUIProgressEventHandler = reference to procedure(
    const AEvent: TBoss4DProgressEvent);

  TBoss4DGUIProgressReporter = class(TInterfacedObject,
    IBoss4DProgressReporter)
  private
    FHandler: TBoss4DGUIProgressEventHandler;
  public
    constructor Create(const AHandler: TBoss4DGUIProgressEventHandler);
    procedure Report(const AEvent: TBoss4DProgressEvent);
  end;

  TBoss4DGUITargetProgressRow = record
    TargetIdentity: string;
    State: string;
    Current: Integer;
    Total: Integer;
    Percentage: Integer;
    Message: string;
    IsFailure: Boolean;
  end;

  TBoss4DGUITargetProgress = class
  public
    class function FromBuildEvent(
      const AEvent: TBoss4DBuildTargetProgressEvent):
      TBoss4DGUITargetProgressRow; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

constructor TBoss4DGUIProgressReporter.Create(
  const AHandler: TBoss4DGUIProgressEventHandler);
begin
  inherited Create;
  if not Assigned(AHandler) then
    raise EArgumentNilException.Create('AHandler');
  FHandler := AHandler;
end;

procedure TBoss4DGUIProgressReporter.Report(
  const AEvent: TBoss4DProgressEvent);
begin
  FHandler(AEvent);
end;

class function TBoss4DGUITargetProgress.FromBuildEvent(
  const AEvent: TBoss4DBuildTargetProgressEvent):
  TBoss4DGUITargetProgressRow;
begin
  if AEvent.TargetIdentity.Trim.IsEmpty then
    raise EArgumentException.Create('A identidade do target e obrigatoria.');
  if AEvent.Total <= 0 then
    raise EArgumentOutOfRangeException.Create(
      'O total de targets deve ser positivo.');
  if (AEvent.Current < 0) or (AEvent.Current > AEvent.Total) then
    raise EArgumentOutOfRangeException.Create(
      'O progresso atual deve estar entre zero e o total.');

  Result := Default(TBoss4DGUITargetProgressRow);
  Result.TargetIdentity := AEvent.TargetIdentity;
  Result.Current := AEvent.Current;
  Result.Total := AEvent.Total;
  Result.Percentage := EnsureRange(
    (AEvent.Current * 100) div AEvent.Total, 0, 100);
  Result.Message := AEvent.Message;
  case AEvent.State of
    TargetStarted: Result.State := 'iniciado';
    TargetBuilt: Result.State := 'compilado';
    TargetRestored: Result.State := 'restaurado';
    TargetSkipped: Result.State := 'atualizado';
    TargetFailed:
      begin
        Result.State := 'falhou';
        Result.IsFailure := True;
      end;
  else
    Result.State := 'desconhecido';
  end;
end;

end.
