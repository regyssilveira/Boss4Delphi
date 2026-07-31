unit Boss4D.Core.Services.Doctor;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Ports;

type
  TBoss4DEnvironmentHealth = (HealthOk, HealthWarning, HealthError);

  TBoss4DDoctorItem = class
  private
    FCode: string;
    FGroup: string;
    FHealth: TBoss4DEnvironmentHealth;
    FMessage: string;
    FRemediation: string;
    FFixable: Boolean;
    FFixed: Boolean;
  public
    property Code: string read FCode write FCode;
    property Group: string read FGroup write FGroup;
    property Health: TBoss4DEnvironmentHealth read FHealth write FHealth;
    property Message: string read FMessage write FMessage;
    property Remediation: string read FRemediation write FRemediation;
    property Fixable: Boolean read FFixable write FFixable;
    property Fixed: Boolean read FFixed write FFixed;
  end;

  TBoss4DDoctorReport = class
  private
    FItems: TObjectList<TBoss4DDoctorItem>;
    function GetPassed: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function HasCode(const ACode: string): Boolean;
    property Items: TObjectList<TBoss4DDoctorItem> read FItems;
    property Passed: Boolean read GetPassed;
  end;

  { Servico de caso de uso para diagnostico de ambiente local (doctor). }
  TBoss4DDoctorService = class
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;
    function SearchInPath(const AFileName: string): string;
    procedure AddItem(const AReport: TBoss4DDoctorReport;
      const ACode, AGroup: string; const AHealth: TBoss4DEnvironmentHealth;
      const AMessage, ARemediation: string; const AFixable: Boolean = False;
      const AFixed: Boolean = False);
  public
    constructor Create(const ARegistry: IBoss4DRegistryService;
      const ALogger: IBoss4DLogger);
    function Diagnose(const AFix: Boolean): TBoss4DDoctorReport;
    function Check(const AFix: Boolean): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.Config;

constructor TBoss4DDoctorReport.Create;
begin
  inherited Create;
  FItems := TObjectList<TBoss4DDoctorItem>.Create(True);
end;

destructor TBoss4DDoctorReport.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TBoss4DDoctorReport.GetPassed: Boolean;
begin
  Result := True;
  for var LItem in FItems do
    if LItem.Health = HealthError then
      Exit(False);
end;

function TBoss4DDoctorReport.HasCode(const ACode: string): Boolean;
begin
  Result := False;
  for var LItem in FItems do
    if SameText(LItem.Code, ACode) then
      Exit(True);
end;

constructor TBoss4DDoctorService.Create(
  const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
end;

procedure TBoss4DDoctorService.AddItem(const AReport: TBoss4DDoctorReport;
  const ACode, AGroup: string; const AHealth: TBoss4DEnvironmentHealth;
  const AMessage, ARemediation: string; const AFixable, AFixed: Boolean);
var
  LItem: TBoss4DDoctorItem;
  LLevel: TBoss4DLogLevel;
  LPrefix: string;
begin
  LItem := TBoss4DDoctorItem.Create;
  LItem.Code := ACode;
  LItem.Group := AGroup;
  LItem.Health := AHealth;
  LItem.Message := AMessage;
  LItem.Remediation := ARemediation;
  LItem.Fixable := AFixable;
  LItem.Fixed := AFixed;
  AReport.Items.Add(LItem);
  case AHealth of
    HealthOk:
      begin
        LLevel := TBoss4DLogLevel.Info;
        if AFixed then LPrefix := '[FIX] ' else LPrefix := '[OK] ';
      end;
    HealthWarning:
      begin
        LLevel := TBoss4DLogLevel.Warning;
        LPrefix := '[AVISO] ';
      end;
  else
    LLevel := TBoss4DLogLevel.Error;
    LPrefix := '[ERRO] ';
  end;
  FLogger.Log(LLevel, LPrefix + AMessage);
end;

function TBoss4DDoctorService.Diagnose(
  const AFix: Boolean): TBoss4DDoctorReport;
var
  LVersions: TArray<string>;
  LGitVersion: string;
  LCompilerPath: string;
  LMSBuildPath: string;
  LDelphiVersion: string;
  LDelphiPath: string;
  LConfigService: TBoss4DConfigService;
  LConfig: TBoss4DGlobalConfig;
begin
  Result := TBoss4DDoctorReport.Create;
  FLogger.Log(TBoss4DLogLevel.Info,
    'Executando auto-diagnostico do Boss4D...');

  if ExecuteCommandLine('git --version', '', LGitVersion) then
    AddItem(Result, 'GIT_CLI', 'Ferramentas', HealthOk,
      'Git CLI detectado: ' + LGitVersion, '')
  else
    AddItem(Result, 'GIT_CLI', 'Ferramentas', HealthError,
      'Git CLI nao detectado ou nao disponivel no PATH.',
      'Instale o Git e adicione git.exe ao PATH.');

  LVersions := FRegistry.GetInstalledDelphiVersions;
  if Length(LVersions) = 0 then
    AddItem(Result, 'DELPHI_REGISTRY', 'Delphi', HealthWarning,
      'Nenhuma instalacao do Delphi foi encontrada no Registro.',
      'Instale o RAD Studio ou valide as chaves BDS do usuario.')
  else
  begin
    AddItem(Result, 'DELPHI_REGISTRY', 'Delphi', HealthOk,
      Format('%d instalacao(oes) do Delphi encontrada(s) no Registro.',
        [Length(LVersions)]), '');
    for LDelphiVersion in LVersions do
    begin
      LDelphiPath := FRegistry.GetDelphiPath(LDelphiVersion);
      if TDirectory.Exists(LDelphiPath) then
        AddItem(Result, 'DELPHI_' + LDelphiVersion, 'Delphi', HealthOk,
          Format('Delphi %s em %s', [LDelphiVersion, LDelphiPath]), '')
      else
        AddItem(Result, 'DELPHI_' + LDelphiVersion, 'Delphi',
          HealthWarning, Format(
            'Delphi %s possui caminho registrado inexistente: %s',
            [LDelphiVersion, LDelphiPath]),
          'Repare a instalacao ou remova a chave BDS obsoleta.');
    end;
  end;

  LCompilerPath := SearchInPath('dcc32.exe');
  if not LCompilerPath.IsEmpty then
    AddItem(Result, 'DCC32_PATH', 'Compilador', HealthOk,
      'Compilador dcc32 detectado no PATH: ' + LCompilerPath, '')
  else
    AddItem(Result, 'DCC32_PATH', 'Compilador', HealthError,
      'Compilador dcc32.exe nao encontrado no PATH.',
      'Execute pelo RAD Studio Command Prompt ou configure o ambiente.');

  LMSBuildPath := SearchInPath('msbuild.exe');
  if not LMSBuildPath.IsEmpty then
    AddItem(Result, 'MSBUILD_PATH', 'Compilador', HealthOk,
      'MSBuild detectado no PATH: ' + LMSBuildPath, '')
  else
    AddItem(Result, 'MSBUILD_PATH', 'Compilador', HealthError,
      'MSBuild.exe nao encontrado no PATH.',
      'Execute pelo RAD Studio Command Prompt ou adicione o MSBuild ao PATH.');

  if AFix and (Length(LVersions) > 0) then
  begin
    var LLastVersion := LVersions[Length(LVersions) - 1];
    var LLastPath := FRegistry.GetDelphiPath(LLastVersion);
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
            AddItem(Result, 'CONFIG_DELPHI_PATH', 'Configuracao',
              HealthOk, 'Caminho global do Delphi atualizado para: ' +
              LLastPath, '', True, True);
          end;
        finally
          LConfig.Free;
        end;
      finally
        LConfigService.Free;
      end;
    end;
  end;
end;

function TBoss4DDoctorService.Check(const AFix: Boolean): Boolean;
var
  LReport: TBoss4DDoctorReport;
begin
  LReport := Diagnose(AFix);
  try
    Result := LReport.Passed;
  finally
    LReport.Free;
  end;
end;

function TBoss4DDoctorService.SearchInPath(const AFileName: string): string;
begin
  Result := FileSearch(AFileName, GetEnvironmentVariable('PATH'));
end;

end.
