unit Boss4D.Core.Services.ArtifactCache;

interface

uses
  Boss4D.Core.Domain.Dependency;

type
  IBoss4DArtifactCacheBackend = interface
    ['{3D4A6042-F3E3-4EDF-BACA-9F7BD47C31C7}']
    function Fetch(const AKey, ADestination: string): Boolean;
    procedure Push(const AKey, ASource: string);
  end;

  TBoss4DFileArtifactCacheBackend = class(TInterfacedObject,
    IBoss4DArtifactCacheBackend)
  private
    FRoot: string;
  public
    constructor Create(const ARoot: string);
    function Fetch(const AKey, ADestination: string): Boolean;
    procedure Push(const AKey, ASource: string);
  end;

  TBoss4DArtifactCacheService = class
  private
    FLocalRoot: string;
    FRemote: IBoss4DArtifactCacheBackend;
    function CacheDirectory(const ADependencyKey, AChecksum, ACompilerVersion,
      APlatform, AConfiguration: string): string;
    procedure WriteManifest(const ACacheDirectory: string);
    function Verify(const ACacheDirectory: string): Boolean;
    function EnsureLocal(const AKey, ACacheDirectory: string): Boolean;
  public
    constructor Create(const ALocalRoot: string = '';
      const ARemote: IBoss4DArtifactCacheBackend = nil);
    class function BuildCacheKey(const ADependencyKey, AChecksum,
      ACompilerVersion, APlatform, AConfiguration: string): string; static;
    function Restore(const ADep: TBoss4DDependency; const AChecksum,
      APlatform, ACompilerVersion: string;
      const AConfiguration: string = '';
      const ATargetRoot: string = ''): Boolean;
    procedure Store(const ADep: TBoss4DDependency; const AChecksum,
      APlatform, ACompilerVersion: string;
      const AConfiguration: string = '';
      const ATargetRoot: string = '');
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Hash,
  System.JSON,
  System.Generics.Collections,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Consts;

const
  CACHE_MANIFEST = '.manifest.json';
  CACHE_COMPLETE = '.complete';

procedure CopyDirectory(const ASource, ADestination: string);
begin
  if not TDirectory.Exists(ASource) then
    Exit;
  TDirectory.CreateDirectory(ADestination);
  for var LDirectory in TDirectory.GetDirectories(ASource, '*',
    TSearchOption.soAllDirectories) do
  begin
    if LDirectory.Contains(TPath.DirectorySeparatorChar +
      '.boss4d-state') then
      Continue;
    TDirectory.CreateDirectory(TPath.Combine(ADestination,
      LDirectory.Substring(Length(IncludeTrailingPathDelimiter(ASource)))));
  end;
  for var LFile in TDirectory.GetFiles(ASource, '*',
    TSearchOption.soAllDirectories) do
  begin
    if LFile.Contains(TPath.DirectorySeparatorChar +
      '.boss4d-state' + TPath.DirectorySeparatorChar) then
      Continue;
    var LRelative := LFile.Substring(
      Length(IncludeTrailingPathDelimiter(ASource)));
    var LTarget := TPath.Combine(ADestination, LRelative);
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LTarget));
    TFile.Copy(LFile, LTarget, True);
  end;
end;

constructor TBoss4DFileArtifactCacheBackend.Create(const ARoot: string);
begin
  inherited Create;
  if ARoot.Trim.IsEmpty then
    raise EArgumentException.Create('A raiz do cache remoto e obrigatoria.');
  FRoot := TPath.GetFullPath(ARoot);
end;

function TBoss4DFileArtifactCacheBackend.Fetch(const AKey,
  ADestination: string): Boolean;
begin
  var LSource := TPath.Combine(FRoot, AKey);
  Result := TDirectory.Exists(LSource);
  if Result then
    CopyDirectory(LSource, ADestination);
end;

procedure TBoss4DFileArtifactCacheBackend.Push(const AKey,
  ASource: string);
begin
  TDirectory.CreateDirectory(FRoot);
  var LDestination := TPath.Combine(FRoot, AKey);
  var LStaging := LDestination + '.tmp-' + TGUID.NewGuid.ToString;
  try
    CopyDirectory(ASource, LStaging);
    if TDirectory.Exists(LDestination) then
      TDirectory.Delete(LDestination, True);
    TDirectory.Move(LStaging, LDestination);
  finally
    if TDirectory.Exists(LStaging) then
      TDirectory.Delete(LStaging, True);
  end;
end;

constructor TBoss4DArtifactCacheService.Create(const ALocalRoot: string;
  const ARemote: IBoss4DArtifactCacheBackend);
begin
  inherited Create;
  if ALocalRoot.Trim.IsEmpty then
    FLocalRoot := TPath.Combine(GetBossHome, 'artifact-cache')
  else
    FLocalRoot := TPath.GetFullPath(ALocalRoot);
  FRemote := ARemote;
end;

class function TBoss4DArtifactCacheService.BuildCacheKey(
  const ADependencyKey, AChecksum, ACompilerVersion, APlatform,
  AConfiguration: string): string;
begin
  Result := THashSHA2.GetHashString(ADependencyKey.ToLower + '|' +
    AChecksum.ToLower + '|' + ACompilerVersion.ToLower + '|' +
    APlatform.ToLower + '|' + AConfiguration.ToLower).ToLower;
end;

function TBoss4DArtifactCacheService.CacheDirectory(const ADependencyKey,
  AChecksum, ACompilerVersion, APlatform, AConfiguration: string): string;
begin
  Result := TPath.Combine(FLocalRoot, BuildCacheKey(ADependencyKey,
    AChecksum, ACompilerVersion, APlatform, AConfiguration));
end;

procedure TBoss4DArtifactCacheService.WriteManifest(
  const ACacheDirectory: string);
begin
  var LFiles := TDirectory.GetFiles(ACacheDirectory, '*',
    TSearchOption.soAllDirectories);
  TArray.Sort<string>(LFiles);
  var LManifest := TJSONObject.Create;
  try
    LManifest.AddPair('algorithm', 'SHA-256');
    var LEntries := TJSONArray.Create;
    for var LFile in LFiles do
    begin
      var LRelative := LFile.Substring(
        Length(IncludeTrailingPathDelimiter(ACacheDirectory)));
      if SameText(LRelative, CACHE_MANIFEST) or
         SameText(LRelative, CACHE_COMPLETE) then
        Continue;
      var LEntry := TJSONObject.Create;
      LEntry.AddPair('path', LRelative.Replace('\', '/'));
      LEntry.AddPair('sha256',
        THashSHA2.GetHashStringFromFile(LFile).ToLower);
      LEntries.AddElement(LEntry);
    end;
    LManifest.AddPair('files', LEntries);
    var LEncoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(TPath.Combine(ACacheDirectory, CACHE_MANIFEST),
        LManifest.Format(2), LEncoding);
    finally
      LEncoding.Free;
    end;
  finally
    LManifest.Free;
  end;
end;

function TBoss4DArtifactCacheService.Verify(
  const ACacheDirectory: string): Boolean;
begin
  Result := False;
  var LManifestPath := TPath.Combine(ACacheDirectory, CACHE_MANIFEST);
  if not TFile.Exists(TPath.Combine(ACacheDirectory, CACHE_COMPLETE)) or
     not TFile.Exists(LManifestPath) then
    Exit;
  var LRoot := TJSONObject.ParseJSONValue(TFile.ReadAllText(LManifestPath,
    TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  var LExpected := TDictionary<string, Boolean>.Create;
  try
    var LEntries := LRoot.GetValue<TJSONArray>('files');
    if not Assigned(LEntries) then
      Exit;
    var LAllowedRoot := IncludeTrailingPathDelimiter(
      TPath.GetFullPath(ACacheDirectory));
    for var I := 0 to LEntries.Count - 1 do
    begin
      if not (LEntries[I] is TJSONObject) then
        Exit;
      var LEntry := TJSONObject(LEntries[I]);
      var LRelative := LEntry.GetValue<string>('path', '').Replace('/',
        TPath.DirectorySeparatorChar);
      var LFile := TPath.GetFullPath(TPath.Combine(ACacheDirectory,
        LRelative));
      if LRelative.IsEmpty or not LFile.StartsWith(LAllowedRoot, True) or
         not TFile.Exists(LFile) then
        Exit;
      if not SameText(THashSHA2.GetHashStringFromFile(LFile),
        LEntry.GetValue<string>('sha256', '')) then
        Exit;
      LExpected.AddOrSetValue(LFile.ToLower, True);
    end;
    for var LFile in TDirectory.GetFiles(ACacheDirectory, '*',
      TSearchOption.soAllDirectories) do
      if not SameText(TPath.GetFileName(LFile), CACHE_MANIFEST) and
         not SameText(TPath.GetFileName(LFile), CACHE_COMPLETE) and
         not LExpected.ContainsKey(TPath.GetFullPath(LFile).ToLower) then
        Exit;
    Result := True;
  finally
    LExpected.Free;
    LRoot.Free;
  end;
end;

function TBoss4DArtifactCacheService.EnsureLocal(const AKey,
  ACacheDirectory: string): Boolean;
begin
  if Verify(ACacheDirectory) then
    Exit(True);
  if TDirectory.Exists(ACacheDirectory) then
    TDirectory.Delete(ACacheDirectory, True);
  if not Assigned(FRemote) then
    Exit(False);
  var LStaging := ACacheDirectory + '.fetch-' + TGUID.NewGuid.ToString;
  try
    if not FRemote.Fetch(AKey, LStaging) or not Verify(LStaging) then
      Exit(False);
    TDirectory.CreateDirectory(TPath.GetDirectoryName(ACacheDirectory));
    TDirectory.Move(LStaging, ACacheDirectory);
    Result := True;
  finally
    if TDirectory.Exists(LStaging) then
      TDirectory.Delete(LStaging, True);
  end;
end;

function TBoss4DArtifactCacheService.Restore(const ADep: TBoss4DDependency;
  const AChecksum, APlatform, ACompilerVersion,
  AConfiguration, ATargetRoot: string): Boolean;
begin
  if AChecksum.IsEmpty then
    Exit(False);
  var LKey := BuildCacheKey(ADep.GetKey, AChecksum, ACompilerVersion,
    APlatform, AConfiguration);
  var LCache := CacheDirectory(ADep.GetKey, AChecksum, ACompilerVersion,
    APlatform, AConfiguration);
  Result := EnsureLocal(LKey, LCache);
  if not Result then
    Exit;
  if not ATargetRoot.IsEmpty then
    CopyDirectory(TPath.Combine(LCache, 'target'), ATargetRoot)
  else
    CopyDirectory(TPath.Combine(LCache, 'module-bin'),
      TPath.Combine(GetModulesDir, TPath.Combine(ADep.Name, FOLDER_BIN)));
end;

procedure TBoss4DArtifactCacheService.Store(const ADep: TBoss4DDependency;
  const AChecksum, APlatform, ACompilerVersion, AConfiguration,
  ATargetRoot: string);
begin
  if AChecksum.IsEmpty then
    Exit;
  var LSource: string;
  if not ATargetRoot.IsEmpty then
    LSource := ATargetRoot
  else
    LSource := TPath.Combine(GetModulesDir,
      TPath.Combine(ADep.Name, FOLDER_BIN));
  if not TDirectory.Exists(LSource) or
     (Length(TDirectory.GetFiles(LSource, '*',
       TSearchOption.soAllDirectories)) = 0) then
    Exit;
  var LKey := BuildCacheKey(ADep.GetKey, AChecksum, ACompilerVersion,
    APlatform, AConfiguration);
  var LCache := CacheDirectory(ADep.GetKey, AChecksum, ACompilerVersion,
    APlatform, AConfiguration);
  var LStaging := LCache + '.store-' + TGUID.NewGuid.ToString;
  try
    if not ATargetRoot.IsEmpty then
      CopyDirectory(LSource, TPath.Combine(LStaging, 'target'))
    else
      CopyDirectory(LSource, TPath.Combine(LStaging, 'module-bin'));
    WriteManifest(LStaging);
    TFile.WriteAllText(TPath.Combine(LStaging, CACHE_COMPLETE), ADep.GetKey);
    TDirectory.CreateDirectory(FLocalRoot);
    if TDirectory.Exists(LCache) then
      TDirectory.Delete(LCache, True);
    TDirectory.Move(LStaging, LCache);
    if Assigned(FRemote) then
      FRemote.Push(LKey, LCache);
  finally
    if TDirectory.Exists(LStaging) then
      TDirectory.Delete(LStaging, True);
  end;
end;

end.
