unit Boss4D.Core.Services.PackageIndex;

interface

uses
  System.Generics.Collections, System.JSON, Boss4D.Core.Ports,
  Boss4D.Core.Services.Config;

type
  TBoss4DPackageArtifactVariant = class
  private
    FPlatform: string;
    FCompiler: string;
    FArtifactUrl: string;
    FArtifactDigest: string;
    FSignatureUrl: string;
    FProvenanceUrl: string;
    FArtifactMirrors: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property Platform: string read FPlatform write FPlatform;
    property Compiler: string read FCompiler write FCompiler;
    property ArtifactUrl: string read FArtifactUrl write FArtifactUrl;
    property ArtifactDigest: string read FArtifactDigest write FArtifactDigest;
    property SignatureUrl: string read FSignatureUrl write FSignatureUrl;
    property ProvenanceUrl: string read FProvenanceUrl write FProvenanceUrl;
    property ArtifactMirrors: TList<string> read FArtifactMirrors;
  end;

  TBoss4DPackageVersion = class
  private
    FVersion: string;
    FRevoked: Boolean;
    FArtifactUrl: string;
    FArtifactDigest: string;
    FSignatureUrl: string;
    FProvenanceUrl: string;
    FChangelogUrl: string;
    FSbomUrl: string;
    FDependencies: TList<string>;
    FArtifactMirrors: TList<string>;
    FVariants: TObjectList<TBoss4DPackageArtifactVariant>;
  public
    constructor Create;
    destructor Destroy; override;
    function SelectVariant(const APlatform, ACompiler: string):
      TBoss4DPackageArtifactVariant;
    property Version: string read FVersion write FVersion;
    property Revoked: Boolean read FRevoked write FRevoked;
    property ArtifactUrl: string read FArtifactUrl write FArtifactUrl;
    property ArtifactDigest: string read FArtifactDigest write FArtifactDigest;
    property SignatureUrl: string read FSignatureUrl write FSignatureUrl;
    property ProvenanceUrl: string read FProvenanceUrl write FProvenanceUrl;
    property ChangelogUrl: string read FChangelogUrl write FChangelogUrl;
    property SbomUrl: string read FSbomUrl write FSbomUrl;
    property Dependencies: TList<string> read FDependencies;
    property ArtifactMirrors: TList<string> read FArtifactMirrors;
    property Variants: TObjectList<TBoss4DPackageArtifactVariant> read FVariants;
  end;

  TBoss4DPackageIndexEntry = class
  private
    FName: string;
    FRepository: string;
    FDescription: string;
    FLatestVersion: string;
    FLicense: string;
    FSource: string;
    FArtifactUrl: string;
    FArtifactDigest: string;
    FSignatureUrl: string;
    FProvenanceUrl: string;
    FChangelogUrl: string;
    FSbomUrl: string;
    FDependencies: TList<string>;
    FVariants: TObjectList<TBoss4DPackageArtifactVariant>;
    FVersions: TObjectList<TBoss4DPackageVersion>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure RefreshLatest;
    function SelectVariant(const APlatform, ACompiler: string):
      TBoss4DPackageArtifactVariant;
    function ResolveVersion(const ARange: string): TBoss4DPackageVersion;
    property Name: string read FName write FName;
    property Repository: string read FRepository write FRepository;
    property Description: string read FDescription write FDescription;
    property LatestVersion: string read FLatestVersion write FLatestVersion;
    property License: string read FLicense write FLicense;
    property Source: string read FSource write FSource;
    property ArtifactUrl: string read FArtifactUrl write FArtifactUrl;
    property ArtifactDigest: string read FArtifactDigest write FArtifactDigest;
    property SignatureUrl: string read FSignatureUrl write FSignatureUrl;
    property ProvenanceUrl: string read FProvenanceUrl write FProvenanceUrl;
    property ChangelogUrl: string read FChangelogUrl write FChangelogUrl;
    property SbomUrl: string read FSbomUrl write FSbomUrl;
    property Dependencies: TList<string> read FDependencies;
    property Variants: TObjectList<TBoss4DPackageArtifactVariant> read FVariants;
    property Versions: TObjectList<TBoss4DPackageVersion> read FVersions;
  end;

  TBoss4DPackageIndexService = class
  private
    FConfigService: TBoss4DConfigService;
    FHttp: IBoss4DHttpClient;
    FLogger: IBoss4DLogger;
    function ReadSource(const ASource: string): string;
    function ResolveRegistryReference(const ASource,
      AReference: string): string;
    procedure ReadStringArray(const AObject: TJSONObject;
      const AName: string; const ATarget: TList<string>);
    function ParseVariant(const AObject: TJSONObject):
      TBoss4DPackageArtifactVariant;
    function ParseVersion(const AObject: TJSONObject):
      TBoss4DPackageVersion;
    function ParsePackage(const ASource: string; const ASchemaVersion: Integer;
      const AObject: TJSONObject): TBoss4DPackageIndexEntry;
    procedure LoadRegistryLinks(const ASource: string;
      const ARoot: TJSONObject;
      const AEntries: TObjectList<TBoss4DPackageIndexEntry>;
      const AVisited: TDictionary<string, Boolean>);
    procedure ApplyRegistryRevocations(const ARoot: TJSONObject;
      const AEntries: TObjectList<TBoss4DPackageIndexEntry>);
    procedure AddBuiltIn(const AEntries: TObjectList<TBoss4DPackageIndexEntry>);
    procedure LoadRegistry(const ASource: string;
      const AEntries: TObjectList<TBoss4DPackageIndexEntry>);
    procedure LoadRegistryInternal(const ASource: string;
      const AEntries: TObjectList<TBoss4DPackageIndexEntry>;
      const AVisited: TDictionary<string, Boolean>);
  public
    constructor Create(const AConfigService: TBoss4DConfigService;
      const AHttp: IBoss4DHttpClient; const ALogger: IBoss4DLogger);
    function Search(const AQuery: string):
      TObjectList<TBoss4DPackageIndexEntry>;
    function Info(const AName: string): TBoss4DPackageIndexEntry;
    function Versions(const AName: string): TArray<string>;
    procedure AddRegistry(const ASource: string);
    procedure RemoveRegistry(const ASource: string);
    function ListRegistries: TArray<string>;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Hash,
  Boss4D.Core.Domain.SemVer, Boss4D.Core.Services.Resolver;

const
  BOSS4D_PUBLIC_REGISTRY =
    'https://raw.githubusercontent.com/regyssilveira/Boss4Delphi/main/registry/index-v2.json';

function TBoss4DPackageIndexService.ReadSource(const ASource: string): string;
var
  LStatus: Integer;
  LCacheDirectory, LCachePath, LContent: string;
  function IsValidRegistryContent(const AContent: string): Boolean;
  begin
    Result := False;
    var LValue := TJSONObject.ParseJSONValue(AContent);
    try
      if not (LValue is TJSONObject) then Exit;
      var LSchema := TJSONObject(LValue).GetValue<Integer>(
        'schemaVersion', 0);
      Result := LSchema in [1, 2];
    finally
      LValue.Free;
    end;
  end;
begin
  if not ASource.StartsWith('http://', True) and
     not ASource.StartsWith('https://', True) then
    Exit(TFile.ReadAllText(TPath.GetFullPath(ASource), TEncoding.UTF8));
  LCacheDirectory := TPath.Combine(GetEnvironmentVariable('BOSS_HOME'),
    'registry-cache');
  if GetEnvironmentVariable('BOSS_HOME').IsEmpty then
    LCacheDirectory := TPath.Combine(TPath.GetHomePath,
      TPath.Combine('.boss', 'registry-cache'));
  LCachePath := TPath.Combine(LCacheDirectory,
    THashSHA2.GetHashString(ASource.ToLower).ToLower + '.json');
  LStatus := FHttp.Get(ASource, LContent);
  if (LStatus >= 200) and (LStatus < 300) and
     IsValidRegistryContent(LContent) then
  begin
    TDirectory.CreateDirectory(LCacheDirectory);
    TFile.WriteAllText(LCachePath, LContent, TEncoding.UTF8);
    Exit(LContent);
  end;
  if TFile.Exists(LCachePath) then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning,
      Format('Registry HTTP/conteudo invalido (%d); usando cache local: %s',
        [LStatus, ASource]));
    Exit(TFile.ReadAllText(LCachePath, TEncoding.UTF8));
  end;
  raise Exception.CreateFmt('Registry %s respondeu HTTP %d',
    [ASource, LStatus]);
end;

constructor TBoss4DPackageArtifactVariant.Create;
begin
  inherited Create;
  FArtifactMirrors := TList<string>.Create;
end;

destructor TBoss4DPackageArtifactVariant.Destroy;
begin
  FArtifactMirrors.Free;
  inherited Destroy;
end;

constructor TBoss4DPackageVersion.Create;
begin
  inherited Create;
  FVariants := TObjectList<TBoss4DPackageArtifactVariant>.Create(True);
  FArtifactMirrors := TList<string>.Create;
  FDependencies := TList<string>.Create;
end;

destructor TBoss4DPackageVersion.Destroy;
begin
  FDependencies.Free;
  FArtifactMirrors.Free;
  FVariants.Free;
  inherited Destroy;
end;

procedure TBoss4DPackageIndexEntry.RefreshLatest;
begin
  FLatestVersion := '';
  FArtifactUrl := '';
  FArtifactDigest := '';
  FSignatureUrl := '';
  FProvenanceUrl := '';
  FVariants.Clear;
  for var LPackageVersion in FVersions do
    if not LPackageVersion.Revoked then
    begin
      FLatestVersion := LPackageVersion.Version;
      FArtifactUrl := LPackageVersion.ArtifactUrl;
      FArtifactDigest := LPackageVersion.ArtifactDigest;
      FSignatureUrl := LPackageVersion.SignatureUrl;
      FProvenanceUrl := LPackageVersion.ProvenanceUrl;
      if not LPackageVersion.ChangelogUrl.IsEmpty then
        FChangelogUrl := LPackageVersion.ChangelogUrl;
      if not LPackageVersion.SbomUrl.IsEmpty then
        FSbomUrl := LPackageVersion.SbomUrl;
      if LPackageVersion.Dependencies.Count > 0 then
      begin
        FDependencies.Clear;
        FDependencies.AddRange(LPackageVersion.Dependencies.ToArray);
      end;
      for var LVariant in LPackageVersion.Variants do
      begin
        var LCopy := TBoss4DPackageArtifactVariant.Create;
        LCopy.Platform := LVariant.Platform;
        LCopy.Compiler := LVariant.Compiler;
        LCopy.ArtifactUrl := LVariant.ArtifactUrl;
        LCopy.ArtifactDigest := LVariant.ArtifactDigest;
        LCopy.SignatureUrl := LVariant.SignatureUrl;
        LCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
        LCopy.ArtifactMirrors.AddRange(LVariant.ArtifactMirrors.ToArray);
        FVariants.Add(LCopy);
      end;
      Break;
    end;
end;

function TBoss4DPackageVersion.SelectVariant(const APlatform,
  ACompiler: string): TBoss4DPackageArtifactVariant;
var
  LBestScore, LScore: Integer;
begin
  Result := nil;
  LBestScore := -1;
  for var LVariant in FVariants do
  begin
    if not LVariant.Platform.IsEmpty and
       not SameText(LVariant.Platform, APlatform) then Continue;
    if not LVariant.Compiler.IsEmpty and
       not SameText(LVariant.Compiler, ACompiler) then Continue;
    LScore := 0;
    if not LVariant.Platform.IsEmpty then Inc(LScore, 2);
    if not LVariant.Compiler.IsEmpty then Inc(LScore);
    if LScore > LBestScore then
    begin
      LBestScore := LScore;
      Result := LVariant;
    end;
  end;
end;

constructor TBoss4DPackageIndexEntry.Create;
begin
  inherited Create;
  FVariants := TObjectList<TBoss4DPackageArtifactVariant>.Create(True);
  FVersions := TObjectList<TBoss4DPackageVersion>.Create(True);
  FDependencies := TList<string>.Create;
end;

destructor TBoss4DPackageIndexEntry.Destroy;
begin
  FDependencies.Free;
  FVersions.Free;
  FVariants.Free;
  inherited Destroy;
end;

function TBoss4DPackageIndexEntry.ResolveVersion(
  const ARange: string): TBoss4DPackageVersion;
begin
  Result := nil;
  var LCandidates := TList<string>.Create;
  try
    for var LVersion in FVersions do
      if not LVersion.Revoked then
        LCandidates.Add(LVersion.Version);
    var LResolved := TBoss4DVersionResolver.Create;
    try
      var LSelected := LResolved.Resolve(ARange, LCandidates.ToArray,
        TBoss4DResolutionStrategy.HighestCompatible);
      for var LVersion in FVersions do
        if SameText(LVersion.Version, LSelected) then
          Exit(LVersion);
    finally
      LResolved.Free;
    end;
  finally
    LCandidates.Free;
  end;
end;

function TBoss4DPackageIndexEntry.SelectVariant(const APlatform,
  ACompiler: string): TBoss4DPackageArtifactVariant;
var
  LBestScore, LScore: Integer;
begin
  Result := nil;
  LBestScore := -1;
  for var LVariant in FVariants do
  begin
    if not LVariant.Platform.IsEmpty and
       not SameText(LVariant.Platform, APlatform) then Continue;
    if not LVariant.Compiler.IsEmpty and
       not SameText(LVariant.Compiler, ACompiler) then Continue;
    LScore := 0;
    if not LVariant.Platform.IsEmpty then Inc(LScore, 2);
    if not LVariant.Compiler.IsEmpty then Inc(LScore);
    if LScore > LBestScore then
    begin
      LBestScore := LScore;
      Result := LVariant;
    end;
  end;
end;

constructor TBoss4DPackageIndexService.Create(
  const AConfigService: TBoss4DConfigService; const AHttp: IBoss4DHttpClient;
  const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FConfigService := AConfigService;
  FHttp := AHttp;
  FLogger := ALogger;
end;

procedure TBoss4DPackageIndexService.AddBuiltIn(
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>);
const
  NAMES: array[0..6] of string = ('Horse', 'RESTRequest4Delphi', 'mORMot',
    'Skia4Delphi', 'Dext', 'Boss4Delphi', 'DataSet-Serialize');
  REPOS: array[0..6] of string = ('github.com/hashload/horse',
    'github.com/viniciussanchez/RESTRequest4Delphi',
    'github.com/synopse/mORMot2', 'github.com/skia4delphi/skia4delphi',
    'github.com/regyssilveira/dext', 'github.com/regyssilveira/Boss4Delphi',
    'github.com/viniciussanchez/dataset-serialize');
begin
  for var I := Low(NAMES) to High(NAMES) do
  begin
    var LEntry := TBoss4DPackageIndexEntry.Create;
    LEntry.Name := NAMES[I];
    LEntry.Repository := REPOS[I];
    LEntry.Source := 'builtin';
    AEntries.Add(LEntry);
  end;
end;

procedure TBoss4DPackageIndexService.LoadRegistry(const ASource: string;
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>);
begin
  var LVisited := TDictionary<string, Boolean>.Create;
  try
    LoadRegistryInternal(ASource, AEntries, LVisited);
  finally
    LVisited.Free;
  end;
end;

function TBoss4DPackageIndexService.ResolveRegistryReference(
  const ASource, AReference: string): string;
begin
  if AReference.StartsWith('http://', True) or
     AReference.StartsWith('https://', True) or
     TPath.IsPathRooted(AReference) then
    Exit(AReference);
  if ASource.StartsWith('http://', True) or
     ASource.StartsWith('https://', True) then
    Exit(ASource.Substring(0, ASource.LastIndexOf('/') + 1) +
      AReference.Replace('\', '/'));
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.GetDirectoryName(TPath.GetFullPath(ASource)), AReference));
end;

procedure TBoss4DPackageIndexService.ReadStringArray(
  const AObject: TJSONObject; const AName: string;
  const ATarget: TList<string>);
begin
  if not (AObject.GetValue(AName) is TJSONArray) then Exit;
  for var LValue in TJSONArray(AObject.GetValue(AName)) do
    if LValue is TJSONString then ATarget.Add(LValue.Value);
end;

function TBoss4DPackageIndexService.ParseVariant(
  const AObject: TJSONObject): TBoss4DPackageArtifactVariant;
begin
  Result := TBoss4DPackageArtifactVariant.Create;
  Result.Platform := AObject.GetValue<string>('platform', '');
  Result.Compiler := AObject.GetValue<string>('compiler', '');
  Result.ArtifactUrl := AObject.GetValue<string>('artifact', '');
  Result.ArtifactDigest := AObject.GetValue<string>('sha256', '');
  Result.SignatureUrl := AObject.GetValue<string>('signature', '');
  Result.ProvenanceUrl := AObject.GetValue<string>('provenance', '');
  ReadStringArray(AObject, 'mirrors', Result.ArtifactMirrors);
  if Result.ArtifactUrl.IsEmpty or Result.ArtifactDigest.IsEmpty then
    FreeAndNil(Result);
end;

function TBoss4DPackageIndexService.ParseVersion(
  const AObject: TJSONObject): TBoss4DPackageVersion;
begin
  Result := TBoss4DPackageVersion.Create;
  Result.Version := AObject.GetValue<string>('version', '');
  if not TBoss4DSemVer.Create(Result.Version).IsValid then
  begin
    FreeAndNil(Result);
    Exit;
  end;
  Result.Revoked := AObject.GetValue<Boolean>('revoked', False);
  Result.ArtifactUrl := AObject.GetValue<string>('artifact', '');
  Result.ArtifactDigest := AObject.GetValue<string>('sha256', '');
  Result.SignatureUrl := AObject.GetValue<string>('signature', '');
  Result.ProvenanceUrl := AObject.GetValue<string>('provenance', '');
  Result.ChangelogUrl := AObject.GetValue<string>('changelog', '');
  Result.SbomUrl := AObject.GetValue<string>('sbom', '');
  ReadStringArray(AObject, 'dependencies', Result.Dependencies);
  ReadStringArray(AObject, 'mirrors', Result.ArtifactMirrors);
  if AObject.GetValue('variants') is TJSONArray then
    for var LValue in TJSONArray(AObject.GetValue('variants')) do
      if LValue is TJSONObject then
      begin
        var LVariant := ParseVariant(TJSONObject(LValue));
        if Assigned(LVariant) then Result.Variants.Add(LVariant);
      end;
end;

function TBoss4DPackageIndexService.ParsePackage(const ASource: string;
  const ASchemaVersion: Integer;
  const AObject: TJSONObject): TBoss4DPackageIndexEntry;
begin
  Result := TBoss4DPackageIndexEntry.Create;
  Result.Name := AObject.GetValue<string>('name', '');
  Result.Repository := AObject.GetValue<string>('repository', '');
  Result.Description := AObject.GetValue<string>('description', '');
  Result.LatestVersion := AObject.GetValue<string>('version', '');
  Result.License := AObject.GetValue<string>('license', '');
  Result.ArtifactUrl := AObject.GetValue<string>('artifact', '');
  Result.ArtifactDigest := AObject.GetValue<string>('sha256', '');
  Result.SignatureUrl := AObject.GetValue<string>('signature', '');
  Result.ProvenanceUrl := AObject.GetValue<string>('provenance', '');
  Result.ChangelogUrl := AObject.GetValue<string>('changelog', '');
  Result.SbomUrl := AObject.GetValue<string>('sbom', '');
  ReadStringArray(AObject, 'dependencies', Result.Dependencies);
  if (ASchemaVersion = 2) and
     (AObject.GetValue('versions') is TJSONArray) then
    for var LValue in TJSONArray(AObject.GetValue('versions')) do
      if LValue is TJSONObject then
      begin
        var LVersion := ParseVersion(TJSONObject(LValue));
        if not Assigned(LVersion) then Continue;
        var LInsertAt := 0;
        while (LInsertAt < Result.Versions.Count) and
          (TBoss4DSemVer.Create(Result.Versions[LInsertAt].Version) >
           TBoss4DSemVer.Create(LVersion.Version)) do Inc(LInsertAt);
        Result.Versions.Insert(LInsertAt, LVersion);
      end;
  if ASchemaVersion = 2 then Result.RefreshLatest;
  if (Result.Versions.Count = 0) and
     TBoss4DSemVer.Create(Result.LatestVersion).IsValid then
  begin
    var LLegacy := TBoss4DPackageVersion.Create;
    LLegacy.Version := Result.LatestVersion;
    LLegacy.ArtifactUrl := Result.ArtifactUrl;
    LLegacy.ArtifactDigest := Result.ArtifactDigest;
    LLegacy.SignatureUrl := Result.SignatureUrl;
    LLegacy.ProvenanceUrl := Result.ProvenanceUrl;
    LLegacy.ChangelogUrl := Result.ChangelogUrl;
    LLegacy.SbomUrl := Result.SbomUrl;
    LLegacy.Dependencies.AddRange(Result.Dependencies.ToArray);
    Result.Versions.Add(LLegacy);
  end;
  Result.Source := ASource;
  if Result.Name.IsEmpty or Result.Repository.IsEmpty then
    FreeAndNil(Result);
end;

procedure TBoss4DPackageIndexService.LoadRegistryLinks(
  const ASource: string; const ARoot: TJSONObject;
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>;
  const AVisited: TDictionary<string, Boolean>);
begin
  if ARoot.GetValue('includes') is TJSONArray then
    for var LInclude in TJSONArray(ARoot.GetValue('includes')) do
      LoadRegistryInternal(ResolveRegistryReference(ASource, LInclude.Value),
        AEntries, AVisited);
  if not (ARoot.GetValue('sparse') is TJSONArray) then Exit;
  for var LSparse in TJSONArray(ARoot.GetValue('sparse')) do
  begin
    var LCandidates := TList<string>.Create;
    try
      if LSparse is TJSONString then LCandidates.Add(LSparse.Value)
      else if LSparse is TJSONObject then
      begin
        var LPath := TJSONObject(LSparse).GetValue<string>('path', '');
        if not LPath.IsEmpty then LCandidates.Add(LPath);
        ReadStringArray(TJSONObject(LSparse), 'mirrors', LCandidates);
      end;
      var LLoaded := False;
      for var LCandidate in LCandidates do
        try
          LoadRegistryInternal(ResolveRegistryReference(
            ASource, LCandidate), AEntries, AVisited);
          LLoaded := True;
          Break;
        except
          on E: Exception do FLogger.Log(TBoss4DLogLevel.Warning,
            'Fonte sparse indisponivel: ' + E.Message);
        end;
      if not LLoaded then
        raise Exception.Create('Nenhuma fonte sparse pode ser carregada.');
    finally
      LCandidates.Free;
    end;
  end;
end;

procedure TBoss4DPackageIndexService.ApplyRegistryRevocations(
  const ARoot: TJSONObject;
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>);
begin
  if not (ARoot.GetValue('revocations') is TJSONArray) then Exit;
  for var LValue in TJSONArray(ARoot.GetValue('revocations')) do
    if LValue is TJSONObject then
    begin
      var LName := TJSONObject(LValue).GetValue<string>('name', '');
      var LVersionName := TJSONObject(LValue).GetValue<string>('version', '');
      for var LEntry in AEntries do
        if SameText(LEntry.Name, LName) then
        begin
          for var LVersion in LEntry.Versions do
            if SameText(LVersion.Version, LVersionName) then
              LVersion.Revoked := True;
          LEntry.RefreshLatest;
        end;
    end;
end;

procedure TBoss4DPackageIndexService.LoadRegistryInternal(const ASource: string;
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>;
  const AVisited: TDictionary<string, Boolean>);
begin
  if AVisited.ContainsKey(ASource.ToLower) then Exit;
  AVisited.Add(ASource.ToLower, True);
  var LValue := TJSONObject.ParseJSONValue(ReadSource(ASource));
  try
    if not (LValue is TJSONObject) then
      raise Exception.Create('Indice deve ser um objeto JSON: ' + ASource);
    var LRoot := TJSONObject(LValue);
    var LSchemaVersion := LRoot.GetValue<Integer>('schemaVersion', 0);
    if not (LSchemaVersion in [1, 2]) then
      raise Exception.CreateFmt('Schema de registry nao suportado: %d',
        [LSchemaVersion]);
    if LSchemaVersion = 2 then
      LoadRegistryLinks(ASource, LRoot, AEntries, AVisited);
    var LPackages := LRoot.GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
      if LSchemaVersion = 1 then
        raise Exception.Create('Indice nao contem packages: ' + ASource)
      else
        Exit;
    for var LValueItem in LPackages do
      if LValueItem is TJSONObject then
      begin
        var LEntry := ParsePackage(ASource, LSchemaVersion,
          TJSONObject(LValueItem));
        if Assigned(LEntry) then AEntries.Add(LEntry);
      end;
    if LSchemaVersion = 2 then ApplyRegistryRevocations(LRoot, AEntries);
  finally
    LValue.Free;
  end;
end;

function TBoss4DPackageIndexService.Search(
  const AQuery: string): TObjectList<TBoss4DPackageIndexEntry>;
var
  LAll: TObjectList<TBoss4DPackageIndexEntry>;
  LConfig: TBoss4DGlobalConfig;
begin
  Result := TObjectList<TBoss4DPackageIndexEntry>.Create(True);
  LAll := TObjectList<TBoss4DPackageIndexEntry>.Create(True);
  LConfig := FConfigService.Load;
  try
    try
      LoadRegistry(BOSS4D_PUBLIC_REGISTRY, LAll);
    except
      on E: Exception do
      begin
        FLogger.Log(TBoss4DLogLevel.Warning,
          'Registro publico indisponivel; usando catalogo offline: ' +
          E.Message);
        AddBuiltIn(LAll);
      end;
    end;
    for var LSource in LConfig.Registries do
      try
        LoadRegistry(LSource, LAll);
      except
        on E: Exception do
          FLogger.Log(TBoss4DLogLevel.Warning, E.Message);
      end;
    var LSeenNames := TDictionary<string, Boolean>.Create;
    try
      for var I := LAll.Count - 1 downto 0 do
      begin
        var LEntry := LAll[I];
        var LIdentity := LEntry.Name.ToLowerInvariant;
        if LSeenNames.ContainsKey(LIdentity) then
          Continue;
        LSeenNames.Add(LIdentity, True);
        if not (AQuery.IsEmpty or LEntry.Name.Contains(AQuery, True) or
           LEntry.Repository.Contains(AQuery, True) or
           LEntry.Description.Contains(AQuery, True)) then
          Continue;
        var LCopy := TBoss4DPackageIndexEntry.Create;
        LCopy.Name := LEntry.Name;
        LCopy.Repository := LEntry.Repository;
        LCopy.Description := LEntry.Description;
        LCopy.LatestVersion := LEntry.LatestVersion;
        LCopy.License := LEntry.License;
        LCopy.Source := LEntry.Source;
        LCopy.ArtifactUrl := LEntry.ArtifactUrl;
        LCopy.ArtifactDigest := LEntry.ArtifactDigest;
        LCopy.SignatureUrl := LEntry.SignatureUrl;
        LCopy.ProvenanceUrl := LEntry.ProvenanceUrl;
        LCopy.ChangelogUrl := LEntry.ChangelogUrl;
        LCopy.SbomUrl := LEntry.SbomUrl;
        LCopy.Dependencies.AddRange(LEntry.Dependencies.ToArray);
        for var LVariant in LEntry.Variants do
        begin
          var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
          LVariantCopy.Platform := LVariant.Platform;
          LVariantCopy.Compiler := LVariant.Compiler;
          LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
          LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
          LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
          LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
          LVariantCopy.ArtifactMirrors.AddRange(
            LVariant.ArtifactMirrors.ToArray);
          LCopy.Variants.Add(LVariantCopy);
        end;
        for var LVersion in LEntry.Versions do
        begin
          var LVersionCopy := TBoss4DPackageVersion.Create;
          LVersionCopy.Version := LVersion.Version;
          LVersionCopy.Revoked := LVersion.Revoked;
          LVersionCopy.ArtifactUrl := LVersion.ArtifactUrl;
          LVersionCopy.ArtifactDigest := LVersion.ArtifactDigest;
          LVersionCopy.SignatureUrl := LVersion.SignatureUrl;
          LVersionCopy.ProvenanceUrl := LVersion.ProvenanceUrl;
          LVersionCopy.ChangelogUrl := LVersion.ChangelogUrl;
          LVersionCopy.SbomUrl := LVersion.SbomUrl;
          LVersionCopy.Dependencies.AddRange(
            LVersion.Dependencies.ToArray);
          LVersionCopy.ArtifactMirrors.AddRange(
            LVersion.ArtifactMirrors.ToArray);
          for var LVariant in LVersion.Variants do
          begin
            var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
            LVariantCopy.Platform := LVariant.Platform;
            LVariantCopy.Compiler := LVariant.Compiler;
            LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
            LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
            LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
            LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
            LVariantCopy.ArtifactMirrors.AddRange(
              LVariant.ArtifactMirrors.ToArray);
            LVersionCopy.Variants.Add(LVariantCopy);
          end;
          LCopy.Versions.Add(LVersionCopy);
        end;
        Result.Add(LCopy);
      end;
      Result.Reverse;
    finally
      LSeenNames.Free;
    end;
  finally
    LConfig.Free;
    LAll.Free;
  end;
end;

function TBoss4DPackageIndexService.Info(
  const AName: string): TBoss4DPackageIndexEntry;
begin
  Result := nil;
  var LEntries := Search(AName);
  try
    for var LEntry in LEntries do
      if SameText(LEntry.Name, AName) or
         SameText(LEntry.Repository, AName) then
      begin
        Result := TBoss4DPackageIndexEntry.Create;
        Result.Name := LEntry.Name;
        Result.Repository := LEntry.Repository;
        Result.Description := LEntry.Description;
        Result.LatestVersion := LEntry.LatestVersion;
        Result.License := LEntry.License;
        Result.Source := LEntry.Source;
        Result.ArtifactUrl := LEntry.ArtifactUrl;
        Result.ArtifactDigest := LEntry.ArtifactDigest;
        Result.SignatureUrl := LEntry.SignatureUrl;
        Result.ProvenanceUrl := LEntry.ProvenanceUrl;
        Result.ChangelogUrl := LEntry.ChangelogUrl;
        Result.SbomUrl := LEntry.SbomUrl;
        Result.Dependencies.AddRange(LEntry.Dependencies.ToArray);
        for var LVariant in LEntry.Variants do
        begin
          var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
          LVariantCopy.Platform := LVariant.Platform;
          LVariantCopy.Compiler := LVariant.Compiler;
          LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
          LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
          LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
          LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
          LVariantCopy.ArtifactMirrors.AddRange(
            LVariant.ArtifactMirrors.ToArray);
          Result.Variants.Add(LVariantCopy);
        end;
        for var LVersion in LEntry.Versions do
        begin
          var LVersionCopy := TBoss4DPackageVersion.Create;
          LVersionCopy.Version := LVersion.Version;
          LVersionCopy.Revoked := LVersion.Revoked;
          LVersionCopy.ArtifactUrl := LVersion.ArtifactUrl;
          LVersionCopy.ArtifactDigest := LVersion.ArtifactDigest;
          LVersionCopy.SignatureUrl := LVersion.SignatureUrl;
          LVersionCopy.ProvenanceUrl := LVersion.ProvenanceUrl;
          LVersionCopy.ChangelogUrl := LVersion.ChangelogUrl;
          LVersionCopy.SbomUrl := LVersion.SbomUrl;
          LVersionCopy.Dependencies.AddRange(
            LVersion.Dependencies.ToArray);
          LVersionCopy.ArtifactMirrors.AddRange(
            LVersion.ArtifactMirrors.ToArray);
          for var LVariant in LVersion.Variants do
          begin
            var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
            LVariantCopy.Platform := LVariant.Platform;
            LVariantCopy.Compiler := LVariant.Compiler;
            LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
            LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
            LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
            LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
            LVariantCopy.ArtifactMirrors.AddRange(
              LVariant.ArtifactMirrors.ToArray);
            LVersionCopy.Variants.Add(LVariantCopy);
          end;
          Result.Versions.Add(LVersionCopy);
        end;
        Exit;
      end;
  finally
    LEntries.Free;
  end;
end;

function TBoss4DPackageIndexService.Versions(
  const AName: string): TArray<string>;
begin
  Result := nil;
  var LEntry := Info(AName);
  try
    if not Assigned(LEntry) then
      Exit;
    SetLength(Result, LEntry.Versions.Count);
    for var I := 0 to LEntry.Versions.Count - 1 do
    begin
      Result[I] := LEntry.Versions[I].Version;
      if LEntry.Versions[I].Revoked then
        Result[I] := Result[I] + ' (revoked)';
    end;
  finally
    LEntry.Free;
  end;
end;

procedure TBoss4DPackageIndexService.AddRegistry(const ASource: string);
begin
  var LConfig := FConfigService.Load;
  try
    for var LExisting in LConfig.Registries do
      if SameText(LExisting, ASource) then Exit;
    LConfig.Registries.Add(ASource);
    FConfigService.Save(LConfig);
  finally
    LConfig.Free;
  end;
end;

procedure TBoss4DPackageIndexService.RemoveRegistry(const ASource: string);
begin
  var LConfig := FConfigService.Load;
  try
    for var I := LConfig.Registries.Count - 1 downto 0 do
      if SameText(LConfig.Registries[I], ASource) then
        LConfig.Registries.Delete(I);
    FConfigService.Save(LConfig);
  finally
    LConfig.Free;
  end;
end;

function TBoss4DPackageIndexService.ListRegistries: TArray<string>;
begin
  var LConfig := FConfigService.Load;
  try
    Result := LConfig.Registries.ToArray;
  finally
    LConfig.Free;
  end;
end;

end.
