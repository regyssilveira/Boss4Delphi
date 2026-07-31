unit Boss4D.Tests.RegistryHealth;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsRegistryHealth = class
  private
    FRoot: string;
    procedure WriteRegistryFile(const AName, AContent: string);
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestMixedCatalogReportsLegacyAndTrustedPackages;
    [Test] procedure TestDuplicatePackageFailsHealthAudit;
    [Test] procedure TestMissingSparseFileFailsHealthAudit;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Services.RegistryHealth;

procedure TTestsRegistryHealth.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_registry_health_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(TPath.Combine(FRoot, 'registry\packages'));
  WriteRegistryFile('publishers.json',
    '{"schemaVersion":1,"publishers":[{"id":"demo",' +
    '"repositories":["github.com/demo/"],"allowedSigners":["' +
    StringOfChar('A', 40) + '"]}]}');
end;

procedure TTestsRegistryHealth.TearDown;
begin
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TTestsRegistryHealth.WriteRegistryFile(
  const AName, AContent: string);
begin
  TFile.WriteAllText(TPath.Combine(FRoot, 'registry\' + AName),
    AContent, TEncoding.UTF8);
end;

procedure TTestsRegistryHealth.TestMixedCatalogReportsLegacyAndTrustedPackages;
var
  LService: TBoss4DRegistryHealthService;
  LResult: TBoss4DRegistryHealthResult;
begin
  WriteRegistryFile('index-v2.json',
    '{"schemaVersion":2,"includes":["index-v1.json"],' +
    '"sparse":["packages/secure.json"],"packages":[]}');
  WriteRegistryFile('index-v1.json',
    '{"schemaVersion":1,"packages":[{"name":"Legacy",' +
    '"repository":"github.com/demo/legacy"}]}');
  WriteRegistryFile('packages\secure.json',
    '{"schemaVersion":2,"packages":[{"name":"Secure",' +
    '"publisher":"demo","repository":"github.com/demo/secure",' +
    '"signerFingerprint":"' + StringOfChar('A', 40) +
    '","versions":[{"version":"1.0.0"}]}]}');
  LService := TBoss4DRegistryHealthService.Create;
  try
    LResult := LService.Audit(FRoot);
  finally
    LService.Free;
  end;
  Assert.IsTrue(LResult.Passed);
  Assert.AreEqual(2, LResult.PackageCount);
  Assert.AreEqual(1, LResult.LegacyPackageCount);
  Assert.AreEqual(1, LResult.TrustedPackageCount);
  Assert.AreEqual(2, LResult.WarningCount);
end;

procedure TTestsRegistryHealth.TestDuplicatePackageFailsHealthAudit;
var
  LService: TBoss4DRegistryHealthService;
  LResult: TBoss4DRegistryHealthResult;
begin
  WriteRegistryFile('index-v2.json',
    '{"schemaVersion":2,"includes":["index-v1.json"],' +
    '"sparse":[],"packages":[{"name":"Demo",' +
    '"publisher":"demo","repository":"github.com/demo/main",' +
    '"signerFingerprint":"' + StringOfChar('A', 40) +
    '","versions":[{"version":"1.0.0"}]}]}');
  WriteRegistryFile('index-v1.json',
    '{"schemaVersion":1,"packages":[{"name":"demo",' +
    '"repository":"github.com/demo/legacy"}]}');
  LService := TBoss4DRegistryHealthService.Create;
  try
    LResult := LService.Audit(FRoot);
  finally
    LService.Free;
  end;
  Assert.IsFalse(LResult.Passed);
  Assert.AreEqual(1, LResult.ErrorCount);
end;

procedure TTestsRegistryHealth.TestMissingSparseFileFailsHealthAudit;
var
  LService: TBoss4DRegistryHealthService;
  LResult: TBoss4DRegistryHealthResult;
begin
  WriteRegistryFile('index-v2.json',
    '{"schemaVersion":2,"includes":[],' +
    '"sparse":["packages/missing.json"],"packages":[]}');
  LService := TBoss4DRegistryHealthService.Create;
  try
    LResult := LService.Audit(FRoot);
  finally
    LService.Free;
  end;
  Assert.IsFalse(LResult.Passed);
  Assert.AreEqual(1, LResult.ErrorCount);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsRegistryHealth);

end.
