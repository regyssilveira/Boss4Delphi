unit Boss4D.Tests.Services;

interface

uses
  DUnitX.TestFramework, System.SysUtils, System.IOUtils, System.Generics.Collections,
  Boss4D.Core.Ports, Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Consts, Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.Init, Boss4D.Core.Services.Config, Boss4D.Core.Services.Install,
  Boss4D.CLI.Parser, Boss4D.Adapters.Json, Boss4D.Adapters.Compiler, Boss4D.Tests.Mocks;

type
  { MockLogger simples para nao poluir o console de testes e capturar saidas }
  TTestLogger = class(TInterfacedObject, IBoss4DLogger)
  public
    LastLogMessage: string;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string); overload;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const); overload;
    procedure SetDebugMode(const AEnabled: Boolean);
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
  end;

implementation

uses
  Winapi.Windows;

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
  
  LParser := TBoss4DCommandLineParser.Create(LLogger, LInit, LInstall, LConfigService);
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

end.
