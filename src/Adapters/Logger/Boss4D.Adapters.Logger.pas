unit Boss4D.Adapters.Logger;

interface

uses
  System.SyncObjs, Boss4D.Core.Ports;

type
  { Adaptador de log colorido e thread-safe para console e arquivo }
  TBoss4DConsoleLoggerAdapter = class(TInterfacedObject, IBoss4DLogger)
  private
    FDebugMode: Boolean;
    FLock: TCriticalSection;
    FLogFilePath: string;

    procedure WriteToConsole(const ALevel: TBoss4DLogLevel; const AMessage: string);
    procedure WriteToFile(const ALevel: TBoss4DLogLevel; const AMessage: string);
    procedure SetConsoleColor(const ALevel: TBoss4DLogLevel);
    procedure ResetConsoleColor;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string); overload;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const); overload;
    procedure SetDebugMode(const AEnabled: Boolean);
  end;

implementation

uses
  System.SysUtils, System.IOUtils
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF};

{ TBoss4DConsoleLoggerAdapter }

constructor TBoss4DConsoleLoggerAdapter.Create;
begin
  inherited Create;
  FDebugMode := False;
  FLock := TCriticalSection.Create;
  FLogFilePath := TPath.Combine(TDirectory.GetCurrentDirectory, 'boss4d.log');
end;

destructor TBoss4DConsoleLoggerAdapter.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TBoss4DConsoleLoggerAdapter.Log(const ALevel: TBoss4DLogLevel; const AMessage: string);
begin
  if (ALevel = TBoss4DLogLevel.Debug) and not FDebugMode then
    Exit;

  FLock.Enter;
  try
    WriteToConsole(ALevel, AMessage);
    if FDebugMode then
      WriteToFile(ALevel, AMessage);
  finally
    FLock.Leave;
  end;
end;

procedure TBoss4DConsoleLoggerAdapter.Log(const ALevel: TBoss4DLogLevel; const AMessage: string;
  const AArgs: array of const);
begin
  Log(ALevel, Format(AMessage, AArgs));
end;

procedure TBoss4DConsoleLoggerAdapter.SetDebugMode(const AEnabled: Boolean);
begin
  FLock.Enter;
  try
    FDebugMode := AEnabled;
  finally
    FLock.Leave;
  end;
end;

procedure TBoss4DConsoleLoggerAdapter.SetConsoleColor(const ALevel: TBoss4DLogLevel);
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
  LColorAttr: Word;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  case ALevel of
    TBoss4DLogLevel.Debug:
      LColorAttr := FOREGROUND_BLUE or FOREGROUND_GREEN; // Ciano escuro
    TBoss4DLogLevel.Info:
      LColorAttr := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE; // Branco padrao
    TBoss4DLogLevel.Warning:
      LColorAttr := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_INTENSITY; // Amarelo
    TBoss4DLogLevel.Error:
      LColorAttr := FOREGROUND_RED or FOREGROUND_INTENSITY; // Vermelho brilhante
  else
    LColorAttr := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE;
  end;
  SetConsoleTextAttribute(LHandle, LColorAttr);
end;
{$ELSE}
begin
  // No-op ou sequencias ANSI para Linux
  case ALevel of
    TBoss4DLogLevel.Debug: Write( #27'[36m' );
    TBoss4DLogLevel.Info: Write( #27'[0m' );
    TBoss4DLogLevel.Warning: Write( #27'[33m' );
    TBoss4DLogLevel.Error: Write( #27'[31m' );
  end;
end;
{$ENDIF}

procedure TBoss4DConsoleLoggerAdapter.ResetConsoleColor;
{$IFDEF MSWINDOWS}
var
  LHandle: THandle;
begin
  LHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  SetConsoleTextAttribute(LHandle, FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE);
end;
{$ELSE}
begin
  Write( #27'[0m' );
end;
{$ENDIF}

procedure TBoss4DConsoleLoggerAdapter.WriteToConsole(const ALevel: TBoss4DLogLevel; const AMessage: string);
var
  LPrefix: string;
begin
  case ALevel of
    TBoss4DLogLevel.Debug:   LPrefix := '[DEBUG] ';
    TBoss4DLogLevel.Info:    LPrefix := ''; // Info nao precisa de prefixo para manter o visual limpo do CLI original
    TBoss4DLogLevel.Warning: LPrefix := '⚠️  [WARN] ';
    TBoss4DLogLevel.Error:   LPrefix := '❌ [ERROR] ';
  end;

  SetConsoleColor(ALevel);
  try
    Writeln(LPrefix + AMessage);
  finally
    ResetConsoleColor;
  end;
end;

procedure TBoss4DConsoleLoggerAdapter.WriteToFile(const ALevel: TBoss4DLogLevel; const AMessage: string);
var
  LPrefix: string;
  LTimestamp: string;
begin
  case ALevel of
    TBoss4DLogLevel.Debug:   LPrefix := 'DEBUG';
    TBoss4DLogLevel.Info:    LPrefix := 'INFO';
    TBoss4DLogLevel.Warning: LPrefix := 'WARN';
    TBoss4DLogLevel.Error:   LPrefix := 'ERROR';
  end;

  LTimestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
  var LFormattedMsg := Format('%s [%s] %s', [LTimestamp, LPrefix, AMessage]);

  try
    TFile.AppendAllText(FLogFilePath, LFormattedMsg + sLineBreak, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      // Falha de escrita do arquivo de log e direcionada para a saida de erro padrao (ErrOutput) do Windows
      System.WriteLn(ErrOutput, 'Erro ao gravar arquivo de log: ' + E.Message);
    end;
  end;
end;

end.
