unit Boss4D.Tests.PackageInstall;

interface

uses
  DUnitX.TestFramework, Boss4D.Core.Ports;

type
  TPackageVerifierMock = class(TInterfacedObject, IBoss4DPackageSigner)
  private
    FValid: Boolean;
  public
    constructor Create(const AValid: Boolean);
    function Sign(const AArtifactPath, AKeyId: string): string;
    function Verify(const AArtifactPath, ASignaturePath: string): Boolean;
  end;

  [TestFixture]
  TBoss4DPackageInstallTests = class
  public
    [Test] procedure InstallsVerifiedArtifactTransactionally;
    [Test] procedure RejectsDigestMismatchWithoutReplacingTarget;
    [Test] procedure RejectsInvalidSignature;
    [Test] procedure UsesMirrorOnlyWhenDigestMatches;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Tests.Mocks, Boss4D.Core.Services.Pack,
  Boss4D.Core.Services.PackageInstall;

constructor TPackageVerifierMock.Create(const AValid: Boolean);
begin
  inherited Create;
  FValid := AValid;
end;

function TPackageVerifierMock.Sign(const AArtifactPath,
  AKeyId: string): string;
begin
  Result := AArtifactPath + '.asc';
end;

function TPackageVerifierMock.Verify(const AArtifactPath,
  ASignaturePath: string): Boolean;
begin
  Result := FValid;
end;

procedure CreatePackedFixture(out ARoot, AArtifact: string;
  out AResult: TBoss4DPackResult);
begin
  ARoot := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  AArtifact := TPath.Combine(TPath.GetTempPath,
    TPath.GetRandomFileName + '.b4dpkg');
  TDirectory.CreateDirectory(ARoot);
  TFile.WriteAllText(TPath.Combine(ARoot, 'boss.json'),
    '{"name":"verified","version":"1.0.0","dependencies":{}}');
  TFile.WriteAllText(TPath.Combine(ARoot, 'verified.pas'), 'unit verified;');
  var LPack := TBoss4DPackService.Create;
  try
    AResult := LPack.Execute(ARoot, AArtifact);
  finally
    LPack.Free;
  end;
end;

procedure DeletePackedFixture(const ARoot, AArtifact: string);
begin
  if TDirectory.Exists(ARoot) then TDirectory.Delete(ARoot, True);
  if TFile.Exists(AArtifact) then TFile.Delete(AArtifact);
  if TFile.Exists(AArtifact + '.intoto.json') then
    TFile.Delete(AArtifact + '.intoto.json');
end;

procedure TBoss4DPackageInstallTests.InstallsVerifiedArtifactTransactionally;
const
  ARTIFACT_URL = 'https://packages.example/verified.b4dpkg';
  SIGNATURE_URL = ARTIFACT_URL + '.asc';
  PROVENANCE_URL = ARTIFACT_URL + '.intoto.json';
var
  LRoot, LArtifact, LTarget: string;
  LPackResult: TBoss4DPackResult;
  LHttp: THttpClientMock;
  LService: TBoss4DPackageInstallService;
  LRequest: TBoss4DPackageInstallRequest;
begin
  CreatePackedFixture(LRoot, LArtifact, LPackResult);
  LTarget := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(ARTIFACT_URL, TFile.ReadAllText(LArtifact), 200);
  LHttp.AddResponse(SIGNATURE_URL, 'signature', 200);
  LHttp.AddResponse(PROVENANCE_URL,
    TFile.ReadAllText(LPackResult.ProvenancePath), 200);
  LService := TBoss4DPackageInstallService.Create(LHttp,
    TPackageVerifierMock.Create(True));
  try
    LRequest := Default(TBoss4DPackageInstallRequest);
    LRequest.PackageName := 'verified';
    LRequest.Version := '1.0.0';
    LRequest.Platform := 'Win64';
    LRequest.Compiler := '37.0';
    LRequest.ArtifactUrl := ARTIFACT_URL;
    LRequest.Sha256 := LPackResult.Digest;
    LRequest.SignatureUrl := SIGNATURE_URL;
    LRequest.ProvenanceUrl := PROVENANCE_URL;
    LRequest.TargetDirectory := LTarget;
    var LResult := LService.Execute(LRequest);
    Assert.IsTrue(LResult.Installed);
    Assert.AreEqual<Integer>(2, LResult.FileCount);
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'boss.json')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'verified.pas')));
    var LReceipt := TFile.ReadAllText(TPath.Combine(LTarget,
      '.boss4d-package.json'), TEncoding.UTF8);
    Assert.IsTrue(LReceipt.Contains('"version": "1.0.0"'));
    Assert.IsTrue(LReceipt.Contains('"platform": "Win64"'));
    Assert.IsTrue(LReceipt.Contains('"compiler": "37.0"'));
    Assert.IsTrue(LReceipt.Contains(LPackResult.Digest));
    Assert.IsTrue(LReceipt.Contains('"signatureVerified": true'));
    Assert.IsTrue(LReceipt.Contains('"provenanceVerified": true'));
  finally
    LService.Free;
    if TDirectory.Exists(LTarget) then TDirectory.Delete(LTarget, True);
    DeletePackedFixture(LRoot, LArtifact);
  end;
end;

procedure TBoss4DPackageInstallTests.RejectsDigestMismatchWithoutReplacingTarget;
const
  ARTIFACT_URL = 'https://packages.example/tampered.b4dpkg';
var
  LRoot, LArtifact, LTarget: string;
  LPackResult: TBoss4DPackResult;
  LHttp: THttpClientMock;
  LService: TBoss4DPackageInstallService;
  LRequest: TBoss4DPackageInstallRequest;
begin
  CreatePackedFixture(LRoot, LArtifact, LPackResult);
  LTarget := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  TDirectory.CreateDirectory(LTarget);
  TFile.WriteAllText(TPath.Combine(LTarget, 'keep.txt'), 'keep');
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(ARTIFACT_URL, TFile.ReadAllText(LArtifact), 200);
  LService := TBoss4DPackageInstallService.Create(LHttp);
  try
    LRequest := Default(TBoss4DPackageInstallRequest);
    LRequest.ArtifactUrl := ARTIFACT_URL;
    LRequest.Sha256 := StringOfChar('0', 64);
    LRequest.TargetDirectory := LTarget;
    Assert.WillRaise(
      procedure begin LService.Execute(LRequest); end, Exception);
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'keep.txt')));
  finally
    LService.Free;
    TDirectory.Delete(LTarget, True);
    DeletePackedFixture(LRoot, LArtifact);
  end;
end;

procedure TBoss4DPackageInstallTests.RejectsInvalidSignature;
const
  ARTIFACT_URL = 'https://packages.example/unsigned.b4dpkg';
var
  LRoot, LArtifact, LTarget: string;
  LPackResult: TBoss4DPackResult;
  LHttp: THttpClientMock;
  LService: TBoss4DPackageInstallService;
  LRequest: TBoss4DPackageInstallRequest;
begin
  CreatePackedFixture(LRoot, LArtifact, LPackResult);
  LTarget := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(ARTIFACT_URL, TFile.ReadAllText(LArtifact), 200);
  LHttp.AddResponse(ARTIFACT_URL + '.asc', 'invalid', 200);
  LService := TBoss4DPackageInstallService.Create(LHttp,
    TPackageVerifierMock.Create(False));
  try
    LRequest := Default(TBoss4DPackageInstallRequest);
    LRequest.ArtifactUrl := ARTIFACT_URL;
    LRequest.Sha256 := LPackResult.Digest;
    LRequest.SignatureUrl := ARTIFACT_URL + '.asc';
    LRequest.TargetDirectory := LTarget;
    Assert.WillRaise(
      procedure begin LService.Execute(LRequest); end, Exception);
    Assert.IsFalse(TDirectory.Exists(LTarget));
  finally
    LService.Free;
    DeletePackedFixture(LRoot, LArtifact);
  end;
end;

procedure TBoss4DPackageInstallTests.UsesMirrorOnlyWhenDigestMatches;
const
  PRIMARY_URL = 'https://primary.example/package.b4dpkg';
  MIRROR_URL = 'https://mirror.example/package.b4dpkg';
var
  LRoot, LArtifact, LTarget: string;
  LPackResult: TBoss4DPackResult;
  LHttp: THttpClientMock;
  LService: TBoss4DPackageInstallService;
  LRequest: TBoss4DPackageInstallRequest;
begin
  CreatePackedFixture(LRoot, LArtifact, LPackResult);
  LTarget := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LHttp := THttpClientMock.Create;
  LHttp.AddResponse(PRIMARY_URL, 'tampered', 200);
  LHttp.AddResponse(MIRROR_URL, TFile.ReadAllText(LArtifact), 200);
  LService := TBoss4DPackageInstallService.Create(LHttp);
  try
    LRequest := Default(TBoss4DPackageInstallRequest);
    LRequest.ArtifactUrl := PRIMARY_URL;
    LRequest.ArtifactMirrors := TArray<string>.Create(MIRROR_URL);
    LRequest.Sha256 := LPackResult.Digest;
    LRequest.TargetDirectory := LTarget;
    Assert.IsTrue(LService.Execute(LRequest).Installed);
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'verified.pas')));
  finally
    LService.Free;
    if TDirectory.Exists(LTarget) then TDirectory.Delete(LTarget, True);
    DeletePackedFixture(LRoot, LArtifact);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DPackageInstallTests);

end.
