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
    procedure TestClonePackagesAndPersistenceAreIndependent;
    [Test]
    procedure TestExportImportAndLaunchRegistryBranch;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Core.Services.IDEProfiles;

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

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEProfiles);

end.
