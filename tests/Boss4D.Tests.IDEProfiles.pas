unit Boss4D.Tests.IDEProfiles;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsIDEProfiles = class
  private
    FDirectory: string;
    FStore: TObject;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestDefaultAndNamedProfilesUseIsolatedBranches;
    [Test]
    procedure TestDefaultMigratesLegacyInventoryWithoutOverwrite;
    [Test]
    procedure TestClonePackagesAndPersistenceAreIndependent;
    [Test]
    procedure TestExportImportAndLaunchRegistryBranch;
    [Test]
    procedure TestRemoveRejectsProfileWithInstalledPackages;
    [Test]
    procedure TestConfigureTargetPersistsProfileDefaults;
    [Test]
    procedure TestSnapshotDetectsDriftAndRestoresExactInventory;
    [Test]
    procedure TestSnapshotRejectsTamperedInventory;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Core.Services.IDEProfiles;

procedure TTestsIDEProfiles.TestSnapshotDetectsDriftAndRestoresExactInventory;
var
  LService: TBoss4DIDEProfileService;
  LProfile: TBoss4DIDEProfile;
  LSnapshotPath: string;
  LDrift: TList<string>;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    LProfile := LService.CreateProfile('Snapshot Test', '', 'd13',
      'C:\Delphi13\bin\bds.exe');
    try
      TDirectory.CreateDirectory(
        TPath.GetDirectoryName(LProfile.InventoryPath));
      TFile.WriteAllText(LProfile.InventoryPath, '{"version":1}',
        TEncoding.UTF8);
    finally
      LProfile.Free;
    end;
    LService.AddPackage('snapshot-test', 'Horse@3.1.0');
    LSnapshotPath := TPath.Combine(FDirectory, 'snapshot.json');
    LService.CreateSnapshot('snapshot-test', LSnapshotPath);

    LService.ConfigureTarget('snapshot-test', 'Win64', 'Debug');
    LService.AddPackage('snapshot-test', 'JWT@1.0.0');
    LProfile := LService.Get('snapshot-test');
    try
      TFile.WriteAllText(LProfile.InventoryPath, '{"version":2}',
        TEncoding.UTF8);
    finally
      LProfile.Free;
    end;
    LDrift := LService.CompareSnapshot('snapshot-test', LSnapshotPath);
    try
      Assert.IsTrue(LDrift.Contains('defaultPlatform'));
      Assert.IsTrue(LDrift.Contains('defaultConfiguration'));
      Assert.IsTrue(LDrift.Contains('packages'));
      Assert.IsTrue(LDrift.Contains('inventory'));
    finally
      LDrift.Free;
    end;

    LProfile := LService.RestoreSnapshot(LSnapshotPath);
    try
      Assert.AreEqual('Win32', LProfile.DefaultPlatform);
      Assert.AreEqual('Release', LProfile.DefaultConfiguration);
      Assert.AreEqual<Integer>(1, LProfile.Packages.Count);
      Assert.AreEqual('Horse@3.1.0', LProfile.Packages[0]);
      Assert.AreEqual('{"version":1}', TFile.ReadAllText(
        LProfile.InventoryPath, TEncoding.UTF8));
    finally
      LProfile.Free;
    end;
    LDrift := LService.CompareSnapshot('snapshot-test', LSnapshotPath);
    try
      Assert.AreEqual<Integer>(0, LDrift.Count);
    finally
      LDrift.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TTestsIDEProfiles.TestSnapshotRejectsTamperedInventory;
var
  LService: TBoss4DIDEProfileService;
  LSnapshotPath: string;
  LContent: string;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    var LProfile := LService.CreateProfile('Tamper Test', '', 'd13',
      'C:\Delphi13\bin\bds.exe');
    LProfile.Free;
    LSnapshotPath := TPath.Combine(FDirectory, 'tampered.json');
    LService.CreateSnapshot('tamper-test', LSnapshotPath);
    LContent := TFile.ReadAllText(LSnapshotPath, TEncoding.UTF8);
    LContent := LContent.Replace('"inventory": ""',
      '"inventory": "tampered"');
    TFile.WriteAllText(LSnapshotPath, LContent, TEncoding.UTF8);
    Assert.WillRaise(
      procedure
      begin
        LService.RestoreSnapshot(LSnapshotPath).Free;
      end,
      EBoss4DIDEProfileError);
  finally
    LService.Free;
  end;
end;

procedure TTestsIDEProfiles.Setup;
begin
  FDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_profiles_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDirectory);
  FStore := TBoss4DIDEProfileStore.Create(
    TPath.Combine(FDirectory, 'profiles.json'));
end;

procedure TTestsIDEProfiles.TearDown;
begin
  FStore.Free;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TTestsIDEProfiles.TestDefaultAndNamedProfilesUseIsolatedBranches;
var
  LService: TBoss4DIDEProfileService;
  LDefault: TBoss4DIDEProfile;
  LNamed: TBoss4DIDEProfile;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    LDefault := LService.EnsureDefault('d13', 'C:\Delphi13\bin\bds.exe');
    LNamed := LService.CreateProfile('CI Isolated', 'CI profile',
      '37.0', 'C:\Delphi13\bin\bds.exe');
    try
      Assert.AreEqual('default', LDefault.Id);
      Assert.AreEqual('Software\Embarcadero\BDS',
        LDefault.RegistryRoot);
      Assert.AreEqual('ci-isolated', LNamed.Id);
      Assert.AreEqual('Boss4D-ci-isolated', LNamed.RegistryBranch);
      Assert.AreEqual('Software\Embarcadero\Boss4D-ci-isolated',
        LNamed.RegistryRoot);
      Assert.AreNotEqual(LDefault.InventoryPath, LNamed.InventoryPath);
    finally
      LNamed.Free;
      LDefault.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TTestsIDEProfiles.TestDefaultMigratesLegacyInventoryWithoutOverwrite;
var
  LService: TBoss4DIDEProfileService;
  LProfile: TBoss4DIDEProfile;
  LLegacyPath: string;
begin
  LLegacyPath := TPath.Combine(FDirectory,
    'ide-registrations.json');
  TFile.WriteAllText(LLegacyPath, '{"legacy":true}', TEncoding.UTF8);
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    LProfile := LService.EnsureDefault('d13',
      'C:\Delphi13\bin\bds.exe', LLegacyPath);
    try
      Assert.AreEqual('{"legacy":true}', TFile.ReadAllText(
        LProfile.InventoryPath, TEncoding.UTF8));
      TFile.WriteAllText(LProfile.InventoryPath, '{"new":true}',
        TEncoding.UTF8);
    finally
      LProfile.Free;
    end;
    LProfile := LService.EnsureDefault('d13',
      'C:\Delphi13\bin\bds.exe', LLegacyPath);
    try
      Assert.AreEqual('{"new":true}', TFile.ReadAllText(
        LProfile.InventoryPath, TEncoding.UTF8),
        'Inventario ja migrado nunca pode ser sobrescrito.');
      Assert.AreEqual('Software\Embarcadero\BDS',
        LProfile.RegistryRoot);
    finally
      LProfile.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TTestsIDEProfiles.TestClonePackagesAndPersistenceAreIndependent;
var
  LService: TBoss4DIDEProfileService;
  LProfile: TBoss4DIDEProfile;
  LClone: TBoss4DIDEProfile;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    LProfile := LService.CreateProfile('Developer', '', 'd12',
      'C:\Delphi12\bin\bds.exe');
    LProfile.Free;
    LService.AddPackage('developer', 'Horse');
    LClone := LService.CloneProfile('developer', 'Experimental');
    try
      Assert.AreEqual<Integer>(1, LClone.Packages.Count);
      Assert.AreEqual('Horse', LClone.Packages[0]);
    finally
      LClone.Free;
    end;
    LService.RemovePackage('experimental', 'Horse');
    LProfile := LService.Get('developer');
    LClone := LService.Get('experimental');
    try
      Assert.AreEqual<Integer>(1, LProfile.Packages.Count);
      Assert.AreEqual<Integer>(0, LClone.Packages.Count);
      Assert.AreNotEqual(LProfile.RegistryBranch, LClone.RegistryBranch);
      Assert.AreNotEqual(LProfile.InventoryPath, LClone.InventoryPath);
    finally
      LClone.Free;
      LProfile.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TTestsIDEProfiles.TestExportImportAndLaunchRegistryBranch;
var
  LService: TBoss4DIDEProfileService;
  LImportedService: TBoss4DIDEProfileService;
  LImportedStore: TBoss4DIDEProfileStore;
  LProfile: TBoss4DIDEProfile;
  LExportPath: string;
  LExecutable: string;
  LArguments: string;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'),
    procedure(const AExecutable, AArguments: string)
    begin
      LExecutable := AExecutable;
      LArguments := AArguments;
    end);
  try
    LProfile := LService.CreateProfile('QA', '', 'd13',
      'C:\Delphi13\bin\bds.exe');
    LProfile.Free;
    LService.Launch('qa');
    Assert.AreEqual('C:\Delphi13\bin\bds.exe', LExecutable);
    Assert.AreEqual('/r:Boss4D-qa', LArguments);
    LExportPath := TPath.Combine(FDirectory, 'qa-profile.json');
    LService.ExportProfile('qa', LExportPath);
  finally
    LService.Free;
  end;

  LImportedStore := TBoss4DIDEProfileStore.Create(
    TPath.Combine(FDirectory, 'imported-profiles.json'));
  LImportedService := TBoss4DIDEProfileService.Create(LImportedStore,
    TPath.Combine(FDirectory, 'imported-data'));
  try
    LProfile := LImportedService.ImportProfile(LExportPath);
    try
      Assert.AreEqual('qa', LProfile.Id);
      Assert.AreEqual('Boss4D-qa', LProfile.RegistryBranch);
    finally
      LProfile.Free;
    end;
  finally
    LImportedService.Free;
    LImportedStore.Free;
  end;
end;

procedure TTestsIDEProfiles.TestRemoveRejectsProfileWithInstalledPackages;
var
  LService: TBoss4DIDEProfileService;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    var LProfile := LService.CreateProfile('Disposable', '', 'd13',
      'C:\Delphi13\bin\bds.exe');
    LProfile.Free;
    LService.AddPackage('disposable', 'Horse');
    Assert.WillRaise(
      procedure
      begin
        LService.Remove('disposable');
      end,
      EBoss4DIDEProfileError);
    LService.RemovePackage('disposable', 'Horse');
    LService.Remove('disposable');
    Assert.WillRaise(
      procedure
      begin
        LService.Get('disposable').Free;
      end,
      EBoss4DIDEProfileError);
  finally
    LService.Free;
  end;
end;

procedure TTestsIDEProfiles.TestConfigureTargetPersistsProfileDefaults;
var
  LService: TBoss4DIDEProfileService;
begin
  LService := TBoss4DIDEProfileService.Create(
    TBoss4DIDEProfileStore(FStore),
    TPath.Combine(FDirectory, 'data'));
  try
    var LProfile := LService.CreateProfile('Win64 Debug', '', 'd13',
      'C:\Delphi13\bin\bds.exe');
    LProfile.Free;
    LService.ConfigureTarget('win64-debug', 'Win64', 'Debug');
    LProfile := LService.Get('win64-debug');
    try
      Assert.AreEqual('Win64', LProfile.DefaultPlatform);
      Assert.AreEqual('Debug', LProfile.DefaultConfiguration);
    finally
      LProfile.Free;
    end;
    Assert.WillRaise(
      procedure
      begin
        LService.ConfigureTarget('win64-debug', '', 'Release');
      end,
      EArgumentException);
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEProfiles);

end.
