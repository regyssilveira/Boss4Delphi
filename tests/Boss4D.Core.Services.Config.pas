unit Boss4D.Core.Services.Config;

interface

uses
  Boss4D.Core.Ports;

type
  { Representa o modelo de configuracao global do Boss4D }
  TBoss4DGlobalConfig = class
  private
    FDelphiPath: string;
    FGitShallow: Boolean;
  public
    property DelphiPath: string read FDelphiPath write FDelphiPath;
    property GitShallow: Boolean read FGitShallow write FGitShallow;
  end;

  { Servico para carregar e salvar as configuracoes do boss.cfg.json }
  TBoss4DConfigService = class
  private
    FLogger: IBoss4DLogger;
  public
    constructor Create(const ALogger: IBoss4DLogger);

    function Load: TBoss4DGlobalConfig;
    procedure Save(const AConfig: TBoss4DGlobalConfig);
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env;

{ TBoss4DConfigService }

constructor TBoss4DConfigService.Create(const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

function TBoss4DConfigService.Load: TBoss4DGlobalConfig;
var
  LPath: string;
  LJSONStr: string;
  LJSONObj: TJSONObject;
begin
  Result := TBoss4DGlobalConfig.Create;
  LPath := GetGlobalConfigPath;
  
  if not TFile.Exists(LPath) then
  begin
    // Retorna configuracoes padroes
    Result.DelphiPath := '';
    Result.GitShallow := False;
    Exit;
  end;

  try
    LJSONStr := TFile.ReadAllText(LPath, TEncoding.UTF8);
    var LParsedValue := TJSONObject.ParseJSONValue(LJSONStr);
    if Assigned(LParsedValue) and (LParsedValue is TJSONObject) then
    begin
      LJSONObj := LParsedValue as TJSONObject;
      try
        Result.DelphiPath := LJSONObj.GetValue<string>('delphiPath', '');
        Result.GitShallow := LJSONObj.GetValue<Boolean>('gitShallow', False);
      finally
        LJSONObj.Free;
      end;
    end
    else
    begin
      LParsedValue.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Log(TBoss4DLogLevel.Warning, 'Erro ao ler arquivo de configuracao global: ' + E.Message);
    end;
  end;
end;

procedure TBoss4DConfigService.Save(const AConfig: TBoss4DGlobalConfig);
var
  LPath: string;
  LJSONObj: TJSONObject;
  LJSONStr: string;
begin
  LPath := GetGlobalConfigPath;
  
  // Garante que o diretorio home (~/.boss) existe antes de salvar
  var LHomeDir := TPath.GetDirectoryName(LPath);
  if not TDirectory.Exists(LHomeDir) then
    TDirectory.CreateDirectory(LHomeDir);

  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('delphiPath', AConfig.DelphiPath);
    LJSONObj.AddPair('gitShallow', AConfig.GitShallow);
    
    LJSONStr := LJSONObj.Format(2);
    TFile.WriteAllText(LPath, LJSONStr, TEncoding.UTF8);
  finally
    LJSONObj.Free;
  end;
end;

end.
