unit Boss4D.Core.Services.IDEIntegration;

interface

uses
  Boss4D.Core.Ports, System.Win.Registry, Winapi.Windows,
  Boss4D.Core.Services.IDERegistration;

type
  { Servico para integrar e registrar Library Paths de dependencias automaticamente na IDE do Delphi }
  TBoss4DIDEIntegrationService = class
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;
    FRegistryRoot: HKEY;
    FRegistryKeyPrefix: string;
    FRegistrationService: TBoss4DIDERegistrationService;
    procedure UpdateSearchPathForVersion(const AVersion, APlatform, APathToInject: string);
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
    destructor Destroy; override;
    procedure IntegrateLibraryPaths(const APlatform: string = '');
    procedure RegisterDesignTimePackage(const ABPLPath: string; const ADescription: string = '');
    procedure RegisterIDEPackage(const ABPLPath: string; const ADescription: string = '');
    procedure RegisterTarget(const ARegistration: TBoss4DIDERegistration);
    function UnregisterTarget(const APackageName, ACompiler,
      APlatform: string): Integer;
    function UninstallPackage(const AOwnerPackage: string): Integer;
    function RepairRegistrations: Integer;

    property RegistryKeyPrefix: string read FRegistryKeyPrefix write FRegistryKeyPrefix;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env;

{ TBoss4DIDEIntegrationService }

constructor TBoss4DIDEIntegrationService.Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
  FRegistryRoot := HKEY_CURRENT_USER;
  FRegistryKeyPrefix := 'Software\Embarcadero\BDS\';
  FRegistrationService := TBoss4DIDERegistrationService.Create(
    TBoss4DWindowsIDERegistryStore.Create,
    TPath.Combine(GetBossHome, 'ide-registrations.json'));
end;

destructor TBoss4DIDEIntegrationService.Destroy;
begin
  FRegistrationService.Free;
  inherited Destroy;
end;

procedure TBoss4DIDEIntegrationService.UpdateSearchPathForVersion(const AVersion, APlatform, APathToInject: string);
var
  LReg: TRegistry;
  LSubKey: string;
  LCurrentPath: string;
  LNewPath: string;
begin
  LReg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    LReg.RootKey := FRegistryRoot;
    LSubKey := FRegistryKeyPrefix + AVersion + '\Library\' + APlatform;

    if LReg.OpenKey(LSubKey, True) then
    begin
      LCurrentPath := LReg.ReadString('Search Path');

      // Se ja contiver o caminho, nao faz nada
      if LCurrentPath.Contains(APathToInject) then
        Exit;

      LNewPath := LCurrentPath;
      if not LNewPath.IsEmpty and not LNewPath.EndsWith(';') then
        LNewPath := LNewPath + ';';

      LNewPath := LNewPath + APathToInject;
      LReg.WriteString('Search Path', LNewPath);
      FLogger.Log(TBoss4DLogLevel.Info, '  [OK] Library Path atualizado para Delphi %s (%s).', [AVersion, APlatform]);
    end;
  finally
    LReg.Free;
  end;
end;

procedure TBoss4DIDEIntegrationService.IntegrateLibraryPaths(const APlatform: string = '');
var
  LVersions: TArray<string>;
  LPlatforms: TArray<string>;
  LPathToInject: string;
  LPlat: string;
  LVer: string;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'Iniciando integracao de Library Paths na IDE...');

  LVersions := FRegistry.GetInstalledDelphiVersions;
  if Length(LVersions) = 0 then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Nenhuma versao do Delphi encontrada no Registro.');
    Exit;
  end;

  if not APlatform.IsEmpty then
    LPlatforms := TArray<string>.Create(APlatform)
  else
    LPlatforms := TArray<string>.Create('Win32', 'Win64', 'Linux64', 'OSX64', 'Android32', 'Android64', 'iOSDevice64');

  for LVer in LVersions do
  begin
    for LPlat in LPlatforms do
    begin
      LPathToInject := TPath.Combine(TDirectory.GetCurrentDirectory,
        TPath.Combine('modules', TPath.Combine(FOLDER_DCU, TPath.Combine(LPlat, 'Debug'))));
      UpdateSearchPathForVersion(LVer, LPlat, LPathToInject);
    end;
  end;

  FLogger.Log(TBoss4DLogLevel.Info, 'Integracao concluida!');
end;

procedure TBoss4DIDEIntegrationService.RegisterDesignTimePackage(const ABPLPath: string; const ADescription: string = '');
var
  LVersions: TArray<string>;
  LVer: string;
  LReg: TRegistry;
  LSubKey: string;
begin
  LVersions := FRegistry.GetInstalledDelphiVersions;
  for LVer in LVersions do
  begin
    // Limpeza preventiva de Known IDE Packages caso exista
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := FRegistryRoot;
      LSubKey := FRegistryKeyPrefix + LVer + '\Known IDE Packages';
      if LReg.OpenKey(LSubKey, False) then
      begin
        if LReg.ValueExists(ABPLPath) then
          LReg.DeleteValue(ABPLPath);
      end;
    finally
      LReg.Free;
    end;

    // Registro em Known Packages
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := FRegistryRoot;
      LSubKey := FRegistryKeyPrefix + LVer + '\Known Packages';
      if LReg.OpenKey(LSubKey, True) then
      begin
        LReg.WriteString(ABPLPath, ADescription);
        FLogger.Log(TBoss4DLogLevel.Info, '  [OK] Pacote registrado em Known Packages (Delphi %s).', [LVer]);
      end;
    finally
      LReg.Free;
    end;
  end;
end;

procedure TBoss4DIDEIntegrationService.RegisterIDEPackage(const ABPLPath: string; const ADescription: string = '');
begin
  RegisterDesignTimePackage(ABPLPath, ADescription);
end;

procedure TBoss4DIDEIntegrationService.RegisterTarget(
  const ARegistration: TBoss4DIDERegistration);
begin
  FRegistrationService.RegisterTarget(ARegistration);
  FLogger.Log(TBoss4DLogLevel.Info,
    '  [OK] Target IDE registrado para Delphi %s (%s).',
    [ARegistration.Compiler, ARegistration.Platform]);
end;

function TBoss4DIDEIntegrationService.UnregisterTarget(
  const APackageName, ACompiler, APlatform: string): Integer;
begin
  Result := FRegistrationService.Unregister(APackageName, ACompiler,
    APlatform);
  FLogger.Log(TBoss4DLogLevel.Info,
    '  [OK] %d registro(s) IDE removido(s).', [Result]);
end;

function TBoss4DIDEIntegrationService.UninstallPackage(
  const AOwnerPackage: string): Integer;
begin
  Result := FRegistrationService.Uninstall(AOwnerPackage);
  FLogger.Log(TBoss4DLogLevel.Info,
    'Pacote %s removido de todas as IDEs: %d registros.',
    [AOwnerPackage, Result]);
end;

function TBoss4DIDEIntegrationService.RepairRegistrations: Integer;
begin
  Result := FRegistrationService.Repair;
  FLogger.Log(TBoss4DLogLevel.Info,
    '  [OK] %d registro(s) IDE reparado(s).', [Result]);
end;

end.
