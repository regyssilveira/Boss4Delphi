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
    procedure TestLegacyPackageContractRemainsStringBased;
    [Test]
    procedure TestBuildMatrixSerialization;
    [Test]
    procedure TestIDEAssetsSerialization;
    [Test]
    procedure TestBuildMatrixExampleIsExecutable;
    [Test]
    procedure TestComponentLifecycleExampleIsExecutable;
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
  System.SysUtils, System.IOUtils, System.JSON, Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.BuildMatrix, Boss4D.Core.Services.BuildMatrix;

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
    LPkg.AddDevDependency('github.com/example/test-kit', '1.0.0');
    LPkg.Scripts.Add('build', 'msbuild');
    LPkg.Engines.Compiler := '36.0';
    LPkg.Engines.Platforms.Add('Win32');
    LPkg.Trust.RequireSignedCommits := True;
    LPkg.Trust.RequireSignedTags := True;
    LPkg.Trust.AllowedSigners.Add('release@example.com');
    var LManualComponent := TBoss4DManualComponent.Create;
    LManualComponent.Id := 'commercial-driver';
    LManualComponent.Name := 'Commercial Database Driver';
    LManualComponent.Version := '5.4';
    LManualComponent.ComponentType := 'library';
    LManualComponent.License := 'Commercial';
    LManualComponent.HashAlgorithm := 'SHA-256';
    LManualComponent.HashValue := 'manual-hash';
    LManualComponent.Source := 'getit';
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
      Assert.AreEqual<string>('1.0.0',
        LLoadedPkg.DevDependencies['github.com/example/test-kit']);
      Assert.AreEqual<string>('msbuild', LLoadedPkg.Scripts['build']);
      Assert.AreEqual('36.0', LLoadedPkg.Engines.Compiler);
      Assert.AreEqual('Win32', LLoadedPkg.Engines.Platforms[0]);
      Assert.IsTrue(LLoadedPkg.Trust.RequireSignedCommits);
      Assert.IsTrue(LLoadedPkg.Trust.RequireSignedTags);
      Assert.AreEqual('release@example.com',
        LLoadedPkg.Trust.AllowedSigners[0]);
      Assert.AreEqual<Integer>(1, LLoadedPkg.SbomComponents.Count);
      Assert.AreEqual('commercial-driver', LLoadedPkg.SbomComponents[0].Id);
      Assert.AreEqual('Commercial', LLoadedPkg.SbomComponents[0].License);
      Assert.AreEqual('manual-hash', LLoadedPkg.SbomComponents[0].HashValue);
      Assert.AreEqual('getit', LLoadedPkg.SbomComponents[0].Source);
    finally
      LLoadedPkg.Free;
    end;
  finally
    LPkg.Free;
  end;
end;

procedure TTestsJson.TestBuildMatrixExampleIsExecutable;
var
  LExamplePath: string;
  LPackage: TBoss4DPackage;
  LTargets: TBoss4DBuildTargetList;
begin
  LExamplePath := TPath.GetFullPath(TPath.Combine(
    TDirectory.GetCurrentDirectory, '..\examples\build-matrix\boss.json'));
  Assert.IsTrue(TFile.Exists(LExamplePath),
    'O exemplo documentado da matriz deve existir.');

  LPackage := FPackageRepo.Load(LExamplePath);
  try
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      Assert.AreEqual<Integer>(23, LTargets.Count);
      Assert.AreEqual(
        'multi-delphi-component|packages/ComponentDesign.dproj|22.0|Win32|Release',
        LTargets[0].Identity);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsJson.TestComponentLifecycleExampleIsExecutable;
var
  LExamplePath: string;
  LPackage: TBoss4DPackage;
  LTargets: TBoss4DBuildTargetList;
  LFoundBinaryWin64: Boolean;
begin
  LExamplePath := TPath.GetFullPath(TPath.Combine(
    TDirectory.GetCurrentDirectory,
    '..\examples\component-build-and-ide\boss.json'));
  Assert.IsTrue(TFile.Exists(LExamplePath),
    'O exemplo completo de componente deve existir.');
  LPackage := FPackageRepo.Load(LExamplePath);
  try
    Assert.AreEqual<Integer>(5, LPackage.BuildMatrix.Projects.Count);
    Assert.AreEqual<Integer>(1, LPackage.IDEAssets.Tools.Count);
    Assert.AreEqual<Integer>(1, LPackage.IDEAssets.Templates.Count);
    Assert.AreEqual<Integer>(1, LPackage.IDEAssets.RegistryValues.Count);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      Assert.AreEqual<Integer>(51, LTargets.Count);
      LFoundBinaryWin64 := False;
      for var LTarget in LTargets do
        if SameText(LTarget.ProjectKind, 'binary') and
           SameText(LTarget.Platform, 'Win64') then
          LFoundBinaryWin64 := True;
      Assert.IsTrue(LFoundBinaryWin64);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsJson.TestBuildMatrixSerialization;
var
  LFilePath: string;
  LPackage: TBoss4DPackage;
  LLoaded: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LDependency: TBoss4DBuildDependency;
begin
  LFilePath := TPath.Combine(FTempDir, 'matrix-boss.json');
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'matrix-component';
    LPackage.Version := '2.0.0';
    LPackage.IDEProfile := 'team-components';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Compilers.Add('22.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LPackage.BuildMatrix.DefaultCompiler := '37.0';
    LPackage.BuildMatrix.DefaultPlatform := 'Win64';
    LPackage.BuildMatrix.DefaultConfiguration := 'Release';

    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'packages/runtime.dproj';
    LProject.PackageName := 'RuntimePackage';
    LProject.Kind := 'runtime';
    LProject.Platforms.Add('Win32');
    LProject.Platforms.Add('Win64');
    LPackage.BuildMatrix.Projects.Add(LProject);

    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'packages/design.dproj';
    LProject.PackageName := 'DesignPackage';
    LProject.IDEPackageDescription := 'Design-time integration';
    LProject.PalettePage := 'Boss4D Samples';
    LProject.Kind := 'design';
    LProject.DependsOn.Add('packages/runtime.dproj');
    LDependency := TBoss4DBuildDependency.Create;
    LDependency.Path := 'packages/optional-runtime.dproj';
    LDependency.Optional := True;
    LDependency.Compilers.Add('37.0');
    LDependency.Platforms.Add('Win32');
    LDependency.Configurations.Add('Release');
    LProject.Dependencies.Add(LDependency);
    LProject.Compilers.Add('37.0');
    LProject.Configurations.Add('Release');
    LPackage.BuildMatrix.Projects.Add(LProject);

    FPackageRepo.Save(LPackage, LFilePath);
  finally
    LPackage.Free;
  end;

  LLoaded := FPackageRepo.Load(LFilePath);
  try
    Assert.IsTrue(LLoaded.BuildMatrix.IsDeclared);
    Assert.AreEqual('team-components', LLoaded.IDEProfile);
    Assert.AreEqual<Integer>(2, LLoaded.BuildMatrix.Compilers.Count);
    Assert.AreEqual('22.0', LLoaded.BuildMatrix.Compilers[0]);
    Assert.AreEqual('37.0', LLoaded.BuildMatrix.DefaultCompiler);
    Assert.AreEqual('Win64', LLoaded.BuildMatrix.DefaultPlatform);
    Assert.AreEqual('Release', LLoaded.BuildMatrix.DefaultConfiguration);
    Assert.AreEqual<Integer>(2, LLoaded.BuildMatrix.Projects.Count);
    Assert.AreEqual('packages/design.dproj',
      LLoaded.BuildMatrix.Projects[0].Path);
    Assert.AreEqual('design', LLoaded.BuildMatrix.Projects[0].Kind);
    Assert.AreEqual('DesignPackage',
      LLoaded.BuildMatrix.Projects[0].PackageName);
    Assert.AreEqual('Design-time integration',
      LLoaded.BuildMatrix.Projects[0].IDEPackageDescription);
    Assert.AreEqual('Boss4D Samples',
      LLoaded.BuildMatrix.Projects[0].PalettePage);
    Assert.AreEqual<Integer>(1,
      LLoaded.BuildMatrix.Projects[0].DependsOn.Count);
    Assert.AreEqual('packages/runtime.dproj',
      LLoaded.BuildMatrix.Projects[0].DependsOn[0]);
    Assert.AreEqual<Integer>(1,
      LLoaded.BuildMatrix.Projects[0].Dependencies.Count);
    Assert.AreEqual('packages/optional-runtime.dproj',
      LLoaded.BuildMatrix.Projects[0].Dependencies[0].Path);
    Assert.IsTrue(
      LLoaded.BuildMatrix.Projects[0].Dependencies[0].Optional);
    Assert.AreEqual('37.0',
      LLoaded.BuildMatrix.Projects[0].Dependencies[0].Compilers[0]);
    Assert.AreEqual('Win32',
      LLoaded.BuildMatrix.Projects[0].Dependencies[0].Platforms[0]);
    Assert.AreEqual('Release',
      LLoaded.BuildMatrix.Projects[0].Dependencies[0].Configurations[0]);
    Assert.AreEqual('37.0',
      LLoaded.BuildMatrix.Projects[0].Compilers[0]);
    Assert.AreEqual('RuntimePackage',
      LLoaded.BuildMatrix.Projects[1].PackageName);
  finally
    LLoaded.Free;
  end;
end;

procedure TTestsJson.TestIDEAssetsSerialization;
var
  LFilePath: string;
  LPackage: TBoss4DPackage;
  LLoaded: TBoss4DPackage;
  LRegistryValue: TBoss4DIDERegistryValue;
begin
  LFilePath := TPath.Combine(FTempDir, 'ide-assets-boss.json');
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'ide-assets-component';
    LPackage.Version := '1.0.0';
    LPackage.IDEAssets.Tools.Add('ide/tools/component-wizard.exe');
    LPackage.IDEAssets.Templates.Add('ide/templates/component-template.zip');
    LRegistryValue := TBoss4DIDERegistryValue.Create;
    LRegistryValue.Key :=
      'Software\Embarcadero\BDS\{compiler}\ComponentVendor';
    LRegistryValue.Name := 'TemplatePath';
    LRegistryValue.Value := '{templates}';
    LPackage.IDEAssets.RegistryValues.Add(LRegistryValue);
    FPackageRepo.Save(LPackage, LFilePath);
  finally
    LPackage.Free;
  end;

  LLoaded := FPackageRepo.Load(LFilePath);
  try
    Assert.IsTrue(LLoaded.IDEAssets.IsDeclared);
    Assert.AreEqual<Integer>(1, LLoaded.IDEAssets.Tools.Count);
    Assert.AreEqual('ide/tools/component-wizard.exe',
      LLoaded.IDEAssets.Tools[0]);
    Assert.AreEqual<Integer>(1, LLoaded.IDEAssets.Templates.Count);
    Assert.AreEqual('ide/templates/component-template.zip',
      LLoaded.IDEAssets.Templates[0]);
    Assert.AreEqual<Integer>(1, LLoaded.IDEAssets.RegistryValues.Count);
    Assert.AreEqual(
      'Software\Embarcadero\BDS\{compiler}\ComponentVendor',
      LLoaded.IDEAssets.RegistryValues[0].Key);
    Assert.AreEqual('TemplatePath',
      LLoaded.IDEAssets.RegistryValues[0].Name);
    Assert.AreEqual('{templates}',
      LLoaded.IDEAssets.RegistryValues[0].Value);
  finally
    LLoaded.Free;
  end;
end;

procedure TTestsJson.TestLegacyPackageContractRemainsStringBased;
var
  LFilePath: string;
  LPackage: TBoss4DPackage;
  LRoot: TJSONObject;
  LProjects: TJSONArray;
  LDependencies: TJSONObject;
  LScripts: TJSONObject;
begin
  LFilePath := TPath.Combine(FTempDir, 'legacy-boss.json');
  TFile.WriteAllText(LFilePath,
    '{' +
      '"name":"legacy-component",' +
      '"version":"1.0.0",' +
      '"projects":["packages/runtime.dproj","packages/design.dproj"],' +
      '"scripts":{"build":"msbuild legacy.groupproj"},' +
      '"dependencies":{"github.com/example/runtime":"^1.2.0"},' +
      '"devDependencies":{"github.com/example/tests":"1.0.0"},' +
      '"engines":{"compiler":"34.0","platforms":["Win32","Win64"]},' +
      '"toolchain":{"compiler":"34.0","platform":"Win64","path":"C:\\Delphi","strict":true}' +
    '}', TEncoding.UTF8);

  LPackage := FPackageRepo.Load(LFilePath);
  try
    Assert.AreEqual<Integer>(2, LPackage.Projects.Count);
    Assert.AreEqual('packages/runtime.dproj', LPackage.Projects[0]);
    Assert.AreEqual('packages/design.dproj', LPackage.Projects[1]);
    Assert.AreEqual('msbuild legacy.groupproj', LPackage.Scripts['build']);
    Assert.AreEqual('^1.2.0',
      LPackage.Dependencies['github.com/example/runtime']);
    Assert.AreEqual('1.0.0',
      LPackage.DevDependencies['github.com/example/tests']);
    Assert.AreEqual('34.0', LPackage.Engines.Compiler);
    Assert.AreEqual<Integer>(2, LPackage.Engines.Platforms.Count);
    Assert.AreEqual('34.0', LPackage.Toolchain.Compiler);
    Assert.AreEqual('Win64', LPackage.Toolchain.Platform);
    Assert.IsTrue(LPackage.Toolchain.Strict);

    FPackageRepo.Save(LPackage, LFilePath);
  finally
    LPackage.Free;
  end;

  LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(LFilePath, TEncoding.UTF8)) as TJSONObject;
  try
    LProjects := LRoot.GetValue<TJSONArray>('projects');
    Assert.IsNotNull(LProjects);
    Assert.IsTrue(LProjects[0] is TJSONString,
      'Entradas legadas de projects devem continuar sendo strings.');

    LScripts := LRoot.GetValue<TJSONObject>('scripts');
    Assert.IsNotNull(LScripts);
    Assert.IsTrue(LScripts.GetValue('build') is TJSONString,
      'Valores legados de scripts devem continuar sendo strings.');

    LDependencies := LRoot.GetValue<TJSONObject>('dependencies');
    Assert.IsNotNull(LDependencies);
    Assert.IsTrue(
      LDependencies.GetValue('github.com/example/runtime') is TJSONString,
      'Versoes legadas de dependencies devem continuar sendo strings.');
    Assert.IsNull(LRoot.GetValue('buildMatrix'),
      'Salvar um manifesto legado nao deve adicionar buildMatrix.');
  finally
    LRoot.Free;
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
      LLockedDep.Artifacts.Base := 'module';
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
      Assert.AreEqual('module', LInstalled.Artifacts.Base);
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
    Assert.IsTrue(LSerialized.Contains('"lockVersion": 3'));
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
    LLock.RootDevDependencies.Add('github.com/example/test-kit');
    LLock.AddDependency(LDep, '3.1.0', 'legacy-identity-hash', 'content-checksum');
    Assert.IsTrue(LLock.GetInstalled(LDep, LLocked));
    LLocked.Revision := '0123456789abcdef0123456789abcdef01234567';
    LLocked.ResolvedFrom := 'refs/tags/v3.1.0';
    LLocked.LicenseExpression := 'MIT';
    LLocked.LicenseSource := 'boss.json';
    LLocked.Scope := 'development';
    LLocked.Dependencies.Add('github.com/vendor/dependency');

    FLockRepo.Save(LLock, LFilePath);
    LLoadedLock := FLockRepo.Load(LFilePath);
    try
      Assert.AreEqual<Integer>(3, LLoadedLock.LockVersion);
      Assert.IsTrue(LLoadedLock.HasRootMetadata);
      Assert.AreEqual('sample-app', LLoadedLock.RootName);
      Assert.AreEqual('2.0.0', LLoadedLock.RootVersion);
      Assert.AreEqual('Apache-2.0', LLoadedLock.RootLicense);
      Assert.AreEqual<Integer>(1, LLoadedLock.RootDependencies.Count);
      Assert.AreEqual(LDep.GetKey, LLoadedLock.RootDependencies[0]);
      Assert.AreEqual<Integer>(1, LLoadedLock.RootDevDependencies.Count);
      Assert.IsTrue(LLoadedLock.GetInstalled(LDep, LLoaded));
      Assert.AreEqual('https://github.com/hashload/horse', LLoaded.Repository);
      Assert.AreEqual(LLocked.Revision, LLoaded.Revision);
      Assert.AreEqual('refs/tags/v3.1.0', LLoaded.ResolvedFrom);
      Assert.AreEqual('SHA-256', LLoaded.ChecksumAlgorithm);
      Assert.AreEqual('content-checksum', LLoaded.Checksum);
      Assert.AreEqual('MIT', LLoaded.LicenseExpression);
      Assert.AreEqual('boss.json', LLoaded.LicenseSource);
      Assert.AreEqual('development', LLoaded.Scope);
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
