unit Boss4D.Core.Services.ArtifactCache;

interface

uses
  Boss4D.Core.Domain.Dependency;

type
  TBoss4DArtifactCacheService = class
  private
    function CacheDirectory(const ADependencyKey, AChecksum, ACompilerVersion,
      APlatform, AConfiguration: string): string;
    procedure CopyDirectory(const ASource, ADestination: string);
  public
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
  System.SysUtils, System.IOUtils, System.Hash,
  Boss4D.Core.Domain.Env, Boss4D.Core.Domain.Consts;

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
  Result := TPath.Combine(TPath.Combine(GetBossHome, 'artifact-cache'),
    BuildCacheKey(ADependencyKey, AChecksum, ACompilerVersion, APlatform,
      AConfiguration));
end;

procedure TBoss4DArtifactCacheService.CopyDirectory(const ASource,
  ADestination: string);
begin
  if not TDirectory.Exists(ASource) then Exit;
  TDirectory.CreateDirectory(ADestination);
  for var LDirectory in TDirectory.GetDirectories(ASource, '*',
    TSearchOption.soAllDirectories) do
    TDirectory.CreateDirectory(TPath.Combine(ADestination,
      LDirectory.Substring(Length(IncludeTrailingPathDelimiter(ASource)))));
  for var LFile in TDirectory.GetFiles(ASource, '*',
    TSearchOption.soAllDirectories) do
  begin
    var LRelative := LFile.Substring(
      Length(IncludeTrailingPathDelimiter(ASource)));
    var LTarget := TPath.Combine(ADestination, LRelative);
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LTarget));
    TFile.Copy(LFile, LTarget, True);
  end;
end;

function TBoss4DArtifactCacheService.Restore(const ADep: TBoss4DDependency;
  const AChecksum, APlatform, ACompilerVersion,
  AConfiguration, ATargetRoot: string): Boolean;
var
  LCache: string;
begin
  if AChecksum.IsEmpty then Exit(False);
  LCache := CacheDirectory(ADep.GetKey, AChecksum, ACompilerVersion,
    APlatform, AConfiguration);
  Result := TFile.Exists(TPath.Combine(LCache, '.complete'));
  if not Result then Exit;
  if not ATargetRoot.IsEmpty then
    CopyDirectory(TPath.Combine(LCache, 'target'), ATargetRoot)
  else
    CopyDirectory(TPath.Combine(LCache, 'module-bin'),
      TPath.Combine(GetModulesDir, TPath.Combine(ADep.Name, FOLDER_BIN)));
end;

procedure TBoss4DArtifactCacheService.Store(const ADep: TBoss4DDependency;
  const AChecksum, APlatform, ACompilerVersion, AConfiguration,
  ATargetRoot: string);
var
  LCache: string;
  LSource: string;
begin
  if AChecksum.IsEmpty then Exit;
  if not ATargetRoot.IsEmpty then
    LSource := ATargetRoot
  else
    LSource := TPath.Combine(GetModulesDir,
      TPath.Combine(ADep.Name, FOLDER_BIN));
  if not TDirectory.Exists(LSource) or
     (Length(TDirectory.GetFiles(LSource, '*',
       TSearchOption.soAllDirectories)) = 0) then Exit;
  LCache := CacheDirectory(ADep.GetKey, AChecksum, ACompilerVersion,
    APlatform, AConfiguration);
  if TDirectory.Exists(LCache) then
    TDirectory.Delete(LCache, True);
  TDirectory.CreateDirectory(LCache);
  if not ATargetRoot.IsEmpty then
    CopyDirectory(LSource, TPath.Combine(LCache, 'target'))
  else
    CopyDirectory(LSource, TPath.Combine(LCache, 'module-bin'));
  TFile.WriteAllText(TPath.Combine(LCache, '.complete'), ADep.GetKey);
end;

end.
