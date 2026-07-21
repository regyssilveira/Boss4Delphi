unit Boss4D.Tests.Sbom;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsSbom = class
  public
    [Test]
    procedure TestBuilderCreatesNeutralGraph;
    [Test]
    procedure TestBuilderStrictRejectsMissingEvidence;
    [Test]
    procedure TestBuilderReportsLegacyLock;
    [Test]
    procedure TestCycloneDX17SerializationAndValidation;
    [Test]
    procedure TestCycloneDXReproducibleOutput;
    [Test]
    procedure TestLicenseNormalization;
    [Test]
    procedure TestManualComponentInGraph;
    [Test]
    procedure TestToolchainCollectorAddsDetectedInstallations;
    [Test]
    procedure TestArtifactCollectorHashesDeclaredFiles;
    [Test]
    procedure TestSpdx23SerializationAndValidation;
    [Test]
    procedure TestLockOnlyDoesNotRequireBossJson;
    [Test]
    procedure TestStrictLockOnlyRejectsLockWithoutRootEvidence;
    [Test]
    procedure TestGetItInventoryIsSeparatedFromDeclaredUsage;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Sbom,
  Boss4D.Core.Services.Sbom,
  Boss4D.Core.Domain.License,
  Boss4D.Core.Ports,
  Boss4D.Adapters.Sbom.CycloneDX,
  Boss4D.Adapters.Sbom.Collectors,
  Boss4D.Adapters.Sbom.Spdx, Boss4D.Adapters.Json,
  Boss4D.Tests.Mocks;

procedure ConfigureLockedDependency(const ALock: TBoss4DLock; const ADependency: TBoss4DDependency;
  const AVersion, ARevision, AChecksum: string);
var
  LLocked: TBoss4DLockedDependency;
begin
  ALock.AddDependency(ADependency, AVersion, ADependency.HashName, AChecksum);
  if ALock.GetInstalled(ADependency, LLocked) then
  begin
    LLocked.Revision := ARevision;
    LLocked.ResolvedFrom := AVersion;
    LLocked.LicenseExpression := 'MIT';
    LLocked.LicenseSource := 'boss.json';
  end;
end;

procedure TTestsSbom.TestBuilderCreatesNeutralGraph;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDepA, LDepB: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LBuilder: TBoss4DSbomBuilder;
  LDocument: TBoss4DSbomDocument;
  LRootRelation, LARelation: TBoss4DSbomRelationship;
begin
  LPkg := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LDepA := TBoss4DDependency.Create('github.com/example/a', '^1.0.0');
  LDepB := TBoss4DDependency.Create('git@github.com:example/b.git', '2.0.0');
  LBuilder := TBoss4DSbomBuilder.Create;
  try
    LPkg.Name := 'sample-app';
    LPkg.Version := '1.0.0';
    LPkg.Description := 'Aplicacao de teste';
    LPkg.License := 'Apache-2.0';
    LPkg.AddDependency(LDepA.Repository, LDepA.Version);

    ConfigureLockedDependency(LLock, LDepA, '1.2.0',
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'checksum-a');
    ConfigureLockedDependency(LLock, LDepB, '2.0.0',
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'checksum-b');
    Assert.IsTrue(LLock.GetInstalled(LDepA, LLocked));
    LLocked.Dependencies.Add(LDepB.GetKey);

    LDocument := LBuilder.Build(LPkg, LLock, True);
    try
      Assert.AreEqual<Integer>(3, LDocument.Components.Count);
      Assert.AreEqual<Integer>(3, LDocument.Relationships.Count);
      Assert.AreEqual('a', LDocument.Components[1].Name);
      Assert.AreEqual('b', LDocument.Components[2].Name);
      Assert.AreEqual('boss-managed-dependencies', LDocument.Coverage);
      Assert.AreEqual<TBoss4DSbomCompleteness>(Incomplete, LDocument.Completeness);
      Assert.AreEqual<Integer>(0, LDocument.Issues.Count);

      LRootRelation := LDocument.FindRelationship(LDocument.RootComponentId);
      Assert.IsNotNull(LRootRelation);
      Assert.AreEqual<Integer>(1, LRootRelation.DependsOn.Count);

      LARelation := LDocument.FindRelationship(
        'boss4d:git:https://github.com/example/a@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      Assert.IsNotNull(LARelation);
      Assert.AreEqual<Integer>(1, LARelation.DependsOn.Count);
      Assert.AreEqual(
        'boss4d:git:https://github.com/example/b@bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        LARelation.DependsOn[0]);
    finally
      LDocument.Free;
    end;
  finally
    LBuilder.Free;
    LDepB.Free;
    LDepA.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

procedure TTestsSbom.TestBuilderStrictRejectsMissingEvidence;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LBuilder: TBoss4DSbomBuilder;
  LRaised: Boolean;
begin
  LPkg := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/example/missing', '1.0.0');
  LBuilder := TBoss4DSbomBuilder.Create;
  try
    LPkg.Name := 'strict-app';
    LPkg.Version := '1.0.0';
    LPkg.AddDependency(LDep.Repository, LDep.Version);
    LLock.AddDependency(LDep, '1.0.0', LDep.HashName);

    LRaised := False;
    try
      var LDocument := LBuilder.Build(LPkg, LLock, True);
      LDocument.Free;
    except
      on E: EBoss4DSbomValidation do
        LRaised := True;
    end;
    Assert.IsTrue(LRaised);
  finally
    LBuilder.Free;
    LDep.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

procedure TTestsSbom.TestBuilderReportsLegacyLock;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LBuilder: TBoss4DSbomBuilder;
  LDocument: TBoss4DSbomDocument;
begin
  LPkg := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LBuilder := TBoss4DSbomBuilder.Create;
  try
    LPkg.Name := 'legacy-app';
    LPkg.Version := '1.0.0';
    LLock.LockVersion := 1;
    LDocument := LBuilder.Build(LPkg, LLock, False);
    try
      Assert.AreEqual<Integer>(1, LDocument.Issues.Count);
      Assert.IsTrue(LDocument.Issues[0].Contains('lock v1'));
    finally
      LDocument.Free;
    end;
  finally
    LBuilder.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

function CreateMinimalDocument: TBoss4DSbomDocument;
var
  LRoot, LDependency: TBoss4DSbomComponent;
  LRelationship: TBoss4DSbomRelationship;
  LHash: TBoss4DSbomHash;
begin
  Result := TBoss4DSbomDocument.Create;
  Result.ToolName := 'Boss4D';
  Result.ToolVersion := '1.0.1';
  Result.Lifecycle := 'build';
  Result.Coverage := 'boss-managed-dependencies';
  Result.Completeness := Incomplete;

  LRoot := TBoss4DSbomComponent.Create;
  LRoot.Id := 'boss4d:root:app@1.0.0';
  LRoot.Name := 'app';
  LRoot.Version := '1.0.0';
  LRoot.ComponentType := ApplicationComponent;
  Result.RootComponentId := LRoot.Id;
  Result.Components.Add(LRoot);

  LDependency := TBoss4DSbomComponent.Create;
  LDependency.Id := 'boss4d:git:https://github.com/example/lib@abc';
  LDependency.Name := 'lib';
  LDependency.Version := '1.0.0';
  LDependency.ComponentType := LibraryComponent;
  LHash := TBoss4DSbomHash.Create;
  LHash.Algorithm := 'SHA-256';
  LHash.Value := '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  LDependency.Hashes.Add(LHash);
  Result.Components.Add(LDependency);

  LRelationship := TBoss4DSbomRelationship.Create;
  LRelationship.ComponentId := LRoot.Id;
  LRelationship.DependsOn.Add(LDependency.Id);
  Result.Relationships.Add(LRelationship);
  LRelationship := TBoss4DSbomRelationship.Create;
  LRelationship.ComponentId := LDependency.Id;
  Result.Relationships.Add(LRelationship);
end;

procedure TTestsSbom.TestCycloneDX17SerializationAndValidation;
var
  LDocument: TBoss4DSbomDocument;
  LWriter: IBoss4DSbomWriter;
  LJSON, LError: string;
begin
  LDocument := CreateMinimalDocument;
  LWriter := TBoss4DCycloneDXWriter.Create;
  try
    LJSON := LWriter.Serialize(LDocument, False);
    Assert.IsTrue(LJSON.Contains('"bomFormat": "CycloneDX"'));
    Assert.IsTrue(LJSON.Contains('"specVersion": "1.7"'));
    Assert.IsTrue(LJSON.Contains('"aggregate": "incomplete"'));
    Assert.IsTrue(LJSON.Contains('"serialNumber"'));
    Assert.IsTrue(LWriter.Validate(LJSON, LError), LError);
  finally
    LDocument.Free;
  end;
end;

procedure TTestsSbom.TestCycloneDXReproducibleOutput;
var
  LDocument: TBoss4DSbomDocument;
  LWriter: IBoss4DSbomWriter;
  LFirst, LSecond: string;
begin
  LDocument := CreateMinimalDocument;
  LWriter := TBoss4DCycloneDXWriter.Create;
  try
    LFirst := LWriter.Serialize(LDocument, True);
    LSecond := LWriter.Serialize(LDocument, True);
    Assert.AreEqual(LFirst, LSecond);
    Assert.IsFalse(LFirst.Contains('"serialNumber"'));
    Assert.IsFalse(LFirst.Contains('"timestamp"'));
  finally
    LDocument.Free;
  end;
end;

procedure TTestsSbom.TestLicenseNormalization;
var
  LLicense: TBoss4DSbomLicense;
begin
  LLicense := TBoss4DLicenseNormalizer.Normalize('MIT OR Apache-2.0', 'boss.json');
  try
    Assert.AreEqual<TBoss4DSbomLicenseKind>(SpdxExpressionLicense, LLicense.Kind);
    Assert.AreEqual('MIT OR Apache-2.0', LLicense.Expression);
  finally
    LLicense.Free;
  end;

  LLicense := TBoss4DLicenseNormalizer.Normalize('Commercial', 'manual');
  try
    Assert.AreEqual<TBoss4DSbomLicenseKind>(ProprietaryLicense, LLicense.Kind);
    Assert.AreEqual('Commercial', LLicense.Name);
  finally
    LLicense.Free;
  end;

  LLicense := TBoss4DLicenseNormalizer.Normalize('', 'scan');
  try
    Assert.AreEqual<TBoss4DSbomLicenseKind>(MissingLicense, LLicense.Kind);
  finally
    LLicense.Free;
  end;
end;

procedure TTestsSbom.TestManualComponentInGraph;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LBuilder: TBoss4DSbomBuilder;
  LDocument: TBoss4DSbomDocument;
  LManual: TBoss4DManualComponent;
  LComponent: TBoss4DSbomComponent;
begin
  LPkg := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LBuilder := TBoss4DSbomBuilder.Create;
  try
    LPkg.Name := 'manual-app';
    LPkg.Version := '1.0.0';
    LManual := TBoss4DManualComponent.Create;
    LManual.Id := 'vendor-driver';
    LManual.Name := 'Vendor Driver';
    LManual.Version := '5.4';
    LManual.ComponentType := 'library';
    LManual.License := 'Commercial';
    LManual.Repository := 'https://vendor.example/driver';
    LPkg.SbomComponents.Add(LManual);

    LDocument := LBuilder.Build(LPkg, LLock, True);
    try
      LComponent := LDocument.FindComponent('boss4d:manual:vendor-driver');
      Assert.IsNotNull(LComponent);
      Assert.AreEqual<Integer>(1, LComponent.Licenses.Count);
      Assert.AreEqual<TBoss4DSbomLicenseKind>(ProprietaryLicense,
        LComponent.Licenses[0].Kind);
      Assert.AreEqual<Integer>(1,
        LDocument.FindRelationship(LDocument.RootComponentId).DependsOn.Count);
      Assert.AreEqual('boss4d:manual:vendor-driver',
        LDocument.FindRelationship(LDocument.RootComponentId).DependsOn[0]);
    finally
      LDocument.Free;
    end;
  finally
    LBuilder.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

procedure TTestsSbom.TestToolchainCollectorAddsDetectedInstallations;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LBuilder: TBoss4DSbomBuilder;
  LDocument: TBoss4DSbomDocument;
  LRegistry: TRegistryMock;
  LCollector: IBoss4DSbomCollector;
begin
  LPkg := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LBuilder := TBoss4DSbomBuilder.Create;
  LRegistry := TRegistryMock.Create;
  try
    LPkg.Name := 'toolchain-app';
    LPkg.Version := '1.0.0';
    LRegistry.Path37 := 'C:\Fake\RADStudio13';
    LDocument := LBuilder.Build(LPkg, LLock);
    try
      LCollector := TBoss4DToolchainSbomCollector.Create(LRegistry);
      LCollector.Collect(LDocument, LPkg, LLock, TDirectory.GetCurrentDirectory);
      Assert.IsNotNull(LDocument.FindComponent('boss4d:toolchain:rad-studio@37.0'));
      Assert.Contains(LDocument.Coverage, 'delphi-toolchain-rtl');
    finally
      LDocument.Free;
    end;
  finally
    LBuilder.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

procedure TTestsSbom.TestArtifactCollectorHashesDeclaredFiles;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LBuilder: TBoss4DSbomBuilder;
  LDocument: TBoss4DSbomDocument;
  LCollector: IBoss4DSbomCollector;
  LTempDir, LArtifact: string;
begin
  LTempDir := TPath.Combine(TPath.GetTempPath, 'boss4d-sbom-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LTempDir);
  LArtifact := TPath.Combine(LTempDir, 'vendor.dll');
  TFile.WriteAllText(LArtifact, 'binary fixture');
  LPkg := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/example/vendor', '1.0.0');
  LBuilder := TBoss4DSbomBuilder.Create;
  try
    LPkg.Name := 'artifact-app';
    LPkg.Version := '1.0.0';
    LPkg.Dependencies.Add(LDep.Name, '1.0.0');
    ConfigureLockedDependency(LLock, LDep, '1.0.0', 'abc123', 'deadbeef');
    Assert.IsTrue(LLock.GetInstalled(LDep, LLocked));
    LLocked.Artifacts.Bin.Add('vendor.dll');
    LDocument := LBuilder.Build(LPkg, LLock);
    try
      LCollector := TBoss4DArtifactSbomCollector.Create;
      LCollector.Collect(LDocument, LPkg, LLock, LTempDir);
      var LFile := LDocument.FindComponent('boss4d:file:vendor.dll');
      Assert.IsNotNull(LFile);
      Assert.AreEqual<Integer>(1, LFile.Hashes.Count);
      Assert.AreEqual<Integer>(64, LFile.Hashes[0].Value.Length);
    finally
      LDocument.Free;
    end;
  finally
    LBuilder.Free;
    LDep.Free;
    LLock.Free;
    LPkg.Free;
    TDirectory.Delete(LTempDir, True);
  end;
end;

procedure TTestsSbom.TestSpdx23SerializationAndValidation;
var
  LDocument: TBoss4DSbomDocument;
  LWriter: IBoss4DSbomWriter;
  LContent, LError: string;
begin
  LDocument := CreateMinimalDocument;
  try
    LWriter := TBoss4DSpdxWriter.Create;
    LContent := LWriter.Serialize(LDocument, True);
    Assert.IsTrue(LWriter.Validate(LContent, LError), LError);
    Assert.Contains(LContent, '"spdxVersion":"SPDX-2.3"');
    Assert.Contains(LContent, '"relationshipType":"DESCRIBES"');
    Assert.Contains(LContent, '"relationshipType":"DEPENDS_ON"');
    Assert.Contains(LContent, '"created":"1970-01-01T00:00:00Z"');
    Assert.AreEqual(LContent, LWriter.Serialize(LDocument, True));
  finally
    LDocument.Free;
  end;
end;

procedure TTestsSbom.TestLockOnlyDoesNotRequireBossJson;
var
  LTempDir, LLockPath, LMissingPackagePath: string;
  LLock: TBoss4DLock;
  LLockRepository: IBoss4DLockRepository;
  LPackageRepository: IBoss4DPackageRepository;
  LWriter: IBoss4DSbomWriter;
  LService: TBoss4DSbomService;
  LOptions: TBoss4DSbomOptions;
  LContent: string;
begin
  LTempDir := TPath.Combine(TPath.GetTempPath, 'boss4d-lock-only-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LTempDir);
  LLockPath := TPath.Combine(LTempDir, 'boss-lock.json');
  LMissingPackagePath := TPath.Combine(LTempDir, 'boss.json');
  LLockRepository := TBoss4DLockJsonRepository.Create;
  LPackageRepository := TBoss4DPackageJsonRepository.Create;
  LWriter := TBoss4DCycloneDXWriter.Create;
  LLock := TBoss4DLock.Create;
  try
    LLock.HasRootMetadata := True;
    LLock.RootName := 'lock-only-app';
    LLock.RootVersion := '1.2.3';
    LLock.RootLicense := 'MIT';
    LLockRepository.Save(LLock, LLockPath);
  finally
    LLock.Free;
  end;

  LService := TBoss4DSbomService.Create(LPackageRepository, LLockRepository, LWriter);
  try
    LOptions := Default(TBoss4DSbomOptions);
    LOptions.LockOnly := True;
    LOptions.StrictMode := True;
    LOptions.ValidateOutput := True;
    LOptions.ReproducibleOutput := True;
    LContent := LService.Generate(LMissingPackagePath, LLockPath, LOptions);
    Assert.Contains(LContent, 'lock-only-app');
    Assert.IsFalse(TFile.Exists(LMissingPackagePath));
  finally
    LService.Free;
    TDirectory.Delete(LTempDir, True);
  end;
end;

procedure TTestsSbom.TestStrictLockOnlyRejectsLockWithoutRootEvidence;
var
  LTempDir, LLockPath: string;
  LLock: TBoss4DLock;
  LLockRepository: IBoss4DLockRepository;
  LService: TBoss4DSbomService;
  LOptions: TBoss4DSbomOptions;
  LRaised: Boolean;
begin
  LTempDir := TPath.Combine(TPath.GetTempPath, 'boss4d-lock-root-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LTempDir);
  LLockPath := TPath.Combine(LTempDir, 'boss-lock.json');
  LLockRepository := TBoss4DLockJsonRepository.Create;
  LLock := TBoss4DLock.Create;
  try
    LLockRepository.Save(LLock, LLockPath);
  finally
    LLock.Free;
  end;
  LService := TBoss4DSbomService.Create(TBoss4DPackageJsonRepository.Create,
    LLockRepository, TBoss4DCycloneDXWriter.Create);
  try
    LOptions := Default(TBoss4DSbomOptions);
    LOptions.LockOnly := True;
    LOptions.StrictMode := True;
    LRaised := False;
    try
      LService.Generate(TPath.Combine(LTempDir, 'boss.json'), LLockPath, LOptions);
    except
      on E: EBoss4DSbomValidation do LRaised := True;
    end;
    Assert.IsTrue(LRaised, 'Lock-only estrito deve exigir evidencia da raiz.');
  finally
    LService.Free;
    TDirectory.Delete(LTempDir, True);
  end;
end;

procedure TTestsSbom.TestGetItInventoryIsSeparatedFromDeclaredUsage;
var
  LDocument: TBoss4DSbomDocument;
  LDeclared: TBoss4DSbomComponent;
  LRootRelation: TBoss4DSbomRelationship;
  LValue: string;
begin
  LDocument := CreateMinimalDocument;
  try
    LRootRelation := LDocument.FindRelationship(LDocument.RootComponentId);
    var LInitialDependencyCount := LRootRelation.DependsOn.Count;
    TBoss4DGetItInventoryParser.Enrich(
      'Id  Version  Description' + sLineBreak +
      '--  -------  -----------' + sLineBreak +
      'InstalledOnly-1.0  1.0  Environment package', LDocument);
    var LInventory := LDocument.FindComponent('boss4d:getit:installedonly-1.0@1.0');
    Assert.IsNotNull(LInventory);
    Assert.IsTrue(LInventory.Properties.TryGetValue('boss4d:usage', LValue));
    Assert.AreEqual('unknown', LValue);
    Assert.AreEqual(LInitialDependencyCount, LRootRelation.DependsOn.Count,
      'Pacote apenas instalado nao pode virar dependencia do projeto.');

    LDeclared := TBoss4DSbomComponent.Create;
    LDeclared.Id := 'boss4d:manual:declared-getit';
    LDeclared.Name := 'UsedPackage-2.0';
    LDeclared.Version := '2.0';
    LDeclared.ComponentType := LibraryComponent;
    LDeclared.Properties.Add('boss4d:source', 'getit');
    LDeclared.Properties.Add('boss4d:usage', 'declared');
    LDocument.Components.Add(LDeclared);
    LRootRelation.DependsOn.Add(LDeclared.Id);
    TBoss4DGetItInventoryParser.Enrich(
      'UsedPackage-2.0  2.0  Declared and installed', LDocument);
    Assert.IsTrue(LDeclared.Properties.TryGetValue('boss4d:installed', LValue));
    Assert.AreEqual('true', LValue);
    Assert.AreEqual<Integer>(0, LDocument.Issues.Count);

    LDeclared.Properties.AddOrSetValue('boss4d:installed', 'false');
    TBoss4DGetItInventoryParser.Enrich('Different-1.0  1.0  Other', LDocument);
    Assert.AreEqual<Integer>(1, LDocument.Issues.Count);
  finally
    LDocument.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsSbom);

end.
