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
  end;

implementation

uses
  System.SysUtils,
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

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUITargetProgressTests);

end.
