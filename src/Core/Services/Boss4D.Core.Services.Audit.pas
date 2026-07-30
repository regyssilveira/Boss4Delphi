unit Boss4D.Core.Services.Audit;

interface

uses
  System.SysUtils, Boss4D.Core.Ports;

type
  TBoss4DAuditSeverity = (AuditUnknown, AuditLow, AuditMedium, AuditHigh,
    AuditCritical);

  TBoss4DAuditOptions = record
    Offline: Boolean;
    CacheHours: Integer;
    FailOn: TBoss4DAuditSeverity;
    VexPath: string;
  end;

  TBoss4DAuditSummary = record
    Vulnerabilities: Integer;
    Suppressed: Integer;
    PolicyViolations: Integer;
  end;

  EBoss4DAuditPolicy = class(Exception);

  TBoss4DAuditService = class
  private
    FLockRepo: IBoss4DLockRepository;
    FHttp: IBoss4DHttpClient;
    FLogger: IBoss4DLogger;
    function CachePath(const ARevision: string): string;
    function LoadOrQuery(const ARevision: string;
      const AOptions: TBoss4DAuditOptions): string;
  public
    constructor Create(const ALockRepo: IBoss4DLockRepository;
      const AHttp: IBoss4DHttpClient; const ALogger: IBoss4DLogger);
    function Execute(const ALockPath: string;
      const AOptions: TBoss4DAuditOptions): TBoss4DAuditSummary;
    class function ParseSeverity(const AValue: string): TBoss4DAuditSeverity;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.Hash, System.DateUtils,
  System.Generics.Collections, Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Lock;

const
  OSV_QUERY_URL = 'https://api.osv.dev/v1/query';

constructor TBoss4DAuditService.Create(
  const ALockRepo: IBoss4DLockRepository; const AHttp: IBoss4DHttpClient;
  const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FLockRepo := ALockRepo;
  FHttp := AHttp;
  FLogger := ALogger;
end;

class function TBoss4DAuditService.ParseSeverity(
  const AValue: string): TBoss4DAuditSeverity;
begin
  if SameText(AValue, 'low') then Exit(AuditLow);
  if SameText(AValue, 'medium') or SameText(AValue, 'moderate') then
    Exit(AuditMedium);
  if SameText(AValue, 'high') then Exit(AuditHigh);
  if SameText(AValue, 'critical') then Exit(AuditCritical);
  Result := AuditUnknown;
end;

function TBoss4DAuditService.CachePath(const ARevision: string): string;
begin
  Result := TPath.Combine(TPath.Combine(GetBossHome, 'audit-cache'),
    THashSHA2.GetHashString(ARevision).ToLower + '.json');
end;

function TBoss4DAuditService.LoadOrQuery(const ARevision: string;
  const AOptions: TBoss4DAuditOptions): string;
var
  LPath: string;
  LHours: Integer;
  LStatus: Integer;
begin
  LPath := CachePath(ARevision);
  LHours := AOptions.CacheHours;
  if LHours <= 0 then LHours := 24;
  if TFile.Exists(LPath) and
     (HoursBetween(Now, TFile.GetLastWriteTime(LPath)) <= LHours) then
    Exit(TFile.ReadAllText(LPath, TEncoding.UTF8));
  if AOptions.Offline then
    raise Exception.Create(
      'Cache OSV ausente ou expirado para a revisao ' + ARevision);
  LStatus := FHttp.PostJson(OSV_QUERY_URL,
    '{"commit":"' + ARevision + '"}', Result);
  if (LStatus < 200) or (LStatus >= 300) then
    raise Exception.CreateFmt('OSV respondeu HTTP %d: %s',
      [LStatus, Result]);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(LPath));
  var LEncoding := TUTF8Encoding.Create(False);
  try
    TFile.WriteAllText(LPath, Result, LEncoding);
  finally
    LEncoding.Free;
  end;
end;

function TBoss4DAuditService.Execute(const ALockPath: string;
  const AOptions: TBoss4DAuditOptions): TBoss4DAuditSummary;
var
  LLock: TBoss4DLock;
  LVexStates: TDictionary<string, string>;
begin
  Result := Default(TBoss4DAuditSummary);
  LVexStates := TDictionary<string, string>.Create;
  LLock := FLockRepo.Load(ALockPath);
  try
    if not AOptions.VexPath.IsEmpty then
    begin
      var LVexValue := TJSONObject.ParseJSONValue(
        TFile.ReadAllText(TPath.GetFullPath(AOptions.VexPath),
          TEncoding.UTF8));
      try
        if not (LVexValue is TJSONObject) then
          raise Exception.Create('VEX deve ser um objeto JSON.');
        var LVexEntries := TJSONObject(LVexValue).GetValue<TJSONArray>(
          'vulnerabilities');
        if Assigned(LVexEntries) then
          for var I := 0 to LVexEntries.Count - 1 do
            if LVexEntries[I] is TJSONObject then
            begin
              var LVexEntry := TJSONObject(LVexEntries[I]);
              var LId := LVexEntry.GetValue<string>('id', '');
              var LState := LVexEntry.GetValue<string>('state', '').ToLower;
              if not LId.IsEmpty then
                LVexStates.AddOrSetValue(LId.ToLower, LState);
            end;
      finally
        LVexValue.Free;
      end;
    end;

    for var LLocked in LLock.Installed.Values do
    begin
      if LLocked.Revision.IsEmpty then
        Continue;
      var LValue := TJSONObject.ParseJSONValue(
        LoadOrQuery(LLocked.Revision, AOptions));
      try
        if not (LValue is TJSONObject) then
          raise Exception.Create('Resposta OSV invalida.');
        var LVulns := TJSONObject(LValue).GetValue<TJSONArray>('vulns');
        if not Assigned(LVulns) then Continue;
        for var I := 0 to LVulns.Count - 1 do
        begin
          if not (LVulns[I] is TJSONObject) then Continue;
          var LVuln := TJSONObject(LVulns[I]);
          var LId := LVuln.GetValue<string>('id', 'UNKNOWN');
          Inc(Result.Vulnerabilities);
          var LState: string;
          if LVexStates.TryGetValue(LId.ToLower, LState) and
             ((LState = 'not_affected') or (LState = 'fixed') or
              (LState = 'resolved')) then
          begin
            Inc(Result.Suppressed);
            FLogger.Log(TBoss4DLogLevel.Info,
              'VEX suprimiu %s em %s (%s)', [LId, LLocked.Name, LState]);
            Continue;
          end;
          var LSeverityText := '';
          var LDatabase := LVuln.GetValue<TJSONObject>('database_specific');
          if Assigned(LDatabase) then
            LSeverityText := LDatabase.GetValue<string>('severity', '');
          var LSeverity := ParseSeverity(LSeverityText);
          FLogger.Log(TBoss4DLogLevel.Warning, '%s em %s [%s]',
            [LId, LLocked.Name, LSeverityText]);
          if (AOptions.FailOn <> AuditUnknown) and
             (LSeverity >= AOptions.FailOn) then
            Inc(Result.PolicyViolations);
        end;
      finally
        LValue.Free;
      end;
    end;
  finally
    LLock.Free;
    LVexStates.Free;
  end;
  if Result.PolicyViolations > 0 then
    raise EBoss4DAuditPolicy.CreateFmt(
      'Auditoria falhou: %d vulnerabilidade(s) violam a politica.',
      [Result.PolicyViolations]);
end;

end.
