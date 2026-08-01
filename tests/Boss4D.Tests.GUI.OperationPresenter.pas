unit Boss4D.Tests.GUI.OperationPresenter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DGUIOperationPresenterTests = class
  public
    [Test] procedure TracksRunningAndCompletedElapsedTime;
    [Test] procedure FailedOperationCanRetry;
    [Test] procedure CancelledOperationCanRetry;
    [Test] procedure RejectsConcurrentStart;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.GUI.Operation.Presenter;

procedure TBoss4DGUIOperationPresenterTests.TracksRunningAndCompletedElapsedTime;
begin
  var LPresenter := TBoss4DGUIOperationPresenter.Create;
  try
    LPresenter.Start(1000);
    Assert.IsTrue(LPresenter.CanCancel);
    Assert.AreEqual('0:02', LPresenter.ElapsedText(3500));
    LPresenter.Complete(62000);
    Assert.AreEqual(GUISucceeded, LPresenter.State);
    Assert.AreEqual('1:01', LPresenter.ElapsedText(90000));
  finally
    LPresenter.Free;
  end;
end;

procedure TBoss4DGUIOperationPresenterTests.FailedOperationCanRetry;
begin
  var LPresenter := TBoss4DGUIOperationPresenter.Create;
  try
    LPresenter.Start(10);
    LPresenter.Fail('network', 20);
    Assert.IsTrue(LPresenter.CanRetry);
    Assert.AreEqual('network', LPresenter.ErrorMessage);
    LPresenter.Start(30);
    Assert.AreEqual<Integer>(2, LPresenter.Attempt);
    Assert.AreEqual(GUIRunning, LPresenter.State);
  finally
    LPresenter.Free;
  end;
end;

procedure TBoss4DGUIOperationPresenterTests.CancelledOperationCanRetry;
begin
  var LPresenter := TBoss4DGUIOperationPresenter.Create;
  try
    LPresenter.Start(10);
    LPresenter.Cancel(20);
    Assert.AreEqual(GUICancelled, LPresenter.State);
    Assert.IsTrue(LPresenter.CanRetry);
  finally
    LPresenter.Free;
  end;
end;

procedure TBoss4DGUIOperationPresenterTests.RejectsConcurrentStart;
var
  LPresenter: TBoss4DGUIOperationPresenter;
begin
  LPresenter := TBoss4DGUIOperationPresenter.Create;
  try
    LPresenter.Start(10);
    Assert.WillRaise(
      procedure
      begin
        LPresenter.Start(20);
      end,
      EInvalidOpException);
  finally
    LPresenter.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUIOperationPresenterTests);

end.
