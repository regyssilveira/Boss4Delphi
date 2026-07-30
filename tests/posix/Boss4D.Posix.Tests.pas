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
  end;

implementation

uses
  Boss4D.Posix.Core;

procedure TPosixCoreTests.TestPlatform;
begin
  AssertEquals('linux', PlatformName);
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
