unit Boss4D.Tests.Conformance;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DConformanceTests = class
  public
    [Test] procedure AcceptsRegistryV1;
    [Test] procedure AcceptsComposableRegistryV2;
    [Test] procedure RejectsUnsafeRegistryV2Include;
    [Test] procedure RejectsPartialRegistryV2Release;
    [Test] procedure RejectsPartialArtifactMetadata;
    [Test] procedure RejectsDuplicateRegistryEntries;
    [Test] procedure AcceptsGeneratedPackage;
    [Test] procedure RejectsTamperedPackage;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Services.Conformance, Boss4D.Core.Services.Pack;

procedure TBoss4DConformanceTests.AcceptsRegistryV1;
var
  LService: TBoss4DConformanceService;
begin
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsTrue(LService.ValidateRegistryContent(
      '{"schemaVersion":1,"packages":[{"name":"demo",' +
      '"repository":"github.com/example/demo"}]}').Passed);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DConformanceTests.AcceptsComposableRegistryV2;
var
  LService: TBoss4DConformanceService;
begin
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsTrue(LService.ValidateRegistryContent(
      '{"schemaVersion":2,"includes":["community/index-v1.json"],' +
      '"packages":[{"name":"demo","repository":"github.com/example/demo",' +
      '"versions":[{"version":"2.0.0","artifact":"demo.b4dpkg",' +
      '"sha256":"abc"}]}]}').Passed);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DConformanceTests.RejectsUnsafeRegistryV2Include;
var
  LService: TBoss4DConformanceService;
begin
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsFalse(LService.ValidateRegistryContent(
      '{"schemaVersion":2,"includes":["../private.json"],"packages":[]}')
      .Passed);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DConformanceTests.RejectsPartialRegistryV2Release;
var
  LService: TBoss4DConformanceService;
begin
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsFalse(LService.ValidateRegistryContent(
      '{"schemaVersion":2,"packages":[{"name":"demo",' +
      '"repository":"github.com/example/demo","versions":[' +
      '{"version":"2.0.0","artifact":"demo.b4dpkg"}]}]}').Passed);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DConformanceTests.RejectsPartialArtifactMetadata;
var
  LService: TBoss4DConformanceService;
begin
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsFalse(LService.ValidateRegistryContent(
      '{"schemaVersion":1,"packages":[{"name":"demo",' +
      '"repository":"github.com/example/demo","artifact":"demo.b4dpkg"}]}')
      .Passed);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DConformanceTests.RejectsDuplicateRegistryEntries;
var
  LService: TBoss4DConformanceService;
begin
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsFalse(LService.ValidateRegistryContent(
      '{"schemaVersion":1,"packages":[' +
      '{"name":"demo","repository":"github.com/example/demo"},' +
      '{"name":"DEMO","repository":"github.com/example/other"}]}').Passed);
    Assert.IsFalse(LService.ValidateRegistryContent(
      '{"schemaVersion":1,"packages":[' +
      '{"name":"demo","repository":"github.com/example/demo"},' +
      '{"name":"other","repository":"GITHUB.COM/EXAMPLE/DEMO"}]}').Passed);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DConformanceTests.AcceptsGeneratedPackage;
var
  LRoot, LOutput: string;
  LPack: TBoss4DPackService;
  LService: TBoss4DConformanceService;
begin
  LRoot := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LOutput := TPath.Combine(TPath.GetTempPath,
    TPath.GetRandomFileName + '.b4dpkg');
  TDirectory.CreateDirectory(LRoot);
  TFile.WriteAllText(TPath.Combine(LRoot, 'boss.json'), '{}');
  LPack := TBoss4DPackService.Create;
  LService := TBoss4DConformanceService.Create;
  try
    LPack.Execute(LRoot, LOutput);
    Assert.IsTrue(LService.ValidatePackageFile(LOutput).Passed);
  finally
    LService.Free;
    LPack.Free;
    TDirectory.Delete(LRoot, True);
    TFile.Delete(LOutput);
    TFile.Delete(LOutput + '.intoto.json');
  end;
end;

procedure TBoss4DConformanceTests.RejectsTamperedPackage;
var
  LPath: string;
  LService: TBoss4DConformanceService;
begin
  LPath := TPath.Combine(TPath.GetTempPath,
    TPath.GetRandomFileName + '.b4dpkg');
  TFile.WriteAllText(LPath, '{"format":"boss4d-package",' +
    '"schemaVersion":1,"files":[{"path":"demo.pas","sha256":"' +
    StringOfChar('0', 64) + '","content":"dGFtcGVyZWQ="}]}');
  LService := TBoss4DConformanceService.Create;
  try
    Assert.IsFalse(LService.ValidatePackageFile(LPath).Passed);
  finally
    LService.Free;
    TFile.Delete(LPath);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DConformanceTests);

end.
