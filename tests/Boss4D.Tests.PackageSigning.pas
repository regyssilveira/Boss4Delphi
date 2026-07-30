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
    [Test] procedure RejectsSigningFailure;
  end;

implementation

uses
  System.SysUtils, Boss4D.Adapters.Security.Gpg;

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

initialization
  TDUnitX.RegisterTestFixture(TBoss4DPackageSigningTests);

end.
