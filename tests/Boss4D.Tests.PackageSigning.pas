unit Boss4D.Tests.PackageSigning;

interface

uses
  DUnitX.TestFramework, Boss4D.Core.Ports;

type
  TSigningRunnerMock = class(TInterfacedObject, IBoss4DProcessRunner)
  private
    FCommand: string;
    FSucceed: Boolean;
  public
    constructor Create(const ASucceed: Boolean);
    function Execute(const ACommandLine, AWorkingDirectory: string;
      out AOutput: string): Boolean;
    property Command: string read FCommand;
  end;

  [TestFixture]
  TBoss4DPackageSigningTests = class
  public
    [Test] procedure BuildsDetachedSignatureCommand;
    [Test] procedure BuildsVerificationCommand;
    [Test] procedure UsesConfiguredGpgExecutable;
    [Test] procedure RejectsSigningFailure;
    [Test] procedure PreservesVerificationFailureDetails;
    [Test] procedure DiscoversNativeProgramFilesFromWin32Process;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows,
  Boss4D.Adapters.Security.Gpg;

constructor TSigningRunnerMock.Create(const ASucceed: Boolean);
begin
  inherited Create;
  FSucceed := ASucceed;
end;

function TSigningRunnerMock.Execute(const ACommandLine,
  AWorkingDirectory: string; out AOutput: string): Boolean;
begin
  FCommand := ACommandLine;
  AOutput := 'mock';
  Result := FSucceed;
end;

procedure TBoss4DPackageSigningTests.BuildsDetachedSignatureCommand;
var
  LRunner: TSigningRunnerMock;
  LSigner: IBoss4DPackageSigner;
begin
  LRunner := TSigningRunnerMock.Create(True);
  LSigner := TBoss4DGpgPackageSigner.Create(LRunner);
  Assert.IsTrue(LSigner.Sign('C:\pkg\demo.b4dpkg', 'release@example.com')
    .EndsWith('.asc'));
  Assert.IsTrue(LRunner.Command.Contains('--detach-sign'));
  Assert.IsTrue(LRunner.Command.Contains('release@example.com'));
end;

procedure TBoss4DPackageSigningTests.BuildsVerificationCommand;
var
  LRunner: TSigningRunnerMock;
  LSigner: IBoss4DPackageSigner;
begin
  LRunner := TSigningRunnerMock.Create(True);
  LSigner := TBoss4DGpgPackageSigner.Create(LRunner);
  Assert.IsTrue(LSigner.Verify('C:\pkg\demo.b4dpkg',
    'C:\pkg\demo.b4dpkg.asc'));
  Assert.IsTrue(LRunner.Command.Contains('--verify'));
end;

procedure TBoss4DPackageSigningTests.UsesConfiguredGpgExecutable;
var
  LRunner: TSigningRunnerMock;
  LSigner: IBoss4DPackageSigner;
begin
  LRunner := TSigningRunnerMock.Create(True);
  LSigner := TBoss4DGpgPackageSigner.Create(LRunner,
    'C:\Program Files\Git\usr\bin\gpg.exe');
  Assert.IsTrue(LSigner.Verify('C:\pkg\demo.b4dpkg',
    'C:\pkg\demo.b4dpkg.asc'));
  Assert.IsTrue(LRunner.Command.StartsWith(
    '"C:\Program Files\Git\usr\bin\gpg.exe" --batch'));
end;

procedure TBoss4DPackageSigningTests.RejectsSigningFailure;
var
  LSigner: IBoss4DPackageSigner;
begin
  LSigner := TBoss4DGpgPackageSigner.Create(
    TSigningRunnerMock.Create(False));
  Assert.WillRaise(
    procedure
    begin
      LSigner.Sign('C:\pkg\demo.b4dpkg', 'release@example.com');
    end, Exception);
end;

procedure TBoss4DPackageSigningTests.PreservesVerificationFailureDetails;
var
  LSigner: IBoss4DPackageSigner;
  LDetails: IBoss4DPackageVerificationDetails;
begin
  LSigner := TBoss4DGpgPackageSigner.Create(
    TSigningRunnerMock.Create(False));
  Assert.IsFalse(LSigner.Verify('C:\pkg\demo.b4dpkg',
    'C:\pkg\demo.b4dpkg.asc'));
  Assert.IsTrue(Supports(LSigner, IBoss4DPackageVerificationDetails,
    LDetails));
  Assert.AreEqual('mock', LDetails.LastVerificationError);
end;

procedure TBoss4DPackageSigningTests.DiscoversNativeProgramFilesFromWin32Process;
var
  LRoot, LGpgPath, LPreviousRoot, LPreviousOverride: string;
  LRunner: TSigningRunnerMock;
  LSigner: IBoss4DPackageSigner;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-gpg-discovery-' + TGUID.NewGuid.ToString);
  LGpgPath := TPath.Combine(LRoot, 'Git\usr\bin\gpg.exe');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(LGpgPath));
  TFile.WriteAllText(LGpgPath, '');
  LPreviousRoot := GetEnvironmentVariable('ProgramW6432');
  LPreviousOverride := GetEnvironmentVariable('BOSS4D_GPG');
  try
    Winapi.Windows.SetEnvironmentVariable('BOSS4D_GPG', '');
    Winapi.Windows.SetEnvironmentVariable('ProgramW6432', PChar(LRoot));
    LRunner := TSigningRunnerMock.Create(True);
    LSigner := TBoss4DGpgPackageSigner.Create(LRunner);
    Assert.IsTrue(LSigner.Verify('C:\pkg\demo.b4dpkg',
      'C:\pkg\demo.b4dpkg.asc'));
    Assert.IsTrue(LRunner.Command.StartsWith('"' + LGpgPath + '"'));
  finally
    Winapi.Windows.SetEnvironmentVariable(
      'ProgramW6432', PChar(LPreviousRoot));
    Winapi.Windows.SetEnvironmentVariable(
      'BOSS4D_GPG', PChar(LPreviousOverride));
    TDirectory.Delete(LRoot, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DPackageSigningTests);

end.
