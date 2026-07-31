unit Boss4D.Core.Services.IDEProfileApplication;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Core.Services.BuildCommand,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.Core.Services.IDEOperationResult;

type
  TBoss4DIDERegistrationServiceFactory = reference to function(
    const AProfile: TBoss4DIDEProfile): TBoss4DIDERegistrationService;

  TBoss4DIDEProfileOperationSummary = record
    Scheduled: Integer;
    Built: Integer;
    Skipped: Integer;
    Restored: Integer;
    Affected: Integer;
  end;

  TBoss4DIDEProfileApplication = class
  private
    FProfiles: TBoss4DIDEProfileService;
    FBuildInventory: TBoss4DBuildInventory;
    FPackageRepository: IBoss4DPackageRepository;
    FLockRepository: IBoss4DLockRepository;
    FCompiler: IBoss4DCompiler;
    FLogger: IBoss4DLogger;
    FRegistrationFactory: TBoss4DIDERegistrationServiceFactory;
    FResultStore: IBoss4DIDEOperationResultStore;
    function BuildOptions(const AProfile: TBoss4DIDEProfile;
      const AConflictPolicy: TBoss4DIDEConflictPolicy):
      TBoss4DBuildCommandOptions;
  public
    constructor Create(const AProfiles: TBoss4DIDEProfileService;
      const ABuildInventory: TBoss4DBuildInventory;
      const APackageRepository: IBoss4DPackageRepository;
      const ALockRepository: IBoss4DLockRepository;
      const ACompiler: IBoss4DCompiler; const ALogger: IBoss4DLogger;
      const ARegistrationFactory:
        TBoss4DIDERegistrationServiceFactory;
      const AResultStore: IBoss4DIDEOperationResultStore = nil);
    function PreviewInstall(const AProfileId,
      AOwnerPackage: string): TBoss4DBuildCommandPlan;
    function Install(const AProfileId, AOwnerPackage: string;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AIDEOpenPolicy: TBoss4DIDEOpenPolicy):
      TBoss4DIDEProfileOperationSummary;
    function PreviewUninstall(const AProfileId,
      AOwnerPackage: string): TBoss4DIDERemovalPlan;
    function Uninstall(const AProfileId,
      AOwnerPackage: string): TBoss4DIDEProfileOperationSummary;
    function Repair(const AProfileId: string):
      TBoss4DIDEProfileOperationSummary;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.BuildMatrix;

constructor TBoss4DIDEProfileApplication.Create(
  const AProfiles: TBoss4DIDEProfileService;
  const ABuildInventory: TBoss4DBuildInventory;
  const APackageRepository: IBoss4DPackageRepository;
  const ALockRepository: IBoss4DLockRepository;
  const ACompiler: IBoss4DCompiler; const ALogger: IBoss4DLogger;
  const ARegistrationFactory: TBoss4DIDERegistrationServiceFactory;
  const AResultStore: IBoss4DIDEOperationResultStore);
begin
  inherited Create;
  if not Assigned(AProfiles) then
    raise EArgumentNilException.Create('AProfiles');
  if not Assigned(ABuildInventory) then
    raise EArgumentNilException.Create('ABuildInventory');
  if not Assigned(APackageRepository) then
    raise EArgumentNilException.Create('APackageRepository');
  if not Assigned(ALockRepository) then
    raise EArgumentNilException.Create('ALockRepository');
  if not Assigned(ACompiler) then
    raise EArgumentNilException.Create('ACompiler');
  if not Assigned(ARegistrationFactory) then
    raise EArgumentNilException.Create('ARegistrationFactory');
  FProfiles := AProfiles;
  FBuildInventory := ABuildInventory;
  FPackageRepository := APackageRepository;
  FLockRepository := ALockRepository;
  FCompiler := ACompiler;
  FLogger := ALogger;
  FRegistrationFactory := ARegistrationFactory;
  FResultStore := AResultStore;
end;

function TBoss4DIDEProfileApplication.BuildOptions(
  const AProfile: TBoss4DIDEProfile;
  const AConflictPolicy: TBoss4DIDEConflictPolicy):
  TBoss4DBuildCommandOptions;
begin
  Result := Default(TBoss4DBuildCommandOptions);
  Result.Selection := TBoss4DBuildSelection.Create(
    AProfile.Compiler, AProfile.DefaultPlatform,
    AProfile.DefaultConfiguration);
  Result.RegisterTargets := True;
  Result.ConflictPolicy := AConflictPolicy;
  Result.Jobs := 1;
end;

function TBoss4DIDEProfileApplication.PreviewInstall(
  const AProfileId, AOwnerPackage: string): TBoss4DBuildCommandPlan;
begin
  var LProfile := FProfiles.Get(AProfileId);
  try
    var LInstalled := FBuildInventory.GetPackage(AOwnerPackage);
    var LManifest := TPath.Combine(LInstalled.RootDirectory, FILE_PACKAGE);
    var LPackage := FPackageRepository.Load(LManifest);
    try
      var LCommand := TBoss4DBuildCommand.Create(FCompiler, FLogger);
      try
        Result := LCommand.Plan(LPackage, LInstalled.RootDirectory,
          BuildOptions(LProfile, TBoss4DIDEConflictPolicy.Fail));
      finally
        LCommand.Free;
      end;
    finally
      LPackage.Free;
    end;
  finally
    LProfile.Free;
  end;
end;

function TBoss4DIDEProfileApplication.Install(
  const AProfileId, AOwnerPackage: string;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AIDEOpenPolicy: TBoss4DIDEOpenPolicy):
  TBoss4DIDEProfileOperationSummary;
var
  LRegistrationService: TBoss4DIDERegistrationService;
begin
  Result := Default(TBoss4DIDEProfileOperationSummary);
  var LProfile := FProfiles.Get(AProfileId);
  var LOperation := TBoss4DIDEOperationResult.New(
    'profile-install', LProfile.Id, AOwnerPackage);
  try
    try
      var LInstalled := FBuildInventory.GetPackage(AOwnerPackage);
      var LManifest := TPath.Combine(LInstalled.RootDirectory, FILE_PACKAGE);
      var LPackage := FPackageRepository.Load(LManifest);
      try
        var LLockPath := TPath.Combine(
          LInstalled.RootDirectory, FILE_PACKAGE_LOCK);
        var LLock: TBoss4DLock;
        if FLockRepository.Exists(LLockPath) then
          LLock := FLockRepository.Load(LLockPath)
        else
          LLock := TBoss4DLock.Create;
        try
          LRegistrationService := FRegistrationFactory(LProfile);
          try
            var LCommand := TBoss4DBuildCommand.Create(
              FCompiler, FLogger, nil, FBuildInventory,
              function(const ARegistrations:
                TObjectList<TBoss4DIDERegistration>): Integer
              begin
                for var LRegistration in ARegistrations do
                  LRegistration.IDEOpenPolicy := AIDEOpenPolicy;
                Result := LRegistrationService.RegisterTargets(
                  ARegistrations);
              end);
            try
              var LBuildResult := LCommand.Execute(LPackage, LLock,
                LInstalled.RootDirectory,
                BuildOptions(LProfile, AConflictPolicy));
              Result.Scheduled := LBuildResult.Scheduled;
              Result.Built := LBuildResult.Built;
              Result.Skipped := LBuildResult.Skipped;
              Result.Restored := LBuildResult.Restored;
              Result.Affected := LBuildResult.Registered;
            finally
              LCommand.Free;
            end;
          finally
            LRegistrationService.Free;
          end;
        finally
          LLock.Free;
        end;
      finally
        LPackage.Free;
      end;
      FProfiles.AddPackage(LProfile.Id, AOwnerPackage);
      LOperation.CompletedActions.Add('build ' + AOwnerPackage);
      LOperation.CompletedActions.Add('register ' + AOwnerPackage);
      LOperation.Complete;
      if Assigned(FResultStore) then
        FResultStore.Save(LOperation);
    except
      on E: Exception do
      begin
        LOperation.Fail(E.Message,
          'Execute profile repair para ' + LProfile.Id +
          ' e repita a instalacao de ' + AOwnerPackage + '.');
        if Assigned(FResultStore) then
          FResultStore.Save(LOperation);
        raise;
      end;
    end;
  finally
    LOperation.Free;
    LProfile.Free;
  end;
end;

function TBoss4DIDEProfileApplication.PreviewUninstall(
  const AProfileId, AOwnerPackage: string): TBoss4DIDERemovalPlan;
begin
  var LProfile := FProfiles.Get(AProfileId);
  try
    var LRegistrationService := FRegistrationFactory(LProfile);
    try
      Result := LRegistrationService.PlanUninstall(AOwnerPackage);
    finally
      LRegistrationService.Free;
    end;
  finally
    LProfile.Free;
  end;
end;

function TBoss4DIDEProfileApplication.Uninstall(
  const AProfileId, AOwnerPackage: string):
  TBoss4DIDEProfileOperationSummary;
begin
  Result := Default(TBoss4DIDEProfileOperationSummary);
  var LProfile := FProfiles.Get(AProfileId);
  var LOperation := TBoss4DIDEOperationResult.New(
    'profile-uninstall', LProfile.Id, AOwnerPackage);
  try
    try
      var LRegistrationService := FRegistrationFactory(LProfile);
      try
        Result.Affected := LRegistrationService.Uninstall(AOwnerPackage);
      finally
        LRegistrationService.Free;
      end;
      FProfiles.RemovePackage(LProfile.Id, AOwnerPackage);
      LOperation.CompletedActions.Add('unregister ' + AOwnerPackage);
      LOperation.Complete;
      if Assigned(FResultStore) then
        FResultStore.Save(LOperation);
    except
      on E: Exception do
      begin
        LOperation.Fail(E.Message,
          'Execute profile repair para ' + LProfile.Id +
          ' antes de repetir o uninstall.');
        if Assigned(FResultStore) then
          FResultStore.Save(LOperation);
        raise;
      end;
    end;
  finally
    LOperation.Free;
    LProfile.Free;
  end;
end;

function TBoss4DIDEProfileApplication.Repair(
  const AProfileId: string): TBoss4DIDEProfileOperationSummary;
begin
  Result := Default(TBoss4DIDEProfileOperationSummary);
  var LProfile := FProfiles.Get(AProfileId);
  var LOperation := TBoss4DIDEOperationResult.New(
    'profile-repair', LProfile.Id, LProfile.Id);
  try
    try
      var LRegistrationService := FRegistrationFactory(LProfile);
      try
        Result.Affected := LRegistrationService.Repair;
      finally
        LRegistrationService.Free;
      end;
      LOperation.CompletedActions.Add('repair ' + LProfile.Id);
      LOperation.Complete;
      if Assigned(FResultStore) then
        FResultStore.Save(LOperation);
    except
      on E: Exception do
      begin
        LOperation.Fail(E.Message,
          'Execute doctor no perfil ' + LProfile.Id +
          ' e corrija os artefatos reportados.');
        if Assigned(FResultStore) then
          FResultStore.Save(LOperation);
        raise;
      end;
    end;
  finally
    LOperation.Free;
    LProfile.Free;
  end;
end;

end.
