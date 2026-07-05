unit Boss4D.Core.Services.IDEIntegration;

interface

uses
  Boss4D.Core.Ports, System.Win.Registry, Winapi.Windows;

type
  { Servico para integrar e registrar Library Paths de dependencias automaticamente na IDE do Delphi }
  TBoss4DIDEIntegrationService = class
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;
    FRegistryRoot: HKEY;
    FRegistryKeyPrefix: string;
    procedure UpdateSearchPathForVersion(const AVersion, APlatform, APathToInject: string);
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
    procedure IntegrateLibraryPaths(const APlatform: string = '');
    procedure RegisterDesignTimePackage(const ABPLPath: string; const ADescription: string = '');
    procedure RegisterIDEPackage(const ABPLPath: string; const ADescription: string = '');

    property RegistryRoot: HKEY read FRegistryRoot write FRegistryRoot;
    property RegistryKeyPrefix: string read FRegistryKeyPrefix write FRegistryKeyPrefix;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Consts;

{ TBoss4DIDEIntegrationService }

constructor TBoss4DIDEIntegrationService.Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
  FRegistryRoot := HKEY_CURRENT_USER;
  FRegistryKeyPrefix := 'Software\Embarcadero\BDS\';
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

    if LReg.OpenKey(LSubKey, False) then
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

  LPathToInject := TPath.Combine(TDirectory.GetCurrentDirectory, TPath.Combine('modules', FOLDER_DCU));

  if not APlatform.IsEmpty then
    LPlatforms := TArray<string>.Create(APlatform)
  else
    LPlatforms := TArray<string>.Create('Win32', 'Win64', 'Linux64', 'OSX64', 'Android32', 'Android64', 'iOSDevice64');

  for LVer in LVersions do
  begin
    for LPlat in LPlatforms do
    begin
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
var
  LVersions: TArray<string>;
  LVer: string;
  LReg: TRegistry;
  LSubKey: string;
begin
  LVersions := FRegistry.GetInstalledDelphiVersions;
  for LVer in LVersions do
  begin
    LReg := TRegistry.Create(KEY_WRITE);
    try
      LReg.RootKey := FRegistryRoot;
      LSubKey := FRegistryKeyPrefix + LVer + '\Known IDE Packages';
      if LReg.OpenKey(LSubKey, True) then
      begin
        LReg.WriteString(ABPLPath, ADescription);
        FLogger.Log(TBoss4DLogLevel.Info, '  [OK] Plugin registrado em Known IDE Packages (Delphi %s).', [LVer]);
      end;
    finally
      LReg.Free;
    end;
  end;
end;

end.
