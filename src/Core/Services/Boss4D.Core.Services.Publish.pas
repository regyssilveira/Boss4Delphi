unit Boss4D.Core.Services.Publish;

interface

uses
  System.SysUtils, Boss4D.Core.Ports;

type
  TBoss4DPublishOptions = record
    RegistryUrl: string;
    Token: string;
    DryRun: Boolean;
    RequireCleanGit: Boolean;
    RunTests: Boolean;
  end;

  EBoss4DPublishGate = class(Exception);

  TBoss4DPublishService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLockRepo: IBoss4DLockRepository;
    FHttp: IBoss4DHttpClient;
    FLogger: IBoss4DLogger;
    procedure ValidateGates(const APackagePath, ALockPath: string;
      const AOptions: TBoss4DPublishOptions);
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository;
      const ALockRepo: IBoss4DLockRepository; const AHttp: IBoss4DHttpClient;
      const ALogger: IBoss4DLogger);
    function BuildPayload(const APackagePath, ALockPath: string): string;
    function Execute(const APackagePath, ALockPath: string;
      const AOptions: TBoss4DPublishOptions): string;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.Generics.Collections,
  Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Env;

constructor TBoss4DPublishService.Create(
  const APackageRepo: IBoss4DPackageRepository;
  const ALockRepo: IBoss4DLockRepository; const AHttp: IBoss4DHttpClient;
  const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLockRepo := ALockRepo;
  FHttp := AHttp;
  FLogger := ALogger;
end;

procedure TBoss4DPublishService.ValidateGates(const APackagePath,
  ALockPath: string; const AOptions: TBoss4DPublishOptions);
var
  LPackage: TBoss4DPackage;
  LLock: TBoss4DLock;
  LOutput: string;
begin
  if not FPackageRepo.Exists(APackagePath) then
    raise EBoss4DPublishGate.Create('boss.json nao encontrado.');
  if not FLockRepo.Exists(ALockPath) then
    raise EBoss4DPublishGate.Create('boss-lock.json nao encontrado.');
  LPackage := FPackageRepo.Load(APackagePath);
  LLock := FLockRepo.Load(ALockPath);
  try
    if LPackage.Name.Trim.IsEmpty or LPackage.Version.Trim.IsEmpty then
      raise EBoss4DPublishGate.Create(
        'Nome e versao do pacote sao obrigatorios.');
    if LLock.LockVersion <> TBoss4DLockSchema.CurrentVersion then
      raise EBoss4DPublishGate.CreateFmt(
        'Publish exige lock v%d.', [TBoss4DLockSchema.CurrentVersion]);
    if not LLock.HasRootMetadata or
       not SameText(LLock.RootName, LPackage.Name) or
       (LLock.RootVersion <> LPackage.Version) then
      raise EBoss4DPublishGate.Create(
        'Metadados da raiz divergem entre manifesto e lock.');
    for var LLocked in LLock.Installed.Values do
      if LLocked.Revision.IsEmpty or LLocked.Checksum.IsEmpty then
        raise EBoss4DPublishGate.Create(
          'Todas as dependencias precisam de revisao e checksum.');
    if AOptions.RequireCleanGit then
    begin
      if not ExecuteCommandLine('git status --porcelain',
        TPath.GetDirectoryName(TPath.GetFullPath(APackagePath)), LOutput) then
        raise EBoss4DPublishGate.Create('Nao foi possivel validar o Git.');
      if not LOutput.Trim.IsEmpty then
        raise EBoss4DPublishGate.Create(
          'Worktree possui alteracoes nao commitadas.');
    end;
    if AOptions.RunTests and LPackage.Scripts.ContainsKey('test') then
      if not ExecuteCommandLine(LPackage.Scripts['test'],
        TPath.GetDirectoryName(TPath.GetFullPath(APackagePath)), LOutput) then
        raise EBoss4DPublishGate.Create('Script de testes falhou: ' + LOutput);
  finally
    LLock.Free;
    LPackage.Free;
  end;
end;

function TBoss4DPublishService.BuildPayload(const APackagePath,
  ALockPath: string): string;
var
  LPackage: TBoss4DPackage;
  LLock: TBoss4DLock;
  LRoot, LDependencies: TJSONObject;
begin
  LPackage := FPackageRepo.Load(APackagePath);
  LLock := FLockRepo.Load(ALockPath);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('name', LPackage.Name);
    LRoot.AddPair('version', LPackage.Version);
    LRoot.AddPair('description', LPackage.Description);
    LRoot.AddPair('license', LPackage.License);
    LRoot.AddPair('homepage', LPackage.Homepage);
    LRoot.AddPair('lockVersion', TJSONNumber.Create(LLock.LockVersion));
    LDependencies := TJSONObject.Create;
    var LKeys := TList<string>.Create;
    try
      LKeys.AddRange(LLock.Installed.Keys);
      LKeys.Sort;
      for var LKey in LKeys do
      begin
        var LLocked := LLock.Installed[LKey];
        var LEntry := TJSONObject.Create;
        LEntry.AddPair('version', LLocked.Version);
        LEntry.AddPair('repository', LLocked.Repository);
        LEntry.AddPair('revision', LLocked.Revision);
        LEntry.AddPair('checksum', LLocked.Checksum);
        LEntry.AddPair('scope', LLocked.Scope);
        LDependencies.AddPair(LKey, LEntry);
      end;
    finally
      LKeys.Free;
    end;
    LRoot.AddPair('dependencies', LDependencies);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
    LLock.Free;
    LPackage.Free;
  end;
end;

function TBoss4DPublishService.Execute(const APackagePath, ALockPath: string;
  const AOptions: TBoss4DPublishOptions): string;
var
  LResponse: string;
  LStatus: Integer;
  LUrl: string;
begin
  ValidateGates(APackagePath, ALockPath, AOptions);
  Result := BuildPayload(APackagePath, ALockPath);
  if AOptions.DryRun then
  begin
    FLogger.Log(TBoss4DLogLevel.Info,
      'Dry-run concluido; nenhuma publicacao foi enviada.');
    Exit;
  end;
  if AOptions.RegistryUrl.Trim.IsEmpty then
    raise EBoss4DPublishGate.Create('Informe --registry.');
  if AOptions.Token.IsEmpty then
    raise EBoss4DPublishGate.Create('Token de publicacao ausente.');
  LUrl := AOptions.RegistryUrl.Trim;
  while LUrl.EndsWith('/') do
    Delete(LUrl, Length(LUrl), 1);
  LUrl := LUrl + '/packages';
  LStatus := FHttp.PostJsonAuthorized(LUrl, Result, AOptions.Token, LResponse);
  if (LStatus < 200) or (LStatus >= 300) then
    raise Exception.CreateFmt('Registry respondeu HTTP %d: %s',
      [LStatus, LResponse]);
end;

end.
