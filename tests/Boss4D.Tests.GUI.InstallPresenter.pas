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
  end;

implementation

uses
  System.SysUtils,
  Boss4D.GUI.Install.Presenter;

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
begin
  var LRequest := CompleteRequest;
  LRequest.Version := '';
  Assert.WillRaise(
    procedure
    begin
      TBoss4DGUIInstallPresenter.Validate(LRequest);
    end,
    EArgumentException);
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUIInstallPresenterTests);

end.
