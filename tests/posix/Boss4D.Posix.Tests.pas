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

  TSignatureVerifierMock = class
  private
    FAccept: Boolean;
    FCalls: Integer;
  public
    function Verify(const AArtifactPath, ASignaturePath: string): Boolean;
    property Accept: Boolean read FAccept write FAccept;
    property Calls: Integer read FCalls;
  end;

  TAuditFetcherMock = class
  private
    FCalls: Integer;
    FResponse: string;
    FNextResponse: string;
    FFail: Boolean;
  public
    function Fetch(const ARevision, APageToken: string): string;
    property Calls: Integer read FCalls;
    property Response: string read FResponse write FResponse;
    property NextResponse: string read FNextResponse write FNextResponse;
    property Fail: Boolean read FFail write FFail;
  end;

  TSecretToolRunnerMock = class
  private
    FInput: string;
    FCommand: string;
    FOutput: string;
    FSuccess: Boolean;
  public
    function Run(const AArguments: TStrings; const AInput: string;
      out AOutput: string): Boolean;
    property Input: string read FInput;
    property Command: string read FCommand;
    property Output: string read FOutput write FOutput;
    property Success: Boolean read FSuccess write FSuccess;
  end;

  TUpdateMock = class
  private
    FDirectory: string;
    FRelease: string;
    FDownloads: Integer;
  public
    function Fetch: string;
    function Download(const AUrl, ATarget: string): Boolean;
    function Extract(const AArchive, ATargetDirectory: string): Boolean;
    property Directory: string read FDirectory write FDirectory;
    property Release: string read FRelease write FRelease;
    property Downloads: Integer read FDownloads;
  end;

  TToolCompilerMock = class
  private
    FCalls: Integer;
  public
    function Compile(const ASourceDirectory, AOutputPath: string): Boolean;
    property Calls: Integer read FCalls;
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
    procedure TestRegistrySelectsArtifactVariant;
    procedure TestVerifiedPackageInstall;
    procedure TestPackageRejectsArtifactDigestMismatch;
    procedure TestPackageRejectsFileDigestMismatch;
    procedure TestPackageRejectsUnsafePath;
    procedure TestPackageRejectsInvalidSignature;
    procedure TestPackageRejectsInvalidProvenance;
    procedure TestArtifactInstallRecordsLegacyManifestAndLock;
    procedure TestStructuredProgressFormats;
    procedure TestProgressModePrecedence;
    procedure TestExitCodeClassification;
    procedure TestCancellation;
    procedure TestInstallHonorsCancellation;
    procedure TestLinuxDoctor;
    procedure TestCycloneDxLockOnlySbom;
    procedure TestSpdxLockOnlySbom;
    procedure TestCycloneDxVex;
    procedure TestSbomReproducibleAndRejectsSpdxVex;
    procedure TestAuditPolicyAndVex;
    procedure TestAuditOfflineCache;
    procedure TestAuditOfflineCacheMiss;
    procedure TestDirectoryDigestIsDeterministicAndExcludesGit;
    procedure TestStrictSbomEvidenceAndValidation;
    procedure TestGitLockEvidence;
    procedure TestSecretServiceCredentialStore;
    procedure TestSecretMasking;
    procedure TestCacheManagement;
    procedure TestWorkspaceLinks;
    procedure TestSecureSelfUpdate;
    procedure TestSelfUpdateSkipsCurrentVersion;
    procedure TestGlobalToolLifecycle;
  end;

implementation

uses
  fpjson, DateUtils, Boss4D.Posix.Core, Boss4D.Posix.Registry,
  Boss4D.Posix.Config,
  Boss4D.Posix.Package,
  Boss4D.Posix.Operations, Boss4D.Posix.Compliance, Boss4D.Posix.Audit,
  Boss4D.Posix.Workflows, Boss4D.Posix.Update, Boss4D.Posix.Tools;

procedure SaveFixture(const APath, AContent: string); forward;

function TRegistryFetcherMock.Fetch(const ASource: string): string;
begin
  Inc(FCalls);
  if FFail then raise Exception.Create('network unavailable');
  Result := FContent;
end;

function TSignatureVerifierMock.Verify(const AArtifactPath,
  ASignaturePath: string): Boolean;
begin
  Inc(FCalls);
  Result := FAccept and FileExists(AArtifactPath) and
    FileExists(ASignaturePath);
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

procedure TPosixCoreTests.TestRegistrySelectsArtifactVariant;
var
  LDir, LRoot: string;
  LService: TBoss4DRegistryService;
  LEntries: TBoss4DRegistryEntries;
  LEntry: TBoss4DRegistryEntry;
  LVariant: TBoss4DArtifactVariant;
begin
  LDir := NewTempDirectory;
  LRoot := IncludeTrailingPathDelimiter(LDir) + 'index.json';
  SaveFixture(LRoot, '{"schemaVersion":2,"packages":[{"name":"Demo",' +
    '"repository":"example.test/demo","versions":[{"version":"2.0.0",' +
    '"variants":[{"platform":"linux","compiler":"3.2.2",' +
    '"artifact":"exact.b4dpkg","sha256":"exact"},' +
    '{"platform":"linux","artifact":"platform.b4dpkg",' +
    '"sha256":"platform"},{"artifact":"generic.b4dpkg",' +
    '"sha256":"generic"}]}]}]}');
  LService := TBoss4DRegistryService.Create;
  try
    LEntries := LService.Load(LRoot);
    try
      LEntry := LEntries.Find('Demo');
      AssertEquals(3, LEntry.Variants.Count);
      LVariant := LEntry.SelectVariant('linux', '3.2.2');
      AssertEquals('exact.b4dpkg', LVariant.ArtifactUrl);
      LVariant := LEntry.SelectVariant('linux', '3.0.0');
      AssertEquals('platform.b4dpkg', LVariant.ArtifactUrl);
      LVariant := LEntry.SelectVariant('macos', '3.0.0');
      AssertEquals('generic.b4dpkg', LVariant.ArtifactUrl);
    finally
      LEntries.Free;
    end;
  finally
    LService.Free;
  end;
end;

function CreatePackageFixture(const ADirectory, APath,
  AFileDigest: string): string;
var
  LContentPath: string;
begin
  LContentPath := IncludeTrailingPathDelimiter(ADirectory) + 'content.tmp';
  SaveFixture(LContentPath, 'unit verified;');
  Result := IncludeTrailingPathDelimiter(ADirectory) + 'fixture.b4dpkg';
  SaveFixture(Result, '{"format":"boss4d-package","schemaVersion":1,' +
    '"files":[{"path":"' + APath + '","content":"dW5pdCB2ZXJpZmllZDsK",' +
    '"sha256":"' + AFileDigest + '"}]}');
end;

procedure InitPackageRequest(var ARequest: TBoss4DPackageRequest;
  const AArtifact, ATarget: string);
begin
  ARequest.ArtifactUrl := AArtifact;
  ARequest.Sha256 := Sha256File(AArtifact);
  ARequest.SignatureUrl := '';
  ARequest.ProvenanceUrl := '';
  ARequest.TargetDirectory := ATarget;
end;

procedure TPosixCoreTests.TestVerifiedPackageInstall;
var
  LDir, LContent, LArtifact, LTarget, LSignature, LProvenance: string;
  LRequest: TBoss4DPackageRequest;
  LResult: TBoss4DPackageResult;
  LVerifier: TSignatureVerifierMock;
  LService: TBoss4DPackageService;
begin
  LDir := NewTempDirectory;
  LContent := IncludeTrailingPathDelimiter(LDir) + 'content.tmp';
  SaveFixture(LContent, 'unit verified;');
  LArtifact := CreatePackageFixture(LDir, 'src/verified.pas',
    Sha256File(LContent));
  LTarget := IncludeTrailingPathDelimiter(LDir) + 'modules/verified';
  LSignature := LArtifact + '.asc';
  LProvenance := LArtifact + '.intoto.json';
  SaveFixture(LSignature, 'test signature');
  InitPackageRequest(LRequest, LArtifact, LTarget);
  SaveFixture(LProvenance, '{"_type":"https://in-toto.io/Statement/v1",' +
    '"subject":[{"name":"fixture.b4dpkg","digest":{"sha256":"' +
    LRequest.Sha256 + '"}}]}');
  LRequest.SignatureUrl := LSignature;
  LRequest.ProvenanceUrl := LProvenance;
  LVerifier := TSignatureVerifierMock.Create;
  try
    LVerifier.Accept := True;
    LService := TBoss4DPackageService.Create(@LVerifier.Verify);
    try
      LResult := LService.Install(LRequest);
      AssertTrue(LResult.Installed);
      AssertEquals(1, LResult.FileCount);
      AssertEquals(1, LVerifier.Calls);
      AssertTrue(FileExists(IncludeTrailingPathDelimiter(LTarget) +
        'src/verified.pas'));
    finally
      LService.Free;
    end;
  finally
    LVerifier.Free;
  end;
end;

procedure TPosixCoreTests.TestPackageRejectsArtifactDigestMismatch;
var
  LDir, LContent, LArtifact, LTarget, LExisting: string;
  LRequest: TBoss4DPackageRequest;
  LService: TBoss4DPackageService;
begin
  LDir := NewTempDirectory;
  LContent := IncludeTrailingPathDelimiter(LDir) + 'content.tmp';
  SaveFixture(LContent, 'unit verified;');
  LArtifact := CreatePackageFixture(LDir, 'verified.pas',
    Sha256File(LContent));
  LTarget := IncludeTrailingPathDelimiter(LDir) + 'modules/verified';
  ForceDirectories(LTarget);
  LExisting := IncludeTrailingPathDelimiter(LTarget) + 'existing.txt';
  SaveFixture(LExisting, 'preserve');
  InitPackageRequest(LRequest, LArtifact, LTarget);
  LRequest.Sha256 := StringOfChar('0', 64);
  LService := TBoss4DPackageService.Create;
  try
    try
      LService.Install(LRequest);
      Fail('Artifact digest mismatch should fail');
    except
      on E: Exception do AssertTrue(Pos('SHA-256 mismatch', E.Message) > 0);
    end;
    AssertTrue(FileExists(LExisting));
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestPackageRejectsFileDigestMismatch;
var
  LDir, LArtifact: string;
  LRequest: TBoss4DPackageRequest;
  LService: TBoss4DPackageService;
begin
  LDir := NewTempDirectory;
  LArtifact := CreatePackageFixture(LDir, 'verified.pas',
    StringOfChar('0', 64));
  InitPackageRequest(LRequest, LArtifact,
    IncludeTrailingPathDelimiter(LDir) + 'modules/verified');
  LService := TBoss4DPackageService.Create;
  try
    try
      LService.Install(LRequest);
      Fail('File digest mismatch should fail');
    except
      on E: Exception do AssertTrue(Pos('file digest mismatch', E.Message) > 0);
    end;
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestPackageRejectsUnsafePath;
var
  LDir, LContent, LArtifact: string;
  LRequest: TBoss4DPackageRequest;
  LService: TBoss4DPackageService;
begin
  LDir := NewTempDirectory;
  LContent := IncludeTrailingPathDelimiter(LDir) + 'content.tmp';
  SaveFixture(LContent, 'unit verified;');
  LArtifact := CreatePackageFixture(LDir, '../escaped.pas',
    Sha256File(LContent));
  InitPackageRequest(LRequest, LArtifact,
    IncludeTrailingPathDelimiter(LDir) + 'modules/verified');
  LService := TBoss4DPackageService.Create;
  try
    try
      LService.Install(LRequest);
      Fail('Unsafe path should fail');
    except
      on E: Exception do AssertTrue(Pos('unsafe package path', E.Message) > 0);
    end;
    AssertFalse(FileExists(IncludeTrailingPathDelimiter(LDir) + 'escaped.pas'));
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestPackageRejectsInvalidSignature;
var
  LDir, LContent, LArtifact: string;
  LRequest: TBoss4DPackageRequest;
  LVerifier: TSignatureVerifierMock;
  LService: TBoss4DPackageService;
begin
  LDir := NewTempDirectory;
  LContent := IncludeTrailingPathDelimiter(LDir) + 'content.tmp';
  SaveFixture(LContent, 'unit verified;');
  LArtifact := CreatePackageFixture(LDir, 'verified.pas',
    Sha256File(LContent));
  InitPackageRequest(LRequest, LArtifact,
    IncludeTrailingPathDelimiter(LDir) + 'modules/verified');
  LRequest.SignatureUrl := LArtifact + '.asc';
  SaveFixture(LRequest.SignatureUrl, 'invalid');
  LVerifier := TSignatureVerifierMock.Create;
  try
    LVerifier.Accept := False;
    LService := TBoss4DPackageService.Create(@LVerifier.Verify);
    try
      try
        LService.Install(LRequest);
        Fail('Invalid signature should fail');
      except
        on E: Exception do
          AssertTrue(Pos('signature verification failed', E.Message) > 0);
      end;
    finally
      LService.Free;
    end;
  finally
    LVerifier.Free;
  end;
end;

procedure TPosixCoreTests.TestPackageRejectsInvalidProvenance;
var
  LDir, LContent, LArtifact: string;
  LRequest: TBoss4DPackageRequest;
  LService: TBoss4DPackageService;
begin
  LDir := NewTempDirectory;
  LContent := IncludeTrailingPathDelimiter(LDir) + 'content.tmp';
  SaveFixture(LContent, 'unit verified;');
  LArtifact := CreatePackageFixture(LDir, 'verified.pas',
    Sha256File(LContent));
  InitPackageRequest(LRequest, LArtifact,
    IncludeTrailingPathDelimiter(LDir) + 'modules/verified');
  LRequest.ProvenanceUrl := LArtifact + '.intoto.json';
  SaveFixture(LRequest.ProvenanceUrl,
    '{"_type":"https://in-toto.io/Statement/v1","subject":[]}');
  LService := TBoss4DPackageService.Create;
  try
    try
      LService.Install(LRequest);
      Fail('Invalid provenance should fail');
    except
      on E: Exception do
        AssertTrue(Pos('provenance verification failed', E.Message) > 0);
    end;
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestArtifactInstallRecordsLegacyManifestAndLock;
var
  LDir: string;
  LManifest, LDependencies, LLock, LInstalled, LEntry: TJSONObject;
  LExpectedHash: string;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  RecordArtifactDependency(LDir, 'example.test/verified', 'v2.0.0',
    StringOfChar('a', 64), 'modules/verified');
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(LDir) + 'boss.json');
  try
    LDependencies := TJSONObject(LManifest.Find('dependencies'));
    AssertEquals('v2.0.0',
      LDependencies.Get('example.test/verified', ''));
  finally
    LManifest.Free;
  end;
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(LDir) + 'boss.json');
  try
    LExpectedHash := ManifestFingerprint(LManifest);
  finally
    LManifest.Free;
  end;
  LLock := LoadJsonObject(IncludeTrailingPathDelimiter(LDir) +
    'boss-lock.json');
  try
    LInstalled := TJSONObject(LLock.Find('installedModules'));
    LEntry := TJSONObject(LInstalled.Find('example.test/verified'));
    AssertEquals('registry-artifact', LEntry.Get('resolvedFrom', ''));
    AssertEquals('sha256:' + StringOfChar('a', 64),
      LEntry.Get('checksum', ''));
    AssertEquals(LExpectedHash, LLock.Get('hash', ''));
  finally
    LLock.Free;
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
  LArguments := BuildCachedCloneArguments('https://example.test/repo.git',
    'v1.0.0', '/tmp/repo', '/tmp/cache.git');
  try
    AssertEquals('--reference-if-able', LArguments[1]);
    AssertEquals('/tmp/cache.git', LArguments[2]);
    AssertEquals('--no-hardlinks', LArguments[3]);
  finally
    LArguments.Free;
  end;
end;

procedure TPosixCoreTests.TestStructuredProgressFormats;
var
  LEvent: TBoss4DProgressEvent;
  LJson, LPlain: string;
  LReporter: TBoss4DProgressReporter;
begin
  LEvent.OperationId := 'install-1';
  LEvent.PackageName := 'Demo';
  LEvent.Phase := 'verification';
  LEvent.Current := 1;
  LEvent.Total := 2;
  LEvent.MessageText := 'checking "digest"';
  LEvent.Timestamp := '2026-07-30T12:00:00.000Z';
  LJson := FormatProgressEvent(LEvent, pmJson);
  AssertTrue(Pos('"operationId":"install-1"', LJson) > 0);
  AssertTrue(Pos('"message":"checking \"digest\""', LJson) > 0);
  AssertTrue(Pos('"current":1,"total":2', LJson) > 0);
  LPlain := FormatProgressEvent(LEvent, pmPlain);
  AssertEquals('[verification] Demo 1/2 - checking "digest"', LPlain);
  AssertEquals('', FormatProgressEvent(LEvent, pmQuiet));
  LReporter := TBoss4DProgressReporter.Create(pmQuiet);
  try
    LReporter.Emit(LEvent);
  finally
    LReporter.Free;
  end;
end;

procedure TPosixCoreTests.TestProgressModePrecedence;
begin
  AssertEquals(Ord(pmPlain), Ord(ParseProgressMode('', False, False)));
  AssertEquals(Ord(pmInteractive), Ord(ParseProgressMode(
    'interactive', False, False)));
  AssertEquals(Ord(pmJson), Ord(ParseProgressMode('plain', True, False)));
  AssertEquals(Ord(pmQuiet), Ord(ParseProgressMode('json', True, True)));
  try
    ParseProgressMode('invalid', False, False);
    Fail('Invalid progress mode should fail');
  except
    on E: Exception do AssertTrue(Pos('invalid progress mode', E.Message) > 0);
  end;
end;

procedure TPosixCoreTests.TestExitCodeClassification;
begin
  AssertEquals(2, ClassifyExitCode('usage: boss4d package install'));
  AssertEquals(3, ClassifyExitCode('package not found: demo'));
  AssertEquals(4, ClassifyExitCode('artifact SHA-256 mismatch'));
  AssertEquals(5, ClassifyExitCode('offline registry cache miss'));
  AssertEquals(6, ClassifyExitCode('audit policy violation: 1'));
  AssertEquals(130, ClassifyExitCode('operation cancelled'));
  AssertEquals(1, ClassifyExitCode('unexpected failure'));
end;

procedure TPosixCoreTests.TestCancellation;
begin
  ResetCancellation;
  CheckCancelled;
  RequestCancellation;
  try
    CheckCancelled;
    Fail('Cancellation should stop the operation');
  except
    on E: Exception do AssertEquals('operation cancelled', E.Message);
  end;
  ResetCancellation;
end;

procedure TPosixCoreTests.TestInstallHonorsCancellation;
var
  LDir: string;
begin
  LDir := NewTempDirectory;
  InitProject(LDir);
  RequestCancellation;
  try
    try
      InstallProject(LDir);
      Fail('Install should honor cancellation');
    except
      on E: Exception do AssertEquals('operation cancelled', E.Message);
    end;
  finally
    ResetCancellation;
  end;
end;

procedure TPosixCoreTests.TestLinuxDoctor;
var
  LResults: TStringList;
begin
  AssertTrue(FindExecutable('sha256sum') <> '');
  AssertEquals('', FindExecutable('boss4d-command-that-does-not-exist'));
  LResults := RunDoctor;
  try
    AssertTrue(LResults.Text,
      LResults.IndexOf('OK sha256sum: available') >= 0);
    AssertTrue(LResults.Text, LResults.IndexOf('OK home: writable') >= 0);
    AssertEquals(LResults.Text,
      LResults.IndexOf('ERROR git: not found') < 0, DoctorPassed(LResults));
  finally
    LResults.Free;
  end;
end;

function TAuditFetcherMock.Fetch(const ARevision, APageToken: string): string;
begin
  Inc(FCalls);
  if FFail then raise Exception.Create('network unavailable');
  if APageToken = '' then Result := FResponse
  else Result := FNextResponse;
end;

function TSecretToolRunnerMock.Run(const AArguments: TStrings;
  const AInput: string; out AOutput: string): Boolean;
begin
  FCommand := AArguments.DelimitedText;
  FInput := AInput;
  AOutput := FOutput;
  Result := FSuccess;
end;

function TUpdateMock.Fetch: string;
begin
  Result := FRelease;
end;

function TUpdateMock.Download(const AUrl, ATarget: string): Boolean;
var
  LSource: string;
  LInput, LOutput: TFileStream;
begin
  Inc(FDownloads);
  if Pos('SHA256SUMS', AUrl) > 0 then
    LSource := IncludeTrailingPathDelimiter(FDirectory) + 'SHA256SUMS.txt'
  else
    LSource := IncludeTrailingPathDelimiter(FDirectory) +
      'boss4d-linux-x86_64.tar.gz';
  LInput := TFileStream.Create(LSource, fmOpenRead);
  try
    LOutput := TFileStream.Create(ATarget, fmCreate);
    try
      LOutput.CopyFrom(LInput, 0);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
  Result := True;
end;

function TUpdateMock.Extract(const AArchive,
  ATargetDirectory: string): Boolean;
begin
  ForceDirectories(ATargetDirectory);
  SaveFixture(IncludeTrailingPathDelimiter(ATargetDirectory) + 'boss4d',
    'new executable');
  Result := True;
end;

function TToolCompilerMock.Compile(const ASourceDirectory,
  AOutputPath: string): Boolean;
begin
  Inc(FCalls);
  SaveFixture(AOutputPath, 'tool build ' + IntToStr(FCalls));
  Result := True;
end;

function CreateComplianceLock(const ADirectory: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ADirectory) + 'boss-lock.json';
  SaveFixture(Result, '{"lockVersion":3,"hash":"fixture-hash",' +
    '"updated":"2026-07-30T12:00:00Z","root":{"name":"app",' +
    '"version":"1.0.0"},"installedModules":{"example.test/demo":{' +
    '"name":"demo","version":"2.0.0","repository":"example.test/demo",' +
    '"scope":"development","revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",' +
    '"checksum":"sha256:' + StringOfChar('b', 64) +
    '","dependencies":[]}}}');
end;

procedure TPosixCoreTests.TestCycloneDxLockOnlySbom;
var
  LDir, LLock, LOutput: string;
  LRoot: TJSONObject;
  LComponents: TJSONArray;
  LComponent: TJSONObject;
  LOptions: TBoss4DSbomOptions;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LOutput := IncludeTrailingPathDelimiter(LDir) + 'sbom.cdx.json';
  LOptions := DefaultSbomOptions(sfCycloneDX);
  GenerateLockSbom(LLock, LOutput, LOptions);
  LRoot := LoadJsonObject(LOutput);
  try
    AssertEquals('CycloneDX', LRoot.Get('bomFormat', ''));
    AssertEquals('1.7', LRoot.Get('specVersion', ''));
    LComponents := TJSONArray(LRoot.Find('components'));
    AssertEquals(1, LComponents.Count);
    LComponent := TJSONObject(LComponents.Items[0]);
    AssertEquals('demo', LComponent.Get('name', ''));
    AssertTrue(Assigned(LComponent.Find('hashes')));
    AssertTrue(Pos('development', LComponent.AsJSON) > 0);
  finally
    LRoot.Free;
  end;
end;

procedure TPosixCoreTests.TestSpdxLockOnlySbom;
var
  LDir, LLock, LOutput: string;
  LRoot: TJSONObject;
  LPackages: TJSONArray;
  LPackage: TJSONObject;
  LOptions: TBoss4DSbomOptions;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LOutput := IncludeTrailingPathDelimiter(LDir) + 'sbom.spdx.json';
  LOptions := DefaultSbomOptions(sfSpdx);
  GenerateLockSbom(LLock, LOutput, LOptions);
  LRoot := LoadJsonObject(LOutput);
  try
    AssertEquals('SPDX-2.3', LRoot.Get('spdxVersion', ''));
    LPackages := TJSONArray(LRoot.Find('packages'));
    AssertEquals(1, LPackages.Count);
    LPackage := TJSONObject(LPackages.Items[0]);
    AssertEquals('demo', LPackage.Get('name', ''));
    AssertEquals('boss4d:scope=development', LPackage.Get('comment', ''));
    AssertTrue(Assigned(LRoot.Find('relationships')));
  finally
    LRoot.Free;
  end;
end;

procedure TPosixCoreTests.TestCycloneDxVex;
var
  LDir, LLock, LOutput, LVex: string;
  LRoot: TJSONObject;
  LVulnerabilities: TJSONArray;
  LOptions: TBoss4DSbomOptions;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LVex := IncludeTrailingPathDelimiter(LDir) + 'security.vex.json';
  SaveFixture(LVex, '{"vulnerabilities":[{"id":"CVE-2099-0001",' +
    '"component":"boss4d:demo@2.0.0","state":"not_affected",' +
    '"detail":"code path excluded"}]}');
  LOutput := IncludeTrailingPathDelimiter(LDir) + 'sbom.vex.cdx.json';
  LOptions := DefaultSbomOptions(sfCycloneDX);
  LOptions.VexPath := LVex;
  GenerateLockSbom(LLock, LOutput, LOptions);
  LRoot := LoadJsonObject(LOutput);
  try
    LVulnerabilities := TJSONArray(LRoot.Find('vulnerabilities'));
    AssertEquals(1, LVulnerabilities.Count);
    AssertTrue(Pos('"state" : "not_affected"',
      LVulnerabilities.Items[0].FormatJSON) > 0);
  finally
    LRoot.Free;
  end;
end;

procedure TPosixCoreTests.TestSbomReproducibleAndRejectsSpdxVex;
var
  LDir, LLock, LFirst, LSecond, LVex: string;
  LOne, LTwo: TStringList;
  LOptions: TBoss4DSbomOptions;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LFirst := IncludeTrailingPathDelimiter(LDir) + 'one.json';
  LSecond := IncludeTrailingPathDelimiter(LDir) + 'two.json';
  LOptions := DefaultSbomOptions(sfCycloneDX);
  LOptions.Reproducible := True;
  GenerateLockSbom(LLock, LFirst, LOptions);
  GenerateLockSbom(LLock, LSecond, LOptions);
  LOne := TStringList.Create;
  LTwo := TStringList.Create;
  try
    LOne.LoadFromFile(LFirst);
    LTwo.LoadFromFile(LSecond);
    AssertEquals(LOne.Text, LTwo.Text);
  finally
    LOne.Free;
    LTwo.Free;
  end;
  LVex := IncludeTrailingPathDelimiter(LDir) + 'vex.json';
  SaveFixture(LVex, '{"vulnerabilities":[]}');
  try
    LOptions := DefaultSbomOptions(sfSpdx);
    LOptions.VexPath := LVex;
    GenerateLockSbom(LLock, LFirst, LOptions);
    Fail('SPDX 2.3 VEX should be rejected');
  except
    on E: Exception do AssertTrue(Pos('VEX requires CycloneDX', E.Message) > 0);
  end;
end;

procedure TPosixCoreTests.TestAuditPolicyAndVex;
var
  LDir, LLock, LVex: string;
  LFetcher: TAuditFetcherMock;
  LService: TBoss4DAuditService;
  LOptions: TBoss4DAuditOptions;
  LSummary: TBoss4DAuditSummary;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LFetcher := TAuditFetcherMock.Create;
  try
    LFetcher.Response := '{"vulns":[{"id":"OSV-TEST-1",' +
      '"database_specific":{"severity":"HIGH"}}],' +
      '"next_page_token":"page-2"}';
    LFetcher.NextResponse := '{"vulns":[{"id":"OSV-TEST-2",' +
      '"database_specific":{"severity":"LOW"}}]}';
    LService := TBoss4DAuditService.Create(@LFetcher.Fetch);
    try
      LOptions := DefaultAuditOptions;
      LOptions.CacheDirectory := IncludeTrailingPathDelimiter(LDir) + 'cache';
      LOptions.FailOn := 'high';
      LSummary := LService.Execute(LLock, LOptions);
      AssertEquals(1, LSummary.Packages);
      AssertEquals(2, LSummary.Vulnerabilities);
      AssertEquals(1, LSummary.PolicyViolations);
      AssertEquals(2, LFetcher.Calls);
      AssertTrue(Pos('HIGH OSV-TEST-1', LService.Findings[0]) = 1);
      LVex := IncludeTrailingPathDelimiter(LDir) + 'audit.vex.json';
      SaveFixture(LVex, '{"vulnerabilities":[{"id":"OSV-TEST-1",' +
        '"state":"not_affected"}]}');
      LOptions.VexPath := LVex;
      LSummary := LService.Execute(LLock, LOptions);
      AssertEquals(1, LSummary.Suppressed);
      AssertEquals(0, LSummary.PolicyViolations);
    finally
      LService.Free;
    end;
  finally
    LFetcher.Free;
  end;
end;

procedure TPosixCoreTests.TestAuditOfflineCache;
var
  LDir, LLock: string;
  LFetcher: TAuditFetcherMock;
  LService: TBoss4DAuditService;
  LOptions: TBoss4DAuditOptions;
  LSummary: TBoss4DAuditSummary;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LFetcher := TAuditFetcherMock.Create;
  try
    LFetcher.Response := '{"vulns":[]}';
    LService := TBoss4DAuditService.Create(@LFetcher.Fetch);
    try
      LOptions := DefaultAuditOptions;
      LOptions.CacheDirectory := IncludeTrailingPathDelimiter(LDir) + 'cache';
      LSummary := LService.Execute(LLock, LOptions);
      AssertEquals(1, LSummary.Packages);
      AssertEquals(1, LFetcher.Calls);
      LFetcher.Fail := True;
      LOptions.Offline := True;
      LSummary := LService.Execute(LLock, LOptions);
      AssertEquals(0, LSummary.Vulnerabilities);
      AssertEquals(1, LFetcher.Calls);
    finally
      LService.Free;
    end;
  finally
    LFetcher.Free;
  end;
end;

procedure TPosixCoreTests.TestAuditOfflineCacheMiss;
var
  LDir, LLock: string;
  LOptions: TBoss4DAuditOptions;
  LService: TBoss4DAuditService;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LOptions := DefaultAuditOptions;
  LOptions.CacheDirectory := IncludeTrailingPathDelimiter(LDir) + 'empty-cache';
  LOptions.Offline := True;
  LService := TBoss4DAuditService.Create;
  try
    try
      LService.Execute(LLock, LOptions);
      Fail('Offline audit cache miss should fail');
    except
      on E: Exception do AssertTrue(Pos('offline audit cache miss',
        E.Message) > 0);
    end;
  finally
    LService.Free;
  end;
end;

procedure TPosixCoreTests.TestDirectoryDigestIsDeterministicAndExcludesGit;
var
  LDir, LFirst, LSecond: string;
begin
  LDir := NewTempDirectory;
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'src');
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'src/a.pas', 'a');
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'b.pas', 'b');
  LFirst := DirectorySha256(LDir);
  AssertEquals(LFirst, DirectorySha256(LDir));
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + '.git');
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + '.git/index', 'ignored');
  AssertEquals(LFirst, DirectorySha256(LDir));
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'b.pas', 'changed');
  LSecond := DirectorySha256(LDir);
  AssertTrue(LFirst <> LSecond);
end;

procedure TPosixCoreTests.TestStrictSbomEvidenceAndValidation;
var
  LDir, LLock, LOutput, LInvalid: string;
  LOptions: TBoss4DSbomOptions;
begin
  LDir := NewTempDirectory;
  LLock := CreateComplianceLock(LDir);
  LOutput := IncludeTrailingPathDelimiter(LDir) + 'strict.cdx.json';
  LOptions := DefaultSbomOptions(sfCycloneDX);
  LOptions.Reproducible := True;
  LOptions.Strict := True;
  LOptions.Validate := True;
  GenerateLockSbom(LLock, LOutput, LOptions);
  ValidateGeneratedSbom(LOutput, sfCycloneDX);
  LInvalid := IncludeTrailingPathDelimiter(LDir) + 'invalid.json';
  SaveFixture(LInvalid, '{"bomFormat":"CycloneDX"}');
  try
    ValidateGeneratedSbom(LInvalid, sfCycloneDX);
    Fail('Invalid generated SBOM should fail validation');
  except
    on E: Exception do AssertTrue(Pos('CycloneDX document is invalid',
      E.Message) > 0);
  end;
  SaveFixture(LLock, '{"lockVersion":3,"root":{"name":"app",' +
    '"version":"1.0.0"},"installedModules":{"repo":{"name":"demo",' +
    '"version":"1.0.0","repository":"repo","resolvedFrom":"git",' +
    '"checksum":"sha256:' + StringOfChar('a', 64) +
    '","dependencies":[]}}}');
  try
    GenerateLockSbom(LLock, LOutput, LOptions);
    Fail('Strict Git dependency without revision should fail');
  except
    on E: Exception do AssertTrue(Pos('requires Git revision', E.Message) > 0);
  end;
end;

procedure TPosixCoreTests.TestGitLockEvidence;
var
  LDir: string;
  LEvidence: TJSONObject;
begin
  LDir := NewTempDirectory;
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'unit.pas', 'content');
  LEvidence := CreateGitLockEvidence('example.test/demo', 'v1.0.0',
    LDir, 'runtime', 'abc123');
  try
    AssertEquals('git', LEvidence.Get('resolvedFrom', ''));
    AssertEquals('abc123', LEvidence.Get('revision', ''));
    AssertEquals('modules/demo', LEvidence.Get('target', ''));
    AssertTrue(Pos('sha256:', LEvidence.Get('checksum', '')) = 1);
    AssertTrue(LEvidence.Find('dependencies') is TJSONArray);
  finally
    LEvidence.Free;
  end;
end;

procedure TPosixCoreTests.TestSecretServiceCredentialStore;
var
  LRunner: TSecretToolRunnerMock;
  LStore: TBoss4DPosixCredentialStore;
begin
  LRunner := TSecretToolRunnerMock.Create;
  try
    LRunner.Success := True;
    LStore := TBoss4DPosixCredentialStore.Create(@LRunner.Run);
    try
      LStore.Store('GitHub', 'secret-token');
      AssertTrue(Pos('store', LRunner.Command) > 0);
      AssertTrue(Pos('secret-token', LRunner.Command) = 0);
      AssertEquals('secret-token', LRunner.Input);
      LRunner.Output := 'retrieved-token';
      AssertEquals('retrieved-token', LStore.Retrieve('github'));
      LStore.Remove('github');
      AssertTrue(Pos('clear', LRunner.Command) > 0);
    finally
      LStore.Free;
    end;
  finally
    LRunner.Free;
  end;
end;

procedure TPosixCoreTests.TestSecretMasking;
begin
  AssertEquals('request token=*** failed',
    MaskSecret('request token=abc123 failed', 'abc123'));
  AssertEquals('unchanged', MaskSecret('unchanged', ''));
  AssertEquals('https://github.com/example/private',
    NormalizeRepositoryUrl('github.com/example/private'));
  AssertEquals('ssh://git@example.test/repo',
    NormalizeRepositoryUrl('ssh://git@example.test/repo'));
end;

procedure TPosixCoreTests.TestCacheManagement;
var
  LDir: string;
begin
  LDir := NewTempDirectory;
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'old');
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'old/data.bin', '1234');
  AssertTrue(DirectorySize(LDir) >= 4);
  AssertEquals(1, PruneCacheDirectory(LDir, IncDay(Now, 1)));
  AssertEquals(Int64(0), DirectorySize(LDir));
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'one');
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'two');
  AssertEquals(2, CleanCacheDirectory(LDir));
  AssertTrue(DirectoryExists(LDir));
end;

procedure TPosixCoreTests.TestWorkspaceLinks;
var
  LDir: string;
begin
  LDir := NewTempDirectory;
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'packages/one');
  ForceDirectories(IncludeTrailingPathDelimiter(LDir) + 'packages/two');
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'boss.json',
    '{"name":"workspace","version":"1.0.0","dependencies":{},' +
    '"workspaces":["packages/*"]}');
  AssertEquals(2, LinkDeclaredWorkspaces(LDir));
  AssertTrue(DirectoryExists(IncludeTrailingPathDelimiter(LDir) +
    'packages/one/modules'));
  AssertTrue(DirectoryExists(IncludeTrailingPathDelimiter(LDir) +
    'packages/two/modules'));
  AssertEquals(0, LinkDeclaredWorkspaces(LDir));
end;

procedure TPosixCoreTests.TestSecureSelfUpdate;
var
  LDir, LArchive, LTarget, LHash: string;
  LMock: TUpdateMock;
  LService: TBoss4DPosixUpdateService;
  LResult: TBoss4DUpdateResult;
  LContent: TStringList;
begin
  LDir := NewTempDirectory;
  LArchive := IncludeTrailingPathDelimiter(LDir) +
    'boss4d-linux-x86_64.tar.gz';
  SaveFixture(LArchive, 'archive fixture');
  LHash := Sha256File(LArchive);
  SaveFixture(IncludeTrailingPathDelimiter(LDir) + 'SHA256SUMS.txt',
    LHash + '  boss4d-linux-x86_64.tar.gz');
  LTarget := IncludeTrailingPathDelimiter(LDir) + 'installed/boss4d';
  ForceDirectories(ExtractFileDir(LTarget));
  SaveFixture(LTarget, 'old executable');
  LMock := TUpdateMock.Create;
  try
    LMock.Directory := LDir;
    LMock.Release := '{"tag_name":"v1.6.0","assets":[' +
      '{"name":"boss4d-linux-x86_64.tar.gz",' +
      '"browser_download_url":"https://release/archive"},' +
      '{"name":"SHA256SUMS.txt",' +
      '"browser_download_url":"https://release/SHA256SUMS.txt"}]}';
    LService := TBoss4DPosixUpdateService.Create(@LMock.Fetch,
      @LMock.Download, @LMock.Extract);
    try
      LResult := LService.Execute('1.5.0', LTarget);
      AssertTrue(LResult.Updated);
      AssertEquals('v1.6.0', LResult.Version);
      AssertEquals(2, LMock.Downloads);
      LContent := TStringList.Create;
      try
        LContent.LoadFromFile(LTarget);
        AssertTrue(Pos('new executable', LContent.Text) > 0);
      finally
        LContent.Free;
      end;
      AssertFalse(FileExists(LTarget + '.previous'));
    finally
      LService.Free;
    end;
  finally
    LMock.Free;
  end;
end;

procedure TPosixCoreTests.TestSelfUpdateSkipsCurrentVersion;
var
  LMock: TUpdateMock;
  LService: TBoss4DPosixUpdateService;
  LResult: TBoss4DUpdateResult;
begin
  AssertTrue(CompareVersions('1.5.0', 'v1.6.0') < 0);
  AssertEquals(0, CompareVersions('v1.5.0', '1.5.0'));
  LMock := TUpdateMock.Create;
  try
    LMock.Release := '{"tag_name":"v1.5.0","assets":[]}';
    LService := TBoss4DPosixUpdateService.Create(@LMock.Fetch,
      @LMock.Download, @LMock.Extract);
    try
      LResult := LService.Execute('1.5.0', '/not/used');
      AssertFalse(LResult.Updated);
      AssertEquals(0, LMock.Downloads);
    finally
      LService.Free;
    end;
  finally
    LMock.Free;
  end;
end;

procedure TPosixCoreTests.TestGlobalToolLifecycle;
var
  LDir, LSource, LTarget: string;
  LCompiler: TToolCompilerMock;
  LService: TBoss4DPosixToolService;
  LTools, LContent: TStringList;
begin
  LDir := NewTempDirectory;
  LSource := IncludeTrailingPathDelimiter(LDir) + 'source';
  ForceDirectories(LSource);
  LCompiler := TToolCompilerMock.Create;
  try
    LService := TBoss4DPosixToolService.Create(
      IncludeTrailingPathDelimiter(LDir) + 'home', @LCompiler.Compile);
    try
      LTarget := LService.Install(LSource, 'demo-tool');
      AssertTrue(FileExists(LTarget));
      LTools := LService.List;
      try
        AssertEquals(1, LTools.Count);
        AssertEquals('demo-tool', LTools[0]);
      finally
        LTools.Free;
      end;
      LService.Install(LSource, 'demo-tool');
      AssertEquals(2, LCompiler.Calls);
      LContent := TStringList.Create;
      try
        LContent.LoadFromFile(LTarget);
        AssertTrue(Pos('tool build 2', LContent.Text) > 0);
      finally
        LContent.Free;
      end;
      AssertFalse(FileExists(LTarget + '.previous'));
      LService.Uninstall('demo-tool');
      AssertFalse(FileExists(LTarget));
      LTools := LService.List;
      try
        AssertEquals(0, LTools.Count);
      finally
        LTools.Free;
      end;
    finally
      LService.Free;
    end;
  finally
    LCompiler.Free;
  end;
end;

initialization
  RegisterTest(TPosixCoreTests);

end.
