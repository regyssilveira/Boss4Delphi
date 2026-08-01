unit Boss4D.Tests.GUI.ProcessWindows;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DGUIWindowsProcessRunnerTests = class
  public
    [Test] procedure CapturesSuccessfulProcessOutput;
    [Test] procedure CancelsRunningProcess;
  end;

implementation

uses
  System.IOUtils,
  Boss4D.GUI.Process.Windows;

procedure TBoss4DGUIWindowsProcessRunnerTests.CapturesSuccessfulProcessOutput;
var
  LRunner: TBoss4DGUIWindowsProcessRunner;
  LOutput: string;
  LCancelled: Boolean;
begin
  LRunner := TBoss4DGUIWindowsProcessRunner.Create;
  try
    Assert.IsTrue(LRunner.Execute('cmd.exe /d /c echo gui-runner',
      TDirectory.GetCurrentDirectory, nil, LOutput, LCancelled));
    Assert.IsFalse(LCancelled);
    Assert.AreEqual('gui-runner', LOutput);
  finally
    LRunner.Free;
  end;
end;

procedure TBoss4DGUIWindowsProcessRunnerTests.CancelsRunningProcess;
var
  LRunner: TBoss4DGUIWindowsProcessRunner;
  LOutput: string;
  LCancelled: Boolean;
begin
  LRunner := TBoss4DGUIWindowsProcessRunner.Create;
  try
    Assert.IsFalse(LRunner.Execute(
      'powershell.exe -NoProfile -Command Start-Sleep -Seconds 20',
      TDirectory.GetCurrentDirectory,
      function: Boolean
      begin
        Result := True;
      end,
      LOutput, LCancelled));
    Assert.IsTrue(LCancelled);
  finally
    LRunner.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUIWindowsProcessRunnerTests);

end.
