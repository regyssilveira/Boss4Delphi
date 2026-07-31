unit Boss4D.Core.Services.BuildCoordinator;

interface

uses
  Boss4D.Core.Ports,
  Boss4D.Core.Services.BuildCommand,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.IDEDiscovery;

type
  TBoss4DBuildCoordinator = class
  private
    FCompiler: IBoss4DCompiler;
    FLogger: IBoss4DLogger;
    FPackageRepository: IBoss4DPackageRepository;
    FLockRepository: IBoss4DLockRepository;
    FRegistrationHandler: TBoss4DIDERegistrationHandler;
    FInventory: TBoss4DBuildInventory;
    FIDEDiscovery: IBoss4DIDEDiscovery;
  public
    constructor Create(const ACompiler: IBoss4DCompiler;
      const ALogger: IBoss4DLogger;
      const APackageRepository: IBoss4DPackageRepository;
      const ALockRepository: IBoss4DLockRepository;
      const ARegistrationHandler: TBoss4DIDERegistrationHandler;
      const AInventory: TBoss4DBuildInventory;
      const AIDEDiscovery: IBoss4DIDEDiscovery = nil);
    function Execute(const ARootDirectory: string;
      const AOptions: TBoss4DBuildCommandOptions): TBoss4DBuildCommandResult;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Domain.Consts;

constructor TBoss4DBuildCoordinator.Create(const ACompiler: IBoss4DCompiler;
  const ALogger: IBoss4DLogger;
  const APackageRepository: IBoss4DPackageRepository;
  const ALockRepository: IBoss4DLockRepository;
  const ARegistrationHandler: TBoss4DIDERegistrationHandler;
  const AInventory: TBoss4DBuildInventory;
  const AIDEDiscovery: IBoss4DIDEDiscovery);
begin
  inherited Create;
  if not Assigned(ACompiler) then
    raise EArgumentNilException.Create('ACompiler');
  if not Assigned(APackageRepository) then
    raise EArgumentNilException.Create('APackageRepository');
  if not Assigned(ALockRepository) then
    raise EArgumentNilException.Create('ALockRepository');
  if not Assigned(AInventory) then
    raise EArgumentNilException.Create('AInventory');
  FCompiler := ACompiler;
  FLogger := ALogger;
  FPackageRepository := APackageRepository;
  FLockRepository := ALockRepository;
  FRegistrationHandler := ARegistrationHandler;
  FInventory := AInventory;
  FIDEDiscovery := AIDEDiscovery;
end;

function TBoss4DBuildCoordinator.Execute(const ARootDirectory: string;
  const AOptions: TBoss4DBuildCommandOptions): TBoss4DBuildCommandResult;
var
  LSeedPackage: TBoss4DPackage;
  LSelected: TList<string>;
  LRoots: TDictionary<string, string>;
  LOrder: TArray<string>;
  LInstallations: TBoss4DIDEInstallationList;
begin
  Result := Default(TBoss4DBuildCommandResult);
  var LSeedRoot := TPath.GetFullPath(ARootDirectory);
  var LSeedManifest := TPath.Combine(LSeedRoot, FILE_PACKAGE);
  if not FPackageRepository.Exists(LSeedManifest) then
    raise EFileNotFoundException.CreateFmt(
      'Manifesto do pacote raiz nao encontrado: %s.', [LSeedManifest]);

  LSeedPackage := FPackageRepository.Load(LSeedManifest);
  LSelected := TList<string>.Create;
  LRoots := TDictionary<string, string>.Create;
  LInstallations := nil;
  try
    if AOptions.AllInstalledIDEs then
    begin
      if not Assigned(FIDEDiscovery) then
        raise EInvalidOpException.Create(
          'A descoberta de IDEs nao esta disponivel neste ambiente.');
      LInstallations := FIDEDiscovery.Discover;
      if LInstallations.Count = 0 then
        raise EInvalidOpException.Create(
          'Nenhuma instalacao Delphi com compilador foi detectada.');
    end;
    var LSeedName := LSeedPackage.Name.Trim.ToLower;
    if LSeedName.IsEmpty then
      raise EBoss4DBuildInventoryError.Create(
        'O pacote raiz precisa ter um nome para o build global.');
    LSelected.Add(LSeedName);
    LRoots.Add(LSeedName, LSeedRoot);
    if AOptions.WithDependents then
      for var LDependent in FInventory.DependentsOf(LSeedName) do
      begin
        LSelected.Add(LDependent);
        LRoots.AddOrSetValue(LDependent,
          FInventory.GetPackage(LDependent).RootDirectory);
      end;
    LOrder := FInventory.BuildOrder(LSelected.ToArray);

    for var LName in LOrder do
    begin
      var LRoot := LRoots[LName];
      var LManifest := TPath.Combine(LRoot, FILE_PACKAGE);
      if not FPackageRepository.Exists(LManifest) then
        raise EFileNotFoundException.CreateFmt(
          'Manifesto do pacote dependente nao encontrado: %s.',
          [LManifest]);
      var LPackage: TBoss4DPackage;
      if SameText(LName, LSeedName) then
      begin
        LPackage := LSeedPackage;
        LSeedPackage := nil;
      end
      else
        LPackage := FPackageRepository.Load(LManifest);
      try
        var LLockPath := TPath.Combine(LRoot, FILE_PACKAGE_LOCK);
        var LLock: TBoss4DLock;
        if FLockRepository.Exists(LLockPath) then
          LLock := FLockRepository.Load(LLockPath)
        else
          LLock := TBoss4DLock.Create;
        try
          var LCommand := TBoss4DBuildCommand.Create(FCompiler, FLogger,
            FRegistrationHandler, FInventory);
          try
            var LSelections: TArray<TBoss4DBuildSelection>;
            if AOptions.AllInstalledIDEs then
              LSelections := TBoss4DMultiIDEPlanner.Plan(LPackage,
                LInstallations)
            else
              LSelections := TArray<TBoss4DBuildSelection>.Create(
                AOptions.Selection);
            if Length(LSelections) = 0 then
              raise EInvalidOpException.CreateFmt(
                'Nenhum target instalado e compativel com o pacote %s.',
                [LPackage.Name]);
            for var LSelection in LSelections do
            begin
              var LTargetOptions := AOptions;
              LTargetOptions.Selection := LSelection;
              var LPartial := LCommand.Execute(LPackage, LLock, LRoot,
                LTargetOptions);
              Inc(Result.Scheduled, LPartial.Scheduled);
              Inc(Result.Built, LPartial.Built);
              Inc(Result.Skipped, LPartial.Skipped);
              Inc(Result.Restored, LPartial.Restored);
              Inc(Result.Registered, LPartial.Registered);
            end;
          finally
            LCommand.Free;
          end;
        finally
          LLock.Free;
        end;
      finally
        LPackage.Free;
      end;
    end;
  finally
    LInstallations.Free;
    LRoots.Free;
    LSelected.Free;
    LSeedPackage.Free;
  end;
end;

end.
