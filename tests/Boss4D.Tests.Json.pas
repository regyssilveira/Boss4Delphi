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

    FPackageRepo.Save(LPkg, LFilePath);
    Assert.IsTrue(TFile.Exists(LFilePath));

    LLoadedPkg := FPackageRepo.Load(LFilePath);
    try
      Assert.AreEqual(LPkg.Name, LLoadedPkg.Name);
      Assert.AreEqual(LPkg.Description, LLoadedPkg.Description);
      Assert.AreEqual(LPkg.Version, LLoadedPkg.Version);
      Assert.AreEqual(LPkg.Homepage, LLoadedPkg.Homepage);
      Assert.AreEqual(1, LLoadedPkg.Projects.Count);
      Assert.AreEqual('Source/Project1.dproj', LLoadedPkg.Projects[0]);
      Assert.IsTrue(LLoadedPkg.Dependencies.ContainsKey('github.com/hashload/horse'));
      Assert.AreEqual('^3.0.0', LLoadedPkg.Dependencies['github.com/hashload/horse']);
      Assert.AreEqual('msbuild', LLoadedPkg.Scripts['build']);
      Assert.AreEqual('36.0', LLoadedPkg.Engines.Compiler);
      Assert.AreEqual('Win32', LLoadedPkg.Engines.Platforms[0]);
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
      Assert.AreEqual('horse', LInstalled.Name);
      Assert.AreEqual('3.1.0', LInstalled.Version);
      Assert.AreEqual('commithash', LInstalled.Hash);
      Assert.AreEqual(1, LInstalled.Artifacts.Bin.Count);
      Assert.AreEqual('bin/horse.dll', LInstalled.Artifacts.Bin[0]);
    finally
      LLoadedLock.Free;
    end;
  finally
    LDep.Free;
    LLock.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsJson);

end.
