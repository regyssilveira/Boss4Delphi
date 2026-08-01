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
    [Test] procedure AddsHealthyBuildWithRebuildAction;
    [Test] procedure MapsRegistryDriftToExactReregisterAction;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.Core.Services.Doctor,
  Boss4D.Core.Services.BuildDoctor,
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

procedure TBoss4DGUIHealthPresenterTests.AddsHealthyBuildWithRebuildAction;
begin
  var LBuild := TBoss4DBuildDoctorResult.Create;
  try
    var LRows := TBoss4DGUIHealthPresenter.AppendBuildRows(nil, LBuild);
    Assert.AreEqual<Integer>(1, Length(LRows));
    Assert.AreEqual('Projeto/Build', LRows[0].Group);
    Assert.AreEqual('BUILD_READY', LRows[0].Code);
    Assert.AreEqual(HealthActionRebuild, LRows[0].Action);
    Assert.AreEqual('Rebuild completo', LRows[0].ActionLabel);
  finally
    LBuild.Free;
  end;
end;

procedure TBoss4DGUIHealthPresenterTests.
  MapsRegistryDriftToExactReregisterAction;
begin
  var LBuild := TBoss4DBuildDoctorResult.Create;
  try
    var LIssue := TBoss4DBuildDoctorIssue.Create;
    LIssue.Code := 'IDE_REGISTRY_DRIFT';
    LIssue.Severity := TBoss4DDoctorSeverity.Warning;
    LIssue.Message :=
      'Registro IDE divergente: HorseDesign|37.0|Win32|Release';
    LIssue.Remediation := 'Registre novamente o target.';
    LBuild.Issues.Add(LIssue);
    var LRows := TBoss4DGUIHealthPresenter.AppendBuildRows(nil, LBuild);
    Assert.AreEqual<Integer>(1, Length(LRows));
    Assert.AreEqual('Aviso', LRows[0].Status);
    Assert.AreEqual(HealthActionReregister, LRows[0].Action);
    Assert.AreEqual('Registrar novamente', LRows[0].ActionLabel);
    Assert.AreEqual('HorseDesign|37.0|Win32|Release',
      LRows[0].ActionTarget);
  finally
    LBuild.Free;
  end;
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
