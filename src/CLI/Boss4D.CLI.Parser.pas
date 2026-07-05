unit Boss4D.CLI.Parser;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Install, Boss4D.Core.Services.Config,
  Boss4D.Core.Services.Cache, Boss4D.Core.Services.Run,
  Boss4D.Core.Services.Doctor, Boss4D.Core.Services.License,
  Boss4D.Core.Services.Tree, Boss4D.Core.Services.Outdated,
  Boss4D.Core.Services.Tool, Boss4D.Core.Services.IDEIntegration;

type
  { Interpretador e orquestrador de comandos da linha de comando (CLI) }
  TBoss4DCommandLineParser = class
  private
    FLogger: IBoss4DLogger;
    FInitService: TBoss4DInitService;
    FInstallService: TBoss4DInstallService;
    FConfigService: TBoss4DConfigService;
    FPackageRepo: IBoss4DPackageRepository;
    FRegistry: IBoss4DRegistryService;

    procedure ShowHelp;
    procedure ShowVersion;
    procedure HandleInit(const AArgs: TArray<string>);
    procedure HandleInstall(const AArgs: TArray<string>);
    procedure HandleConfig(const AArgs: TArray<string>);
    procedure HandleCache(const AArgs: TArray<string>);
    procedure HandleRun(const AArgs: TArray<string>);
    procedure HandleDoctor(const AArgs: TArray<string>);
    procedure HandleLicense(const AArgs: TArray<string>);
    procedure HandleTree(const AArgs: TArray<string>);
    procedure HandleOutdated(const AArgs: TArray<string>);
    procedure HandleTool(const AArgs: TArray<string>);
    procedure HandlePlugin(const AArgs: TArray<string>);
  public
    constructor Create(
      const ALogger: IBoss4DLogger;
      const AInitService: TBoss4DInitService;
      const AInstallService: TBoss4DInstallService;
      const AConfigService: TBoss4DConfigService;
      const APackageRepo: IBoss4DPackageRepository;
      const ARegistry: IBoss4DRegistryService
    );

    procedure ParseAndExecute(const AArgs: TArray<string>);
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Adapters.Json,
  Boss4D.Adapters.Git,
  Boss4D.Adapters.Compiler,
  Boss4D.Adapters.Registry,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Env;

{ TBoss4DCommandLineParser }

constructor TBoss4DCommandLineParser.Create(
  const ALogger: IBoss4DLogger;
  const AInitService: TBoss4DInitService;
  const AInstallService: TBoss4DInstallService;
  const AConfigService: TBoss4DConfigService;
  const APackageRepo: IBoss4DPackageRepository;
  const ARegistry: IBoss4DRegistryService
);
begin
  inherited Create;
  FLogger := ALogger;
  FInitService := AInitService;
  FInstallService := AInstallService;
  FConfigService := AConfigService;
  FPackageRepo := APackageRepo;
  FRegistry := ARegistry;
end;

procedure TBoss4DCommandLineParser.ShowHelp;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'Boss4D - Gerenciador de Dependencias Delphi Nativo (v1.0.0)');
  FLogger.Log(TBoss4DLogLevel.Info, '');
  FLogger.Log(TBoss4DLogLevel.Info, 'Uso:');
  FLogger.Log(TBoss4DLogLevel.Info, '  boss4d [comando] [argumentos] [flags]');
  FLogger.Log(TBoss4DLogLevel.Info, '');
  FLogger.Log(TBoss4DLogLevel.Info, 'Comandos Disponiveis:');
  FLogger.Log(TBoss4DLogLevel.Info, '  init                 Inicializa um novo arquivo boss.json no diretorio atual.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -q, --quiet (modo silencioso).');
  FLogger.Log(TBoss4DLogLevel.Info, '  install              Instala todas as dependencias declaradas no boss.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -p, --platform <plataforma> (Win32, Win64, Linux64, etc.).');
  FLogger.Log(TBoss4DLogLevel.Info, '  install <dep>        Instala uma dependencia especifica.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Exemplo: boss4d install github.com/hashload/horse@^3.0.0');
  FLogger.Log(TBoss4DLogLevel.Info, '  config delphi use <caminho>  Configura o caminho global do compilador Delphi.');
  FLogger.Log(TBoss4DLogLevel.Info, '  config git shallow <true/false> Configura uso de shallow clones globais.');
  FLogger.Log(TBoss4DLogLevel.Info, '  config auth <github/gitlab> <token> Configura tokens de autenticacao global.');
  FLogger.Log(TBoss4DLogLevel.Info, '  cache                Gerenciamento do cache global do Git.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Subcomandos: size, clean, prune.');
  FLogger.Log(TBoss4DLogLevel.Info, '  run <script>         Executa um script customizado definido no boss.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '  doctor               Executa diagnosticos do ambiente de compilacao.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -fix, --fix (tenta auto-configurar a versao delphi).');
  FLogger.Log(TBoss4DLogLevel.Info, '  license report       Gera relatorios de conformidade de licencas em docs/.');
  FLogger.Log(TBoss4DLogLevel.Info, '  tree                 Exibe a arvore de dependencias do projeto.');
  FLogger.Log(TBoss4DLogLevel.Info, '  outdated             Verifica se ha atualizacoes disponiveis dos pacotes.');
  FLogger.Log(TBoss4DLogLevel.Info, '  tool install -g <repo> Compila e instala um utilitario Delphi globalmente.');
  FLogger.Log(TBoss4DLogLevel.Info, '  version, -v, --version Exibe a versao atual do Boss4D.');
  FLogger.Log(TBoss4DLogLevel.Info, '  help, -h, --help     Exibe este menu de ajuda.');
  FLogger.Log(TBoss4DLogLevel.Info, '');
end;

procedure TBoss4DCommandLineParser.ShowVersion;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'v1.0.0-delphi-native');
end;

procedure TBoss4DCommandLineParser.ParseAndExecute(const AArgs: TArray<string>);
begin
  if Length(AArgs) = 0 then
  begin
    ShowHelp;
    Exit;
  end;

  var LCommand := AArgs[0].ToLower;

  if (LCommand = 'help') or (LCommand = '-h') or (LCommand = '--help') then
    ShowHelp
  else if (LCommand = 'version') or (LCommand = '-v') or (LCommand = '--version') then
    ShowVersion
  else if LCommand = 'init' then
    HandleInit(AArgs)
  else if (LCommand = 'install') or (LCommand = 'i') then
    HandleInstall(AArgs)
  else if LCommand = 'config' then
    HandleConfig(AArgs)
  else if LCommand = 'cache' then
    HandleCache(AArgs)
  else if LCommand = 'run' then
    HandleRun(AArgs)
  else if LCommand = 'doctor' then
    HandleDoctor(AArgs)
  else if LCommand = 'license' then
    HandleLicense(AArgs)
  else if LCommand = 'tree' then
    HandleTree(AArgs)
  else if LCommand = 'outdated' then
    HandleOutdated(AArgs)
  else if LCommand = 'tool' then
    HandleTool(AArgs)
  else if LCommand = 'plugin' then
    HandlePlugin(AArgs);
end;

procedure TBoss4DCommandLineParser.HandleInit(const AArgs: TArray<string>);
var
  LQuiet: Boolean;
begin
  LQuiet := False;
  for var I := 1 to Length(AArgs) - 1 do
  begin
    if (AArgs[I] = '-q') or (AArgs[I] = '--quiet') then
      LQuiet := True;
  end;
  FInitService.Execute(LQuiet);
end;

procedure TBoss4DCommandLineParser.HandleInstall(const AArgs: TArray<string>);
var
  LDepToInstall: string;
  LPlatform: string;
  I: Integer;
begin
  LDepToInstall := '';
  LPlatform := '';

  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--platform') or SameText(AArgs[I], '-p') then
    begin
      if I + 1 < Length(AArgs) then
      begin
        LPlatform := AArgs[I + 1];
        Inc(I, 2);
      end
      else
        Inc(I);
    end
    else
    begin
      if not AArgs[I].StartsWith('-') then
        LDepToInstall := AArgs[I];
      Inc(I);
    end;
  end;

  FInstallService.Execute(LDepToInstall, LPlatform);
end;

procedure TBoss4DCommandLineParser.HandleConfig(const AArgs: TArray<string>);
begin
  if (Length(AArgs) >= 4) and SameText(AArgs[1], 'delphi') and SameText(AArgs[2], 'use') then
  begin
    var LConfig := FConfigService.Load;
    try
      LConfig.DelphiPath := AArgs[3];
      FConfigService.Save(LConfig);
      FLogger.Log(TBoss4DLogLevel.Info, '✅ Caminho do Delphi atualizado para: %s', [LConfig.DelphiPath]);
    finally
      LConfig.Free;
    end;
  end
  else if (Length(AArgs) >= 4) and SameText(AArgs[1], 'git') and SameText(AArgs[2], 'shallow') then
  begin
    var LConfig := FConfigService.Load;
    try
      LConfig.GitShallow := SameText(AArgs[3], 'true') or (AArgs[3] = '1');
      FConfigService.Save(LConfig);
      FLogger.Log(TBoss4DLogLevel.Info,
        '✅ Configuracao git shallow definida para: %s',
        [BoolToStr(LConfig.GitShallow, True)]);
    finally
      LConfig.Free;
    end;
  end
  else if (Length(AArgs) >= 4) and SameText(AArgs[1], 'auth') then
  begin
    var LConfig := FConfigService.Load;
    try
      if SameText(AArgs[2], 'github') then
      begin
        LConfig.GitHubToken := AArgs[3];
        FConfigService.Save(LConfig);
        FLogger.Log(TBoss4DLogLevel.Info, '✅ Token de autenticacao do GitHub configurado com sucesso.');
      end
      else if SameText(AArgs[2], 'gitlab') then
      begin
        LConfig.GitLabToken := AArgs[3];
        FConfigService.Save(LConfig);
        FLogger.Log(TBoss4DLogLevel.Info, '✅ Token de autenticacao do GitLab configurado com sucesso.');
      end
      else
      begin
        FLogger.Log(TBoss4DLogLevel.Warning, 'Provedor de autenticacao "%s" desconhecido. Use github ou gitlab.', [AArgs[2]]);
      end;
    finally
      LConfig.Free;
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando config.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Comandos aceitos:');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d config delphi use <caminho>');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d config git shallow <true/false>');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d config auth <github/gitlab> <token>');
  end;
end;

procedure TBoss4DCommandLineParser.HandleCache(const AArgs: TArray<string>);
var
  LCacheService: TBoss4DCacheService;
  LSubCommand: string;
begin
  if Length(AArgs) < 2 then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando cache.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Comandos aceitos:');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d cache size      Exibe o tamanho em disco do cache global.');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d cache clean     Limpa todo o cache global.');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d cache prune     Remove caches obsoletos (mais de 30 dias).');
    Exit;
  end;

  LSubCommand := AArgs[1].ToLower;
  LCacheService := TBoss4DCacheService.Create(FLogger);
  try
    if LSubCommand = 'size' then
      FLogger.Log(TBoss4DLogLevel.Info, 'Tamanho do cache global: ' + LCacheService.GetFormattedSize)
    else if LSubCommand = 'clean' then
      LCacheService.Clean
    else if LSubCommand = 'prune' then
      LCacheService.Prune(30)
    else
      FLogger.Log(TBoss4DLogLevel.Warning, 'Subcomando "%s" invalido para o comando cache.', [LSubCommand]);
  finally
    LCacheService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleRun(const AArgs: TArray<string>);
var
  LRunService: TBoss4DRunService;
begin
  if Length(AArgs) < 2 then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Defina o nome do script a ser executado.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Uso: boss4d run <nome_do_script>');
    Exit;
  end;

  LRunService := TBoss4DRunService.Create(FPackageRepo, FLogger);
  try
    LRunService.Execute(AArgs[1]);
  finally
    LRunService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleDoctor(const AArgs: TArray<string>);
var
  LDoctorService: TBoss4DDoctorService;
  LFix: Boolean;
begin
  LFix := False;
  if (Length(AArgs) > 1) and ((AArgs[1] = '-fix') or (AArgs[1] = '--fix')) then
    LFix := True;

  LDoctorService := TBoss4DDoctorService.Create(FRegistry, FLogger);
  try
    LDoctorService.Check(LFix);
  finally
    LDoctorService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleLicense(const AArgs: TArray<string>);
var
  LLicenseService: TBoss4DLicenseService;
begin
  if (Length(AArgs) < 2) or not SameText(AArgs[1], 'report') then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando license.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Uso: boss4d license report');
    Exit;
  end;

  LLicenseService := TBoss4DLicenseService.Create(FPackageRepo, FLogger);
  try
    LLicenseService.GenerateReport;
  finally
    LLicenseService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleTree(const AArgs: TArray<string>);
var
  LTreeService: TBoss4DTreeService;
begin
  LTreeService := TBoss4DTreeService.Create(FPackageRepo, FLogger);
  try
    LTreeService.GenerateTree;
  finally
    LTreeService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleTool(const AArgs: TArray<string>);
var
  LToolService: TBoss4DToolService;
  LGitClient: IBoss4DGitClient;
  LCompiler: IBoss4DCompiler;
  LRegistry: IBoss4DRegistryService;
begin
  if (Length(AArgs) >= 4) and SameText(AArgs[1], 'install') and SameText(AArgs[2], '-g') then
  begin
    LGitClient := TBoss4DGitCliAdapter.Create(False);
    LRegistry := TBoss4DWindowsRegistryAdapter.Create;
    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, FLogger);
    LToolService := TBoss4DToolService.Create(LGitClient, LCompiler, FLogger);
    try
      LToolService.InstallGlobalTool(AArgs[3]);
    finally
      LToolService.Free;
    end;
  end
  else if (Length(AArgs) >= 4) and SameText(AArgs[1], 'update') then
  begin
    LGitClient := TBoss4DGitCliAdapter.Create(False);
    LRegistry := TBoss4DWindowsRegistryAdapter.Create;
    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, FLogger);
    LToolService := TBoss4DToolService.Create(LGitClient, LCompiler, FLogger);
    try
      LToolService.UpdateGlobalTool(AArgs[2], AArgs[3]);
    finally
      LToolService.Free;
    end;
  end
  else if (Length(AArgs) >= 3) and SameText(AArgs[1], 'uninstall') then
  begin
    LGitClient := TBoss4DGitCliAdapter.Create(False);
    LRegistry := TBoss4DWindowsRegistryAdapter.Create;
    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, FLogger);
    LToolService := TBoss4DToolService.Create(LGitClient, LCompiler, FLogger);
    try
      LToolService.UninstallGlobalTool(AArgs[2]);
    finally
      LToolService.Free;
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando tool.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Comandos aceitos:');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d tool install -g <repositorio>');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d tool update <ferramenta> <repositorio>');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d tool uninstall <ferramenta>');
  end;
end;

procedure TBoss4DCommandLineParser.HandleOutdated(const AArgs: TArray<string>);
var
  LOutdatedService: TBoss4DOutdatedService;
  LLockRepo: IBoss4DLockRepository;
  LGitClient: IBoss4DGitClient;
begin
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitClient := TBoss4DGitCliAdapter.Create(False);
  LOutdatedService := TBoss4DOutdatedService.Create(FPackageRepo, LLockRepo, LGitClient, FLogger);
  try
    LOutdatedService.CheckOutdated;
  finally
    LOutdatedService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandlePlugin(const AArgs: TArray<string>);
var
  LGitClient: IBoss4DGitClient;
  LCompiler: IBoss4DCompiler;
  LRegistry: IBoss4DRegistryService;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LDep: TBoss4DDependency;
  LTempCloneDir: string;
  LPluginsDir: string;
  LFiles: TArray<string>;
  LBPLFiles: TArray<string>;
  LLock: TBoss4DLock;
  LPluginName: string;
  LDestBPL: string;
begin
  if (Length(AArgs) < 3) or not SameText(AArgs[1], 'install') then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando plugin.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Uso: boss4d plugin install <repositorio>');
    Exit;
  end;

  FLogger.Log(TBoss4DLogLevel.Info, 'Iniciando instalacao de plugin de IDE: %s', [AArgs[2]]);

  LGitClient := TBoss4DGitCliAdapter.Create(False);
  LRegistry := TBoss4DWindowsRegistryAdapter.Create;
  LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, FLogger);
  LIDEIntegration := TBoss4DIDEIntegrationService.Create(LRegistry, FLogger);
  
  LDep := TBoss4DDependency.Create(AArgs[2], '*');
  LLock := TBoss4DLock.Create;
  LTempCloneDir := TPath.Combine(TPath.Combine(GetBossHome, 'temp_plugins'), LDep.Name);
  LPluginsDir := TPath.Combine(TPath.Combine(GetEnvironmentVariable('APPDATA'), 'Boss4D'), 'plugins');
  try
    if TDirectory.Exists(LTempCloneDir) then
      TDirectory.Delete(LTempCloneDir, True);

    TDirectory.CreateDirectory(LTempCloneDir);

    FLogger.Log(TBoss4DLogLevel.Info, '  Clonando fontes do plugin...');
    LGitClient.CloneCache(LDep, LTempCloneDir);

    LFiles := TDirectory.GetFiles(LTempCloneDir, '*.dproj', TSearchOption.soAllDirectories);
    if Length(LFiles) = 0 then
      raise Exception.Create('Nenhum projeto Delphi (.dproj) encontrado no repositorio do plugin.');

    FLogger.Log(TBoss4DLogLevel.Info, '  Compilando plugin...');
    if not LCompiler.Compile(LFiles[0], LDep, LLock) then
      raise Exception.Create('Falha na compilacao do plugin.');

    LBPLFiles := TDirectory.GetFiles(LTempCloneDir, '*.bpl', TSearchOption.soAllDirectories);
    if Length(LBPLFiles) = 0 then
      raise Exception.Create('Arquivo BPL compilado nao foi localizado na pasta de build.');

    if not TDirectory.Exists(LPluginsDir) then
      TDirectory.CreateDirectory(LPluginsDir);

    LPluginName := TPath.GetFileNameWithoutExtension(LFiles[0]);
    LDestBPL := TPath.Combine(LPluginsDir, LPluginName + '.bpl');

    TFile.Copy(LBPLFiles[0], LDestBPL, True);

    FLogger.Log(TBoss4DLogLevel.Info, '  Registrando plugin no RAD Studio...');
    LIDEIntegration.RegisterIDEPackage(LDestBPL, LPluginName + ' - IDE Extension');

    FLogger.Log(TBoss4DLogLevel.Info, '🚀 Plugin "%s" instalado e registrado com sucesso!', [LPluginName]);
  finally
    if TDirectory.Exists(LTempCloneDir) then
      TDirectory.Delete(LTempCloneDir, True);
    LLock.Free;
    LDep.Free;
    LIDEIntegration.Free;
  end;
end;

end.
