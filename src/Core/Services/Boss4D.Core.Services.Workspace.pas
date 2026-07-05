unit Boss4D.Core.Services.Workspace;

interface

uses
  System.Generics.Collections, Boss4D.Core.Ports, Boss4D.Core.Domain.Package;

type
  { Serviço para gerenciar workspaces e linkagem de monorepos no Boss4D }
  TBoss4DWorkspaceService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLogger: IBoss4DLogger;
    function ResolveGlob(const ARootPath, AGlob: string): TArray<string>;
    procedure CreateDirectoryJunction(const ASourceDir, ADestJunction: string);
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
    
    // Varre os diretórios e retorna a lista de caminhos absolutos dos subprojetos
    function FindSubprojects(const ARootPkg: TBoss4DPackage; const ARootPath: string): TList<string>;
    
    // Cria links de junção virtuais da pasta modules nos subprojetos
    procedure LinkWorkspaceSubprojects(const ARootPath: string; const ASubprojectPaths: TList<string>);
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env;

{ TBoss4DWorkspaceService }

constructor TBoss4DWorkspaceService.Create(const APackageRepo: IBoss4DPackageRepository; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLogger := ALogger;
end;

function TBoss4DWorkspaceService.ResolveGlob(const ARootPath, AGlob: string): TArray<string>;
var
  LGlobClean: string;
  LFolderToSearch: string;
  LDirs: TArray<string>;
  LResult: TList<string>;
begin
  LResult := TList<string>.Create;
  try
    LGlobClean := AGlob.Replace('/', '\').Trim;
    if LGlobClean.EndsWith('*') then
    begin
      // Ex: projects\* -> Varre todos os subdiretórios de projects/
      LFolderToSearch := TPath.Combine(ARootPath, LGlobClean.Substring(0, LGlobClean.Length - 1));
      if TDirectory.Exists(LFolderToSearch) then
      begin
        LDirs := TDirectory.GetDirectories(LFolderToSearch);
        LResult.AddRange(LDirs);
      end;
    end
    else
    begin
      // Ex: projects/app1 -> Caminho relativo direto
      LFolderToSearch := TPath.Combine(ARootPath, LGlobClean);
      if TDirectory.Exists(LFolderToSearch) then
        LResult.Add(LFolderToSearch);
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

function TBoss4DWorkspaceService.FindSubprojects(const ARootPkg: TBoss4DPackage; const ARootPath: string): TList<string>;
var
  LPaths: TList<string>;
  LGlob: string;
  LResolvedDirs: TArray<string>;
  LDir: string;
  LSubPkgPath: string;
begin
  LPaths := TList<string>.Create;
  
  if not Assigned(ARootPkg) or (ARootPkg.Workspaces.Count = 0) then
    Exit(LPaths);

  for LGlob in ARootPkg.Workspaces do
  begin
    LResolvedDirs := ResolveGlob(ARootPath, LGlob);
    for LDir in LResolvedDirs do
    begin
      LSubPkgPath := TPath.Combine(LDir, FILE_PACKAGE);
      if FPackageRepo.Exists(LSubPkgPath) then
      begin
        LPaths.Add(LDir);
      end;
    end;
  end;

  Result := LPaths;
end;

procedure TBoss4DWorkspaceService.CreateDirectoryJunction(const ASourceDir, ADestJunction: string);
var
  LOutput: string;
begin
  // Remove link ou pasta anterior se houver
  if TDirectory.Exists(ADestJunction) then
  begin
    FLogger.Log(TBoss4DLogLevel.Debug, '  Limpando pasta/link de modules existente em: ' + ADestJunction);
    try
      // Se for uma Junction, removemos usando rmdir no Windows
      ExecuteCommandLine('cmd.exe /c rmdir "' + ADestJunction + '"', TPath.GetDirectoryName(ADestJunction), LOutput);
    except
      // Se falhar (ex: e uma pasta física comum), deleta de forma recursiva normal
      TDirectory.Delete(ADestJunction, True);
    end;
    
    // Fallback de seguranca caso o rmdir nao tenha completado
    if TDirectory.Exists(ADestJunction) then
      TDirectory.Delete(ADestJunction, True);
  end;

  FLogger.Log(TBoss4DLogLevel.Debug, '  Criando junção de diretório: %s -> %s', [ADestJunction, ASourceDir]);
  
  // No Windows, criamos junção via mklink /J (não exige privilégios de Admin)
  if not ExecuteCommandLine('cmd.exe /c mklink /J "' + ADestJunction + '" "' + ASourceDir + '"', TPath.GetDirectoryName(ADestJunction), LOutput) then
  begin
    FLogger.Log(TBoss4DLogLevel.Warning, '  Falha ao criar Directory Junction via cmd. Fazendo copia de seguranca.');
    // Fallback: se mklink falhar por algum motivo de OS, cria o diretorio fisico
    TDirectory.CreateDirectory(ADestJunction);
  end;
end;

procedure TBoss4DWorkspaceService.LinkWorkspaceSubprojects(const ARootPath: string; const ASubprojectPaths: TList<string>);
var
  LModulesRoot: string;
  LSubPath: string;
  LSubModulesDir: string;
begin
  LModulesRoot := TPath.Combine(ARootPath, FOLDER_DEPENDENCIES);
  
  if not TDirectory.Exists(LModulesRoot) then
    TDirectory.CreateDirectory(LModulesRoot);

  for LSubPath in ASubprojectPaths do
  begin
    LSubModulesDir := TPath.Combine(LSubPath, FOLDER_DEPENDENCIES);
    FLogger.Log(TBoss4DLogLevel.Info, 'Vinculando monorepo para subprojeto: %s', [TPath.GetFileName(LSubPath)]);
    CreateDirectoryJunction(LModulesRoot, LSubModulesDir);
  end;
end;

end.
