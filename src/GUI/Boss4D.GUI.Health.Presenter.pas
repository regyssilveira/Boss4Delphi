unit Boss4D.GUI.Health.Presenter;

interface

uses
  Boss4D.Core.Services.Doctor,
  Boss4D.Core.Services.BuildDoctor;

type
  TBoss4DGUIHealthAction = (HealthActionNone, HealthActionRebuild,
    HealthActionReregister);

  TBoss4DGUIHealthRow = record
    Group: string;
    Status: string;
    Code: string;
    Message: string;
    Remediation: string;
    Fixable: Boolean;
    Fixed: Boolean;
    Action: TBoss4DGUIHealthAction;
    ActionTarget: string;
    function ActionLabel: string;
  end;

  TBoss4DGUIHealthSummary = record
    Healthy: Integer;
    Warnings: Integer;
    Errors: Integer;
    Fixed: Integer;
    function Text: string;
  end;

  TBoss4DGUIHealthPresenter = class
  public
    class function BuildRows(const AReport: TBoss4DDoctorReport):
      TArray<TBoss4DGUIHealthRow>; static;
    class function Summarize(const AReport: TBoss4DDoctorReport):
      TBoss4DGUIHealthSummary; static;
    class function AppendBuildRows(
      const ARows: TArray<TBoss4DGUIHealthRow>;
      const ABuildReport: TBoss4DBuildDoctorResult):
      TArray<TBoss4DGUIHealthRow>; static;
  end;

implementation

uses
  System.SysUtils;

function TBoss4DGUIHealthRow.ActionLabel: string;
begin
  case Action of
    HealthActionRebuild: Result := 'Rebuild completo';
    HealthActionReregister: Result := 'Registrar novamente';
  else
    Result := '';
  end;
end;

function TBoss4DGUIHealthSummary.Text: string;
begin
  Result := Format('%d saudavel(is), %d aviso(s), %d erro(s)',
    [Healthy, Warnings, Errors]);
  if Fixed > 0 then
    Result := Result + Format(', %d corrigido(s)', [Fixed]);
end;

class function TBoss4DGUIHealthPresenter.AppendBuildRows(
  const ARows: TArray<TBoss4DGUIHealthRow>;
  const ABuildReport: TBoss4DBuildDoctorResult):
  TArray<TBoss4DGUIHealthRow>;
begin
  Result := Copy(ARows);
  if not Assigned(ABuildReport) then
    Exit;
  if ABuildReport.Issues.Count = 0 then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := Default(TBoss4DGUIHealthRow);
    Result[High(Result)].Group := 'Projeto/Build';
    Result[High(Result)].Status := 'Saudavel';
    Result[High(Result)].Code := 'BUILD_READY';
    Result[High(Result)].Message :=
      'Matriz, grafo, projetos, outputs e registros estao consistentes.';
    Result[High(Result)].Remediation :=
      'Use rebuild completo para recompilar todos os targets.';
    Result[High(Result)].Action := HealthActionRebuild;
    Exit;
  end;

  for var LIssue in ABuildReport.Issues do
  begin
    SetLength(Result, Length(Result) + 1);
    var LIndex := High(Result);
    Result[LIndex] := Default(TBoss4DGUIHealthRow);
    Result[LIndex].Group := 'Projeto/Build';
    Result[LIndex].Code := LIssue.Code;
    Result[LIndex].Message := LIssue.Message;
    Result[LIndex].Remediation := LIssue.Remediation;
    case LIssue.Severity of
      TBoss4DDoctorSeverity.Error: Result[LIndex].Status := 'Erro';
      TBoss4DDoctorSeverity.Warning: Result[LIndex].Status := 'Aviso';
    else
      Result[LIndex].Status := 'Saudavel';
    end;
    if SameText(LIssue.Code, 'IDE_REGISTRY_DRIFT') then
    begin
      Result[LIndex].Action := HealthActionReregister;
      Result[LIndex].ActionTarget := LIssue.Message;
    end;
  end;
end;

class function TBoss4DGUIHealthPresenter.BuildRows(
  const AReport: TBoss4DDoctorReport): TArray<TBoss4DGUIHealthRow>;
begin
  if not Assigned(AReport) then
    Exit(nil);
  SetLength(Result, AReport.Items.Count);
  for var I := 0 to AReport.Items.Count - 1 do
  begin
    Result[I] := Default(TBoss4DGUIHealthRow);
    Result[I].Group := AReport.Items[I].Group;
    Result[I].Code := AReport.Items[I].Code;
    Result[I].Message := AReport.Items[I].Message;
    Result[I].Remediation := AReport.Items[I].Remediation;
    Result[I].Fixable := AReport.Items[I].Fixable;
    Result[I].Fixed := AReport.Items[I].Fixed;
    case AReport.Items[I].Health of
      HealthOk:
        if AReport.Items[I].Fixed then
          Result[I].Status := 'Corrigido'
        else
          Result[I].Status := 'Saudavel';
      HealthWarning: Result[I].Status := 'Aviso';
      HealthError: Result[I].Status := 'Erro';
    end;
  end;
end;

class function TBoss4DGUIHealthPresenter.Summarize(
  const AReport: TBoss4DDoctorReport): TBoss4DGUIHealthSummary;
begin
  Result := Default(TBoss4DGUIHealthSummary);
  if not Assigned(AReport) then
    Exit;
  for var LItem in AReport.Items do
  begin
    case LItem.Health of
      HealthOk: Inc(Result.Healthy);
      HealthWarning: Inc(Result.Warnings);
      HealthError: Inc(Result.Errors);
    end;
    if LItem.Fixed then
      Inc(Result.Fixed);
  end;
end;

end.
