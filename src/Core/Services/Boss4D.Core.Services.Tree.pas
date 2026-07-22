unit Boss4D.Core.Services.Tree;

interface

uses
  Boss4D.Core.Ports, System.Generics.Collections;

type
  { Servico para geracao de relatorios graficos em arvore das dependencias transitivas }
  TBoss4DTreeService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLogger: IBoss4DLogger;
    procedure PrintTreeRecursive(const APackagePath: string; const APrefix: string; const AIsLast: Boolean; const AProcessed: TList<string>);
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
    procedure GenerateTree;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Consts;

{ TBoss4DTreeService }

constructor TBoss4DTreeService.Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLogger := ALogger;
end;

procedure TBoss4DTreeService.PrintTreeRecursive(const APackagePath: string; const APrefix: string; const AIsLast: Boolean; const AProcessed: TList<string>);
var
  LPkg: TBoss4DPackage;
  LDeps: TArray<TBoss4DDependency>;
  LConnector: string;
  LNewPrefix: string;
  LKey: string;
  LSubPath: string;
  I: Integer;
  LDep: TBoss4DDependency;
begin
  if not FPackageRepo.Exists(APackagePath) then
    Exit;

  LPkg := FPackageRepo.Load(APackagePath);
  try
    LConnector := '├── ';
    if AIsLast then
      LConnector := '└── ';

    LKey := LPkg.Name.ToLower + '@' + LPkg.Version;
    if AProcessed.Contains(LKey) then
    begin
      FLogger.Log(TBoss4DLogLevel.Info, APrefix + LConnector + LPkg.Name + ' (' + LPkg.Version + ') [Circular]');
      Exit;
    end;
    AProcessed.Add(LKey);

    FLogger.Log(TBoss4DLogLevel.Info, APrefix + LConnector + LPkg.Name + ' (' + LPkg.Version + ')');

    LDeps := LPkg.GetParsedDependencies;
    try
      LNewPrefix := APrefix;
      if AIsLast then
        LNewPrefix := LNewPrefix + '    '
      else
        LNewPrefix := LNewPrefix + '│   ';

      for I := 0 to Length(LDeps) - 1 do
      begin
        LSubPath := TPath.Combine(TPath.Combine(GetModulesDir,
          LDeps[I].StorageName), FILE_PACKAGE);
        PrintTreeRecursive(LSubPath, LNewPrefix, I = Length(LDeps) - 1, AProcessed);
      end;
    finally
      for LDep in LDeps do
        LDep.Free;
    end;
  finally
    LPkg.Free;
  end;
end;

procedure TBoss4DTreeService.GenerateTree;
var
  LPkgPath: string;
  LPkg: TBoss4DPackage;
  LDeps: TArray<TBoss4DDependency>;
  LProcessed: TList<string>;
  I: Integer;
  LDep: TBoss4DDependency;
  LSubPath: string;
begin
  LPkgPath := GetBossFile;
  if not FPackageRepo.Exists(LPkgPath) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Arquivo boss.json nao encontrado neste diretorio.');
    Exit;
  end;

  LPkg := FPackageRepo.Load(LPkgPath);
  try
    FLogger.Log(TBoss4DLogLevel.Info, LPkg.Name + ' (' + LPkg.Version + ')');
    LDeps := LPkg.GetParsedDependencies;
    LProcessed := TList<string>.Create;
    try
      for I := 0 to Length(LDeps) - 1 do
      begin
        LSubPath := TPath.Combine(TPath.Combine(GetModulesDir,
          LDeps[I].StorageName), FILE_PACKAGE);
        PrintTreeRecursive(LSubPath, '', I = Length(LDeps) - 1, LProcessed);
      end;
    finally
      LProcessed.Free;
      for LDep in LDeps do
        LDep.Free;
    end;
  finally
    LPkg.Free;
  end;
end;

end.
