unit Boss4D.Core.Services.IDEManagementQuery;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDEProfileApplication;

type
  TBoss4DIDEProfileView = class
  private
    FId: string;
    FName: string;
    FDescription: string;
    FCompiler: string;
    FExecutable: string;
    FRegistryBranch: string;
    FDefaultPlatform: string;
    FDefaultConfiguration: string;
    FPackageCount: Integer;
  public
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Compiler: string read FCompiler write FCompiler;
    property Executable: string read FExecutable write FExecutable;
    property RegistryBranch: string read FRegistryBranch
      write FRegistryBranch;
    property DefaultPlatform: string read FDefaultPlatform
      write FDefaultPlatform;
    property DefaultConfiguration: string read FDefaultConfiguration
      write FDefaultConfiguration;
    property PackageCount: Integer read FPackageCount write FPackageCount;
  end;

  TBoss4DIDEPackageView = class
  private
    FName: string;
    FRootDirectory: string;
    FDependencies: TArray<string>;
    FInstalled: Boolean;
  public
    property Name: string read FName write FName;
    property RootDirectory: string read FRootDirectory write FRootDirectory;
    property Dependencies: TArray<string> read FDependencies
      write FDependencies;
    property Installed: Boolean read FInstalled write FInstalled;
  end;

  TBoss4DIDETargetView = class
  private
    FIdentity: string;
  public
    property Identity: string read FIdentity write FIdentity;
  end;

  TBoss4DIDEManagementQuery = class
  private
    FProfiles: TBoss4DIDEProfileService;
    FInventory: TBoss4DBuildInventory;
    FOperations: TBoss4DIDEProfileApplication;
  public
    constructor Create(const AProfiles: TBoss4DIDEProfileService;
      const AInventory: TBoss4DBuildInventory;
      const AOperations: TBoss4DIDEProfileApplication = nil);
    function Profiles: TObjectList<TBoss4DIDEProfileView>;
    function Packages(const AProfileId: string):
      TObjectList<TBoss4DIDEPackageView>;
    function InstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
  end;

implementation

uses
  System.SysUtils;

constructor TBoss4DIDEManagementQuery.Create(
  const AProfiles: TBoss4DIDEProfileService;
  const AInventory: TBoss4DBuildInventory;
  const AOperations: TBoss4DIDEProfileApplication);
begin
  inherited Create;
  if not Assigned(AProfiles) then
    raise EArgumentNilException.Create('AProfiles');
  if not Assigned(AInventory) then
    raise EArgumentNilException.Create('AInventory');
  FProfiles := AProfiles;
  FInventory := AInventory;
  FOperations := AOperations;
end;

function TBoss4DIDEManagementQuery.Profiles:
  TObjectList<TBoss4DIDEProfileView>;
begin
  Result := TObjectList<TBoss4DIDEProfileView>.Create(True);
  var LProfiles := FProfiles.List;
  try
    for var LProfile in LProfiles do
    begin
      var LView := TBoss4DIDEProfileView.Create;
      LView.Id := LProfile.Id;
      LView.Name := LProfile.Name;
      LView.Description := LProfile.Description;
      LView.Compiler := LProfile.Compiler;
      LView.Executable := LProfile.Executable;
      LView.RegistryBranch := LProfile.RegistryBranch;
      LView.DefaultPlatform := LProfile.DefaultPlatform;
      LView.DefaultConfiguration := LProfile.DefaultConfiguration;
      LView.PackageCount := LProfile.Packages.Count;
      Result.Add(LView);
    end;
  finally
    LProfiles.Free;
  end;
end;

function TBoss4DIDEManagementQuery.Packages(
  const AProfileId: string): TObjectList<TBoss4DIDEPackageView>;
begin
  Result := TObjectList<TBoss4DIDEPackageView>.Create(True);
  var LProfile := FProfiles.Get(AProfileId);
  var LPackages := FInventory.ListPackages;
  try
    for var LPackage in LPackages do
    begin
      var LView := TBoss4DIDEPackageView.Create;
      LView.Name := LPackage.Name;
      LView.RootDirectory := LPackage.RootDirectory;
      LView.Dependencies := LPackage.Dependencies.ToArray;
      LView.Installed := False;
      for var LInstalled in LProfile.Packages do
        if SameText(LInstalled, LPackage.Name) then
        begin
          LView.Installed := True;
          Break;
        end;
      Result.Add(LView);
    end;
  finally
    LPackages.Free;
    LProfile.Free;
  end;
end;

function TBoss4DIDEManagementQuery.InstallTargets(
  const AProfileId, APackage: string):
  TObjectList<TBoss4DIDETargetView>;
begin
  if not Assigned(FOperations) then
    raise EInvalidOpException.Create(
      'As operacoes de perfil IDE nao foram configuradas.');
  Result := TObjectList<TBoss4DIDETargetView>.Create(True);
  var LPlan := FOperations.PreviewInstall(AProfileId, APackage);
  try
    for var LTarget in LPlan.Targets do
    begin
      var LView := TBoss4DIDETargetView.Create;
      LView.Identity := LTarget;
      Result.Add(LView);
    end;
  finally
    LPlan.Free;
  end;
end;

end.
