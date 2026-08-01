unit Boss4D.Tests.GUI.TargetProgress;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DGUITargetProgressTests = class
  public
    [Test]
    procedure MapsDeterminateCompletedTarget;
    [Test]
    procedure MapsFailureForStructuredLogging;
    [Test]
    procedure RejectsInvalidProgressRange;
    [Test]
    procedure ReporterForwardsCoreProgressEvent;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.Core.Domain.Progress,
  Boss4D.Core.Services.BuildExecutor,
  Boss4D.GUI.TargetProgress;

procedure TBoss4DGUITargetProgressTests.MapsDeterminateCompletedTarget;
begin
  var LEvent := TBoss4DBuildTargetProgressEvent.Create(
    'HorseDesign|37.0|Win64|Release', TargetBuilt, 2, 4,
    'target compilado');
  var LRow := TBoss4DGUITargetProgress.FromBuildEvent(LEvent);
  Assert.AreEqual('HorseDesign|37.0|Win64|Release',
    LRow.TargetIdentity);
  Assert.AreEqual('compilado', LRow.State);
  Assert.AreEqual<Integer>(50, LRow.Percentage);
  Assert.IsFalse(LRow.IsFailure);
end;

procedure TBoss4DGUITargetProgressTests.MapsFailureForStructuredLogging;
begin
  var LEvent := TBoss4DBuildTargetProgressEvent.Create(
    'HorseDesign|37.0|Win32|Release', TargetFailed, 1, 1,
    'dcc32 retornou erro');
  var LRow := TBoss4DGUITargetProgress.FromBuildEvent(LEvent);
  Assert.AreEqual('falhou', LRow.State);
  Assert.AreEqual<Integer>(100, LRow.Percentage);
  Assert.IsTrue(LRow.IsFailure);
  Assert.AreEqual('dcc32 retornou erro', LRow.Message);
end;

procedure TBoss4DGUITargetProgressTests.RejectsInvalidProgressRange;
var
  LEvent: TBoss4DBuildTargetProgressEvent;
begin
  LEvent := TBoss4DBuildTargetProgressEvent.Create(
    'target', TargetStarted, 2, 1, '');
  Assert.WillRaise(
    procedure
    begin
      TBoss4DGUITargetProgress.FromBuildEvent(LEvent);
    end,
    EArgumentOutOfRangeException);
end;

procedure TBoss4DGUITargetProgressTests.ReporterForwardsCoreProgressEvent;
var
  LReceived: TBoss4DProgressEvent;
  LReporter: IBoss4DProgressReporter;
begin
  LReceived := Default(TBoss4DProgressEvent);
  LReporter := TBoss4DGUIProgressReporter.Create(
    procedure(const AEvent: TBoss4DProgressEvent)
    begin
      LReceived := AEvent;
    end);
  LReporter.Report(TBoss4DProgressEvent.Create(
    'install-1', 'horse', TBoss4DProgressPhase.Compiling,
    3, 5, 'HorseDesign.dproj'));
  Assert.AreEqual('horse', LReceived.PackageName);
  Assert.AreEqual(TBoss4DProgressPhase.Compiling, LReceived.Phase);
  Assert.AreEqual<Integer>(3, LReceived.Current);
  Assert.AreEqual<Integer>(5, LReceived.Total);
  Assert.AreEqual('HorseDesign.dproj', LReceived.Message);
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUITargetProgressTests);

end.
