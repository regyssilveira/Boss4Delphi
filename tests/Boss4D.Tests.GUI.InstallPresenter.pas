unit Boss4D.Tests.GUI.InstallPresenter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DGUIInstallPresenterTests = class
  public
    [Test] procedure BuildsExactVerifiedPackageCommand;
    [Test] procedure IncludesSourceFallbackByDefault;
    [Test] procedure RejectsIncompleteSelection;
    [Test] procedure ExecutorRunsEquivalentCommandInProject;
    [Test] procedure ExecutorReportsCommandFailure;
    [Test] procedure ExecutorReturnsCancellationWithoutFailure;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.GUI.Install.Presenter;

type
  TProcessRunnerMock = class(TInterfacedObject,
    IBoss4DGUICancellableProcessRunner)
  public
    ShouldSucceed: Boolean;
    ShouldCancel: Boolean;
    CommandLine: string;
    WorkingDirectory: string;
    function Execute(const ACommandLine, AWorkingDirectory: string;
      const ACancellation: TBoss4DGUICancellationProbe;
      out AOutput: string; out ACancelled: Boolean): Boolean;
  end;

function TProcessRunnerMock.Execute(const ACommandLine,
  AWorkingDirectory: string; const ACancellation: TBoss4DGUICancellationProbe;
  out AOutput: string; out ACancelled: Boolean): Boolean;
begin
  CommandLine := ACommandLine;
  WorkingDirectory := AWorkingDirectory;
  AOutput := 'output';
  ACancelled := ShouldCancel;
  Result := ShouldSucceed;
end;

function CompleteRequest: TBoss4DGUIInstallRequest;
begin
  Result := Default(TBoss4DGUIInstallRequest);
  Result.PackageName := 'Horse';
  Result.Version := '3.2.1';
  Result.Compiler := 'd13';
  Result.Platform := 'Win64';
  Result.AllowSourceFallback := True;
end;

procedure TBoss4DGUIInstallPresenterTests.BuildsExactVerifiedPackageCommand;
begin
  var LRequest := CompleteRequest;
  LRequest.AllowSourceFallback := False;
  Assert.AreEqual(
    'boss4d package install "Horse@3.2.1" --compiler "d13" ' +
    '--platform "Win64" --no-source-fallback',
    TBoss4DGUIInstallPresenter.BuildEquivalentCommand(LRequest));
end;

procedure TBoss4DGUIInstallPresenterTests.IncludesSourceFallbackByDefault;
begin
  Assert.AreEqual(
    'package install "Horse@3.2.1" --compiler "d13" --platform "Win64"',
    TBoss4DGUIInstallPresenter.BuildArguments(CompleteRequest));
end;

procedure TBoss4DGUIInstallPresenterTests.RejectsIncompleteSelection;
var
  LRequest: TBoss4DGUIInstallRequest;
begin
  LRequest := CompleteRequest;
  LRequest.Version := '';
  Assert.WillRaise(
    procedure
    begin
      TBoss4DGUIInstallPresenter.Validate(LRequest);
    end,
    EArgumentException);
end;

procedure TBoss4DGUIInstallPresenterTests.ExecutorRunsEquivalentCommandInProject;
var
  LCancelled: Boolean;
begin
  var LMock := TProcessRunnerMock.Create;
  LMock.ShouldSucceed := True;
  var LExecutor := TBoss4DGUIInstallExecutor.Create(LMock);
  try
    Assert.AreEqual('output',
      LExecutor.Execute('C:\Boss4D\boss4d.exe', 'C:\Project',
        CompleteRequest, nil, LCancelled));
    Assert.IsFalse(LCancelled);
    Assert.AreEqual(
      '"C:\Boss4D\boss4d.exe" package install "Horse@3.2.1" ' +
      '--compiler "d13" --platform "Win64"', LMock.CommandLine);
    Assert.AreEqual('C:\Project', LMock.WorkingDirectory);
  finally
    LExecutor.Free;
  end;
end;

procedure TBoss4DGUIInstallPresenterTests.ExecutorReportsCommandFailure;
var
  LMock: TProcessRunnerMock;
  LExecutor: TBoss4DGUIInstallExecutor;
  LCancelled: Boolean;
begin
  LMock := TProcessRunnerMock.Create;
  LMock.ShouldSucceed := False;
  LExecutor := TBoss4DGUIInstallExecutor.Create(LMock);
  try
    Assert.WillRaise(
      procedure
      begin
        LExecutor.Execute('boss4d.exe', 'C:\Project', CompleteRequest,
          nil, LCancelled);
      end,
      Exception);
  finally
    LExecutor.Free;
  end;
end;

procedure TBoss4DGUIInstallPresenterTests.ExecutorReturnsCancellationWithoutFailure;
var
  LMock: TProcessRunnerMock;
  LExecutor: TBoss4DGUIInstallExecutor;
  LCancelled: Boolean;
begin
  LMock := TProcessRunnerMock.Create;
  LMock.ShouldCancel := True;
  LExecutor := TBoss4DGUIInstallExecutor.Create(LMock);
  try
    Assert.AreEqual('output',
      LExecutor.Execute('boss4d.exe', 'C:\Project', CompleteRequest,
        nil, LCancelled));
    Assert.IsTrue(LCancelled);
  finally
    LExecutor.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUIInstallPresenterTests);

end.
