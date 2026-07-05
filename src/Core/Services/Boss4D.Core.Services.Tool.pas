unit Boss4D.Core.Services.Tool;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico para clonar, compilar e distribuir utilitarios CLI globais em Delphi }
  TBoss4DToolService = class
  private
    FGitClient: IBoss4DGitClient;
    FCompiler: IBoss4DCompiler;
    FLogger: IBoss4DLogger;
  public
    constructor Create(const AGitClient: IBoss4DGitClient; const ACompiler: IBoss4DCompiler; const ALogger: IBoss4DLogger);
    procedure InstallGlobalTool(const ARepository: string);
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Env;

{ TBoss4DToolService }

constructor TBoss4DToolService.Create(const AGitClient: IBoss4DGitClient; const ACompiler: IBoss4DCompiler; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FGitClient := AGitClient;
  FCompiler := ACompiler;
  FLogger := ALogger;
end;

procedure TBoss4DToolService.InstallGlobalTool(const ARepository: string);
var
  LDep: TBoss4DDependency;
  LTempCloneDir: string;
  LBinGlobalDir: string;
  LFiles: TArray<string>;
  LEXEFiles: TArray<string>;
  LLock: TBoss4DLock;
  LToolName: string;
  LDestEXE: string;
  LHomeDir: string;
begin
  FLogger.Log(TBoss4DLogLevel.Info, 'Iniciando instalacao global da ferramenta: %s', [ARepository]);

  LDep := TBoss4DDependency.Create(ARepository, '*');
  LLock := TBoss4DLock.Create;
  LHomeDir := GetBossHome;
  LTempCloneDir := TPath.Combine(TPath.Combine(LHomeDir, 'temp_tools'), LDep.Name);
  LBinGlobalDir := TPath.Combine(LHomeDir, 'bin');
  try
    // 1. Limpa clone temporario anterior se houver
    if TDirectory.Exists(LTempCloneDir) then
      TDirectory.Delete(LTempCloneDir, True);

    TDirectory.CreateDirectory(LTempCloneDir);

    // 2. Clona o repositorio da ferramenta
    FLogger.Log(TBoss4DLogLevel.Info, '  Clonando fontes...');
    FGitClient.CloneCache(LDep, LTempCloneDir);

    // 3. Busca arquivos .dproj
    LFiles := TDirectory.GetFiles(LTempCloneDir, '*.dproj', TSearchOption.soAllDirectories);
    if Length(LFiles) = 0 then
      raise Exception.Create('Nenhum projeto Delphi (.dproj) encontrado no repositorio da ferramenta.');

    // 4. Compila a ferramenta Delphi
    FLogger.Log(TBoss4DLogLevel.Info, '  Compilando executavel...');
    if not FCompiler.Compile(LFiles[0], LDep, LLock) then
      raise Exception.Create('Falha na compilacao da ferramenta.');

    // 5. Busca o executavel (.exe) recem gerado no build
    LEXEFiles := TDirectory.GetFiles(LTempCloneDir, '*.exe', TSearchOption.soAllDirectories);
    if Length(LEXEFiles) = 0 then
      raise Exception.Create('Executavel compilado nao foi localizado na pasta de build.');

    // 6. Garante a existencia do diretorio global de executaveis (~/.boss/bin)
    if not TDirectory.Exists(LBinGlobalDir) then
      TDirectory.CreateDirectory(LBinGlobalDir);

    LToolName := TPath.GetFileNameWithoutExtension(LFiles[0]);
    LDestEXE := TPath.Combine(LBinGlobalDir, LToolName + '.exe');

    TFile.Copy(LEXEFiles[0], LDestEXE, True);

    FLogger.Log(TBoss4DLogLevel.Info, '🚀 Ferramenta "%s" instalada com sucesso em: %s', [LToolName, LDestEXE]);
    FLogger.Log(TBoss4DLogLevel.Info, 'Dica: Certifique-se de adicionar a pasta "%s" ao PATH do sistema.', [LBinGlobalDir]);
  finally
    // Limpeza de temporarios
    if TDirectory.Exists(LTempCloneDir) then
      TDirectory.Delete(LTempCloneDir, True);
    LLock.Free;
    LDep.Free;
  end;
end;

end.
