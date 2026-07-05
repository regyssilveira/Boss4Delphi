unit Boss4D.Core.Services.Init;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico de caso de uso para inicializar o boss.json (boss init) }
  TBoss4DInitService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLogger: IBoss4DLogger;
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);

    procedure Execute(const AQuiet: Boolean); overload;
    procedure Execute(const AQuiet: Boolean; const AName, ADescription, AVersion, AHomepage: string); overload;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Env;

{ TBoss4DInitService }

constructor TBoss4DInitService.Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLogger := ALogger;
end;

procedure TBoss4DInitService.Execute(const AQuiet: Boolean);
begin
  Execute(AQuiet, '', '', '1.0.0', '');
end;

procedure TBoss4DInitService.Execute(const AQuiet: Boolean; const AName, ADescription, AVersion, AHomepage: string);
var
  LPkg: TBoss4DPackage;
  LFilePath: string;
begin
  LFilePath := GetBossFile;
  if FPackageRepo.Exists(LFilePath) then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, 'Arquivo boss.json ja existe neste diretorio.');
    Exit;
  end;

  LPkg := TBoss4DPackage.Create;
  try
    if AQuiet then
    begin
      // Modo silencioso: usa o nome da pasta atual como nome do projeto
      LPkg.Name := TPath.GetFileName(GetCurrentDir).ToLower;
      LPkg.Version := '1.0.0';
      LPkg.Description := '';
      LPkg.Homepage := '';
    end
    else
    begin
      // Modo interativo/parametrizado: usa os dados fornecidos pelo chamador
      if AName.IsEmpty then
        LPkg.Name := TPath.GetFileName(GetCurrentDir).ToLower
      else
        LPkg.Name := AName.ToLower;

      LPkg.Description := ADescription;
      LPkg.Version := AVersion;
      LPkg.Homepage := AHomepage;
    end;

    FPackageRepo.Save(LPkg, LFilePath);
    FLogger.Log(TBoss4DLogLevel.Info, 'Pronto. boss.json inicializado com sucesso em %s', [LFilePath]);
  finally
    LPkg.Free;
  end;
end;

end.
