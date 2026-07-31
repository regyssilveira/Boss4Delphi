unit Boss4D.CLI.Parser;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Install, Boss4D.Core.Services.Config,
  Boss4D.Core.Services.Cache, Boss4D.Core.Services.Run,
  Boss4D.Core.Services.Doctor, Boss4D.Core.Services.License,
  Boss4D.Core.Services.Tree, Boss4D.Core.Services.Outdated,
  Boss4D.Core.Services.Tool, Boss4D.Core.Services.IDEIntegration,
  Boss4D.Core.Services.GetIt, Boss4D.Core.Services.Clean,
  Boss4D.Core.Services.Sbom, Boss4D.Core.Services.Scaffold,
  Boss4D.Core.Services.BuildCommand, Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.BuildCoordinator, Boss4D.Core.Services.IDEDiscovery;


type
  TBoss4DIDEUnregisterHandler = reference to function(
    const APackageName, ACompiler, APlatform: string): Integer;
  TBoss4DIDERepairHandler = reference to function: Integer;
  TBoss4DIDEUninstallHandler = reference to function(
    const AOwnerPackage: string): Integer;

  TBoss4DParserRuntime = record
  private
    FCompiler: IBoss4DCompiler;
    FRegistrationHandler: TBoss4DIDERegistrationHandler;
    FUnregisterHandler: TBoss4DIDEUnregisterHandler;
    FRepairHandler: TBoss4DIDERepairHandler;
    FUninstallHandler: TBoss4DIDEUninstallHandler;
  public
    class function Create(const ACompiler: IBoss4DCompiler;
      const ARegistrationHandler: TBoss4DIDERegistrationHandler;
      const AUnregisterHandler: TBoss4DIDEUnregisterHandler;
      const ARepairHandler: TBoss4DIDERepairHandler;
      const AUninstallHandler: TBoss4DIDEUninstallHandler = nil):
      TBoss4DParserRuntime;
      static;
    property Compiler: IBoss4DCompiler read FCompiler;
    property RegistrationHandler: TBoss4DIDERegistrationHandler
      read FRegistrationHandler;
    property UnregisterHandler: TBoss4DIDEUnregisterHandler
      read FUnregisterHandler;
    property RepairHandler: TBoss4DIDERepairHandler read FRepairHandler;
    property UninstallHandler: TBoss4DIDEUninstallHandler
      read FUninstallHandler;
  end;

  TBoss4DSbomCommandOptions = record
    Options: TBoss4DSbomOptions;
    OutputPath: string;
    Format: string;
    IncludeGetIt: Boolean;
    IncludeToolchain: Boolean;
    IncludeArtifacts: Boolean;
    VexPath: string;
    AttestationOutput: string;
    VerifyAttestation: string;
  end;

  { Interpretador e orquestrador de comandos da linha de comando (CLI) }
  TBoss4DCommandLineParser = class
  private
    FLogger: IBoss4DLogger;
    FInitService: TBoss4DInitService;
    FInstallService: TBoss4DInstallService;
    FConfigService: TBoss4DConfigService;
    FPackageRepo: IBoss4DPackageRepository;
    FRegistry: IBoss4DRegistryService;
    FCompiler: IBoss4DCompiler;
    FRegistrationHandler: TBoss4DIDERegistrationHandler;
    FUnregisterHandler: TBoss4DIDEUnregisterHandler;
    FRepairHandler: TBoss4DIDERepairHandler;
    FUninstallHandler: TBoss4DIDEUninstallHandler;

    procedure ShowHelp;
    procedure ShowVersion;
    procedure HandleInit(const AArgs: TArray<string>);
    procedure HandleInstall(const AArgs: TArray<string>);
    procedure HandleCI(const AArgs: TArray<string>);
    procedure HandleAdd(const AArgs: TArray<string>);
    procedure HandleRemove(const AArgs: TArray<string>);
    procedure HandleUpdate(const AArgs: TArray<string>);
    procedure HandleList;
    procedure HandleWhy(const AArgs: TArray<string>);
    procedure HandleAudit(const AArgs: TArray<string>);
    procedure HandleRegistry(const AArgs: TArray<string>);
    procedure HandleSearch(const AArgs: TArray<string>);
    procedure HandleInfo(const AArgs: TArray<string>);
    procedure HandlePackage(const AArgs: TArray<string>);
    procedure HandleDependency(const AArgs: TArray<string>);
    procedure HandlePublish(const AArgs: TArray<string>);
    procedure HandleConfig(const AArgs: TArray<string>);
    procedure HandleCache(const AArgs: TArray<string>);
    procedure HandleRun(const AArgs: TArray<string>);
    procedure HandleDoctor(const AArgs: TArray<string>);
    procedure HandleLicense(const AArgs: TArray<string>);
    procedure HandleTree(const AArgs: TArray<string>);
    procedure HandleOutdated(const AArgs: TArray<string>);
    procedure HandleTool(const AArgs: TArray<string>);
    procedure HandlePlugin(const AArgs: TArray<string>);
    procedure HandleGetIt(const AArgs: TArray<string>);
    procedure HandleClean(const AArgs: TArray<string>);
    procedure HandleNew(const AArgs: TArray<string>);
    procedure HandleSelfUpdate;
    procedure HandlePack(const AArgs: TArray<string>);
    procedure HandleConformance(const AArgs: TArray<string>);
    procedure HandleSpec(const AArgs: TArray<string>);
    procedure HandleBuild(const AArgs: TArray<string>);
    procedure HandleSupport(const AArgs: TArray<string>);
    procedure HandleIDEUninstall(const AArgs: TArray<string>);
    procedure HandleIDEProfile(const AArgs: TArray<string>);
    procedure HandleIDE(const AArgs: TArray<string>);
    function ParseSbomArguments(
      const AArgs: TArray<string>): TBoss4DSbomCommandOptions;
    procedure HandleSbom(const AArgs: TArray<string>);
  public
    constructor Create(
      const ALogger: IBoss4DLogger;
      const AInitService: TBoss4DInitService;
      const AInstallService: TBoss4DInstallService;
      const AConfigService: TBoss4DConfigService;
      const APackageRepo: IBoss4DPackageRepository;
      const ARegistry: IBoss4DRegistryService); overload;
    constructor Create(
      const ALogger: IBoss4DLogger;
      const AInitService: TBoss4DInitService;
      const AInstallService: TBoss4DInstallService;
      const AConfigService: TBoss4DConfigService;
      const APackageRepo: IBoss4DPackageRepository;
      const ARegistry: IBoss4DRegistryService;
      const ARuntime: TBoss4DParserRuntime); overload;

    procedure ParseAndExecute(const AArgs: TArray<string>);
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  System.Generics.Collections,
  Boss4D.Adapters.Json,
  Boss4D.Adapters.Http,
  Boss4D.Adapters.Git,
  Boss4D.Adapters.Compiler,
  Boss4D.Adapters.Registry,
  Boss4D.Adapters.Sbom.CycloneDX,
  Boss4D.Adapters.Sbom.Collectors,
  Boss4D.Adapters.Sbom.Spdx,
  Boss4D.Adapters.Sbom.Security,
  Boss4D.Adapters.Security.Gpg,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Sbom,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Core.Platform,
  Boss4D.Core.Services.Dependencies,
  Boss4D.Core.Services.Audit,
  Boss4D.Core.Services.PackageIndex,
  Boss4D.Core.Services.DependencySubmission,
  Boss4D.Core.Services.Publish,
  Boss4D.Core.Services.SelfUpdate,
  Boss4D.Core.Services.Pack,
  Boss4D.Core.Services.Resolver,
  Boss4D.Core.Services.Conformance,
  Boss4D.Core.Services.RegistryPortal,
  Boss4D.Core.Services.PackageInstall,
  Boss4D.Core.Services.BuildSpec,
  Boss4D.Core.Services.BuildConventions,
  Boss4D.Core.Services.BuildCapabilities,
  Boss4D.Core.Services.BuildDoctor,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProfiles;

class function TBoss4DParserRuntime.Create(const ACompiler: IBoss4DCompiler;
  const ARegistrationHandler: TBoss4DIDERegistrationHandler;
  const AUnregisterHandler: TBoss4DIDEUnregisterHandler;
  const ARepairHandler: TBoss4DIDERepairHandler;
  const AUninstallHandler: TBoss4DIDEUninstallHandler):
  TBoss4DParserRuntime;
begin
  Result := Default(TBoss4DParserRuntime);
  Result.FCompiler := ACompiler;
  Result.FRegistrationHandler := ARegistrationHandler;
  Result.FUnregisterHandler := AUnregisterHandler;
  Result.FRepairHandler := ARepairHandler;
  Result.FUninstallHandler := AUninstallHandler;
end;

constructor TBoss4DCommandLineParser.Create(
  const ALogger: IBoss4DLogger;
  const AInitService: TBoss4DInitService;
  const AInstallService: TBoss4DInstallService;
  const AConfigService: TBoss4DConfigService;
  const APackageRepo: IBoss4DPackageRepository;
  const ARegistry: IBoss4DRegistryService);
begin
  inherited Create;
  FLogger := ALogger;
  FInitService := AInitService;
  FInstallService := AInstallService;
  FConfigService := AConfigService;
  FPackageRepo := APackageRepo;
  FRegistry := ARegistry;
end;

constructor TBoss4DCommandLineParser.Create(
  const ALogger: IBoss4DLogger;
  const AInitService: TBoss4DInitService;
  const AInstallService: TBoss4DInstallService;
  const AConfigService: TBoss4DConfigService;
  const APackageRepo: IBoss4DPackageRepository;
  const ARegistry: IBoss4DRegistryService;
  const ARuntime: TBoss4DParserRuntime
);
begin
  inherited Create;
  FLogger := ALogger;
  FInitService := AInitService;
  FInstallService := AInstallService;
  FConfigService := AConfigService;
  FPackageRepo := APackageRepo;
  FRegistry := ARegistry;
  FCompiler := ARuntime.Compiler;
  FRegistrationHandler := ARuntime.RegistrationHandler;
  FUnregisterHandler := ARuntime.UnregisterHandler;
  FRepairHandler := ARuntime.RepairHandler;
  FUninstallHandler := ARuntime.UninstallHandler;
end;

procedure TBoss4DCommandLineParser.ShowHelp;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'Boss4D - Gerenciador de Dependencias Delphi Nativo (v1.6.0)');
  FLogger.Log(TBoss4DLogLevel.Info, '');
  FLogger.Log(TBoss4DLogLevel.Info, 'Uso:');
  FLogger.Log(TBoss4DLogLevel.Info, '  boss4d [comando] [argumentos] [flags]');
  FLogger.Log(TBoss4DLogLevel.Info, '');
  FLogger.Log(TBoss4DLogLevel.Info, 'Comandos Disponiveis:');
  FLogger.Log(TBoss4DLogLevel.Info, '  init                 Inicializa um novo arquivo boss.json no diretorio atual.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -q, --quiet (modo silencioso).');
  FLogger.Log(TBoss4DLogLevel.Info, '  install              Instala todas as dependencias declaradas no boss.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -p, --platform <plataforma> (Win32, Win64, Linux64, etc.).');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: --locked, --frozen-lockfile, --offline, --production, --no-register, --progress plain|interactive, --json, --quiet.');
  FLogger.Log(TBoss4DLogLevel.Info, '  install <dep>        Instala uma dependencia especifica.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Exemplo: boss4d install github.com/hashload/horse@^3.0.0');
  FLogger.Log(TBoss4DLogLevel.Info, '  add <dep> [--dev]    Adiciona dependencia de runtime ou desenvolvimento.');
  FLogger.Log(TBoss4DLogLevel.Info, '  remove <dep>         Remove uma dependencia e locks orfaos.');
  FLogger.Log(TBoss4DLogLevel.Info, '  update [dep]         Atualiza uma ou todas as dependencias.');
  FLogger.Log(TBoss4DLogLevel.Info, '  list                 Lista dependencias diretas e transitivas.');
  FLogger.Log(TBoss4DLogLevel.Info, '  why <dep>            Explica por que uma dependencia foi instalada.');
  FLogger.Log(TBoss4DLogLevel.Info, '  audit               Consulta vulnerabilidades OSV por revisao do lock.');
  FLogger.Log(TBoss4DLogLevel.Info, '  registry add|remove|list Gerencia indices publicos e privados.');
  FLogger.Log(TBoss4DLogLevel.Info, '  search <termo>       Pesquisa pacotes nos indices configurados.');
  FLogger.Log(TBoss4DLogLevel.Info, '  info <pacote>        Exibe metadados de um pacote indexado.');
  FLogger.Log(TBoss4DLogLevel.Info, '  package install <pacote> Instala .b4dpkg verificado; aceita --platform e --compiler.');
  FLogger.Log(TBoss4DLogLevel.Info, '  dependency submit    Envia snapshot ao GitHub Dependency Graph.');
  FLogger.Log(TBoss4DLogLevel.Info, '  publish              Publica pacote com validacoes; use --dry-run para inspecionar.');
  FLogger.Log(TBoss4DLogLevel.Info, '  ci [--offline]       Reinstala limpo usando o lock sem altera-lo; aceita --progress, --json e --quiet.');
  FLogger.Log(TBoss4DLogLevel.Info, '  config delphi use <caminho>  Configura o caminho global do compilador Delphi.');
  FLogger.Log(TBoss4DLogLevel.Info, '  config git shallow <true/false> Configura uso de shallow clones globais.');
  FLogger.Log(TBoss4DLogLevel.Info, '  config auth <github/gitlab> <token> Configura tokens de autenticacao global.');
  FLogger.Log(TBoss4DLogLevel.Info, '  cache                Gerenciamento do cache global do Git.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Subcomandos: size, clean, prune.');
  FLogger.Log(TBoss4DLogLevel.Info, '  run <script>         Executa um script customizado definido no boss.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '  doctor               Executa diagnosticos do ambiente de compilacao.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -fix, --fix (tenta auto-configurar a versao delphi).');
  FLogger.Log(TBoss4DLogLevel.Info, '  license report       Gera relatorios de conformidade de licencas em docs/.');
  FLogger.Log(TBoss4DLogLevel.Info, '  sbom                 Gera SBOM CycloneDX 1.7 ou SPDX 2.3 a partir do boss-lock.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: --output, --type, --strict, --validate, --lock-only, --reproducible, --include-getit, --include-toolchain, --include-artifacts, --vex, --attestation-output, --verify-attestation.');
  FLogger.Log(TBoss4DLogLevel.Info, '  tree                 Exibe a arvore de dependencias do projeto.');
  FLogger.Log(TBoss4DLogLevel.Info, '  outdated             Verifica se ha atualizacoes disponiveis dos pacotes.');
  FLogger.Log(TBoss4DLogLevel.Info, '  tool install -g <repo> Compila e instala um utilitario Delphi globalmente.');
  FLogger.Log(TBoss4DLogLevel.Info, '  clean                Apaga a pasta modules e o arquivo boss-lock.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '  new <template> <nome> [--path <dir>] Cria app/package/VCL/FMX/API/DUnitX/Lazarus/workspace.');
  FLogger.Log(TBoss4DLogLevel.Info, '  version, -v, --version Exibe a versao atual do Boss4D.');
  FLogger.Log(TBoss4DLogLevel.Info, '  self-update          Baixa, verifica e inicia a atualizacao oficial.');
  FLogger.Log(TBoss4DLogLevel.Info, '  pack [--output arq]  Gera um pacote .b4dpkg deterministico e imutavel.');
  FLogger.Log(TBoss4DLogLevel.Info, '  conformance registry|package <arq> Valida o protocolo publico.');
  FLogger.Log(TBoss4DLogLevel.Info, '  spec --detect [--compiler <versao>] Detecta projetos e gera buildMatrix.');
  FLogger.Log(TBoss4DLogLevel.Info, '  build                Compila a matriz declarada.');
  FLogger.Log(TBoss4DLogLevel.Info, '  support              Consulta suporte por compilador, plataforma e tipo.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: --compiler, --platform, --configuration, --jobs, --force, --full, --explain, --register, --all-installed, --affected, --with-dependents.');
  FLogger.Log(TBoss4DLogLevel.Info, '  ide unregister <bpl> --compiler <versao> --platform <Win32|Win64>');
  FLogger.Log(TBoss4DLogLevel.Info, '  ide uninstall <pacote> Remove todos os targets gerenciados do pacote.');
  FLogger.Log(TBoss4DLogLevel.Info, '  ide repair           Repara registros da IDE a partir do inventario.');
  FLogger.Log(TBoss4DLogLevel.Info, '  help, -h, --help     Exibe este menu de ajuda.');
  FLogger.Log(TBoss4DLogLevel.Info, '');
end;

procedure TBoss4DCommandLineParser.ShowVersion;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'v1.6.0-delphi-native');
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
  else if LCommand = 'ci' then
    HandleCI(AArgs)
  else if LCommand = 'restore' then
  begin
    if (Length(AArgs) > 1) and SameText(AArgs[1], '--ci') then
    begin
      var LCIArgs := TList<string>.Create;
      try
        LCIArgs.Add('ci');
        for var LRestoreIndex := 2 to Length(AArgs) - 1 do
          LCIArgs.Add(AArgs[LRestoreIndex]);
        HandleCI(LCIArgs.ToArray);
      finally
        LCIArgs.Free;
      end;
    end
    else
      HandleInstall(AArgs);
  end
  else if LCommand = 'add' then
    HandleAdd(AArgs)
  else if (LCommand = 'remove') or (LCommand = 'rm') then
    HandleRemove(AArgs)
  else if (LCommand = 'update') or (LCommand = 'up') then
    HandleUpdate(AArgs)
  else if (LCommand = 'list') or (LCommand = 'ls') then
    HandleList
  else if LCommand = 'why' then
    HandleWhy(AArgs)
  else if LCommand = 'audit' then
    HandleAudit(AArgs)
  else if LCommand = 'registry' then
    HandleRegistry(AArgs)
  else if LCommand = 'search' then
    HandleSearch(AArgs)
  else if LCommand = 'info' then
    HandleInfo(AArgs)
  else if LCommand = 'package' then
    HandlePackage(AArgs)
  else if LCommand = 'dependency' then
    HandleDependency(AArgs)
  else if LCommand = 'publish' then
    HandlePublish(AArgs)
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
    HandlePlugin(AArgs)
  else if LCommand = 'getit' then
    HandleGetIt(AArgs)
  else if LCommand = 'clean' then
    HandleClean(AArgs)
  else if LCommand = 'new' then
    HandleNew(AArgs)
  else if LCommand = 'self-update' then
    HandleSelfUpdate
  else if LCommand = 'pack' then
    HandlePack(AArgs)
  else if LCommand = 'conformance' then
    HandleConformance(AArgs)
  else if LCommand = 'spec' then
    HandleSpec(AArgs)
  else if LCommand = 'build' then
    HandleBuild(AArgs)
  else if LCommand = 'support' then
    HandleSupport(AArgs)
  else if LCommand = 'ide' then
    HandleIDE(AArgs)
  else if LCommand = 'sbom' then
    HandleSbom(AArgs);
end;

procedure TBoss4DCommandLineParser.HandleSupport(
  const AArgs: TArray<string>);
var
  LCompilers, LPlatforms: TArray<string>;
  LCompiler, LPlatform, LKind, LProject: string;
  LCapability: TBoss4DBuildCapability;
  I: Integer;
begin
  LCompiler := 'all';
  LPlatform := 'all';
  LKind := 'runtime';
  LProject := 'package.dproj';
  I := 1;
  while I < Length(AArgs) do
  begin
    if (I + 1 >= Length(AArgs)) or not AArgs[I].StartsWith('--') then
      raise EArgumentException.Create(
        'Uso: boss4d support [--compiler <versao|all>] ' +
        '[--platform <target|all>] [--kind <tipo>] [--project <arquivo>].');
    if SameText(AArgs[I], '--compiler') then
      LCompiler := AArgs[I + 1]
    else if SameText(AArgs[I], '--platform') then
      LPlatform := AArgs[I + 1]
    else if SameText(AArgs[I], '--kind') then
      LKind := AArgs[I + 1]
    else if SameText(AArgs[I], '--project') then
      LProject := AArgs[I + 1]
    else
      raise EArgumentException.Create(
        'Opcao desconhecida para support: ' + AArgs[I]);
    Inc(I, 2);
  end;

  if SameText(LCompiler, 'all') then
    LCompilers := TBoss4DBuildCapabilities.SupportedCompilers
  else
  begin
    TBoss4DBuildConventions.ResolveCompiler(LCompiler);
    LCompilers := TArray<string>.Create(LCompiler);
  end;
  if SameText(LPlatform, 'all') then
    LPlatforms := TBoss4DBuildCapabilities.SupportedPlatforms
  else
    LPlatforms := TArray<string>.Create(
      TBoss4DBuildCapabilities.NormalizePlatform(LPlatform));

  FLogger.Log(TBoss4DLogLevel.Info,
    'compiler | platform | kind | level | reason');
  for var LCompilerItem in LCompilers do
    for var LPlatformItem in LPlatforms do
    begin
      LCapability := TBoss4DBuildCapabilities.Evaluate(
        LCompilerItem, LPlatformItem, LKind, LProject);
      FLogger.Log(TBoss4DLogLevel.Info, '%s | %s | %s | %s | %s',
        [TBoss4DBuildConventions.ResolveCompiler(LCompilerItem).Alias,
         LPlatformItem, LKind,
         TBoss4DBuildCapability.LevelName(LCapability.Level),
         LCapability.Reason]);
    end;
end;

procedure TBoss4DCommandLineParser.HandleIDEUninstall(
  const AArgs: TArray<string>);
var
  LInventory: TBoss4DBuildInventory;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LRemovalNames: TList<string>;
  LDependents, LOrder: TArray<string>;
  LCascade, LForce: Boolean;
  LCount: Integer;
begin
  if Length(AArgs) < 3 then
    raise EArgumentException.Create(
      'Uso: boss4d ide uninstall <pacote> [--cascade|--force].');
  LCascade := False;
  LForce := False;
  for var LOptionIndex := 3 to Length(AArgs) - 1 do
    if SameText(AArgs[LOptionIndex], '--cascade') then
      LCascade := True
    else if SameText(AArgs[LOptionIndex], '--force') then
      LForce := True
    else
      raise EArgumentException.Create(
        'Opcao desconhecida para ide uninstall: ' + AArgs[LOptionIndex]);
  if LCascade and LForce then
    raise EArgumentException.Create(
      '--cascade e --force nao podem ser combinados.');

  LInventory := TBoss4DBuildInventory.Create(TPath.Combine(
    GetBossHome, 'build-inventory.json'));
  LIDEIntegration := nil;
  LRemovalNames := TList<string>.Create;
  try
    LInventory.Load;
    LRemovalNames.Add(AArgs[2].ToLower);
    if LInventory.Contains(AArgs[2]) then
    begin
      LDependents := LInventory.DependentsOf(AArgs[2]);
      if (Length(LDependents) > 0) and not LCascade and not LForce then
        raise EInvalidOpException.CreateFmt(
          'Nao e possivel remover %s; dependentes instalados: %s.',
          [AArgs[2], string.Join(', ', LDependents)]);
      if LCascade then
        LRemovalNames.AddRange(LDependents);
    end;
    LOrder := LInventory.BuildOrder(LRemovalNames.ToArray);
    LCount := 0;
    if not Assigned(FUninstallHandler) then
      LIDEIntegration := TBoss4DIDEIntegrationService.Create(
        FRegistry, FLogger);
    for var LOrderIndex := Length(LOrder) - 1 downto 0 do
    begin
      var LOwner := LOrder[LOrderIndex];
      if Assigned(FUninstallHandler) then
        Inc(LCount, FUninstallHandler(LOwner))
      else
        Inc(LCount, LIDEIntegration.UninstallPackage(LOwner));
      if LInventory.Contains(LOwner) then
        LInventory.RemovePackage(LOwner);
    end;
    LInventory.Save;
  finally
    LRemovalNames.Free;
    LIDEIntegration.Free;
    LInventory.Free;
  end;
  FLogger.Log(TBoss4DLogLevel.Info,
    'Pacote removido de todas as IDEs: %d registros.', [LCount]);
end;

procedure TBoss4DCommandLineParser.HandleIDEProfile(
  const AArgs: TArray<string>);
var
  LStore: TBoss4DIDEProfileStore;
  LService: TBoss4DIDEProfileService;
  LProfile: TBoss4DIDEProfile;
  LCompiler: string;
  LDescription: string;
  LExecutable: string;
  I: Integer;
begin
  if Length(AArgs) < 3 then
    raise EArgumentException.Create(
      'Uso: boss4d ide profile list|create|show|clone|remove|' +
      'export|import|launch.');
  LStore := TBoss4DIDEProfileStore.Create(TPath.Combine(
    GetBossHome, 'ide-profiles.json'));
  LService := TBoss4DIDEProfileService.Create(LStore,
    TPath.Combine(GetBossHome, 'ide-profiles'));
  try
    if SameText(AArgs[2], 'list') then
    begin
      var LProfiles := LService.List;
      try
        for LProfile in LProfiles do
          FLogger.Log(TBoss4DLogLevel.Info,
            '%s  %s  Delphi %s  %s',
            [LProfile.Id, LProfile.Name, LProfile.Compiler,
             LProfile.RegistryBranch]);
      finally
        LProfiles.Free;
      end;
      Exit;
    end;

    if SameText(AArgs[2], 'create') then
    begin
      if Length(AArgs) < 4 then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile create <nome> --compiler <versao>.');
      I := 4;
      while I < Length(AArgs) do
      begin
        if I + 1 >= Length(AArgs) then
          raise EArgumentException.Create(
            'Informe um valor para ' + AArgs[I] + '.');
        if SameText(AArgs[I], '--compiler') then
          LCompiler := AArgs[I + 1]
        else if SameText(AArgs[I], '--description') then
          LDescription := AArgs[I + 1]
        else if SameText(AArgs[I], '--executable') then
          LExecutable := AArgs[I + 1]
        else
          raise EArgumentException.Create(
            'Opcao desconhecida para ide profile create: ' + AArgs[I]);
        Inc(I, 2);
      end;
      if LCompiler.Trim.IsEmpty then
        raise EArgumentException.Create('--compiler e obrigatorio.');
      LCompiler := TBoss4DBuildConventions.ResolveCompiler(
        LCompiler).BDSVersion;
      if LExecutable.Trim.IsEmpty then
      begin
        var LIDEPath := FRegistry.GetDelphiPath(LCompiler);
        if not LIDEPath.Trim.IsEmpty then
          LExecutable := TPath.Combine(LIDEPath, 'bin\bds.exe');
      end;
      LProfile := LService.CreateProfile(AArgs[3], LDescription,
        LCompiler, LExecutable);
      try
        FLogger.Log(TBoss4DLogLevel.Info,
          'Perfil IDE criado: %s (%s).',
          [LProfile.Id, LProfile.RegistryBranch]);
      finally
        LProfile.Free;
      end;
      Exit;
    end;

    if SameText(AArgs[2], 'show') then
    begin
      if Length(AArgs) <> 4 then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile show <perfil>.');
      LProfile := LService.Get(AArgs[3]);
      try
        FLogger.Log(TBoss4DLogLevel.Info,
          '%s | Delphi %s | branch %s | packages: %s',
          [LProfile.Name, LProfile.Compiler, LProfile.RegistryBranch,
           string.Join(', ', LProfile.Packages.ToArray)]);
      finally
        LProfile.Free;
      end;
      Exit;
    end;

    if SameText(AArgs[2], 'clone') then
    begin
      if Length(AArgs) <> 5 then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile clone <origem> <novo-nome>.');
      LProfile := LService.CloneProfile(AArgs[3], AArgs[4]);
      try
        FLogger.Log(TBoss4DLogLevel.Info,
          'Perfil IDE clonado: %s.', [LProfile.Id]);
      finally
        LProfile.Free;
      end;
      Exit;
    end;

    if SameText(AArgs[2], 'remove') then
    begin
      if Length(AArgs) <> 4 then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile remove <perfil>.');
      LService.Remove(AArgs[3]);
      FLogger.Log(TBoss4DLogLevel.Info,
        'Perfil IDE removido: %s.', [AArgs[3]]);
      Exit;
    end;

    if SameText(AArgs[2], 'export') then
    begin
      if (Length(AArgs) <> 6) or
         not SameText(AArgs[4], '--output') then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile export <perfil> --output <arquivo>.');
      LService.ExportProfile(AArgs[3], AArgs[5]);
      Exit;
    end;

    if SameText(AArgs[2], 'import') then
    begin
      if Length(AArgs) <> 4 then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile import <arquivo>.');
      LProfile := LService.ImportProfile(AArgs[3]);
      try
        FLogger.Log(TBoss4DLogLevel.Info,
          'Perfil IDE importado: %s.', [LProfile.Id]);
      finally
        LProfile.Free;
      end;
      Exit;
    end;

    if SameText(AArgs[2], 'launch') then
    begin
      if Length(AArgs) <> 4 then
        raise EArgumentException.Create(
          'Uso: boss4d ide profile launch <perfil>.');
      LService.Launch(AArgs[3]);
      Exit;
    end;

    raise EArgumentException.Create(
      'Comando ide profile desconhecido: ' + AArgs[2]);
  finally
    LService.Free;
    LStore.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleIDE(
  const AArgs: TArray<string>);
var
  LCompiler: string;
  LPlatform: string;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LRegistrationService: TBoss4DIDERegistrationService;
  LInventory: TBoss4DBuildInventory;
  LCompilerService: IBoss4DCompiler;
  LCount: Integer;
  I: Integer;
begin
  if Length(AArgs) < 2 then
    raise EArgumentException.Create(
      'Uso: boss4d ide unregister|repair.');

  LIDEIntegration := nil;
  LRegistrationService := nil;
  LInventory := nil;
  try
    if SameText(AArgs[1], 'profile') then
    begin
      HandleIDEProfile(AArgs);
      Exit;
    end;
    if SameText(AArgs[1], 'repair') then
    begin
      if Length(AArgs) <> 2 then
        raise EArgumentException.Create('Uso: boss4d ide repair.');
      if Assigned(FRepairHandler) then
        LCount := FRepairHandler()
      else
      begin
        LCompilerService := FCompiler;
        if not Assigned(LCompilerService) then
          LCompilerService := TBoss4DDelphiCompilerAdapter.Create(
            FRegistry, FLogger);
        LInventory := TBoss4DBuildInventory.Create(TPath.Combine(
          GetBossHome, 'build-inventory.json'));
        LInventory.Load;
        LRegistrationService := TBoss4DIDERegistrationService.Create(
          TBoss4DWindowsIDERegistryStore.Create,
          TPath.Combine(GetBossHome, 'ide-registrations.json'),
          procedure(const ARegistration: TBoss4DIDERegistration)
          begin
            if not LInventory.Contains(ARegistration.OwnerPackage) then
              raise EBoss4DIDERegistrationError.CreateFmt(
                'Pacote %s nao encontrado no inventario de build.',
                [ARegistration.OwnerPackage]);
            var LRoot := LInventory.GetPackage(
              ARegistration.OwnerPackage).RootDirectory;
            var LManifest := TPath.Combine(LRoot, FILE_PACKAGE);
            var LPackage := FPackageRepo.Load(LManifest);
            try
              var LLockRepo: IBoss4DLockRepository :=
                TBoss4DLockJsonRepository.Create;
              var LLockPath := TPath.Combine(LRoot, FILE_PACKAGE_LOCK);
              var LLock: TBoss4DLock;
              if LLockRepo.Exists(LLockPath) then
                LLock := LLockRepo.Load(LLockPath)
              else
                LLock := TBoss4DLock.Create;
              try
                var LConfiguration := ARegistration.Configuration;
                if LConfiguration.IsEmpty then
                  LConfiguration := TPath.GetFileName(
                    ExcludeTrailingPathDelimiter(
                      ARegistration.ArtifactRoot));
                if not SameText(LConfiguration, 'Debug') and
                   not SameText(LConfiguration, 'Release') then
                  LConfiguration := 'Release';
                var LOptions := TBoss4DBuildCommandOptions.Parse(
                  TArray<string>.Create('build', '--compiler',
                    ARegistration.Compiler, '--platform',
                    ARegistration.Platform, '--configuration',
                    LConfiguration, '--force'));
                var LCommand := TBoss4DBuildCommand.Create(
                  LCompilerService, FLogger);
                try
                  LCommand.Execute(LPackage, LLock, LRoot, LOptions);
                finally
                  LCommand.Free;
                end;
              finally
                LLock.Free;
              end;
            finally
              LPackage.Free;
            end;
          end);
        LCount := LRegistrationService.Repair;
      end;
      FLogger.Log(TBoss4DLogLevel.Info,
        'Registros IDE reparados: %d.', [LCount]);
      Exit;
    end;

    if SameText(AArgs[1], 'uninstall') then
    begin
      HandleIDEUninstall(AArgs);
      Exit;
    end;

    if not SameText(AArgs[1], 'unregister') or (Length(AArgs) < 3) then
      raise EArgumentException.Create(
        'Uso: boss4d ide unregister <pacote> --compiler <versao> ' +
        '--platform <Win32|Win64>.');
    I := 3;
    while I < Length(AArgs) do
    begin
      if SameText(AArgs[I], '--compiler') then
      begin
        if I + 1 >= Length(AArgs) then
          raise EArgumentException.Create(
            'Informe um valor para --compiler.');
        Inc(I);
        LCompiler :=
          TBoss4DBuildConventions.ResolveCompiler(AArgs[I]).BDSVersion;
      end
      else if SameText(AArgs[I], '--platform') then
      begin
        if I + 1 >= Length(AArgs) then
          raise EArgumentException.Create(
            'Informe um valor para --platform.');
        Inc(I);
        if SameText(AArgs[I], 'Win32') then
          LPlatform := 'Win32'
        else if SameText(AArgs[I], 'Win64') then
          LPlatform := 'Win64'
        else
          raise EArgumentException.CreateFmt(
            'Plataforma Delphi nao suportada: %s.', [AArgs[I]]);
      end
      else
        raise EArgumentException.Create(
          'Opcao desconhecida para ide unregister: ' + AArgs[I]);
      Inc(I);
    end;
    if LCompiler.IsEmpty or LPlatform.IsEmpty then
      raise EArgumentException.Create(
        '--compiler e --platform sao obrigatorios para ide unregister.');

    if Assigned(FUnregisterHandler) then
      LCount := FUnregisterHandler(AArgs[2], LCompiler, LPlatform)
    else
    begin
      LIDEIntegration := TBoss4DIDEIntegrationService.Create(
        FRegistry, FLogger);
      LCount := LIDEIntegration.UnregisterTarget(
        AArgs[2], LCompiler, LPlatform);
    end;
    FLogger.Log(TBoss4DLogLevel.Info,
      'Registros IDE removidos: %d.', [LCount]);
  finally
    LInventory.Free;
    LRegistrationService.Free;
    LIDEIntegration.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleBuild(
  const AArgs: TArray<string>);
var
  LCompiler: IBoss4DCompiler;
  LLockRepo: IBoss4DLockRepository;
  LCoordinator: TBoss4DBuildCoordinator;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LHandler: TBoss4DIDERegistrationHandler;
  LInventory: TBoss4DBuildInventory;
begin
  LCompiler := FCompiler;
  if not Assigned(LCompiler) then
    LCompiler := TBoss4DDelphiCompilerAdapter.Create(FRegistry, FLogger);
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LIDEIntegration := nil;
  LHandler := FRegistrationHandler;
  if not Assigned(LHandler) then
  begin
    LIDEIntegration := TBoss4DIDEIntegrationService.Create(
      FRegistry, FLogger);
    LHandler :=
      procedure(const ARegistration: TBoss4DIDERegistration)
      begin
        LIDEIntegration.RegisterTarget(ARegistration);
      end;
  end;
  try
    LInventory := TBoss4DBuildInventory.Create(TPath.Combine(
      GetBossHome, 'build-inventory.json'));
    try
      LInventory.Load;
      LCoordinator := TBoss4DBuildCoordinator.Create(LCompiler, FLogger,
        FPackageRepo, LLockRepo, LHandler, LInventory,
        TBoss4DRegistryIDEDiscovery.Create(FRegistry));
      try
        LCoordinator.Execute(GetCurrentDir,
          TBoss4DBuildCommandOptions.Parse(AArgs));
      finally
        LCoordinator.Free;
      end;
    finally
      LInventory.Free;
    end;
  finally
    LIDEIntegration.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleSpec(
  const AArgs: TArray<string>);
var
  LCompilers: TList<string>;
  LPackage: TBoss4DPackage;
  I: Integer;
begin
  if (Length(AArgs) < 2) or not SameText(AArgs[1], '--detect') then
    raise EArgumentException.Create(
      'Uso: boss4d spec --detect [--compiler <versao>].');

  LCompilers := TList<string>.Create;
  try
    I := 2;
    while I < Length(AArgs) do
    begin
      if not SameText(AArgs[I], '--compiler') then
        raise EArgumentException.Create(
          'Opcao desconhecida para spec: ' + AArgs[I]);
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create(
          'Informe um valor para --compiler.');
      Inc(I);
      if SameText(AArgs[I], 'all') then
        LCompilers.Clear
      else
        LCompilers.Add(AArgs[I]);
      Inc(I);
    end;

    LPackage := FPackageRepo.Load(GetBossFile);
    try
      if LCompilers.Count = 0 then
        TBoss4DBuildSpecDetector.Detect(LPackage, GetCurrentDir)
      else
        TBoss4DBuildSpecDetector.Detect(LPackage, GetCurrentDir,
          LCompilers.ToArray);
      FPackageRepo.Save(LPackage, GetBossFile);
      FLogger.Log(TBoss4DLogLevel.Info,
        'buildMatrix detectada: %d projetos, %d compiladores.',
        [LPackage.BuildMatrix.Projects.Count,
         LPackage.BuildMatrix.Compilers.Count]);
    finally
      LPackage.Free;
    end;
  finally
    LCompilers.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleConformance(
  const AArgs: TArray<string>);
var
  LService: TBoss4DConformanceService;
  LResult: TBoss4DConformanceResult;
begin
  if Length(AArgs) < 3 then
    raise EArgumentException.Create(
      'Uso: conformance registry|package <arquivo>.');
  LService := TBoss4DConformanceService.Create;
  try
    if SameText(AArgs[1], 'registry') then
      LResult := LService.ValidateRegistryContent(
        TFile.ReadAllText(TPath.GetFullPath(AArgs[2]), TEncoding.UTF8))
    else if SameText(AArgs[1], 'package') then
      LResult := LService.ValidatePackageFile(TPath.GetFullPath(AArgs[2]))
    else
      raise EArgumentException.Create('Tipo de conformidade desconhecido.');
    if not LResult.Passed then
      raise Exception.Create('Falha de conformidade: ' +
        LResult.ErrorMessage);
    FLogger.Log(TBoss4DLogLevel.Info, Format(
      'Conformidade aprovada (%d entradas).', [LResult.PackageCount]));
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandlePack(const AArgs: TArray<string>);
var
  LOutput: string;
  LSigningKey: string;
  LService: TBoss4DPackService;
  LResult: TBoss4DPackResult;
begin
  LOutput := TPath.Combine(GetCurrentDir, 'dist\package.b4dpkg');
  LSigningKey := '';
  for var I := 1 to High(AArgs) do
    if SameText(AArgs[I], '--output') then
    begin
      if I + 1 > High(AArgs) then
        raise EArgumentException.Create('Informe o arquivo de saida.');
      LOutput := AArgs[I + 1];
    end;
  for var I := 1 to High(AArgs) do
    if SameText(AArgs[I], '--sign') then
    begin
      if I + 1 > High(AArgs) then
        raise EArgumentException.Create('Informe a chave GPG.');
      LSigningKey := AArgs[I + 1];
    end;
  LService := TBoss4DPackService.Create;
  try
    LResult := LService.Execute(GetCurrentDir, LOutput);
    FLogger.Log(TBoss4DLogLevel.Info,
      'Pacote gerado: %s (sha256:%s, %d arquivos)',
      [LResult.OutputPath, LResult.Digest, LResult.FileCount]);
    FLogger.Log(TBoss4DLogLevel.Info,
      'Proveniencia gerada: ' + LResult.ProvenancePath);
    if not LSigningKey.IsEmpty then
    begin
      var LSigner: IBoss4DPackageSigner :=
        TBoss4DGpgPackageSigner.Create(Boss4DProcessRunner);
      var LSignature := LSigner.Sign(LResult.OutputPath, LSigningKey);
      if not LSigner.Verify(LResult.OutputPath, LSignature) then
        raise Exception.Create('A assinatura gerada nao foi verificada.');
      FLogger.Log(TBoss4DLogLevel.Info,
        'Assinatura OpenPGP verificada: ' + LSignature);
    end;
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleSelfUpdate;
var
  LService: TBoss4DSelfUpdateService;
  LResult: TBoss4DSelfUpdateResult;
begin
  LService := TBoss4DSelfUpdateService.Create(TBoss4DHttpNativeAdapter.Create,
    FLogger, Boss4DSelfUpdateApplier);
  try
    LResult := LService.CheckAndDownload('1.6.0',
      TPath.Combine(TPath.GetTempPath, 'boss4d-update'));
    if not LResult.Updated then
      FLogger.Log(TBoss4DLogLevel.Info, 'Boss4D ja esta atualizado.')
    else
      FLogger.Log(TBoss4DLogLevel.Info,
        'Instalador verificado iniciado. Versao: ' + LResult.Version);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandlePublish(
  const AArgs: TArray<string>);
var
  LOptions: TBoss4DPublishOptions;
  LService: TBoss4DPublishService;
  LLockRepo: IBoss4DLockRepository;
  LHttp: IBoss4DHttpClient;
  LPayload, LOutputPath, LTokenEnvironment: string;
  I: Integer;
  LEncoding: TEncoding;
begin
  LOptions := Default(TBoss4DPublishOptions);
  LOptions.RequireCleanGit := True;
  LOptions.RunTests := True;
  LTokenEnvironment := 'BOSS4D_PUBLISH_TOKEN';
  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--dry-run') then
      LOptions.DryRun := True
    else if SameText(AArgs[I], '--allow-dirty') then
      LOptions.RequireCleanGit := False
    else if SameText(AArgs[I], '--skip-tests') then
      LOptions.RunTests := False
    else if SameText(AArgs[I], '--registry') or
            SameText(AArgs[I], '--token-env') or
            SameText(AArgs[I], '--output') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um valor para ' + AArgs[I]);
      Inc(I);
      if SameText(AArgs[I - 1], '--registry') then
        LOptions.RegistryUrl := AArgs[I]
      else if SameText(AArgs[I - 1], '--token-env') then
        LTokenEnvironment := AArgs[I]
      else
        LOutputPath := AArgs[I];
    end
    else
      raise EArgumentException.Create(
        'Opcao desconhecida para publish: ' + AArgs[I]);
    Inc(I);
  end;
  LOptions.Token := GetEnvironmentVariable(LTokenEnvironment);
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LService := TBoss4DPublishService.Create(
    FPackageRepo, LLockRepo, LHttp, FLogger);
  try
    LPayload := LService.Execute(GetBossFile,
      TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK), LOptions);
    if LOutputPath.IsEmpty then
    begin
      if LOptions.DryRun then
        System.Write(LPayload);
    end
    else
    begin
      LOutputPath := TPath.GetFullPath(LOutputPath);
      if not TPath.GetDirectoryName(LOutputPath).IsEmpty then
        TDirectory.CreateDirectory(TPath.GetDirectoryName(LOutputPath));
      LEncoding := TUTF8Encoding.Create(False);
      try
        TFile.WriteAllText(LOutputPath, LPayload, LEncoding);
      finally
        LEncoding.Free;
      end;
    end;
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleAdd(const AArgs: TArray<string>);
var
  LOptions: TBoss4DInstallOptions;
begin
  if (Length(AArgs) < 2) or (Length(AArgs) > 3) then
    raise EArgumentException.Create(
      'Uso: boss4d add <repositorio>@<versao> [--dev]');
  LOptions := Default(TBoss4DInstallOptions);
  LOptions.InstallSingle := AArgs[1];
  if Length(AArgs) = 3 then
  begin
    if not SameText(AArgs[2], '--dev') then
      raise EArgumentException.Create('Opcao desconhecida: ' + AArgs[2]);
    LOptions.Development := True;
  end;
  FInstallService.Execute(LOptions);
end;

procedure TBoss4DCommandLineParser.HandleRemove(const AArgs: TArray<string>);
var
  LService: TBoss4DDependencyService;
  LLockRepo: IBoss4DLockRepository;
begin
  if Length(AArgs) <> 2 then
    raise EArgumentException.Create('Uso: boss4d remove <dependencia>');
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LService := TBoss4DDependencyService.Create(FPackageRepo, LLockRepo, FLogger);
  try
    LService.Remove(AArgs[1]);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleUpdate(const AArgs: TArray<string>);
var
  LPkg: TBoss4DPackage;
  LRequested, LKey, LVersion: string;
  LDevelopment: Boolean;
  LOptions: TBoss4DInstallOptions;
begin
  if Length(AArgs) = 1 then
  begin
    FInstallService.Execute;
    Exit;
  end;
  if Length(AArgs) <> 2 then
    raise EArgumentException.Create('Uso: boss4d update [dependencia[@versao]]');
  LRequested := AArgs[1];
  if LRequested.Contains('@') then
  begin
    FInstallService.Execute(LRequested);
    Exit;
  end;
  LPkg := FPackageRepo.Load(GetBossFile);
  try
    LKey := '';
    LDevelopment := False;
    for var LPair in LPkg.Dependencies do
      if SameText(LPair.Key, LRequested) or
         SameText(TPath.GetFileName(LPair.Key), LRequested) then
      begin
        LKey := LPair.Key;
        LVersion := LPair.Value;
        Break;
      end;
    if LKey.IsEmpty then
      for var LPair in LPkg.DevDependencies do
        if SameText(LPair.Key, LRequested) or
           SameText(TPath.GetFileName(LPair.Key), LRequested) then
        begin
          LKey := LPair.Key;
          LVersion := LPair.Value;
          LDevelopment := True;
          Break;
        end;
    if LKey.IsEmpty then
      raise EArgumentException.Create('Dependencia nao declarada: ' + LRequested);
    if LDevelopment then
    begin
      LOptions := Default(TBoss4DInstallOptions);
      LOptions.InstallSingle := LKey + '@' + LVersion;
      LOptions.Development := True;
      FInstallService.Execute(LOptions);
    end
    else
      FInstallService.Execute(LKey + '@' + LVersion);
  finally
    LPkg.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleList;
var
  LService: TBoss4DDependencyService;
  LLockRepo: IBoss4DLockRepository;
  LInfo: TBoss4DDependencyInfo;
  LScope: string;
begin
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LService := TBoss4DDependencyService.Create(FPackageRepo, LLockRepo, FLogger);
  try
    for LInfo in LService.List do
    begin
      if LInfo.Direct then LScope := 'direct' else LScope := 'transitive';
      FLogger.Log(TBoss4DLogLevel.Info, '%s@%s (%s, %s)',
        [LInfo.Key, LInfo.Version, LScope, LInfo.Scope]);
    end;
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleWhy(const AArgs: TArray<string>);
var
  LService: TBoss4DDependencyService;
  LLockRepo: IBoss4DLockRepository;
  LPath: TArray<string>;
begin
  if Length(AArgs) <> 2 then
    raise EArgumentException.Create('Uso: boss4d why <dependencia>');
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LService := TBoss4DDependencyService.Create(FPackageRepo, LLockRepo, FLogger);
  try
    LPath := LService.Why(AArgs[1]);
    if Length(LPath) = 0 then
      FLogger.Log(TBoss4DLogLevel.Warning,
        'Dependencia nao encontrada no grafo: ' + AArgs[1])
    else
      FLogger.Log(TBoss4DLogLevel.Info, string.Join(' -> ', LPath));
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleAudit(const AArgs: TArray<string>);
var
  LOptions: TBoss4DAuditOptions;
  LService: TBoss4DAuditService;
  LLockRepo: IBoss4DLockRepository;
  LHttp: IBoss4DHttpClient;
  LSummary: TBoss4DAuditSummary;
  I: Integer;
begin
  LOptions := Default(TBoss4DAuditOptions);
  LOptions.CacheHours := 24;
  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--offline') then
      LOptions.Offline := True
    else if SameText(AArgs[I], '--fail-on') or
            SameText(AArgs[I], '--vex') or
            SameText(AArgs[I], '--cache-hours') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um valor para ' + AArgs[I]);
      Inc(I);
      if SameText(AArgs[I - 1], '--fail-on') then
      begin
        LOptions.FailOn := TBoss4DAuditService.ParseSeverity(AArgs[I]);
        if LOptions.FailOn = AuditUnknown then
          raise EArgumentException.Create('Severidade invalida: ' + AArgs[I]);
      end
      else if SameText(AArgs[I - 1], '--vex') then
        LOptions.VexPath := AArgs[I]
      else
        LOptions.CacheHours := StrToInt(AArgs[I]);
    end
    else
      raise EArgumentException.Create(
        'Opcao desconhecida para audit: ' + AArgs[I]);
    Inc(I);
  end;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LService := TBoss4DAuditService.Create(LLockRepo, LHttp, FLogger);
  try
    LSummary := LService.Execute(
      TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK), LOptions);
    FLogger.Log(TBoss4DLogLevel.Info,
      'Auditoria: %d encontrada(s), %d suprimida(s).',
      [LSummary.Vulnerabilities, LSummary.Suppressed]);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleRegistry(
  const AArgs: TArray<string>);
var
  LService: TBoss4DPackageIndexService;
  LHttp: IBoss4DHttpClient;
begin
  if Length(AArgs) < 2 then
    raise EArgumentException.Create(
      'Uso: boss4d registry add|remove|list [origem]');
  if (Length(AArgs) = 4) and SameText(AArgs[1], 'portal') then
  begin
    var LPortal := TBoss4DRegistryPortalService.Create;
    try
      var LHtml := LPortal.Generate(TFile.ReadAllText(
        TPath.GetFullPath(AArgs[2]), TEncoding.UTF8));
      TFile.WriteAllText(TPath.GetFullPath(AArgs[3]), LHtml,
        TEncoding.UTF8);
      FLogger.Log(TBoss4DLogLevel.Info,
        'Portal de registry gerado: ' + TPath.GetFullPath(AArgs[3]));
    finally
      LPortal.Free;
    end;
    Exit;
  end;
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LService := TBoss4DPackageIndexService.Create(
    FConfigService, LHttp, FLogger);
  try
    if SameText(AArgs[1], 'list') then
      for var LSource in LService.ListRegistries do
        FLogger.Log(TBoss4DLogLevel.Info, LSource)
    else if (Length(AArgs) = 3) and SameText(AArgs[1], 'add') then
      LService.AddRegistry(AArgs[2])
    else if (Length(AArgs) = 3) and SameText(AArgs[1], 'remove') then
      LService.RemoveRegistry(AArgs[2])
    else
      raise EArgumentException.Create(
        'Uso: boss4d registry add|remove|list [origem]');
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleSearch(const AArgs: TArray<string>);
var
  LService: TBoss4DPackageIndexService;
  LHttp: IBoss4DHttpClient;
begin
  if Length(AArgs) <> 2 then
    raise EArgumentException.Create('Uso: boss4d search <termo>');
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LService := TBoss4DPackageIndexService.Create(
    FConfigService, LHttp, FLogger);
  try
    var LEntries := LService.Search(AArgs[1]);
    try
      for var LEntry in LEntries do
        FLogger.Log(TBoss4DLogLevel.Info, '%s  %s  %s',
          [LEntry.Name, LEntry.LatestVersion, LEntry.Repository]);
    finally
      LEntries.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleInfo(const AArgs: TArray<string>);
var
  LService: TBoss4DPackageIndexService;
  LHttp: IBoss4DHttpClient;
  LEntry: TBoss4DPackageIndexEntry;
begin
  if Length(AArgs) <> 2 then
    raise EArgumentException.Create('Uso: boss4d info <pacote>');
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LService := TBoss4DPackageIndexService.Create(
    FConfigService, LHttp, FLogger);
  try
    LEntry := LService.Info(AArgs[1]);
    try
      if not Assigned(LEntry) then
        raise EArgumentException.Create('Pacote nao encontrado: ' + AArgs[1]);
      FLogger.Log(TBoss4DLogLevel.Info, 'Nome: ' + LEntry.Name);
      FLogger.Log(TBoss4DLogLevel.Info, 'Repositorio: ' + LEntry.Repository);
      FLogger.Log(TBoss4DLogLevel.Info, 'Versao: ' + LEntry.LatestVersion);
      FLogger.Log(TBoss4DLogLevel.Info, 'Licenca: ' + LEntry.License);
      FLogger.Log(TBoss4DLogLevel.Info, 'Descricao: ' + LEntry.Description);
      FLogger.Log(TBoss4DLogLevel.Info, 'Origem: ' + LEntry.Source);
    finally
      LEntry.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandlePackage(const AArgs: TArray<string>);
var
  LIndex: TBoss4DPackageIndexService;
  LEntry: TBoss4DPackageIndexEntry;
  LInstaller: TBoss4DPackageInstallService;
  LRequest: TBoss4DPackageInstallRequest;
  LDependency: TBoss4DDependency;
  LAllowFallback: Boolean;
  LPlatform, LCompiler: string;
begin
  if (Length(AArgs) < 3) or not SameText(AArgs[1], 'install') then
    raise EArgumentException.Create(
      'Uso: boss4d package install <pacote> [--no-source-fallback].');
  LAllowFallback := True;
  LPlatform := '';
  LCompiler := '';
  var I := 3;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--no-source-fallback') then
      LAllowFallback := False
    else if SameText(AArgs[I], '--platform') and (I + 1 < Length(AArgs)) then
    begin
      LPlatform := AArgs[I + 1];
      Inc(I);
    end
    else if SameText(AArgs[I], '--compiler') and (I + 1 < Length(AArgs)) then
    begin
      LCompiler := AArgs[I + 1];
      Inc(I);
    end;
    Inc(I);
  end;
  LIndex := TBoss4DPackageIndexService.Create(FConfigService,
    TBoss4DHttpNativeAdapter.Create, FLogger);
  try
    LEntry := LIndex.Info(AArgs[2]);
    try
      if not Assigned(LEntry) then
        raise EArgumentException.Create('Pacote nao encontrado: ' + AArgs[2]);
      var LVariant := LEntry.SelectVariant(LPlatform, LCompiler);
      if Assigned(LVariant) then
      begin
        LEntry.ArtifactUrl := LVariant.ArtifactUrl;
        LEntry.ArtifactDigest := LVariant.ArtifactDigest;
        LEntry.SignatureUrl := LVariant.SignatureUrl;
        LEntry.ProvenanceUrl := LVariant.ProvenanceUrl;
      end
      else if LEntry.Variants.Count > 0 then
      begin
        LEntry.ArtifactUrl := '';
        LEntry.ArtifactDigest := '';
        LEntry.SignatureUrl := '';
        LEntry.ProvenanceUrl := '';
      end;
      if not LEntry.ArtifactUrl.IsEmpty and
         not LEntry.ArtifactDigest.IsEmpty then
      begin
        LDependency := TBoss4DDependency.Create(LEntry.Repository,
          LEntry.LatestVersion);
        try
          LRequest := Default(TBoss4DPackageInstallRequest);
          LRequest.ArtifactUrl := LEntry.ArtifactUrl;
          LRequest.Sha256 := LEntry.ArtifactDigest;
          LRequest.SignatureUrl := LEntry.SignatureUrl;
          LRequest.ProvenanceUrl := LEntry.ProvenanceUrl;
          LRequest.TargetDirectory := TPath.Combine(GetModulesDir,
            LDependency.StorageName);
          LInstaller := TBoss4DPackageInstallService.Create(
            TBoss4DHttpNativeAdapter.Create,
            TBoss4DGpgPackageSigner.Create(Boss4DProcessRunner));
          try
            try
              var LResult := LInstaller.Execute(LRequest);
              FLogger.Log(TBoss4DLogLevel.Info,
                'Pacote verificado instalado: %s (%d arquivos, sha256:%s)',
                [LEntry.Name, LResult.FileCount, LResult.Digest]);
              Exit;
            except
              on E: Exception do
              begin
                if not LAllowFallback then raise;
                FLogger.Log(TBoss4DLogLevel.Warning,
                  'Artefato recusado; usando fontes Git: ' + E.Message);
              end;
            end;
          finally
            LInstaller.Free;
          end;
        finally
          LDependency.Free;
        end;
      end
      else if not LAllowFallback then
        raise Exception.Create('Pacote nao possui artefato imutavel publicado.');
      var LSource := LEntry.Repository;
      if not LEntry.LatestVersion.IsEmpty then
        LSource := LSource + '@' + LEntry.LatestVersion;
      FInstallService.Execute(LSource);
    finally
      LEntry.Free;
    end;
  finally
    LIndex.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleDependency(
  const AArgs: TArray<string>);
var
  LRepository, LSha, LRef, LTokenEnv, LJobId: string;
  LLockRepo: IBoss4DLockRepository;
  LHttp: IBoss4DHttpClient;
  LService: TBoss4DDependencySubmissionService;
  I: Integer;
begin
  if (Length(AArgs) < 2) or not SameText(AArgs[1], 'submit') then
    raise EArgumentException.Create(
      'Uso: boss4d dependency submit --repo owner/name --sha commit --ref refs/heads/main');
  LTokenEnv := 'GITHUB_TOKEN';
  LJobId := FormatDateTime('yyyymmddhhnnss', Now);
  I := 2;
  while I < Length(AArgs) do
  begin
    if (I + 1 >= Length(AArgs)) or not AArgs[I].StartsWith('--') then
      raise EArgumentException.Create('Opcao invalida para dependency submit.');
    if SameText(AArgs[I], '--repo') then LRepository := AArgs[I + 1]
    else if SameText(AArgs[I], '--sha') then LSha := AArgs[I + 1]
    else if SameText(AArgs[I], '--ref') then LRef := AArgs[I + 1]
    else if SameText(AArgs[I], '--token-env') then LTokenEnv := AArgs[I + 1]
    else if SameText(AArgs[I], '--job-id') then LJobId := AArgs[I + 1]
    else raise EArgumentException.Create('Opcao desconhecida: ' + AArgs[I]);
    Inc(I, 2);
  end;
  if LRepository.IsEmpty or LSha.IsEmpty or LRef.IsEmpty then
    raise EArgumentException.Create('--repo, --sha e --ref sao obrigatorios.');
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LService := TBoss4DDependencySubmissionService.Create(LLockRepo, LHttp);
  try
    LService.Submit(TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK),
      LRepository, LSha, LRef, GetEnvironmentVariable(LTokenEnv), LJobId);
    FLogger.Log(TBoss4DLogLevel.Info,
      'Snapshot enviado ao GitHub Dependency Graph.');
  finally
    LService.Free;
  end;
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
  LOptions: TBoss4DInstallOptions;
  I: Integer;
  LProgressMode: string;
begin
  LDepToInstall := '';
  LOptions := Default(TBoss4DInstallOptions);
  LOptions.InstallIDEs := True;
  LProgressMode := 'plain';

  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--platform') or SameText(AArgs[I], '-p') then
    begin
      if I + 1 < Length(AArgs) then
      begin
        LOptions.Platform := AArgs[I + 1];
        Inc(I, 2);
      end
      else
        Inc(I);
    end
    else if SameText(AArgs[I], '--locked') or
            SameText(AArgs[I], '--frozen-lockfile') then
    begin
      LOptions.Locked := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--offline') then
    begin
      LOptions.Offline := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--production') then
    begin
      LOptions.Production := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--no-register') or
            SameText(AArgs[I], '--build-only') then
    begin
      LOptions.InstallIDEs := False;
      Inc(I);
    end
    else if SameText(AArgs[I], '--remote-cache') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create(
          'Informe o caminho do cache remoto.');
      LOptions.RemoteCachePath := AArgs[I + 1];
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--resolution') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe highest ou minimal.');
      if SameText(AArgs[I + 1], 'minimal') then
        LOptions.ResolutionStrategy := MinimalCompatible
      else if SameText(AArgs[I + 1], 'highest') then
        LOptions.ResolutionStrategy := HighestCompatible
      else
        raise EArgumentException.Create('Estrategia de resolucao invalida.');
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--json') then
    begin
      LProgressMode := 'json';
      Inc(I);
    end
    else if SameText(AArgs[I], '--quiet') or SameText(AArgs[I], '-q') then
    begin
      LProgressMode := 'quiet';
      Inc(I);
    end
    else if SameText(AArgs[I], '--progress') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe o modo de progresso.');
      LProgressMode := LowerCase(AArgs[I + 1]);
      if (LProgressMode <> 'plain') and (LProgressMode <> 'interactive') then
        raise EArgumentException.Create('Modo de progresso invalido: ' +
          LProgressMode);
      Inc(I, 2);
    end
    else
    begin
      if not AArgs[I].StartsWith('-') then
        LDepToInstall := AArgs[I];
      Inc(I);
    end;
  end;

  if LOptions.Locked and not LDepToInstall.IsEmpty then
    raise EArgumentException.Create(
      '--locked instala somente o grafo completo declarado no lock.');
  FInstallService.SetProgressMode(LProgressMode);
  LOptions.InstallSingle := LDepToInstall;
  FInstallService.Execute(LOptions);
end;

procedure TBoss4DCommandLineParser.HandleCI(const AArgs: TArray<string>);
var
  LOptions: TBoss4DInstallOptions;
  I: Integer;
  LProgressMode: string;
begin
  LOptions := Default(TBoss4DInstallOptions);
  LOptions.Locked := True;
  LOptions.CleanModules := True;
  LOptions.CIMode := True;
  LOptions.InstallIDEs := False;
  LProgressMode := 'plain';
  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--offline') then
      LOptions.Offline := True
    else if SameText(AArgs[I], '--production') then
      LOptions.Production := True
    else if SameText(AArgs[I], '--platform') or
            SameText(AArgs[I], '-p') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe uma plataforma.');
      Inc(I);
      LOptions.Platform := AArgs[I];
    end
    else if SameText(AArgs[I], '--remote-cache') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create(
          'Informe o caminho do cache remoto.');
      Inc(I);
      LOptions.RemoteCachePath := AArgs[I];
    end
    else if SameText(AArgs[I], '--json') then
      LProgressMode := 'json'
    else if SameText(AArgs[I], '--quiet') or SameText(AArgs[I], '-q') then
      LProgressMode := 'quiet'
    else if SameText(AArgs[I], '--progress') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe o modo de progresso.');
      Inc(I);
      LProgressMode := LowerCase(AArgs[I]);
      if (LProgressMode <> 'plain') and (LProgressMode <> 'interactive') then
        raise EArgumentException.Create('Modo de progresso invalido: ' +
          LProgressMode);
    end
    else
      raise EArgumentException.Create('Opcao desconhecida para ci: ' + AArgs[I]);
    Inc(I);
  end;
  FInstallService.SetProgressMode(LProgressMode);
  FInstallService.Execute(LOptions);
end;

procedure TBoss4DCommandLineParser.HandleConfig(const AArgs: TArray<string>);
begin
  if (Length(AArgs) >= 4) and SameText(AArgs[1], 'delphi') and SameText(AArgs[2], 'use') then
  begin
    var LConfig := FConfigService.Load;
    try
      LConfig.DelphiPath := AArgs[3];
      FConfigService.Save(LConfig);
      FLogger.Log(TBoss4DLogLevel.Info, 'âœ… Caminho do Delphi atualizado para: %s', [LConfig.DelphiPath]);
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
        'âœ… Configuracao git shallow definida para: %s',
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
        FLogger.Log(TBoss4DLogLevel.Info, 'âœ… Token de autenticacao do GitHub configurado com sucesso.');
      end
      else if SameText(AArgs[2], 'gitlab') then
      begin
        LConfig.GitLabToken := AArgs[3];
        FConfigService.Save(LConfig);
        FLogger.Log(TBoss4DLogLevel.Info, 'âœ… Token de autenticacao do GitLab configurado com sucesso.');
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
  LPackage: TBoss4DPackage;
  LBuildDoctor: TBoss4DBuildDoctor;
  LBuildResult: TBoss4DBuildDoctorResult;
  LRegistrationService: TBoss4DIDERegistrationService;
  LLevel: TBoss4DLogLevel;
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

  if not FPackageRepo.Exists(GetBossFile) then
    Exit;
  LPackage := FPackageRepo.Load(GetBossFile);
  try
    LRegistrationService := TBoss4DIDERegistrationService.Create(
      TBoss4DWindowsIDERegistryStore.Create,
      TPath.Combine(GetBossHome, 'ide-registrations.json'));
    try
      LBuildDoctor := TBoss4DBuildDoctor.Create(FRegistry,
        function: TArray<string>
        begin
          Result := LRegistrationService.FindDrift;
        end);
      try
        LBuildResult := LBuildDoctor.Diagnose(LPackage, GetCurrentDir);
        try
          if LBuildResult.Issues.Count = 0 then
            FLogger.Log(TBoss4DLogLevel.Info,
              '[OK] Matriz, grafo, outputs e registros IDE consistentes.')
          else
            for var LIssue in LBuildResult.Issues do
            begin
              case LIssue.Severity of
                TBoss4DDoctorSeverity.Error:
                  LLevel := TBoss4DLogLevel.Error;
                TBoss4DDoctorSeverity.Warning:
                  LLevel := TBoss4DLogLevel.Warning;
              else
                LLevel := TBoss4DLogLevel.Info;
              end;
              FLogger.Log(LLevel, '[%s] %s Acao: %s',
                [LIssue.Code, LIssue.Message, LIssue.Remediation]);
            end;
        finally
          LBuildResult.Free;
        end;
      finally
        LBuildDoctor.Free;
      end;
    finally
      LRegistrationService.Free;
    end;
  finally
    LPackage.Free;
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
  LTempCloneDir := TPath.Combine(TPath.Combine(GetBossHome, 'temp_plugins'),
    LDep.StorageName);
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
    LIDEIntegration.RegisterDesignTimePackage(LDestBPL, LPluginName + ' - IDE Extension');

    FLogger.Log(TBoss4DLogLevel.Info, 'ðŸš€ Plugin "%s" instalado e registrado com sucesso!', [LPluginName]);
  finally
    if TDirectory.Exists(LTempCloneDir) then
      TDirectory.Delete(LTempCloneDir, True);
    LLock.Free;
    LDep.Free;
    LIDEIntegration.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleGetIt(const AArgs: TArray<string>);
var
  LGetItService: TBoss4DGetItBridgeService;
begin
  if Length(AArgs) < 2 then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando getit.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Uso:');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d getit install <pacote>');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d getit mode-online');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d getit mode-offline');
    Exit;
  end;

  LGetItService := TBoss4DGetItBridgeService.Create(FRegistry, FLogger);
  try
    if SameText(AArgs[1], 'install') then
    begin
      if Length(AArgs) < 3 then
        raise Exception.Create('Informe o nome do pacote para instalar.');
      LGetItService.InstallPackage(AArgs[2]);
    end
    else if SameText(AArgs[1], 'mode-online') then
    begin
      LGetItService.SetGetItMode(True);
    end
    else if SameText(AArgs[1], 'mode-offline') then
    begin
      LGetItService.SetGetItMode(False);
    end
    else
    begin
      FLogger.Log(TBoss4DLogLevel.Warning, 'Subcomando getit invalido: ' + AArgs[1]);
    end;
  finally
    LGetItService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleClean(const AArgs: TArray<string>);
var
  LCleanService: TBoss4DCleanService;
begin
  LCleanService := TBoss4DCleanService.Create(FLogger);
  try
    LCleanService.Execute;
  finally
    LCleanService.Free;
  end;
end;

procedure TBoss4DCommandLineParser.HandleNew(const AArgs: TArray<string>);
var
  LTemplate, LName, LTargetPath: string;
  LService: TBoss4DScaffoldService;
begin
  if Length(AArgs) < 3 then
    raise EArgumentException.Create(
      'Uso: boss4d new <template> <nome> [--path <diretorio>]');
  LTemplate := AArgs[1];
  LName := AArgs[2];
  LTargetPath := TPath.Combine(GetCurrentDir, LName);
  for var I := 3 to Length(AArgs) - 1 do
    if SameText(AArgs[I], '--path') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um diretorio para --path.');
      LTargetPath := AArgs[I + 1];
      Break;
    end;
  LService := TBoss4DScaffoldService.Create(FPackageRepo, FLogger);
  try
    LService.Execute(LTemplate, LName, LTargetPath);
  finally
    LService.Free;
  end;
end;

function TBoss4DCommandLineParser.ParseSbomArguments(
  const AArgs: TArray<string>): TBoss4DSbomCommandOptions;
var
  I: Integer;
begin
  Result := Default(TBoss4DSbomCommandOptions);
  Result.Format := 'cyclonedx';
  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--format') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um valor para --format.');
      Result.Format := AArgs[I + 1].ToLower;
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--output') or SameText(AArgs[I], '-o') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um arquivo para --output.');
      Result.OutputPath := AArgs[I + 1];
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--strict') then
    begin
      Result.Options.StrictMode := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--validate') then
    begin
      Result.Options.ValidateOutput := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--reproducible') then
    begin
      Result.Options.ReproducibleOutput := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--lock-only') then
    begin
      Result.Options.LockOnly := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--include-getit') then
    begin
      Result.IncludeGetIt := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--include-toolchain') then
    begin
      Result.IncludeToolchain := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--include-artifacts') then
    begin
      Result.IncludeArtifacts := True;
      Inc(I);
    end
    else if SameText(AArgs[I], '--vex') or
            SameText(AArgs[I], '--attestation-output') or
            SameText(AArgs[I], '--verify-attestation') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um arquivo para ' + AArgs[I] + '.');
      if SameText(AArgs[I], '--vex') then Result.VexPath := AArgs[I + 1]
      else if SameText(AArgs[I], '--attestation-output') then Result.AttestationOutput := AArgs[I + 1]
      else Result.VerifyAttestation := AArgs[I + 1];
      Inc(I, 2);
    end
    else if SameText(AArgs[I], '--type') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create('Informe um valor para --type.');
      if SameText(AArgs[I + 1], 'application') then
        Result.Options.RootComponentType := ApplicationComponent
      else if SameText(AArgs[I + 1], 'library') then
        Result.Options.RootComponentType := LibraryComponent
      else if SameText(AArgs[I + 1], 'framework') then
        Result.Options.RootComponentType := FrameworkComponent
      else
        raise EArgumentException.Create('Tipo SBOM invalido: ' + AArgs[I + 1]);
      Result.Options.HasRootComponentType := True;
      Inc(I, 2);
    end
    else
      raise EArgumentException.Create('Opcao desconhecida para sbom: ' + AArgs[I]);
  end;

  if (Result.Format <> 'cyclonedx') and (Result.Format <> 'spdx') then
    raise EArgumentException.Create('Formato SBOM ainda nao suportado: ' + Result.Format);
  if (Result.Format = 'spdx') and not Result.VexPath.IsEmpty then
    raise EArgumentException.Create('--vex requer CycloneDX; SPDX 2.3 nao possui perfil VEX.');
  if Result.Options.LockOnly and (Result.IncludeGetIt or
     Result.IncludeToolchain or Result.IncludeArtifacts) then
    raise EArgumentException.Create('--lock-only nao pode ser combinado com coletores de ambiente.');
  Result.Options.OutputFormat := Result.Format;
end;

procedure TBoss4DCommandLineParser.HandleSbom(const AArgs: TArray<string>);
var
  LCommandOptions: TBoss4DSbomCommandOptions;
  LLockRepository: IBoss4DLockRepository;
  LWriter: IBoss4DSbomWriter;
  LService: TBoss4DSbomService;
  LContent: string;
  LEncoding: TEncoding;
begin
  LCommandOptions := ParseSbomArguments(AArgs);

  LLockRepository := TBoss4DLockJsonRepository.Create;
  if LCommandOptions.Format = 'spdx' then
    LWriter := TBoss4DSpdxWriter.Create
  else
    LWriter := TBoss4DCycloneDXWriter.Create;
  LService := TBoss4DSbomService.Create(FPackageRepo, LLockRepository, LWriter);
  try
    if LCommandOptions.IncludeGetIt then
      LService.AddCollector(TBoss4DGetItSbomCollector.Create(FRegistry));
    if LCommandOptions.IncludeToolchain then
      LService.AddCollector(TBoss4DToolchainSbomCollector.Create(FRegistry));
    if LCommandOptions.IncludeArtifacts then
      LService.AddCollector(TBoss4DArtifactSbomCollector.Create);
    if not LCommandOptions.VexPath.IsEmpty then
      LService.AddTransformer(TBoss4DOfflineVexTransformer.Create(
        TPath.GetFullPath(LCommandOptions.VexPath)));
    LContent := LService.Generate(GetBossFile,
      TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK), LCommandOptions.Options);
    var LAttestor: IBoss4DSbomAttestor := TBoss4DSbomSha256Attestor.Create;
    if not LCommandOptions.VerifyAttestation.IsEmpty then
    begin
      var LAttestationError: string;
      if not LAttestor.VerifyAttestation(LContent,
        TFile.ReadAllText(TPath.GetFullPath(LCommandOptions.VerifyAttestation), TEncoding.UTF8),
        LAttestationError) then
        raise EBoss4DSbomValidation.Create('Atestacao invalida: ' + LAttestationError);
    end;
    if not LCommandOptions.AttestationOutput.IsEmpty then
    begin
      var LAttestationPath := TPath.GetFullPath(LCommandOptions.AttestationOutput);
      var LAttestationDirectory := TPath.GetDirectoryName(LAttestationPath);
      if not LAttestationDirectory.IsEmpty and not TDirectory.Exists(LAttestationDirectory) then
        TDirectory.CreateDirectory(LAttestationDirectory);
      var LAttestationEncoding := TUTF8Encoding.Create(False);
      try
        TFile.WriteAllText(LAttestationPath,
          LAttestor.CreateAttestation(LContent, LCommandOptions.Format), LAttestationEncoding);
      finally
        LAttestationEncoding.Free;
      end;
    end;
    if LCommandOptions.OutputPath.IsEmpty then
      System.Write(LContent)
    else
    begin
      LCommandOptions.OutputPath := TPath.GetFullPath(LCommandOptions.OutputPath);
      var LOutputDirectory := TPath.GetDirectoryName(LCommandOptions.OutputPath);
      if not LOutputDirectory.IsEmpty and not TDirectory.Exists(LOutputDirectory) then
        TDirectory.CreateDirectory(LOutputDirectory);
      LEncoding := TUTF8Encoding.Create(False);
      try
        TFile.WriteAllText(LCommandOptions.OutputPath, LContent, LEncoding);
      finally
        LEncoding.Free;
      end;
      if LCommandOptions.Format = 'spdx' then
        FLogger.Log(TBoss4DLogLevel.Info, 'SBOM SPDX 2.3 gerado em: ' + LCommandOptions.OutputPath)
      else
        FLogger.Log(TBoss4DLogLevel.Info, 'SBOM CycloneDX 1.7 gerado em: ' + LCommandOptions.OutputPath);
    end;
  finally
    LService.Free;
  end;
end;

end.
