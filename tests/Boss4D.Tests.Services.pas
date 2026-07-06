unit Boss4D.Tests.Services;

interface

uses
  DUnitX.TestFramework, Boss4D.Core.Ports;

type
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
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.Generics.Collections,
  System.Win.Registry,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Consts, Boss4D.Core.Domain.Env, Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Config, Boss4D.Core.Services.Install, Boss4D.CLI.Parser,
  Boss4D.Adapters.Json, Boss4D.Adapters.Compiler, Boss4D.Tests.Mocks,
  Boss4D.Core.Services.Cache, Boss4D.Core.Services.Run,
  Boss4D.Core.Services.Doctor, Boss4D.Core.Services.License,
  Boss4D.Core.Services.Tree, Boss4D.Core.Services.Outdated,
  Boss4D.Core.Services.IDEIntegration, Boss4D.Core.Services.Tool, Boss4D.Core.Services.Workspace, Boss4D.Core.Services.GetIt,
  Boss4D.Core.Services.Clean, Boss4D.IDE.Wizard;

{ TTestLogger }

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
    // Instala dependência específica (boss4d install github.com/hashload/horse@^3.1.0)
    LInstall.Execute('github.com/hashload/horse@^3.1.0');

    // Valida se o diretório do módulo foi criado em modules/horse
    var LModuleDir := TPath.Combine(GetModulesDir, 'horse');
    Assert.IsTrue(TDirectory.Exists(LModuleDir));

    // Valida se o boss-lock.json foi gerado e travado na versão resolvida
    LLockPath := TPath.Combine(FTempDir, FILE_PACKAGE_LOCK);
    Assert.IsTrue(TFile.Exists(LLockPath));

    LLock := LLockRepo.Load(LLockPath);
    try
      var LLockedDep: TBoss4DLockedDependency;
      Assert.IsTrue(LLock.GetInstalled(TBoss4DDependency.Create('github.com/hashload/horse', ''), LLockedDep));
      Assert.AreEqual('3.2.0', LLockedDep.Version); // v3.2.0 atende ^3.1.0 e é a mais recente!
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
    var LModuleDir := TPath.Combine(GetModulesDir, 'horse');
    Assert.IsTrue(TDirectory.Exists(LModuleDir));

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
    Assert.AreEqual('v1.0.1-delphi-native', LLogger.LastLogMessage.Trim);

    // Testa o comando "help"
    LParser.ParseAndExecute(TArray<string>.Create('-h'));
    Assert.IsTrue(LLogger.LastLogMessage.Contains('Uso:'));
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

    // Configura o mock do registro com os caminhos dinâmicos de teste
    LRegistryMock.Path23 := LDelphi12FakeDir;
    LRegistryMock.Path22 := LDelphi11FakeDir;

    // 1. Sem configuracao no boss.cfg.json, deve usar o Registro e escolher a versao mais recente (23.0 -> Delphi 12)
    Assert.IsTrue(LCompiler.FindRsvarsPath(LResolvedPath, LPlatform));
    Assert.AreEqual(TPath.Combine(LFakeRsvarsDir12, 'rsvars.bat').ToLower, LResolvedPath.ToLower);

    // Garante que o diretorio de configuracao exista
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LCfgPath));

    // 2. Salva a configuracao forçando a versao de release "22.0"
    TFile.WriteAllText(LCfgPath, '{"delphiPath": "22.0"}', TEncoding.UTF8);
    Assert.IsTrue(LCompiler.FindRsvarsPath(LResolvedPath, LPlatform));
    Assert.AreEqual(TPath.Combine(LFakeRsvarsDir11, 'rsvars.bat').ToLower, LResolvedPath.ToLower);

    // 3. Salva a configuracao forçando o diretorio fisico do Delphi 11
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
    // O setup limpou a pasta, então deve começar vazia
    Assert.AreEqual<Int64>(0, LCacheService.GetCacheSize);

    // Cria um arquivo fictício de teste no cache
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
    // Adiciona um script simulado simples e portável
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
    // Roda a verificação de auto-diagnóstico sem fix (deve completar com ou sem avisos)
    LDoctorService.Check(False);
    
    // Roda a verificação aplicando fix
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

    // Simula uma dependência instalada em modules/horse/boss.json com licença MIT
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

    // Gera o relatório de licenças
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
        
        // Simula uma alteração indevida de arquivos na dependência instalada
        LTargetDir := TPath.Combine(GetModulesDir, LLockedDep.Name);
        TFile.WriteAllText(TPath.Combine(LTargetDir, 'unauthorized.txt'), 'tampered content', TEncoding.UTF8);

        // 2. Tenta re-instalar (deve disparar erro de segurança, pois o checksum calculado diverge do trancado!)
        var LFailed := False;
        try
          LInstall.Execute('');
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

  // 2. Cria subdependência mockada em modules/
  LSubDir := TPath.Combine(GetModulesDir, 'dep1');
  TDirectory.CreateDirectory(LSubDir);
  LPkg := TBoss4DPackage.Create;
  LPkg.Name := 'dep1';
  LPkg.Version := '1.1.0';
  LPkg.AddDependency('github.com/dep2', '^2.0.0');
  LPkgRepo.Save(LPkg, TPath.Combine(LSubDir, FILE_PACKAGE));
  LPkg.Free;

  LSubDir2 := TPath.Combine(GetModulesDir, 'dep2');
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

  // 2. Cria lock com versão anterior (v1.0.0)
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
begin
  LConfigService := TBoss4DConfigService.Create(TTestLogger.Create);
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
  LGitClientMock: IBoss4DGitClient;
  LCompilerMock: IBoss4DCompiler;
  LRegistryMock: IBoss4DRegistryService;
  LIDEIntegration: TBoss4DIDEIntegrationService;
  LTempCloneDir: string;
  LPluginsDir: string;
  LDep: TBoss4DDependency;
  LLock: TBoss4DLock;
  LDestBPL: string;
begin
  LGitClientMock := TGitClientMock.Create;
  LCompilerMock := TCompilerMock.Create;
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
  LMenu: TBoss4DProjectManagerMenu;
  LNotifier: TBoss4DProjectMenuItemCreatorNotifier;
  LMenuList: IInterfaceList;
  LProj: IOTAProject;
  LTempDir: string;
  LBossJsonFile: string;
  LBossJsonContent: string;
  LIdentList: TStrings;
  I: Integer;
  LFoundBuildScript: Boolean;
  LMenuItem: IOTAProjectManagerMenu;
begin
  // 1. Valida stubs básicos de menu
  LMenu := TBoss4DProjectManagerMenu.Create('Boss4D Install', 'mnuBoss4DInstall', 'mnuBoss4D', 'Boss4DInstallVerb', 'C:\Proj', 'install', 120);
  try
    Assert.AreEqual<string>('Boss4D Install', LMenu.GetCaption);
    Assert.AreEqual<string>('mnuBoss4DInstall', LMenu.GetName);
    Assert.AreEqual<string>('mnuBoss4D', LMenu.GetParent);
    Assert.AreEqual<string>('Boss4DInstallVerb', LMenu.GetVerb);
    Assert.AreEqual<Integer>(120, LMenu.GetPosition);
    Assert.IsFalse(LMenu.GetIsMultiSelectable);

    LMenu.SetIsMultiSelectable(True);
    Assert.IsTrue(LMenu.GetIsMultiSelectable);
  finally
    LMenu.Free;
  end;

  // 2. Valida segurança de projeto não salvo em disco
  LTempDir := TPath.Combine(TPath.GetTempPath, 'boss4d_wizard_test_' + TGUID.NewGuid.ToString.Replace('{', '').Replace('}', ''));
  TDirectory.CreateDirectory(LTempDir);
  try
    LProj := TOTAProjectMock.Create(TPath.Combine(LTempDir, 'NonExistentProject.dproj'));
    LNotifier := TBoss4DProjectMenuItemCreatorNotifier.Create;
    LMenuList := TInterfaceList.Create;
    LIdentList := TStringList.Create;
    try
      // Como o arquivo .dproj não existe fisicamente no disco, o AddMenu deve sair silenciosamente sem popular a lista!
      LNotifier.AddMenu(LProj, LIdentList, LMenuList, False);
      Assert.AreEqual<Integer>(0, LMenuList.Count);

      // Agora cria o arquivo físico de dproj para validar que ele popula
      TFile.WriteAllText(LProj.FileName, '<?xml version="1.0" encoding="utf-8"?><Project/>', TEncoding.UTF8);

      // Cria um boss.json com scripts de teste
      LBossJsonFile := TPath.Combine(LTempDir, 'boss.json');
      LBossJsonContent := '{"name":"test-proj","scripts":{"build":"dcc32 test.dpr","test":"Boss4DTests.exe"}}';
      TFile.WriteAllText(LBossJsonFile, LBossJsonContent, TEncoding.UTF8);

      LNotifier.AddMenu(LProj, LIdentList, LMenuList, False);

      // O menu deve conter itens principais, os novos itens do doctor, tree, getit, cache, etc., mais os scripts dinâmicos!
      Assert.IsTrue(LMenuList.Count > 5, 'Deveria ter populado os itens de menu estáticos e dinâmicos. Total: ' + LMenuList.Count.ToString);

      // Procura pelo script dinâmico de build no menu
      LFoundBuildScript := False;
      for I := 0 to LMenuList.Count - 1 do
      begin
        if Supports(LMenuList[I], IOTAProjectManagerMenu, LMenuItem) then
        begin
          if LMenuItem.GetName = 'mnuBoss4DRun_build_NonExistentProject' then
          begin
            LFoundBuildScript := True;
            Assert.AreEqual<string>('Boss4D Run: build', LMenuItem.GetCaption);
            Assert.AreEqual<string>('', LMenuItem.GetParent);
            Assert.AreEqual<string>('Boss4DRun_build_NonExistentProjectVerb', LMenuItem.GetVerb);
            Break;
          end;
        end;
      end;
      Assert.IsTrue(LFoundBuildScript, 'Nao encontrou o script dinamico "build" do boss.json no menu!');

    finally
      LNotifier.Free;
      LIdentList.Free;
    end;
  finally
    if TDirectory.Exists(LTempDir) then
      TDirectory.Delete(LTempDir, True);
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

end.
