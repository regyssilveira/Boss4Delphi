unit Boss4D.Tests.GUI.HealthPresenter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DGUIHealthPresenterTests = class
  public
    [Test] procedure GroupsHealthRowsAndPreservesRemediation;
    [Test] procedure SummarizesHealthAndAppliedFixes;
  end;

implementation

uses
  Boss4D.Core.Services.Doctor,
  Boss4D.GUI.Health.Presenter;

function AddItem(const AReport: TBoss4DDoctorReport; const ACode,
  AGroup: string; const AHealth: TBoss4DEnvironmentHealth;
  const ARemediation: string; const AFixed: Boolean = False):
  TBoss4DDoctorItem;
begin
  Result := TBoss4DDoctorItem.Create;
  Result.Code := ACode;
  Result.Group := AGroup;
  Result.Health := AHealth;
  Result.Message := ACode + ' message';
  Result.Remediation := ARemediation;
  Result.Fixed := AFixed;
  AReport.Items.Add(Result);
end;

procedure TBoss4DGUIHealthPresenterTests.GroupsHealthRowsAndPreservesRemediation;
begin
  var LReport := TBoss4DDoctorReport.Create;
  try
    AddItem(LReport, 'GIT', 'Ferramentas', HealthError, 'Instale o Git');
    var LRows := TBoss4DGUIHealthPresenter.BuildRows(LReport);
    Assert.AreEqual<Integer>(1, Length(LRows));
    Assert.AreEqual('Ferramentas', LRows[0].Group);
    Assert.AreEqual('Erro', LRows[0].Status);
    Assert.AreEqual('Instale o Git', LRows[0].Remediation);
  finally
    LReport.Free;
  end;
end;

procedure TBoss4DGUIHealthPresenterTests.SummarizesHealthAndAppliedFixes;
begin
  var LReport := TBoss4DDoctorReport.Create;
  try
    AddItem(LReport, 'OK', 'Delphi', HealthOk, '');
    AddItem(LReport, 'FIX', 'Configuracao', HealthOk, '', True);
    AddItem(LReport, 'WARN', 'Delphi', HealthWarning, 'Repare');
    AddItem(LReport, 'ERR', 'Ferramentas', HealthError, 'Instale');
    var LSummary := TBoss4DGUIHealthPresenter.Summarize(LReport);
    Assert.AreEqual<Integer>(2, LSummary.Healthy);
    Assert.AreEqual<Integer>(1, LSummary.Warnings);
    Assert.AreEqual<Integer>(1, LSummary.Errors);
    Assert.AreEqual<Integer>(1, LSummary.Fixed);
    Assert.AreEqual(
      '2 saudavel(is), 1 aviso(s), 1 erro(s), 1 corrigido(s)',
      LSummary.Text);
  finally
    LReport.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUIHealthPresenterTests);

end.
