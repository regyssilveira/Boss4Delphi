unit Boss4D.GUI.Logs;

interface

uses
  System.Generics.Collections,
  System.SyncObjs,
  Boss4D.Core.Ports;

type
  TBoss4DGUILogFilter = (AllLogs, DebugLogs, InfoLogs, WarningLogs,
    ErrorLogs);

  TBoss4DGUILogEntry = record
    OccurredAt: string;
    Level: TBoss4DLogLevel;
    Source: string;
    MessageText: string;
    class function Create(const ALevel: TBoss4DLogLevel;
      const ASource, AMessage: string;
      const AOccurredAt: string = ''): TBoss4DGUILogEntry; static;
    function LevelName: string;
  end;

  TBoss4DGUILogStore = class
  private
    FLock: TCriticalSection;
    FEntries: TList<TBoss4DGUILogEntry>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AEntry: TBoss4DGUILogEntry);
    procedure Clear;
    function Query(const AFilter: TBoss4DGUILogFilter;
      const ASearch: string = ''): TArray<TBoss4DGUILogEntry>;
    function Count: Integer;
  end;

  TBoss4DGUILogs = class
  public
    class function ParseLegacy(const AMessage: string;
      const AOccurredAt: string = ''): TBoss4DGUILogEntry; static;
    class function ToJson(
      const AEntries: TArray<TBoss4DGUILogEntry>): string; static;
    class procedure SaveJson(const APath: string;
      const AEntries: TArray<TBoss4DGUILogEntry>); static;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  System.IOUtils;

function MatchesFilter(const AEntry: TBoss4DGUILogEntry;
  const AFilter: TBoss4DGUILogFilter): Boolean;
begin
  case AFilter of
    TBoss4DGUILogFilter.DebugLogs:
      Result := AEntry.Level = TBoss4DLogLevel.Debug;
    TBoss4DGUILogFilter.InfoLogs:
      Result := AEntry.Level = TBoss4DLogLevel.Info;
    TBoss4DGUILogFilter.WarningLogs:
      Result := AEntry.Level = TBoss4DLogLevel.Warning;
    TBoss4DGUILogFilter.ErrorLogs:
      Result := AEntry.Level = TBoss4DLogLevel.Error;
  else
    Result := True;
  end;
end;

function ContainsSearch(const AEntry: TBoss4DGUILogEntry;
  const ASearch: string): Boolean;
begin
  if ASearch.Trim.IsEmpty then
    Exit(True);
  Result := AEntry.Source.Contains(ASearch, True) or
    AEntry.MessageText.Contains(ASearch, True) or
    AEntry.LevelName.Contains(ASearch, True);
end;

class function TBoss4DGUILogEntry.Create(
  const ALevel: TBoss4DLogLevel;
  const ASource, AMessage, AOccurredAt: string): TBoss4DGUILogEntry;
begin
  Result.Level := ALevel;
  Result.Source := ASource.Trim;
  if Result.Source.IsEmpty then
    Result.Source := 'GUI';
  Result.MessageText := AMessage.Trim;
  if AOccurredAt.Trim.IsEmpty then
    Result.OccurredAt := DateToISO8601(Now, False)
  else
    Result.OccurredAt := AOccurredAt.Trim;
end;

function TBoss4DGUILogEntry.LevelName: string;
begin
  case Level of
    TBoss4DLogLevel.Debug:
      Result := 'DEBUG';
    TBoss4DLogLevel.Warning:
      Result := 'AVISO';
    TBoss4DLogLevel.Error:
      Result := 'ERRO';
  else
    Result := 'INFO';
  end;
end;

constructor TBoss4DGUILogStore.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FEntries := TList<TBoss4DGUILogEntry>.Create;
end;

destructor TBoss4DGUILogStore.Destroy;
begin
  FEntries.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TBoss4DGUILogStore.Add(const AEntry: TBoss4DGUILogEntry);
begin
  FLock.Acquire;
  try
    FEntries.Add(AEntry);
  finally
    FLock.Release;
  end;
end;

procedure TBoss4DGUILogStore.Clear;
begin
  FLock.Acquire;
  try
    FEntries.Clear;
  finally
    FLock.Release;
  end;
end;

function TBoss4DGUILogStore.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FEntries.Count;
  finally
    FLock.Release;
  end;
end;

function TBoss4DGUILogStore.Query(const AFilter: TBoss4DGUILogFilter;
  const ASearch: string): TArray<TBoss4DGUILogEntry>;
begin
  var LResult := TList<TBoss4DGUILogEntry>.Create;
  try
    FLock.Acquire;
    try
      for var LEntry in FEntries do
        if MatchesFilter(LEntry, AFilter) and
           ContainsSearch(LEntry, ASearch) then
          LResult.Add(LEntry);
    finally
      FLock.Release;
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

class function TBoss4DGUILogs.ParseLegacy(const AMessage,
  AOccurredAt: string): TBoss4DGUILogEntry;
begin
  var LMessage := AMessage.Trim;
  var LLevel := TBoss4DLogLevel.Info;
  var LSource := 'GUI';
  if LMessage.StartsWith('[IDE]', True) then
  begin
    LSource := 'IDE';
    Delete(LMessage, 1, Length('[IDE]'));
    LMessage := LMessage.Trim;
  end;
  if LMessage.StartsWith('[DEBUG]', True) then
  begin
    LLevel := TBoss4DLogLevel.Debug;
    Delete(LMessage, 1, Length('[DEBUG]'));
  end
  else if LMessage.StartsWith('[WARN]', True) or
          LMessage.StartsWith('[AVISO]', True) then
  begin
    LLevel := TBoss4DLogLevel.Warning;
    if LMessage.StartsWith('[WARN]', True) then
      Delete(LMessage, 1, Length('[WARN]'))
    else
      Delete(LMessage, 1, Length('[AVISO]'));
  end
  else if LMessage.StartsWith('[ERRO]', True) or
          LMessage.StartsWith('[FALHA]', True) then
  begin
    LLevel := TBoss4DLogLevel.Error;
    if LMessage.StartsWith('[ERRO]', True) then
      Delete(LMessage, 1, Length('[ERRO]'))
    else
      Delete(LMessage, 1, Length('[FALHA]'));
  end
  else if LMessage.StartsWith('[INFO]', True) then
    Delete(LMessage, 1, Length('[INFO]'));
  Result := TBoss4DGUILogEntry.Create(
    LLevel, LSource, LMessage, AOccurredAt);
end;

class function TBoss4DGUILogs.ToJson(
  const AEntries: TArray<TBoss4DGUILogEntry>): string;
begin
  var LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    var LItems := TJSONArray.Create;
    for var LEntry in AEntries do
    begin
      var LItem := TJSONObject.Create;
      LItem.AddPair('occurredAt', LEntry.OccurredAt);
      LItem.AddPair('level', LEntry.LevelName.ToLower);
      LItem.AddPair('source', LEntry.Source);
      LItem.AddPair('message', LEntry.MessageText);
      LItems.AddElement(LItem);
    end;
    LRoot.AddPair('entries', LItems);
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

class procedure TBoss4DGUILogs.SaveJson(const APath: string;
  const AEntries: TArray<TBoss4DGUILogEntry>);
begin
  if APath.Trim.IsEmpty then
    raise EArgumentException.Create('O caminho de exportacao e obrigatorio.');
  TFile.WriteAllText(TPath.GetFullPath(APath), ToJson(AEntries),
    TEncoding.UTF8);
end;

end.
