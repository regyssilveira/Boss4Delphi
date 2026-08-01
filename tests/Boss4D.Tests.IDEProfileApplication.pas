unit Boss4D.Tests.IDEProfileApplication;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsIDEProfileApplication = class
  private
    FDirectory: string;
    FPreviousDirectory: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestInstallPreviewRepairAndUninstallUseSelectedProfile;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Adapters.Json,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.BuildCommand,
  Boss4D.Core.Services.BuildExecutor,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDEProfileApplication,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDEOperationResult,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.Tests.BuildCommand,
  Boss4D.Tests.IDEProcessPolicy,
  Boss4D.Tests.Mocks;

function IntroduceAndAssertProfileDrift(
  const AApplication: TBoss4DIDEProfileApplication;
  const ARegistry: TIDERegistryStoreMock): string;
begin
  Assert.AreEqual<Integer>(0,
    Length(AApplication.FindDrift('isolated')));
  const LKnownPackageKey =
    'Software\Embarcadero\Boss4D-isolated\37.0\Known Packages';
  var LKnownPackageNames := ARegistry.ListValueNames(
    LKnownPackageKey);
  ARegistry.DeleteValue(LKnownPackageKey, LKnownPackageNames[0]);
  var LDrift := AApplication.FindDrift('isolated');
  Assert.AreEqual<Integer>(1, Length(LDrift));
  Result := LDrift[0];
end;

procedure AssertInstallResultAndProgress(
  const ASummary: TBoss4DIDEProfileOperationSummary;
  const AProgress: TList<TBoss4DBuildTargetProgressEvent>;
  const ARegistry: TIDERegistryStoreMock);
begin
  Assert.AreEqual<Integer>(1, ASummary.Built + ASummary.Restored,
    'built or restored');
  Assert.AreEqual<Integer>(1, ASummary.Affected, 'registered');
  Assert.AreEqual<Integer>(2, AProgress.Count);
  Assert.AreEqual(TargetStarted, AProgress[0].State);
  Assert.IsTrue(AProgress[1].State in [TargetBuilt, TargetRestored]);
  Assert.AreEqual<Integer>(1, AProgress[1].Current);
  Assert.AreEqual<Integer>(1, AProgress[1].Total);
  Assert.IsTrue(Length(ARegistry.ListValueNames(
    'Software\Embarcadero\Boss4D-isolated\37.0\Known Packages')) > 0);
end;

procedure AssertUninstallOperationSnapshots(
  const AProfiles: TBoss4DIDEProfileService;
  const AOperation: TBoss4DIDEOperationResult);
begin
  Assert.IsTrue(TFile.Exists(AOperation.UndoSnapshot));
  Assert.IsTrue(TFile.Exists(AOperation.AfterSnapshot));
  var LChanges := AProfiles.CompareSnapshots(
    AOperation.UndoSnapshot, AOperation.AfterSnapshot);
  try
    Assert.IsTrue(LChanges.Contains('packages'));
    Assert.IsTrue(LChanges.Contains('inventory'));
  finally
    LChanges.Free;
  end;
end;

procedure TTestsIDEProfileApplication.Setup;
begin
  FPreviousDirectory := TDirectory.GetCurrentDirectory;
  FDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_profile_app_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDirectory);
  TDirectory.SetCurrentDirectory(FDirectory);
end;

procedure TTestsIDEProfileApplication.TearDown;
begin
  TDirectory.SetCurrentDirectory(FPreviousDirectory);
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TTestsIDEProfileApplication.TestInstallPreviewRepairAndUninstallUseSelectedProfile;
var
  LProfileStore: TBoss4DIDEProfileStore;
  LProfiles: TBoss4DIDEProfileService;
  LProfile: TBoss4DIDEProfile;
  LBuildInventory: TBoss4DBuildInventory;
  LPackageRepository: IBoss4DPackageRepository;
  LLockRepository: IBoss4DLockRepository;
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LRegistryStore: IBoss4DIDERegistryStore;
  LRegistryMock: TIDERegistryStoreMock;
  LResultStore: IBoss4DIDEOperationResultStore;
  LResultStoreObject: TBoss4DJsonIDEOperationResultStore;
  LApplication: TBoss4DIDEProfileApplication;
  LPlan: TBoss4DBuildCommandPlan;
  LRemovalPlan: TBoss4DIDERemovalPlan;
  LSummary: TBoss4DIDEProfileOperationSummary;
  LProgress: TList<TBoss4DBuildTargetProgressEvent>;
  LDriftIdentity: string;
  LUninstallOperationId: string;
begin
  TFile.WriteAllText(TPath.Combine(FDirectory, 'Design.dproj'),
    '<Project/>', TEncoding.UTF8);
  LPackageRepository := TBoss4DPackageJsonRepository.Create;
  LLockRepository := TBoss4DLockJsonRepository.Create;
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'profile-component';
    LPackage.Version := '1.0.0';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Design.dproj';
    LProject.Role := TBoss4DBuildProjectRole.DesignPackage;
    LPackage.BuildMatrix.Projects.Add(LProject);
    LPackageRepository.Save(LPackage,
      TPath.Combine(FDirectory, 'boss.json'));
  finally
    LPackage.Free;
  end;

  LProfileStore := TBoss4DIDEProfileStore.Create(
    TPath.Combine(FDirectory, 'profiles.json'));
  LProfiles := TBoss4DIDEProfileService.Create(LProfileStore,
    TPath.Combine(FDirectory, 'profiles'));
  LBuildInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(FDirectory, 'build-inventory.json'));
  LRegistryMock := TIDERegistryStoreMock.Create;
  LRegistryStore := LRegistryMock;
  LResultStoreObject := TBoss4DJsonIDEOperationResultStore.Create(
    TPath.Combine(FDirectory, 'operation-results'));
  LResultStore := LResultStoreObject;
  LProgress := TList<TBoss4DBuildTargetProgressEvent>.Create;
  try
    LProfile := LProfiles.CreateProfile('Isolated', '', 'd13',
      'C:\Delphi13\bin\bds.exe');
    LProfile.Free;
    LBuildInventory.RegisterPackage('profile-component',
      FDirectory, []);
    LBuildInventory.Save;
    LApplication := TBoss4DIDEProfileApplication.Create(
      LProfiles, LBuildInventory, LPackageRepository, LLockRepository,
      TBuildCommandCompilerMock.Create, nil,
      function(const AProfile: TBoss4DIDEProfile):
        TBoss4DIDERegistrationService
      begin
        Result := TBoss4DIDERegistrationService.Create(
          LRegistryStore, AProfile.InventoryPath, nil, nil,
          AProfile.Id, 30000, TIDEProcessProbeMock.Create(False),
          AProfile.Executable, AProfile.RegistryRoot);
      end,
      LResultStore);
    try
      LApplication.TargetProgress :=
        procedure(const AEvent: TBoss4DBuildTargetProgressEvent)
        begin
          LProgress.Add(AEvent);
        end;
      var LQuery := TBoss4DIDEManagementQuery.Create(
        LProfiles, LBuildInventory, LApplication);
      try
        var LTargets := LQuery.InstallTargets(
          'isolated', 'profile-component');
        try
          Assert.AreEqual<Integer>(1, LTargets.Count);
          Assert.IsTrue(LTargets[0].Identity.Contains('Design.dproj'));
        finally
          LTargets.Free;
        end;
      finally
        LQuery.Free;
      end;
      LPlan := LApplication.PreviewInstall(
        'isolated', 'profile-component');
      try
        Assert.AreEqual<Integer>(1, LPlan.Targets.Count);
      finally
        LPlan.Free;
      end;
      LSummary := LApplication.Install('isolated',
        'profile-component', TBoss4DIDEConflictPolicy.Fail,
        TBoss4DIDEOpenPolicy.Fail);
      AssertInstallResultAndProgress(
        LSummary, LProgress, LRegistryMock);
      LDriftIdentity := IntroduceAndAssertProfileDrift(
        LApplication, LRegistryMock);
      LProfile := LProfiles.Get('isolated');
      try
        Assert.AreEqual<Integer>(1, LProfile.Packages.Count,
          'profile packages');
        Assert.AreEqual('profile-component', LProfile.Packages[0]);
      finally
        LProfile.Free;
      end;

      LSummary := LApplication.RepairTarget(
        'isolated', LDriftIdentity);
      Assert.IsTrue(LSummary.Affected > 0);
      Assert.AreEqual<Integer>(0,
        Length(LApplication.FindDrift('isolated')));
      LQuery := TBoss4DIDEManagementQuery.Create(
        LProfiles, LBuildInventory, LApplication);
      try
        var LTargets := LQuery.UninstallTargets(
          'isolated', 'profile-component');
        try
          Assert.AreEqual<Integer>(1, LTargets.Count);
        finally
          LTargets.Free;
        end;
      finally
        LQuery.Free;
      end;
      LRemovalPlan := LApplication.PreviewUninstall(
        'isolated', 'profile-component');
      try
        Assert.AreEqual<Integer>(1, LRemovalPlan.Targets.Count,
          'removal targets');
      finally
        LRemovalPlan.Free;
      end;
      LSummary := LApplication.Uninstall('isolated',
        'profile-component');
      Assert.AreEqual<Integer>(1, LSummary.Affected, 'uninstalled');
      LProfile := LProfiles.Get('isolated');
      try
        Assert.AreEqual<Integer>(0, LProfile.Packages.Count);
      finally
        LProfile.Free;
      end;
      var LOperation := LResultStoreObject.LoadLatest;
      try
        Assert.AreEqual(TBoss4DIDEOperationStatus.Succeeded,
          LOperation.Status);
        Assert.AreEqual('profile-uninstall', LOperation.Kind);
        LUninstallOperationId := LOperation.OperationId;
        AssertUninstallOperationSnapshots(LProfiles, LOperation);
      finally
        LOperation.Free;
      end;
      LSummary := LApplication.Rollback(LUninstallOperationId);
      Assert.IsTrue(LSummary.Affected > 0, 'undo restored registrations');
      LProfile := LProfiles.Get('isolated');
      try
        Assert.AreEqual<Integer>(1, LProfile.Packages.Count);
        Assert.AreEqual('profile-component', LProfile.Packages[0]);
      finally
        LProfile.Free;
      end;
      Assert.IsTrue(Length(LRegistryMock.ListValueNames(
        'Software\Embarcadero\Boss4D-isolated\37.0\Known Packages')) > 0);
      LOperation := LResultStoreObject.LoadLatest;
      try
        Assert.AreEqual('profile-undo', LOperation.Kind);
        Assert.AreEqual(TBoss4DIDEOperationStatus.Succeeded,
          LOperation.Status);
      finally
        LOperation.Free;
      end;
    finally
      LApplication.Free;
    end;
  finally
    LProgress.Free;
    LResultStore := nil;
    LRegistryStore := nil;
    LBuildInventory.Free;
    LProfiles.Free;
    LProfileStore.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEProfileApplication);

end.
