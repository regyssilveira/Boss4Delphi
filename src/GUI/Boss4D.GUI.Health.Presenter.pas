unit Boss4D.GUI.Health.Presenter;

interface

uses
  Boss4D.Core.Services.Doctor;

type
  TBoss4DGUIHealthRow = record
    Group: string;
    Status: string;
    Code: string;
    Message: string;
    Remediation: string;
    Fixable: Boolean;
    Fixed: Boolean;
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
  end;

implementation

uses
  System.SysUtils;

function TBoss4DGUIHealthSummary.Text: string;
begin
  Result := Format('%d saudavel(is), %d aviso(s), %d erro(s)',
    [Healthy, Warnings, Errors]);
  if Fixed > 0 then
    Result := Result + Format(', %d corrigido(s)', [Fixed]);
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
