unit Boss4D.Core.Domain.Package;

interface

uses
  System.Generics.Collections, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.BuildMatrix;

type
  TBoss4DManualComponent = class
  private
    FId: string;
    FName: string;
    FVersion: string;
    FComponentType: string;
    FDescription: string;
    FLicense: string;
    FRepository: string;
    FHashAlgorithm: string;
    FHashValue: string;
    FSource: string;
  public
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property ComponentType: string read FComponentType write FComponentType;
    property Description: string read FDescription write FDescription;
    property License: string read FLicense write FLicense;
    property Repository: string read FRepository write FRepository;
    property HashAlgorithm: string read FHashAlgorithm write FHashAlgorithm;
    property HashValue: string read FHashValue write FHashValue;
    property Source: string read FSource write FSource;
  end;

  { Configurações de Engines no boss.json }
  TBoss4DPackageEngines = class
  private
    FCompiler: string;
    FPlatforms: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    property Compiler: string read FCompiler write FCompiler;
    property Platforms: TList<string> read FPlatforms;
  end;

  { Configurações de Toolchain no boss.json }
  TBoss4DPackageToolchain = class
  private
    FCompiler: string;
    FPlatform: string;
    FPath: string;
    FStrict: Boolean;
  public
    property Compiler: string read FCompiler write FCompiler;
    property Platform: string read FPlatform write FPlatform;
    property Path: string read FPath write FPath;
    property Strict: Boolean read FStrict write FStrict;
  end;

  TBoss4DPackageTrust = class
  private
    FRequireSignedCommits: Boolean;
    FRequireSignedTags: Boolean;
    FAllowedSigners: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property RequireSignedCommits: Boolean read FRequireSignedCommits write FRequireSignedCommits;
    property RequireSignedTags: Boolean read FRequireSignedTags write FRequireSignedTags;
    property AllowedSigners: TList<string> read FAllowedSigners;
  end;

  TBoss4DIDERegistryValue = class
  private
    FKey: string;
    FName: string;
    FValue: string;
  public
    property Key: string read FKey write FKey;
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
  end;

  TBoss4DIDEAssets = class
  private
    FTools: TList<string>;
    FTemplates: TList<string>;
    FRegistryValues: TObjectList<TBoss4DIDERegistryValue>;
  public
    constructor Create;
    destructor Destroy; override;
    function IsDeclared: Boolean;
    property Tools: TList<string> read FTools;
    property Templates: TList<string> read FTemplates;
    property RegistryValues: TObjectList<TBoss4DIDERegistryValue>
      read FRegistryValues;
  end;

  { Entidade pura de dominio que representa o arquivo boss.json }
  TBoss4DPackage = class
  private
    FName: string;
    FDescription: string;
    FVersion: string;
    FHomepage: string;
    FLicense: string;
    FMainSrc: string;
    FBrowsingPath: string;
    FProjects: TList<string>;
    FScripts: TDictionary<string, string>;
    FDependencies: TDictionary<string, string>;
    FDevDependencies: TDictionary<string, string>;
    FEngines: TBoss4DPackageEngines;
    FToolchain: TBoss4DPackageToolchain;
    FTrust: TBoss4DPackageTrust;
    FWorkspaces: TList<string>;
    FSbomComponents: TObjectList<TBoss4DManualComponent>;
    FBuildMatrix: TBoss4DBuildMatrix;
    FIDEAssets: TBoss4DIDEAssets;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddDependency(const ADep: string; const AVer: string);
    procedure AddDevDependency(const ADep: string; const AVer: string);
    function RemoveDependency(const ADep: string): Boolean;
    procedure AddProject(const AProject: string);

    // Retorna uma lista de dependencias prontas e parseadas. O chamador e responsavel por liberar os objetos do array.
    function GetParsedDependencies: TArray<TBoss4DDependency>;
    function GetParsedDevDependencies: TArray<TBoss4DDependency>;

    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Version: string read FVersion write FVersion;
    property Homepage: string read FHomepage write FHomepage;
    property License: string read FLicense write FLicense;
    property MainSrc: string read FMainSrc write FMainSrc;
    property BrowsingPath: string read FBrowsingPath write FBrowsingPath;
    property Projects: TList<string> read FProjects;
    property Scripts: TDictionary<string, string> read FScripts;
    property Dependencies: TDictionary<string, string> read FDependencies;
    property DevDependencies: TDictionary<string, string> read FDevDependencies;
    property Engines: TBoss4DPackageEngines read FEngines;
    property Toolchain: TBoss4DPackageToolchain read FToolchain;
    property Trust: TBoss4DPackageTrust read FTrust;
    property Workspaces: TList<string> read FWorkspaces;
    property SbomComponents: TObjectList<TBoss4DManualComponent> read FSbomComponents;
    property BuildMatrix: TBoss4DBuildMatrix read FBuildMatrix;
    property IDEAssets: TBoss4DIDEAssets read FIDEAssets;
  end;

implementation

uses
  System.SysUtils;

{ TBoss4DPackageEngines }

constructor TBoss4DPackageTrust.Create;
begin
  inherited Create;
  FAllowedSigners := TList<string>.Create;
end;

destructor TBoss4DPackageTrust.Destroy;
begin
  FAllowedSigners.Free;
  inherited Destroy;
end;

constructor TBoss4DPackageEngines.Create;
begin
  inherited Create;
  FPlatforms := TList<string>.Create;
end;

destructor TBoss4DPackageEngines.Destroy;
begin
  FPlatforms.Free;
  inherited Destroy;
end;

{ TBoss4DPackage }

constructor TBoss4DIDEAssets.Create;
begin
  inherited Create;
  FTools := TList<string>.Create;
  FTemplates := TList<string>.Create;
  FRegistryValues := TObjectList<TBoss4DIDERegistryValue>.Create(True);
end;

destructor TBoss4DIDEAssets.Destroy;
begin
  FRegistryValues.Free;
  FTemplates.Free;
  FTools.Free;
  inherited Destroy;
end;

function TBoss4DIDEAssets.IsDeclared: Boolean;
begin
  Result := (FTools.Count > 0) or (FTemplates.Count > 0) or
    (FRegistryValues.Count > 0);
end;

constructor TBoss4DPackage.Create;
begin
  inherited Create;
  FProjects := TList<string>.Create;
  FScripts := TDictionary<string, string>.Create;
  FDependencies := TDictionary<string, string>.Create;
  FDevDependencies := TDictionary<string, string>.Create;
  FEngines := TBoss4DPackageEngines.Create;
  FToolchain := TBoss4DPackageToolchain.Create;
  FTrust := TBoss4DPackageTrust.Create;
  FWorkspaces := TList<string>.Create;
  FSbomComponents := TObjectList<TBoss4DManualComponent>.Create(True);
  FBuildMatrix := TBoss4DBuildMatrix.Create;
  FIDEAssets := TBoss4DIDEAssets.Create;
end;

destructor TBoss4DPackage.Destroy;
begin
  FIDEAssets.Free;
  FBuildMatrix.Free;
  FSbomComponents.Free;
  FWorkspaces.Free;
  FTrust.Free;
  FToolchain.Free;
  FEngines.Free;
  FDevDependencies.Free;
  FDependencies.Free;
  FScripts.Free;
  FProjects.Free;
  inherited Destroy;
end;

procedure TBoss4DPackage.AddDependency(const ADep: string; const AVer: string);
begin
  // Evita duplicacao de dependencias por diferenca de maiusculas/minusculas
  var LFoundKey := '';
  for var LKey in FDependencies.Keys do
  begin
    if SameText(LKey, ADep) then
    begin
      LFoundKey := LKey;
      Break;
    end;
  end;

  if not LFoundKey.IsEmpty then
    FDependencies.AddOrSetValue(LFoundKey, AVer)
  else
    FDependencies.Add(ADep, AVer);
end;

procedure TBoss4DPackage.AddDevDependency(const ADep, AVer: string);
var
  LKey, LFoundKey: string;
begin
  LFoundKey := '';
  for LKey in FDevDependencies.Keys do
    if SameText(LKey, ADep) then
    begin
      LFoundKey := LKey;
      Break;
    end;
  if not LFoundKey.IsEmpty then
    FDevDependencies.AddOrSetValue(LFoundKey, AVer)
  else
    FDevDependencies.Add(ADep, AVer);
end;

function TBoss4DPackage.RemoveDependency(const ADep: string): Boolean;
var
  LKey, LFoundKey: string;
begin
  LFoundKey := '';
  for LKey in FDependencies.Keys do
    if SameText(LKey, ADep) then
    begin
      LFoundKey := LKey;
      Break;
    end;
  Result := not LFoundKey.IsEmpty;
  if Result then
    FDependencies.Remove(LFoundKey);
end;

procedure TBoss4DPackage.AddProject(const AProject: string);
begin
  if not FProjects.Contains(AProject) then
    FProjects.Add(AProject);
end;

function TBoss4DPackage.GetParsedDependencies: TArray<TBoss4DDependency>;
var
  LResultList: TList<TBoss4DDependency>;
begin
  if FDependencies.Count = 0 then
    Exit(nil);

  LResultList := TList<TBoss4DDependency>.Create;
  try
    for var LPair in FDependencies do
    begin
      LResultList.Add(TBoss4DDependency.Parse(LPair.Key, LPair.Value));
    end;
    Result := LResultList.ToArray;
  finally
    LResultList.Free;
  end;
end;

function TBoss4DPackage.GetParsedDevDependencies: TArray<TBoss4DDependency>;
var
  LResultList: TList<TBoss4DDependency>;
  LDep: TBoss4DDependency;
begin
  if FDevDependencies.Count = 0 then
    Exit(nil);
  LResultList := TList<TBoss4DDependency>.Create;
  try
    for var LPair in FDevDependencies do
    begin
      LDep := TBoss4DDependency.Parse(LPair.Key, LPair.Value);
      LDep.Scope := 'development';
      LResultList.Add(LDep);
    end;
    Result := LResultList.ToArray;
  finally
    LResultList.Free;
  end;
end;

end.
