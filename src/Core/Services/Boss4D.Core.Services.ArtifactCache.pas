unit Boss4D.Core.Services.ArtifactCache;

interface

uses
  Boss4D.Core.Domain.Dependency;

type
  TBoss4DArtifactCacheService = class
  private
    function CacheDirectory(const AChecksum, APlatform,
      ACompilerVersion: string): string;
    procedure CopyDirectory(const ASource, ADestination: string);
  public
    function Restore(const ADep: TBoss4DDependency; const AChecksum,
      APlatform, ACompilerVersion: string): Boolean;
    procedure Store(const ADep: TBoss4DDependency; const AChecksum,
      APlatform, ACompilerVersion: string);
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Hash,
  Boss4D.Core.Domain.Env, Boss4D.Core.Domain.Consts;

function TBoss4DArtifactCacheService.CacheDirectory(const AChecksum,
  APlatform, ACompilerVersion: string): string;
begin
  Result := TPath.Combine(TPath.Combine(GetBossHome, 'artifact-cache'),
    THashSHA2.GetHashString(AChecksum + '|' + APlatform.ToLower + '|' +
      ACompilerVersion.ToLower).ToLower);
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
  const AChecksum, APlatform, ACompilerVersion: string): Boolean;
var
  LCache: string;
begin
  if AChecksum.IsEmpty then Exit(False);
  LCache := CacheDirectory(AChecksum, APlatform, ACompilerVersion);
  Result := TFile.Exists(TPath.Combine(LCache, '.complete'));
  if not Result then Exit;
  CopyDirectory(TPath.Combine(LCache, 'module-bin'),
    TPath.Combine(GetModulesDir, TPath.Combine(ADep.Name, FOLDER_BIN)));
end;

procedure TBoss4DArtifactCacheService.Store(const ADep: TBoss4DDependency;
  const AChecksum, APlatform, ACompilerVersion: string);
var
  LCache: string;
begin
  if AChecksum.IsEmpty then Exit;
  var LBinSource := TPath.Combine(GetModulesDir,
    TPath.Combine(ADep.Name, FOLDER_BIN));
  if not TDirectory.Exists(LBinSource) or
     (Length(TDirectory.GetFiles(LBinSource, '*',
       TSearchOption.soAllDirectories)) = 0) then Exit;
  LCache := CacheDirectory(AChecksum, APlatform, ACompilerVersion);
  if TDirectory.Exists(LCache) then
    TDirectory.Delete(LCache, True);
  TDirectory.CreateDirectory(LCache);
  CopyDirectory(LBinSource,
    TPath.Combine(LCache, 'module-bin'));
  TFile.WriteAllText(TPath.Combine(LCache, '.complete'), ADep.GetKey);
end;

end.
