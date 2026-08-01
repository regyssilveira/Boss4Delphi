unit Boss4D.GUI.IDE.Timeline;

interface

uses
  Boss4D.Core.Services.IDEOperationResult;

type
  TBoss4DGUITimelineRow = record
    OperationId: string;
    StartedAt: string;
    CompletedAt: string;
    Status: string;
    Kind: string;
    Profile: string;
    Target: string;
    Actions: string;
    ErrorMessage: string;
    RecoveryInstruction: string;
    UndoSnapshot: string;
    AfterSnapshot: string;
    ChangedFields: string;
    function CanUndo: Boolean;
    function CanCompare: Boolean;
    function Detail: string;
  end;

  TBoss4DGUITimeline = class
  public
    class function Build(
      const AOperations: array of TBoss4DIDEOperationResult):
      TArray<TBoss4DGUITimelineRow>; static;
    class function FromOperation(
      const AOperation: TBoss4DIDEOperationResult):
      TBoss4DGUITimelineRow; static;
  end;

implementation

uses
  System.SysUtils;

function TBoss4DGUITimelineRow.CanUndo: Boolean;
begin
  Result := (Status = 'succeeded') and
    (SameText(Kind, 'profile-install') or
     SameText(Kind, 'profile-uninstall')) and
    not UndoSnapshot.Trim.IsEmpty;
end;

function TBoss4DGUITimelineRow.CanCompare: Boolean;
begin
  Result := not UndoSnapshot.Trim.IsEmpty and
    not AfterSnapshot.Trim.IsEmpty;
end;

function TBoss4DGUITimelineRow.Detail: string;
begin
  Result := Format(
    'Operacao: %s%sPerfil: %s%sTarget: %s%sStatus: %s%s' +
    'Inicio: %s%sFim: %s%sAcoes: %s',
    [Kind, sLineBreak, Profile, sLineBreak, Target, sLineBreak,
     Status, sLineBreak, StartedAt, sLineBreak, CompletedAt,
     sLineBreak, Actions]);
  if not ErrorMessage.Trim.IsEmpty then
    Result := Result + sLineBreak + 'Erro: ' + ErrorMessage;
  if not RecoveryInstruction.Trim.IsEmpty then
    Result := Result + sLineBreak + 'Recuperacao: ' +
      RecoveryInstruction;
  if CanUndo then
    Result := Result + sLineBreak + 'Desfazer: disponivel';
  if CanCompare then
  begin
    if ChangedFields.Trim.IsEmpty then
      Result := Result + sLineBreak + 'Antes/depois: sem alteracoes'
    else
      Result := Result + sLineBreak + 'Antes/depois: ' +
        ChangedFields;
  end;
end;

class function TBoss4DGUITimeline.FromOperation(
  const AOperation: TBoss4DIDEOperationResult):
  TBoss4DGUITimelineRow;
begin
  if not Assigned(AOperation) then
    raise EArgumentNilException.Create('AOperation');
  Result.OperationId := AOperation.OperationId;
  Result.StartedAt := AOperation.StartedAt;
  Result.CompletedAt := AOperation.CompletedAt;
  Result.Status := TBoss4DIDEOperationStatuses.NameOf(
    AOperation.Status);
  Result.Kind := AOperation.Kind;
  Result.Profile := AOperation.Profile;
  Result.Target := AOperation.Target;
  Result.Actions := string.Join(', ', AOperation.CompletedActions.ToArray);
  Result.ErrorMessage := AOperation.ErrorMessage;
  Result.RecoveryInstruction := AOperation.RecoveryInstruction;
  Result.UndoSnapshot := AOperation.UndoSnapshot;
  Result.AfterSnapshot := AOperation.AfterSnapshot;
end;

class function TBoss4DGUITimeline.Build(
  const AOperations: array of TBoss4DIDEOperationResult):
  TArray<TBoss4DGUITimelineRow>;
begin
  SetLength(Result, Length(AOperations));
  for var I := Low(AOperations) to High(AOperations) do
    Result[I] := FromOperation(AOperations[I]);
end;

end.
