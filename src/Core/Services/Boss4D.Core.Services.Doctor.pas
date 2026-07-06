unit Boss4D.Core.Services.Doctor;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico de caso de uso para diagnostico de ambiente local (doctor) }
  TBoss4DDoctorService = class
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;
    function SearchInPath(const AFileName: string): string;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
    function Check(const AFix: Boolean): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.Config;

{ TBoss4DDoctorService }

constructor TBoss4DDoctorService.Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
end;

function TBoss4DDoctorService.Check(const AFix: Boolean): Boolean;
var
  LVersions: TArray<string>;
  LGitVersion: string;
  LGitSuccess: Boolean;
  LCompilerPath: string;
  LMSBuildPath: string;
  LDelphiVersion: string;
  LDelphiPath: string;
  LConfigService: TBoss4DConfigService;
  LConfig: TBoss4DGlobalConfig;
begin
  Result := True;
  FLogger.Log(TBoss4DLogLevel.Info, 'ðŸ©º Executando auto-diagnostico do Boss4D...');

  // 1. Verifica Git CLI
  LGitSuccess := ExecuteCommandLine('git --version', '', LGitVersion);
  if LGitSuccess then
    FLogger.Log(TBoss4DLogLevel.Info, '[OK] Git CLI detectado: ' + LGitVersion)
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Error, '[ERRO] Git CLI nao detectado ou nao disponivel no PATH.');
    Result := False;
  end;

  // 2. Verifica Delphi no Registro
  LVersions := FRegistry.GetInstalledDelphiVersions;
  if Length(LVersions) = 0 then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, '[AVISO] Nenhuma instalacao do Delphi foi encontrada no Registro.');
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Info, '[OK] Versoes do Delphi encontradas no Registro:');
    for LDelphiVersion in LVersions do
    begin
      LDelphiPath := FRegistry.GetDelphiPath(LDelphiVersion);
      if TDirectory.Exists(LDelphiPath) then
        FLogger.Log(TBoss4DLogLevel.Info, '  -> Delphi %s em %s', [LDelphiVersion, LDelphiPath])
      else
        FLogger.Log(TBoss4DLogLevel.Warning, '  -> Delphi %s (Caminho registrado nao existe: %s)', [LDelphiVersion, LDelphiPath]);
    end;
  end;

  // 3. Verifica dcc32 no PATH
  LCompilerPath := SearchInPath('dcc32.exe');
  if not LCompilerPath.IsEmpty then
    FLogger.Log(TBoss4DLogLevel.Info, '[OK] Compilador dcc32 detectado no PATH: ' + LCompilerPath)
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, '[AVISO] Compilador dcc32.exe nao encontrado no PATH.');
    Result := False;
  end;

  // 4. Verifica MSBuild no PATH
  LMSBuildPath := SearchInPath('msbuild.exe');
  if not LMSBuildPath.IsEmpty then
    FLogger.Log(TBoss4DLogLevel.Info, '[OK] MSBuild detectado no PATH: ' + LMSBuildPath)
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, '[AVISO] MSBuild.exe nao encontrado no PATH. A compilacao automatica do Boss4D pode falhar.');
    Result := False;
  end;

  // 5. Aplicar correcao (Fix) se solicitado
  if AFix then
  begin
    FLogger.Log(TBoss4DLogLevel.Info, 'Tentando aplicar correcoes de configuracao...');

    if (Length(LVersions) > 0) then
    begin
      var LLastVer := LVersions[Length(LVersions) - 1];
      var LLastPath := FRegistry.GetDelphiPath(LLastVer);
      if TDirectory.Exists(LLastPath) then
      begin
        LConfigService := TBoss4DConfigService.Create(FLogger);
        try
          LConfig := LConfigService.Load;
          try
            if LConfig.DelphiPath.IsEmpty then
            begin
              LConfig.DelphiPath := LLastPath;
              LConfigService.Save(LConfig);
              FLogger.Log(TBoss4DLogLevel.Info, '[FIX] Configuracao global do Boss4D (delphi path) atualizada para: ' + LLastPath);
            end;
          finally
            LConfig.Free;
          end;
        finally
          LConfigService.Free;
        end;
      end;
    end;

    FLogger.Log(TBoss4DLogLevel.Info, 'Dica: Sempre execute o Boss4D a partir do "RAD Studio Command Prompt" para carregar automaticamente o ambiente compilador.');
  end;
end;

function TBoss4DDoctorService.SearchInPath(const AFileName: string): string;
begin
  Result := FileSearch(AFileName, GetEnvironmentVariable('PATH'));
end;

end.
