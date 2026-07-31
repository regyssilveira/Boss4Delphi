unit Boss4D.Core.Services.PackageIndex;

interface

uses
  System.Generics.Collections, Boss4D.Core.Ports,
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
  public
    property Platform: string read FPlatform write FPlatform;
    property Compiler: string read FCompiler write FCompiler;
    property ArtifactUrl: string read FArtifactUrl write FArtifactUrl;
    property ArtifactDigest: string read FArtifactDigest write FArtifactDigest;
    property SignatureUrl: string read FSignatureUrl write FSignatureUrl;
    property ProvenanceUrl: string read FProvenanceUrl write FProvenanceUrl;
  end;

  TBoss4DPackageVersion = class
  private
    FVersion: string;
    FRevoked: Boolean;
    FArtifactUrl: string;
    FArtifactDigest: string;
    FSignatureUrl: string;
    FProvenanceUrl: string;
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
    FVariants: TObjectList<TBoss4DPackageArtifactVariant>;
    FVersions: TObjectList<TBoss4DPackageVersion>;
  public
    constructor Create;
    destructor Destroy; override;
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
    property Variants: TObjectList<TBoss4DPackageArtifactVariant> read FVariants;
    property Versions: TObjectList<TBoss4DPackageVersion> read FVersions;
  end;

  TBoss4DPackageIndexService = class
  private
    FConfigService: TBoss4DConfigService;
    FHttp: IBoss4DHttpClient;
    FLogger: IBoss4DLogger;
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
  System.SysUtils, System.IOUtils, System.JSON,
  Boss4D.Core.Domain.SemVer, Boss4D.Core.Services.Resolver;

const
  BOSS4D_PUBLIC_REGISTRY =
    'https://raw.githubusercontent.com/regyssilveira/Boss4Delphi/main/registry/index-v2.json';

constructor TBoss4DPackageVersion.Create;
begin
  inherited Create;
  FVariants := TObjectList<TBoss4DPackageArtifactVariant>.Create(True);
end;

destructor TBoss4DPackageVersion.Destroy;
begin
  FVariants.Free;
  inherited Destroy;
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
end;

destructor TBoss4DPackageIndexEntry.Destroy;
begin
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

procedure TBoss4DPackageIndexService.LoadRegistryInternal(const ASource: string;
  const AEntries: TObjectList<TBoss4DPackageIndexEntry>;
  const AVisited: TDictionary<string, Boolean>);
var
  LContent: string;
  LStatus: Integer;
begin
  if AVisited.ContainsKey(ASource.ToLower) then
    Exit;
  AVisited.Add(ASource.ToLower, True);
  if ASource.StartsWith('http://', True) or
     ASource.StartsWith('https://', True) then
  begin
    LStatus := FHttp.Get(ASource, LContent);
    if (LStatus < 200) or (LStatus >= 300) then
      raise Exception.CreateFmt('Registry %s respondeu HTTP %d',
        [ASource, LStatus]);
  end
  else
    LContent := TFile.ReadAllText(TPath.GetFullPath(ASource), TEncoding.UTF8);
  var LValue := TJSONObject.ParseJSONValue(LContent);
  try
    if not (LValue is TJSONObject) then
      raise Exception.Create('Indice deve ser um objeto JSON: ' + ASource);
    var LSchemaVersion := TJSONObject(LValue).GetValue<Integer>(
      'schemaVersion', 0);
    if not (LSchemaVersion in [1, 2]) then
      raise Exception.CreateFmt('Schema de registry nao suportado: %d',
        [LSchemaVersion]);
    if LSchemaVersion = 2 then
    begin
      var LIncludes: TJSONArray := nil;
      if TJSONObject(LValue).GetValue('includes') is TJSONArray then
        LIncludes := TJSONArray(TJSONObject(LValue).GetValue('includes'));
      if Assigned(LIncludes) then
        for var LInclude in LIncludes do
        begin
          var LReference := LInclude.Value;
          var LResolved: string;
          if LReference.StartsWith('http://', True) or
             LReference.StartsWith('https://', True) or
             TPath.IsPathRooted(LReference) then
            LResolved := LReference
          else if ASource.StartsWith('http://', True) or
                  ASource.StartsWith('https://', True) then
            LResolved := ASource.Substring(0, ASource.LastIndexOf('/') + 1) +
              LReference.Replace('\', '/')
          else
            LResolved := TPath.GetFullPath(TPath.Combine(
              TPath.GetDirectoryName(TPath.GetFullPath(ASource)), LReference));
          LoadRegistryInternal(LResolved, AEntries, AVisited);
        end;
    end;
    var LPackages := TJSONObject(LValue).GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
      if LSchemaVersion = 1 then
        raise Exception.Create('Indice nao contem packages: ' + ASource)
      else
        Exit;
    for var I := 0 to LPackages.Count - 1 do
      if LPackages[I] is TJSONObject then
      begin
        var LObject := TJSONObject(LPackages[I]);
        var LEntry := TBoss4DPackageIndexEntry.Create;
        LEntry.Name := LObject.GetValue<string>('name', '');
        LEntry.Repository := LObject.GetValue<string>('repository', '');
        LEntry.Description := LObject.GetValue<string>('description', '');
        LEntry.LatestVersion := LObject.GetValue<string>('version', '');
        LEntry.License := LObject.GetValue<string>('license', '');
        LEntry.ArtifactUrl := LObject.GetValue<string>('artifact', '');
        LEntry.ArtifactDigest := LObject.GetValue<string>('sha256', '');
        LEntry.SignatureUrl := LObject.GetValue<string>('signature', '');
        LEntry.ProvenanceUrl := LObject.GetValue<string>('provenance', '');
        if LSchemaVersion = 2 then
        begin
          var LVersions: TJSONArray := nil;
          if LObject.GetValue('versions') is TJSONArray then
            LVersions := TJSONArray(LObject.GetValue('versions'));
          if Assigned(LVersions) then
            for var LVersionValue in LVersions do
              if LVersionValue is TJSONObject then
              begin
                var LVersionObject := TJSONObject(LVersionValue);
                var LPackageVersion := TBoss4DPackageVersion.Create;
                LPackageVersion.Version := LVersionObject.GetValue<string>(
                  'version', '');
                var LSemVer := TBoss4DSemVer.Create(LPackageVersion.Version);
                if not LSemVer.IsValid then
                begin
                  LPackageVersion.Free;
                  Continue;
                end;
                LPackageVersion.Revoked := LVersionObject.GetValue<Boolean>(
                  'revoked', False);
                LPackageVersion.ArtifactUrl := LVersionObject.GetValue<string>(
                  'artifact', '');
                LPackageVersion.ArtifactDigest := LVersionObject.GetValue<string>(
                  'sha256', '');
                LPackageVersion.SignatureUrl := LVersionObject.GetValue<string>(
                  'signature', '');
                LPackageVersion.ProvenanceUrl := LVersionObject.GetValue<string>(
                  'provenance', '');
                var LVariants: TJSONArray := nil;
                if LVersionObject.GetValue('variants') is TJSONArray then
                  LVariants := TJSONArray(LVersionObject.GetValue('variants'));
                if Assigned(LVariants) then
                  for var LVariantValue in LVariants do
                    if LVariantValue is TJSONObject then
                    begin
                      var LVariantObject := TJSONObject(LVariantValue);
                      var LVariant := TBoss4DPackageArtifactVariant.Create;
                      LVariant.Platform := LVariantObject.GetValue<string>(
                        'platform', '');
                      LVariant.Compiler := LVariantObject.GetValue<string>(
                        'compiler', '');
                      LVariant.ArtifactUrl := LVariantObject.GetValue<string>(
                        'artifact', '');
                      LVariant.ArtifactDigest := LVariantObject.GetValue<string>(
                        'sha256', '');
                      LVariant.SignatureUrl := LVariantObject.GetValue<string>(
                        'signature', '');
                      LVariant.ProvenanceUrl := LVariantObject.GetValue<string>(
                        'provenance', '');
                      if not LVariant.ArtifactUrl.IsEmpty and
                         not LVariant.ArtifactDigest.IsEmpty then
                        LPackageVersion.Variants.Add(LVariant)
                      else
                        LVariant.Free;
                    end;
                var LInsertAt := 0;
                while (LInsertAt < LEntry.Versions.Count) and
                  (TBoss4DSemVer.Create(
                    LEntry.Versions[LInsertAt].Version) > LSemVer) do
                  Inc(LInsertAt);
                LEntry.Versions.Insert(LInsertAt, LPackageVersion);
              end;
          for var LPackageVersion in LEntry.Versions do
            if not LPackageVersion.Revoked then
            begin
              LEntry.LatestVersion := LPackageVersion.Version;
              LEntry.ArtifactUrl := LPackageVersion.ArtifactUrl;
              LEntry.ArtifactDigest := LPackageVersion.ArtifactDigest;
              LEntry.SignatureUrl := LPackageVersion.SignatureUrl;
              LEntry.ProvenanceUrl := LPackageVersion.ProvenanceUrl;
              for var LVariant in LPackageVersion.Variants do
              begin
                var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
                LVariantCopy.Platform := LVariant.Platform;
                LVariantCopy.Compiler := LVariant.Compiler;
                LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
                LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
                LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
                LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
                LEntry.Variants.Add(LVariantCopy);
              end;
              Break;
            end;
        end;
        if (LEntry.Versions.Count = 0) and
           TBoss4DSemVer.Create(LEntry.LatestVersion).IsValid then
        begin
          var LLegacyVersion := TBoss4DPackageVersion.Create;
          LLegacyVersion.Version := LEntry.LatestVersion;
          LLegacyVersion.ArtifactUrl := LEntry.ArtifactUrl;
          LLegacyVersion.ArtifactDigest := LEntry.ArtifactDigest;
          LLegacyVersion.SignatureUrl := LEntry.SignatureUrl;
          LLegacyVersion.ProvenanceUrl := LEntry.ProvenanceUrl;
          LEntry.Versions.Add(LLegacyVersion);
        end;
        LEntry.Source := ASource;
        if not LEntry.Name.IsEmpty and not LEntry.Repository.IsEmpty then
          AEntries.Add(LEntry)
        else
          LEntry.Free;
      end;
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
    for var LEntry in LAll do
      if AQuery.IsEmpty or LEntry.Name.Contains(AQuery, True) or
         LEntry.Repository.Contains(AQuery, True) or
         LEntry.Description.Contains(AQuery, True) then
      begin
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
        for var LVariant in LEntry.Variants do
        begin
          var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
          LVariantCopy.Platform := LVariant.Platform;
          LVariantCopy.Compiler := LVariant.Compiler;
          LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
          LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
          LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
          LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
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
          for var LVariant in LVersion.Variants do
          begin
            var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
            LVariantCopy.Platform := LVariant.Platform;
            LVariantCopy.Compiler := LVariant.Compiler;
            LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
            LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
            LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
            LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
            LVersionCopy.Variants.Add(LVariantCopy);
          end;
          LCopy.Versions.Add(LVersionCopy);
        end;
        Result.Add(LCopy);
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
        for var LVariant in LEntry.Variants do
        begin
          var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
          LVariantCopy.Platform := LVariant.Platform;
          LVariantCopy.Compiler := LVariant.Compiler;
          LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
          LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
          LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
          LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
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
          for var LVariant in LVersion.Variants do
          begin
            var LVariantCopy := TBoss4DPackageArtifactVariant.Create;
            LVariantCopy.Platform := LVariant.Platform;
            LVariantCopy.Compiler := LVariant.Compiler;
            LVariantCopy.ArtifactUrl := LVariant.ArtifactUrl;
            LVariantCopy.ArtifactDigest := LVariant.ArtifactDigest;
            LVariantCopy.SignatureUrl := LVariant.SignatureUrl;
            LVariantCopy.ProvenanceUrl := LVariant.ProvenanceUrl;
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
