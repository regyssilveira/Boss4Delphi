unit Boss4D.Tests.Json;

interface

uses
  DUnitX.TestFramework, Boss4D.Adapters.Json;

type
  [TestFixture]
  TTestsJson = class
  private
    FPackageRepo: TBoss4DPackageJsonRepository;
    FLockRepo: TBoss4DLockJsonRepository;
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestPackageSerialization;
    [Test]
    procedure TestLockSerialization;
    [Test]
    procedure TestLockV1BackwardCompatibility;
    [Test]
    procedure TestLockV2MetadataRoundTrip;
    [Test]
    procedure TestLockV2DeterministicSerialization;
    [Test]
    procedure TestLockV2RejectsFutureVersion;
    [Test]
    procedure TestLockV2SharedAndCircularGraph;
    [Test]
    procedure TestUTF8WithoutBOMSerialization;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Dependency;

{ TTestsJson }

procedure TTestsJson.Setup;
begin
  FPackageRepo := TBoss4DPackageJsonRepository.Create;
  FLockRepo := TBoss4DLockJsonRepository.Create;
  FTempDir := TPath.Combine(TPath.GetTempPath, 'Boss4DTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TTestsJson.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
  FLockRepo.Free;
  FPackageRepo.Free;
end;

procedure TTestsJson.TestPackageSerialization;
var
  LPkg, LLoadedPkg: TBoss4DPackage;
  LFilePath: string;
begin
  LFilePath := TPath.Combine(FTempDir, 'boss.json');
  LPkg := TBoss4DPackage.Create;
  try
    LPkg.Name := 'test-project';
    LPkg.Description := 'Projeto de Teste';
    LPkg.Version := '1.0.0';
    LPkg.Homepage := 'https://github.com/test/project';
    LPkg.AddProject('Source/Project1.dproj');
    LPkg.AddDependency('github.com/hashload/horse', '^3.0.0');
    LPkg.Scripts.Add('build', 'msbuild');
    LPkg.Engines.Compiler := '36.0';
    LPkg.Engines.Platforms.Add('Win32');
    var LManualComponent := TBoss4DManualComponent.Create;
    LManualComponent.Id := 'commercial-driver';
    LManualComponent.Name := 'Commercial Database Driver';
    LManualComponent.Version := '5.4';
    LManualComponent.ComponentType := 'library';
    LManualComponent.License := 'Commercial';
    LManualComponent.HashAlgorithm := 'SHA-256';
    LManualComponent.HashValue := 'manual-hash';
    LPkg.SbomComponents.Add(LManualComponent);

    FPackageRepo.Save(LPkg, LFilePath);
    Assert.IsTrue(TFile.Exists(LFilePath));

    LLoadedPkg := FPackageRepo.Load(LFilePath);
    try
      Assert.AreEqual(LPkg.Name, LLoadedPkg.Name);
      Assert.AreEqual(LPkg.Description, LLoadedPkg.Description);
      Assert.AreEqual(LPkg.Version, LLoadedPkg.Version);
      Assert.AreEqual(LPkg.Homepage, LLoadedPkg.Homepage);
      Assert.AreEqual<Integer>(1, LLoadedPkg.Projects.Count);
      Assert.AreEqual('Source/Project1.dproj', LLoadedPkg.Projects[0]);
      Assert.IsTrue(LLoadedPkg.Dependencies.ContainsKey('github.com/hashload/horse'));
      Assert.AreEqual<string>('^3.0.0', LLoadedPkg.Dependencies['github.com/hashload/horse']);
      Assert.AreEqual<string>('msbuild', LLoadedPkg.Scripts['build']);
      Assert.AreEqual('36.0', LLoadedPkg.Engines.Compiler);
      Assert.AreEqual('Win32', LLoadedPkg.Engines.Platforms[0]);
      Assert.AreEqual<Integer>(1, LLoadedPkg.SbomComponents.Count);
      Assert.AreEqual('commercial-driver', LLoadedPkg.SbomComponents[0].Id);
      Assert.AreEqual('Commercial', LLoadedPkg.SbomComponents[0].License);
      Assert.AreEqual('manual-hash', LLoadedPkg.SbomComponents[0].HashValue);
    finally
      LLoadedPkg.Free;
    end;
  finally
    LPkg.Free;
  end;
end;

procedure TTestsJson.TestLockSerialization;
var
  LLock, LLoadedLock: TBoss4DLock;
  LFilePath: string;
  LDep: TBoss4DDependency;
  LLockedDep: TBoss4DLockedDependency;
begin
  LFilePath := TPath.Combine(FTempDir, 'boss.lock');
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/hashload/horse', '^3.0.0');
  try
    LLock.Hash := 'somehashvalue';
    LLock.Updated := '2026-07-04T12:00:00Z';

    // Adiciona dependencia travada
    LLock.AddDependency(LDep, '3.1.0', 'commithash');

    // Adiciona artefatos a dependencia travada
    if LLock.GetInstalled(LDep, LLockedDep) then
    begin
      LLockedDep.Artifacts.Bin.Add('bin/horse.dll');
      LLockedDep.Artifacts.Dcu.Add('lib/horse.dcu');
    end;

    FLockRepo.Save(LLock, LFilePath);
    Assert.IsTrue(TFile.Exists(LFilePath));

    LLoadedLock := FLockRepo.Load(LFilePath);
    try
      Assert.AreEqual(LLock.Hash, LLoadedLock.Hash);
      Assert.AreEqual(LLock.Updated, LLoadedLock.Updated);
      Assert.IsTrue(LLoadedLock.Installed.ContainsKey(LDep.GetKey));

      var LInstalled: TBoss4DLockedDependency;
      Assert.IsTrue(LLoadedLock.GetInstalled(LDep, LInstalled));
      Assert.AreEqual<string>('horse', LInstalled.Name);
      Assert.AreEqual<string>('3.1.0', LInstalled.Version);
      Assert.AreEqual<string>('commithash', LInstalled.Hash);
      Assert.AreEqual<Integer>(1, LInstalled.Artifacts.Bin.Count);
      Assert.AreEqual<string>('bin/horse.dll', LInstalled.Artifacts.Bin[0]);
    finally
      LLoadedLock.Free;
    end;
  finally
    LDep.Free;
    LLock.Free;
  end;
end;

procedure TTestsJson.TestLockV1BackwardCompatibility;
var
  LFilePath: string;
  LLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LInstalled: TBoss4DLockedDependency;
  LSerialized: string;
begin
  LFilePath := TPath.Combine(FTempDir, 'boss-lock-v1.json');
  TFile.WriteAllText(LFilePath,
    '{' +
    '"hash":"manifest-hash",' +
    '"updated":"2026-07-21T12:00:00Z",' +
    '"installedModules":{' +
      '"github.com/hashload/horse":{' +
        '"name":"horse",' +
        '"version":"3.1.0",' +
        '"hash":"legacy-hash",' +
        '"checksum":"legacy-checksum",' +
        '"artifacts":{"bin":[],"dcp":[],"dcu":[],"bpl":[]}' +
      '}' +
    '}' +
    '}', TEncoding.UTF8);

  LLock := FLockRepo.Load(LFilePath);
  LDep := TBoss4DDependency.Create('github.com/hashload/horse', '*');
  try
    Assert.AreEqual<Integer>(1, LLock.LockVersion);
    Assert.IsTrue(LLock.GetInstalled(LDep, LInstalled));
    Assert.AreEqual('legacy-checksum', LInstalled.Checksum);
    Assert.AreEqual('SHA-256', LInstalled.ChecksumAlgorithm);

    FLockRepo.Save(LLock, LFilePath);
    LSerialized := TFile.ReadAllText(LFilePath, TEncoding.UTF8);
    Assert.IsTrue(LSerialized.Contains('"lockVersion": 2'));
    Assert.IsTrue(LSerialized.Contains('"algorithm": "SHA-256"'));
  finally
    LDep.Free;
    LLock.Free;
  end;
end;

procedure TTestsJson.TestLockV2MetadataRoundTrip;
var
  LFilePath: string;
  LLock, LLoadedLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LLocked, LLoaded: TBoss4DLockedDependency;
begin
  LFilePath := TPath.Combine(FTempDir, 'boss-lock-v2.json');
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/hashload/horse', '^3.0.0');
  try
    LLock.HasRootMetadata := True;
    LLock.RootName := 'sample-app';
    LLock.RootVersion := '2.0.0';
    LLock.RootDescription := 'Lock-only root';
    LLock.RootHomepage := 'https://example.test/sample';
    LLock.RootLicense := 'Apache-2.0';
    LLock.RootDependencies.Add(LDep.GetKey);
    LLock.AddDependency(LDep, '3.1.0', 'legacy-identity-hash', 'content-checksum');
    Assert.IsTrue(LLock.GetInstalled(LDep, LLocked));
    LLocked.Revision := '0123456789abcdef0123456789abcdef01234567';
    LLocked.ResolvedFrom := 'refs/tags/v3.1.0';
    LLocked.LicenseExpression := 'MIT';
    LLocked.LicenseSource := 'boss.json';
    LLocked.Dependencies.Add('github.com/vendor/dependency');

    FLockRepo.Save(LLock, LFilePath);
    LLoadedLock := FLockRepo.Load(LFilePath);
    try
      Assert.AreEqual<Integer>(2, LLoadedLock.LockVersion);
      Assert.IsTrue(LLoadedLock.HasRootMetadata);
      Assert.AreEqual('sample-app', LLoadedLock.RootName);
      Assert.AreEqual('2.0.0', LLoadedLock.RootVersion);
      Assert.AreEqual('Apache-2.0', LLoadedLock.RootLicense);
      Assert.AreEqual<Integer>(1, LLoadedLock.RootDependencies.Count);
      Assert.AreEqual(LDep.GetKey, LLoadedLock.RootDependencies[0]);
      Assert.IsTrue(LLoadedLock.GetInstalled(LDep, LLoaded));
      Assert.AreEqual('https://github.com/hashload/horse', LLoaded.Repository);
      Assert.AreEqual(LLocked.Revision, LLoaded.Revision);
      Assert.AreEqual('refs/tags/v3.1.0', LLoaded.ResolvedFrom);
      Assert.AreEqual('SHA-256', LLoaded.ChecksumAlgorithm);
      Assert.AreEqual('content-checksum', LLoaded.Checksum);
      Assert.AreEqual('MIT', LLoaded.LicenseExpression);
      Assert.AreEqual('boss.json', LLoaded.LicenseSource);
      Assert.AreEqual<Integer>(1, LLoaded.Dependencies.Count);
      Assert.AreEqual('github.com/vendor/dependency', LLoaded.Dependencies[0]);
    finally
      LLoadedLock.Free;
    end;
  finally
    LDep.Free;
    LLock.Free;
  end;
end;

procedure TTestsJson.TestLockV2DeterministicSerialization;
var
  LLock: TBoss4DLock;
  LDepA, LDepZ: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LFirstPath, LSecondPath: string;
begin
  LFirstPath := TPath.Combine(FTempDir, 'first-lock.json');
  LSecondPath := TPath.Combine(FTempDir, 'second-lock.json');
  LLock := TBoss4DLock.Create;
  LDepA := TBoss4DDependency.Create('github.com/example/alpha', '1.0.0');
  LDepZ := TBoss4DDependency.Create('github.com/example/zeta', '1.0.0');
  try
    // Insere em ordem inversa para provar que a ordem de escrita nao depende do dicionario.
    LLock.AddDependency(LDepZ, '1.0.0', 'zeta-hash');
    LLock.AddDependency(LDepA, '1.0.0', 'alpha-hash');
    Assert.IsTrue(LLock.GetInstalled(LDepZ, LLocked));
    LLocked.Dependencies.Add('github.com/example/z-child');
    LLocked.Dependencies.Add('github.com/example/a-child');

    FLockRepo.Save(LLock, LFirstPath);
    FLockRepo.Save(LLock, LSecondPath);

    Assert.AreEqual(
      TFile.ReadAllText(LFirstPath, TEncoding.UTF8),
      TFile.ReadAllText(LSecondPath, TEncoding.UTF8));
    Assert.IsTrue(
      TFile.ReadAllText(LFirstPath, TEncoding.UTF8).IndexOf('github.com/example/alpha') <
      TFile.ReadAllText(LFirstPath, TEncoding.UTF8).IndexOf('github.com/example/zeta'));
  finally
    LDepZ.Free;
    LDepA.Free;
    LLock.Free;
  end;
end;

procedure TTestsJson.TestLockV2RejectsFutureVersion;
var
  LFilePath: string;
  LRaised: Boolean;
  LLock: TBoss4DLock;
begin
  LFilePath := TPath.Combine(FTempDir, 'future-lock.json');
  TFile.WriteAllText(LFilePath,
    '{"lockVersion":999,"installedModules":{}}', TEncoding.UTF8);

  LRaised := False;
  LLock := nil;
  try
    try
      LLock := FLockRepo.Load(LFilePath);
    except
      on E: EConvertError do
      begin
        LRaised := True;
        Assert.IsTrue(E.Message.Contains('nao suportada'));
      end;
    end;
    Assert.IsTrue(LRaised, 'Locks de versoes futuras devem ser recusados.');
  finally
    LLock.Free;
  end;
end;

procedure TTestsJson.TestLockV2SharedAndCircularGraph;
var
  LFilePath: string;
  LLock, LLoaded: TBoss4DLock;
  LDepA, LDepB, LDepC: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
begin
  LFilePath := TPath.Combine(FTempDir, 'graph-lock.json');
  LLock := TBoss4DLock.Create;
  LDepA := TBoss4DDependency.Create('github.com/example/a', '1.0.0');
  LDepB := TBoss4DDependency.Create('github.com/example/b', '1.0.0');
  LDepC := TBoss4DDependency.Create('github.com/example/c', '1.0.0');
  try
    LLock.AddDependency(LDepA, '1.0.0', 'a');
    LLock.AddDependency(LDepB, '1.0.0', 'b');
    LLock.AddDependency(LDepC, '1.0.0', 'c');
    Assert.IsTrue(LLock.GetInstalled(LDepA, LLocked));
    LLocked.Dependencies.Add(LDepC.GetKey);
    Assert.IsTrue(LLock.GetInstalled(LDepB, LLocked));
    LLocked.Dependencies.Add(LDepC.GetKey);
    Assert.IsTrue(LLock.GetInstalled(LDepC, LLocked));
    LLocked.Dependencies.Add(LDepA.GetKey);

    FLockRepo.Save(LLock, LFilePath);
    LLoaded := FLockRepo.Load(LFilePath);
    try
      Assert.AreEqual<Integer>(3, LLoaded.Installed.Count);
      Assert.IsTrue(LLoaded.GetInstalled(LDepA, LLocked));
      Assert.AreEqual(LDepC.GetKey, LLocked.Dependencies[0]);
      Assert.IsTrue(LLoaded.GetInstalled(LDepB, LLocked));
      Assert.AreEqual(LDepC.GetKey, LLocked.Dependencies[0]);
      Assert.IsTrue(LLoaded.GetInstalled(LDepC, LLocked));
      Assert.AreEqual(LDepA.GetKey, LLocked.Dependencies[0]);
    finally
      LLoaded.Free;
    end;
  finally
    LDepC.Free;
    LDepB.Free;
    LDepA.Free;
    LLock.Free;
  end;
end;

procedure TTestsJson.TestUTF8WithoutBOMSerialization;
var
  LPkg: TBoss4DPackage;
  LFilePath: string;
  LBytes: TBytes;
begin
  LFilePath := TPath.Combine(FTempDir, 'boss_nobom.json');
  LPkg := TBoss4DPackage.Create;
  try
    LPkg.Name := 'test-nobom';
    LPkg.Version := '1.0.0';
    FPackageRepo.Save(LPkg, LFilePath);

    Assert.IsTrue(TFile.Exists(LFilePath));
    LBytes := TFile.ReadAllBytes(LFilePath);

    // Assegura que o arquivo tem pelo menos 3 bytes e os 3 primeiros nao sao o BOM UTF-8 (EF BB BF)
    Assert.IsTrue(Length(LBytes) >= 3);
    Assert.IsFalse((LBytes[0] = $EF) and (LBytes[1] = $BB) and (LBytes[2] = $BF), 'O arquivo nao deve conter o BOM UTF-8!');
  finally
    LPkg.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsJson);

end.
