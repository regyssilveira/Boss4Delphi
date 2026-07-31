unit Boss4D.Core.Services.BuildInventory;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  EBoss4DBuildInventoryError = class(Exception);

  TBoss4DInstalledBuild = class
  private
    FName: string;
    FRootDirectory: string;
    FDependencies: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function Clone: TBoss4DInstalledBuild;
    property Name: string read FName write FName;
    property RootDirectory: string read FRootDirectory write FRootDirectory;
    property Dependencies: TList<string> read FDependencies;
  end;

  TBoss4DBuildInventory = class
  private
    FPath: string;
    FPackages: TObjectDictionary<string, TBoss4DInstalledBuild>;
    function NormalizeName(const AName: string): string;
    procedure Validate;
  public
    constructor Create(const APath: string);
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    procedure RegisterPackage(const AName, ARootDirectory: string;
      const ADependencies: TArray<string>);
    procedure RemovePackage(const AName: string);
    function Contains(const AName: string): Boolean;
    function GetPackage(const AName: string): TBoss4DInstalledBuild;
    function ListPackages: TObjectList<TBoss4DInstalledBuild>;
    function DependentsOf(const AName: string;
      const ATransitive: Boolean = True): TArray<string>;
    function BuildOrder(const ANames: TArray<string>): TArray<string>;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.Generics.Defaults;

constructor TBoss4DInstalledBuild.Create;
begin
  inherited Create;
  FDependencies := TList<string>.Create;
end;

destructor TBoss4DInstalledBuild.Destroy;
begin
  FDependencies.Free;
  inherited Destroy;
end;

function TBoss4DInstalledBuild.Clone: TBoss4DInstalledBuild;
begin
  Result := TBoss4DInstalledBuild.Create;
  Result.Name := FName;
  Result.RootDirectory := FRootDirectory;
  Result.Dependencies.AddRange(FDependencies);
end;

constructor TBoss4DBuildInventory.Create(const APath: string);
begin
  inherited Create;
  if APath.Trim.IsEmpty then
    raise EArgumentException.Create('O caminho do inventario e obrigatorio.');
  FPath := TPath.GetFullPath(APath);
  FPackages := TObjectDictionary<string, TBoss4DInstalledBuild>.Create(
    [doOwnsValues]);
end;

destructor TBoss4DBuildInventory.Destroy;
begin
  FPackages.Free;
  inherited Destroy;
end;

function TBoss4DBuildInventory.NormalizeName(const AName: string): string;
begin
  Result := AName.Trim.ToLower;
  if Result.IsEmpty then
    raise EArgumentException.Create('O nome do pacote e obrigatorio.');
end;

procedure TBoss4DBuildInventory.RegisterPackage(const AName,
  ARootDirectory: string; const ADependencies: TArray<string>);
var
  LPackage: TBoss4DInstalledBuild;
  LKey: string;
  LCreated: Boolean;
  LPreviousName: string;
  LPreviousRoot: string;
  LPreviousDependencies: TArray<string>;
begin
  LKey := NormalizeName(AName);
  if ARootDirectory.Trim.IsEmpty then
    raise EArgumentException.Create('A raiz do pacote e obrigatoria.');
  LCreated := not FPackages.TryGetValue(LKey, LPackage);
  if LCreated then
  begin
    LPackage := TBoss4DInstalledBuild.Create;
    FPackages.Add(LKey, LPackage);
  end;
  LPreviousName := LPackage.Name;
  LPreviousRoot := LPackage.RootDirectory;
  LPreviousDependencies := LPackage.Dependencies.ToArray;
  try
    LPackage.Name := AName.Trim;
    LPackage.RootDirectory := TPath.GetFullPath(ARootDirectory);
    LPackage.Dependencies.Clear;
    for var LDependency in ADependencies do
    begin
      var LDependencyKey := NormalizeName(LDependency);
      if SameText(LDependencyKey, LKey) then
        raise EBoss4DBuildInventoryError.CreateFmt(
          'O pacote %s nao pode depender de si mesmo.', [AName]);
      if not LPackage.Dependencies.Contains(LDependencyKey) then
        LPackage.Dependencies.Add(LDependencyKey);
    end;
    LPackage.Dependencies.Sort;
    Validate;
  except
    if LCreated then
      FPackages.Remove(LKey)
    else
    begin
      LPackage.Name := LPreviousName;
      LPackage.RootDirectory := LPreviousRoot;
      LPackage.Dependencies.Clear;
      LPackage.Dependencies.AddRange(LPreviousDependencies);
    end;
    raise;
  end;
end;

procedure TBoss4DBuildInventory.RemovePackage(const AName: string);
begin
  FPackages.Remove(NormalizeName(AName));
end;

function TBoss4DBuildInventory.Contains(const AName: string): Boolean;
begin
  Result := FPackages.ContainsKey(NormalizeName(AName));
end;

function TBoss4DBuildInventory.GetPackage(
  const AName: string): TBoss4DInstalledBuild;
begin
  if not FPackages.TryGetValue(NormalizeName(AName), Result) then
    raise EBoss4DBuildInventoryError.CreateFmt(
      'Pacote nao registrado no inventario de build: %s.', [AName]);
end;

function TBoss4DBuildInventory.ListPackages:
  TObjectList<TBoss4DInstalledBuild>;
begin
  Result := TObjectList<TBoss4DInstalledBuild>.Create(True);
  var LNames := TList<string>.Create;
  try
    LNames.AddRange(FPackages.Keys.ToArray);
    LNames.Sort;
    for var LName in LNames do
      Result.Add(FPackages[LName].Clone);
  finally
    LNames.Free;
  end;
end;

procedure TBoss4DBuildInventory.Validate;
var
  LVisiting: TDictionary<string, Boolean>;
  LVisited: TDictionary<string, Boolean>;

  procedure Visit(const AName: string);
  begin
    if LVisited.ContainsKey(AName) then
      Exit;
    if LVisiting.ContainsKey(AName) then
      raise EBoss4DBuildInventoryError.CreateFmt(
        'Ciclo detectado no inventario global em %s.', [AName]);
    LVisiting.Add(AName, True);
    if FPackages.ContainsKey(AName) then
      for var LDependency in FPackages[AName].Dependencies do
        if FPackages.ContainsKey(LDependency) then
          Visit(LDependency);
    LVisiting.Remove(AName);
    LVisited.Add(AName, True);
  end;

begin
  LVisiting := TDictionary<string, Boolean>.Create;
  LVisited := TDictionary<string, Boolean>.Create;
  try
    for var LName in FPackages.Keys do
      Visit(LName);
  finally
    LVisited.Free;
    LVisiting.Free;
  end;
end;

function TBoss4DBuildInventory.DependentsOf(const AName: string;
  const ATransitive: Boolean): TArray<string>;
var
  LResult: TList<string>;
  LSeen: TDictionary<string, Boolean>;

  procedure AddDependents(const ADependency: string);
  begin
    for var LPair in FPackages do
      if LPair.Value.Dependencies.Contains(ADependency) and
         not LSeen.ContainsKey(LPair.Key) then
      begin
        LSeen.Add(LPair.Key, True);
        LResult.Add(LPair.Key);
        if ATransitive then
          AddDependents(LPair.Key);
      end;
  end;

begin
  var LKey := NormalizeName(AName);
  LResult := TList<string>.Create;
  LSeen := TDictionary<string, Boolean>.Create;
  try
    AddDependents(LKey);
    LResult.Sort;
    Result := LResult.ToArray;
  finally
    LSeen.Free;
    LResult.Free;
  end;
end;

function TBoss4DBuildInventory.BuildOrder(
  const ANames: TArray<string>): TArray<string>;
var
  LSelected: TDictionary<string, Boolean>;
  LVisited: TDictionary<string, Boolean>;
  LResult: TList<string>;

  procedure Visit(const AName: string);
  begin
    if LVisited.ContainsKey(AName) then
      Exit;
    LVisited.Add(AName, True);
    if FPackages.ContainsKey(AName) then
      for var LDependency in FPackages[AName].Dependencies do
        if LSelected.ContainsKey(LDependency) then
          Visit(LDependency);
    LResult.Add(AName);
  end;

begin
  Validate;
  LSelected := TDictionary<string, Boolean>.Create;
  LVisited := TDictionary<string, Boolean>.Create;
  LResult := TList<string>.Create;
  try
    for var LName in ANames do
      LSelected.AddOrSetValue(NormalizeName(LName), True);
    var LSorted := TList<string>.Create;
    try
      LSorted.AddRange(LSelected.Keys.ToArray);
      LSorted.Sort;
      for var LName in LSorted do
        Visit(LName);
    finally
      LSorted.Free;
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
    LVisited.Free;
    LSelected.Free;
  end;
end;

procedure TBoss4DBuildInventory.Save;
var
  LRoot: TJSONObject;
  LPackages: TJSONArray;
  LNames: TList<string>;
  LEncoding: TEncoding;
begin
  Validate;
  TDirectory.CreateDirectory(TPath.GetDirectoryName(FPath));
  LRoot := TJSONObject.Create;
  LNames := TList<string>.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LPackages := TJSONArray.Create;
    LRoot.AddPair('packages', LPackages);
    LNames.AddRange(FPackages.Keys.ToArray);
    LNames.Sort;
    for var LName in LNames do
    begin
      var LPackage := FPackages[LName];
      var LObject := TJSONObject.Create;
      LObject.AddPair('name', LPackage.Name);
      LObject.AddPair('root', LPackage.RootDirectory);
      var LDependencies := TJSONArray.Create;
      for var LDependency in LPackage.Dependencies do
        LDependencies.Add(LDependency);
      LObject.AddPair('dependencies', LDependencies);
      LPackages.AddElement(LObject);
    end;
    LEncoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(FPath, LRoot.Format(2), LEncoding);
    finally
      LEncoding.Free;
    end;
  finally
    LNames.Free;
    LRoot.Free;
  end;
end;

procedure TBoss4DBuildInventory.Load;
var
  LRoot: TJSONObject;
  LPackages: TJSONArray;
begin
  FPackages.Clear;
  if not TFile.Exists(FPath) then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(FPath, TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LRoot) then
    raise EBoss4DBuildInventoryError.Create('Inventario global invalido.');
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EBoss4DBuildInventoryError.Create(
        'Versao do inventario global nao suportada.');
    LPackages := LRoot.GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
      raise EBoss4DBuildInventoryError.Create(
        'Lista de pacotes ausente no inventario global.');
    for var I := 0 to LPackages.Count - 1 do
    begin
      var LObject := LPackages[I] as TJSONObject;
      if not Assigned(LObject) then
        raise EBoss4DBuildInventoryError.Create(
          'Entrada de pacote invalida no inventario global.');
      var LName := LObject.GetValue<string>('name', '');
      var LRootDirectory := LObject.GetValue<string>('root', '');
      var LDependencies := LObject.GetValue<TJSONArray>('dependencies');
      var LValues := TList<string>.Create;
      try
        if Assigned(LDependencies) then
          for var J := 0 to LDependencies.Count - 1 do
            LValues.Add(LDependencies[J].Value);
        RegisterPackage(LName, LRootDirectory, LValues.ToArray);
      finally
        LValues.Free;
      end;
    end;
    Validate;
  finally
    LRoot.Free;
  end;
end;

end.
