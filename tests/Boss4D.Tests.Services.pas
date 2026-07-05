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
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, System.Generics.Collections,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Consts, Boss4D.Core.Domain.Env, Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Config, Boss4D.Core.Services.Install, Boss4D.CLI.Parser,
  Boss4D.Adapters.Json, Boss4D.Adapters.Compiler, Boss4D.Tests.Mocks,
  Boss4D.Core.Services.Cache, Boss4D.Core.Services.Run,
  Boss4D.Core.Services.Doctor, Boss4D.Core.Services.License,
  Boss4D.Core.Services.Tree, Boss4D.Core.Services.Outdated;

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
    Assert.AreEqual('v1.0.0-delphi-native', LLogger.LastLogMessage.Trim);

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

end.
