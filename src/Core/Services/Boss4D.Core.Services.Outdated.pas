unit Boss4D.Core.Services.Outdated;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico para analise de dependencias desatualizadas (outdated) }
  TBoss4DOutdatedService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLockRepo: IBoss4DLockRepository;
    FGitClient: IBoss4DGitClient;
    FLogger: IBoss4DLogger;
    function GetLatestRemoteVersion(const ARepository, ACacheDir: string): string;
  public
    constructor Create(
      const APackageRepo: IBoss4DPackageRepository;
      const ALockRepo: IBoss4DLockRepository;
      const AGitClient: IBoss4DGitClient;
      const ALogger: IBoss4DLogger
    );
    procedure CheckOutdated;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.SemVer, Boss4D.Core.Domain.Consts;

{ TBoss4DOutdatedService }

constructor TBoss4DOutdatedService.Create(
  const APackageRepo: IBoss4DPackageRepository;
  const ALockRepo: IBoss4DLockRepository;
  const AGitClient: IBoss4DGitClient;
  const ALogger: IBoss4DLogger
);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLockRepo := ALockRepo;
  FGitClient := AGitClient;
  FLogger := ALogger;
end;

function TBoss4DOutdatedService.GetLatestRemoteVersion(const ARepository, ACacheDir: string): string;
var
  LVersions: TArray<string>;
  LBestSemVer: TBoss4DSemVer;
  LTag: string;
  LVer: TBoss4DSemVer;
begin
  Result := 'Desconhecida';
  if not TDirectory.Exists(ACacheDir) then
    Exit;

  try
    LVersions := FGitClient.GetVersions(ACacheDir);
    if Length(LVersions) = 0 then
      Exit('Branch principal');

    LBestSemVer := Default(TBoss4DSemVer);
    for LTag in LVersions do
    begin
      LVer := TBoss4DSemVer.Create(LTag);
      if LVer.IsValid then
      begin
        if LBestSemVer.RawVersion.IsEmpty or (LVer > LBestSemVer) then
          LBestSemVer := LVer;
      end;
    end;

    if LBestSemVer.IsValid then
      Result := LBestSemVer.ToString;
  except
    // Ignora falhas silenciosamente e mantem padrao
  end;
end;

procedure TBoss4DOutdatedService.CheckOutdated;
var
  LPkgPath: string;
  LLockPath: string;
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDeps: TArray<TBoss4DDependency>;
  LLocked: TBoss4DLockedDependency;
  LCacheDir: string;
  LLatest: string;
  LInstalledVer: string;
  LStatus: string;
  I: Integer;
  LDep: TBoss4DDependency;
begin
  LPkgPath := GetBossFile;
  LLockPath := TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK);

  if not FPackageRepo.Exists(LPkgPath) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Arquivo boss.json nao encontrado neste diretorio.');
    Exit;
  end;

  FLogger.Log(TBoss4DLogLevel.Info, 'Buscando informacoes de atualizacao de pacotes...');

  LPkg := FPackageRepo.Load(LPkgPath);
  LLock := FLockRepo.Load(LLockPath);
  try
    LDeps := LPkg.GetParsedDependencies;
    try
      if Length(LDeps) = 0 then
      begin
        FLogger.Log(TBoss4DLogLevel.Info, 'Nenhuma dependencia declarada no projeto.');
        Exit;
      end;

      FLogger.Log(TBoss4DLogLevel.Info, '');
      FLogger.Log(TBoss4DLogLevel.Info, '| Dependencia | Instalada | Mais Recente | Status |');
      FLogger.Log(TBoss4DLogLevel.Info, '| --- | --- | --- | --- |');

      for I := 0 to Length(LDeps) - 1 do
      begin
        LDep := LDeps[I];
        LInstalledVer := 'Nao instalada';
        LStatus := 'Pendente';
        LLatest := 'Desconhecida';

        if LLock.GetInstalled(LDep, LLocked) then
        begin
          LInstalledVer := LLocked.Version;
          LCacheDir := TPath.Combine(GetCacheDir, LDep.HashName);
          LLatest := GetLatestRemoteVersion(LDep.Repository, LCacheDir);

          if LLatest = LInstalledVer then
            LStatus := 'Atualizado'
          else
            LStatus := 'Desatualizado';
        end;

        FLogger.Log(TBoss4DLogLevel.Info, Format('| %s | %s | %s | %s |', [LDep.Name, LInstalledVer, LLatest, LStatus]));
      end;
    finally
      for I := 0 to Length(LDeps) - 1 do
        LDeps[I].Free;
    end;
  finally
    LLock.Free;
    LPkg.Free;
  end;
end;

end.
