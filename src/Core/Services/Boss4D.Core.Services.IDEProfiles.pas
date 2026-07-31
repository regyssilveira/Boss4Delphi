unit Boss4D.Core.Services.IDEProfiles;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Domain.IDEProfile;

type
  EBoss4DIDEProfileError = class(Exception);

  TBoss4DIDEProfileStore = class
  private
    FPath: string;
    procedure Validate(const AProfile: TBoss4DIDEProfile);
  public
    constructor Create(const APath: string);
    function Load: TObjectList<TBoss4DIDEProfile>;
    procedure Save(const AProfiles: TObjectList<TBoss4DIDEProfile>);
  end;

  TBoss4DIDELaunchHandler = reference to procedure(
    const AExecutable, AArguments: string);

  TBoss4DIDEProfileService = class
  private
    FStore: TBoss4DIDEProfileStore;
    FProfilesRoot: string;
    FLaunchHandler: TBoss4DIDELaunchHandler;
    function NormalizeId(const AName: string): string;
    function Find(const AProfiles: TObjectList<TBoss4DIDEProfile>;
      const AIdOrName: string): TBoss4DIDEProfile;
  public
    constructor Create(const AStore: TBoss4DIDEProfileStore;
      const AProfilesRoot: string;
      const ALaunchHandler: TBoss4DIDELaunchHandler = nil);
    function EnsureDefault(const ACompiler, AExecutable: string;
      const ALegacyInventoryPath: string = ''): TBoss4DIDEProfile;
    function CreateProfile(const AName, ADescription, ACompiler,
      AExecutable: string): TBoss4DIDEProfile;
    function CloneProfile(const ASourceId, ANewName: string):
      TBoss4DIDEProfile;
    function Get(const AIdOrName: string): TBoss4DIDEProfile;
    function List: TObjectList<TBoss4DIDEProfile>;
    procedure Remove(const AIdOrName: string);
    procedure AddPackage(const AProfileId, APackage: string);
    procedure RemovePackage(const AProfileId, APackage: string);
    procedure ConfigureTarget(const AProfileId, APlatform,
      AConfiguration: string);
    procedure ExportProfile(const AIdOrName, APath: string);
    function ImportProfile(const APath: string): TBoss4DIDEProfile;
    procedure Launch(const AIdOrName: string);
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.Generics.Defaults,
  Winapi.Windows,
  Winapi.ShellAPI,
  Boss4D.Core.Services.BuildConventions;

procedure WriteProfile(const AObject: TJSONObject;
  const AProfile: TBoss4DIDEProfile);
begin
  AObject.AddPair('schemaVersion',
    TJSONNumber.Create(AProfile.SchemaVersion));
  AObject.AddPair('id', AProfile.Id);
  AObject.AddPair('name', AProfile.Name);
  AObject.AddPair('description', AProfile.Description);
  AObject.AddPair('compiler', AProfile.Compiler);
  AObject.AddPair('executable', AProfile.Executable);
  AObject.AddPair('registryBranch', AProfile.RegistryBranch);
  AObject.AddPair('defaultPlatform', AProfile.DefaultPlatform);
  AObject.AddPair('defaultConfiguration',
    AProfile.DefaultConfiguration);
  AObject.AddPair('inventory', AProfile.InventoryPath);
  var LPackages := TJSONArray.Create;
  for var LPackage in AProfile.Packages do
    LPackages.Add(LPackage);
  AObject.AddPair('packages', LPackages);
end;

function ReadProfile(const AObject: TJSONObject): TBoss4DIDEProfile;
begin
  Result := TBoss4DIDEProfile.Create;
  try
    Result.SchemaVersion := AObject.GetValue<Integer>('schemaVersion', 0);
    Result.Id := AObject.GetValue<string>('id', '');
    Result.Name := AObject.GetValue<string>('name', '');
    Result.Description := AObject.GetValue<string>('description', '');
    Result.Compiler := AObject.GetValue<string>('compiler', '');
    Result.Executable := AObject.GetValue<string>('executable', '');
    Result.RegistryBranch := AObject.GetValue<string>('registryBranch', '');
    Result.DefaultPlatform := AObject.GetValue<string>(
      'defaultPlatform', 'Win32');
    Result.DefaultConfiguration := AObject.GetValue<string>(
      'defaultConfiguration', 'Release');
    Result.InventoryPath := AObject.GetValue<string>('inventory', '');
    var LPackages := AObject.GetValue<TJSONArray>('packages');
    if Assigned(LPackages) then
      for var I := 0 to LPackages.Count - 1 do
        Result.Packages.Add(LPackages[I].Value);
  except
    Result.Free;
    raise;
  end;
end;

constructor TBoss4DIDEProfileStore.Create(const APath: string);
begin
  inherited Create;
  if APath.Trim.IsEmpty then
    raise EArgumentException.Create(
      'O caminho do store de perfis e obrigatorio.');
  FPath := TPath.GetFullPath(APath);
end;

procedure TBoss4DIDEProfileStore.Validate(
  const AProfile: TBoss4DIDEProfile);
begin
  if not Assigned(AProfile) then
    raise EArgumentNilException.Create('AProfile');
  if AProfile.SchemaVersion <> 1 then
    raise EBoss4DIDEProfileError.CreateFmt(
      'Schema de perfil IDE nao suportado: %d.',
      [AProfile.SchemaVersion]);
  if AProfile.Id.Trim.IsEmpty or AProfile.Name.Trim.IsEmpty or
     AProfile.Compiler.Trim.IsEmpty or
     AProfile.RegistryBranch.Trim.IsEmpty or
     AProfile.InventoryPath.Trim.IsEmpty then
    raise EBoss4DIDEProfileError.Create(
      'Perfil IDE possui campos obrigatorios vazios.');
  TBoss4DBuildConventions.ResolveCompiler(AProfile.Compiler);
  if AProfile.RegistryBranch.Contains('..') or
     AProfile.RegistryBranch.StartsWith('\') then
    raise EBoss4DIDEProfileError.Create(
      'Registry branch de perfil invalido.');
end;

function TBoss4DIDEProfileStore.Load:
  TObjectList<TBoss4DIDEProfile>;
begin
  Result := TObjectList<TBoss4DIDEProfile>.Create(True);
  if not TFile.Exists(FPath) then
    Exit;
  var LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(FPath, TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LRoot) then
    raise EBoss4DIDEProfileError.Create(
      'Store de perfis IDE invalido.');
  try
    try
      if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
        raise EBoss4DIDEProfileError.Create(
          'Schema do store de perfis IDE nao suportado.');
      var LItems := LRoot.GetValue<TJSONArray>('profiles');
      if not Assigned(LItems) then
        raise EBoss4DIDEProfileError.Create(
          'Lista de perfis IDE ausente.');
      for var I := 0 to LItems.Count - 1 do
      begin
        var LProfile := ReadProfile(LItems[I] as TJSONObject);
        Validate(LProfile);
        Result.Add(LProfile);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TBoss4DIDEProfileStore.Save(
  const AProfiles: TObjectList<TBoss4DIDEProfile>);
begin
  if not Assigned(AProfiles) then
    raise EArgumentNilException.Create('AProfiles');
  var LSorted := TList<TBoss4DIDEProfile>.Create;
  var LSeen := TDictionary<string, Boolean>.Create;
  var LRoot := TJSONObject.Create;
  try
    for var LProfile in AProfiles do
    begin
      Validate(LProfile);
      var LKey := LProfile.Id.ToLower;
      if LSeen.ContainsKey(LKey) then
        raise EBoss4DIDEProfileError.CreateFmt(
          'Perfil IDE duplicado: %s.', [LProfile.Id]);
      LSeen.Add(LKey, True);
      LProfile.Packages.Sort;
      LSorted.Add(LProfile);
    end;
    LSorted.Sort(TComparer<TBoss4DIDEProfile>.Construct(
      function(const ALeft, ARight: TBoss4DIDEProfile): Integer
      begin
        Result := CompareText(ALeft.Id, ARight.Id);
      end));
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    var LItems := TJSONArray.Create;
    for var LProfile in LSorted do
    begin
      var LObject := TJSONObject.Create;
      WriteProfile(LObject, LProfile);
      LItems.AddElement(LObject);
    end;
    LRoot.AddPair('profiles', LItems);
    TDirectory.CreateDirectory(TPath.GetDirectoryName(FPath));
    var LTemp := FPath + '.tmp';
    var LEncoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(LTemp, LRoot.Format(2), LEncoding);
    finally
      LEncoding.Free;
    end;
    if TFile.Exists(FPath) then
    begin
      var LBackup := FPath + '.bak';
      if TFile.Exists(LBackup) then
        TFile.Delete(LBackup);
      TFile.Replace(LTemp, FPath, LBackup);
      if TFile.Exists(LBackup) then
        TFile.Delete(LBackup);
    end
    else
      TFile.Move(LTemp, FPath);
  finally
    LRoot.Free;
    LSeen.Free;
    LSorted.Free;
  end;
end;

constructor TBoss4DIDEProfileService.Create(
  const AStore: TBoss4DIDEProfileStore; const AProfilesRoot: string;
  const ALaunchHandler: TBoss4DIDELaunchHandler);
begin
  inherited Create;
  if not Assigned(AStore) then
    raise EArgumentNilException.Create('AStore');
  if AProfilesRoot.Trim.IsEmpty then
    raise EArgumentException.Create(
      'A raiz de perfis IDE e obrigatoria.');
  FStore := AStore;
  FProfilesRoot := TPath.GetFullPath(AProfilesRoot);
  FLaunchHandler := ALaunchHandler;
end;

function TBoss4DIDEProfileService.NormalizeId(
  const AName: string): string;
begin
  Result := '';
  for var LChar in AName.Trim.ToLower do
    if CharInSet(LChar, ['a'..'z', '0'..'9']) then
      Result := Result + LChar
    else if (LChar = '-') or (LChar = '_') or (LChar = ' ') then
      if not Result.EndsWith('-') then
        Result := Result + '-';
  Result := Result.Trim(['-']);
  if Result.IsEmpty then
    raise EBoss4DIDEProfileError.Create(
      'O nome nao produz um id de perfil valido.');
end;

function TBoss4DIDEProfileService.Find(
  const AProfiles: TObjectList<TBoss4DIDEProfile>;
  const AIdOrName: string): TBoss4DIDEProfile;
begin
  for var LProfile in AProfiles do
    if SameText(LProfile.Id, AIdOrName) or
       SameText(LProfile.Name, AIdOrName) then
      Exit(LProfile);
  raise EBoss4DIDEProfileError.CreateFmt(
    'Perfil IDE nao encontrado: %s.', [AIdOrName]);
end;

function TBoss4DIDEProfileService.EnsureDefault(
  const ACompiler, AExecutable,
  ALegacyInventoryPath: string): TBoss4DIDEProfile;
begin
  var LProfiles := FStore.Load;
  try
    for var LProfile in LProfiles do
      if SameText(LProfile.Id, 'default') then
      begin
        if not ALegacyInventoryPath.Trim.IsEmpty and
           TFile.Exists(ALegacyInventoryPath) and
           not TFile.Exists(LProfile.InventoryPath) then
        begin
          TDirectory.CreateDirectory(
            TPath.GetDirectoryName(LProfile.InventoryPath));
          TFile.Copy(TPath.GetFullPath(ALegacyInventoryPath),
            LProfile.InventoryPath, False);
        end;
        Exit(LProfile.Clone);
      end;
    var LProfile := TBoss4DIDEProfile.Create;
    LProfile.Id := 'default';
    LProfile.Name := 'default';
    LProfile.Description := 'Boss4D default IDE profile';
    LProfile.Compiler :=
      TBoss4DBuildConventions.ResolveCompiler(ACompiler).BDSVersion;
    LProfile.Executable := AExecutable;
    LProfile.RegistryBranch := 'BDS';
    LProfile.InventoryPath := TPath.Combine(
      TPath.Combine(FProfilesRoot, 'default'), 'registrations.json');
    if not ALegacyInventoryPath.Trim.IsEmpty and
       TFile.Exists(ALegacyInventoryPath) and
       not TFile.Exists(LProfile.InventoryPath) then
    begin
      TDirectory.CreateDirectory(
        TPath.GetDirectoryName(LProfile.InventoryPath));
      TFile.Copy(TPath.GetFullPath(ALegacyInventoryPath),
        LProfile.InventoryPath, False);
    end;
    LProfiles.Add(LProfile);
    FStore.Save(LProfiles);
    Result := LProfile.Clone;
  finally
    LProfiles.Free;
  end;
end;

function TBoss4DIDEProfileService.CreateProfile(
  const AName, ADescription, ACompiler,
  AExecutable: string): TBoss4DIDEProfile;
begin
  var LProfiles := FStore.Load;
  try
    var LId := NormalizeId(AName);
    for var LExisting in LProfiles do
      if SameText(LExisting.Id, LId) or
         SameText(LExisting.Name, AName) then
        raise EBoss4DIDEProfileError.CreateFmt(
          'Perfil IDE ja existe: %s.', [AName]);
    var LProfile := TBoss4DIDEProfile.Create;
    LProfile.Id := LId;
    LProfile.Name := AName.Trim;
    LProfile.Description := ADescription.Trim;
    LProfile.Compiler :=
      TBoss4DBuildConventions.ResolveCompiler(ACompiler).BDSVersion;
    LProfile.Executable := AExecutable;
    LProfile.RegistryBranch := 'Boss4D-' + LId;
    LProfile.InventoryPath := TPath.Combine(
      TPath.Combine(FProfilesRoot, LId), 'registrations.json');
    LProfiles.Add(LProfile);
    FStore.Save(LProfiles);
    Result := LProfile.Clone;
  finally
    LProfiles.Free;
  end;
end;

function TBoss4DIDEProfileService.CloneProfile(
  const ASourceId, ANewName: string): TBoss4DIDEProfile;
begin
  var LProfiles := FStore.Load;
  try
    var LSource := Find(LProfiles, ASourceId);
    var LId := NormalizeId(ANewName);
    for var LExisting in LProfiles do
      if SameText(LExisting.Id, LId) then
        raise EBoss4DIDEProfileError.CreateFmt(
          'Perfil IDE ja existe: %s.', [ANewName]);
    var LClone := LSource.Clone;
    LClone.Id := LId;
    LClone.Name := ANewName.Trim;
    LClone.RegistryBranch := 'Boss4D-' + LId;
    LClone.InventoryPath := TPath.Combine(
      TPath.Combine(FProfilesRoot, LId), 'registrations.json');
    LProfiles.Add(LClone);
    FStore.Save(LProfiles);
    Result := LClone.Clone;
  finally
    LProfiles.Free;
  end;
end;

function TBoss4DIDEProfileService.Get(
  const AIdOrName: string): TBoss4DIDEProfile;
begin
  var LProfiles := FStore.Load;
  try
    Result := Find(LProfiles, AIdOrName).Clone;
  finally
    LProfiles.Free;
  end;
end;

function TBoss4DIDEProfileService.List:
  TObjectList<TBoss4DIDEProfile>;
begin
  Result := FStore.Load;
end;

procedure TBoss4DIDEProfileService.Remove(const AIdOrName: string);
begin
  var LProfiles := FStore.Load;
  try
    var LProfile := Find(LProfiles, AIdOrName);
    if SameText(LProfile.Id, 'default') then
      raise EBoss4DIDEProfileError.Create(
        'O perfil default nao pode ser removido.');
    if LProfile.Packages.Count > 0 then
      raise EBoss4DIDEProfileError.CreateFmt(
        'O perfil %s ainda possui %d package(s). Remova-os antes de ' +
        'excluir o perfil.', [LProfile.Id, LProfile.Packages.Count]);
    LProfiles.Remove(LProfile);
    FStore.Save(LProfiles);
  finally
    LProfiles.Free;
  end;
end;

procedure TBoss4DIDEProfileService.AddPackage(
  const AProfileId, APackage: string);
begin
  if APackage.Trim.IsEmpty then
    raise EArgumentException.Create('O package e obrigatorio.');
  var LProfiles := FStore.Load;
  try
    var LProfile := Find(LProfiles, AProfileId);
    for var LExisting in LProfile.Packages do
      if SameText(LExisting, APackage) then
        Exit;
    LProfile.Packages.Add(APackage.Trim);
    FStore.Save(LProfiles);
  finally
    LProfiles.Free;
  end;
end;

procedure TBoss4DIDEProfileService.RemovePackage(
  const AProfileId, APackage: string);
begin
  var LProfiles := FStore.Load;
  try
    var LProfile := Find(LProfiles, AProfileId);
    for var I := LProfile.Packages.Count - 1 downto 0 do
      if SameText(LProfile.Packages[I], APackage) then
        LProfile.Packages.Delete(I);
    FStore.Save(LProfiles);
  finally
    LProfiles.Free;
  end;
end;

procedure TBoss4DIDEProfileService.ConfigureTarget(
  const AProfileId, APlatform, AConfiguration: string);
begin
  if APlatform.Trim.IsEmpty then
    raise EArgumentException.Create('A plataforma e obrigatoria.');
  if AConfiguration.Trim.IsEmpty then
    raise EArgumentException.Create('A configuracao e obrigatoria.');
  var LProfiles := FStore.Load;
  try
    var LProfile := Find(LProfiles, AProfileId);
    LProfile.DefaultPlatform := APlatform.Trim;
    LProfile.DefaultConfiguration := AConfiguration.Trim;
    FStore.Save(LProfiles);
  finally
    LProfiles.Free;
  end;
end;

procedure TBoss4DIDEProfileService.ExportProfile(
  const AIdOrName, APath: string);
begin
  var LProfile := Get(AIdOrName);
  try
    var LObject := TJSONObject.Create;
    try
      WriteProfile(LObject, LProfile);
      TDirectory.CreateDirectory(TPath.GetDirectoryName(
        TPath.GetFullPath(APath)));
      TFile.WriteAllText(APath, LObject.Format(2), TEncoding.UTF8);
    finally
      LObject.Free;
    end;
  finally
    LProfile.Free;
  end;
end;

function TBoss4DIDEProfileService.ImportProfile(
  const APath: string): TBoss4DIDEProfile;
begin
  var LObject := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APath, TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LObject) then
    raise EBoss4DIDEProfileError.Create('Perfil importado invalido.');
  var LImported: TBoss4DIDEProfile := nil;
  try
    LImported := ReadProfile(LObject);
    var LProfiles := FStore.Load;
    try
      for var LExisting in LProfiles do
        if SameText(LExisting.Id, LImported.Id) then
          raise EBoss4DIDEProfileError.CreateFmt(
            'Perfil IDE ja existe: %s.', [LImported.Id]);
      LProfiles.Add(LImported);
      LImported := nil;
      FStore.Save(LProfiles);
      Result := LProfiles.Last.Clone;
    finally
      LProfiles.Free;
    end;
  finally
    LImported.Free;
    LObject.Free;
  end;
end;

procedure TBoss4DIDEProfileService.Launch(
  const AIdOrName: string);
begin
  var LProfile := Get(AIdOrName);
  try
    if LProfile.Executable.Trim.IsEmpty then
      raise EBoss4DIDEProfileError.Create(
        'O perfil nao possui executavel da IDE.');
    var LArguments := '';
    if not SameText(LProfile.Id, 'default') then
      LArguments := '/r:' + LProfile.RegistryBranch;
    if Assigned(FLaunchHandler) then
      FLaunchHandler(LProfile.Executable, LArguments)
    else if ShellExecute(0, 'open', PChar(LProfile.Executable),
      PChar(LArguments), nil, SW_SHOWNORMAL) <= 32 then
      RaiseLastOSError;
  finally
    LProfile.Free;
  end;
end;

end.
