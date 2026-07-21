program Boss4DTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
{$DYNAMICBASE OFF}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  {$ENDIF}
  DUnitX.TestFramework,
  Boss4D.Core.Domain.Consts in '..\src\Core\Domain\Boss4D.Core.Domain.Consts.pas',
  Boss4D.Core.Domain.Env in '..\src\Core\Domain\Boss4D.Core.Domain.Env.pas',
  Boss4D.Core.Domain.SemVer in '..\src\Core\Domain\Boss4D.Core.Domain.SemVer.pas',
  Boss4D.Core.Domain.Dependency in '..\src\Core\Domain\Boss4D.Core.Domain.Dependency.pas',
  Boss4D.Core.Domain.Package in '..\src\Core\Domain\Boss4D.Core.Domain.Package.pas',
  Boss4D.Core.Domain.Lock in '..\src\Core\Domain\Boss4D.Core.Domain.Lock.pas',
  Boss4D.Core.Domain.Sbom in '..\src\Core\Domain\Boss4D.Core.Domain.Sbom.pas',
  Boss4D.Core.Domain.License in '..\src\Core\Domain\Boss4D.Core.Domain.License.pas',
  Boss4D.Core.Ports in '..\src\Core\Ports\Boss4D.Core.Ports.pas',
  Boss4D.Adapters.Json in '..\src\Adapters\Json\Boss4D.Adapters.Json.pas',
  Boss4D.Adapters.Http in '..\src\Adapters\Http\Boss4D.Adapters.Http.pas',
  Boss4D.Adapters.Git in '..\src\Adapters\Git\Boss4D.Adapters.Git.pas',
  Boss4D.Adapters.Registry in '..\src\Adapters\Registry\Boss4D.Adapters.Registry.pas',
  Boss4D.Adapters.Compiler in '..\src\Adapters\Compiler\Boss4D.Adapters.Compiler.pas',
  Boss4D.Adapters.Sbom.CycloneDX in '..\src\Adapters\Sbom\Boss4D.Adapters.Sbom.CycloneDX.pas',
  Boss4D.Adapters.Sbom.Collectors in '..\src\Adapters\Sbom\Boss4D.Adapters.Sbom.Collectors.pas',
  Boss4D.Adapters.Sbom.Spdx in '..\src\Adapters\Sbom\Boss4D.Adapters.Sbom.Spdx.pas',
  Boss4D.Adapters.Sbom.Security in '..\src\Adapters\Sbom\Boss4D.Adapters.Sbom.Security.pas',
  Boss4D.Adapters.Logger in '..\src\Adapters\Logger\Boss4D.Adapters.Logger.pas',
  Boss4D.Core.Services.Init in '..\src\Core\Services\Boss4D.Core.Services.Init.pas',
  Boss4D.Core.Services.Config in '..\src\Core\Services\Boss4D.Core.Services.Config.pas',
  Boss4D.Core.Services.Install in '..\src\Core\Services\Boss4D.Core.Services.Install.pas',
  Boss4D.Core.Services.Cache in '..\src\Core\Services\Boss4D.Core.Services.Cache.pas',
  Boss4D.Core.Services.Run in '..\src\Core\Services\Boss4D.Core.Services.Run.pas',
  Boss4D.Core.Services.Doctor in '..\src\Core\Services\Boss4D.Core.Services.Doctor.pas',
  Boss4D.Core.Services.License in '..\src\Core\Services\Boss4D.Core.Services.License.pas',
  Boss4D.Core.Services.Tree in '..\src\Core\Services\Boss4D.Core.Services.Tree.pas',
  Boss4D.Core.Services.Outdated in '..\src\Core\Services\Boss4D.Core.Services.Outdated.pas',
  Boss4D.Core.Services.IDEIntegration in '..\src\Core\Services\Boss4D.Core.Services.IDEIntegration.pas',
  Boss4D.Core.Services.Tool in '..\src\Core\Services\Boss4D.Core.Services.Tool.pas',
  Boss4D.Core.Services.Workspace in '..\src\Core\Services\Boss4D.Core.Services.Workspace.pas',
  Boss4D.Core.Services.GetIt in '..\src\Core\Services\Boss4D.Core.Services.GetIt.pas',
  Boss4D.Core.Services.Clean in '..\src\Core\Services\Boss4D.Core.Services.Clean.pas',
  Boss4D.Core.Services.Sbom in '..\src\Core\Services\Boss4D.Core.Services.Sbom.pas',
  Boss4D.CLI.Parser in '..\src\CLI\Boss4D.CLI.Parser.pas',
  Boss4D.Tests.Mocks in 'Boss4D.Tests.Mocks.pas',
  Boss4D.Tests.SemVer in 'Boss4D.Tests.SemVer.pas',
  Boss4D.Tests.Dependency in 'Boss4D.Tests.Dependency.pas',
  Boss4D.Tests.Json in 'Boss4D.Tests.Json.pas',
  Boss4D.Tests.Sbom in 'Boss4D.Tests.Sbom.pas',
  Boss4D.IDE.Wizard in '..\src\IDE\Boss4D.IDE.Wizard.pas',
  Boss4D.Tests.Services in 'Boss4D.Tests.Services.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  Exit;
{$ENDIF}
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);

    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
