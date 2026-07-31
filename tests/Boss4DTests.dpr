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
  Boss4D.Core.Domain.BuildMatrix in '..\src\Core\Domain\Boss4D.Core.Domain.BuildMatrix.pas',
  Boss4D.Core.Domain.Lock in '..\src\Core\Domain\Boss4D.Core.Domain.Lock.pas',
  Boss4D.Core.Domain.Sbom in '..\src\Core\Domain\Boss4D.Core.Domain.Sbom.pas',
  Boss4D.Core.Domain.License in '..\src\Core\Domain\Boss4D.Core.Domain.License.pas',
  Boss4D.Core.Domain.Progress in '..\src\Core\Domain\Boss4D.Core.Domain.Progress.pas',
  Boss4D.Core.Domain.IDEProfile in '..\src\Core\Domain\Boss4D.Core.Domain.IDEProfile.pas',
  Boss4D.Core.Ports in '..\src\Core\Ports\Boss4D.Core.Ports.pas',
  Boss4D.Core.Platform in '..\src\Core\Platform\Boss4D.Core.Platform.pas',
  Boss4D.Adapters.Platform.Windows in '..\src\Adapters\Platform\Windows\Boss4D.Adapters.Platform.Windows.pas',
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
  Boss4D.Adapters.Security.Windows in '..\src\Adapters\Security\Boss4D.Adapters.Security.Windows.pas',
  Boss4D.Adapters.Security.Gpg in '..\src\Adapters\Security\Boss4D.Adapters.Security.Gpg.pas',
  Boss4D.Core.Services.Init in '..\src\Core\Services\Boss4D.Core.Services.Init.pas',
  Boss4D.Core.Services.Config in '..\src\Core\Services\Boss4D.Core.Services.Config.pas',
  Boss4D.Core.Services.Install in '..\src\Core\Services\Boss4D.Core.Services.Install.pas',
  Boss4D.Core.Services.SelfUpdate in '..\src\Core\Services\Boss4D.Core.Services.SelfUpdate.pas',
  Boss4D.Core.Services.Pack in '..\src\Core\Services\Boss4D.Core.Services.Pack.pas',
  Boss4D.Core.Services.Resolver in '..\src\Core\Services\Boss4D.Core.Services.Resolver.pas',
  Boss4D.Core.Services.Conformance in '..\src\Core\Services\Boss4D.Core.Services.Conformance.pas',
  Boss4D.Core.Services.RegistryPortal in '..\src\Core\Services\Boss4D.Core.Services.RegistryPortal.pas',
  Boss4D.Core.Services.Progress in '..\src\Core\Services\Boss4D.Core.Services.Progress.pas',
  Boss4D.Core.Services.Transaction in '..\src\Core\Services\Boss4D.Core.Services.Transaction.pas',
  Boss4D.Core.Services.Dependencies in '..\src\Core\Services\Boss4D.Core.Services.Dependencies.pas',
  Boss4D.Core.Services.VersionHistory in '..\src\Core\Services\Boss4D.Core.Services.VersionHistory.pas',
  Boss4D.Core.Services.Audit in '..\src\Core\Services\Boss4D.Core.Services.Audit.pas',
  Boss4D.Core.Services.PackageIndex in '..\src\Core\Services\Boss4D.Core.Services.PackageIndex.pas',
  Boss4D.Core.Services.DependencySubmission in '..\src\Core\Services\Boss4D.Core.Services.DependencySubmission.pas',
  Boss4D.Core.Services.Publish in '..\src\Core\Services\Boss4D.Core.Services.Publish.pas',
  Boss4D.Core.Services.RegistrySubmission in '..\src\Core\Services\Boss4D.Core.Services.RegistrySubmission.pas',
  Boss4D.Core.Services.RegistryCheckout in '..\src\Core\Services\Boss4D.Core.Services.RegistryCheckout.pas',
  Boss4D.Core.Services.RegistryHealth in '..\src\Core\Services\Boss4D.Core.Services.RegistryHealth.pas',
  Boss4D.Core.Services.RegistryPullRequest in '..\src\Core\Services\Boss4D.Core.Services.RegistryPullRequest.pas',
  Boss4D.Core.Services.OfficialPublish in '..\src\Core\Services\Boss4D.Core.Services.OfficialPublish.pas',
  Boss4D.Core.Services.ArtifactCache in '..\src\Core\Services\Boss4D.Core.Services.ArtifactCache.pas',
  Boss4D.Core.Services.BuildMatrix in '..\src\Core\Services\Boss4D.Core.Services.BuildMatrix.pas',
  Boss4D.Core.Services.BuildConventions in '..\src\Core\Services\Boss4D.Core.Services.BuildConventions.pas',
  Boss4D.Core.Services.BuildCapabilities in '..\src\Core\Services\Boss4D.Core.Services.BuildCapabilities.pas',
  Boss4D.Core.Services.BuildSpec in '..\src\Core\Services\Boss4D.Core.Services.BuildSpec.pas',
  Boss4D.Core.Services.BuildCommand in '..\src\Core\Services\Boss4D.Core.Services.BuildCommand.pas',
  Boss4D.Core.Services.BuildDoctor in '..\src\Core\Services\Boss4D.Core.Services.BuildDoctor.pas',
  Boss4D.Core.Services.BuildPaths in '..\src\Core\Services\Boss4D.Core.Services.BuildPaths.pas',
  Boss4D.Core.Services.BuildExecutor in '..\src\Core\Services\Boss4D.Core.Services.BuildExecutor.pas',
  Boss4D.Core.Services.BuildGraph in '..\src\Core\Services\Boss4D.Core.Services.BuildGraph.pas',
  Boss4D.Core.Services.ComponentPlan in '..\src\Core\Services\Boss4D.Core.Services.ComponentPlan.pas',
  Boss4D.Core.Services.ComponentRemoval in '..\src\Core\Services\Boss4D.Core.Services.ComponentRemoval.pas',
  Boss4D.Core.Services.BuildState in '..\src\Core\Services\Boss4D.Core.Services.BuildState.pas',
  Boss4D.Core.Services.BuildScheduler in '..\src\Core\Services\Boss4D.Core.Services.BuildScheduler.pas',
  Boss4D.Core.Services.BuildInventory in '..\src\Core\Services\Boss4D.Core.Services.BuildInventory.pas',
  Boss4D.Core.Services.BuildCoordinator in '..\src\Core\Services\Boss4D.Core.Services.BuildCoordinator.pas',
  Boss4D.Core.Services.OperationGate in '..\src\Core\Services\Boss4D.Core.Services.OperationGate.pas',
  Boss4D.Core.Services.Documentation in '..\src\Core\Services\Boss4D.Core.Services.Documentation.pas',
  Boss4D.Core.Services.IDEDiscovery in '..\src\Core\Services\Boss4D.Core.Services.IDEDiscovery.pas',
  Boss4D.Core.Services.PackageInstall in '..\src\Core\Services\Boss4D.Core.Services.PackageInstall.pas',
  Boss4D.Core.Services.Cache in '..\src\Core\Services\Boss4D.Core.Services.Cache.pas',
  Boss4D.Core.Services.Run in '..\src\Core\Services\Boss4D.Core.Services.Run.pas',
  Boss4D.Core.Services.Doctor in '..\src\Core\Services\Boss4D.Core.Services.Doctor.pas',
  Boss4D.Core.Services.License in '..\src\Core\Services\Boss4D.Core.Services.License.pas',
  Boss4D.Core.Services.Tree in '..\src\Core\Services\Boss4D.Core.Services.Tree.pas',
  Boss4D.Core.Services.Outdated in '..\src\Core\Services\Boss4D.Core.Services.Outdated.pas',
  Boss4D.Core.Services.IDEIntegration in '..\src\Core\Services\Boss4D.Core.Services.IDEIntegration.pas',
  Boss4D.Core.Services.IDERegistration in '..\src\Core\Services\Boss4D.Core.Services.IDERegistration.pas',
  Boss4D.Core.Services.IDEOperationLock in '..\src\Core\Services\Boss4D.Core.Services.IDEOperationLock.pas',
  Boss4D.Core.Services.IDEProcessPolicy in '..\src\Core\Services\Boss4D.Core.Services.IDEProcessPolicy.pas',
  Boss4D.Core.Services.IDEOperationResult in '..\src\Core\Services\Boss4D.Core.Services.IDEOperationResult.pas',
  Boss4D.Core.Services.IDEProfiles in '..\src\Core\Services\Boss4D.Core.Services.IDEProfiles.pas',
  Boss4D.Core.Services.IDEProfileApplication in '..\src\Core\Services\Boss4D.Core.Services.IDEProfileApplication.pas',
  Boss4D.Core.Services.IDEManagementQuery in '..\src\Core\Services\Boss4D.Core.Services.IDEManagementQuery.pas',
  Boss4D.GUI.IDE.Presenter in '..\src\GUI\Boss4D.GUI.IDE.Presenter.pas',
  Boss4D.GUI.Catalog.Presenter in '..\src\GUI\Boss4D.GUI.Catalog.Presenter.pas',
  Boss4D.GUI.IDE.Backend in '..\src\GUI\Boss4D.GUI.IDE.Backend.pas',
  Boss4D.Core.Services.Tool in '..\src\Core\Services\Boss4D.Core.Services.Tool.pas',
  Boss4D.Core.Services.Workspace in '..\src\Core\Services\Boss4D.Core.Services.Workspace.pas',
  Boss4D.Core.Services.GetIt in '..\src\Core\Services\Boss4D.Core.Services.GetIt.pas',
  Boss4D.Core.Services.Clean in '..\src\Core\Services\Boss4D.Core.Services.Clean.pas',
  Boss4D.Core.Services.Sbom in '..\src\Core\Services\Boss4D.Core.Services.Sbom.pas',
  Boss4D.Core.Services.Scaffold in '..\src\Core\Services\Boss4D.Core.Services.Scaffold.pas',
  Boss4D.Core.Services.SourceNormalizer in '..\src\Core\Services\Boss4D.Core.Services.SourceNormalizer.pas',
  Boss4D.Core.Services.PackageManifest in '..\src\Core\Services\Boss4D.Core.Services.PackageManifest.pas',
  Boss4D.Core.Services.LazarusProject in '..\src\Core\Services\Boss4D.Core.Services.LazarusProject.pas',
  Boss4D.CLI.Parser in '..\src\CLI\Boss4D.CLI.Parser.pas',
  Boss4D.Tests.Mocks in 'Boss4D.Tests.Mocks.pas',
  Boss4D.Tests.SemVer in 'Boss4D.Tests.SemVer.pas',
  Boss4D.Tests.Dependency in 'Boss4D.Tests.Dependency.pas',
  Boss4D.Tests.VersionHistory in 'Boss4D.Tests.VersionHistory.pas',
  Boss4D.Tests.Json in 'Boss4D.Tests.Json.pas',
  Boss4D.Tests.BuildMatrix in 'Boss4D.Tests.BuildMatrix.pas',
  Boss4D.Tests.ComponentPlan in 'Boss4D.Tests.ComponentPlan.pas',
  Boss4D.Tests.ComponentRemoval in 'Boss4D.Tests.ComponentRemoval.pas',
  Boss4D.Tests.BuildSpec in 'Boss4D.Tests.BuildSpec.pas',
  Boss4D.Tests.BuildCommand in 'Boss4D.Tests.BuildCommand.pas',
  Boss4D.Tests.BuildDoctor in 'Boss4D.Tests.BuildDoctor.pas',
  Boss4D.Tests.BuildInventory in 'Boss4D.Tests.BuildInventory.pas',
  Boss4D.Tests.BuildCoordinator in 'Boss4D.Tests.BuildCoordinator.pas',
  Boss4D.Tests.OperationGate in 'Boss4D.Tests.OperationGate.pas',
  Boss4D.Tests.Documentation in 'Boss4D.Tests.Documentation.pas',
  Boss4D.Tests.IDEDiscovery in 'Boss4D.Tests.IDEDiscovery.pas',
  Boss4D.Tests.IDEOperationLock in 'Boss4D.Tests.IDEOperationLock.pas',
  Boss4D.Tests.IDEProcessPolicy in 'Boss4D.Tests.IDEProcessPolicy.pas',
  Boss4D.Tests.IDEOperationResult in 'Boss4D.Tests.IDEOperationResult.pas',
  Boss4D.Tests.IDEProfiles in 'Boss4D.Tests.IDEProfiles.pas',
  Boss4D.Tests.IDEProfileApplication in 'Boss4D.Tests.IDEProfileApplication.pas',
  Boss4D.Tests.IDEManagementQuery in 'Boss4D.Tests.IDEManagementQuery.pas',
  Boss4D.Tests.GUI.IDEPresenter in 'Boss4D.Tests.GUI.IDEPresenter.pas',
  Boss4D.Tests.GUI.CatalogPresenter in 'Boss4D.Tests.GUI.CatalogPresenter.pas',
  Boss4D.Tests.Sbom in 'Boss4D.Tests.Sbom.pas',
  Boss4D.Tests.LazarusProject in 'Boss4D.Tests.LazarusProject.pas',
  Boss4D.Tests.Platform in 'Boss4D.Tests.Platform.pas',
  Boss4D.Tests.Progress in 'Boss4D.Tests.Progress.pas',
  Boss4D.Tests.SelfUpdate in 'Boss4D.Tests.SelfUpdate.pas',
  Boss4D.Tests.Pack in 'Boss4D.Tests.Pack.pas',
  Boss4D.Tests.Resolver in 'Boss4D.Tests.Resolver.pas',
  Boss4D.Tests.PackageSigning in 'Boss4D.Tests.PackageSigning.pas',
  Boss4D.Tests.PackageInstall in 'Boss4D.Tests.PackageInstall.pas',
  Boss4D.Tests.Conformance in 'Boss4D.Tests.Conformance.pas',
  Boss4D.Tests.RegistryPortal in 'Boss4D.Tests.RegistryPortal.pas',
  Boss4D.Tests.RegistryPullRequest in 'Boss4D.Tests.RegistryPullRequest.pas',
  Boss4D.Tests.RegistryHealth in 'Boss4D.Tests.RegistryHealth.pas',
  Boss4D.IDE.Wizard in '..\src\IDE\Boss4D.IDE.Wizard.pas',
  Boss4D.IDE.Legacy.Metadata in '..\src\IDE\Boss4D.IDE.Legacy.Metadata.pas',
  Boss4D.Tests.LegacyIDE in 'Boss4D.Tests.LegacyIDE.pas',
  Boss4D.Tests.Services in 'Boss4D.Tests.Services.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
begin
  ConfigureWindowsPlatform;
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
