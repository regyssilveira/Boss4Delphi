unit Boss4D.Core.Services.Clean;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico para limpar dependencias (modules e boss-lock.json) do projeto }
  TBoss4DCleanService = class
  private
    FLogger: IBoss4DLogger;
  public
    constructor Create(const ALogger: IBoss4DLogger);
    procedure Execute;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Domain.Consts, Winapi.Windows;

{ TBoss4DCleanService }

constructor TBoss4DCleanService.Create(const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

procedure TBoss4DCleanService.Execute;
var
  LModulesDir: string;
  LLockFile: string;
  LFiles: TArray<string>;
begin
  FLogger.Log(TBoss4DLogLevel.Info, '🧹 Iniciando limpeza do projeto...');

  LModulesDir := TPath.Combine(TDirectory.GetCurrentDirectory, FOLDER_DEPENDENCIES);
  LLockFile := TPath.Combine(TDirectory.GetCurrentDirectory, FILE_PACKAGE_LOCK);

  // 1. Remove a pasta modules
  if TDirectory.Exists(LModulesDir) then
  begin
    FLogger.Log(TBoss4DLogLevel.Info, '  Removendo pasta ' + FOLDER_DEPENDENCIES + '...');
    try
      // Limpa atributos de somente leitura recursively para evitar erros de permissão de arquivos do .git
      LFiles := TDirectory.GetFiles(LModulesDir, '*', TSearchOption.soAllDirectories);
      for var LFile in LFiles do
      begin
        SetFileAttributes(PChar(LFile), FILE_ATTRIBUTE_NORMAL);
      end;
      
      TDirectory.Delete(LModulesDir, True);
      FLogger.Log(TBoss4DLogLevel.Info, '  [OK] Pasta ' + FOLDER_DEPENDENCIES + ' removida.');
    except
      on E: Exception do
        FLogger.Log(TBoss4DLogLevel.Error, '  [ERRO] Falha ao remover a pasta ' + FOLDER_DEPENDENCIES + ': ' + E.Message);
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Info, '  Pasta ' + FOLDER_DEPENDENCIES + ' nao existe.');
  end;

  // 2. Remove o boss-lock.json
  if TFile.Exists(LLockFile) then
  begin
    FLogger.Log(TBoss4DLogLevel.Info, '  Removendo arquivo ' + FILE_PACKAGE_LOCK + '...');
    try
      SetFileAttributes(PChar(LLockFile), FILE_ATTRIBUTE_NORMAL);
      TFile.Delete(LLockFile);
      FLogger.Log(TBoss4DLogLevel.Info, '  [OK] Arquivo ' + FILE_PACKAGE_LOCK + ' removido.');
    except
      on E: Exception do
        FLogger.Log(TBoss4DLogLevel.Error, '  [ERRO] Falha ao remover ' + FILE_PACKAGE_LOCK + ': ' + E.Message);
    end;
  end
  else
  begin
    FLogger.Log(TBoss4DLogLevel.Info, '  Arquivo ' + FILE_PACKAGE_LOCK + ' nao existe.');
  end;

  FLogger.Log(TBoss4DLogLevel.Info, '✨ Limpeza concluida com sucesso!');
end;

end.
