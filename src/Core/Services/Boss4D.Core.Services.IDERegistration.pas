unit Boss4D.Core.Services.IDERegistration;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Boss4D.Core.Services.IDEOperationLock,
  Boss4D.Core.Services.IDEProcessPolicy;

type
  EBoss4DIDERegistrationError = class(Exception);
  TBoss4DIDERegistration = class;
  TBoss4DIDEArtifactRepairHandler = reference to procedure(
    const ARegistration: TBoss4DIDERegistration);

  IBoss4DIDERegistryStore = interface
    ['{893DFD50-485C-4D19-97BF-A52E435BEA21}']
    function TryRead(const AKey, AName: string; out AValue: string): Boolean;
    procedure WriteValue(const AKey, AName, AValue: string);
    procedure DeleteValue(const AKey, AName: string);
    function ListValueNames(const AKey: string): TArray<string>;
  end;

  TBoss4DWindowsIDERegistryStore = class(TInterfacedObject,
    IBoss4DIDERegistryStore)
  private
    FRootKey: HKEY;
  public
    constructor Create(const ARootKey: HKEY = HKEY_CURRENT_USER);
    function TryRead(const AKey, AName: string; out AValue: string): Boolean;
    procedure WriteValue(const AKey, AName, AValue: string);
    procedure DeleteValue(const AKey, AName: string);
    function ListValueNames(const AKey: string): TArray<string>;
  end;

  TBoss4DIDEPackageConflict = record
    RegistryKey: string;
    ExistingPath: string;
    Description: string;
  end;

  TBoss4DIDEConflictPolicy = (Fail, Warn, Adopt, Replace);
  TBoss4DIDEPlanDisposition = (Ready, Blocked, Adopted, Deferred);
  TBoss4DIDERegistryChangeKind = (WriteValue, DeleteValue);

  TBoss4DIDERegistryChange = class
  private
    FKind: TBoss4DIDERegistryChangeKind;
    FKey: string;
    FName: string;
    FCurrentValue: string;
    FProposedValue: string;
  public
    constructor Create(const AKind: TBoss4DIDERegistryChangeKind;
      const AKey, AName, ACurrentValue, AProposedValue: string);
    property Kind: TBoss4DIDERegistryChangeKind read FKind;
    property Key: string read FKey;
    property Name: string read FName;
    property CurrentValue: string read FCurrentValue;
    property ProposedValue: string read FProposedValue;
  end;

  TBoss4DIDERegistrationPlan = class
  private
    FIdentity: string;
    FDisposition: TBoss4DIDEPlanDisposition;
    FInventoryChangeRequired: Boolean;
    FChanges: TObjectList<TBoss4DIDERegistryChange>;
    FConflicts: TList<TBoss4DIDEPackageConflict>;
  public
    constructor Create;
    destructor Destroy; override;
    function IsNoOp: Boolean;
    property Identity: string read FIdentity write FIdentity;
    property Disposition: TBoss4DIDEPlanDisposition read FDisposition
      write FDisposition;
    property InventoryChangeRequired: Boolean
      read FInventoryChangeRequired write FInventoryChangeRequired;
    property Changes: TObjectList<TBoss4DIDERegistryChange> read FChanges;
    property Conflicts: TList<TBoss4DIDEPackageConflict> read FConflicts;
  end;

  TBoss4DIDERemovalPlan = class
  private
    FTargets: TList<string>;
    FChanges: TObjectList<TBoss4DIDERegistryChange>;
    FFiles: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function IsNoOp: Boolean;
    property Targets: TList<string> read FTargets;
    property Changes: TObjectList<TBoss4DIDERegistryChange> read FChanges;
    property Files: TList<string> read FFiles;
  end;

  TBoss4DIDEManagedRegistryValue = class
  private
    FKey: string;
    FName: string;
    FValue: string;
  public
    function Clone: TBoss4DIDEManagedRegistryValue;
    property Key: string read FKey write FKey;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
  end;

  TBoss4DIDERegistration = class
  private
    FPackageName: string;
    FOwnerPackage: string;
    FCompiler: string;
    FPlatform: string;
    FConfiguration: string;
    FRegistryRoot: string;
    FBplPath: string;
    FDescription: string;
    FSearchPath: string;
    FBrowsingPath: string;
    FDebugDcuPath: string;
    FRuntimePath: string;
    FToolPath: string;
    FArtifactRoot: string;
    FArtifacts: TList<string>;
    FHelpFiles: TList<string>;
    FRegistryValues: TObjectList<TBoss4DIDEManagedRegistryValue>;
    FConflictPolicy: TBoss4DIDEConflictPolicy;
    FIDEOpenPolicy: TBoss4DIDEOpenPolicy;
    FDisplacedRegistryValues:
      TObjectList<TBoss4DIDEManagedRegistryValue>;
  public
    constructor Create;
    destructor Destroy; override;
    function Identity: string;
    function Clone: TBoss4DIDERegistration;
    property PackageName: string read FPackageName write FPackageName;
    property OwnerPackage: string read FOwnerPackage write FOwnerPackage;
    property Compiler: string read FCompiler write FCompiler;
    property Platform: string read FPlatform write FPlatform;
    property Configuration: string read FConfiguration write FConfiguration;
    property RegistryRoot: string read FRegistryRoot write FRegistryRoot;
    property BplPath: string read FBplPath write FBplPath;
    property Description: string read FDescription write FDescription;
    property SearchPath: string read FSearchPath write FSearchPath;
    property BrowsingPath: string read FBrowsingPath write FBrowsingPath;
    property DebugDcuPath: string read FDebugDcuPath write FDebugDcuPath;
    property RuntimePath: string read FRuntimePath write FRuntimePath;
    property ToolPath: string read FToolPath write FToolPath;
    property ArtifactRoot: string read FArtifactRoot write FArtifactRoot;
    property Artifacts: TList<string> read FArtifacts;
    property HelpFiles: TList<string> read FHelpFiles;
    property RegistryValues: TObjectList<TBoss4DIDEManagedRegistryValue>
      read FRegistryValues;
    property ConflictPolicy: TBoss4DIDEConflictPolicy read FConflictPolicy
      write FConflictPolicy;
    property IDEOpenPolicy: TBoss4DIDEOpenPolicy read FIDEOpenPolicy
      write FIDEOpenPolicy;
    property DisplacedRegistryValues:
      TObjectList<TBoss4DIDEManagedRegistryValue>
      read FDisplacedRegistryValues;
  end;

  TBoss4DIDERegistrationService = class
  private
    FStore: IBoss4DIDERegistryStore;
    FInventoryPath: string;
    FArtifactRepairHandler: TBoss4DIDEArtifactRepairHandler;
    FOperationLock: IBoss4DIDEOperationLock;
    FProfileName: string;
    FLockTimeoutMilliseconds: Cardinal;
    FProcessProbe: IBoss4DIDEProcessProbe;
    FIDEExecutableName: string;
    FRegistryRoot: string;
    function LibraryKey(const ARegistration: TBoss4DIDERegistration): string;
    function PackageKey(const ARegistration: TBoss4DIDERegistration): string;
    function IDEPackageKey(
      const ARegistration: TBoss4DIDERegistration): string;
    procedure Validate(const ARegistration: TBoss4DIDERegistration);
    function LoadInventory: TObjectList<TBoss4DIDERegistration>;
    procedure SaveInventory(
      const AInventory: TObjectList<TBoss4DIDERegistration>);
    function ArtifactsHealthy(
      const ARegistration: TBoss4DIDERegistration): Boolean;
    function IsHealthy(const ARegistration: TBoss4DIDERegistration): Boolean;
    function RemoveMatching(const AName, ACompiler, APlatform: string;
      const AByOwner: Boolean): Integer;
    function PlanRemoval(const AName, ACompiler, APlatform: string;
      const AByOwner: Boolean): TBoss4DIDERemovalPlan;
  public
    constructor Create(const AStore: IBoss4DIDERegistryStore;
      const AInventoryPath: string;
      const AArtifactRepairHandler: TBoss4DIDEArtifactRepairHandler = nil;
      const AOperationLock: IBoss4DIDEOperationLock = nil;
      const AProfileName: string = 'default';
      const ALockTimeoutMilliseconds: Cardinal = 30000;
      const AProcessProbe: IBoss4DIDEProcessProbe = nil;
      const AIDEExecutableName: string = 'bds.exe';
      const ARegistryRoot: string = 'Software\Embarcadero\BDS');
    procedure RegisterTarget(const ARegistration: TBoss4DIDERegistration);
    function RegisterTargets(
      const ARegistrations: TObjectList<TBoss4DIDERegistration>): Integer;
    function DetectConflicts(
      const ARegistration: TBoss4DIDERegistration):
      TArray<TBoss4DIDEPackageConflict>;
    function PlanRegistration(
      const ARegistration: TBoss4DIDERegistration):
      TBoss4DIDERegistrationPlan;
    function Unregister(const APackageName, ACompiler,
      APlatform: string): Integer;
    function Uninstall(const AOwnerPackage: string): Integer;
    function PlanUnregister(const APackageName, ACompiler,
      APlatform: string): TBoss4DIDERemovalPlan;
    function PlanUninstall(
      const AOwnerPackage: string): TBoss4DIDERemovalPlan;
    function Repair: Integer; overload;
    function Repair(const AIdentity: string): Integer; overload;
    function FindDrift: TArray<string>;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Defaults,
  System.Win.Registry,
  Boss4D.Core.Services.BuildConventions;

type
  TBoss4DRegistrySnapshot = class
  private
    FKey: string;
    FName: string;
    FExisted: Boolean;
    FValue: string;
  end;

constructor TBoss4DWindowsIDERegistryStore.Create(const ARootKey: HKEY);
begin
  inherited Create;
  FRootKey := ARootKey;
end;

function TBoss4DWindowsIDERegistryStore.TryRead(const AKey,
  AName: string; out AValue: string): Boolean;
var
  LRegistry: TRegistry;
begin
  Result := False;
  AValue := '';
  LRegistry := TRegistry.Create(KEY_READ);
  try
    LRegistry.RootKey := FRootKey;
    if LRegistry.OpenKeyReadOnly(AKey) and LRegistry.ValueExists(AName) then
    begin
      AValue := LRegistry.ReadString(AName);
      Result := True;
    end;
  finally
    LRegistry.Free;
  end;
end;

procedure TBoss4DWindowsIDERegistryStore.WriteValue(const AKey, AName,
  AValue: string);
var
  LRegistry: TRegistry;
begin
  LRegistry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    LRegistry.RootKey := FRootKey;
    if not LRegistry.OpenKey(AKey, True) then
      raise EBoss4DIDERegistrationError.CreateFmt(
        'Nao foi possivel abrir a chave %s.', [AKey]);
    LRegistry.WriteString(AName, AValue);
  finally
    LRegistry.Free;
  end;
end;

procedure TBoss4DWindowsIDERegistryStore.DeleteValue(const AKey,
  AName: string);
var
  LRegistry: TRegistry;
begin
  LRegistry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    LRegistry.RootKey := FRootKey;
    if LRegistry.OpenKey(AKey, False) and LRegistry.ValueExists(AName) then
      LRegistry.DeleteValue(AName);
  finally
    LRegistry.Free;
  end;
end;

constructor TBoss4DIDERegistryChange.Create(
  const AKind: TBoss4DIDERegistryChangeKind;
  const AKey, AName, ACurrentValue, AProposedValue: string);
begin
  inherited Create;
  FKind := AKind;
  FKey := AKey;
  FName := AName;
  FCurrentValue := ACurrentValue;
  FProposedValue := AProposedValue;
end;

constructor TBoss4DIDERegistrationPlan.Create;
begin
  inherited Create;
  FDisposition := TBoss4DIDEPlanDisposition.Ready;
  FChanges := TObjectList<TBoss4DIDERegistryChange>.Create(True);
  FConflicts := TList<TBoss4DIDEPackageConflict>.Create;
end;

destructor TBoss4DIDERegistrationPlan.Destroy;
begin
  FConflicts.Free;
  FChanges.Free;
  inherited Destroy;
end;

function TBoss4DIDERegistrationPlan.IsNoOp: Boolean;
begin
  Result := (FDisposition = TBoss4DIDEPlanDisposition.Ready) and
    not FInventoryChangeRequired and (FChanges.Count = 0);
end;

constructor TBoss4DIDERemovalPlan.Create;
begin
  inherited Create;
  FTargets := TList<string>.Create;
  FChanges := TObjectList<TBoss4DIDERegistryChange>.Create(True);
  FFiles := TList<string>.Create;
end;

destructor TBoss4DIDERemovalPlan.Destroy;
begin
  FFiles.Free;
  FChanges.Free;
  FTargets.Free;
  inherited Destroy;
end;

function TBoss4DIDERemovalPlan.IsNoOp: Boolean;
begin
  Result := FTargets.Count = 0;
end;

constructor TBoss4DIDERegistration.Create;
begin
  inherited Create;
  FIDEOpenPolicy := TBoss4DIDEOpenPolicy.Force;
  FRegistryRoot := 'Software\Embarcadero\BDS';
  FArtifacts := TList<string>.Create;
  FHelpFiles := TList<string>.Create;
  FRegistryValues := TObjectList<TBoss4DIDEManagedRegistryValue>.Create(True);
  FDisplacedRegistryValues :=
    TObjectList<TBoss4DIDEManagedRegistryValue>.Create(True);
end;

function TBoss4DWindowsIDERegistryStore.ListValueNames(
  const AKey: string): TArray<string>;
var
  LRegistry: TRegistry;
  LNames: TStringList;
begin
  LRegistry := TRegistry.Create(KEY_READ);
  LNames := TStringList.Create;
  try
    LRegistry.RootKey := FRootKey;
    if LRegistry.OpenKeyReadOnly(AKey) then
      LRegistry.GetValueNames(LNames);
    Result := LNames.ToStringArray;
  finally
    LNames.Free;
    LRegistry.Free;
  end;
end;

destructor TBoss4DIDERegistration.Destroy;
begin
  FDisplacedRegistryValues.Free;
  FRegistryValues.Free;
  FHelpFiles.Free;
  FArtifacts.Free;
  inherited Destroy;
end;

function TBoss4DIDERegistration.Identity: string;
begin
  Result := FPackageName + '|' + FCompiler + '|' + FPlatform;
end;

function TBoss4DIDERegistration.Clone: TBoss4DIDERegistration;
begin
  Result := TBoss4DIDERegistration.Create;
  Result.PackageName := FPackageName;
  Result.OwnerPackage := FOwnerPackage;
  Result.Compiler := FCompiler;
  Result.Platform := FPlatform;
  Result.Configuration := FConfiguration;
  Result.RegistryRoot := FRegistryRoot;
  Result.BplPath := FBplPath;
  Result.Description := FDescription;
  Result.SearchPath := FSearchPath;
  Result.BrowsingPath := FBrowsingPath;
  Result.DebugDcuPath := FDebugDcuPath;
  Result.RuntimePath := FRuntimePath;
  Result.ToolPath := FToolPath;
  Result.ArtifactRoot := FArtifactRoot;
  Result.Artifacts.AddRange(FArtifacts);
  Result.HelpFiles.AddRange(FHelpFiles);
  for var LValue in FRegistryValues do
    Result.RegistryValues.Add(LValue.Clone);
  Result.ConflictPolicy := FConflictPolicy;
  Result.IDEOpenPolicy := FIDEOpenPolicy;
  for var LValue in FDisplacedRegistryValues do
    Result.DisplacedRegistryValues.Add(LValue.Clone);
end;

function TBoss4DIDEManagedRegistryValue.Clone:
  TBoss4DIDEManagedRegistryValue;
begin
  Result := TBoss4DIDEManagedRegistryValue.Create;
  Result.Key := FKey;
  Result.Name := FName;
  Result.Value := FValue;
end;

function TBoss4DIDERegistrationService.DetectConflicts(
  const ARegistration: TBoss4DIDERegistration):
  TArray<TBoss4DIDEPackageConflict>;
var
  LConflicts: TList<TBoss4DIDEPackageConflict>;

  procedure InspectKey(const AKey: string);
  begin
    for var LExistingPath in FStore.ListValueNames(AKey) do
    begin
      if SameText(LExistingPath, ARegistration.BplPath) or
         not SameText(TPath.GetFileName(LExistingPath),
           TPath.GetFileName(ARegistration.BplPath)) then
        Continue;
      var LConflict := Default(TBoss4DIDEPackageConflict);
      LConflict.RegistryKey := AKey;
      LConflict.ExistingPath := LExistingPath;
      FStore.TryRead(AKey, LExistingPath, LConflict.Description);
      LConflicts.Add(LConflict);
    end;
  end;
begin
  Validate(ARegistration);
  LConflicts := TList<TBoss4DIDEPackageConflict>.Create;
  try
    InspectKey(PackageKey(ARegistration));
    InspectKey(IDEPackageKey(ARegistration));
    var LInventory := LoadInventory;
    try
      for var I := LConflicts.Count - 1 downto 0 do
        for var LOwnedRegistration in LInventory do
          if SameText(LOwnedRegistration.Identity,
               ARegistration.Identity) and
             SameText(LOwnedRegistration.BplPath,
               LConflicts[I].ExistingPath) then
          begin
            LConflicts.Delete(I);
            Break;
          end;
    finally
      LInventory.Free;
    end;
    Result := LConflicts.ToArray;
  finally
    LConflicts.Free;
  end;
end;

function ContainsPath(const AValue, APath: string): Boolean;
begin
  Result := False;
  for var LPart in AValue.Split([';']) do
    if SameText(LPart.Trim, APath.Trim) then
      Exit(True);
end;

function AddPath(const AValue, APath: string): string;
begin
  Result := AValue.Trim;
  if APath.Trim.IsEmpty or ContainsPath(Result, APath) then
    Exit;
  if not Result.IsEmpty then
    Result := Result + ';';
  Result := Result + APath.Trim;
end;

function RemovePath(const AValue, APath: string): string;
var
  LParts: TList<string>;
begin
  LParts := TList<string>.Create;
  try
    for var LPart in AValue.Split([';']) do
      if not LPart.Trim.IsEmpty and not SameText(LPart.Trim, APath.Trim) then
        LParts.Add(LPart.Trim);
    Result := string.Join(';', LParts.ToArray);
  finally
    LParts.Free;
  end;
end;

function SameStrings(const ALeft, ARight: TList<string>): Boolean;
begin
  if ALeft.Count <> ARight.Count then
    Exit(False);
  for var I := 0 to ALeft.Count - 1 do
    if not SameText(ALeft[I], ARight[I]) then
      Exit(False);
  Result := True;
end;

function SameRegistryValues(
  const ALeft, ARight: TObjectList<TBoss4DIDEManagedRegistryValue>):
  Boolean;
begin
  if ALeft.Count <> ARight.Count then
    Exit(False);
  for var I := 0 to ALeft.Count - 1 do
    if not SameText(ALeft[I].Key, ARight[I].Key) or
       not SameText(ALeft[I].Name, ARight[I].Name) or
       (ALeft[I].Value <> ARight[I].Value) then
      Exit(False);
  Result := True;
end;

function SameRegistration(const ALeft,
  ARight: TBoss4DIDERegistration): Boolean;
begin
  Result := SameText(ALeft.Identity, ARight.Identity) and
    SameText(ALeft.OwnerPackage, ARight.OwnerPackage) and
    SameText(ALeft.Configuration, ARight.Configuration) and
    SameText(ALeft.BplPath, ARight.BplPath) and
    (ALeft.Description = ARight.Description) and
    SameText(ALeft.SearchPath, ARight.SearchPath) and
    SameText(ALeft.BrowsingPath, ARight.BrowsingPath) and
    SameText(ALeft.DebugDcuPath, ARight.DebugDcuPath) and
    SameText(ALeft.RuntimePath, ARight.RuntimePath) and
    SameText(ALeft.ToolPath, ARight.ToolPath) and
    SameText(ALeft.ArtifactRoot, ARight.ArtifactRoot) and
    SameStrings(ALeft.Artifacts, ARight.Artifacts) and
    SameStrings(ALeft.HelpFiles, ARight.HelpFiles) and
    SameRegistryValues(ALeft.RegistryValues, ARight.RegistryValues);
end;

function TBoss4DIDERegistrationService.PlanRegistration(
  const ARegistration: TBoss4DIDERegistration):
  TBoss4DIDERegistrationPlan;
var
  LPlan: TBoss4DIDERegistrationPlan;

  function ReadProjected(const AKey, AName: string;
    out AValue: string): Boolean;
  begin
    for var I := LPlan.Changes.Count - 1 downto 0 do
      if SameText(LPlan.Changes[I].Key, AKey) and
         SameText(LPlan.Changes[I].Name, AName) then
      begin
        AValue := LPlan.Changes[I].ProposedValue;
        Exit(LPlan.Changes[I].Kind =
          TBoss4DIDERegistryChangeKind.WriteValue);
      end;
    Result := FStore.TryRead(AKey, AName, AValue);
  end;

  procedure PlanWrite(const AKey, AName, AValue: string);
  begin
    var LCurrent := '';
    var LExists := FStore.TryRead(AKey, AName, LCurrent);
    for var I := LPlan.Changes.Count - 1 downto 0 do
      if SameText(LPlan.Changes[I].Key, AKey) and
         SameText(LPlan.Changes[I].Name, AName) then
      begin
        if LExists and (LCurrent = AValue) then
          LPlan.Changes.Delete(I)
        else
        begin
          LPlan.Changes[I].FKind :=
            TBoss4DIDERegistryChangeKind.WriteValue;
          LPlan.Changes[I].FProposedValue := AValue;
        end;
        Exit;
      end;
    if not LExists or (LCurrent <> AValue) then
      LPlan.Changes.Add(TBoss4DIDERegistryChange.Create(
        TBoss4DIDERegistryChangeKind.WriteValue, AKey, AName,
        LCurrent, AValue));
  end;

  procedure PlanDelete(const AKey, AName: string);
  begin
    var LCurrent := '';
    if FStore.TryRead(AKey, AName, LCurrent) then
      LPlan.Changes.Add(TBoss4DIDERegistryChange.Create(
        TBoss4DIDERegistryChangeKind.DeleteValue, AKey, AName,
        LCurrent, ''));
  end;

  procedure PlanPath(const AKey, AName, APath: string);
  begin
    if APath.Trim.IsEmpty then
      Exit;
    var LCurrent := '';
    ReadProjected(AKey, AName, LCurrent);
    PlanWrite(AKey, AName, AddPath(LCurrent, APath));
  end;

begin
  Validate(ARegistration);
  Result := TBoss4DIDERegistrationPlan.Create;
  LPlan := Result;
  try
    Result.Identity := ARegistration.Identity;
    if TBoss4DIDEProcessPolicy.Evaluate(FProcessProbe,
      FIDEExecutableName, ARegistration.IDEOpenPolicy) =
      TBoss4DIDEOpenDecision.Deferred then
      Result.Disposition := TBoss4DIDEPlanDisposition.Deferred;
    Result.InventoryChangeRequired := True;
    var LInventory := LoadInventory;
    try
      for var LInstalled in LInventory do
        if SameRegistration(LInstalled, ARegistration) then
        begin
          Result.InventoryChangeRequired := False;
          Break;
        end;
    finally
      LInventory.Free;
    end;
    for var LConflict in DetectConflicts(ARegistration) do
      Result.Conflicts.Add(LConflict);
    if Result.Conflicts.Count > 0 then
      case ARegistration.ConflictPolicy of
        TBoss4DIDEConflictPolicy.Fail:
          begin
            Result.Disposition := TBoss4DIDEPlanDisposition.Blocked;
            Exit;
          end;
        TBoss4DIDEConflictPolicy.Adopt:
          begin
            Result.Disposition := TBoss4DIDEPlanDisposition.Adopted;
            Exit;
          end;
      end;

    var LLibraryKey := LibraryKey(ARegistration);
    PlanPath(LLibraryKey, 'Search Path', ARegistration.SearchPath);
    PlanPath(LLibraryKey, 'Browsing Path', ARegistration.BrowsingPath);
    PlanPath(LLibraryKey, 'Debug DCU Path',
      ARegistration.DebugDcuPath);
    PlanPath('Environment', 'Path', ARegistration.RuntimePath);
    PlanPath('Environment', 'Path', ARegistration.ToolPath);
    for var LHelpFile in ARegistration.HelpFiles do
      PlanWrite(FRegistryRoot + '\' +
        ARegistration.Compiler + '\Help\HtmlHelp1Files',
        ARegistration.OwnerPackage + ':' + TPath.GetFileName(LHelpFile),
        TPath.GetFullPath(LHelpFile));
    for var LRegistryValue in ARegistration.RegistryValues do
      PlanWrite(LRegistryValue.Key, LRegistryValue.Name,
        LRegistryValue.Value);
    if ARegistration.ConflictPolicy =
      TBoss4DIDEConflictPolicy.Replace then
      for var LConflict in Result.Conflicts do
        PlanDelete(LConflict.RegistryKey, LConflict.ExistingPath);
    PlanDelete(IDEPackageKey(ARegistration), ARegistration.BplPath);
    PlanWrite(PackageKey(ARegistration), ARegistration.BplPath,
      ARegistration.Description);
  except
    Result.Free;
    raise;
  end;
end;

constructor TBoss4DIDERegistrationService.Create(
  const AStore: IBoss4DIDERegistryStore; const AInventoryPath: string;
  const AArtifactRepairHandler: TBoss4DIDEArtifactRepairHandler;
  const AOperationLock: IBoss4DIDEOperationLock;
  const AProfileName: string;
  const ALockTimeoutMilliseconds: Cardinal;
  const AProcessProbe: IBoss4DIDEProcessProbe;
  const AIDEExecutableName: string;
  const ARegistryRoot: string);
begin
  inherited Create;
  if not Assigned(AStore) then
    raise EArgumentNilException.Create('AStore');
  if AInventoryPath.Trim.IsEmpty then
    raise EArgumentException.Create('Inventory path nao pode ser vazio.');
  if AProfileName.Trim.IsEmpty then
    raise EArgumentException.Create('Profile name nao pode ser vazio.');
  FStore := AStore;
  FInventoryPath := AInventoryPath;
  FArtifactRepairHandler := AArtifactRepairHandler;
  FOperationLock := AOperationLock;
  if not Assigned(FOperationLock) then
    FOperationLock := TBoss4DFileIDEOperationLock.Create(
      TPath.Combine(TPath.GetDirectoryName(FInventoryPath), '.ide-locks'));
  FProfileName := AProfileName.Trim;
  FLockTimeoutMilliseconds := ALockTimeoutMilliseconds;
  FProcessProbe := AProcessProbe;
  if not Assigned(FProcessProbe) then
    FProcessProbe := TBoss4DWindowsIDEProcessProbe.Create;
  FIDEExecutableName := AIDEExecutableName.Trim;
  if FIDEExecutableName.IsEmpty then
    raise EArgumentException.Create(
      'IDE executable name nao pode ser vazio.');
  FRegistryRoot := ARegistryRoot.Trim;
  while FRegistryRoot.EndsWith('\') do
    Delete(FRegistryRoot, Length(FRegistryRoot), 1);
  if FRegistryRoot.IsEmpty or FRegistryRoot.Contains('..') or
     not FRegistryRoot.StartsWith('Software\Embarcadero\', True) then
    raise EArgumentException.Create(
      'Registry root do perfil IDE invalido.');
end;

function TBoss4DIDERegistrationService.LibraryKey(
  const ARegistration: TBoss4DIDERegistration): string;
begin
  Result := FRegistryRoot + '\' + ARegistration.Compiler +
    '\Library\' + ARegistration.Platform;
end;

function TBoss4DIDERegistrationService.PackageKey(
  const ARegistration: TBoss4DIDERegistration): string;
begin
  Result := FRegistryRoot + '\' + ARegistration.Compiler +
    '\Known Packages';
end;

function TBoss4DIDERegistrationService.IDEPackageKey(
  const ARegistration: TBoss4DIDERegistration): string;
begin
  Result := FRegistryRoot + '\' + ARegistration.Compiler +
    '\Known IDE Packages';
end;

procedure TBoss4DIDERegistrationService.Validate(
  const ARegistration: TBoss4DIDERegistration);
begin
  if not Assigned(ARegistration) then
    raise EArgumentNilException.Create('ARegistration');
  ARegistration.RegistryRoot := FRegistryRoot;
  if ARegistration.PackageName.Trim.IsEmpty then
    raise EArgumentException.Create('PackageName nao pode ser vazio.');
  var LConvention := TBoss4DBuildConventions.ResolveCompiler(
    ARegistration.Compiler);
  if not SameText(LConvention.BDSVersion, ARegistration.Compiler) then
    raise EArgumentException.CreateFmt(
      'O registro IDE exige a versao BDS canonica; use %s em vez de %s.',
      [LConvention.BDSVersion, ARegistration.Compiler]);
  if not SameText(ARegistration.Platform, 'Win32') and
     not SameText(ARegistration.Platform, 'Win64') then
    raise EArgumentException.CreateFmt(
      'Plataforma IDE nao suportada: %s.', [ARegistration.Platform]);
  if ARegistration.BplPath.Trim.IsEmpty then
    raise EArgumentException.Create('BplPath nao pode ser vazio.');
  var LAllowedPrefix := FRegistryRoot + '\' +
    ARegistration.Compiler + '\';
  for var LRegistryValue in ARegistration.RegistryValues do
  begin
    var LDefaultPrefix := 'Software\Embarcadero\BDS\' +
      ARegistration.Compiler + '\';
    if not LRegistryValue.Key.StartsWith(LAllowedPrefix, True) and
       LRegistryValue.Key.StartsWith(LDefaultPrefix, True) then
      LRegistryValue.Key := LAllowedPrefix +
        LRegistryValue.Key.Substring(LDefaultPrefix.Length);
    if not LRegistryValue.Key.StartsWith(LAllowedPrefix, True) then
      raise EArgumentException.CreateFmt(
        'Chave de Registro IDE fora do escopo HKCU permitido: %s.',
        [LRegistryValue.Key]);
    if LRegistryValue.Name.Trim.IsEmpty then
      raise EArgumentException.Create(
        'Nome de valor de Registro IDE nao pode ser vazio.');
  end;
end;

function TBoss4DIDERegistrationService.LoadInventory:
  TObjectList<TBoss4DIDERegistration>;
var
  LRoot: TJSONObject;
  LItems: TJSONArray;
begin
  Result := TObjectList<TBoss4DIDERegistration>.Create(True);
  if not TFile.Exists(FInventoryPath) then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(TFile.ReadAllText(FInventoryPath,
    TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LRoot) then
    raise EBoss4DIDERegistrationError.Create(
      'Inventario de registro IDE invalido.');
  try
    LItems := LRoot.GetValue<TJSONArray>('registrations');
    if not Assigned(LItems) then
      Exit;
    for var I := 0 to LItems.Count - 1 do
    begin
      if not (LItems[I] is TJSONObject) then
        Continue;
      var LObject := TJSONObject(LItems[I]);
      var LRegistration := TBoss4DIDERegistration.Create;
      LRegistration.PackageName := LObject.GetValue<string>('package', '');
      LRegistration.OwnerPackage := LObject.GetValue<string>(
        'ownerPackage', '');
      LRegistration.Compiler := LObject.GetValue<string>('compiler', '');
      LRegistration.Platform := LObject.GetValue<string>('platform', '');
      LRegistration.Configuration := LObject.GetValue<string>(
        'configuration', '');
      LRegistration.RegistryRoot := LObject.GetValue<string>(
        'registryRoot', FRegistryRoot);
      LRegistration.BplPath := LObject.GetValue<string>('bpl', '');
      LRegistration.Description := LObject.GetValue<string>(
        'description', '');
      LRegistration.SearchPath := LObject.GetValue<string>('searchPath', '');
      LRegistration.BrowsingPath := LObject.GetValue<string>(
        'browsingPath', '');
      LRegistration.DebugDcuPath := LObject.GetValue<string>(
        'debugDcuPath', '');
      LRegistration.RuntimePath := LObject.GetValue<string>(
        'runtimePath', '');
      LRegistration.ToolPath := LObject.GetValue<string>('toolPath', '');
      LRegistration.ArtifactRoot := LObject.GetValue<string>(
        'artifactRoot', '');
      var LArtifacts := LObject.GetValue<TJSONArray>('artifacts');
      if Assigned(LArtifacts) then
        for var J := 0 to LArtifacts.Count - 1 do
          LRegistration.Artifacts.Add(LArtifacts.Items[J].Value);
      var LHelpFiles := LObject.GetValue<TJSONArray>('helpFiles');
      if Assigned(LHelpFiles) then
        for var J := 0 to LHelpFiles.Count - 1 do
          LRegistration.HelpFiles.Add(LHelpFiles.Items[J].Value);
      var LRegistryValues := LObject.GetValue<TJSONArray>('registryValues');
      if Assigned(LRegistryValues) then
        for var J := 0 to LRegistryValues.Count - 1 do
          if LRegistryValues.Items[J] is TJSONObject then
          begin
            var LRegistryObject := TJSONObject(LRegistryValues.Items[J]);
            var LRegistryValue := TBoss4DIDEManagedRegistryValue.Create;
            LRegistryValue.Key := LRegistryObject.GetValue<string>('key', '');
            LRegistryValue.Name := LRegistryObject.GetValue<string>(
              'name', '');
            LRegistryValue.Value := LRegistryObject.GetValue<string>(
              'value', '');
            LRegistration.RegistryValues.Add(LRegistryValue);
          end;
      LRegistration.ConflictPolicy := TBoss4DIDEConflictPolicy(
        LObject.GetValue<Integer>('conflictPolicy', 0));
      var LDisplacedValues := LObject.GetValue<TJSONArray>(
        'displacedRegistryValues');
      if Assigned(LDisplacedValues) then
        for var J := 0 to LDisplacedValues.Count - 1 do
          if LDisplacedValues.Items[J] is TJSONObject then
          begin
            var LDisplacedObject := TJSONObject(LDisplacedValues.Items[J]);
            var LDisplacedValue := TBoss4DIDEManagedRegistryValue.Create;
            LDisplacedValue.Key := LDisplacedObject.GetValue<string>(
              'key', '');
            LDisplacedValue.Name := LDisplacedObject.GetValue<string>(
              'name', '');
            LDisplacedValue.Value := LDisplacedObject.GetValue<string>(
              'value', '');
            LRegistration.DisplacedRegistryValues.Add(LDisplacedValue);
          end;
      Result.Add(LRegistration);
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TBoss4DIDERegistrationService.SaveInventory(
  const AInventory: TObjectList<TBoss4DIDERegistration>);
var
  LRoot: TJSONObject;
  LItems: TJSONArray;
  LEncoding: TEncoding;
  LTempPath: string;
  LBackupPath: string;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(4));
    LItems := TJSONArray.Create;
    for var LRegistration in AInventory do
    begin
      var LObject := TJSONObject.Create;
      LObject.AddPair('package', LRegistration.PackageName);
      LObject.AddPair('ownerPackage', LRegistration.OwnerPackage);
      LObject.AddPair('compiler', LRegistration.Compiler);
      LObject.AddPair('platform', LRegistration.Platform);
      LObject.AddPair('configuration', LRegistration.Configuration);
      LObject.AddPair('registryRoot', LRegistration.RegistryRoot);
      LObject.AddPair('bpl', LRegistration.BplPath);
      LObject.AddPair('description', LRegistration.Description);
      LObject.AddPair('searchPath', LRegistration.SearchPath);
      LObject.AddPair('browsingPath', LRegistration.BrowsingPath);
      LObject.AddPair('debugDcuPath', LRegistration.DebugDcuPath);
      LObject.AddPair('runtimePath', LRegistration.RuntimePath);
      LObject.AddPair('toolPath', LRegistration.ToolPath);
      LObject.AddPair('artifactRoot', LRegistration.ArtifactRoot);
      var LArtifacts := TJSONArray.Create;
      for var LArtifact in LRegistration.Artifacts do
        LArtifacts.Add(LArtifact);
      LObject.AddPair('artifacts', LArtifacts);
      var LHelpFiles := TJSONArray.Create;
      for var LHelpFile in LRegistration.HelpFiles do
        LHelpFiles.Add(LHelpFile);
      LObject.AddPair('helpFiles', LHelpFiles);
      var LRegistryValues := TJSONArray.Create;
      for var LRegistryValue in LRegistration.RegistryValues do
      begin
        var LRegistryObject := TJSONObject.Create;
        LRegistryObject.AddPair('key', LRegistryValue.Key);
        LRegistryObject.AddPair('name', LRegistryValue.Name);
        LRegistryObject.AddPair('value', LRegistryValue.Value);
        LRegistryValues.AddElement(LRegistryObject);
      end;
      LObject.AddPair('registryValues', LRegistryValues);
      LObject.AddPair('conflictPolicy', TJSONNumber.Create(
        Ord(LRegistration.ConflictPolicy)));
      var LDisplacedValues := TJSONArray.Create;
      for var LDisplacedValue in
        LRegistration.DisplacedRegistryValues do
      begin
        var LDisplacedObject := TJSONObject.Create;
        LDisplacedObject.AddPair('key', LDisplacedValue.Key);
        LDisplacedObject.AddPair('name', LDisplacedValue.Name);
        LDisplacedObject.AddPair('value', LDisplacedValue.Value);
        LDisplacedValues.AddElement(LDisplacedObject);
      end;
      LObject.AddPair('displacedRegistryValues', LDisplacedValues);
      LItems.AddElement(LObject);
    end;
    LRoot.AddPair('registrations', LItems);
    var LDirectory := TPath.GetDirectoryName(FInventoryPath);
    if not LDirectory.IsEmpty then
      TDirectory.CreateDirectory(LDirectory);
    LTempPath := FInventoryPath + '.tmp';
    LEncoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(LTempPath, LRoot.Format(2), LEncoding);
    finally
      LEncoding.Free;
    end;
    if TFile.Exists(FInventoryPath) then
    begin
      LBackupPath := FInventoryPath + '.bak';
      if TFile.Exists(LBackupPath) then
        TFile.Delete(LBackupPath);
      TFile.Replace(LTempPath, FInventoryPath, LBackupPath);
      if TFile.Exists(LBackupPath) then
        TFile.Delete(LBackupPath);
    end
    else
      TFile.Move(LTempPath, FInventoryPath);
  finally
    LRoot.Free;
  end;
end;

procedure TakeSnapshot(const AStore: IBoss4DIDERegistryStore;
  const AKey, AName: string;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>);
begin
  var LSnapshot := TBoss4DRegistrySnapshot.Create;
  LSnapshot.FKey := AKey;
  LSnapshot.FName := AName;
  LSnapshot.FExisted := AStore.TryRead(AKey, AName, LSnapshot.FValue);
  ASnapshots.Add(LSnapshot);
end;

procedure Rollback(const AStore: IBoss4DIDERegistryStore;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>);
begin
  for var I := ASnapshots.Count - 1 downto 0 do
    if ASnapshots[I].FExisted then
      AStore.WriteValue(ASnapshots[I].FKey, ASnapshots[I].FName,
        ASnapshots[I].FValue)
    else
      AStore.DeleteValue(ASnapshots[I].FKey, ASnapshots[I].FName);
end;

procedure WritePathValue(const AStore: IBoss4DIDERegistryStore;
  const AKey, AName, APath: string;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>);
var
  LCurrent: string;
begin
  if APath.Trim.IsEmpty then
    Exit;
  TakeSnapshot(AStore, AKey, AName, ASnapshots);
  if not AStore.TryRead(AKey, AName, LCurrent) then
    LCurrent := '';
  AStore.WriteValue(AKey, AName, AddPath(LCurrent, APath));
end;

procedure ApplyRegistration(const AStore: IBoss4DIDERegistryStore;
  const ARegistration: TBoss4DIDERegistration;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>);
var
  LLibraryKey: string;
  LPackageKey: string;
  LIDEPackageKey: string;
begin
  LLibraryKey := ARegistration.RegistryRoot + '\' + ARegistration.Compiler +
    '\Library\' + ARegistration.Platform;
  LPackageKey := ARegistration.RegistryRoot + '\' + ARegistration.Compiler +
    '\Known Packages';
  LIDEPackageKey := ARegistration.RegistryRoot + '\' + ARegistration.Compiler +
    '\Known IDE Packages';
  WritePathValue(AStore, LLibraryKey, 'Search Path',
    ARegistration.SearchPath, ASnapshots);
  WritePathValue(AStore, LLibraryKey, 'Browsing Path',
    ARegistration.BrowsingPath, ASnapshots);
  WritePathValue(AStore, LLibraryKey, 'Debug DCU Path',
    ARegistration.DebugDcuPath, ASnapshots);
  WritePathValue(AStore, 'Environment', 'Path',
    ARegistration.RuntimePath, ASnapshots);
  WritePathValue(AStore, 'Environment', 'Path',
    ARegistration.ToolPath, ASnapshots);
  for var LHelpFile in ARegistration.HelpFiles do
  begin
    var LHelpKey := ARegistration.RegistryRoot + '\' +
      ARegistration.Compiler + '\Help\HtmlHelp1Files';
    var LHelpName := ARegistration.OwnerPackage + ':' +
      TPath.GetFileName(LHelpFile);
    TakeSnapshot(AStore, LHelpKey, LHelpName, ASnapshots);
    AStore.WriteValue(LHelpKey, LHelpName, TPath.GetFullPath(LHelpFile));
  end;
  for var LRegistryValue in ARegistration.RegistryValues do
  begin
    TakeSnapshot(AStore, LRegistryValue.Key, LRegistryValue.Name, ASnapshots);
    AStore.WriteValue(LRegistryValue.Key, LRegistryValue.Name,
      LRegistryValue.Value);
  end;
  for var LDisplacedValue in ARegistration.DisplacedRegistryValues do
  begin
    TakeSnapshot(AStore, LDisplacedValue.Key, LDisplacedValue.Name,
      ASnapshots);
    AStore.DeleteValue(LDisplacedValue.Key, LDisplacedValue.Name);
  end;
  TakeSnapshot(AStore, LIDEPackageKey, ARegistration.BplPath, ASnapshots);
  AStore.DeleteValue(LIDEPackageKey, ARegistration.BplPath);
  TakeSnapshot(AStore, LPackageKey, ARegistration.BplPath, ASnapshots);
  AStore.WriteValue(LPackageKey, ARegistration.BplPath,
    ARegistration.Description);
end;

procedure RemovePathValue(const AStore: IBoss4DIDERegistryStore;
  const AKey, AName, APath: string;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>); forward;

procedure RemoveRegistration(const AStore: IBoss4DIDERegistryStore;
  const ARegistration: TBoss4DIDERegistration;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>);
var
  LLibraryKey: string;
  LPackageKey: string;
  LIDEPackageKey: string;
begin
  LLibraryKey := ARegistration.RegistryRoot + '\' + ARegistration.Compiler +
    '\Library\' + ARegistration.Platform;
  LPackageKey := ARegistration.RegistryRoot + '\' + ARegistration.Compiler +
    '\Known Packages';
  LIDEPackageKey := ARegistration.RegistryRoot + '\' + ARegistration.Compiler +
    '\Known IDE Packages';
  RemovePathValue(AStore, LLibraryKey, 'Search Path',
    ARegistration.SearchPath, ASnapshots);
  RemovePathValue(AStore, LLibraryKey, 'Browsing Path',
    ARegistration.BrowsingPath, ASnapshots);
  RemovePathValue(AStore, LLibraryKey, 'Debug DCU Path',
    ARegistration.DebugDcuPath, ASnapshots);
  RemovePathValue(AStore, 'Environment', 'Path',
    ARegistration.RuntimePath, ASnapshots);
  RemovePathValue(AStore, 'Environment', 'Path',
    ARegistration.ToolPath, ASnapshots);
  for var LHelpFile in ARegistration.HelpFiles do
  begin
    var LHelpKey := ARegistration.RegistryRoot + '\' +
      ARegistration.Compiler + '\Help\HtmlHelp1Files';
    var LHelpName := ARegistration.OwnerPackage + ':' +
      TPath.GetFileName(LHelpFile);
    TakeSnapshot(AStore, LHelpKey, LHelpName, ASnapshots);
    AStore.DeleteValue(LHelpKey, LHelpName);
  end;
  for var LRegistryValue in ARegistration.RegistryValues do
  begin
    TakeSnapshot(AStore, LRegistryValue.Key, LRegistryValue.Name, ASnapshots);
    AStore.DeleteValue(LRegistryValue.Key, LRegistryValue.Name);
  end;
  TakeSnapshot(AStore, LPackageKey, ARegistration.BplPath, ASnapshots);
  AStore.DeleteValue(LPackageKey, ARegistration.BplPath);
  TakeSnapshot(AStore, LIDEPackageKey, ARegistration.BplPath, ASnapshots);
  AStore.DeleteValue(LIDEPackageKey, ARegistration.BplPath);
  for var LDisplacedValue in ARegistration.DisplacedRegistryValues do
  begin
    TakeSnapshot(AStore, LDisplacedValue.Key, LDisplacedValue.Name,
      ASnapshots);
    AStore.WriteValue(LDisplacedValue.Key, LDisplacedValue.Name,
      LDisplacedValue.Value);
  end;
end;

procedure TBoss4DIDERegistrationService.RegisterTarget(
  const ARegistration: TBoss4DIDERegistration);
var
  LRegistrations: TObjectList<TBoss4DIDERegistration>;
begin
  if not Assigned(ARegistration) then
    raise EArgumentNilException.Create('ARegistration');
  LRegistrations := TObjectList<TBoss4DIDERegistration>.Create(False);
  try
    LRegistrations.Add(ARegistration);
    RegisterTargets(LRegistrations);
  finally
    LRegistrations.Free;
  end;
end;

function TBoss4DIDERegistrationService.RegisterTargets(
  const ARegistrations: TObjectList<TBoss4DIDERegistration>): Integer;
var
  LCompilers: TList<string>;
  LLeases: TList<IBoss4DIDEOperationLease>;
  LPlans: TObjectList<TBoss4DIDERegistrationPlan>;
  LEffective: TObjectList<TBoss4DIDERegistration>;
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
  LInventory: TObjectList<TBoss4DIDERegistration>;
begin
  if not Assigned(ARegistrations) then
    raise EArgumentNilException.Create('ARegistrations');
  Result := 0;
  LCompilers := TList<string>.Create;
  LLeases := TList<IBoss4DIDEOperationLease>.Create;
  LPlans := TObjectList<TBoss4DIDERegistrationPlan>.Create(True);
  LEffective := TObjectList<TBoss4DIDERegistration>.Create(True);
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  LInventory := nil;
  try
    for var LRegistration in ARegistrations do
    begin
      Validate(LRegistration);
      if not LCompilers.Contains(LRegistration.Compiler) then
        LCompilers.Add(LRegistration.Compiler);
    end;
    LCompilers.Sort;
    for var LCompiler in LCompilers do
      LLeases.Add(FOperationLock.Acquire(FProfileName, LCompiler,
        FLockTimeoutMilliseconds));

    for var LRegistration in ARegistrations do
    begin
      var LPlan := PlanRegistration(LRegistration);
      LPlans.Add(LPlan);
      if LPlan.Disposition = TBoss4DIDEPlanDisposition.Blocked then
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Conflito de pacote IDE: %s ja esta registrado em %s.',
          [TPath.GetFileName(LRegistration.BplPath),
           LPlan.Conflicts[0].ExistingPath]);
      if (LPlan.Disposition in [
           TBoss4DIDEPlanDisposition.Adopted,
           TBoss4DIDEPlanDisposition.Deferred]) or LPlan.IsNoOp then
        Continue;
      var LEffectiveRegistration := LRegistration.Clone;
      LEffective.Add(LEffectiveRegistration);
      if LRegistration.ConflictPolicy =
        TBoss4DIDEConflictPolicy.Replace then
        for var LConflict in LPlan.Conflicts do
        begin
          var LDisplacedValue := TBoss4DIDEManagedRegistryValue.Create;
          LDisplacedValue.Key := LConflict.RegistryKey;
          LDisplacedValue.Name := LConflict.ExistingPath;
          LDisplacedValue.Value := LConflict.Description;
          LEffectiveRegistration.DisplacedRegistryValues.Add(
            LDisplacedValue);
        end;
    end;
    if LEffective.Count = 0 then
      Exit;

    try
      LInventory := LoadInventory;
      for var LRegistration in LEffective do
      begin
        for var I := LInventory.Count - 1 downto 0 do
          if SameText(LInventory[I].Identity,
            LRegistration.Identity) then
          begin
            RemoveRegistration(FStore, LInventory[I], LSnapshots);
            LInventory.Delete(I);
          end;
        ApplyRegistration(FStore, LRegistration, LSnapshots);
        LInventory.Add(LRegistration.Clone);
        Inc(Result);
      end;
      SaveInventory(LInventory);
    except
      on E: Exception do
      begin
        Rollback(FStore, LSnapshots);
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Falha ao registrar lote de targets IDE: %s', [E.Message]);
      end;
    end;
  finally
    LInventory.Free;
    LSnapshots.Free;
    LEffective.Free;
    LPlans.Free;
    LLeases.Free;
    LCompilers.Free;
  end;
end;

procedure RemovePathValue(const AStore: IBoss4DIDERegistryStore;
  const AKey, AName, APath: string;
  const ASnapshots: TObjectList<TBoss4DRegistrySnapshot>);
var
  LCurrent: string;
  LUpdated: string;
begin
  if APath.Trim.IsEmpty or not AStore.TryRead(AKey, AName, LCurrent) then
    Exit;
  TakeSnapshot(AStore, AKey, AName, ASnapshots);
  LUpdated := RemovePath(LCurrent, APath);
  if LUpdated.IsEmpty then
    AStore.DeleteValue(AKey, AName)
  else
    AStore.WriteValue(AKey, AName, LUpdated);
end;

procedure RestoreStagedArtifacts(
  const AStagedFiles: TDictionary<string, string>);
begin
  for var LPair in AStagedFiles do
    if TFile.Exists(LPair.Value) then
    begin
      TDirectory.CreateDirectory(TPath.GetDirectoryName(LPair.Key));
      TFile.Move(LPair.Value, LPair.Key);
    end;
end;

function TBoss4DIDERegistrationService.PlanRemoval(
  const AName, ACompiler, APlatform: string;
  const AByOwner: Boolean): TBoss4DIDERemovalPlan;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LPlan: TBoss4DIDERemovalPlan;

  function Selected(const ARegistration: TBoss4DIDERegistration): Boolean;
  begin
    if AByOwner then
      Result := SameText(ARegistration.OwnerPackage, AName)
    else
      Result := SameText(ARegistration.PackageName, AName);
    Result := Result and
      (ACompiler.IsEmpty or SameText(ARegistration.Compiler, ACompiler)) and
      (APlatform.IsEmpty or SameText(ARegistration.Platform, APlatform));
  end;

  function PathUsedOutsideSelection(
    const ARegistration: TBoss4DIDERegistration;
    const APath, AKind: string): Boolean;
  begin
    Result := False;
    if APath.Trim.IsEmpty then
      Exit;
    for var LOther in LInventory do
    begin
      if Selected(LOther) or
         not SameText(LOther.Compiler, ARegistration.Compiler) or
         not SameText(LOther.Platform, ARegistration.Platform) then
        Continue;
      if (SameText(AKind, 'search') and
          SameText(LOther.SearchPath, APath)) or
         (SameText(AKind, 'browsing') and
          SameText(LOther.BrowsingPath, APath)) or
         (SameText(AKind, 'debug') and
          SameText(LOther.DebugDcuPath, APath)) or
         (SameText(AKind, 'runtime') and
          SameText(LOther.RuntimePath, APath)) or
         (SameText(AKind, 'tool') and
          SameText(LOther.ToolPath, APath)) then
        Exit(True);
    end;
  end;

  function ArtifactUsedOutsideSelection(const AArtifact: string): Boolean;
  begin
    Result := False;
    for var LOther in LInventory do
      if not Selected(LOther) then
        for var LOtherArtifact in LOther.Artifacts do
          if SameText(TPath.GetFullPath(LOtherArtifact),
            TPath.GetFullPath(AArtifact)) then
            Exit(True);
  end;

  function FindChange(const AKey, AValueName: string): Integer;
  begin
    for var I := LPlan.Changes.Count - 1 downto 0 do
      if SameText(LPlan.Changes[I].Key, AKey) and
         SameText(LPlan.Changes[I].Name, AValueName) then
        Exit(I);
    Result := -1;
  end;

  function ReadProjected(const AKey, AValueName: string;
    out AValue: string): Boolean;
  begin
    var LIndex := FindChange(AKey, AValueName);
    if LIndex >= 0 then
    begin
      AValue := LPlan.Changes[LIndex].ProposedValue;
      Exit(LPlan.Changes[LIndex].Kind =
        TBoss4DIDERegistryChangeKind.WriteValue);
    end;
    Result := FStore.TryRead(AKey, AValueName, AValue);
  end;

  procedure PlanWrite(const AKey, AValueName, AValue: string);
  begin
    var LOriginal := '';
    var LExisted := FStore.TryRead(AKey, AValueName, LOriginal);
    var LIndex := FindChange(AKey, AValueName);
    if LIndex >= 0 then
    begin
      if LExisted and (LOriginal = AValue) then
        LPlan.Changes.Delete(LIndex)
      else
      begin
        LPlan.Changes[LIndex].FKind :=
          TBoss4DIDERegistryChangeKind.WriteValue;
        LPlan.Changes[LIndex].FProposedValue := AValue;
      end;
      Exit;
    end;
    if not LExisted or (LOriginal <> AValue) then
      LPlan.Changes.Add(TBoss4DIDERegistryChange.Create(
        TBoss4DIDERegistryChangeKind.WriteValue, AKey, AValueName,
        LOriginal, AValue));
  end;

  procedure PlanDelete(const AKey, AValueName: string);
  begin
    var LOriginal := '';
    if not FStore.TryRead(AKey, AValueName, LOriginal) then
      Exit;
    var LIndex := FindChange(AKey, AValueName);
    if LIndex >= 0 then
    begin
      LPlan.Changes[LIndex].FKind :=
        TBoss4DIDERegistryChangeKind.DeleteValue;
      LPlan.Changes[LIndex].FProposedValue := '';
    end
    else
      LPlan.Changes.Add(TBoss4DIDERegistryChange.Create(
        TBoss4DIDERegistryChangeKind.DeleteValue, AKey, AValueName,
        LOriginal, ''));
  end;

  procedure PlanRemovePath(const AKey, AValueName, APath: string);
  begin
    if APath.Trim.IsEmpty then
      Exit;
    var LCurrent := '';
    if not ReadProjected(AKey, AValueName, LCurrent) then
      Exit;
    var LUpdated := RemovePath(LCurrent, APath);
    if LUpdated.IsEmpty then
      PlanDelete(AKey, AValueName)
    else
      PlanWrite(AKey, AValueName, LUpdated);
  end;

begin
  if AName.Trim.IsEmpty then
    raise EArgumentException.Create(
      'O package ou produto para remocao e obrigatorio.');
  Result := TBoss4DIDERemovalPlan.Create;
  LPlan := Result;
  LInventory := LoadInventory;
  try
    for var LRegistration in LInventory do
    begin
      if not Selected(LRegistration) then
        Continue;
      LPlan.Targets.Add(LRegistration.Identity);
      if not PathUsedOutsideSelection(LRegistration,
        LRegistration.SearchPath, 'search') then
        PlanRemovePath(LibraryKey(LRegistration), 'Search Path',
          LRegistration.SearchPath);
      if not PathUsedOutsideSelection(LRegistration,
        LRegistration.BrowsingPath, 'browsing') then
        PlanRemovePath(LibraryKey(LRegistration), 'Browsing Path',
          LRegistration.BrowsingPath);
      if not PathUsedOutsideSelection(LRegistration,
        LRegistration.DebugDcuPath, 'debug') then
        PlanRemovePath(LibraryKey(LRegistration), 'Debug DCU Path',
          LRegistration.DebugDcuPath);
      if not PathUsedOutsideSelection(LRegistration,
        LRegistration.RuntimePath, 'runtime') then
        PlanRemovePath('Environment', 'Path',
          LRegistration.RuntimePath);
      if not PathUsedOutsideSelection(LRegistration,
        LRegistration.ToolPath, 'tool') then
        PlanRemovePath('Environment', 'Path',
          LRegistration.ToolPath);
      PlanDelete(PackageKey(LRegistration), LRegistration.BplPath);
      PlanDelete(IDEPackageKey(LRegistration), LRegistration.BplPath);
      for var LHelpFile in LRegistration.HelpFiles do
        PlanDelete(FRegistryRoot + '\' +
          LRegistration.Compiler + '\Help\HtmlHelp1Files',
          LRegistration.OwnerPackage + ':' + TPath.GetFileName(LHelpFile));
      for var LRegistryValue in LRegistration.RegistryValues do
        PlanDelete(LRegistryValue.Key, LRegistryValue.Name);
      for var LDisplacedValue in
        LRegistration.DisplacedRegistryValues do
        PlanWrite(LDisplacedValue.Key, LDisplacedValue.Name,
          LDisplacedValue.Value);
      if not LRegistration.ArtifactRoot.Trim.IsEmpty then
      begin
        var LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(
          LRegistration.ArtifactRoot));
        for var LDeclaredArtifact in LRegistration.Artifacts do
        begin
          var LArtifact := TPath.GetFullPath(LDeclaredArtifact);
          if not LArtifact.StartsWith(LRoot, True) then
            raise EBoss4DIDERegistrationError.CreateFmt(
              'Artefato gerenciado fora da raiz permitida: %s.',
              [LArtifact]);
          if TFile.Exists(LArtifact) and
             not ArtifactUsedOutsideSelection(LArtifact) and
             not LPlan.Files.Contains(LArtifact) then
            LPlan.Files.Add(LArtifact);
        end;
      end;
    end;
    LPlan.Targets.Sort;
    LPlan.Files.Sort;
    LPlan.Changes.Sort(
      TComparer<TBoss4DIDERegistryChange>.Construct(
        function(const ALeft, ARight: TBoss4DIDERegistryChange): Integer
        begin
          Result := CompareText(ALeft.Key + '|' + ALeft.Name,
            ARight.Key + '|' + ARight.Name);
        end));
  except
    LInventory.Free;
    Result.Free;
    raise;
  end;
  LInventory.Free;
end;

function TBoss4DIDERegistrationService.RemoveMatching(
  const AName, ACompiler, APlatform: string;
  const AByOwner: Boolean): Integer;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
  LStagedFiles: TDictionary<string, string>;
  LStagingDirectory: string;
  LCompilers: TList<string>;
  LLeases: TList<IBoss4DIDEOperationLease>;

  function Selected(const ARegistration: TBoss4DIDERegistration): Boolean;
  begin
    if AByOwner then
      Result := SameText(ARegistration.OwnerPackage, AName)
    else
      Result := SameText(ARegistration.PackageName, AName);
    Result := Result and
      (ACompiler.IsEmpty or SameText(ARegistration.Compiler, ACompiler)) and
      (APlatform.IsEmpty or SameText(ARegistration.Platform, APlatform));
  end;

  function PathUsedOutsideSelection(
    const ARegistration: TBoss4DIDERegistration;
    const APath, AKind: string): Boolean;
  begin
    Result := False;
    if APath.Trim.IsEmpty then
      Exit;
    for var LOther in LInventory do
    begin
      if Selected(LOther) or
         not SameText(LOther.Compiler, ARegistration.Compiler) or
         not SameText(LOther.Platform, ARegistration.Platform) then
        Continue;
      if (SameText(AKind, 'search') and
          SameText(LOther.SearchPath, APath)) or
         (SameText(AKind, 'browsing') and
          SameText(LOther.BrowsingPath, APath)) or
         (SameText(AKind, 'debug') and
          SameText(LOther.DebugDcuPath, APath)) or
         (SameText(AKind, 'runtime') and
          SameText(LOther.RuntimePath, APath)) or
         (SameText(AKind, 'tool') and
          SameText(LOther.ToolPath, APath)) then
        Exit(True);
    end;
  end;

  function ArtifactUsedOutsideSelection(const AArtifact: string): Boolean;
  begin
    Result := False;
    for var LOther in LInventory do
    begin
      if Selected(LOther) then
        Continue;
      for var LOtherArtifact in LOther.Artifacts do
        if SameText(TPath.GetFullPath(LOtherArtifact),
          TPath.GetFullPath(AArtifact)) then
          Exit(True);
    end;
  end;

  procedure StageArtifacts(const ARegistration: TBoss4DIDERegistration);
  begin
    if ARegistration.ArtifactRoot.Trim.IsEmpty then
      Exit;
    var LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(
      ARegistration.ArtifactRoot));
    for var LDeclaredArtifact in ARegistration.Artifacts do
    begin
      var LArtifact := TPath.GetFullPath(LDeclaredArtifact);
      if not LArtifact.StartsWith(LRoot, True) then
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Artefato gerenciado fora da raiz permitida: %s.', [LArtifact]);
      if LStagedFiles.ContainsKey(LArtifact) or
         not TFile.Exists(LArtifact) or
         ArtifactUsedOutsideSelection(LArtifact) then
        Continue;
      TDirectory.CreateDirectory(LStagingDirectory);
      var LStaged := TPath.Combine(LStagingDirectory,
        TGUID.NewGuid.ToString + TPath.GetExtension(LArtifact));
      TFile.Move(LArtifact, LStaged);
      LStagedFiles.Add(LArtifact, LStaged);
    end;
  end;

begin
  Result := 0;
  LInventory := LoadInventory;
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  LStagedFiles := TDictionary<string, string>.Create;
  LCompilers := TList<string>.Create;
  LLeases := TList<IBoss4DIDEOperationLease>.Create;
  LStagingDirectory := FInventoryPath + '.uninstall-' +
    TGUID.NewGuid.ToString;
  try
    for var LRegistration in LInventory do
      if Selected(LRegistration) and
         not LCompilers.Contains(LRegistration.Compiler) then
        LCompilers.Add(LRegistration.Compiler);
    LCompilers.Sort;
    for var LCompiler in LCompilers do
      LLeases.Add(FOperationLock.Acquire(FProfileName, LCompiler,
        FLockTimeoutMilliseconds));
    try
      for var LRegistration in LInventory do
        if Selected(LRegistration) then
          StageArtifacts(LRegistration);
      for var I := LInventory.Count - 1 downto 0 do
      begin
        var LRegistration := LInventory[I];
        if not Selected(LRegistration) then
          Continue;
        if not PathUsedOutsideSelection(LRegistration,
          LRegistration.SearchPath, 'search') then
          RemovePathValue(FStore, LibraryKey(LRegistration), 'Search Path',
            LRegistration.SearchPath, LSnapshots);
        if not PathUsedOutsideSelection(LRegistration,
          LRegistration.BrowsingPath, 'browsing') then
          RemovePathValue(FStore, LibraryKey(LRegistration), 'Browsing Path',
            LRegistration.BrowsingPath, LSnapshots);
        if not PathUsedOutsideSelection(LRegistration,
          LRegistration.DebugDcuPath, 'debug') then
          RemovePathValue(FStore, LibraryKey(LRegistration),
            'Debug DCU Path', LRegistration.DebugDcuPath, LSnapshots);
        if not PathUsedOutsideSelection(LRegistration,
          LRegistration.RuntimePath, 'runtime') then
          RemovePathValue(FStore, 'Environment', 'Path',
            LRegistration.RuntimePath, LSnapshots);
        if not PathUsedOutsideSelection(LRegistration,
          LRegistration.ToolPath, 'tool') then
          RemovePathValue(FStore, 'Environment', 'Path',
            LRegistration.ToolPath, LSnapshots);
        TakeSnapshot(FStore, PackageKey(LRegistration),
          LRegistration.BplPath, LSnapshots);
        FStore.DeleteValue(PackageKey(LRegistration),
          LRegistration.BplPath);
        TakeSnapshot(FStore, IDEPackageKey(LRegistration),
          LRegistration.BplPath, LSnapshots);
        FStore.DeleteValue(IDEPackageKey(LRegistration),
          LRegistration.BplPath);
        for var LHelpFile in LRegistration.HelpFiles do
        begin
          var LHelpKey := FRegistryRoot + '\' +
            LRegistration.Compiler + '\Help\HtmlHelp1Files';
          var LHelpName := LRegistration.OwnerPackage + ':' +
            TPath.GetFileName(LHelpFile);
          TakeSnapshot(FStore, LHelpKey, LHelpName, LSnapshots);
          FStore.DeleteValue(LHelpKey, LHelpName);
        end;
        for var LRegistryValue in LRegistration.RegistryValues do
        begin
          TakeSnapshot(FStore, LRegistryValue.Key, LRegistryValue.Name,
            LSnapshots);
          FStore.DeleteValue(LRegistryValue.Key, LRegistryValue.Name);
        end;
        for var LDisplacedValue in
          LRegistration.DisplacedRegistryValues do
        begin
          TakeSnapshot(FStore, LDisplacedValue.Key,
            LDisplacedValue.Name, LSnapshots);
          FStore.WriteValue(LDisplacedValue.Key, LDisplacedValue.Name,
            LDisplacedValue.Value);
        end;
        LInventory.Delete(I);
        Inc(Result);
      end;
      if Result > 0 then
        SaveInventory(LInventory);
    except
      on E: Exception do
      begin
        try
          Rollback(FStore, LSnapshots);
        finally
          RestoreStagedArtifacts(LStagedFiles);
        end;
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Falha ao desregistrar pacote IDE %s: %s',
          [AName, E.Message]);
      end;
    end;
    if TDirectory.Exists(LStagingDirectory) then
      TDirectory.Delete(LStagingDirectory, True);
  finally
    LLeases.Free;
    LCompilers.Free;
    LStagedFiles.Free;
    LSnapshots.Free;
    LInventory.Free;
  end;
end;

function TBoss4DIDERegistrationService.Unregister(
  const APackageName, ACompiler, APlatform: string): Integer;
begin
  Result := RemoveMatching(APackageName, ACompiler, APlatform, False);
end;

function TBoss4DIDERegistrationService.PlanUnregister(
  const APackageName, ACompiler,
  APlatform: string): TBoss4DIDERemovalPlan;
begin
  Result := PlanRemoval(APackageName, ACompiler, APlatform, False);
end;

function TBoss4DIDERegistrationService.Uninstall(
  const AOwnerPackage: string): Integer;
begin
  if AOwnerPackage.Trim.IsEmpty then
    raise EArgumentException.Create('OwnerPackage nao pode ser vazio.');
  Result := RemoveMatching(AOwnerPackage, '', '', True);
end;

function TBoss4DIDERegistrationService.PlanUninstall(
  const AOwnerPackage: string): TBoss4DIDERemovalPlan;
begin
  Result := PlanRemoval(AOwnerPackage, '', '', True);
end;

function TBoss4DIDERegistrationService.ArtifactsHealthy(
  const ARegistration: TBoss4DIDERegistration): Boolean;
begin
  if ARegistration.ArtifactRoot.Trim.IsEmpty then
    Exit(True);
  if not TFile.Exists(ARegistration.BplPath) then
    Exit(False);
  for var LArtifact in ARegistration.Artifacts do
    if not TFile.Exists(LArtifact) then
      Exit(False);
  Result := True;
end;

function TBoss4DIDERegistrationService.IsHealthy(
  const ARegistration: TBoss4DIDERegistration): Boolean;
var
  LValue: string;
  function PathValueHealthy(const AName, APath: string): Boolean;
  begin
    if APath.Trim.IsEmpty then
      Exit(True);
    Result := FStore.TryRead(LibraryKey(ARegistration), AName, LValue) and
      ContainsPath(LValue, APath);
  end;
begin
  Result := ArtifactsHealthy(ARegistration) and
    PathValueHealthy('Search Path', ARegistration.SearchPath) and
    PathValueHealthy('Browsing Path', ARegistration.BrowsingPath) and
    PathValueHealthy('Debug DCU Path', ARegistration.DebugDcuPath) and
    (ARegistration.RuntimePath.Trim.IsEmpty or
      (FStore.TryRead('Environment', 'Path', LValue) and
       ContainsPath(LValue, ARegistration.RuntimePath))) and
    (ARegistration.ToolPath.Trim.IsEmpty or
      (FStore.TryRead('Environment', 'Path', LValue) and
       ContainsPath(LValue, ARegistration.ToolPath))) and
    FStore.TryRead(PackageKey(ARegistration), ARegistration.BplPath,
      LValue) and SameText(LValue, ARegistration.Description);
  if Result then
    for var LHelpFile in ARegistration.HelpFiles do
    begin
      var LHelpKey := FRegistryRoot + '\' +
        ARegistration.Compiler + '\Help\HtmlHelp1Files';
      var LHelpName := ARegistration.OwnerPackage + ':' +
        TPath.GetFileName(LHelpFile);
      if not FStore.TryRead(LHelpKey, LHelpName, LValue) or
         not SameText(LValue, TPath.GetFullPath(LHelpFile)) then
        Exit(False);
    end;
  if Result then
    for var LRegistryValue in ARegistration.RegistryValues do
      if not FStore.TryRead(LRegistryValue.Key, LRegistryValue.Name,
        LValue) or (LValue <> LRegistryValue.Value) then
        Exit(False);
  if Result then
    for var LDisplacedValue in ARegistration.DisplacedRegistryValues do
      if FStore.TryRead(LDisplacedValue.Key, LDisplacedValue.Name,
        LValue) then
        Exit(False);
end;

function TBoss4DIDERegistrationService.Repair: Integer;
begin
  Result := Repair('');
end;

function TBoss4DIDERegistrationService.Repair(
  const AIdentity: string): Integer;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
  LFound: Boolean;
begin
  Result := 0;
  LFound := AIdentity.Trim.IsEmpty;
  LInventory := LoadInventory;
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  try
    try
      for var LRegistration in LInventory do
        if AIdentity.Trim.IsEmpty or
           SameText(LRegistration.Identity, AIdentity.Trim) then
        begin
          LFound := True;
          if IsHealthy(LRegistration) then
            Continue;
          if not ArtifactsHealthy(LRegistration) then
          begin
            if not Assigned(FArtifactRepairHandler) then
              raise EBoss4DIDERegistrationError.CreateFmt(
                'Artefatos ausentes para %s; execute o reparo com um compilador disponivel.',
                [LRegistration.Identity]);
            FArtifactRepairHandler(LRegistration);
            if not ArtifactsHealthy(LRegistration) then
              raise EBoss4DIDERegistrationError.CreateFmt(
                'O rebuild nao restaurou todos os artefatos de %s.',
                [LRegistration.Identity]);
          end;
          ApplyRegistration(FStore, LRegistration, LSnapshots);
          Inc(Result);
        end;
      if not LFound then
        raise EBoss4DIDERegistrationError.Create(
          'Registro IDE nao encontrado no inventario: ' + AIdentity);
    except
      on E: Exception do
      begin
        Rollback(FStore, LSnapshots);
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Falha ao reparar registros IDE: %s', [E.Message]);
      end;
    end;
  finally
    LSnapshots.Free;
    LInventory.Free;
  end;
end;

function TBoss4DIDERegistrationService.FindDrift: TArray<string>;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LDrift: TList<string>;
begin
  LInventory := LoadInventory;
  LDrift := TList<string>.Create;
  try
    for var LRegistration in LInventory do
      if not IsHealthy(LRegistration) then
        LDrift.Add(LRegistration.Identity);
    LDrift.Sort;
    Result := LDrift.ToArray;
  finally
    LDrift.Free;
    LInventory.Free;
  end;
end;

end.
