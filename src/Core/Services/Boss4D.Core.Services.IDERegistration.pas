unit Boss4D.Core.Services.IDERegistration;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows;

type
  EBoss4DIDERegistrationError = class(Exception);

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
  public
    constructor Create;
    destructor Destroy; override;
    function Identity: string;
    function Clone: TBoss4DIDERegistration;
    property PackageName: string read FPackageName write FPackageName;
    property OwnerPackage: string read FOwnerPackage write FOwnerPackage;
    property Compiler: string read FCompiler write FCompiler;
    property Platform: string read FPlatform write FPlatform;
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
  end;

  TBoss4DIDERegistrationService = class
  private
    FStore: IBoss4DIDERegistryStore;
    FInventoryPath: string;
    function LibraryKey(const ARegistration: TBoss4DIDERegistration): string;
    function PackageKey(const ARegistration: TBoss4DIDERegistration): string;
    function IDEPackageKey(
      const ARegistration: TBoss4DIDERegistration): string;
    procedure Validate(const ARegistration: TBoss4DIDERegistration);
    function LoadInventory: TObjectList<TBoss4DIDERegistration>;
    procedure SaveInventory(
      const AInventory: TObjectList<TBoss4DIDERegistration>);
    function IsHealthy(const ARegistration: TBoss4DIDERegistration): Boolean;
    function RemoveMatching(const AName, ACompiler, APlatform: string;
      const AByOwner: Boolean): Integer;
  public
    constructor Create(const AStore: IBoss4DIDERegistryStore;
      const AInventoryPath: string);
    procedure RegisterTarget(const ARegistration: TBoss4DIDERegistration);
    function DetectConflicts(
      const ARegistration: TBoss4DIDERegistration):
      TArray<TBoss4DIDEPackageConflict>;
    function Unregister(const APackageName, ACompiler,
      APlatform: string): Integer;
    function Uninstall(const AOwnerPackage: string): Integer;
    function Repair: Integer;
    function FindDrift: TArray<string>;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Win.Registry;

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

constructor TBoss4DIDERegistration.Create;
begin
  inherited Create;
  FArtifacts := TList<string>.Create;
  FHelpFiles := TList<string>.Create;
  FRegistryValues := TObjectList<TBoss4DIDEManagedRegistryValue>.Create(True);
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

constructor TBoss4DIDERegistrationService.Create(
  const AStore: IBoss4DIDERegistryStore; const AInventoryPath: string);
begin
  inherited Create;
  if not Assigned(AStore) then
    raise EArgumentNilException.Create('AStore');
  if AInventoryPath.Trim.IsEmpty then
    raise EArgumentException.Create('Inventory path nao pode ser vazio.');
  FStore := AStore;
  FInventoryPath := AInventoryPath;
end;

function TBoss4DIDERegistrationService.LibraryKey(
  const ARegistration: TBoss4DIDERegistration): string;
begin
  Result := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Library\' + ARegistration.Platform;
end;

function TBoss4DIDERegistrationService.PackageKey(
  const ARegistration: TBoss4DIDERegistration): string;
begin
  Result := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Known Packages';
end;

function TBoss4DIDERegistrationService.IDEPackageKey(
  const ARegistration: TBoss4DIDERegistration): string;
begin
  Result := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Known IDE Packages';
end;

procedure TBoss4DIDERegistrationService.Validate(
  const ARegistration: TBoss4DIDERegistration);
begin
  if not Assigned(ARegistration) then
    raise EArgumentNilException.Create('ARegistration');
  if ARegistration.PackageName.Trim.IsEmpty then
    raise EArgumentException.Create('PackageName nao pode ser vazio.');
  if (ARegistration.Compiler <> '17.0') and
     (ARegistration.Compiler <> '18.0') and
     (ARegistration.Compiler <> '22.0') and
     (ARegistration.Compiler <> '23.0') and
     (ARegistration.Compiler <> '37.0') then
    raise EArgumentException.CreateFmt(
      'Toolchain Delphi nao suportada: %s.', [ARegistration.Compiler]);
  if not SameText(ARegistration.Platform, 'Win32') and
     not SameText(ARegistration.Platform, 'Win64') then
    raise EArgumentException.CreateFmt(
      'Plataforma IDE nao suportada: %s.', [ARegistration.Platform]);
  if ARegistration.BplPath.Trim.IsEmpty then
    raise EArgumentException.Create('BplPath nao pode ser vazio.');
  var LAllowedPrefix := 'Software\Embarcadero\BDS\' +
    ARegistration.Compiler + '\';
  for var LRegistryValue in ARegistration.RegistryValues do
  begin
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
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(3));
    LItems := TJSONArray.Create;
    for var LRegistration in AInventory do
    begin
      var LObject := TJSONObject.Create;
      LObject.AddPair('package', LRegistration.PackageName);
      LObject.AddPair('ownerPackage', LRegistration.OwnerPackage);
      LObject.AddPair('compiler', LRegistration.Compiler);
      LObject.AddPair('platform', LRegistration.Platform);
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
  LLibraryKey := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Library\' + ARegistration.Platform;
  LPackageKey := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Known Packages';
  LIDEPackageKey := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
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
    var LHelpKey := 'Software\Embarcadero\BDS\' +
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
  LLibraryKey := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Library\' + ARegistration.Platform;
  LPackageKey := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
    '\Known Packages';
  LIDEPackageKey := 'Software\Embarcadero\BDS\' + ARegistration.Compiler +
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
    var LHelpKey := 'Software\Embarcadero\BDS\' +
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
end;

procedure TBoss4DIDERegistrationService.RegisterTarget(
  const ARegistration: TBoss4DIDERegistration);
var
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
  LInventory: TObjectList<TBoss4DIDERegistration>;
begin
  Validate(ARegistration);
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  LInventory := nil;
  try
    try
      LInventory := LoadInventory;
      for var I := LInventory.Count - 1 downto 0 do
        if SameText(LInventory[I].Identity, ARegistration.Identity) then
        begin
          RemoveRegistration(FStore, LInventory[I], LSnapshots);
          LInventory.Delete(I);
        end;
      ApplyRegistration(FStore, ARegistration, LSnapshots);
      LInventory.Add(ARegistration.Clone);
      SaveInventory(LInventory);
    except
      on E: Exception do
      begin
        Rollback(FStore, LSnapshots);
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Falha ao registrar target IDE %s: %s',
          [ARegistration.Identity, E.Message]);
      end;
    end;
  finally
    LInventory.Free;
    LSnapshots.Free;
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

function TBoss4DIDERegistrationService.RemoveMatching(
  const AName, ACompiler, APlatform: string;
  const AByOwner: Boolean): Integer;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
  LStagedFiles: TDictionary<string, string>;
  LStagingDirectory: string;

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
         not TFile.Exists(LArtifact) then
        Continue;
      TDirectory.CreateDirectory(LStagingDirectory);
      var LStaged := TPath.Combine(LStagingDirectory,
        TGUID.NewGuid.ToString + TPath.GetExtension(LArtifact));
      TFile.Move(LArtifact, LStaged);
      LStagedFiles.Add(LArtifact, LStaged);
    end;
  end;

  procedure RestoreStagedArtifacts;
  begin
    for var LPair in LStagedFiles do
      if TFile.Exists(LPair.Value) then
      begin
        var LOriginal := LPair.Key;
        TDirectory.CreateDirectory(TPath.GetDirectoryName(LOriginal));
        TFile.Move(LPair.Value, LOriginal);
      end;
  end;

begin
  Result := 0;
  LInventory := LoadInventory;
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  LStagedFiles := TDictionary<string, string>.Create;
  LStagingDirectory := FInventoryPath + '.uninstall-' +
    TGUID.NewGuid.ToString;
  try
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
          var LHelpKey := 'Software\Embarcadero\BDS\' +
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
          RestoreStagedArtifacts;
        end;
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Falha ao desregistrar pacote IDE %s: %s',
          [AName, E.Message]);
      end;
    end;
    if TDirectory.Exists(LStagingDirectory) then
      TDirectory.Delete(LStagingDirectory, True);
  finally
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

function TBoss4DIDERegistrationService.Uninstall(
  const AOwnerPackage: string): Integer;
begin
  if AOwnerPackage.Trim.IsEmpty then
    raise EArgumentException.Create('OwnerPackage nao pode ser vazio.');
  Result := RemoveMatching(AOwnerPackage, '', '', True);
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
  Result := PathValueHealthy('Search Path', ARegistration.SearchPath) and
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
      var LHelpKey := 'Software\Embarcadero\BDS\' +
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
end;

function TBoss4DIDERegistrationService.Repair: Integer;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
begin
  Result := 0;
  LInventory := LoadInventory;
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  try
    try
      for var LRegistration in LInventory do
        if not IsHealthy(LRegistration) then
        begin
          ApplyRegistration(FStore, LRegistration, LSnapshots);
          Inc(Result);
        end;
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
