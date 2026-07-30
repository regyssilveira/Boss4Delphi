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
  end;

  TBoss4DIDERegistration = class
  private
    FPackageName: string;
    FCompiler: string;
    FPlatform: string;
    FBplPath: string;
    FDescription: string;
    FSearchPath: string;
    FBrowsingPath: string;
    FDebugDcuPath: string;
  public
    function Identity: string;
    function Clone: TBoss4DIDERegistration;
    property PackageName: string read FPackageName write FPackageName;
    property Compiler: string read FCompiler write FCompiler;
    property Platform: string read FPlatform write FPlatform;
    property BplPath: string read FBplPath write FBplPath;
    property Description: string read FDescription write FDescription;
    property SearchPath: string read FSearchPath write FSearchPath;
    property BrowsingPath: string read FBrowsingPath write FBrowsingPath;
    property DebugDcuPath: string read FDebugDcuPath write FDebugDcuPath;
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
  public
    constructor Create(const AStore: IBoss4DIDERegistryStore;
      const AInventoryPath: string);
    procedure RegisterTarget(const ARegistration: TBoss4DIDERegistration);
    function Unregister(const APackageName, ACompiler,
      APlatform: string): Integer;
    function Repair: Integer;
    function FindDrift: TArray<string>;
  end;

implementation

uses
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

function TBoss4DIDERegistration.Identity: string;
begin
  Result := FPackageName + '|' + FCompiler + '|' + FPlatform;
end;

function TBoss4DIDERegistration.Clone: TBoss4DIDERegistration;
begin
  Result := TBoss4DIDERegistration.Create;
  Result.PackageName := FPackageName;
  Result.Compiler := FCompiler;
  Result.Platform := FPlatform;
  Result.BplPath := FBplPath;
  Result.Description := FDescription;
  Result.SearchPath := FSearchPath;
  Result.BrowsingPath := FBrowsingPath;
  Result.DebugDcuPath := FDebugDcuPath;
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
  if (ARegistration.Compiler <> '18.0') and
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
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LItems := TJSONArray.Create;
    for var LRegistration in AInventory do
    begin
      var LObject := TJSONObject.Create;
      LObject.AddPair('package', LRegistration.PackageName);
      LObject.AddPair('compiler', LRegistration.Compiler);
      LObject.AddPair('platform', LRegistration.Platform);
      LObject.AddPair('bpl', LRegistration.BplPath);
      LObject.AddPair('description', LRegistration.Description);
      LObject.AddPair('searchPath', LRegistration.SearchPath);
      LObject.AddPair('browsingPath', LRegistration.BrowsingPath);
      LObject.AddPair('debugDcuPath', LRegistration.DebugDcuPath);
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

function TBoss4DIDERegistrationService.Unregister(
  const APackageName, ACompiler, APlatform: string): Integer;
var
  LInventory: TObjectList<TBoss4DIDERegistration>;
  LSnapshots: TObjectList<TBoss4DRegistrySnapshot>;
begin
  Result := 0;
  LInventory := LoadInventory;
  LSnapshots := TObjectList<TBoss4DRegistrySnapshot>.Create(True);
  try
    try
      for var I := LInventory.Count - 1 downto 0 do
      begin
        var LRegistration := LInventory[I];
        if not SameText(LRegistration.PackageName, APackageName) or
           (not ACompiler.IsEmpty and
            not SameText(LRegistration.Compiler, ACompiler)) or
           (not APlatform.IsEmpty and
            not SameText(LRegistration.Platform, APlatform)) then
          Continue;
        RemovePathValue(FStore, LibraryKey(LRegistration), 'Search Path',
          LRegistration.SearchPath, LSnapshots);
        RemovePathValue(FStore, LibraryKey(LRegistration), 'Browsing Path',
          LRegistration.BrowsingPath, LSnapshots);
        RemovePathValue(FStore, LibraryKey(LRegistration), 'Debug DCU Path',
          LRegistration.DebugDcuPath, LSnapshots);
        TakeSnapshot(FStore, PackageKey(LRegistration),
          LRegistration.BplPath, LSnapshots);
        FStore.DeleteValue(PackageKey(LRegistration),
          LRegistration.BplPath);
        TakeSnapshot(FStore, IDEPackageKey(LRegistration),
          LRegistration.BplPath, LSnapshots);
        FStore.DeleteValue(IDEPackageKey(LRegistration),
          LRegistration.BplPath);
        LInventory.Delete(I);
        Inc(Result);
      end;
      if Result > 0 then
        SaveInventory(LInventory);
    except
      on E: Exception do
      begin
        Rollback(FStore, LSnapshots);
        raise EBoss4DIDERegistrationError.CreateFmt(
          'Falha ao desregistrar pacote IDE %s: %s',
          [APackageName, E.Message]);
      end;
    end;
  finally
    LSnapshots.Free;
    LInventory.Free;
  end;
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
    FStore.TryRead(PackageKey(ARegistration), ARegistration.BplPath,
      LValue) and SameText(LValue, ARegistration.Description);
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
