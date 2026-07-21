program Boss4D;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Threading,
  Winapi.Windows,
  Boss4D.Core.Ports in 'Core/Ports/Boss4D.Core.Ports.pas',
  Boss4D.Core.Domain.Consts in 'Core/Domain/Boss4D.Core.Domain.Consts.pas',
  Boss4D.Core.Domain.Env in 'Core/Domain/Boss4D.Core.Domain.Env.pas',
  Boss4D.Core.Domain.SemVer in 'Core/Domain/Boss4D.Core.Domain.SemVer.pas',
  Boss4D.Core.Domain.Dependency in 'Core/Domain/Boss4D.Core.Domain.Dependency.pas',
  Boss4D.Core.Domain.Package in 'Core/Domain/Boss4D.Core.Domain.Package.pas',
  Boss4D.Core.Domain.Lock in 'Core/Domain/Boss4D.Core.Domain.Lock.pas',
  Boss4D.Core.Domain.Sbom in 'Core/Domain/Boss4D.Core.Domain.Sbom.pas',
  Boss4D.Core.Domain.License in 'Core/Domain/Boss4D.Core.Domain.License.pas',
  Boss4D.Adapters.Json in 'Adapters/Json/Boss4D.Adapters.Json.pas',
  Boss4D.Adapters.Logger in 'Adapters/Logger/Boss4D.Adapters.Logger.pas',
  Boss4D.Adapters.Http in 'Adapters/Http/Boss4D.Adapters.Http.pas',
  Boss4D.Adapters.Git in 'Adapters/Git/Boss4D.Adapters.Git.pas',
  Boss4D.Adapters.Registry in 'Adapters/Registry/Boss4D.Adapters.Registry.pas',
  Boss4D.Adapters.Compiler in 'Adapters/Compiler/Boss4D.Adapters.Compiler.pas',
  Boss4D.Adapters.Sbom.CycloneDX in 'Adapters/Sbom/Boss4D.Adapters.Sbom.CycloneDX.pas',
  Boss4D.Adapters.Sbom.Collectors in 'Adapters/Sbom/Boss4D.Adapters.Sbom.Collectors.pas',
  Boss4D.Adapters.Sbom.Spdx in 'Adapters/Sbom/Boss4D.Adapters.Sbom.Spdx.pas',
  Boss4D.Core.Services.Init in 'Core/Services/Boss4D.Core.Services.Init.pas',
  Boss4D.Core.Services.Config in 'Core/Services/Boss4D.Core.Services.Config.pas',
  Boss4D.Core.Services.Install in 'Core/Services/Boss4D.Core.Services.Install.pas',
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

  // Servicos
  LInitService: TBoss4DInitService;
  LInstallService: TBoss4DInstallService;
  LConfigService: TBoss4DConfigService;

  // Parser
  LParser: TBoss4DCommandLineParser;
begin
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
    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, LLogger);

    // Carrega configuracoes globais para instanciar o Git Client
    LConfigService := TBoss4DConfigService.Create(LLogger);
    var LGlobalConfig := LConfigService.Load;
    try
      LGitClient := TBoss4DGitCliAdapter.Create(LGlobalConfig.GitShallow);
    finally
      LGlobalConfig.Free;
    end;

    // Inicializa os servicos de negocio
    LInitService := TBoss4DInitService.Create(LPackageRepo, LLogger);
    LInstallService := TBoss4DInstallService.Create(
      LPackageRepo, LLockRepo, LGitClient, LHttpClient, LCompiler, LLogger);

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
