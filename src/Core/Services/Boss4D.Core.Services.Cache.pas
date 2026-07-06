unit Boss4D.Core.Services.Cache;

interface

uses
  Boss4D.Core.Ports;

type
  { Servico de caso de uso para gerenciamento de cache global do Boss4D }
  TBoss4DCacheService = class
  private
    FLogger: IBoss4DLogger;
    function GetDirectorySize(const APath: string): Int64;
  public
    constructor Create(const ALogger: IBoss4DLogger);
    function GetCacheSize: Int64;
    function GetFormattedSize: string;
    procedure Clean;
    function Prune(const ADaysThreshold: Integer = 30): Integer;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.DateUtils, Boss4D.Core.Domain.Env;

{ TBoss4DCacheService }

constructor TBoss4DCacheService.Create(const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FLogger := ALogger;
end;

function TBoss4DCacheService.GetDirectorySize(const APath: string): Int64;
var
  LFiles: TArray<string>;
  LSize: Int64;
begin
  LSize := 0;
  if not TDirectory.Exists(APath) then
    Exit(0);

  try
    LFiles := TDirectory.GetFiles(APath, '*', TSearchOption.soAllDirectories);
    for var LFile in LFiles do
    begin
      try
        LSize := LSize + TFile.GetSize(LFile);
      except
        on E: Exception do
          FLogger.Log(TBoss4DLogLevel.Warning, 'Erro ao ler tamanho de arquivo no cache: ' + E.Message);
      end;
    end;
  except
    on E: Exception do
      FLogger.Log(TBoss4DLogLevel.Warning, 'Erro ao listar arquivos do cache: ' + E.Message);
  end;
  Result := LSize;
end;

function TBoss4DCacheService.GetCacheSize: Int64;
begin
  Result := GetDirectorySize(GetCacheDir);
end;

function TBoss4DCacheService.GetFormattedSize: string;
var
  LBytes: Int64;
  LKB, LMB, LGB: Double;
begin
  LBytes := GetCacheSize;
  if LBytes < 1024 then
    Exit(Format('%d Bytes', [LBytes]));

  LKB := LBytes / 1024;
  if LKB < 1024 then
    Exit(Format('%.2f KB', [LKB]));

  LMB := LKB / 1024;
  if LMB < 1024 then
    Exit(Format('%.2f MB', [LMB]));

  LGB := LMB / 1024;
  Result := Format('%.2f GB', [LGB]);
end;

procedure TBoss4DCacheService.Clean;
var
  LCacheDir: string;
begin
  LCacheDir := GetCacheDir;
  FLogger.Log(TBoss4DLogLevel.Info, 'Limpando todo o cache global em %s...', [LCacheDir]);

  if TDirectory.Exists(LCacheDir) then
  begin
    try
      TDirectory.Delete(LCacheDir, True);
    except
      on E: Exception do
      begin
        FLogger.Log(TBoss4DLogLevel.Error, 'Erro ao apagar cache: ' + E.Message);
        Exit;
      end;
    end;
  end;

  TDirectory.CreateDirectory(LCacheDir);
  FLogger.Log(TBoss4DLogLevel.Info, 'Cache global limpo com sucesso!');
end;

function TBoss4DCacheService.Prune(const ADaysThreshold: Integer): Integer;
var
  LCacheDir: string;
  LSubDirs: TArray<string>;
  LDeletedCount: Integer;
begin
  LDeletedCount := 0;
  LCacheDir := GetCacheDir;
  FLogger.Log(TBoss4DLogLevel.Info, 'Iniciando limpeza de caches obsoletos (mais de %d dias)...', [ADaysThreshold]);

  if not TDirectory.Exists(LCacheDir) then
  begin
    FLogger.Log(TBoss4DLogLevel.Info, 'Diretorio de cache nao existe. Nada a fazer.');
    Exit(0);
  end;

  try
    LSubDirs := TDirectory.GetDirectories(LCacheDir);
    for var LSubDir in LSubDirs do
    begin
      try
        var LLastWrite := TDirectory.GetLastWriteTime(LSubDir);
        if DaysBetween(Now, LLastWrite) > ADaysThreshold then
        begin
          FLogger.Log(TBoss4DLogLevel.Debug, 'Removendo cache obsoleto: ' + TPath.GetFileName(LSubDir));
          TDirectory.Delete(LSubDir, True);
          Inc(LDeletedCount);
        end;
      except
        on E: Exception do
          FLogger.Log(TBoss4DLogLevel.Warning, 'Erro ao remover diretorio de cache obsoleto: ' + E.Message);
      end;
    end;
  except
    on E: Exception do
      FLogger.Log(TBoss4DLogLevel.Error, 'Erro ao listar diretorios de cache: ' + E.Message);
  end;

  FLogger.Log(TBoss4DLogLevel.Info, 'Limpeza concluida. %d caches obsoletos foram removidos.', [LDeletedCount]);
  Result := LDeletedCount;
end;

end.
