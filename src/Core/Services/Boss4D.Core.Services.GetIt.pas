unit Boss4D.Core.Services.GetIt;

interface

uses
  Boss4D.Core.Ports;

type
  { ServiÃ§o para interagir com o GetIt Package Manager nativo do Delphi }
  TBoss4DGetItBridgeService = class
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;
    function FindGetItCmdPath(out APath: string): Boolean;
    function ExecuteGetItCommand(const AArgs: string): Boolean;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);

    // Instala um pacote do catÃ¡logo do GetIt
    procedure InstallPackage(const APackageName: string);

    // Configura a conectividade do GetIt (online / offline)
    procedure SetGetItMode(const AOnline: Boolean);
  end;

implementation

uses
  Winapi.Windows, System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Env;

{ TBoss4DGetItBridgeService }

constructor TBoss4DGetItBridgeService.Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
end;

function TBoss4DGetItBridgeService.FindGetItCmdPath(out APath: string): Boolean;
var
  LVersions: TArray<string>;
  LVer: string;
  LRootDir: string;
begin
  Result := False;
  APath := '';

  LVersions := FRegistry.GetInstalledDelphiVersions;
  if Length(LVersions) = 0 then
    Exit;

  // Busca na versÃ£o mais recente encontrada
  for LVer in LVersions do
  begin
    LRootDir := FRegistry.GetDelphiPath(LVer);
    if not LRootDir.IsEmpty then
    begin
      APath := TPath.Combine(TPath.Combine(LRootDir, 'bin'), 'GetItCmd.exe');
      if TFile.Exists(APath) then
      begin
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TBoss4DGetItBridgeService.ExecuteGetItCommand(const AArgs: string): Boolean;
var
  LGetItCmd: string;
  LOutput: string;
begin
  if not FindGetItCmdPath(LGetItCmd) then
  begin
    // Se nao encontrar fisicamente, tenta chamar do PATH como fallback (para mocks em testes)
    LGetItCmd := 'GetItCmd.exe';
  end;

  FLogger.Log(TBoss4DLogLevel.Debug, '  Executando: %s %s', [LGetItCmd, AArgs]);
  Result := ExecuteCommandLine('"' + LGetItCmd + '" ' + AArgs, TDirectory.GetCurrentDirectory, LOutput);

  if not Result then
    FLogger.Log(TBoss4DLogLevel.Error, 'Falha na execucao do GetIt: ' + LOutput);
end;

procedure TBoss4DGetItBridgeService.InstallPackage(const APackageName: string);
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'Iniciando instalacao via GetIt: %s', [APackageName]);

  if ExecuteGetItCommand('-c=install -package=' + APackageName) then
    FLogger.Log(TBoss4DLogLevel.Info, 'ðŸš€ Pacote "%s" instalado com sucesso via GetIt!', [APackageName])
  else
    raise Exception.Create('Falha ao instalar o pacote "' + APackageName + '" via GetIt.');
end;

procedure TBoss4DGetItBridgeService.SetGetItMode(const AOnline: Boolean);
var
  LModeStr: string;
begin
  if AOnline then
    LModeStr := 'online'
  else
    LModeStr := 'offline';

  FLogger.Log(TBoss4DLogLevel.Info, 'Configurando modo do GetIt para: %s', [LModeStr]);

  if ExecuteGetItCommand('-c=mode -mode=' + LModeStr) then
    FLogger.Log(TBoss4DLogLevel.Info, 'âœ… Modo do GetIt definido para %s com sucesso.', [LModeStr])
  else
    raise Exception.Create('Falha ao configurar conectividade do GetIt.');
end;

end.
