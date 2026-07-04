unit Boss4D.CLI.Parser;

interface

uses
  System.SysUtils, Boss4D.Core.Ports, Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Install, Boss4D.Core.Services.Config;

type
  { Interpretador e orquestrador de comandos da linha de comando (CLI) }
  TBoss4DCommandLineParser = class
  private
    FLogger: IBoss4DLogger;
    FInitService: TBoss4DInitService;
    FInstallService: TBoss4DInstallService;
    FConfigService: TBoss4DConfigService;

    procedure ShowHelp;
    procedure ShowVersion;
    procedure HandleInit(const AArgs: TArray<string>);
    procedure HandleInstall(const AArgs: TArray<string>);
    procedure HandleConfig(const AArgs: TArray<string>);
  public
    constructor Create(
      const ALogger: IBoss4DLogger;
      const AInitService: TBoss4DInitService;
      const AInstallService: TBoss4DInstallService;
      const AConfigService: TBoss4DConfigService
    );

    procedure ParseAndExecute(const AArgs: TArray<string>);
  end;

implementation

{ TBoss4DCommandLineParser }

constructor TBoss4DCommandLineParser.Create(
  const ALogger: IBoss4DLogger;
  const AInitService: TBoss4DInitService;
  const AInstallService: TBoss4DInstallService;
  const AConfigService: TBoss4DConfigService
);
begin
  inherited Create;
  FLogger := ALogger;
  FInitService := AInitService;
  FInstallService := AInstallService;
  FConfigService := AConfigService;
end;

procedure TBoss4DCommandLineParser.ShowHelp;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'Boss4D - Gerenciador de Dependencias Delphi Nativo (v1.0.0)');
  FLogger.Log(TBoss4DLogLevel.Info, '');
  FLogger.Log(TBoss4DLogLevel.Info, 'Uso:');
  FLogger.Log(TBoss4DLogLevel.Info, '  boss4d [comando] [argumentos] [flags]');
  FLogger.Log(TBoss4DLogLevel.Info, '');
  FLogger.Log(TBoss4DLogLevel.Info, 'Comandos Disponiveis:');
  FLogger.Log(TBoss4DLogLevel.Info, '  init                 Inicializa um novo arquivo boss.json no diretorio atual.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Flags: -q, --quiet (modo silencioso).');
  FLogger.Log(TBoss4DLogLevel.Info, '  install              Instala todas as dependencias declaradas no boss.json.');
  FLogger.Log(TBoss4DLogLevel.Info, '  install <dep>        Instala uma dependencia especifica.');
  FLogger.Log(TBoss4DLogLevel.Info, '                       Exemplo: boss4d install github.com/hashload/horse@^3.0.0');
  FLogger.Log(TBoss4DLogLevel.Info, '  config delphi use <caminho>  Configura o caminho global do compilador Delphi.');
  FLogger.Log(TBoss4DLogLevel.Info, '  config git shallow <true/false> Configura uso de shallow clones globais.');
  FLogger.Log(TBoss4DLogLevel.Info, '  version, -v, --version Exibe a versao atual do Boss4D.');
  FLogger.Log(TBoss4DLogLevel.Info, '  help, -h, --help     Exibe este menu de ajuda.');
  FLogger.Log(TBoss4DLogLevel.Info, '');
end;

procedure TBoss4DCommandLineParser.ShowVersion;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'v1.0.0-delphi-native');
end;

procedure TBoss4DCommandLineParser.ParseAndExecute(const AArgs: TArray<string>);
begin
  if Length(AArgs) = 0 then
  begin
    ShowHelp;
    Exit;
  end;

  var LCommand := AArgs[0].ToLower;

  if (LCommand = 'help') or (LCommand = '-h') or (LCommand = '--help') then
    ShowHelp
  else if (LCommand = 'version') or (LCommand = '-v') or (LCommand = '--version') then
    ShowVersion
  else if LCommand = 'init' then
    HandleInit(AArgs)
  else if (LCommand = 'install') or (LCommand = 'i') then
    HandleInstall(AArgs)
  else if LCommand = 'config' then
    HandleConfig(AArgs);
end;

procedure TBoss4DCommandLineParser.HandleInit(const AArgs: TArray<string>);
var
  LQuiet: Boolean;
begin
  LQuiet := False;
  for var I := 1 to Length(AArgs) - 1 do
  begin
    if (AArgs[I] = '-q') or (AArgs[I] = '--quiet') then
      LQuiet := True;
  end;
  FInitService.Execute(LQuiet);
end;

procedure TBoss4DCommandLineParser.HandleInstall(const AArgs: TArray<string>);
var
  LDepToInstall: string;
begin
  LDepToInstall := '';
  if Length(AArgs) > 1 then
    LDepToInstall := AArgs[1];
  
  FInstallService.Execute(LDepToInstall);
end;

procedure TBoss4DCommandLineParser.HandleConfig(const AArgs: TArray<string>);
begin
  if (Length(AArgs) >= 4) and SameText(AArgs[1], 'delphi') and SameText(AArgs[2], 'use') then
  begin
    var LConfig := FConfigService.Load;
    try
      LConfig.DelphiPath := AArgs[3];
      FConfigService.Save(LConfig);
      FLogger.Log(TBoss4DLogLevel.Info, '✅ Caminho do Delphi atualizado para: %s', [LConfig.DelphiPath]);
    finally
      LConfig.Free;
    end;
  end
  else if (Length(AArgs) >= 4) and SameText(AArgs[1], 'git') and SameText(AArgs[2], 'shallow') then
  begin
    var LConfig := FConfigService.Load;
    try
      LConfig.GitShallow := SameText(AArgs[3], 'true') or (AArgs[3] = '1');
      FConfigService.Save(LConfig);
      FLogger.Log(TBoss4DLogLevel.Info, 
        '✅ Configuracao git shallow definida para: %s', [BoolToStr(LConfig.GitShallow, True)]);
    finally
      LConfig.Free;
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Uso invalido do comando config.');
    FLogger.Log(TBoss4DLogLevel.Info, 'Comandos aceitos:');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d config delphi use <caminho>');
    FLogger.Log(TBoss4DLogLevel.Info, '  boss4d config git shallow <true/false>');
  end;
end;

end.
