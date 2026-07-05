unit Boss4D.Core.Services.Run;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico de caso de uso para execucao de scripts customizados definidos no boss.json }
  TBoss4DRunService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLogger: IBoss4DLogger;
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
    function Execute(const AScriptName: string): Boolean;
  end;

implementation

uses
  System.SysUtils, Boss4D.Core.Domain.Env, Boss4D.Core.Domain.Package;

{ TBoss4DRunService }

constructor TBoss4DRunService.Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLogger := ALogger;
end;

function TBoss4DRunService.Execute(const AScriptName: string): Boolean;
var
  LPkg: TBoss4DPackage;
  LScriptCmd: string;
  LOutput: string;
begin
  Result := False;
  if not FPackageRepo.Exists(GetBossFile) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Arquivo boss.json nao encontrado no diretorio atual.');
    Exit;
  end;

  LPkg := FPackageRepo.Load(GetBossFile);
  try
    if not LPkg.Scripts.TryGetValue(AScriptName, LScriptCmd) then
    begin
      FLogger.Log(TBoss4DLogLevel.Error, 'Script "%s" nao esta definido no boss.json.', [AScriptName]);
      Exit;
    end;

    FLogger.Log(TBoss4DLogLevel.Info, '> %s', [LScriptCmd]);
    
    // Executa a linha de comando no shell
    Result := ExecuteCommandLine(LScriptCmd, GetCurrentDir, LOutput);
    
    if not LOutput.IsEmpty then
      Writeln(LOutput);
      
    if not Result then
      FLogger.Log(TBoss4DLogLevel.Error, 'Script falhou com erro de execucao.');
  finally
    LPkg.Free;
  end;
end;

end.
