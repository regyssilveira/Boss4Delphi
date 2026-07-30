program Boss4D;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Threading,
  Winapi.Windows,
  Boss4D.Core.Ports in 'Core/Ports/Boss4D.Core.Ports.pas',
  Boss4D.Core.Platform in 'Core/Platform/Boss4D.Core.Platform.pas',
  Boss4D.Adapters.Platform.Windows in 'Adapters/Platform/Windows/Boss4D.Adapters.Platform.Windows.pas',
  Boss4D.Core.Domain.Consts in 'Core/Domain/Boss4D.Core.Domain.Consts.pas',
  Boss4D.Core.Domain.Env in 'Core/Domain/Boss4D.Core.Domain.Env.pas',
  Boss4D.Core.Domain.SemVer in 'Core/Domain/Boss4D.Core.Domain.SemVer.pas',
  Boss4D.Core.Domain.Dependency in 'Core/Domain/Boss4D.Core.Domain.Dependency.pas',
  Boss4D.Core.Domain.Package in 'Core/Domain/Boss4D.Core.Domain.Package.pas',
  Boss4D.Core.Domain.BuildMatrix in 'Core/Domain/Boss4D.Core.Domain.BuildMatrix.pas',
  Boss4D.Core.Domain.Lock in 'Core/Domain/Boss4D.Core.Domain.Lock.pas',
  Boss4D.Core.Domain.Sbom in 'Core/Domain/Boss4D.Core.Domain.Sbom.pas',
  Boss4D.Core.Domain.License in 'Core/Domain/Boss4D.Core.Domain.License.pas',
  Boss4D.Core.Domain.Progress in 'Core/Domain/Boss4D.Core.Domain.Progress.pas',
  Boss4D.Adapters.Json in 'Adapters/Json/Boss4D.Adapters.Json.pas',
  Boss4D.Adapters.Logger in 'Adapters/Logger/Boss4D.Adapters.Logger.pas',
  Boss4D.Adapters.Security.Windows in 'Adapters/Security/Boss4D.Adapters.Security.Windows.pas',
  Boss4D.Adapters.Security.Gpg in 'Adapters/Security/Boss4D.Adapters.Security.Gpg.pas',
  Boss4D.Adapters.Http in 'Adapters/Http/Boss4D.Adapters.Http.pas',
  Boss4D.Adapters.Git in 'Adapters/Git/Boss4D.Adapters.Git.pas',
  Boss4D.Adapters.Registry in 'Adapters/Registry/Boss4D.Adapters.Registry.pas',
  Boss4D.Adapters.Compiler in 'Adapters/Compiler/Boss4D.Adapters.Compiler.pas',
  Boss4D.Adapters.Sbom.CycloneDX in 'Adapters/Sbom/Boss4D.Adapters.Sbom.CycloneDX.pas',
  Boss4D.Adapters.Sbom.Collectors in 'Adapters/Sbom/Boss4D.Adapters.Sbom.Collectors.pas',
  Boss4D.Adapters.Sbom.Spdx in 'Adapters/Sbom/Boss4D.Adapters.Sbom.Spdx.pas',
  Boss4D.Adapters.Sbom.Security in 'Adapters/Sbom/Boss4D.Adapters.Sbom.Security.pas',
  Boss4D.Core.Services.Init in 'Core/Services/Boss4D.Core.Services.Init.pas',
  Boss4D.Core.Services.Config in 'Core/Services/Boss4D.Core.Services.Config.pas',
  Boss4D.Core.Services.Install in 'Core/Services/Boss4D.Core.Services.Install.pas',
  Boss4D.Core.Services.SelfUpdate in 'Core/Services/Boss4D.Core.Services.SelfUpdate.pas',
  Boss4D.Core.Services.Pack in 'Core/Services/Boss4D.Core.Services.Pack.pas',
  Boss4D.Core.Services.Resolver in 'Core/Services/Boss4D.Core.Services.Resolver.pas',
  Boss4D.Core.Services.Conformance in 'Core/Services/Boss4D.Core.Services.Conformance.pas',
  Boss4D.Core.Services.RegistryPortal in 'Core/Services/Boss4D.Core.Services.RegistryPortal.pas',
  Boss4D.Core.Services.Progress in 'Core/Services/Boss4D.Core.Services.Progress.pas',
  Boss4D.Core.Services.Transaction in 'Core/Services/Boss4D.Core.Services.Transaction.pas',
  Boss4D.Core.Services.Dependencies in 'Core/Services/Boss4D.Core.Services.Dependencies.pas',
  Boss4D.Core.Services.Audit in 'Core/Services/Boss4D.Core.Services.Audit.pas',
  Boss4D.Core.Services.PackageIndex in 'Core/Services/Boss4D.Core.Services.PackageIndex.pas',
  Boss4D.Core.Services.DependencySubmission in 'Core/Services/Boss4D.Core.Services.DependencySubmission.pas',
  Boss4D.Core.Services.Publish in 'Core/Services/Boss4D.Core.Services.Publish.pas',
  Boss4D.Core.Services.ArtifactCache in 'Core/Services/Boss4D.Core.Services.ArtifactCache.pas',
  Boss4D.Core.Services.BuildMatrix in 'Core/Services/Boss4D.Core.Services.BuildMatrix.pas',
  Boss4D.Core.Services.BuildPaths in 'Core/Services/Boss4D.Core.Services.BuildPaths.pas',
  Boss4D.Core.Services.BuildExecutor in 'Core/Services/Boss4D.Core.Services.BuildExecutor.pas',
  Boss4D.Core.Services.BuildGraph in 'Core/Services/Boss4D.Core.Services.BuildGraph.pas',
  Boss4D.Core.Services.BuildState in 'Core/Services/Boss4D.Core.Services.BuildState.pas',
  Boss4D.Core.Services.BuildScheduler in 'Core/Services/Boss4D.Core.Services.BuildScheduler.pas',
  Boss4D.Core.Services.PackageInstall in 'Core/Services/Boss4D.Core.Services.PackageInstall.pas',
  Boss4D.Core.Services.Cache in 'Core/Services/Boss4D.Core.Services.Cache.pas',
  Boss4D.Core.Services.Run in 'Core/Services/Boss4D.Core.Services.Run.pas',
  Boss4D.Core.Services.Doctor in 'Core/Services/Boss4D.Core.Services.Doctor.pas',
  Boss4D.Core.Services.License in 'Core/Services/Boss4D.Core.Services.License.pas',
  Boss4D.Core.Services.Tree in 'Core/Services/Boss4D.Core.Services.Tree.pas',
  Boss4D.Core.Services.Outdated in 'Core/Services/Boss4D.Core.Services.Outdated.pas',
  Boss4D.Core.Services.IDEIntegration in 'Core/Services/Boss4D.Core.Services.IDEIntegration.pas',
  Boss4D.Core.Services.Tool in 'Core/Services/Boss4D.Core.Services.Tool.pas',
  Boss4D.Core.Services.Workspace in 'Core/Services/Boss4D.Core.Services.Workspace.pas',
  Boss4D.Core.Services.GetIt in 'Core/Services/Boss4D.Core.Services.GetIt.pas',
  Boss4D.Core.Services.Clean in 'Core/Services/Boss4D.Core.Services.Clean.pas',
  Boss4D.Core.Services.Sbom in 'Core/Services/Boss4D.Core.Services.Sbom.pas',
  Boss4D.Core.Services.Scaffold in 'Core/Services/Boss4D.Core.Services.Scaffold.pas',
  Boss4D.Core.Services.SourceNormalizer in 'Core/Services/Boss4D.Core.Services.SourceNormalizer.pas',
  Boss4D.Core.Services.PackageManifest in 'Core/Services/Boss4D.Core.Services.PackageManifest.pas',
  Boss4D.Core.Services.LazarusProject in 'Core/Services/Boss4D.Core.Services.LazarusProject.pas',
  Boss4D.CLI.Parser in 'CLI/Boss4D.CLI.Parser.pas';

var
  LArgs: TArray<string>;
  I: Integer;

  // Adaptadores (Interfaces - Ciclo de vida gerido por contagem de referencias)
  LLogger: IBoss4DLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitClient: IBoss4DGitClient;
  LHttpClient: IBoss4DHttpClient;
  LRegistry: IBoss4DRegistryService;
  LCompiler: IBoss4DCompiler;
  LCredentialStore: IBoss4DCredentialStore;

  // Servicos
  LInitService: TBoss4DInitService;
  LInstallService: TBoss4DInstallService;
  LConfigService: TBoss4DConfigService;

  // Parser
  LParser: TBoss4DCommandLineParser;
begin
  ConfigureWindowsPlatform;
  SetConsoleOutputCP(CP_UTF8);
  SetConsoleCP(CP_UTF8);
  try
    // Captura os argumentos do terminal
    SetLength(LArgs, ParamCount);
    for I := 1 to ParamCount do
      LArgs[I - 1] := ParamStr(I);

    // Inicializa adaptadores de infraestrutura concretos
    LLogger := TBoss4DConsoleLoggerAdapter.Create;
    LPackageRepo := TBoss4DPackageJsonRepository.Create;
    LLockRepo := TBoss4DLockJsonRepository.Create;
    LHttpClient := TBoss4DHttpNativeAdapter.Create;
    LRegistry := TBoss4DWindowsRegistryAdapter.Create;
    LCredentialStore := TBoss4DWindowsCredentialStore.Create;
    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, LLogger);

    // Carrega configuracoes globais para instanciar o Git Client
    LConfigService := TBoss4DConfigService.Create(LLogger, LCredentialStore);
    var LGlobalConfig := LConfigService.Load;
    try
      LGitClient := TBoss4DGitCliAdapter.Create(LGlobalConfig.GitShallow,
        LCredentialStore);
    finally
      LGlobalConfig.Free;
    end;

    // Inicializa os servicos de negocio
    LInitService := TBoss4DInitService.Create(LPackageRepo, LLogger);
    LInstallService := TBoss4DInstallService.Create(
      LPackageRepo, LLockRepo, LGitClient, LHttpClient, LCompiler, LLogger);
    LInstallService.SetProgressOutput(TBoss4DConsoleProgressOutput.Create);

    // Inicializa o Parser de CLI
    LParser := TBoss4DCommandLineParser.Create(LLogger, LInitService, LInstallService, LConfigService, LPackageRepo, LRegistry);
    try
      LParser.ParseAndExecute(LArgs);
    finally
      LParser.Free;
      LInstallService.Free;
      LInitService.Free;
      LConfigService.Free;
    end;

  except
    on E: EAggregateException do
    begin
      System.ExitCode := 1;
      Writeln(ErrOutput, 'Erro fatal do Boss4D: ' + E.Message);
      for var LIdx := 0 to E.Count - 1 do
        Writeln(ErrOutput, '  -> ' + E[LIdx].Message);
    end;
    on E: Exception do
    begin
      System.ExitCode := 1;
      Writeln(ErrOutput, 'Erro fatal do Boss4D: ' + E.Message);
    end;
  end;
end.
