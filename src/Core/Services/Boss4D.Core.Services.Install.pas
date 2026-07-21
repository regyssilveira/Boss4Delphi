unit Boss4D.Core.Services.Install;

interface

uses
  System.Generics.Collections, System.Threading, System.SyncObjs, Boss4D.Core.Ports,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Lock;

type
  { Servico de caso de uso para instalacao e atualizacao de dependencias (boss install) }
  TBoss4DInstallService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLockRepo: IBoss4DLockRepository;
    FGitClient: IBoss4DGitClient;
    FHttpClient: IBoss4DHttpClient;
    FCompiler: IBoss4DCompiler;
    FLogger: IBoss4DLogger;
    FGitCriticalSection: TCriticalSection;
    FGlobalProcessedDeps: TList<string>;

    procedure ProcessDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock;
      const AProcessedDeps: TList<string>);
    procedure BuildDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock; const APlatform: string = '');
    function ResolveSemVerRange(const ARangeStr, ACacheDir: string): string;
    function ResolveDependencyVersion(const ADep: TBoss4DDependency; const ACacheDir: string): string;
    function CalculateDirectoryChecksum(const ADirPath: string): string;
  public
    constructor Create(
      const APackageRepo: IBoss4DPackageRepository;
      const ALockRepo: IBoss4DLockRepository;
      const AGitClient: IBoss4DGitClient;
      const AHttpClient: IBoss4DHttpClient;
      const ACompiler: IBoss4DCompiler;
      const ALogger: IBoss4DLogger
    );

    destructor Destroy; override;

    procedure Execute(const AInstallSingle: string = ''; const APlatform: string = '');
    procedure RunInstallTask(const ADep: TBoss4DDependency; const ALock: TBoss4DLock; const ATasks: TList<ITask>);
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Hash,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.SemVer, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env,
  Boss4D.Adapters.Registry,
  Boss4D.Core.Services.IDEIntegration, Boss4D.Core.Services.Workspace;

{ TBoss4DInstallService }

constructor TBoss4DInstallService.Create(
  const APackageRepo: IBoss4DPackageRepository;
  const ALockRepo: IBoss4DLockRepository;
  const AGitClient: IBoss4DGitClient;
  const AHttpClient: IBoss4DHttpClient;
  const ACompiler: IBoss4DCompiler;
  const ALogger: IBoss4DLogger
);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLockRepo := ALockRepo;
  FGitClient := AGitClient;
  FHttpClient := AHttpClient;
  FCompiler := ACompiler;
  FLogger := ALogger;
  FGitCriticalSection := TCriticalSection.Create;
  FGlobalProcessedDeps := TList<string>.Create;
end;

destructor TBoss4DInstallService.Destroy;
begin
  FGlobalProcessedDeps.Free;
  FGitCriticalSection.Free;
  inherited Destroy;
end;

procedure TBoss4DInstallService.ProcessDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock;
  const AProcessedDeps: TList<string>);
var
  LCacheDir: string;
  LTargetDir: string;
  LResolvedVersion: string;
  LResolvedRevision: string;
  LSubDeps: TArray<TBoss4DDependency>;
begin
  var LDepKey := ADep.GetKey;

  // 1. Evita loop de dependencias circulares na ramificacao
  if AProcessedDeps.Contains(LDepKey) then
    Exit;

  // 2. Evita reprocessar dependencias que ja foram baixadas/processadas globalmente
  FGitCriticalSection.Enter;
  try
    if FGlobalProcessedDeps.Contains(LDepKey) then
      Exit;
    FGlobalProcessedDeps.Add(LDepKey);
  finally
    FGitCriticalSection.Leave;
  end;

  AProcessedDeps.Add(LDepKey);

  LCacheDir := TPath.Combine(GetCacheDir, ADep.HashName);
  LTargetDir := TPath.Combine(GetModulesDir, ADep.Name);

  FLogger.Log(TBoss4DLogLevel.Info, 'Resolvendo %s (%s)...', [ADep.Name, ADep.Version]);

  FGitCriticalSection.Enter;
  try
    // 1. Garante que o repositorio de cache existe
    if not TDirectory.Exists(LCacheDir) then
    begin
      FLogger.Log(TBoss4DLogLevel.Debug, 'Clonando no cache global: ' + ADep.Repository);
      FGitClient.CloneCache(ADep, LCacheDir);
    end
    else
    begin
      FLogger.Log(TBoss4DLogLevel.Debug, 'Atualizando cache existente: ' + ADep.Repository);
      FGitClient.UpdateCache(ADep, LCacheDir);
    end;

    // 2. Resolve a melhor versao disponivel usando SemVer se a versao informada for um range
    LResolvedVersion := ResolveDependencyVersion(ADep, LCacheDir);
    LResolvedRevision := FGitClient.ResolveRevision(LCacheDir, LResolvedVersion);

    FLogger.Log(TBoss4DLogLevel.Debug, 'Versao selecionada para %s: %s', [ADep.Name, LResolvedVersion]);

    // 3. Executa o checkout local da versao selecionada na pasta modules/
    FGitClient.Checkout(LCacheDir, LResolvedVersion, LTargetDir);

    // Calcular Checksum da pasta de destino instalada
    var LChecksum := CalculateDirectoryChecksum(LTargetDir);

    // Se a dependÃªncia jÃ¡ constava no arquivo lock existente, validar se o checksum atual bate!
    var LExistingLocked: TBoss4DLockedDependency;
    if ALock.GetInstalled(ADep, LExistingLocked) then
    begin
      if not LExistingLocked.Checksum.IsEmpty and (LExistingLocked.Checksum <> LChecksum) then
      begin
        raise Exception.CreateFmt(
          'ERRO DE SEGURANCA: O checksum da dependencia "%s" (%s) nao confere com o esperado!' + sLineBreak +
          '  -> Calculado: %s' + sLineBreak +
          '  -> Esperado do Lock: %s',
          [ADep.Name, LResolvedVersion, LChecksum, LExistingLocked.Checksum]
        );
      end;
    end;

    // 4. Adiciona no arquivo lock com a sobrecarga de checksum
    ALock.AddDependency(ADep, LResolvedVersion, ADep.HashName, LChecksum);
    if ALock.GetInstalled(ADep, LExistingLocked) then
    begin
      LExistingLocked.Revision := LResolvedRevision;
      LExistingLocked.ResolvedFrom := LResolvedVersion;
      LExistingLocked.ChecksumAlgorithm := 'SHA-256';
    end;
  finally
    FGitCriticalSection.Leave;
  end;

  // 5. Recursividade: Analisa subdependencias do modulo recem-baixado
  var LPkgPath := TPath.Combine(LTargetDir, FILE_PACKAGE);
  if TFile.Exists(LPkgPath) then
  begin
    var LSubPackage := FPackageRepo.Load(LPkgPath);
    try
      LSubDeps := LSubPackage.GetParsedDependencies;

      FGitCriticalSection.Enter;
      try
        var LLockedDependency: TBoss4DLockedDependency;
        if ALock.GetInstalled(ADep, LLockedDependency) then
        begin
          if not LSubPackage.License.IsEmpty then
          begin
            LLockedDependency.LicenseExpression := LSubPackage.License;
            LLockedDependency.LicenseSource := FILE_PACKAGE;
          end;

          LLockedDependency.Dependencies.Clear;
          for var LSubDep in LSubDeps do
            LLockedDependency.Dependencies.Add(LSubDep.GetKey);
        end;
      finally
        FGitCriticalSection.Leave;
      end;

      for var LSubDep in LSubDeps do
      begin
        try
          ProcessDependency(LSubDep, ALock, AProcessedDeps);
        finally
          LSubDep.Free;
        end;
      end;
    finally
      LSubPackage.Free;
    end;
  end;
end;

procedure TBoss4DInstallService.BuildDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock; const APlatform: string = '');
var
  LTargetDir: string;
  LFiles: TArray<string>;
begin
  LTargetDir := TPath.Combine(GetModulesDir, ADep.Name);
  if not TDirectory.Exists(LTargetDir) then
    Exit;

  // Busca arquivos dproj no diretorio da dependencia
  LFiles := TDirectory.GetFiles(LTargetDir, '*' + EXT_DPROJ, TSearchOption.soAllDirectories);

  if Length(LFiles) > 0 then
  begin
    for var LFile in LFiles do
    begin
      var LLowerPath := LFile.ToLower;
      if LLowerPath.Contains('\samples\') or
         LLowerPath.Contains('\tests\') or
         LLowerPath.Contains('\examples\') or
         LLowerPath.Contains('\demo\') or
         LLowerPath.Contains('\demos\') or
         LLowerPath.Contains('\test\') or
         LLowerPath.Contains('\sample\') or
         LLowerPath.Contains('/samples/') or
         LLowerPath.Contains('/tests/') or
         LLowerPath.Contains('/examples/') or
         LLowerPath.Contains('/demo/') or
         LLowerPath.Contains('/demos/') or
         LLowerPath.Contains('/test/') or
         LLowerPath.Contains('/sample/') then
        Continue;

      // Executa compilaÃ§Ã£o nativa
      FCompiler.Compile(LFile, ADep, ALock, APlatform);
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Debug, 'Nenhum projeto dproj encontrado para compilar na dependencia %s.', [ADep.Name]);
  end;
end;

procedure TBoss4DInstallService.Execute(const AInstallSingle: string = ''; const APlatform: string = '');
var
  LPkgPath: string;
  LLockPath: string;
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LActiveDeps: TArray<TBoss4DDependency>;
  LProcessedDeps: TList<string>;
  LTasks: TList<ITask>;
  LSubPkgPath: string;
  LSubPkg: TBoss4DPackage;

  procedure CaptureRootMetadata;
  begin
    LLock.HasRootMetadata := True;
    LLock.RootName := LPkg.Name;
    LLock.RootVersion := LPkg.Version;
    LLock.RootDescription := LPkg.Description;
    LLock.RootHomepage := LPkg.Homepage;
    LLock.RootLicense := LPkg.License;
    LLock.RootDependencies.Clear;
    var LDeclaredDependencies := LPkg.GetParsedDependencies;
    for var LDeclaredDependency in LDeclaredDependencies do
      try
        LLock.RootDependencies.Add(LDeclaredDependency.GetKey);
      finally
        LDeclaredDependency.Free;
      end;
    LLock.RootDependencies.Sort;
  end;
begin
  LPkgPath := GetBossFile;
  LLockPath := TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK);

  if not FPackageRepo.Exists(LPkgPath) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Arquivo boss.json nao encontrado neste diretorio.');
    Exit;
  end;

  LPkg := FPackageRepo.Load(LPkgPath);
  LLock := FLockRepo.Load(LLockPath);
  LProcessedDeps := TList<string>.Create;
  LTasks := TList<ITask>.Create;
  try
    CaptureRootMetadata;
    // Se o lock nao tem hash do pacote, usa o hash do pacote atual
    if LLock.Hash.IsEmpty then
      LLock.Hash := THashMD5.GetHashString(LPkg.Name + LPkg.Version);

    if not AInstallSingle.IsEmpty then
    begin
      // Instala uma unica dependencia (boss install url@versao)
      var LDep := TBoss4DDependency.ParseCommandLine(AInstallSingle);
      try
        ProcessDependency(LDep, LLock, LProcessedDeps);
        LPkg.AddDependency(LDep.Repository, LDep.Version);
        FPackageRepo.Save(LPkg, LPkgPath);
        CaptureRootMetadata;

        // Build da dependencia especifica
        BuildDependency(LDep, LLock, APlatform);
      finally
        LDep.Free;
      end;
    end
    else
    begin
      // Instala todas as dependencias declaradas no boss.json
      var LWorkspaceService := TBoss4DWorkspaceService.Create(FPackageRepo, FLogger);
      var LSubprojects: TList<string> := nil;
      var LActiveDepsList := TList<TBoss4DDependency>.Create;
      try
        LSubprojects := LWorkspaceService.FindSubprojects(LPkg, GetCurrentDir);

        // Adiciona dependÃªncias do projeto raiz
        var LRootDeps := LPkg.GetParsedDependencies;
        for var LDep in LRootDeps do
          LActiveDepsList.Add(LDep);

        // Adiciona dependÃªncias de cada subprojeto do workspace de forma unificada
        for var LSubPath in LSubprojects do
        begin
          LSubPkgPath := TPath.Combine(LSubPath, FILE_PACKAGE);
          LSubPkg := FPackageRepo.Load(LSubPkgPath);
          try
            var LSubDeps := LSubPkg.GetParsedDependencies;
            for var LDep in LSubDeps do
            begin
              // Evita duplicados na fila de instalaÃ§Ã£o
              var LAlreadyExists := False;
              for var LExistingDep in LActiveDepsList do
              begin
                if SameText(LExistingDep.Repository, LDep.Repository) then
                begin
                  LAlreadyExists := True;
                  Break;
                end;
              end;
              if not LAlreadyExists then
                LActiveDepsList.Add(LDep)
              else
                LDep.Free;
            end;
          finally
            LSubPkg.Free;
          end;
        end;

        LActiveDeps := LActiveDepsList.ToArray;
      finally
        LActiveDepsList.Free;
      end;

      if Length(LActiveDeps) = 0 then
      begin
        FLogger.Log(TBoss4DLogLevel.Info, 'Nenhuma dependencia declarada no boss.json.');
        LSubprojects.Free;
        LWorkspaceService.Free;
      end;

      if Length(LActiveDeps) > 0 then
      begin
        FLogger.Log(TBoss4DLogLevel.Info, 'Baixando dependencias do projeto...');

      FGlobalProcessedDeps.Clear;

      // FASE 1: Downloads concorrentes das dependencias de primeiro nivel usando PPL
      for var LDep in LActiveDeps do
      begin
        RunInstallTask(LDep, LLock, LTasks);
      end;

      // Aguarda todos os downloads completarem
      try
        TTask.WaitForAll(LTasks.ToArray);
      except
        on E: EAggregateException do
        begin
          if E.Count > 0 then
            raise Exception.Create(E[0].Message)
          else
            raise;
        end;
      end;

      FLogger.Log(TBoss4DLogLevel.Info, 'Compilando modulos instalados...');

      // FASE 2: Compilacao (deve ser sequencial para evitar lock no msbuild)
      for var LDep in LActiveDeps do
      begin
        BuildDependency(LDep, LLock, APlatform);
      end;

      // Se for um workspace, linka os subprojetos
      if LSubprojects.Count > 0 then
      begin
        LWorkspaceService.LinkWorkspaceSubprojects(GetCurrentDir, LSubprojects);
      end;

      LSubprojects.Free;
      LWorkspaceService.Free;

      // Limpa os objetos de dependencias do array
      for var LDep in LActiveDeps do
        LDep.Free;
      end;
    end;

    // Atualiza metadados do lock e salva
    LLock.Updated := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now);
    FLockRepo.Save(LLock, LLockPath);

    FLogger.Log(TBoss4DLogLevel.Info, 'Instalacao concluida com sucesso!');

    // Dispara a integracao automatica de Library Paths na IDE
    var LRegistry: IBoss4DRegistryService := TBoss4DWindowsRegistryAdapter.Create;
    var LIDEIntegration := TBoss4DIDEIntegrationService.Create(LRegistry, FLogger);
    try
      LIDEIntegration.IntegrateLibraryPaths(APlatform);
    finally
      LIDEIntegration.Free;
    end;
  finally
    LTasks.Free;
    LProcessedDeps.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

procedure TBoss4DInstallService.RunInstallTask(const ADep: TBoss4DDependency; const ALock: TBoss4DLock;
  const ATasks: TList<ITask>);
var
  LProc: TProc;
begin
  LProc := procedure
    var LLocalProcessed: TList<string>;
    begin
      LLocalProcessed := TList<string>.Create;
      try
        ProcessDependency(ADep, ALock, LLocalProcessed);
      finally
        LLocalProcessed.Free;
      end;
    end;

  ATasks.Add(TTask.Run(LProc));
end;

function TBoss4DInstallService.ResolveSemVerRange(const ARangeStr, ACacheDir: string): string;
var
  LVersions: TArray<string>;
  LRange: TBoss4DSemVerRange;
  LBestSemVer: TBoss4DSemVer;
begin
  Result := '';
  LVersions := FGitClient.GetVersions(ACacheDir);
  if Length(LVersions) = 0 then
    Exit;

  LRange := TBoss4DSemVerRange.Create(ARangeStr);
  LBestSemVer := Default(TBoss4DSemVer);

  for var LTag in LVersions do
  begin
    var LVer := TBoss4DSemVer.Create(LTag);
    if LVer.IsValid and LRange.IsSatisfiedBy(LVer) then
    begin
      if LBestSemVer.RawVersion.IsEmpty or (LVer > LBestSemVer) then
        LBestSemVer := LVer;
    end;
  end;

  if LBestSemVer.IsValid then
    Result := LBestSemVer.ToString;
end;

function TBoss4DInstallService.ResolveDependencyVersion(const ADep: TBoss4DDependency; const ACacheDir: string): string;
begin
  if not TBoss4DSemVerRange.IsSemVerRange(ADep.Version) then
    Exit(ADep.Version);

  Result := ResolveSemVerRange(ADep.Version, ACacheDir);
  if Result.IsEmpty then
  begin
    if (ADep.Version = '*') or (ADep.Version = '>=0.0.0') then
      Result := '' // Checkout na branch padrao
    else
      Result := ADep.Version;
  end;
end;

function TBoss4DInstallService.CalculateDirectoryChecksum(const ADirPath: string): string;
var
  LFiles: TArray<string>;
  LSHA2: THashSHA2;
  LBytes: TBytes;
begin
  Result := '';
  if not TDirectory.Exists(ADirPath) then
    Exit;

  try
    LSHA2 := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
    LFiles := TDirectory.GetFiles(ADirPath, '*', TSearchOption.soAllDirectories);
    TArray.Sort<string>(LFiles);

    for var LFile in LFiles do
    begin
      // Ignora subpastas do Git ou arquivos temporarios de build se existirem
      if LFile.Contains('.git' + TPath.DirectorySeparatorChar) then
        Continue;

      try
        LBytes := TFile.ReadAllBytes(LFile);
        if Length(LBytes) > 0 then
          LSHA2.Update(LBytes, Length(LBytes));
      except
        on E: Exception do
          FLogger.Log(TBoss4DLogLevel.Warning, 'Falha silenciosa ao ler arquivo para hash: ' + E.Message);
      end;
    end;
    Result := LSHA2.HashAsString;
  except
    on E: Exception do
      FLogger.Log(TBoss4DLogLevel.Warning, 'Erro ao calcular hash de integridade: ' + E.Message);
  end;
end;

end.
