unit Boss4D.Posix.Tests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  TRegistryFetcherMock = class
  private
    FCalls: Integer;
    FContent: string;
    FFail: Boolean;
  public
    function Fetch(const ASource: string): string;
    property Calls: Integer read FCalls;
    property Content: string read FContent write FContent;
    property Fail: Boolean read FFail write FFail;
  end;

  TPosixCoreTests = class(TTestCase)
  published
    procedure TestPlatform;
    procedure TestVersion;
    procedure TestManifest;
    procedure TestDependencyTarget;
    procedure TestCloneArguments;
    procedure TestLegacyManifestCompatibility;
    procedure TestAddAndRemoveDependency;
    procedure TestListHonorsProduction;
    procedure TestInstallWritesV3Lock;
    procedure TestFrozenRejectsManifestDrift;
    procedure TestHighestVersionResolution;
    procedure TestMinimalVersionResolution;
    procedure TestTildeDoesNotCrossMinor;
    procedure TestOfflineRejectsMissingModule;
    procedure TestLockedRequiresLock;
    procedure TestRegistryV2IncludesLegacyV1;
    procedure TestRegistrySearchAndInfo;
    procedure TestRegistryCycleLoadsOnce;
    procedure TestRegistryConfigurationPersistsSources;
    procedure TestRegistryConfigurationPreservesExistingFields;
    procedure TestRegistryOfflineUsesCache;
    procedure TestRegistryOnlineFallsBackToCache;
  end;

implementation

uses
  fpjson, Boss4D.Posix.Core, Boss4D.Posix.Registry, Boss4D.Posix.Config;

procedure SaveFixture(const APath, AContent: string); forward;

function TRegistryFetcherMock.Fetch(const ASource: string): string;
begin
  Inc(FCalls);
  if FFail then raise Exception.Create('network unavailable');
  Result := FContent;
end;

function NewTempDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'boss4d-posix-' + IntToHex(Random(MaxInt), 8);
  ForceDirectories(Result);
end;

procedure TPosixCoreTests.TestRegistryOfflineUsesCache;
var
  LDir: string;
  LFetcher: TRegistryFetcherMock;
  LService: TBoss4DRegistryService;
  LEntries: TBoss4DRegistryEntries;
begin
  LDir := NewTempDirectory;
  LFetcher := TRegistryFetcherMock.Create;
  try
    LFetcher.Content := '{"schemaVersion":1,"packages":[{"name":"Cached",' +
      '"repository":"example.test/cached"}]}';
    LService := TBoss4DRegistryService.Create(LDir, @LFetcher.Fetch);
    try
      LEntries := LService.Load('https://registry.example/index.json');
      LEntries.Free;
      LFetcher.Fail := True;
      LEntries := LService.Load('https://registry.example/index.json', True);
      try
        AssertEquals('Cached', LEntries[0].Name);
        AssertEquals(1, LFetcher.Calls);
      finally
        LEntries.Free;
      end;
    finally
      LService.Free;
    end;
  finally
    LFetcher.Free;
  end;
end;

procedure TPosixCoreTests.TestRegistryOnlineFallsBackToCache;
var
  LDir: string;
  LFetcher: TRegistryFetcherMock;
  LService: TBoss4DRegistryService;
  LEntries: TBoss4DRegistryEntries;
begin
  LDir := NewTempDirectory;
  LFetcher := TRegistryFetcherMock.Create;
  try
    LFetcher.Content := '{"schemaVersion":1,"packages":[{"name":"Fallback",' +
      '"repository":"example.test/fallback"}]}';
    LService := TBoss4DRegistryService.Create(LDir, @LFetcher.Fetch);
    try
      LEntries := LService.Load('https://registry.example/index.json');
      LEntries.Free;
      LFetcher.Fail := True;
      LEntries := LService.Load('https://registry.example/index.json');
      try
        AssertEquals('Fallback', LEntries[0].Name);
        AssertEquals(2, LFetcher.Calls);
      finally
        LEntries.Free;
      end;
    finally
      LService.Free;
    end;
  finally
    LFetcher.Free;
  end;
end;

procedure TPosixCoreTests.TestRegistryConfigurationPersistsSources;
var
  LDir, LPath: string;
  LConfig: TBoss4DPosixConfig;
  LRegistries: TStringList;
begin
  LDir := NewTempDirectory;
  LPath := IncludeTrailingPathDelimiter(LDir) + 'boss.cfg.json';
  LConfig := TBoss4DPosixConfig.Create(LPath);
  try
    LConfig.AddRegistry('https://packages.example/index-v2.json');
    LConfig.AddRegistry('https://packages.example/index-v2.json');
    LRegistries := LConfig.Registries;
    try
      AssertEquals(1, LRegistries.Count);
    finally
      LRegistries.Free;
    end;
    LConfig.RemoveRegistry('https://packages.example/index-v2.json');
    LRegistries := LConfig.Registries;
    try
      AssertEquals(0, LRegistries.Count);
    finally
      LRegistries.Free;
    end;
  finally
    LConfig.Free;
  end;
end;

procedure TPosixCoreTests.TestRegistryConfigurationPreservesExistingFields;
var
  LDir, LPath: string;
  LConfig: TBoss4DPosixConfig;
  LRoot: TJSONObject;
begin
  LDir := NewTempDirectory;
  LPath := IncludeTrailingPathDelimiter(LDir) + 'boss.cfg.json';
  SaveFixture(LPath, '{"gitShallow":true,"custom":"keep","registries":[]}');
  LConfig := TBoss4DPosixConfig.Create(LPath);
  try
    LConfig.AddRegistry('local.json');
  finally
    LConfig.Free;
  end;
  LRoot := LoadJsonObject(LPath);
  try
    AssertTrue(LRoot.Get('gitShallow', False));
    AssertEquals('keep', LRoot.Get('custom', ''));
  finally
    LRoot.Free;
  end;
end;

procedure SaveFixture(const APath, AContent: string);
var
  LContent: TStringList;
begin
  LContent := TStringList.Create;
  try
    LContent.Text := AContent;
    LContent.SaveToFile(APath);
  finally
    LContent.Free;
  end;
end;

procedure TPosixCoreTests.TestRegistryV2IncludesLegacyV1;
var
  LDir, LRoot, LLegacy: string;
  LService: TBoss4DRegistryService;
  LEntries: TBoss4DRegistryEntries;
begin
  LDir := NewTempDirectory;
  LRoot := IncludeTrailingPathDelimiter(LDir) + 'index-v2.json';
  LLegacy := IncludeTrailingPathDelimiter(LDir) + 'legacy-v1.json';
  SaveFixture(LLegacy, '{"schemaVersion":1,"packages":[{"name":"Legacy",' +
    '"repository":"example.test/legacy","version":"1.0.0"}]}');
  SaveFixture(LRoot, '{"schemaVersion":2,"includes":["legacy-v1.json"],' +
    '"packages":[{"name":"Modern","repository":"example.test/modern",' +
    '"versions":[{"version":"2.0.0","artifact":"modern.b4dpkg",' +
    '"sha256":"abc"}]}]}');
  LService := TBoss4DRegistryService.Create;
  try
    LEntries := LService.Load(LRoot);
    try
      AssertEquals(2, LEntries.Count);
      AssertEquals('1.0.0', LEntries.Find('Legacy').Version);
      AssertEquals('2.0.0', LEntries.Find('Modern').Version);
      AssertEquals('modern.b4dpkg', LEntries.Find('Modern').ArtifactUrl);
    finally
      LEntries.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestRegistrySearchAndInfo;
var
  LDir, LRoot: string;
  LService: TBoss4DRegistryService;
  LEntries, LMatches: TBoss4DRegistryEntries;
begin
  LDir := NewTempDirectory;
  LRoot := IncludeTrailingPathDelimiter(LDir) + 'index.json';
  SaveFixture(LRoot, '{"schemaVersion":1,"packages":[' +
    '{"name":"Horse","repository":"github.com/hashload/horse",' +
    '"description":"Web framework"},{"name":"Dext",' +
    '"repository":"github.com/regyssilveira/dext"}]}');
  LService := TBoss4DRegistryService.Create;
  try
    LEntries := LService.Load(LRoot);
    try
      AssertEquals('Horse', LEntries.Find(
        'github.com/hashload/horse').Name);
      LMatches := LEntries.Search('framework');
      try
        AssertEquals(1, LMatches.Count);
        AssertEquals('Horse', LMatches[0].Name);
      finally
        LMatches.Free;
      end;
    finally
      LEntries.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestRegistryCycleLoadsOnce;
var
  LDir, LRoot, LChild: string;
  LService: TBoss4DRegistryService;
  LEntries: TBoss4DRegistryEntries;
begin
  LDir := NewTempDirectory;
  LRoot := IncludeTrailingPathDelimiter(LDir) + 'root.json';
  LChild := IncludeTrailingPathDelimiter(LDir) + 'child.json';
  SaveFixture(LRoot, '{"schemaVersion":2,"includes":["child.json"],' +
    '"packages":[{"name":"Root","repository":"example.test/root"}]}');
  SaveFixture(LChild, '{"schemaVersion":2,"includes":["root.json"],' +
    '"packages":[{"name":"Child","repository":"example.test/child"}]}');
  LService := TBoss4DRegistryService.Create;
  try
    LEntries := LService.Load(LRoot);
    try
      AssertEquals(2, LEntries.Count);
    finally
      LEntries.Free;
    end;
  finally
    LService.Free;
  end;
end;

function Versions(const AValues: array of string): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := Low(AValues) to High(AValues) do Result.Add(AValues[I]);
end;

procedure TPosixCoreTests.TestHighestVersionResolution;
var
  LVersions: TStringList;
begin
  LVersions := Versions(['v1.2.0', 'v2.0.0', 'v1.9.1']);
  try
    AssertEquals('v1.9.1', SelectVersion('^1.1.0', LVersions, 'highest'));
  finally
    LVersions.Free;
  end;
end;

procedure TPosixCoreTests.TestMinimalVersionResolution;
var
  LVersions: TStringList;
begin
  LVersions := Versions(['1.4.0', '1.2.1', '1.8.0']);
  try
    AssertEquals('1.2.1', SelectVersion('^1.2.0', LVersions, 'minimal'));
  finally
    LVersions.Free;
  end;
end;

procedure TPosixCoreTests.TestTildeDoesNotCrossMinor;
var
  LVersions: TStringList;
begin
  LVersions := Versions(['1.2.3', '1.2.9', '1.3.0']);
  try
    AssertEquals('1.2.9', SelectVersion('~1.2.0', LVersions, 'highest'));
  finally
    LVersions.Free;
  end;
end;

procedure TPosixCoreTests.TestOfflineRejectsMissingModule;
var
  LDir: string;
  LOptions: TBoss4DInstallOptions;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  AddDependency(LDir, 'offline.test/package', '*', False);
  FillChar(LOptions, SizeOf(LOptions), 0);
  LOptions.Offline := True;
  try
    InstallProject(LDir, LOptions);
    Fail('Offline install should reject a cache miss');
  except
    on E: Exception do AssertTrue(Pos('offline cache miss', E.Message) > 0);
  end;
end;

procedure TPosixCoreTests.TestLockedRequiresLock;
var
  LDir: string;
  LOptions: TBoss4DInstallOptions;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  FillChar(LOptions, SizeOf(LOptions), 0);
  LOptions.Locked := True;
  try
    InstallProject(LDir, LOptions);
    Fail('Locked install should require a lock');
  except
    on E: Exception do AssertTrue(Pos('requires boss-lock.json', E.Message) > 0);
  end;
end;

procedure TPosixCoreTests.TestPlatform;
begin
  AssertEquals('linux', PlatformName);
end;

procedure TPosixCoreTests.TestLegacyManifestCompatibility;
var
  LDir: string;
  LItems: TStringList;
  LFixture: TStringList;
begin
  LDir := NewTempDirectory;
  LFixture := TStringList.Create;
  try
    LFixture.Text := '{"name":"legacy","version":"1.0.0","dependencies":' +
      '{"github.com/hashload/horse":"^3.0.0"}}';
    LFixture.SaveToFile(IncludeTrailingPathDelimiter(LDir) + 'boss.json');
  finally
    LFixture.Free;
  end;
  LItems := ListProject(LDir, False);
  try
    AssertEquals(1, LItems.Count);
    AssertTrue(Pos('github.com/hashload/horse ^3.0.0', LItems[0]) = 1);
  finally
    LItems.Free;
  end;
end;

procedure TPosixCoreTests.TestAddAndRemoveDependency;
var
  LDir: string;
  LManifest, LDependencies: TJSONObject;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  AddDependency(LDir, 'github.com/test/pkg', 'v1.0.0', False);
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(LDir) + 'boss.json');
  try
    LDependencies := TJSONObject(LManifest.Find('dependencies'));
    AssertEquals('v1.0.0', LDependencies.Get('github.com/test/pkg', ''));
  finally
    LManifest.Free;
  end;
  RemoveDependency(LDir, 'github.com/test/pkg');
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(LDir) + 'boss.json');
  try
    LDependencies := TJSONObject(LManifest.Find('dependencies'));
    AssertFalse(Assigned(LDependencies.Find('github.com/test/pkg')));
  finally
    LManifest.Free;
  end;
end;

procedure TPosixCoreTests.TestListHonorsProduction;
var
  LDir: string;
  LItems, LFixture: TStringList;
begin
  LDir := NewTempDirectory;
  LFixture := TStringList.Create;
  try
    LFixture.Text :=
      '{"name":"app","version":"1.0.0","dependencies":{"runtime":"*"},' +
      '"devDependencies":{"test":"*"}}';
    LFixture.SaveToFile(IncludeTrailingPathDelimiter(LDir) + 'boss.json');
  finally
    LFixture.Free;
  end;
  LItems := ListProject(LDir, True);
  try
    AssertEquals(1, LItems.Count);
    AssertTrue(Pos('runtime', LItems[0]) = 1);
  finally
    LItems.Free;
  end;
end;

procedure TPosixCoreTests.TestInstallWritesV3Lock;
var
  LDir: string;
  LLock: TJSONObject;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  InstallProject(LDir);
  AssertTrue(FileExists(IncludeTrailingPathDelimiter(LDir) + 'boss-lock.json'));
  LLock := LoadJsonObject(IncludeTrailingPathDelimiter(LDir) + 'boss-lock.json');
  try
    AssertEquals(3, LLock.Get('lockVersion', 0));
    AssertTrue(Assigned(LLock.Find('root')));
    AssertTrue(Assigned(LLock.Find('installedModules')));
  finally
    LLock.Free;
  end;
end;

procedure TPosixCoreTests.TestFrozenRejectsManifestDrift;
var
  LDir: string;
  LOptions: TBoss4DInstallOptions;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  InstallProject(LDir);
  AddDependency(LDir, 'offline.test/package', '*', False);
  FillChar(LOptions, SizeOf(LOptions), 0);
  LOptions.FrozenLockfile := True;
  try
    InstallProject(LDir, LOptions);
    Fail('Frozen install should reject manifest drift');
  except
    on E: Exception do
      AssertTrue(Pos('out of sync', E.Message) > 0);
  end;
end;

procedure TPosixCoreTests.TestVersion;
begin
  AssertEquals('1.5.0', Boss4DVersion);
end;

procedure TPosixCoreTests.TestManifest;
begin
  AssertTrue(Pos('"dependencies":{}', DefaultManifest) > 0);
end;

procedure TPosixCoreTests.TestDependencyTarget;
begin
  AssertEquals('horse', DependencyTarget(
    'https://github.com/HashLoad/horse.git/'));
end;

procedure TPosixCoreTests.TestCloneArguments;
var
  LArguments: TStringList;
begin
  LArguments := BuildCloneArguments('https://example.test/repo.git',
    'v1.0.0', '/tmp/repo');
  try
    AssertEquals('--branch', LArguments[3]);
    AssertEquals('v1.0.0', LArguments[4]);
    AssertEquals('/tmp/repo', LArguments[6]);
  finally
    LArguments.Free;
  end;
end;

initialization
  RegisterTest(TPosixCoreTests);

end.
