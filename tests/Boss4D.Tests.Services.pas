unit Boss4D.Tests.Services;

interface

uses
  DUnitX.TestFramework, System.Generics.Collections, Boss4D.Core.Ports;

type
  TCredentialStoreMock = class(TInterfacedObject, IBoss4DCredentialStore)
  private
    FSecrets: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetSecret(const AName, AValue: string);
    function GetSecret(const AName: string): string;
    procedure DeleteSecret(const AName: string);
  end;

  { MockLogger simples para nao poluir o console de testes e capturar saidas }
  TTestLogger = class(TInterfacedObject, IBoss4DLogger)
  private
    FLastLogMessage: string;
  public
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string); overload;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const); overload;
    procedure SetDebugMode(const AEnabled: Boolean);

    property LastLogMessage: string read FLastLogMessage write FLastLogMessage;
  end;

  [TestFixture]
  TTestsServices = class
  private
    FTempDir: string;
    FPrevCurrentDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestInitService;

    [Test]
    procedure TestConfigService;

    [Test]
    procedure TestInstallService;

    [Test]
    procedure TestInstallBranchDependency;

    [Test]
    procedure TestDependencyLifecycleCommands;

    [Test]
    procedure TestInstallTransactionRollback;

    [Test]
    procedure TestLockedOfflineAndCI;

    [Test]
    procedure TestLockedRejectsManifestDrift;

    [Test]
    procedure TestDevelopmentDependencyScopesAndProduction;

    [Test]
    procedure TestAuditOsvCachePolicyAndVex;

    [Test]
    procedure TestGitSignatureTrustPolicy;

    [Test]
    procedure TestPackageIndexRegistrySearchAndInfo;

    [Test]
    procedure TestGitHubDependencySubmission;

    [Test]
    procedure TestPublishDryRunAndGates;

    [Test]
    procedure TestCompiledArtifactCacheIsolation;

    [Test]
    procedure TestCLICommandLineParser;

    [Test]
    procedure TestCompilerAutodetectAndOverride;

    [Test]
    procedure TestCacheService;

    [Test]
    procedure TestRunService;

    [Test]
    procedure TestDoctorService;

    [Test]
    procedure TestLicenseService;

    [Test]
    procedure TestChecksumVerification;

    [Test]
    procedure TestTreeService;

    [Test]
    procedure TestOutdatedService;

    [Test]
    procedure TestConfigAuthAndPrivateRepos;

    [Test]
    procedure TestMultiplatformCompilation;

    [Test]
    procedure TestToolchainAndDeclaredProjects;

    [Test]
    procedure TestDeclaredProjectRejectsTraversal;

    [Test]
    procedure TestInstallIntegratesDeclaredLazarusPaths;

    [Test]
    procedure TestInstallDiscoversRootLazarusProject;

    [Test]
    procedure TestIDEIntegration;

    [Test]
    procedure TestToolGlobalInstallation;

    [Test]
    procedure TestIDEIntegrationPackages;

    [Test]
    procedure TestToolLifecycle;

    [Test]
    procedure TestPluginInstallation;

    [Test]
    procedure TestWorkspacesMonorepos;

    [Test]
    procedure TestGetItBridge;

    [Test]
    procedure TestDCUMegafoldersStructure;

    [Test]
    procedure TestAutodetectDelphiVersionFromDproj;

    [Test]
    procedure TestIDEWizardInitialization;

    [Test]
    procedure TestCleanService;

    [Test]
    procedure TestScaffoldService;

    [Test]
    procedure TestScaffoldPresets;

    [Test]
    procedure TestSourceNormalizer;

    [Test]
    procedure TestPackageRequiresPreservesConditionals;
    [Test]
    procedure TestPackageRequiresPreservesSpacing;
    [Test]
    procedure TestPackageRequiresWithTrailingComments;
    [Test]
    procedure TestPackageRequiresWithMultipleBlocks;
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils,
  System.RegularExpressions,
  System.Win.Registry,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Consts, Boss4D.Core.Domain.Env, Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Config, Boss4D.Core.Services.Install, Boss4D.CLI.Parser,
  Boss4D.Adapters.Json, Boss4D.Adapters.Compiler, Boss4D.Tests.Mocks,
  Boss4D.Core.Services.Cache, Boss4D.Core.Services.Run,
  Boss4D.Core.Services.Doctor, Boss4D.Core.Services.License,
  Boss4D.Core.Services.Tree, Boss4D.Core.Services.Outdated,
  Boss4D.Core.Services.IDEIntegration, Boss4D.Core.Services.Tool, Boss4D.Core.Services.Workspace, Boss4D.Core.Services.GetIt,
  Boss4D.Core.Services.Clean, Boss4D.Core.Services.Scaffold,
  Boss4D.Core.Services.SourceNormalizer,
  Boss4D.Core.Services.Dependencies,
  Boss4D.Core.Services.Audit,
  Boss4D.Core.Services.PackageIndex,
  Boss4D.Core.Services.DependencySubmission,
  Boss4D.Core.Services.Publish,
  Boss4D.Core.Services.ArtifactCache,
  Boss4D.Core.Services.PackageManifest, Boss4D.IDE.Wizard;

{ TTestLogger }

constructor TCredentialStoreMock.Create;
begin
  inherited Create;
  FSecrets := TDictionary<string, string>.Create;
end;

destructor TCredentialStoreMock.Destroy;
begin
  FSecrets.Free;
  inherited Destroy;
end;

procedure TCredentialStoreMock.SetSecret(const AName, AValue: string);
begin
  FSecrets.AddOrSetValue(AName, AValue);
end;

function TCredentialStoreMock.GetSecret(const AName: string): string;
begin
  if not FSecrets.TryGetValue(AName, Result) then
    Result := '';
end;

procedure TCredentialStoreMock.DeleteSecret(const AName: string);
begin
  FSecrets.Remove(AName);
end;

procedure TTestLogger.Log(const ALevel: TBoss4DLogLevel; const AMessage: string);
begin
  LastLogMessage := LastLogMessage + AMessage + sLineBreak;
end;

procedure TTestLogger.Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const);
begin
  LastLogMessage := LastLogMessage + Format(AMessage, AArgs) + sLineBreak;
end;

procedure TTestLogger.SetDebugMode(const AEnabled: Boolean);
begin
  // No-op
end;

{ TTestsServices }

procedure TTestsServices.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'Boss4DServicesTests_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);

  // Altera o diretorio corrente para a pasta temporaria para isolar criacao de arquivos
  FPrevCurrentDir := TDirectory.GetCurrentDirectory;
  TDirectory.SetCurrentDirectory(FTempDir);

  // Define variavel de ambiente BOSS_HOME para nossa pasta temporaria
  SetEnvironmentVariable('BOSS_HOME', PChar(TPath.Combine(FTempDir, '.boss')));
end;

procedure TTestsServices.TearDown;
begin
  TDirectory.SetCurrentDirectory(FPrevCurrentDir);
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestsServices.TestInitService;
var
  LInit: TBoss4DInitService;
  LPkgPath: string;
  LLogger: IBoss4DLogger;
  LPackageRepo: IBoss4DPackageRepository;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;

  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  try
    LInit.Execute(True); // Quiet mode
    LPkgPath := GetBossFile;

    Assert.IsTrue(TFile.Exists(LPkgPath));

    var LPkg := LPackageRepo.Load(LPkgPath);
    try
      // Nome do pacote deve coincidir com o nome da pasta temporaria criada
      Assert.AreEqual(TPath.GetFileName(FTempDir).ToLower, LPkg.Name);
      Assert.AreEqual('1.0.0', LPkg.Version);
    finally
      LPkg.Free;
    end;
  finally
    LInit.Free;
  end;
end;

procedure TTestsServices.TestConfigService;
var
  LConfigService: TBoss4DConfigService;
  LConfig, LLoaded: TBoss4DGlobalConfig;
  LLogger: IBoss4DLogger;
begin
  LLogger := TTestLogger.Create;
  LConfigService := TBoss4DConfigService.Create(LLogger);
  LConfig := TBoss4DGlobalConfig.Create;
  try
    LConfig.DelphiPath := 'C:\Delphi13';
    LConfig.GitShallow := True;
    LConfigService.Save(LConfig);

    LLoaded := LConfigService.Load;
    try
      Assert.AreEqual('C:\Delphi13', LLoaded.DelphiPath);
      Assert.IsTrue(LLoaded.GitShallow);
    finally
      LLoaded.Free;
    end;
  finally
    LConfig.Free;
    LConfigService.Free;
  end;
end;

procedure TTestsServices.TestInstallService;
var
  LInstall: TBoss4DInstallService;
  LInit: TBoss4DInitService;
  LLockPath: string;
  LLock: TBoss4DLock;
  LLogger: IBoss4DLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitMock: TGitClientMock;
  LHttpMock: THttpClientMock;
  LCompilerMock: TCompilerMock;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;

  LGitMock := TGitClientMock.Create;
  LHttpMock := THttpClientMock.Create;
  LCompilerMock := TCompilerMock.Create;

  // 1. Cria um boss.json inicializado
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  try
    LInit.Execute(True);
  finally
    LInit.Free;
  end;

  // Pre-configura as tags simuladas no Git Mock
  LGitMock.AddMockTags('github.com/hashload/horse', TArray<string>.Create('v3.0.0', 'v3.1.0', 'v3.2.0'));

  // 2. Instancia e roda o Instalador
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGitMock, LHttpMock, LCompilerMock, LLogger);
  try
    // Instala dependÃªncia especÃ­fica (boss4d install github.com/hashload/horse@^3.1.0)
    LInstall.Execute('github.com/hashload/horse@^3.1.0');

    // Valida se o diretÃ³rio do mÃ³dulo foi criado em modules/horse
    var LInstalledDep := TBoss4DDependency.Create('github.com/hashload/horse', '');
    try
      var LModuleDir := TPath.Combine(GetModulesDir, LInstalledDep.StorageName);
      Assert.IsTrue(TDirectory.Exists(LModuleDir));
    finally
      LInstalledDep.Free;
    end;

    // Valida se o boss-lock.json foi gerado e travado na versÃ£o resolvida
    LLockPath := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);
    Assert.IsTrue(TFile.Exists(LLockPath));

    LLock := LLockRepo.Load(LLockPath);
    try
      var LLockedDep: TBoss4DLockedDependency;
      Assert.IsTrue(LLock.GetInstalled(TBoss4DDependency.Create('github.com/hashload/horse', ''), LLockedDep));
      Assert.AreEqual('3.2.0', LLockedDep.Version); // v3.2.0 atende ^3.1.0 e Ã© a mais recente!
      Assert.AreEqual<Integer>(3, LLock.LockVersion);
      Assert.AreEqual('https://github.com/hashload/horse', LLockedDep.Repository);
      Assert.AreEqual('0123456789abcdef0123456789abcdef01234567', LLockedDep.Revision);
      Assert.AreEqual('3.2.0', LLockedDep.ResolvedFrom);
      Assert.AreEqual('SHA-256', LLockedDep.ChecksumAlgorithm);
    finally
      LLock.Free;
    end;

  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestInstallBranchDependency;
var
  LInstall: TBoss4DInstallService;
  LInit: TBoss4DInitService;
  LLockPath: string;
  LLock: TBoss4DLock;
  LLogger: IBoss4DLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitMock: TGitClientMock;
  LHttpMock: THttpClientMock;
  LCompilerMock: TCompilerMock;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;

  LGitMock := TGitClientMock.Create;
  LHttpMock := THttpClientMock.Create;
  LCompilerMock := TCompilerMock.Create;

  // 1. Cria um boss.json inicializado
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  try
    LInit.Execute(True);
  finally
    LInit.Free;
  end;

  // 2. Instancia e roda o Instalador passando a branch master (sem tags associadas no Mock)
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGitMock, LHttpMock, LCompilerMock, LLogger);
  try
    LInstall.Execute('github.com/hashload/horse@master');

    // Valida se o diretorio do modulo foi criado
    var LInstalledDep := TBoss4DDependency.Create('github.com/hashload/horse', '');
    try
      var LModuleDir := TPath.Combine(GetModulesDir, LInstalledDep.StorageName);
      Assert.IsTrue(TDirectory.Exists(LModuleDir));
    finally
      LInstalledDep.Free;
    end;

    // Valida se o boss-lock.json foi gerado e travado no branch literal
    LLockPath := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);
    Assert.IsTrue(TFile.Exists(LLockPath));

    LLock := LLockRepo.Load(LLockPath);
    try
      var LLockedDep: TBoss4DLockedDependency;
      Assert.IsTrue(LLock.GetInstalled(TBoss4DDependency.Create('github.com/hashload/horse', ''), LLockedDep));
      Assert.AreEqual('master', LLockedDep.Version);
    finally
      LLock.Free;
    end;

  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestDependencyLifecycleCommands;
var
  LInit: TBoss4DInitService;
  LInstall: TBoss4DInstallService;
  LConfig: TBoss4DConfigService;
  LParser: TBoss4DCommandLineParser;
  LLogger: TTestLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitMock: TGitClientMock;
  LLock: TBoss4DLock;
  LRootLocked: TBoss4DLockedDependency;
  LTransitive: TBoss4DDependency;
  LPkg: TBoss4DPackage;
  LRootKey, LTransitiveKey: string;
  LRootModulePath: string;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitMock := TGitClientMock.Create;
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGitMock,
    THttpClientMock.Create, TCompilerMock.Create, LLogger);
  LConfig := TBoss4DConfigService.Create(LLogger);
  LParser := TBoss4DCommandLineParser.Create(LLogger, LInit, LInstall,
    LConfig, LPackageRepo, TRegistryMock.Create);
  try
    LInit.Execute(True);
    LParser.ParseAndExecute(TArray<string>.Create('add',
      'github.com/hashload/horse@^3.0.0'));

    LPkg := LPackageRepo.Load(GetBossFile);
    try
      Assert.AreEqual<Integer>(1, LPkg.Dependencies.Count);
    finally
      LPkg.Free;
    end;

    LLock := LLockRepo.Load(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK));
    LTransitive := TBoss4DDependency.Create(
      'github.com/example/transitive', '1.0.0');
    try
      LTransitiveKey := LTransitive.GetKey;
      LLock.AddDependency(LTransitive, '1.0.0', 'transitive-hash');
      Assert.IsTrue(LLock.RootDependencies.Count > 0,
        'O add deve registrar a raiz no lock.');
      LRootKey := LLock.RootDependencies[0];
      Assert.IsTrue(LLock.Installed.TryGetValue(LRootKey, LRootLocked),
        'A dependencia raiz deve existir no lock: ' + LRootKey);
      LRootLocked.Dependencies.Add(LTransitive.GetKey);
      LLockRepo.Save(LLock, TPath.Combine(FTempDir, FILE_PACKAGE_LOCK));
    finally
      LTransitive.Free;
      LLock.Free;
    end;

    LLogger.LastLogMessage := '';
    LParser.ParseAndExecute(TArray<string>.Create('list'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('(direct, runtime)'),
      'list nao classificou dependencia direta: ' + LLogger.LastLogMessage);
    Assert.IsTrue(LLogger.LastLogMessage.Contains('(transitive, runtime)'),
      'list nao classificou dependencia transitiva: ' + LLogger.LastLogMessage);

    LLogger.LastLogMessage := '';
    LParser.ParseAndExecute(TArray<string>.Create('why', 'transitive'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains(
      LRootKey + ' -> ' + LTransitiveKey),
      'why nao retornou o caminho esperado: ' + LLogger.LastLogMessage);

    LParser.ParseAndExecute(TArray<string>.Create('update', 'horse'));
    var LRootDep := TBoss4DDependency.Create(
      'github.com/hashload/horse', '');
    try
      LRootModulePath := TPath.Combine(GetModulesDir, LRootDep.StorageName);
    finally
      LRootDep.Free;
    end;
    Assert.IsTrue(TDirectory.Exists(LRootModulePath));
    LParser.ParseAndExecute(TArray<string>.Create('remove', 'horse'));
    Assert.IsFalse(TDirectory.Exists(LRootModulePath),
      'remove deve excluir o modulo que deixou de ser alcancavel.');
    LPkg := LPackageRepo.Load(GetBossFile);
    try
      Assert.AreEqual<Integer>(0, LPkg.Dependencies.Count);
    finally
      LPkg.Free;
    end;
    LLock := LLockRepo.Load(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK));
    try
      Assert.AreEqual<Integer>(0, LLock.Installed.Count,
        'A remocao deve podar dependencias transitivas orfas.');
    finally
      LLock.Free;
    end;
  finally
    LParser.Free;
    LConfig.Free;
    LInstall.Free;
    LInit.Free;
  end;
end;

procedure TTestsServices.TestInstallTransactionRollback;
var
  LInit: TBoss4DInitService;
  LInstall: TBoss4DInstallService;
  LLogger: IBoss4DLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitMock: TGitClientMock;
  LOriginalManifest: string;
  LMarkerPath: string;
  LRaised: Boolean;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  try
    LInit.Execute(True);
  finally
    LInit.Free;
  end;
  LOriginalManifest := TFile.ReadAllText(GetBossFile, TEncoding.UTF8);
  TDirectory.CreateDirectory(GetModulesDir);
  LMarkerPath := TPath.Combine(GetModulesDir, 'existing.txt');
  TFile.WriteAllText(LMarkerPath, 'preserve');

  LGitMock := TGitClientMock.Create;
  LGitMock.FailCheckout := True;
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGitMock,
    THttpClientMock.Create, TCompilerMock.Create, LLogger);
  LRaised := False;
  try
    try
      LInstall.Execute('github.com/example/failing@1.0.0');
    except
      on E: Exception do
        LRaised := True;
    end;
  finally
    LInstall.Free;
  end;

  Assert.IsTrue(LRaised);
  Assert.AreEqual(LOriginalManifest,
    TFile.ReadAllText(GetBossFile, TEncoding.UTF8));
  Assert.IsFalse(TFile.Exists(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK)));
  Assert.IsTrue(TFile.Exists(LMarkerPath));
  Assert.AreEqual('preserve', TFile.ReadAllText(LMarkerPath));
end;

procedure TTestsServices.TestLockedOfflineAndCI;
var
  LInit: TBoss4DInitService;
  LInstall: TBoss4DInstallService;
  LConfig: TBoss4DConfigService;
  LParser: TBoss4DCommandLineParser;
  LLogger: TTestLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitMock: TGitClientMock;
  LPkg: TBoss4DPackage;
  LOptions: TBoss4DInstallOptions;
  LLockBefore, LLockAfter: string;
  LNetworkCalls: Integer;
  LStalePath: string;
  LRaised: Boolean;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitMock := TGitClientMock.Create;
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGitMock,
    THttpClientMock.Create, TCompilerMock.Create, LLogger);
  LConfig := TBoss4DConfigService.Create(LLogger);
  LParser := TBoss4DCommandLineParser.Create(LLogger, LInit, LInstall,
    LConfig, LPackageRepo, TRegistryMock.Create);
  try
    LInit.Execute(True);
    LPkg := LPackageRepo.Load(GetBossFile);
    try
      LPkg.AddDependency('github.com/hashload/horse', '^3.0.0');
      LPackageRepo.Save(LPkg, GetBossFile);
    finally
      LPkg.Free;
    end;

    LOptions := Default(TBoss4DInstallOptions);
    LOptions.Offline := True;
    LRaised := False;
    try
      LInstall.Execute(LOptions);
    except
      on E: Exception do LRaised := True;
    end;
    Assert.IsTrue(LRaised,
      '--offline deve recusar dependencia sem cache local.');
    Assert.IsFalse(TFile.Exists(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK)));

    LInstall.Execute;
    LLockBefore := TFile.ReadAllText(
      TPath.Combine(FTempDir, FILE_PACKAGE_LOCK), TEncoding.UTF8);
    LNetworkCalls := LGitMock.NetworkCallCount;

    LParser.ParseAndExecute(TArray<string>.Create(
      'install', '--locked', '--offline'));
    LLockAfter := TFile.ReadAllText(
      TPath.Combine(FTempDir, FILE_PACKAGE_LOCK), TEncoding.UTF8);
    Assert.AreEqual(LLockBefore, LLockAfter,
      '--locked nao pode reescrever nem atualizar timestamp do lock.');
    Assert.AreEqual<Integer>(LNetworkCalls, LGitMock.NetworkCallCount,
      '--offline nao pode clonar nem atualizar o cache.');
    Assert.AreEqual('0123456789abcdef0123456789abcdef01234567',
      LGitMock.LastCheckoutVersion,
      '--locked deve fazer checkout da revisao exata.');

    LStalePath := TPath.Combine(GetModulesDir, 'stale.txt');
    TFile.WriteAllText(LStalePath, 'stale');
    LParser.ParseAndExecute(TArray<string>.Create('ci', '--offline'));
    Assert.IsFalse(TFile.Exists(LStalePath),
      'ci deve iniciar por uma arvore modules limpa.');
    Assert.AreEqual(LLockBefore, TFile.ReadAllText(
      TPath.Combine(FTempDir, FILE_PACKAGE_LOCK), TEncoding.UTF8));
  finally
    LParser.Free;
    LConfig.Free;
    LInstall.Free;
    LInit.Free;
  end;
end;

procedure TTestsServices.TestLockedRejectsManifestDrift;
var
  LInit: TBoss4DInitService;
  LInstall: TBoss4DInstallService;
  LLogger: IBoss4DLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LPkg: TBoss4DPackage;
  LOptions: TBoss4DInstallOptions;
  LLockBefore: string;
  LRaised: Boolean;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo,
    TGitClientMock.Create, THttpClientMock.Create, TCompilerMock.Create,
    LLogger);
  try
    LInit.Execute(True);
    LInstall.Execute('github.com/hashload/horse@^3.0.0');
    LLockBefore := TFile.ReadAllText(
      TPath.Combine(FTempDir, FILE_PACKAGE_LOCK), TEncoding.UTF8);
    LPkg := LPackageRepo.Load(GetBossFile);
    try
      LPkg.AddDependency('github.com/example/drift', '1.0.0');
      LPackageRepo.Save(LPkg, GetBossFile);
    finally
      LPkg.Free;
    end;

    LOptions := Default(TBoss4DInstallOptions);
    LOptions.Locked := True;
    LRaised := False;
    try
      LInstall.Execute(LOptions);
    except
      on E: Exception do LRaised := True;
    end;
    Assert.IsTrue(LRaised,
      '--locked deve recusar divergencia entre manifest e lock.');
    Assert.AreEqual(LLockBefore, TFile.ReadAllText(
      TPath.Combine(FTempDir, FILE_PACKAGE_LOCK), TEncoding.UTF8));
  finally
    LInstall.Free;
    LInit.Free;
  end;
end;

procedure TTestsServices.TestDevelopmentDependencyScopesAndProduction;
var
  LInit: TBoss4DInitService;
  LInstall: TBoss4DInstallService;
  LConfig: TBoss4DConfigService;
  LParser: TBoss4DCommandLineParser;
  LLogger: TTestLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDevDep, LRuntimeDep: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LCdxPath, LSpdxPath: string;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo,
    TGitClientMock.Create, THttpClientMock.Create, TCompilerMock.Create,
    LLogger);
  LConfig := TBoss4DConfigService.Create(LLogger);
  LParser := TBoss4DCommandLineParser.Create(LLogger, LInit, LInstall,
    LConfig, LPackageRepo, TRegistryMock.Create);
  LDevDep := TBoss4DDependency.Create('github.com/example/test-kit', '');
  LRuntimeDep := TBoss4DDependency.Create('github.com/hashload/horse', '');
  try
    LInit.Execute(True);
    LParser.ParseAndExecute(TArray<string>.Create('add',
      'github.com/hashload/horse@^3.0.0'));
    LParser.ParseAndExecute(TArray<string>.Create('add',
      'github.com/example/test-kit@1.0.0', '--dev'));

    LPkg := LPackageRepo.Load(GetBossFile);
    try
      Assert.AreEqual<Integer>(1, LPkg.Dependencies.Count);
      Assert.AreEqual<Integer>(1, LPkg.DevDependencies.Count);
    finally
      LPkg.Free;
    end;
    LLock := LLockRepo.Load(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK));
    try
      Assert.AreEqual<Integer>(1, LLock.RootDevDependencies.Count);
      Assert.IsTrue(LLock.GetInstalled(LDevDep, LLocked),
        'Dependencia de desenvolvimento ausente do lock.');
      Assert.AreEqual('development', LLocked.Scope);
      Assert.IsTrue(LLock.GetInstalled(LRuntimeDep, LLocked),
        'Dependencia de runtime ausente do lock.');
      Assert.AreEqual('runtime', LLocked.Scope);
    finally
      LLock.Free;
    end;

    LCdxPath := TPath.Combine(FTempDir, 'scoped.cdx.json');
    LSpdxPath := TPath.Combine(FTempDir, 'scoped.spdx.json');
    LParser.ParseAndExecute(TArray<string>.Create('sbom', '--format',
      'cyclonedx', '--output', LCdxPath, '--lock-only'));
    LParser.ParseAndExecute(TArray<string>.Create('sbom', '--format',
      'spdx', '--output', LSpdxPath, '--lock-only'));
    var LCdxContent := TFile.ReadAllText(LCdxPath, TEncoding.UTF8);
    var LSpdxContent := TFile.ReadAllText(LSpdxPath, TEncoding.UTF8);
    Assert.IsTrue(LCdxContent.Contains('"name": "boss4d:scope"'),
      'CycloneDX nao exportou a propriedade de escopo: ' + LCdxContent);
    Assert.IsTrue(LCdxContent.Contains('"value": "development"'),
      'CycloneDX nao exportou o escopo development: ' + LCdxContent);
    Assert.IsTrue(LSpdxContent.Contains(
      '"comment":"boss4d:scope=development"'),
      'SPDX nao exportou o escopo development: ' + LSpdxContent);

    LParser.ParseAndExecute(TArray<string>.Create(
      'ci', '--production'));
    Assert.IsTrue(TDirectory.Exists(TPath.Combine(
      GetModulesDir, LRuntimeDep.StorageName)),
      'CI de producao removeu dependencia de runtime.');
    Assert.IsFalse(TDirectory.Exists(TPath.Combine(
      GetModulesDir, LDevDep.StorageName)),
      'CI de producao instalou dependencia de desenvolvimento.');
  finally
    LRuntimeDep.Free;
    LDevDep.Free;
    LParser.Free;
    LConfig.Free;
    LInstall.Free;
    LInit.Free;
  end;
end;

procedure TTestsServices.TestAuditOsvCachePolicyAndVex;
var
  LLockRepo: IBoss4DLockRepository;
  LLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LHttp: THttpClientMock;
  LService: TBoss4DAuditService;
  LOptions: TBoss4DAuditOptions;
  LSummary: TBoss4DAuditSummary;
  LLockPath, LVexPath: string;
  LRaised: Boolean;
begin
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LLockPath := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/example/vulnerable', '1.0.0');
  try
    LLock.AddDependency(LDep, '1.0.0', 'hash', 'checksum');
    Assert.IsTrue(LLock.GetInstalled(LDep, LLocked));
    LLocked.Revision := 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    LLockRepo.Save(LLock, LLockPath);
  finally
    LDep.Free;
    LLock.Free;
  end;

  LHttp := THttpClientMock.Create;
  LHttp.AddResponse('https://api.osv.dev/v1/query',
    '{"vulns":[{"id":"OSV-TEST-1","database_specific":{"severity":"HIGH"}}]}');
  LService := TBoss4DAuditService.Create(LLockRepo, LHttp,
    TTestLogger.Create);
  try
    LOptions := Default(TBoss4DAuditOptions);
    LOptions.CacheHours := 24;
    LOptions.FailOn := AuditCritical;
    LSummary := LService.Execute(LLockPath, LOptions);
    Assert.AreEqual<Integer>(1, LSummary.Vulnerabilities);
    Assert.AreEqual<Integer>(0, LSummary.PolicyViolations);

    LOptions.Offline := True;
    LOptions.FailOn := AuditHigh;
    LRaised := False;
    try
      LService.Execute(LLockPath, LOptions);
    except
      on E: EBoss4DAuditPolicy do LRaised := True;
    end;
    Assert.IsTrue(LRaised,
      'Politica high deve falhar usando a resposta do cache offline.');

    LVexPath := TPath.Combine(FTempDir, 'audit.vex.json');
    TFile.WriteAllText(LVexPath,
      '{"vulnerabilities":[{"id":"OSV-TEST-1","state":"not_affected"}]}',
      TEncoding.UTF8);
    LOptions.VexPath := LVexPath;
    LSummary := LService.Execute(LLockPath, LOptions);
    Assert.AreEqual<Integer>(1, LSummary.Suppressed);
    Assert.AreEqual<Integer>(0, LSummary.PolicyViolations);
  finally
    LService.Free;
  end;
end;

procedure TTestsServices.TestGitSignatureTrustPolicy;
var
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LPkg: TBoss4DPackage;
  LGit: TGitClientMock;
  LInstall: TBoss4DInstallService;
  LRaised: Boolean;
begin
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LPkg := TBoss4DPackage.Create;
  try
    LPkg.Name := 'signed-project';
    LPkg.Version := '1.0.0';
    LPkg.AddDependency('github.com/example/signed', 'v1.0.0');
    LPkg.Trust.RequireSignedCommits := True;
    LPkg.Trust.RequireSignedTags := True;
    LPkg.Trust.AllowedSigners.Add('release@example.com');
    LPackageRepo.Save(LPkg, GetBossFile);
  finally
    LPkg.Free;
  end;

  LGit := TGitClientMock.Create;
  LGit.Signer := 'intruder@example.com';
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGit,
    THttpClientMock.Create, TCompilerMock.Create, TTestLogger.Create);
  try
    LRaised := False;
    try
      LInstall.Execute;
    except
      on E: Exception do
      begin
        LRaised := True;
        Assert.IsTrue(E.Message.Contains('nao autorizado'));
      end;
    end;
    Assert.IsTrue(LRaised);
    Assert.IsFalse(TFile.Exists(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK)),
      'Falha de confiança deve fazer rollback do lock.');

    LGit.Signer := 'release@example.com';
    LInstall.Execute;
    Assert.IsTrue(TFile.Exists(TPath.Combine(FTempDir, FILE_PACKAGE_LOCK)));

    LGit.TagSignatureValid := False;
    LRaised := False;
    try
      LInstall.Execute;
    except
      on E: Exception do
      begin
        LRaised := True;
        Assert.IsTrue(E.Message.Contains('Tag sem assinatura valida'));
      end;
    end;
    Assert.IsTrue(LRaised);
  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestPackageIndexRegistrySearchAndInfo;
var
  LConfig: TBoss4DConfigService;
  LService: TBoss4DPackageIndexService;
  LIndexPath: string;
  LEntry: TBoss4DPackageIndexEntry;
begin
  LIndexPath := TPath.Combine(FTempDir, 'private-index.json');
  TFile.WriteAllText(LIndexPath,
    '{"schemaVersion":1,"packages":[{"name":"InternalLib","repository":' +
    '"git.example.test/team/internal","description":"Private package",' +
    '"version":"2.4.0","license":"MIT","artifact":' +
    '"https://packages.example/InternalLib-2.4.0.b4dpkg",' +
    '"sha256":"abc123"}]}', TEncoding.UTF8);
  LConfig := TBoss4DConfigService.Create(TTestLogger.Create);
  LService := TBoss4DPackageIndexService.Create(LConfig,
    THttpClientMock.Create, TTestLogger.Create);
  try
    LService.AddRegistry(LIndexPath);
    Assert.AreEqual<Integer>(1, Length(LService.ListRegistries));
    var LResults := LService.Search('private');
    try
      Assert.AreEqual<Integer>(1, LResults.Count);
      Assert.AreEqual('InternalLib', LResults[0].Name);
    finally
      LResults.Free;
    end;
    LEntry := LService.Info('InternalLib');
    try
      Assert.IsNotNull(LEntry);
      Assert.AreEqual('2.4.0', LEntry.LatestVersion);
      Assert.AreEqual('MIT', LEntry.License);
      Assert.AreEqual('https://packages.example/InternalLib-2.4.0.b4dpkg',
        LEntry.ArtifactUrl);
      Assert.AreEqual('abc123', LEntry.ArtifactDigest);
    finally
      LEntry.Free;
    end;
    LService.RemoveRegistry(LIndexPath);
    Assert.AreEqual<Integer>(0, Length(LService.ListRegistries));
  finally
    LService.Free;
    LConfig.Free;
  end;
end;

procedure TTestsServices.TestGitHubDependencySubmission;
var
  LLockRepo: IBoss4DLockRepository;
  LLock: TBoss4DLock;
  LRootDep, LChildDep: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LHttp: THttpClientMock;
  LService: TBoss4DDependencySubmissionService;
  LPayload, LLockPath: string;
begin
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LLock := TBoss4DLock.Create;
  LRootDep := TBoss4DDependency.Create('github.com/example/root', '1.0.0');
  LChildDep := TBoss4DDependency.Create('github.com/example/child', '2.0.0');
  LLockPath := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);
  try
    LLock.RootDependencies.Add(LRootDep.GetKey);
    LLock.AddDependency(LRootDep, '1.0.0', 'root');
    LLock.AddDependency(LChildDep, '2.0.0', 'child');
    Assert.IsTrue(LLock.GetInstalled(LRootDep, LLocked));
    LLocked.Dependencies.Add(LChildDep.GetKey);
    LLockRepo.Save(LLock, LLockPath);

    LHttp := THttpClientMock.Create;
    LHttp.AddResponse(
      'https://api.github.com/repos/example/project/dependency-graph/snapshots',
      '{"id":1}', 201);
    LService := TBoss4DDependencySubmissionService.Create(LLockRepo, LHttp);
    try
      LPayload := LService.BuildPayload(LLock,
        StringOfChar('a', 40), 'refs/heads/main', 'unit-test');
      Assert.IsTrue(LPayload.Contains('"version":0'));
      Assert.IsTrue(LPayload.Contains('"relationship":"direct"'));
      Assert.IsTrue(LPayload.Contains('"relationship":"indirect"'));
      Assert.IsTrue(LPayload.Contains('"scope":"runtime"'));
      LService.Submit(LLockPath, 'example/project', StringOfChar('a', 40),
        'refs/heads/main', 'secret-token', 'unit-test');
    finally
      LService.Free;
    end;
  finally
    LChildDep.Free;
    LRootDep.Free;
    LLock.Free;
  end;
end;

procedure TTestsServices.TestPublishDryRunAndGates;
var
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LPackage: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LLocked: TBoss4DLockedDependency;
  LHttp: THttpClientMock;
  LService: TBoss4DPublishService;
  LOptions: TBoss4DPublishOptions;
  LPackagePath, LLockPath, LPayload: string;
begin
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LPackagePath := TPath.Combine(FTempDir, FILE_PACKAGE);
  LLockPath := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);
  LPackage := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/example/runtime', '1.2.3');
  try
    LPackage.Name := 'publish-test';
    LPackage.Version := '1.0.0';
    LPackage.Description := 'Pacote de teste';
    LPackage.License := 'MIT';
    LPackageRepo.Save(LPackage, LPackagePath);

    LLock.HasRootMetadata := True;
    LLock.RootName := LPackage.Name;
    LLock.RootVersion := LPackage.Version;
    LLock.RootDependencies.Add(LDep.GetKey);
    LLock.AddDependency(LDep, '1.2.3', 'hash', 'sha256-value');
    Assert.IsTrue(LLock.GetInstalled(LDep, LLocked));
    LLocked.Revision := StringOfChar('a', 40);
    LLockRepo.Save(LLock, LLockPath);

    LHttp := THttpClientMock.Create;
    LHttp.AddResponse('https://registry.example/packages', '{"accepted":true}', 201);
    LService := TBoss4DPublishService.Create(
      LPackageRepo, LLockRepo, LHttp, TTestLogger.Create);
    try
      LOptions := Default(TBoss4DPublishOptions);
      LOptions.DryRun := True;
      LPayload := LService.Execute(LPackagePath, LLockPath, LOptions);
      Assert.IsTrue(LPayload.Contains('"name":"publish-test"'));
      Assert.IsTrue(LPayload.Contains('"checksum":"sha256-value"'));
      Assert.IsTrue(LPayload.Contains('"format":"boss4d-package-v1"'));
      Assert.IsTrue(LPayload.Contains('"sha256":'));
      Assert.IsTrue(LPayload.Contains('"content":'));
      Assert.AreEqual(0, LHttp.AuthorizedPostCount,
        'Dry-run nao pode realizar chamadas de publicacao.');

      LOptions.DryRun := False;
      LOptions.RegistryUrl := 'https://registry.example/';
      LOptions.Token := 'secret';
      LService.Execute(LPackagePath, LLockPath, LOptions);
      Assert.AreEqual(1, LHttp.AuthorizedPostCount);

      LLocked.Checksum := '';
      LLockRepo.Save(LLock, LLockPath);
      Assert.WillRaise(
        procedure
        begin
          LOptions.DryRun := True;
          LService.Execute(LPackagePath, LLockPath, LOptions);
        end,
        EBoss4DPublishGate);
    finally
      LService.Free;
    end;
  finally
    LDep.Free;
    LLock.Free;
    LPackage.Free;
  end;
end;

procedure TTestsServices.TestCompiledArtifactCacheIsolation;
var
  LService: TBoss4DArtifactCacheService;
  LDep: TBoss4DDependency;
  LBinDir, LArtifact: string;
begin
  LDep := TBoss4DDependency.Create('github.com/example/tool', '1.0.0');
  LService := TBoss4DArtifactCacheService.Create;
  try
    LBinDir := TPath.Combine(GetModulesDir,
      TPath.Combine(LDep.Name, FOLDER_BIN));
    TDirectory.CreateDirectory(LBinDir);
    LArtifact := TPath.Combine(LBinDir, 'tool.exe');
    TFile.WriteAllText(LArtifact, 'win32-delphi37');
    LService.Store(LDep, 'source-checksum', 'Win32', '37.0');
    TDirectory.Delete(LBinDir, True);
    Assert.IsTrue(LService.Restore(LDep, 'source-checksum',
      'Win32', '37.0'));
    Assert.AreEqual('win32-delphi37', TFile.ReadAllText(LArtifact));

    TDirectory.Delete(LBinDir, True);
    Assert.IsFalse(LService.Restore(LDep, 'source-checksum',
      'Win64', '37.0'), 'Plataformas nao podem compartilhar artefatos.');
    Assert.IsFalse(LService.Restore(LDep, 'source-checksum',
      'Win32', '36.0'), 'Compiladores nao podem compartilhar artefatos.');
  finally
    LService.Free;
    LDep.Free;
  end;
end;

procedure TTestsServices.TestCLICommandLineParser;
var
  LInit: TBoss4DInitService;
  LInstall: TBoss4DInstallService;
  LConfigService: TBoss4DConfigService;
  LParser: TBoss4DCommandLineParser;
  LLogger: TTestLogger;
  LPackageRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitMock: TGitClientMock;
  LHttpMock: THttpClientMock;
  LCompilerMock: TCompilerMock;
begin
  LLogger := TTestLogger.Create;
  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitMock := TGitClientMock.Create;
  LHttpMock := THttpClientMock.Create;
  LCompilerMock := TCompilerMock.Create;

  LInit := TBoss4DInitService.Create(LPackageRepo, LLogger);
  LInstall := TBoss4DInstallService.Create(LPackageRepo, LLockRepo, LGitMock, LHttpMock, LCompilerMock, LLogger);
  LConfigService := TBoss4DConfigService.Create(LLogger);

  LParser := TBoss4DCommandLineParser.Create(LLogger, LInit, LInstall, LConfigService, LPackageRepo, TRegistryMock.Create);
  try
    // Testa o comando "version"
    LParser.ParseAndExecute(TArray<string>.Create('version'));
    Assert.AreEqual('v1.4.0-delphi-native', LLogger.LastLogMessage.Trim);

    // Testa o comando "help"
    LParser.ParseAndExecute(TArray<string>.Create('-h'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('Uso:'));

    // Gera um SBOM por meio do parser real, sem escrever JSON no fluxo de logs.
    LInit.Execute(True);
    var LSbomLock := TBoss4DLock.Create;
    try
      LSbomLock.HasRootMetadata := True;
      LSbomLock.RootName := 'cli-test';
      LSbomLock.RootVersion := '1.0.0';
      LLockRepo.Save(LSbomLock, TPath.Combine(FTempDir, FILE_PACKAGE_LOCK));
    finally
      LSbomLock.Free;
    end;
    var LSbomPath := TPath.Combine(FTempDir, 'bom.cdx.json');
    LParser.ParseAndExecute(TArray<string>.Create('sbom', '--format', 'cyclonedx',
      '--output', LSbomPath, '--validate', '--strict', '--reproducible', '--lock-only',
      '--type', 'library'));
    Assert.IsTrue(TFile.Exists(LSbomPath));
    var LSbomContent := TFile.ReadAllText(LSbomPath, TEncoding.UTF8);
    Assert.IsTrue(LSbomContent.Contains('"specVersion": "1.7"'));
    Assert.IsTrue(LSbomContent.Contains('"type": "library"'));
    Assert.IsFalse(LSbomContent.Contains('"timestamp"'));
    var LInvalidFlagsRaised := False;
    try
      LParser.ParseAndExecute(TArray<string>.Create('sbom', '--lock-only', '--include-getit'));
    except
      on E: EArgumentException do LInvalidFlagsRaised := True;
    end;
    Assert.IsTrue(LInvalidFlagsRaised, 'Lock-only deve rejeitar coletores de ambiente.');
  finally
    LParser.Free;
    LConfigService.Free;
    LInstall.Free;
    LInit.Free;
  end;
end;

procedure TTestsServices.TestCompilerAutodetectAndOverride;
var
  LRegistryMock: TRegistryMock;
  LCompiler: TBoss4DDelphiCompilerAdapter;
  LCfgPath: string;
  LResolvedPath: string;
  LPlatform: string;
begin
  LCfgPath := GetGlobalConfigPath;
  if TFile.Exists(LCfgPath) then
    TFile.Delete(LCfgPath);

  LRegistryMock := TRegistryMock.Create;
  LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistryMock, TTestLogger.Create);
  try
    var LDelphi12FakeDir := TPath.Combine(FTempDir, 'Delphi12_Fake');
    var LFakeRsvarsDir12 := TPath.Combine(LDelphi12FakeDir, 'bin');
    TDirectory.CreateDirectory(LFakeRsvarsDir12);
    TFile.WriteAllText(TPath.Combine(LFakeRsvarsDir12, 'rsvars.bat'), '@echo off', TEncoding.UTF8);

    var LDelphi11FakeDir := TPath.Combine(FTempDir, 'Delphi11_Fake');
    var LFakeRsvarsDir11 := TPath.Combine(LDelphi11FakeDir, 'bin');
    TDirectory.CreateDirectory(LFakeRsvarsDir11);
    TFile.WriteAllText(TPath.Combine(LFakeRsvarsDir11, 'rsvars.bat'), '@echo off', TEncoding.UTF8);

    // Configura o mock do registro com os caminhos dinÃ¢micos de teste
    LRegistryMock.Path23 := LDelphi12FakeDir;
    LRegistryMock.Path22 := LDelphi11FakeDir;

    // 1. Sem configuracao no boss.cfg.json, deve usar o Registro e escolher a versao mais recente (23.0 -> Delphi 12)
    Assert.IsTrue(LCompiler.FindRsvarsPath(LResolvedPath, LPlatform));
    Assert.AreEqual(TPath.Combine(LFakeRsvarsDir12, 'rsvars.bat').ToLower, LResolvedPath.ToLower);

    // Garante que o diretorio de configuracao exista
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LCfgPath));

    // 2. Salva a configuracao forÃ§ando a versao de release "22.0"
    TFile.WriteAllText(LCfgPath, '{"delphiPath": "22.0"}', TEncoding.UTF8);
    Assert.IsTrue(LCompiler.FindRsvarsPath(LResolvedPath, LPlatform));
    Assert.AreEqual(TPath.Combine(LFakeRsvarsDir11, 'rsvars.bat').ToLower, LResolvedPath.ToLower);

    // 3. Salva a configuracao forÃ§ando o diretorio fisico do Delphi 11
    TFile.WriteAllText(LCfgPath, '{"delphiPath": "' + LDelphi11FakeDir.Replace('\', '\\') + '"}', TEncoding.UTF8);
    Assert.IsTrue(LCompiler.FindRsvarsPath(LResolvedPath, LPlatform));
    Assert.AreEqual(TPath.Combine(LFakeRsvarsDir11, 'rsvars.bat').ToLower, LResolvedPath.ToLower);

  finally
    LCompiler.Free;
    if TFile.Exists(LCfgPath) then
      TFile.Delete(LCfgPath);
  end;
end;

procedure TTestsServices.TestCacheService;
var
  LCacheService: TBoss4DCacheService;
  LCacheDir: string;
  LTestFile: string;
begin
  LCacheService := TBoss4DCacheService.Create(TTestLogger.Create);
  try
    LCacheDir := GetCacheDir;
    // O setup limpou a pasta, entÃ£o deve comeÃ§ar vazia
    Assert.AreEqual<Int64>(0, LCacheService.GetCacheSize);

    // Cria um arquivo fictÃ­cio de teste no cache
    TDirectory.CreateDirectory(TPath.Combine(LCacheDir, 'test_repo'));
    LTestFile := TPath.Combine(LCacheDir, 'test_repo\readme.md');
    TFile.WriteAllText(LTestFile, 'hello cache test content', TEncoding.UTF8);

    Assert.IsTrue(LCacheService.GetCacheSize > 0);

    // Limpa o cache
    LCacheService.Clean;
    Assert.AreEqual<Int64>(0, LCacheService.GetCacheSize);

    // Executa prune
    Assert.AreEqual<Integer>(0, LCacheService.Prune(30));
  finally
    LCacheService.Free;
  end;
end;

procedure TTestsServices.TestRunService;
var
  LPkgRepo: IBoss4DPackageRepository;
  LPkg: TBoss4DPackage;
  LRunService: TBoss4DRunService;
  LBossJsonPath: string;
begin
  LBossJsonPath := GetBossFile;
  LPkgRepo := TBoss4DPackageJsonRepository.Create;
  LPkg := TBoss4DPackage.Create;
  try
    LPkg.Name := 'test_run';
    LPkg.Version := '1.0.0';
    // Adiciona um script simulado simples e portÃ¡vel
    LPkg.Scripts.Add('test_cmd', 'cmd /c echo hello');
    LPkgRepo.Save(LPkg, LBossJsonPath);

    LRunService := TBoss4DRunService.Create(LPkgRepo, TTestLogger.Create);
    try
      // Executa o script que deve completar com sucesso (exit code 0)
      Assert.IsTrue(LRunService.Execute('test_cmd'));

      // Tenta executar script inexistente
      Assert.IsFalse(LRunService.Execute('inexistent_cmd'));
    finally
      LRunService.Free;
    end;
  finally
    LPkg.Free;
  end;
end;

procedure TTestsServices.TestDoctorService;
var
  LRegistryMock: TRegistryMock;
  LDoctorService: TBoss4DDoctorService;
begin
  LRegistryMock := TRegistryMock.Create;
  LDoctorService := TBoss4DDoctorService.Create(LRegistryMock, TTestLogger.Create);
  try
    // Roda a verificaÃ§Ã£o de auto-diagnÃ³stico sem fix (deve completar com ou sem avisos)
    LDoctorService.Check(False);

    // Roda a verificaÃ§Ã£o aplicando fix
    LDoctorService.Check(True);
  finally
    LDoctorService.Free;
  end;
end;

procedure TTestsServices.TestLicenseService;
var
  LPkgRepo: IBoss4DPackageRepository;
  LPkg: TBoss4DPackage;
  LDepPkg: TBoss4DPackage;
  LLicenseService: TBoss4DLicenseService;
  LDepDir: string;
  LReportMD: string;
  LReportCSV: string;
begin
  LPkgRepo := TBoss4DPackageJsonRepository.Create;
  LPkg := TBoss4DPackage.Create;
  try
    LPkg.Name := 'test_compliance';
    LPkg.Version := '1.0.0';
    LPkgRepo.Save(LPkg, GetBossFile);

    // Simula uma dependÃªncia instalada em modules/horse/boss.json com licenÃ§a MIT
    LDepDir := TPath.Combine(GetModulesDir, 'horse');
    TDirectory.CreateDirectory(LDepDir);

    LDepPkg := TBoss4DPackage.Create;
    try
      LDepPkg.Name := 'horse';
      LDepPkg.Version := '3.1.0';
      LDepPkg.License := 'MIT';
      LPkgRepo.Save(LDepPkg, TPath.Combine(LDepDir, FILE_PACKAGE));
    finally
      LDepPkg.Free;
    end;

    // Gera o relatÃ³rio de licenÃ§as
    LLicenseService := TBoss4DLicenseService.Create(LPkgRepo, TTestLogger.Create);
    try
      LLicenseService.GenerateReport;

      LReportMD := TPath.Combine(TDirectory.GetCurrentDirectory, 'docs\license_report.md');
      LReportCSV := TPath.Combine(TDirectory.GetCurrentDirectory, 'docs\license_report.csv');

      Assert.IsTrue(TFile.Exists(LReportMD));
      Assert.IsTrue(TFile.Exists(LReportCSV));

      var LMDContent := TFile.ReadAllText(LReportMD, TEncoding.UTF8);
      Assert.IsTrue(LMDContent.Contains('horse'));
      Assert.IsTrue(LMDContent.Contains('MIT'));
      Assert.IsTrue(LMDContent.Contains('spdx-expression'));
      Assert.IsTrue(TFile.ReadAllText(LReportCSV, TEncoding.UTF8).Contains('licenseKind'));
    finally
      LLicenseService.Free;
    end;
  finally
    LPkg.Free;
  end;
end;

procedure TTestsServices.TestChecksumVerification;
var
  LPkgRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitClientMock: IBoss4DGitClient;
  LHttpClientMock: IBoss4DHttpClient;
  LCompilerMock: IBoss4DCompiler;
  LInstall: TBoss4DInstallService;
  LLock: TBoss4DLock;
  LPkg: TBoss4DPackage;
  LDep: TBoss4DDependency;
  LLockedDep: TBoss4DLockedDependency;
  LTargetDir: string;
begin
  LPkgRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitClientMock := TGitClientMock.Create;
  LHttpClientMock := THttpClientMock.Create;
  LCompilerMock := TCompilerMock.Create;

  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'test_integrity';
  LPkg.Version := '1.0.0';
  LPkg.AddDependency('github.com/test/lib', '^1.0.0');
  LPkgRepo.Save(LPkg, GetBossFile);
  LPkg.Free;

  LInstall := TBoss4DInstallService.Create(
    LPkgRepo, LLockRepo, LGitClientMock, LHttpClientMock, LCompilerMock, TTestLogger.Create);
  try
    // 1. Instala pela primeira vez (gera o lock e o checksum inicial)
    LInstall.Execute('');

    Assert.IsTrue(TFile.Exists(TPath.Combine(TDirectory.GetCurrentDirectory, FILE_PACKAGE_LOCK)));

    LLock := LLockRepo.Load(TPath.Combine(TDirectory.GetCurrentDirectory, FILE_PACKAGE_LOCK));
    try
      LDep := TBoss4DDependency.Create('github.com/test/lib', '^1.0.0');
      try
        Assert.IsTrue(LLock.GetInstalled(LDep, LLockedDep));
        Assert.IsFalse(LLockedDep.Checksum.IsEmpty); // Deve ter computado hash SHA-256

        // Simula adulteracao da evidencia de integridade registrada no lock.
        LLockedDep.Checksum := StringOfChar('0', 64);
        LLockRepo.Save(LLock, TPath.Combine(
          TDirectory.GetCurrentDirectory, FILE_PACKAGE_LOCK));

        // 2. A instalacao congelada deve comparar o checkout limpo com o lock.
        var LFailed := False;
        try
          var LOptions := Default(TBoss4DInstallOptions);
          LOptions.Locked := True;
          LInstall.Execute(LOptions);
        except
          on E: Exception do
          begin
            LFailed := True;
            Assert.IsTrue(E.Message.Contains('ERRO DE SEGURANCA'));
          end;
        end;
        Assert.IsTrue(LFailed, 'Deveria ter disparado erro de seguranca de checksum');
      finally
        LDep.Free;
      end;
    finally
      LLock.Free;
    end;
  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestTreeService;
var
  LPkgRepo: IBoss4DPackageRepository;
  LLogger: TTestLogger;
  LTree: TBoss4DTreeService;
  LPkg: TBoss4DPackage;
  LSubDir, LSubDir2: string;
begin
  LPkgRepo := TBoss4DPackageJsonRepository.Create;
  LLogger := TTestLogger.Create;

  // 1. Cria manifesto principal
  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'root_pkg';
  LPkg.Version := '1.0.0';
  LPkg.AddDependency('github.com/dep1', '^1.0.0');
  LPkgRepo.Save(LPkg, GetBossFile);
  LPkg.Free;

  // 2. Cria subdependÃªncia mockada em modules/
  var LDep1 := TBoss4DDependency.Create('github.com/dep1', '');
  LSubDir := TPath.Combine(GetModulesDir, LDep1.StorageName);
  LDep1.Free;
  TDirectory.CreateDirectory(LSubDir);
  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'dep1';
  LPkg.Version := '1.1.0';
  LPkg.AddDependency('github.com/dep2', '^2.0.0');
  LPkgRepo.Save(LPkg, TPath.Combine(LSubDir, FILE_PACKAGE));
  LPkg.Free;

  var LDep2 := TBoss4DDependency.Create('github.com/dep2', '');
  LSubDir2 := TPath.Combine(GetModulesDir, LDep2.StorageName);
  LDep2.Free;
  TDirectory.CreateDirectory(LSubDir2);
  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'dep2';
  LPkg.Version := '2.0.5';
  LPkgRepo.Save(LPkg, TPath.Combine(LSubDir2, FILE_PACKAGE));
  LPkg.Free;

  LTree := TBoss4DTreeService.Create(LPkgRepo, LLogger);
  try
    LTree.GenerateTree;

    Assert.IsTrue(LLogger.LastLogMessage.Contains('root_pkg (1.0.0)'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('dep1 (1.1.0)'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('dep2 (2.0.5)'));
  finally
    LTree.Free;
  end;
end;

procedure TTestsServices.TestOutdatedService;
var
  LPkgRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitClientMock: IBoss4DGitClient;
  LLogger: TTestLogger;
  LOutdated: TBoss4DOutdatedService;
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDep: TBoss4DDependency;
  LCacheDir: string;
begin
  LPkgRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitClientMock := TGitClientMock.Create;
  LLogger := TTestLogger.Create;

  // 1. Cria manifesto principal
  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'test_outdated';
  LPkg.Version := '1.0.0';
  LPkg.AddDependency('github.com/outdated_lib', '^1.0.0');
  LPkgRepo.Save(LPkg, GetBossFile);
  LPkg.Free;

  // 2. Cria lock com versÃ£o anterior (v1.0.0)
  LLock := TBoss4DLock.Create;
  LDep := TBoss4DDependency.Create('github.com/outdated_lib', '^1.0.0');
  LLock.AddDependency(LDep, '1.0.0', 'hash_xyz');
  LLockRepo.Save(LLock, TPath.Combine(TDirectory.GetCurrentDirectory, FILE_PACKAGE_LOCK));

  // 3. Cria cache local mockado contendo as tags Git v1.0.0 e a nova v1.2.5
  LCacheDir := TPath.Combine(GetCacheDir, LDep.HashName);
  TDirectory.CreateDirectory(LCacheDir);

  (LGitClientMock as TGitClientMock).CloneCache(LDep, LCacheDir);
  (LGitClientMock as TGitClientMock).AddMockTags('github.com/outdated_lib', TArray<string>.Create('v1.0.0', 'v1.1.0', 'v1.2.5'));

  LDep.Free;
  LLock.Free;

  LOutdated := TBoss4DOutdatedService.Create(LPkgRepo, LLockRepo, LGitClientMock, LLogger);
  try
    LOutdated.CheckOutdated;

    Assert.IsTrue(LLogger.LastLogMessage.Contains('outdated_lib'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('1.0.0'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('1.2.5'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('Desatualizado'));
  finally
    LOutdated.Free;
  end;
end;

procedure TTestsServices.TestConfigAuthAndPrivateRepos;
var
  LConfigService: TBoss4DConfigService;
  LConfig: TBoss4DGlobalConfig;
  LDep: TBoss4DDependency;
  LCredentialStore: IBoss4DCredentialStore;
begin
  LCredentialStore := TCredentialStoreMock.Create;
  LConfigService := TBoss4DConfigService.Create(TTestLogger.Create,
    LCredentialStore);
  try
    // 1. Salva as credenciais mockadas
    LConfig := TBoss4DGlobalConfig.Create;
    try
      LConfig.GitHubToken := 'my_github_secret_pat';
      LConfig.GitLabToken := 'my_gitlab_secret_pat';
      LConfigService.Save(LConfig);
    finally
      LConfig.Free;
    end;
    Assert.IsFalse(TFile.ReadAllText(GetGlobalConfigPath).Contains(
      'my_github_secret_pat'));
    Assert.IsFalse(TFile.ReadAllText(GetGlobalConfigPath).Contains(
      'my_gitlab_secret_pat'));

    // 2. Carrega e valida os tokens salvos
    LConfig := LConfigService.Load;
    try
      Assert.AreEqual<string>('my_github_secret_pat', LConfig.GitHubToken);
      Assert.AreEqual<string>('my_gitlab_secret_pat', LConfig.GitLabToken);
    finally
      LConfig.Free;
    end;

    // 3. Valida suporte a file:/// no GetURL
    LDep := TBoss4DDependency.Create('file:///d:/Projetos/MinhaLib', '1.0.0');
    try
      Assert.AreEqual<string>('file:///d:/Projetos/MinhaLib', LDep.GetURL);
    finally
      LDep.Free;
    end;

    // 4. Valida suporte a caminhos de drives locais (ex: D:\MinhaLib) no GetURL
    LDep := TBoss4DDependency.Create('d:\Projetos\MinhaLib', '1.0.0');
    try
      Assert.AreEqual<string>('d:\Projetos\MinhaLib', LDep.GetURL);
    finally
      LDep.Free;
    end;
  finally
    LConfigService.Free;
  end;
end;

procedure TTestsServices.TestToolchainAndDeclaredProjects;
var
  LPackageRepository: IBoss4DPackageRepository;
  LLockRepository: IBoss4DLockRepository;
  LPackage: TBoss4DPackage;
  LGitClient: TGitClientMock;
  LCompiler: TCompilerMock;
  LInstall: TBoss4DInstallService;
begin
  LPackageRepository := TBoss4DPackageJsonRepository.Create;
  LLockRepository := TBoss4DLockJsonRepository.Create;
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'toolchain-test';
    LPackage.Version := '1.0.0';
    LPackage.Toolchain.Platform := 'Win64';
    LPackage.Toolchain.Compiler := '37.0';
    LPackageRepository.Save(LPackage, GetBossFile);
  finally
    LPackage.Free;
  end;

  LGitClient := TGitClientMock.Create;
  LCompiler := TCompilerMock.Create;
  LInstall := TBoss4DInstallService.Create(LPackageRepository, LLockRepository,
    LGitClient, THttpClientMock.Create, LCompiler, TTestLogger.Create);
  try
    LInstall.Execute('github.com/test/declared_projects@1.0.0');
    Assert.AreEqual<Integer>(2, LCompiler.CompiledProjects.Count);
    Assert.AreEqual('runtime.dproj',
      TPath.GetFileName(LCompiler.CompiledProjects[0]).ToLower);
    Assert.AreEqual('runtime.lpk',
      TPath.GetFileName(LCompiler.CompiledProjects[1]).ToLower);
    Assert.AreEqual('Win64', LCompiler.LastPlatform);
    Assert.AreEqual('37.0', LCompiler.LastCompilerVersion);
    LInstall.Execute('github.com/test/declared_projects@1.0.0', 'Win32');
    Assert.AreEqual('Win32', LCompiler.LastPlatform);
  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestDeclaredProjectRejectsTraversal;
var
  LRepository: IBoss4DPackageRepository;
  LPackage: TBoss4DPackage;
  LInstall: TBoss4DInstallService;
begin
  LRepository := TBoss4DPackageJsonRepository.Create;
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'invalid-project-test';
    LPackage.Version := '1.0.0';
    LRepository.Save(LPackage, GetBossFile);
  finally
    LPackage.Free;
  end;
  LInstall := TBoss4DInstallService.Create(LRepository,
    TBoss4DLockJsonRepository.Create, TGitClientMock.Create,
    THttpClientMock.Create, TCompilerMock.Create, TTestLogger.Create);
  try
    Assert.WillRaise(
      procedure
      begin
        LInstall.Execute('github.com/test/invalid_project@1.0.0');
      end,
      EArgumentException);
  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestInstallIntegratesDeclaredLazarusPaths;
var
  LPackageRepository: IBoss4DPackageRepository;
  LPackage: TBoss4DPackage;
  LCompiler: TCompilerMock;
  LInstall: TBoss4DInstallService;
  LLpiPath: string;
  LDprojPath: string;
  LContent: string;
begin
  LPackageRepository := TBoss4DPackageJsonRepository.Create;
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'lazarus-root';
    LPackage.Version := '1.0.0';
    LPackage.AddDependency('github.com/test/library', '1.0.0');
    LPackage.AddProject('app.lpi');
    LPackage.AddProject('app.dproj');
    LPackageRepository.Save(LPackage, GetBossFile);
  finally
    LPackage.Free;
  end;

  LLpiPath := TPath.Combine(FTempDir, 'app.lpi');
  TFile.WriteAllText(LLpiPath,
    '<CONFIG><CompilerOptions><SearchPaths>' +
    '<OtherUnitFiles Value="src"/></SearchPaths></CompilerOptions></CONFIG>',
    TEncoding.UTF8);
  LDprojPath := TPath.Combine(FTempDir, 'app.dproj');
  TFile.WriteAllText(LDprojPath, '<Project>unchanged</Project>',
    TEncoding.UTF8);

  LCompiler := TCompilerMock.Create;
  LCompiler.SearchPath := 'modules\zeta;modules\alpha';
  LInstall := TBoss4DInstallService.Create(LPackageRepository,
    TBoss4DLockJsonRepository.Create, TGitClientMock.Create,
    THttpClientMock.Create, LCompiler, TTestLogger.Create);
  try
    LInstall.Execute;
  finally
    LInstall.Free;
  end;

  LContent := TFile.ReadAllText(LLpiPath, TEncoding.UTF8);
  Assert.Contains(LContent, 'Value="src;modules\alpha;modules\zeta"');
  Assert.AreEqual('<Project>unchanged</Project>',
    TFile.ReadAllText(LDprojPath, TEncoding.UTF8));
end;

procedure TTestsServices.TestInstallDiscoversRootLazarusProject;
var
  LPackageRepository: IBoss4DPackageRepository;
  LPackage: TBoss4DPackage;
  LCompiler: TCompilerMock;
  LInstall: TBoss4DInstallService;
  LLpkPath: string;
begin
  LPackageRepository := TBoss4DPackageJsonRepository.Create;
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'lazarus-package-root';
    LPackage.Version := '1.0.0';
    LPackage.AddDependency('github.com/test/library', '1.0.0');
    LPackageRepository.Save(LPackage, GetBossFile);
  finally
    LPackage.Free;
  end;

  LLpkPath := TPath.Combine(FTempDir, 'runtime.lpk');
  TFile.WriteAllText(LLpkPath,
    '<CONFIG><Package><CompilerOptions/></Package></CONFIG>',
    TEncoding.UTF8);

  LCompiler := TCompilerMock.Create;
  LCompiler.SearchPath := 'modules\library';
  LInstall := TBoss4DInstallService.Create(LPackageRepository,
    TBoss4DLockJsonRepository.Create, TGitClientMock.Create,
    THttpClientMock.Create, LCompiler, TTestLogger.Create);
  try
    LInstall.Execute;
  finally
    LInstall.Free;
  end;

  Assert.Contains(TFile.ReadAllText(LLpkPath, TEncoding.UTF8),
    'Value="modules\library"');
end;

procedure TTestsServices.TestMultiplatformCompilation;
var
  LPkgRepo: IBoss4DPackageRepository;
  LLockRepo: IBoss4DLockRepository;
  LGitClientMock: IBoss4DGitClient;
  LHttpClientMock: IBoss4DHttpClient;
  LCompilerMock: IBoss4DCompiler;
  LInstall: TBoss4DInstallService;
  LPkg: TBoss4DPackage;
begin
  LPkgRepo := TBoss4DPackageJsonRepository.Create;
  LLockRepo := TBoss4DLockJsonRepository.Create;
  LGitClientMock := TGitClientMock.Create;
  LHttpClientMock := THttpClientMock.Create;
  LCompilerMock := TCompilerMock.Create;

  // 1. Cria o boss.json do projeto
  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'multiplatform_test';
  LPkg.Version := '1.0.0';
  LPkg.AddDependency('github.com/test_lib', '^1.0.0');
  LPkgRepo.Save(LPkg, GetBossFile);
  LPkg.Free;

  // 2. Instala e passa a plataforma Linux64
  LInstall := TBoss4DInstallService.Create(
    LPkgRepo, LLockRepo, LGitClientMock, LHttpClientMock, LCompilerMock, TTestLogger.Create);
  try
    LInstall.Execute('', 'Linux64');

    // O mock de compilador rodou sem erros e o resolvedor terminou perfeitamente
    Assert.IsTrue(TFile.Exists(TPath.Combine(TDirectory.GetCurrentDirectory, FILE_PACKAGE_LOCK)));
  finally
    LInstall.Free;
  end;
end;

procedure TTestsServices.TestIDEIntegration;
var
  LRegistryMock: IBoss4DRegistryService;
  LIntegration: TBoss4DIDEIntegrationService;
  LReg: TRegistry;
  LTestKey: string;
  LSearchPath: string;
begin
  LRegistryMock := TRegistryMock.Create;
  LIntegration := TBoss4DIDEIntegrationService.Create(LRegistryMock, TTestLogger.Create);
  try
    // 1. Redireciona o Registro para nossa pasta de teste isolada
    LIntegration.RegistryKeyPrefix := 'Software\Boss4DTests\BDS\';

    // 2. Prepara o Registro criando a chave de teste da versao 22.0
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      LTestKey := 'Software\Boss4DTests\BDS\22.0\Library\Win32';
      Assert.IsTrue(LReg.CreateKey(LTestKey));
      LReg.OpenKey(LTestKey, True);
      LReg.WriteString('Search Path', 'C:\PastaExistente');
    finally
      LReg.Free;
    end;

    // 3. Executa a integracao para a plataforma Win32
    LIntegration.IntegrateLibraryPaths('Win32');

    // 4. Valida se o caminho do DCU unificado foi inserido com sucesso
    LReg := TRegistry.Create(KEY_READ);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      Assert.IsTrue(LReg.OpenKey(LTestKey, False));
      LSearchPath := LReg.ReadString('Search Path');

      Assert.IsTrue(LSearchPath.Contains('C:\PastaExistente'));
      Assert.IsTrue(LSearchPath.Contains('modules\dcu'));
    finally
      LReg.Free;
    end;

    // 5. Limpa a chave do Registro de teste
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      LReg.DeleteKey('Software\Boss4DTests');
    finally
      LReg.Free;
    end;
  finally
    LIntegration.Free;
  end;
end;

procedure TTestsServices.TestToolGlobalInstallation;
var
  LGitClientMock: IBoss4DGitClient;
  LCompilerMock: IBoss4DCompiler;
  LToolService: TBoss4DToolService;
  LHomeDir: string;
  LBinGlobalDir: string;
  LFakeEXETarget: string;
begin
  LGitClientMock := TGitClientMock.Create;
  LCompilerMock := TCompilerMock.Create;

  LToolService := TBoss4DToolService.Create(LGitClientMock, LCompilerMock, TTestLogger.Create);
  try
    LHomeDir := GetBossHome;
    LBinGlobalDir := TPath.Combine(LHomeDir, 'bin');

    // Executa a instalacao global mockada
    LToolService.InstallGlobalTool('github.com/test/fake_tool');

    // Valida se o executavel falso foi movido com sucesso para a pasta global de binarios do boss
    LFakeEXETarget := TPath.Combine(LBinGlobalDir, 'fake_tool.exe');
    Assert.IsTrue(TFile.Exists(LFakeEXETarget));

    // Limpa arquivos do teste unitario
    if TFile.Exists(LFakeEXETarget) then
      TFile.Delete(LFakeEXETarget);
  finally
    LToolService.Free;
  end;
end;

procedure TTestsServices.TestIDEIntegrationPackages;
var
  LRegistryMock: IBoss4DRegistryService;
  LIntegration: TBoss4DIDEIntegrationService;
  LReg: TRegistry;
  LTestKeyPackages: string;
  LTestKeyIDEPackages: string;
begin
  LRegistryMock := TRegistryMock.Create;
  LIntegration := TBoss4DIDEIntegrationService.Create(LRegistryMock, TTestLogger.Create);
  try
    LIntegration.RegistryKeyPrefix := 'Software\Boss4DTests\BDS\';

    // Cria as chaves de Known Packages e Known IDE Packages para Delphi 22.0
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      LTestKeyPackages := 'Software\Boss4DTests\BDS\22.0\Known Packages';
      LTestKeyIDEPackages := 'Software\Boss4DTests\BDS\22.0\Known IDE Packages';
      Assert.IsTrue(LReg.CreateKey(LTestKeyPackages));
      Assert.IsTrue(LReg.CreateKey(LTestKeyIDEPackages));
    finally
      LReg.Free;
    end;

    // Registra pacotes
    LIntegration.RegisterDesignTimePackage('C:\fake_component.bpl', 'Componente Fake');
    LIntegration.RegisterIDEPackage('C:\fake_plugin.bpl', 'Plugin Fake');

    // Valida
    LReg := TRegistry.Create(KEY_READ);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      Assert.IsTrue(LReg.OpenKey(LTestKeyPackages, False));
      Assert.AreEqual<string>('Componente Fake', LReg.ReadString('C:\fake_component.bpl'));
      Assert.AreEqual<string>('Plugin Fake', LReg.ReadString('C:\fake_plugin.bpl'));
      LReg.CloseKey;

      if LReg.OpenKey(LTestKeyIDEPackages, False) then
      begin
        Assert.AreEqual<string>('', LReg.ReadString('C:\fake_plugin.bpl'));
        LReg.CloseKey;
      end;
    finally
      LReg.Free;
    end;

    // Limpeza
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      LReg.DeleteKey('Software\Boss4DTests');
    finally
      LReg.Free;
    end;
  finally
    LIntegration.Free;
  end;
end;

procedure TTestsServices.TestToolLifecycle;
var
  LGitClientMock: IBoss4DGitClient;
  LCompilerMock: IBoss4DCompiler;
  LToolService: TBoss4DToolService;
  LHomeDir: string;
  LBinGlobalDir: string;
  LFakeEXETarget: string;
begin
  LGitClientMock := TGitClientMock.Create;
  LCompilerMock := TCompilerMock.Create;
  LToolService := TBoss4DToolService.Create(LGitClientMock, LCompilerMock, TTestLogger.Create);
  try
    LHomeDir := GetBossHome;
    LBinGlobalDir := TPath.Combine(LHomeDir, 'bin');
    LFakeEXETarget := TPath.Combine(LBinGlobalDir, 'fake_tool.exe');

    // Instala
    LToolService.InstallGlobalTool('github.com/test/fake_tool');
    Assert.IsTrue(TFile.Exists(LFakeEXETarget));

    // Update
    LToolService.UpdateGlobalTool('fake_tool', 'github.com/test/fake_tool');
    Assert.IsTrue(TFile.Exists(LFakeEXETarget));

    // Uninstall
    LToolService.UninstallGlobalTool('fake_tool');
    Assert.IsFalse(TFile.Exists(LFakeEXETarget));
  finally
    LToolService.Free;
  end;
end;

procedure TTestsServices.TestPluginInstallation;
var
  LRegistryMock: IBoss4DRegistryService;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LTempCloneDir: string;
  LPluginsDir: string;
  LDep: TBoss4DDependency;
  LLock: TBoss4DLock;
  LDestBPL: string;
begin
  LRegistryMock := TRegistryMock.Create;
  LDep := nil;
  LLock := nil;
  LIDEIntegration := TBoss4DIDEIntegrationService.Create(LRegistryMock, TTestLogger.Create);
  try
    LIDEIntegration.RegistryKeyPrefix := 'Software\Boss4DTests\BDS\';
    LDep := TBoss4DDependency.Create('github.com/test/fake_tool', '*');
    LLock := TBoss4DLock.Create;
    LTempCloneDir := TPath.Combine(TPath.Combine(GetBossHome, 'temp_plugins'), LDep.Name);
    LPluginsDir := TPath.Combine(TPath.Combine(GetEnvironmentVariable('APPDATA'), 'Boss4D'), 'plugins');
    LDestBPL := TPath.Combine(LPluginsDir, 'fake_tool.bpl');

    // 1. Simula Clone e Compilacao do plugin usando os mocks
    if not TDirectory.Exists(LTempCloneDir) then
      TDirectory.CreateDirectory(LTempCloneDir);

    TFile.WriteAllText(TPath.Combine(LTempCloneDir, 'fake_tool.dproj'), 'fake dproj');
    TFile.WriteAllText(TPath.Combine(LTempCloneDir, 'fake_tool.bpl'), 'fake bpl');

    if not TDirectory.Exists(LPluginsDir) then
      TDirectory.CreateDirectory(LPluginsDir);

    TFile.Copy(TPath.Combine(LTempCloneDir, 'fake_tool.bpl'), LDestBPL, True);

    // 2. Registra na IDE
    LIDEIntegration.RegisterIDEPackage(LDestBPL, 'Fake Plugin Extension');

    // 3. Valida no Registro
    var LReg := TRegistry.Create(KEY_READ);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      Assert.IsTrue(LReg.OpenKey('Software\Boss4DTests\BDS\22.0\Known Packages', False));
      Assert.AreEqual<string>('Fake Plugin Extension', LReg.ReadString(LDestBPL));
      LReg.CloseKey;

      if LReg.OpenKey('Software\Boss4DTests\BDS\22.0\Known IDE Packages', False) then
      begin
        Assert.AreEqual<string>('', LReg.ReadString(LDestBPL));
        LReg.CloseKey;
      end;
    finally
      LReg.Free;
    end;

    // 4. Limpeza
    if TFile.Exists(LDestBPL) then TFile.Delete(LDestBPL);
    if TDirectory.Exists(LTempCloneDir) then TDirectory.Delete(LTempCloneDir, True);

    var LRegWrite := TRegistry.Create(KEY_WRITE);
    try
      LRegWrite.RootKey := HKEY_CURRENT_USER;
      LRegWrite.DeleteKey('Software\Boss4DTests');
    finally
      LRegWrite.Free;
    end;
  finally
    LLock.Free;
    LDep.Free;
    LIDEIntegration.Free;
  end;
end;

procedure TTestsServices.TestWorkspacesMonorepos;
var
  LPackageRepo: IBoss4DPackageRepository;
  LWorkspaceService: TBoss4DWorkspaceService;
  LMonorepoRoot: string;
  LApp1Dir: string;
  LApp2Dir: string;
  LSubprojectsList: TList<string>;
  LRootPkg: TBoss4DPackage;
begin
  LMonorepoRoot := TPath.Combine(TPath.GetTempPath, 'boss4d_monorepo_test_' + TGUID.NewGuid.ToString);
  LApp1Dir := TPath.Combine(LMonorepoRoot, TPath.Combine('subprojects', 'app1'));
  LApp2Dir := TPath.Combine(LMonorepoRoot, TPath.Combine('subprojects', 'app2'));

  TDirectory.CreateDirectory(LApp1Dir);
  TDirectory.CreateDirectory(LApp2Dir);

  // Escreve boss.json do subprojeto 1 e 2
  TFile.WriteAllText(TPath.Combine(LApp1Dir, 'boss.json'), '{"name": "app1", "version": "1.0.0"}');
  TFile.WriteAllText(TPath.Combine(LApp2Dir, 'boss.json'), '{"name": "app2", "version": "1.0.0"}');

  LPackageRepo := TBoss4DPackageJsonRepository.Create;
  LWorkspaceService := TBoss4DWorkspaceService.Create(LPackageRepo, TTestLogger.Create);
  try
    LRootPkg := TBoss4DPackage.Create;
    try
      LRootPkg.Name := 'root-monorepo';
      LRootPkg.Version := '1.0.0';
      LRootPkg.Workspaces.Add('subprojects/*');

      // 1. Busca subprojetos
      LSubprojectsList := LWorkspaceService.FindSubprojects(LRootPkg, LMonorepoRoot);
      try
        Assert.AreEqual<Integer>(2, LSubprojectsList.Count);
        Assert.IsTrue(LSubprojectsList[0].Contains('app1') or LSubprojectsList[1].Contains('app1'));
        Assert.IsTrue(LSubprojectsList[0].Contains('app2') or LSubprojectsList[1].Contains('app2'));

        // 2. Linka subprojetos (cria juncoes/pastas virtuais)
        LWorkspaceService.LinkWorkspaceSubprojects(LMonorepoRoot, LSubprojectsList);

        Assert.IsTrue(TDirectory.Exists(TPath.Combine(LApp1Dir, 'modules')));
        Assert.IsTrue(TDirectory.Exists(TPath.Combine(LApp2Dir, 'modules')));
      finally
        LSubprojectsList.Free;
      end;
    finally
      LRootPkg.Free;
    end;
  finally
    LWorkspaceService.Free;
    var LOutput: string;
    ExecuteCommandLine('cmd.exe /c rmdir "' + TPath.Combine(LApp1Dir, 'modules') + '"', LMonorepoRoot, LOutput);
    ExecuteCommandLine('cmd.exe /c rmdir "' + TPath.Combine(LApp2Dir, 'modules') + '"', LMonorepoRoot, LOutput);
    if TDirectory.Exists(LMonorepoRoot) then
      TDirectory.Delete(LMonorepoRoot, True);
  end;
end;

procedure TTestsServices.TestGetItBridge;
var
  LRegistryMock: IBoss4DRegistryService;
  LGetItService: TBoss4DGetItBridgeService;
  LTempDir: string;
  LFakeGetItCmd: string;
begin
  LTempDir := TPath.Combine(TPath.GetTempPath, 'boss4d_getit_test_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LTempDir);
  TDirectory.CreateDirectory(TPath.Combine(LTempDir, 'bin'));

  LFakeGetItCmd := TPath.Combine(TPath.Combine(LTempDir, 'bin'), 'GetItCmd.exe');
  TFile.Copy('C:\Windows\System32\cmd.exe', LFakeGetItCmd, True);

  LRegistryMock := TRegistryMock.Create;
  TRegistryMock(LRegistryMock).Path22 := LTempDir;
  TRegistryMock(LRegistryMock).Path23 := LTempDir;

  LGetItService := TBoss4DGetItBridgeService.Create(LRegistryMock, TTestLogger.Create);
  try
    LGetItService.InstallPackage('horse');
    LGetItService.SetGetItMode(True);
    LGetItService.SetGetItMode(False);
  finally
    LGetItService.Free;
    if TDirectory.Exists(LTempDir) then
      TDirectory.Delete(LTempDir, True);
  end;
end;

procedure TTestsServices.TestDCUMegafoldersStructure;
var
  LRegistryMock: IBoss4DRegistryService;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LReg: TRegistry;
  LSubKey: string;
  LValue: string;
begin
  LRegistryMock := TRegistryMock.Create;
  LIDEIntegration := TBoss4DIDEIntegrationService.Create(LRegistryMock, TTestLogger.Create);
  try
    LIDEIntegration.RegistryKeyPrefix := 'Software\Boss4DTests\BDS\';

    LReg := TRegistry.Create(KEY_READ or KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      LReg.DeleteKey('Software\Boss4DTests');
    except
      // ignora se nao existir
    end;
    LReg.Free;

    LIDEIntegration.IntegrateLibraryPaths('Win32');
    LIDEIntegration.IntegrateLibraryPaths('Win64');

    LReg := TRegistry.Create(KEY_READ);
    try
      LReg.RootKey := HKEY_CURRENT_USER;

      LSubKey := 'Software\Boss4DTests\BDS\22.0\Library\Win32';
      if LReg.OpenKey(LSubKey, False) then
      begin
        LValue := LReg.ReadString('Search Path');
        Assert.IsTrue(LValue.Contains(TPath.Combine('modules', TPath.Combine('dcu', TPath.Combine('Win32', 'Debug')))));
        LReg.CloseKey;
      end
      else
        Assert.Fail('Nao foi possivel abrir a chave de Registro Win32 de teste.');

      LSubKey := 'Software\Boss4DTests\BDS\22.0\Library\Win64';
      if LReg.OpenKey(LSubKey, False) then
      begin
        LValue := LReg.ReadString('Search Path');
        Assert.IsTrue(LValue.Contains(TPath.Combine('modules', TPath.Combine('dcu', TPath.Combine('Win64', 'Debug')))));
        LReg.CloseKey;
      end
      else
        Assert.Fail('Nao foi possivel abrir a chave de Registro Win64 de teste.');
    finally
      LReg.Free;
    end;
  finally
    LIDEIntegration.Free;

    LReg := TRegistry.Create(KEY_READ or KEY_WRITE);
    try
      LReg.RootKey := HKEY_CURRENT_USER;
      LReg.DeleteKey('Software\Boss4DTests');
    except
      // ignora se nao existir
    end;
    LReg.Free;
  end;
end;

procedure TTestsServices.TestAutodetectDelphiVersionFromDproj;
var
  LRegistryMock: IBoss4DRegistryService;
  LCompiler: TBoss4DDelphiCompilerAdapter;
  LTempDir11, LTempDir12, LTempDir13: string;
  LDprojFile: string;
  LDprojContent: string;
  LRsvarsPath: string;
  LPlatform: string;
begin
  LTempDir11 := TPath.Combine(TPath.GetTempPath, 'boss4d_mock_delphi11_' + TGUID.NewGuid.ToString);
  LTempDir12 := TPath.Combine(TPath.GetTempPath, 'boss4d_mock_delphi12_' + TGUID.NewGuid.ToString);
  LTempDir13 := TPath.Combine(TPath.GetTempPath, 'boss4d_mock_delphi13_' + TGUID.NewGuid.ToString);

  TDirectory.CreateDirectory(TPath.Combine(LTempDir11, 'bin'));
  TDirectory.CreateDirectory(TPath.Combine(LTempDir12, 'bin'));
  TDirectory.CreateDirectory(TPath.Combine(LTempDir13, 'bin'));

  TFile.WriteAllText(TPath.Combine(TPath.Combine(LTempDir11, 'bin'), 'rsvars.bat'), '@echo off', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(TPath.Combine(LTempDir12, 'bin'), 'rsvars.bat'), '@echo off', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(TPath.Combine(LTempDir13, 'bin'), 'rsvars.bat'), '@echo off', TEncoding.UTF8);

  LDprojFile := TPath.Combine(TDirectory.GetCurrentDirectory, 'test_mock_project.dproj');

  try
    LRegistryMock := TRegistryMock.Create;
    TRegistryMock(LRegistryMock).Path22 := LTempDir11;
    TRegistryMock(LRegistryMock).Path23 := LTempDir12;
    TRegistryMock(LRegistryMock).Path37 := LTempDir13;

    // 1. Testa deteccao do Delphi 11 (Alexandria) -> ProjectVersion 19.5
    LDprojContent :=
      '<?xml version="1.0" encoding="utf-8"?>'#13#10 +
      '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'#13#10 +
      '  <PropertyGroup>'#13#10 +
      '    <ProjectVersion>19.5</ProjectVersion>'#13#10 +
      '  </PropertyGroup>'#13#10 +
      '</Project>';
    TFile.WriteAllText(LDprojFile, LDprojContent, TEncoding.UTF8);

    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistryMock, TTestLogger.Create);
    try
      Assert.IsTrue(LCompiler.FindRsvarsPath(LRsvarsPath, LPlatform));
      Assert.IsTrue(LRsvarsPath.Contains(LTempDir11), 'Nao priorizou a versao do Delphi 11 do dproj. Usou: ' + LRsvarsPath);
    finally
      LCompiler.Free;
    end;

    // 2. Testa deteccao do Delphi 13 (Florence) -> ProjectVersion 20.3
    LDprojContent :=
      '<?xml version="1.0" encoding="utf-8"?>'#13#10 +
      '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'#13#10 +
      '  <PropertyGroup>'#13#10 +
      '    <ProjectVersion>20.3</ProjectVersion>'#13#10 +
      '  </PropertyGroup>'#13#10 +
      '</Project>';
    TFile.WriteAllText(LDprojFile, LDprojContent, TEncoding.UTF8);

    LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistryMock, TTestLogger.Create);
    try
      Assert.IsTrue(LCompiler.FindRsvarsPath(LRsvarsPath, LPlatform));
      Assert.IsTrue(LRsvarsPath.Contains(LTempDir13), 'Nao priorizou a versao do Delphi 13 do dproj. Usou: ' + LRsvarsPath);
    finally
      LCompiler.Free;
    end;

  finally
    if TFile.Exists(LDprojFile) then TFile.Delete(LDprojFile);
    if TDirectory.Exists(LTempDir11) then TDirectory.Delete(LTempDir11, True);
    if TDirectory.Exists(LTempDir12) then TDirectory.Delete(LTempDir12, True);
    if TDirectory.Exists(LTempDir13) then TDirectory.Delete(LTempDir13, True);
  end;
end;

procedure TTestsServices.TestIDEWizardInitialization;
var
  LWizard: TBoss4DIDEWizard;
begin
  // Valida a criação e os métodos básicos do novo Wizard principal do menu da IDE
  LWizard := TBoss4DIDEWizard.Create;
  try
    Assert.AreEqual<string>('Boss4D IDE Wizard', LWizard.GetName);
    Assert.AreEqual<string>('Boss4D.IDE.Plugin.Wizard', LWizard.GetIDString);
  finally
    LWizard.Free;
  end;
end;

procedure TTestsServices.TestCleanService;
var
  LModulesDir: string;
  LLockFile: string;
  LService: TBoss4DCleanService;
begin
  LModulesDir := TPath.Combine(FTempDir, FOLDER_DEPENDENCIES);
  LLockFile := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);

  TDirectory.CreateDirectory(LModulesDir);
  TFile.WriteAllText(TPath.Combine(LModulesDir, 'dummy.txt'), 'test');
  TFile.WriteAllText(LLockFile, '{}');

  Assert.IsTrue(TDirectory.Exists(LModulesDir));
  Assert.IsTrue(TFile.Exists(LLockFile));

  LService := TBoss4DCleanService.Create(TTestLogger.Create);
  try
    TDirectory.SetCurrentDirectory(FTempDir);
    LService.Execute;
  finally
    LService.Free;
    TDirectory.SetCurrentDirectory(FPrevCurrentDir);
  end;

  Assert.IsFalse(TDirectory.Exists(LModulesDir), 'Pasta modules deveria ter sido removida!');
  Assert.IsFalse(TFile.Exists(LLockFile), 'Arquivo boss-lock.json deveria ter sido removido!');
end;

procedure TTestsServices.TestScaffoldService;
var
  LRepository: IBoss4DPackageRepository;
  LService: TBoss4DScaffoldService;
  LTarget: string;
  LPackage: TBoss4DPackage;
begin
  LRepository := TBoss4DPackageJsonRepository.Create;
  LTarget := TPath.Combine(FTempDir, 'SampleApp');
  LService := TBoss4DScaffoldService.Create(LRepository, TTestLogger.Create);
  try
    LService.Execute('app', 'SampleApp', LTarget);
  finally
    LService.Free;
  end;

  Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, FILE_PACKAGE)));
  Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'SampleApp.dpr')));
  Assert.IsTrue(TDirectory.Exists(TPath.Combine(LTarget, 'src')));
  Assert.IsTrue(TDirectory.Exists(TPath.Combine(LTarget, 'tests')));
  LPackage := LRepository.Load(TPath.Combine(LTarget, FILE_PACKAGE));
  try
    Assert.AreEqual('SampleApp', LPackage.Name);
    Assert.AreEqual<Integer>(1, LPackage.Projects.Count);
    Assert.AreEqual('SampleApp.dpr', LPackage.Projects[0]);
  finally
    LPackage.Free;
  end;
end;

procedure TTestsServices.TestScaffoldPresets;
var
  LRepository: IBoss4DPackageRepository;
  LService: TBoss4DScaffoldService;
  LTarget: string;
  LPackage: TBoss4DPackage;

  procedure CreatePreset(const ATemplate, AName: string);
  begin
    LTarget := TPath.Combine(FTempDir, AName);
    LService.Execute(ATemplate, AName, LTarget);
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, FILE_PACKAGE)));
  end;

begin
  LRepository := TBoss4DPackageJsonRepository.Create;
  LService := TBoss4DScaffoldService.Create(LRepository, TTestLogger.Create);
  try
    CreatePreset('vcl', 'VclSample');
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'src\MainView.pas')));
    CreatePreset('fmx', 'FmxSample');
    Assert.IsTrue(TFile.ReadAllText(TPath.Combine(LTarget,
      'FmxSample.dpr')).Contains('FMX.Forms'));

    CreatePreset('api', 'ApiSample');
    LPackage := LRepository.Load(TPath.Combine(LTarget, FILE_PACKAGE));
    try
      Assert.IsTrue(LPackage.Dependencies.ContainsKey(
        'github.com/hashload/horse'));
      Assert.IsTrue(LPackage.Dependencies.ContainsKey(
        'github.com/regyssilveira/dext'),
        'O template de API deve incluir Dext.');
    finally
      LPackage.Free;
    end;

    CreatePreset('dunitx', 'TestsSample');
    LPackage := LRepository.Load(TPath.Combine(LTarget, FILE_PACKAGE));
    try
      Assert.IsTrue(LPackage.DevDependencies.ContainsKey(
        'github.com/VSoftTechnologies/DUnitX'));
    finally
      LPackage.Free;
    end;
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget,
      'tests\Sample.Tests.pas')));

    CreatePreset('lazarus-app', 'LazApp');
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'LazApp.lpi')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'LazApp.lpr')));
    CreatePreset('lazarus-package', 'LazPackage');
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget, 'LazPackage.lpk')));

    CreatePreset('workspace', 'WorkspaceSample');
    LPackage := LRepository.Load(TPath.Combine(LTarget, FILE_PACKAGE));
    try
      Assert.AreEqual<Integer>(2, LPackage.Workspaces.Count);
    finally
      LPackage.Free;
    end;
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget,
      'apps\app\boss.json')));
    Assert.IsTrue(TFile.Exists(TPath.Combine(LTarget,
      'packages\shared\boss.json')));
  finally
    LService.Free;
  end;
end;

procedure TTestsServices.TestSourceNormalizer;
var
  LSourcePath, LTextPath, LBinaryPath: string;
  LBytes: TBytes;
begin
  LSourcePath := TPath.Combine(FTempDir, 'unit.pas');
  LTextPath := TPath.Combine(FTempDir, 'notes.txt');
  LBinaryPath := TPath.Combine(FTempDir, 'binary.dfm');
  TFile.WriteAllBytes(LSourcePath, TEncoding.UTF8.GetBytes('unit X;'#10'end.'));
  TFile.WriteAllBytes(LTextPath, TEncoding.UTF8.GetBytes('one'#10'two'));
  TFile.WriteAllBytes(LBinaryPath, TBytes.Create(0, 10, 20));

  TBoss4DSourceNormalizer.NormalizeDirectoryToCRLF(FTempDir);
  LBytes := TFile.ReadAllBytes(LSourcePath);
  Assert.IsTrue(TEncoding.UTF8.GetString(LBytes).Contains(#13#10));
  Assert.AreEqual('one'#10'two',
    TEncoding.UTF8.GetString(TFile.ReadAllBytes(LTextPath)));
  Assert.AreEqual<Integer>(3, Length(TFile.ReadAllBytes(LBinaryPath)));
end;

procedure TTestsServices.TestPackageRequiresPreservesConditionals;
var
  LOriginal, LUpdated: string;
begin
  LOriginal := 'package Sample;' + sLineBreak + 'requires' + sLineBreak +
    '  rtl,' + sLineBreak + '  {$IFDEF MSWINDOWS}' + sLineBreak +
    '  designide,' + sLineBreak + '  {$ENDIF}' + sLineBreak +
    '  vcl;' + sLineBreak + 'end.';
  LUpdated := TBoss4DPackageManifest.AddRequires(LOriginal,
    TArray<string>.Create('newruntime', 'rtl'));
  Assert.IsTrue(LUpdated.Contains('{$IFDEF MSWINDOWS}'));
  Assert.IsTrue(LUpdated.Contains('designide,'));
  Assert.IsTrue(LUpdated.Contains('{$ENDIF}'));
  Assert.IsTrue(LUpdated.Contains('newruntime'));
  Assert.AreEqual<Integer>(1,
    TRegEx.Matches(LUpdated, '(?i)\brtl\b').Count);
end;

procedure TTestsServices.TestPackageRequiresPreservesSpacing;
var
  LOriginal, LExpected, LUpdated: string;
begin
  LOriginal := 'package Sample;' + sLineBreak + 'requires' + sLineBreak + '  rtl;' + sLineBreak + 'end.';
  LExpected := 'package Sample;' + sLineBreak + 'requires' + sLineBreak + '  rtl,' + sLineBreak + '  newruntime;' + sLineBreak + 'end.';
  LUpdated := TBoss4DPackageManifest.AddRequires(LOriginal, TArray<string>.Create('newruntime'));
  Assert.AreEqual<string>(LExpected, LUpdated);
end;

procedure TTestsServices.TestPackageRequiresWithTrailingComments;
var
  LOriginal, LUpdated: string;
begin
  LOriginal := 'package Sample;' + sLineBreak + 'requires' + sLineBreak +
    '  rtl // base runtime' + sLineBreak + '  ;' + sLineBreak + 'end.';
  LUpdated := TBoss4DPackageManifest.AddRequires(LOriginal, TArray<string>.Create('newruntime'));
  // Deve garantir que newruntime não fique comentada
  Assert.IsFalse(TRegEx.IsMatch(LUpdated, '//.*newruntime'));
  Assert.IsTrue(LUpdated.Contains('newruntime'));
end;

procedure TTestsServices.TestPackageRequiresWithMultipleBlocks;
var
  LOriginal, LUpdated: string;
begin
  LOriginal := 'package Sample;' + sLineBreak + 'requires' + sLineBreak +
    '  {$IFDEF MSWINDOWS}' + sLineBreak + '  vcl;' + sLineBreak +
    '  {$ELSE}' + sLineBreak + '  fmx;' + sLineBreak + '  {$ENDIF}' + sLineBreak + 'end.';
  LUpdated := TBoss4DPackageManifest.AddRequires(LOriginal, TArray<string>.Create('newruntime'));
  // Ambas as partes da diretiva condicional devem ter a nova dependência adicionada
  Assert.IsTrue(TRegEx.IsMatch(LUpdated, 'vcl,\s*newruntime;'));
  Assert.IsTrue(TRegEx.IsMatch(LUpdated, 'fmx,\s*newruntime;'));
end;

end.
