unit Boss4D.Core.Services.Install;

interface

uses
  System.Generics.Collections, System.Threading, System.SyncObjs, Boss4D.Core.Ports,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Package;

type
  TBoss4DInstallOptions = record
    Platform: string;
    Locked: Boolean;
    Offline: Boolean;
    CleanModules: Boolean;
    Production: Boolean;
    Development: Boolean;
    InstallSingle: string;
  end;

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
    FOptions: TBoss4DInstallOptions;
    FTrust: TBoss4DPackageTrust;

    procedure ProcessDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock;
      const AProcessedDeps: TList<string>);
    procedure BuildDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock;
      const APlatform: string = ''; const ACompilerVersion: string = '');
    function ResolveBuildProjects(const ADep: TBoss4DDependency): TArray<string>;
    function DiscoverBuildProjects(const ARootDirectory: string): TArray<string>;
    function ResolveEffectivePlatform(const APackage: TBoss4DPackage;
      const ACliPlatform: string): string;
    function ResolveRootLazarusProjects(
      const APackage: TBoss4DPackage): TArray<string>;
    procedure IntegrateLazarusProjectPaths(const APackage: TBoss4DPackage;
      const APlatform: string);
    function ResolveSemVerRange(const ARangeStr, ACacheDir: string): string;
    function ResolveDependencyVersion(const ADep: TBoss4DDependency; const ACacheDir: string): string;
    function CalculateDirectoryChecksum(const ADirPath: string): string;
    procedure ExecuteCore(const AInstallSingle: string;
      const APlatform: string);
    procedure ValidateLockedManifest(const APackage: TBoss4DPackage;
      const ALock: TBoss4DLock);
    procedure ApplyLockScopes(const ALock: TBoss4DLock);
    function SignerAllowed(const ASigner: string): Boolean;
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

    procedure Execute(const AInstallSingle: string = '';
      const APlatform: string = ''); overload;
    procedure Execute(const AOptions: TBoss4DInstallOptions); overload;
    procedure RunInstallTask(const ADep: TBoss4DDependency; const ALock: TBoss4DLock; const ATasks: TList<ITask>);
  end;

implementation

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Hash,
  Boss4D.Core.Domain.SemVer, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env,
  Boss4D.Adapters.Registry,
  Boss4D.Core.Services.IDEIntegration, Boss4D.Core.Services.Workspace,
  Boss4D.Core.Services.SourceNormalizer,
  Boss4D.Core.Services.LazarusProject,
  Boss4D.Core.Services.Transaction,
  Boss4D.Core.Services.ArtifactCache;

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

function TBoss4DInstallService.ResolveRootLazarusProjects(
  const APackage: TBoss4DPackage): TArray<string>;
var
  LProjects: TList<string>;
  LRootPath: string;
begin
  LProjects := TList<string>.Create;
  try
    LRootPath := IncludeTrailingPathDelimiter(TPath.GetFullPath(GetCurrentDir));
    if APackage.Projects.Count > 0 then
    begin
      for var LDeclaredProject in APackage.Projects do
      begin
        var LProjectPath := TPath.GetFullPath(
          TPath.Combine(GetCurrentDir, LDeclaredProject));
        if not LProjectPath.StartsWith(LRootPath, True) then
          raise EArgumentException.CreateFmt(
            'Projeto declarado fora da raiz: %s', [LDeclaredProject]);

        var LExtension := TPath.GetExtension(LProjectPath);
        if SameText(LExtension, EXT_LPI) or SameText(LExtension, EXT_LPK) then
          LProjects.Add(LProjectPath);
      end;
    end
    else
    begin
      LProjects.AddRange(TDirectory.GetFiles(GetCurrentDir, '*' + EXT_LPI,
        TSearchOption.soTopDirectoryOnly));
      LProjects.AddRange(TDirectory.GetFiles(GetCurrentDir, '*' + EXT_LPK,
        TSearchOption.soTopDirectoryOnly));
      LProjects.Sort;
    end;
    Result := LProjects.ToArray;
  finally
    LProjects.Free;
  end;
end;

procedure TBoss4DInstallService.IntegrateLazarusProjectPaths(
  const APackage: TBoss4DPackage; const APlatform: string);
var
  LUnitPaths: TList<string>;
begin
  var LProjects := ResolveRootLazarusProjects(APackage);
  if Length(LProjects) = 0 then
    Exit;

  LUnitPaths := TList<string>.Create;
  try
    var LDependencies := APackage.GetParsedDependencies;
    try
      for var LDependency in LDependencies do
      begin
        var LSearchPath := FCompiler.BuildSearchPath(LDependency, APlatform);
        for var LPath in LSearchPath.Split([';']) do
          if not LPath.Trim.IsEmpty then
            LUnitPaths.Add(LPath.Trim);
      end;
    finally
      for var LDependency in LDependencies do
        LDependency.Free;
    end;

    if LUnitPaths.Count = 0 then
      Exit;

    for var LProjectPath in LProjects do
      if TBoss4DLazarusProjectService.UpdateUnitPaths(
        LProjectPath, LUnitPaths.ToArray) then
        FLogger.Log(TBoss4DLogLevel.Info,
          'Paths de dependencias integrados ao projeto Lazarus: %s',
          [TPath.GetFileName(LProjectPath)]);
  finally
    LUnitPaths.Free;
  end;
end;

procedure TBoss4DInstallService.ProcessDependency(const ADep: TBoss4DDependency; const ALock: TBoss4DLock;
  const AProcessedDeps: TList<string>);
var
  LCacheDir: string;
  LTargetDir: string;
  LResolvedVersion: string;
  LResolvedRevision: string;
  LSubDeps: TArray<TBoss4DDependency>;
  LExistingLocked: TBoss4DLockedDependency;
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
  LTargetDir := TPath.Combine(GetModulesDir, ADep.StorageName);

  FLogger.Log(TBoss4DLogLevel.Info, 'Resolvendo %s (%s)...', [ADep.Name, ADep.Version]);

  FGitCriticalSection.Enter;
  try
    // 1. Garante que o repositorio de cache existe
    if not TDirectory.Exists(LCacheDir) then
    begin
      if FOptions.Offline then
        raise Exception.CreateFmt(
          'Cache ausente para %s; --offline proibe acesso a rede.',
          [ADep.Name]);
      FLogger.Log(TBoss4DLogLevel.Debug, 'Clonando no cache global: ' + ADep.Repository);
      FGitClient.CloneCache(ADep, LCacheDir);
    end
    else if not FOptions.Offline then
    begin
      FLogger.Log(TBoss4DLogLevel.Debug, 'Atualizando cache existente: ' + ADep.Repository);
      FGitClient.UpdateCache(ADep, LCacheDir);
    end;

    // 2. Resolve a melhor versao disponivel usando SemVer se a versao informada for um range
    if FOptions.Locked then
    begin
      if not ALock.GetInstalled(ADep, LExistingLocked) then
        raise Exception.CreateFmt(
          'Dependencia %s nao existe no lock congelado.', [ADep.Name]);
      LResolvedVersion := LExistingLocked.Version;
      LResolvedRevision := LExistingLocked.Revision;
      if LResolvedRevision.IsEmpty then
        LResolvedRevision := LResolvedVersion;
    end
    else
    begin
      LResolvedVersion := ResolveDependencyVersion(ADep, LCacheDir);
      LResolvedRevision := FGitClient.ResolveRevision(LCacheDir, LResolvedVersion);
    end;

    if Assigned(FTrust) and FTrust.RequireSignedCommits then
    begin
      var LSigner: string;
      if not FGitClient.VerifyCommit(LCacheDir, LResolvedRevision, LSigner) then
        raise Exception.CreateFmt('Commit sem assinatura valida para %s: %s',
          [ADep.Name, LResolvedRevision]);
      if not SignerAllowed(LSigner) then
        raise Exception.CreateFmt('Signatario nao autorizado para %s: %s',
          [ADep.Name, LSigner]);
    end;
    if Assigned(FTrust) and FTrust.RequireSignedTags and
       not LResolvedVersion.IsEmpty then
    begin
      var LTagSigner: string;
      if not FGitClient.VerifyTag(LCacheDir, LResolvedVersion,
        LTagSigner) then
        raise Exception.CreateFmt('Tag sem assinatura valida para %s: %s',
          [ADep.Name, LResolvedVersion]);
      if not SignerAllowed(LTagSigner) then
        raise Exception.CreateFmt(
          'Signatario da tag nao autorizado para %s: %s',
          [ADep.Name, LTagSigner]);
    end;

    FLogger.Log(TBoss4DLogLevel.Debug, 'Versao selecionada para %s: %s', [ADep.Name, LResolvedVersion]);

    // 3. Executa o checkout local da versao selecionada na pasta modules/
    if FOptions.Locked then
      FGitClient.Checkout(LCacheDir, LResolvedRevision, LTargetDir)
    else
      FGitClient.Checkout(LCacheDir, LResolvedVersion, LTargetDir);

    // Normaliza antes do checksum: o lock e a SBOM descrevem exatamente o
    // conteudo instalado, sem divergencia entre checkouts LF e CRLF.
    TBoss4DSourceNormalizer.NormalizeDirectoryToCRLF(LTargetDir);

    // Calcular Checksum da pasta de destino instalada
    var LChecksum := CalculateDirectoryChecksum(LTargetDir);

    // Se a dependÃªncia jÃ¡ constava no arquivo lock existente, validar se o checksum atual bate!
    if ALock.GetInstalled(ADep, LExistingLocked) then
    begin
      if (FOptions.Locked or
          SameText(LExistingLocked.Revision, LResolvedRevision)) and
         not LExistingLocked.Checksum.IsEmpty and
         (LExistingLocked.Checksum <> LChecksum) then
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
    if not FOptions.Locked then
    begin
      ALock.AddDependency(ADep, LResolvedVersion, ADep.HashName, LChecksum);
      if ALock.GetInstalled(ADep, LExistingLocked) then
      begin
        LExistingLocked.Revision := LResolvedRevision;
        LExistingLocked.ResolvedFrom := LResolvedVersion;
        LExistingLocked.ChecksumAlgorithm := 'SHA-256';
      end;
    end;
  finally
    FGitCriticalSection.Leave;
  end;

  // 5. Recursividade: Analisa subdependencias do modulo recem-baixado
  if FOptions.Locked then
  begin
    if ALock.GetInstalled(ADep, LExistingLocked) then
      for var LChildKey in LExistingLocked.Dependencies do
      begin
        var LChildLocked: TBoss4DLockedDependency;
        if not ALock.Installed.TryGetValue(LChildKey, LChildLocked) then
          raise Exception.CreateFmt(
            'Lock inconsistente: %s referencia %s ausente.',
            [ADep.Name, LChildKey]);
        var LChildDep := TBoss4DDependency.Create(
          LChildLocked.Repository, LChildLocked.Version);
        try
          LChildDep.Scope := LChildLocked.Scope;
          ProcessDependency(LChildDep, ALock, AProcessedDeps);
        finally
          LChildDep.Free;
        end;
      end;
    Exit;
  end;

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
          if SameText(ADep.Scope, 'development') then
            LSubDep.Scope := 'development';
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

function TBoss4DInstallService.DiscoverBuildProjects(
  const ARootDirectory: string): TArray<string>;
var
  LProjects: TList<string>;
begin
  LProjects := TList<string>.Create;
  try
    LProjects.AddRange(TDirectory.GetFiles(ARootDirectory, '*' + EXT_DPROJ,
      TSearchOption.soAllDirectories));
    LProjects.AddRange(TDirectory.GetFiles(ARootDirectory, '*' + EXT_LPI,
      TSearchOption.soAllDirectories));
    LProjects.AddRange(TDirectory.GetFiles(ARootDirectory, '*' + EXT_LPK,
      TSearchOption.soAllDirectories));
    LProjects.Sort;
    Result := LProjects.ToArray;
  finally
    LProjects.Free;
  end;
end;

function TBoss4DInstallService.ResolveBuildProjects(
  const ADep: TBoss4DDependency): TArray<string>;
var
  LTargetDir: string;
  LPackagePath: string;
  LPackage: TBoss4DPackage;
  LProjects: TList<string>;
begin
  SetLength(Result, 0);
  LTargetDir := TPath.Combine(GetModulesDir, ADep.StorageName);
  if not TDirectory.Exists(LTargetDir) then
    Exit;

  LPackagePath := TPath.Combine(LTargetDir, FILE_PACKAGE);
  if not TFile.Exists(LPackagePath) then
    Exit(DiscoverBuildProjects(LTargetDir));

  LPackage := FPackageRepo.Load(LPackagePath);
  try
    if LPackage.Projects.Count = 0 then
      Exit(DiscoverBuildProjects(LTargetDir));

    LProjects := TList<string>.Create;
    try
      var LRootPath := IncludeTrailingPathDelimiter(TPath.GetFullPath(LTargetDir));
      for var LDeclaredProject in LPackage.Projects do
      begin
        var LProjectPath := TPath.GetFullPath(TPath.Combine(LTargetDir,
          LDeclaredProject));
        if not LProjectPath.StartsWith(LRootPath, True) then
          raise EArgumentException.Create('Projeto declarado fora da raiz da dependencia: ' +
            LDeclaredProject);
        var LExtension := TPath.GetExtension(LProjectPath);
        if not SameText(LExtension, EXT_DPROJ) and
           not SameText(LExtension, EXT_LPI) and
           not SameText(LExtension, EXT_LPK) then
          raise EArgumentException.Create('Extensao de projeto ainda nao suportada: ' +
            LDeclaredProject);
        if not TFile.Exists(LProjectPath) then
          raise EFileNotFoundException.Create('Projeto declarado nao encontrado: ' +
            LDeclaredProject);
        if not LProjects.Contains(LProjectPath) then
          LProjects.Add(LProjectPath);
      end;
      Result := LProjects.ToArray;
    finally
      LProjects.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

function TBoss4DInstallService.ResolveEffectivePlatform(
  const APackage: TBoss4DPackage; const ACliPlatform: string): string;
begin
  if not ACliPlatform.IsEmpty then
    Exit(ACliPlatform);
  if not APackage.Toolchain.Platform.IsEmpty then
    Exit(APackage.Toolchain.Platform);
  if APackage.Engines.Platforms.Count > 0 then
    Exit(APackage.Engines.Platforms[0]);
  Result := 'Win32';
end;

procedure TBoss4DInstallService.BuildDependency(const ADep: TBoss4DDependency;
  const ALock: TBoss4DLock; const APlatform: string = '';
  const ACompilerVersion: string = '');
var
  LFiles: TArray<string>;
  LLocked: TBoss4DLockedDependency;
  LChecksum: string;
  LArtifactCache: TBoss4DArtifactCacheService;
begin
  LChecksum := '';
  if ALock.GetInstalled(ADep, LLocked) then
    LChecksum := LLocked.Checksum;
  LArtifactCache := TBoss4DArtifactCacheService.Create;
  try
    if LArtifactCache.Restore(ADep, LChecksum, APlatform,
      ACompilerVersion) then
    begin
      FLogger.Log(TBoss4DLogLevel.Info,
        'Artefatos restaurados do cache: ' + ADep.Name);
      Exit;
    end;
  LFiles := ResolveBuildProjects(ADep);

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
      if not FCompiler.Compile(LFile, ADep, ALock, APlatform,
        ACompilerVersion) then
        raise Exception.Create('Falha ao compilar dependencia: ' + ADep.Name);
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Debug, 'Nenhum projeto dproj encontrado para compilar na dependencia %s.', [ADep.Name]);
  end;
    LArtifactCache.Store(ADep, LChecksum, APlatform, ACompilerVersion);
  finally
    LArtifactCache.Free;
  end;
end;

procedure TBoss4DInstallService.Execute(const AInstallSingle: string;
  const APlatform: string);
var
  LTransaction: TBoss4DProjectTransaction;
begin
  LTransaction := TBoss4DProjectTransaction.Create(GetCurrentDir);
  try
    ExecuteCore(AInstallSingle, APlatform);
    LTransaction.Commit;
  finally
    LTransaction.Free;
  end;
end;

function TBoss4DInstallService.SignerAllowed(const ASigner: string): Boolean;
begin
  if not Assigned(FTrust) or (FTrust.AllowedSigners.Count = 0) then
    Exit(True);
  for var LAllowed in FTrust.AllowedSigners do
    if SameText(LAllowed.Trim, ASigner.Trim) then
      Exit(True);
  Result := False;
end;

procedure TBoss4DInstallService.Execute(
  const AOptions: TBoss4DInstallOptions);
var
  LTransaction: TBoss4DProjectTransaction;
begin
  LTransaction := TBoss4DProjectTransaction.Create(GetCurrentDir);
  try
    FOptions := AOptions;
    ExecuteCore(AOptions.InstallSingle, AOptions.Platform);
    LTransaction.Commit;
  finally
    FOptions := Default(TBoss4DInstallOptions);
    LTransaction.Free;
  end;
end;

procedure TBoss4DInstallService.ValidateLockedManifest(
  const APackage: TBoss4DPackage; const ALock: TBoss4DLock);
var
  LDeclared: TList<string>;
  LDep: TBoss4DDependency;
  LKey: string;
begin
  if not ALock.HasRootMetadata then
    raise Exception.Create(
      'O lock nao possui metadados da raiz; execute boss4d install.');
  LDeclared := TList<string>.Create;
  try
    for var LPair in APackage.Dependencies do
    begin
      LDep := TBoss4DDependency.Parse(LPair.Key, LPair.Value);
      try
        LDeclared.Add(LDep.GetKey);
      finally
        LDep.Free;
      end;
    end;
    LDeclared.Sort;
    if LDeclared.Count <> ALock.RootDependencies.Count then
      raise Exception.Create(
        'boss.json diverge do lock; instalacao congelada recusada.');
    for LKey in LDeclared do
      if not ALock.RootDependencies.Contains(LKey) then
        raise Exception.CreateFmt(
          'Dependencia %s nao esta registrada no lock.', [LKey]);
    if not FOptions.Production then
    begin
      LDeclared.Clear;
      for var LPair in APackage.DevDependencies do
      begin
        LDep := TBoss4DDependency.Parse(LPair.Key, LPair.Value);
        try
          LDeclared.Add(LDep.GetKey);
        finally
          LDep.Free;
        end;
      end;
      if LDeclared.Count <> ALock.RootDevDependencies.Count then
        raise Exception.Create(
          'devDependencies divergem do lock congelado.');
      for LKey in LDeclared do
        if not ALock.RootDevDependencies.Contains(LKey) then
          raise Exception.CreateFmt(
            'Dependencia de desenvolvimento %s nao esta no lock.', [LKey]);
    end;
  finally
    LDeclared.Free;
  end;
end;

procedure TBoss4DInstallService.ApplyLockScopes(const ALock: TBoss4DLock);
var
  LVisited: TDictionary<string, Boolean>;

  procedure MarkRuntime(const AKey: string);
  var
    LLocked: TBoss4DLockedDependency;
    LChild: string;
  begin
    if LVisited.ContainsKey(AKey) then
      Exit;
    LVisited.Add(AKey, True);
    if not ALock.Installed.TryGetValue(AKey, LLocked) then
      Exit;
    LLocked.Scope := 'runtime';
    for LChild in LLocked.Dependencies do
      MarkRuntime(LChild);
  end;

begin
  for var LLocked in ALock.Installed.Values do
    LLocked.Scope := 'development';
  LVisited := TDictionary<string, Boolean>.Create;
  try
    for var LRootKey in ALock.RootDependencies do
      MarkRuntime(LRootKey);
  finally
    LVisited.Free;
  end;
end;

procedure TBoss4DInstallService.ExecuteCore(const AInstallSingle: string;
  const APlatform: string);
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
  LEffectivePlatform: string;
  LEffectiveCompiler: string;

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
    LLock.RootDevDependencies.Clear;
    var LDeclaredDevDependencies := LPkg.GetParsedDevDependencies;
    for var LDeclaredDevDependency in LDeclaredDevDependencies do
      try
        LLock.RootDevDependencies.Add(LDeclaredDevDependency.GetKey);
      finally
        LDeclaredDevDependency.Free;
      end;
    LLock.RootDevDependencies.Sort;
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
    if FOptions.Locked then
    begin
      if not FLockRepo.Exists(LLockPath) then
        raise Exception.Create(
          'boss-lock.json e obrigatorio para --locked.');
      ValidateLockedManifest(LPkg, LLock);
    end;
    if FOptions.CleanModules and TDirectory.Exists(GetModulesDir) then
      TDirectory.Delete(GetModulesDir, True);
    FTrust := LPkg.Trust;
    LEffectivePlatform := ResolveEffectivePlatform(LPkg, APlatform);
    LEffectiveCompiler := LPkg.Toolchain.Compiler;
    CaptureRootMetadata;
    // Se o lock nao tem hash do pacote, usa o hash do pacote atual
    if LLock.Hash.IsEmpty then
      LLock.Hash := THashMD5.GetHashString(LPkg.Name + LPkg.Version);

    if not AInstallSingle.IsEmpty then
    begin
      // Instala uma unica dependencia (boss install url@versao)
      var LDep := TBoss4DDependency.ParseCommandLine(AInstallSingle);
      try
        if FOptions.Development then
          LDep.Scope := 'development';
        ProcessDependency(LDep, LLock, LProcessedDeps);
        if FOptions.Development then
          LPkg.AddDevDependency(LDep.Repository, LDep.Version)
        else
          LPkg.AddDependency(LDep.Repository, LDep.Version);
        FPackageRepo.Save(LPkg, LPkgPath);
        CaptureRootMetadata;

        // Build da dependencia especifica
        BuildDependency(LDep, LLock, LEffectivePlatform, LEffectiveCompiler);
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
        if not FOptions.Production then
        begin
          var LRootDevDeps := LPkg.GetParsedDevDependencies;
          for var LDep in LRootDevDeps do
          begin
            var LAlreadyExists := False;
            for var LExistingDep in LActiveDepsList do
              if SameText(LExistingDep.Repository, LDep.Repository) then
              begin
                LAlreadyExists := True;
                Break;
              end;
            if not LAlreadyExists then
              LActiveDepsList.Add(LDep)
            else
              LDep.Free;
          end;
        end;

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
            if not FOptions.Production then
            begin
              var LSubDevDeps := LSubPkg.GetParsedDevDependencies;
              for var LDep in LSubDevDeps do
              begin
                var LAlreadyExists := False;
                for var LExistingDep in LActiveDepsList do
                  if SameText(LExistingDep.Repository, LDep.Repository) then
                  begin
                    LAlreadyExists := True;
                    Break;
                  end;
                if not LAlreadyExists then
                  LActiveDepsList.Add(LDep)
                else
                  LDep.Free;
              end;
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
        BuildDependency(LDep, LLock, LEffectivePlatform, LEffectiveCompiler);
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
    if not FOptions.Locked then
    begin
      ApplyLockScopes(LLock);
      LLock.Updated := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now);
      FLockRepo.Save(LLock, LLockPath);
    end;

    IntegrateLazarusProjectPaths(LPkg, LEffectivePlatform);

    FLogger.Log(TBoss4DLogLevel.Info, 'Instalacao concluida com sucesso!');

    // Sem dependencias nao ha Library Paths a registrar; evita mutacao desnecessaria da IDE.
    if LLock.Installed.Count > 0 then
    begin
      var LRegistry: IBoss4DRegistryService := TBoss4DWindowsRegistryAdapter.Create;
      var LIDEIntegration := TBoss4DIDEIntegrationService.Create(LRegistry, FLogger);
      try
        LIDEIntegration.IntegrateLibraryPaths(LEffectivePlatform);
      finally
        LIDEIntegration.Free;
      end;
    end;
  finally
    FTrust := nil;
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
