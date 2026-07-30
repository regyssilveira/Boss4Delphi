unit Boss4D.Posix.Audit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DAuditFetcher = function(const ARevision,
    APageToken: string): string of object;

  TBoss4DAuditOptions = record
    Offline: Boolean;
    CacheHours: Integer;
    FailOn: string;
    VexPath: string;
    CacheDirectory: string;
  end;

  TBoss4DAuditSummary = record
    Packages: Integer;
    Vulnerabilities: Integer;
    Suppressed: Integer;
    PolicyViolations: Integer;
  end;

  TBoss4DAuditService = class
  private
    FFetcher: TBoss4DAuditFetcher;
    FFindings: TStringList;
    function FetchAll(const ARevision: string): string;
    function ReadResponse(const ARevision: string;
      const AOptions: TBoss4DAuditOptions): string;
  public
    constructor Create(const AFetcher: TBoss4DAuditFetcher = nil);
    destructor Destroy; override;
    function Execute(const ALockPath: string;
      const AOptions: TBoss4DAuditOptions): TBoss4DAuditSummary;
    property Findings: TStringList read FFindings;
  end;

function DefaultAuditOptions: TBoss4DAuditOptions;

implementation

uses
  fpjson, jsonparser, fphttpclient, opensslsockets, DateUtils,
  Boss4D.Posix.Core, Boss4D.Posix.Operations;

function DefaultAuditOptions: TBoss4DAuditOptions;
var
  LHome: string;
begin
  Result.Offline := False;
  Result.CacheHours := 24;
  Result.FailOn := 'high';
  Result.VexPath := '';
  LHome := GetEnvironmentVariable('BOSS_HOME');
  if LHome = '' then
    LHome := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
      '.boss';
  Result.CacheDirectory := IncludeTrailingPathDelimiter(LHome) + 'audit-cache';
end;

function SafeName(const AValue: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValue) do
    if AValue[I] in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_'] then
      Result := Result + AValue[I];
  if Result = '' then Result := 'unknown';
end;

function NativeFetch(const ARevision, APageToken: string): string;
var
  LClient: TFPHTTPClient;
  LRequest: TStringStream;
  LBody: string;
begin
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.AllowRedirect := True;
    LClient.AddHeader('Content-Type', 'application/json');
    LBody := '{"commit":"' + ARevision + '"';
    if APageToken <> '' then
      LBody := LBody + ',"page_token":"' + APageToken + '"';
    LBody := LBody + '}';
    LRequest := TStringStream.Create(LBody, TEncoding.UTF8);
    try
      LClient.RequestBody := LRequest;
      Result := LClient.Post('https://api.osv.dev/v1/query');
    finally
      LClient.RequestBody := nil;
      LRequest.Free;
    end;
  finally
    LClient.Free;
  end;
end;

function TBoss4DAuditService.FetchAll(const ARevision: string): string;
var
  LPageData: TJSONData;
  LPageRoot, LAggregateRoot: TJSONObject;
  LPageItems, LAggregateItems: TJSONArray;
  LPageToken, LResponse: string;
  I: Integer;
begin
  LAggregateRoot := TJSONObject.Create;
  try
    LAggregateItems := TJSONArray.Create;
    LAggregateRoot.Add('vulns', LAggregateItems);
    LPageToken := '';
    repeat
      CheckCancelled;
      if Assigned(FFetcher) then
        LResponse := FFetcher(ARevision, LPageToken)
      else
        LResponse := NativeFetch(ARevision, LPageToken);
      LPageData := GetJSON(LResponse);
      try
        if not (LPageData is TJSONObject) then
          raise Exception.Create('OSV response root must be an object');
        LPageRoot := TJSONObject(LPageData);
        if LPageRoot.Find('vulns') is TJSONArray then
        begin
          LPageItems := TJSONArray(LPageRoot.Find('vulns'));
          for I := 0 to LPageItems.Count - 1 do
            LAggregateItems.Add(LPageItems.Items[I].Clone);
        end;
        LPageToken := LPageRoot.Get('next_page_token', '');
      finally
        LPageData.Free;
      end;
    until LPageToken = '';
    Result := LAggregateRoot.AsJSON;
  finally
    LAggregateRoot.Free;
  end;
end;

function LoadText(const APath: string): string;
var
  LContent: TStringList;
begin
  LContent := TStringList.Create;
  try
    LContent.LoadFromFile(APath);
    Result := LContent.Text;
  finally
    LContent.Free;
  end;
end;

procedure SaveText(const APath, AContent: string);
var
  LContent: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  LContent := TStringList.Create;
  try
    LContent.Text := AContent;
    LContent.SaveToFile(APath);
  finally
    LContent.Free;
  end;
end;

function CacheFresh(const APath: string; const AHours: Integer): Boolean;
var
  LAge: LongInt;
  LDate: TDateTime;
begin
  Result := False;
  if not FileExists(APath) then Exit;
  if AHours <= 0 then Exit(True);
  LAge := FileAge(APath);
  if LAge = -1 then Exit;
  LDate := FileDateToDateTime(LAge);
  Result := HoursBetween(Now, LDate) <= AHours;
end;

constructor TBoss4DAuditService.Create(const AFetcher: TBoss4DAuditFetcher);
begin
  inherited Create;
  FFetcher := AFetcher;
  FFindings := TStringList.Create;
end;

destructor TBoss4DAuditService.Destroy;
begin
  FFindings.Free;
  inherited Destroy;
end;

function TBoss4DAuditService.ReadResponse(const ARevision: string;
  const AOptions: TBoss4DAuditOptions): string;
var
  LCachePath: string;
begin
  LCachePath := IncludeTrailingPathDelimiter(AOptions.CacheDirectory) +
    SafeName(ARevision) + '.json';
  if AOptions.Offline then
  begin
    if not CacheFresh(LCachePath, AOptions.CacheHours) then
      raise Exception.Create('offline audit cache miss: ' + ARevision);
    Exit(LoadText(LCachePath));
  end;
  try
    Result := FetchAll(ARevision);
    SaveText(LCachePath, Result);
  except
    if CacheFresh(LCachePath, AOptions.CacheHours) then
      Result := LoadText(LCachePath)
    else
      raise;
  end;
end;

function SeverityRank(const ASeverity: string): Integer;
begin
  if SameText(ASeverity, 'low') then Exit(1);
  if SameText(ASeverity, 'medium') or SameText(ASeverity, 'moderate') then
    Exit(2);
  if SameText(ASeverity, 'high') then Exit(3);
  if SameText(ASeverity, 'critical') then Exit(4);
  Result := 0;
end;

function VulnerabilitySeverity(const AVulnerability: TJSONObject): string;
var
  LDatabase, LEcosystem: TJSONObject;
begin
  Result := 'unknown';
  if AVulnerability.Find('database_specific') is TJSONObject then
  begin
    LDatabase := TJSONObject(AVulnerability.Find('database_specific'));
    Result := LowerCase(LDatabase.Get('severity', Result));
  end;
  if (Result = 'unknown') and
     (AVulnerability.Find('ecosystem_specific') is TJSONObject) then
  begin
    LEcosystem := TJSONObject(AVulnerability.Find('ecosystem_specific'));
    Result := LowerCase(LEcosystem.Get('severity', Result));
  end;
end;

function LoadSuppressions(const AVexPath: string): TStringList;
var
  LData: TJSONData;
  LRoot, LItem: TJSONObject;
  LItems: TJSONArray;
  LStream: TFileStream;
  I: Integer;
  LState: string;
begin
  Result := TStringList.Create;
  Result.CaseSensitive := False;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
  if AVexPath = '' then Exit;
  LStream := TFileStream.Create(AVexPath, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  try
    if not (LData is TJSONObject) then
      raise Exception.Create('VEX root must be an object');
    LRoot := TJSONObject(LData);
    if not (LRoot.Find('vulnerabilities') is TJSONArray) then
      raise Exception.Create('VEX vulnerabilities array is required');
    LItems := TJSONArray(LRoot.Find('vulnerabilities'));
    for I := 0 to LItems.Count - 1 do
      if LItems.Items[I] is TJSONObject then
      begin
        LItem := TJSONObject(LItems.Items[I]);
        LState := LowerCase(LItem.Get('state', ''));
        if (LState = 'not_affected') or (LState = 'fixed') or
           (LState = 'resolved') then
          Result.Add(LowerCase(LItem.Get('id', '')));
      end;
  finally
    LData.Free;
  end;
end;

function TBoss4DAuditService.Execute(const ALockPath: string;
  const AOptions: TBoss4DAuditOptions): TBoss4DAuditSummary;
var
  LLock, LEntry, LResponseRoot, LVulnerability: TJSONObject;
  LInstalled: TJSONObject;
  LData: TJSONData;
  LVulnerabilities: TJSONArray;
  LSuppressions: TStringList;
  I, J, LThreshold: Integer;
  LRevision, LId, LSeverity, LRepository, LResponse: string;
begin
  Result.Packages := 0;
  Result.Vulnerabilities := 0;
  Result.Suppressed := 0;
  Result.PolicyViolations := 0;
  FFindings.Clear;
  LThreshold := SeverityRank(AOptions.FailOn);
  if (AOptions.FailOn <> '') and (LThreshold = 0) then
    raise Exception.Create('invalid audit severity: ' + AOptions.FailOn);
  LSuppressions := LoadSuppressions(AOptions.VexPath);
  LLock := LoadJsonObject(ALockPath);
  try
    if not (LLock.Find('installedModules') is TJSONObject) then
      raise Exception.Create('lock installedModules object is required');
    LInstalled := TJSONObject(LLock.Find('installedModules'));
    for I := 0 to LInstalled.Count - 1 do
    begin
      CheckCancelled;
      if not (LInstalled.Items[I] is TJSONObject) then Continue;
      LEntry := TJSONObject(LInstalled.Items[I]);
      LRevision := LEntry.Get('revision', '');
      if LRevision = '' then Continue;
      Inc(Result.Packages);
      LRepository := LEntry.Get('repository', LInstalled.Names[I]);
      LResponse := ReadResponse(LRevision, AOptions);
      LData := GetJSON(LResponse);
      try
        if not (LData is TJSONObject) then
          raise Exception.Create('OSV response root must be an object');
        LResponseRoot := TJSONObject(LData);
        if not (LResponseRoot.Find('vulns') is TJSONArray) then Continue;
        LVulnerabilities := TJSONArray(LResponseRoot.Find('vulns'));
        for J := 0 to LVulnerabilities.Count - 1 do
          if LVulnerabilities.Items[J] is TJSONObject then
          begin
            LVulnerability := TJSONObject(LVulnerabilities.Items[J]);
            LId := LVulnerability.Get('id', 'unknown');
            LSeverity := VulnerabilitySeverity(LVulnerability);
            Inc(Result.Vulnerabilities);
            if LSuppressions.IndexOf(LowerCase(LId)) >= 0 then
            begin
              Inc(Result.Suppressed);
              FFindings.Add('SUPPRESSED ' + LId + ' ' + LRepository);
            end
            else
            begin
              FFindings.Add(UpperCase(LSeverity) + ' ' + LId + ' ' +
                LRepository);
              if (LThreshold > 0) and
                 (SeverityRank(LSeverity) >= LThreshold) then
                Inc(Result.PolicyViolations);
            end;
          end;
      finally
        LData.Free;
      end;
    end;
  finally
    LLock.Free;
    LSuppressions.Free;
  end;
end;

end.
