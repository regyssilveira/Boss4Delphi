program Boss4DPosixTests;

{$mode objfpc}{$H+}

uses
  consoletestrunner, Boss4D.Posix.Tests;

type
  TRunner = class(TTestRunner);

begin
  TRunner.Create(nil).Run;
end.
