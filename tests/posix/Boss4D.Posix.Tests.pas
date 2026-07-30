unit Boss4D.Posix.Tests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
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
  end;

implementation

uses
  fpjson, Boss4D.Posix.Core;

function NewTempDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'boss4d-posix-' + IntToHex(Random(MaxInt), 8);
  ForceDirectories(Result);
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

procedure WriteText(const AFileName, AValue: string);
var
  LFile: TextFile;
begin
  AssignFile(LFile, AFileName);
  Rewrite(LFile);
  try
    Write(LFile, AValue);
  finally
    CloseFile(LFile);
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
begin
  LDir := NewTempDirectory;
  WriteText(IncludeTrailingPathDelimiter(LDir) + 'boss.json',
    '{"name":"legacy","version":"1.0.0","dependencies":' +
    '{"github.com/hashload/horse":"^3.0.0"}}');
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
  LItems: TStringList;
begin
  LDir := NewTempDirectory;
  WriteText(IncludeTrailingPathDelimiter(LDir) + 'boss.json',
    '{"name":"app","version":"1.0.0","dependencies":{"runtime":"*"},' +
    '"devDependencies":{"test":"*"}}');
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
