unit Boss4D.Core.Services.IDEOperationResult;

interface

uses
  System.Generics.Collections;

type
  TBoss4DIDEOperationStatus = (Planned, Running, Succeeded, Failed,
    Deferred);

  TBoss4DIDEOperationResult = class
  private
    FOperationId: string;
    FKind: string;
    FProfile: string;
    FTarget: string;
    FStatus: TBoss4DIDEOperationStatus;
    FStartedAt: string;
    FCompletedAt: string;
    FErrorMessage: string;
    FRecoveryInstruction: string;
    FUndoSnapshot: string;
    FCompletedActions: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    class function New(const AKind, AProfile,
      ATarget: string): TBoss4DIDEOperationResult; static;
    procedure Complete;
    procedure Fail(const AErrorMessage,
      ARecoveryInstruction: string);
    property OperationId: string read FOperationId write FOperationId;
    property Kind: string read FKind write FKind;
    property Profile: string read FProfile write FProfile;
    property Target: string read FTarget write FTarget;
    property Status: TBoss4DIDEOperationStatus read FStatus write FStatus;
    property StartedAt: string read FStartedAt write FStartedAt;
    property CompletedAt: string read FCompletedAt write FCompletedAt;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property RecoveryInstruction: string read FRecoveryInstruction
      write FRecoveryInstruction;
    property UndoSnapshot: string read FUndoSnapshot write FUndoSnapshot;
    property CompletedActions: TList<string> read FCompletedActions;
  end;

  IBoss4DIDEOperationResultStore = interface
    ['{2FBEDE13-4615-451A-B5BF-D10EED3A138D}']
    procedure Save(const AResult: TBoss4DIDEOperationResult);
    function LoadLatest: TBoss4DIDEOperationResult;
    function History: TObjectList<TBoss4DIDEOperationResult>;
  end;

  TBoss4DJsonIDEOperationResultStore = class(TInterfacedObject,
    IBoss4DIDEOperationResultStore)
  private
    FDirectory: string;
    function LoadFromPath(const APath: string): TBoss4DIDEOperationResult;
  public
    constructor Create(const ADirectory: string);
    procedure Save(const AResult: TBoss4DIDEOperationResult);
    function LoadLatest: TBoss4DIDEOperationResult;
    function History: TObjectList<TBoss4DIDEOperationResult>;
  end;

  TBoss4DIDEOperationStatuses = class
  public
    class function NameOf(const AStatus: TBoss4DIDEOperationStatus):
      string; static;
    class function Parse(const AStatus: string):
      TBoss4DIDEOperationStatus; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  System.DateUtils;

class function TBoss4DIDEOperationStatuses.NameOf(
  const AStatus: TBoss4DIDEOperationStatus): string;
begin
  case AStatus of
    TBoss4DIDEOperationStatus.Running:
      Result := 'running';
    TBoss4DIDEOperationStatus.Succeeded:
      Result := 'succeeded';
    TBoss4DIDEOperationStatus.Failed:
      Result := 'failed';
    TBoss4DIDEOperationStatus.Deferred:
      Result := 'deferred';
  else
    Result := 'planned';
  end;
end;

function TBoss4DJsonIDEOperationResultStore.History:
  TObjectList<TBoss4DIDEOperationResult>;
begin
  Result := TObjectList<TBoss4DIDEOperationResult>.Create(True);
  if not TDirectory.Exists(FDirectory) then
    Exit;
  var LFiles := TDirectory.GetFiles(FDirectory, '*.json');
  TArray.Sort<string>(LFiles);
  try
    for var LFile in LFiles do
      if not SameText(TPath.GetFileName(LFile), 'latest.json') then
        Result.Add(LoadFromPath(LFile));
  except
    Result.Free;
    raise;
  end;
end;

class function TBoss4DIDEOperationStatuses.Parse(
  const AStatus: string): TBoss4DIDEOperationStatus;
begin
  if SameText(AStatus, 'running') then
    Exit(TBoss4DIDEOperationStatus.Running);
  if SameText(AStatus, 'succeeded') then
    Exit(TBoss4DIDEOperationStatus.Succeeded);
  if SameText(AStatus, 'failed') then
    Exit(TBoss4DIDEOperationStatus.Failed);
  if SameText(AStatus, 'deferred') then
    Exit(TBoss4DIDEOperationStatus.Deferred);
  if SameText(AStatus, 'planned') then
    Exit(TBoss4DIDEOperationStatus.Planned);
  raise EArgumentException.CreateFmt(
    'Status de operacao IDE invalido: %s.', [AStatus]);
end;

constructor TBoss4DIDEOperationResult.Create;
begin
  inherited Create;
  FStatus := TBoss4DIDEOperationStatus.Planned;
  FCompletedActions := TList<string>.Create;
end;

destructor TBoss4DIDEOperationResult.Destroy;
begin
  FCompletedActions.Free;
  inherited Destroy;
end;

class function TBoss4DIDEOperationResult.New(
  const AKind, AProfile, ATarget: string): TBoss4DIDEOperationResult;
begin
  if AKind.Trim.IsEmpty or AProfile.Trim.IsEmpty or ATarget.Trim.IsEmpty then
    raise EArgumentException.Create(
      'Kind, profile e target sao obrigatorios para a operacao IDE.');
  Result := TBoss4DIDEOperationResult.Create;
  Result.OperationId := TGUID.NewGuid.ToString;
  Result.Kind := AKind.Trim;
  Result.Profile := AProfile.Trim;
  Result.Target := ATarget.Trim;
  Result.Status := TBoss4DIDEOperationStatus.Running;
  Result.StartedAt := DateToISO8601(Now, False);
end;

procedure TBoss4DIDEOperationResult.Complete;
begin
  FStatus := TBoss4DIDEOperationStatus.Succeeded;
  FCompletedAt := DateToISO8601(Now, False);
  FErrorMessage := '';
  FRecoveryInstruction := '';
end;

procedure TBoss4DIDEOperationResult.Fail(const AErrorMessage,
  ARecoveryInstruction: string);
begin
  FStatus := TBoss4DIDEOperationStatus.Failed;
  FCompletedAt := DateToISO8601(Now, False);
  FErrorMessage := AErrorMessage;
  FRecoveryInstruction := ARecoveryInstruction;
end;

constructor TBoss4DJsonIDEOperationResultStore.Create(
  const ADirectory: string);
begin
  inherited Create;
  if ADirectory.Trim.IsEmpty then
    raise EArgumentException.Create(
      'O diretorio de resultados IDE e obrigatorio.');
  FDirectory := TPath.GetFullPath(ADirectory);
end;

procedure TBoss4DJsonIDEOperationResultStore.Save(
  const AResult: TBoss4DIDEOperationResult);
var
  LObject: TJSONObject;
  LActions: TJSONArray;
  LEncoding: TEncoding;
  LPath: string;
  LTempPath: string;
  LBackupPath: string;
begin
  if not Assigned(AResult) then
    raise EArgumentNilException.Create('AResult');
  TDirectory.CreateDirectory(FDirectory);
  LObject := TJSONObject.Create;
  try
    LObject.AddPair('schemaVersion', TJSONNumber.Create(1));
    LObject.AddPair('operationId', AResult.OperationId);
    LObject.AddPair('kind', AResult.Kind);
    LObject.AddPair('profile', AResult.Profile);
    LObject.AddPair('target', AResult.Target);
    LObject.AddPair('status',
      TBoss4DIDEOperationStatuses.NameOf(AResult.Status));
    LObject.AddPair('startedAt', AResult.StartedAt);
    LObject.AddPair('completedAt', AResult.CompletedAt);
    LObject.AddPair('error', AResult.ErrorMessage);
    LObject.AddPair('recovery', AResult.RecoveryInstruction);
    LObject.AddPair('undoSnapshot', AResult.UndoSnapshot);
    LActions := TJSONArray.Create;
    for var LAction in AResult.CompletedActions do
      LActions.Add(LAction);
    LObject.AddPair('completedActions', LActions);
    LPath := TPath.Combine(FDirectory, 'latest.json');
    LTempPath := LPath + '.tmp';
    LEncoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(LTempPath, LObject.Format(2), LEncoding);
    finally
      LEncoding.Free;
    end;
    if TFile.Exists(LPath) then
    begin
      LBackupPath := LPath + '.bak';
      if TFile.Exists(LBackupPath) then
        TFile.Delete(LBackupPath);
      TFile.Replace(LTempPath, LPath, LBackupPath);
      if TFile.Exists(LBackupPath) then
        TFile.Delete(LBackupPath);
    end
    else
      TFile.Move(LTempPath, LPath);
    TFile.Copy(LPath, TPath.Combine(FDirectory,
      AResult.OperationId + '.json'), True);
  finally
    LObject.Free;
  end;
end;

function TBoss4DJsonIDEOperationResultStore.LoadLatest:
  TBoss4DIDEOperationResult;
begin
  Result := LoadFromPath(TPath.Combine(FDirectory, 'latest.json'));
end;

function TBoss4DJsonIDEOperationResultStore.LoadFromPath(
  const APath: string): TBoss4DIDEOperationResult;
var
  LObject: TJSONObject;
  LActions: TJSONArray;
begin
  if not TFile.Exists(APath) then
    raise EFileNotFoundException.Create(
      'Nenhum resultado de operacao IDE foi persistido.');
  LObject := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APath, TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LObject) then
    raise EConvertError.Create(
      'Resultado de operacao IDE invalido.');
  try
    if LObject.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EConvertError.Create(
        'Schema de resultado de operacao IDE nao suportado.');
    Result := TBoss4DIDEOperationResult.Create;
    try
      Result.OperationId := LObject.GetValue<string>('operationId', '');
      Result.Kind := LObject.GetValue<string>('kind', '');
      Result.Profile := LObject.GetValue<string>('profile', '');
      Result.Target := LObject.GetValue<string>('target', '');
      Result.Status := TBoss4DIDEOperationStatuses.Parse(
        LObject.GetValue<string>('status', ''));
      Result.StartedAt := LObject.GetValue<string>('startedAt', '');
      Result.CompletedAt := LObject.GetValue<string>('completedAt', '');
      Result.ErrorMessage := LObject.GetValue<string>('error', '');
      Result.RecoveryInstruction := LObject.GetValue<string>(
        'recovery', '');
      Result.UndoSnapshot := LObject.GetValue<string>(
        'undoSnapshot', '');
      LActions := LObject.GetValue<TJSONArray>('completedActions');
      if Assigned(LActions) then
        for var I := 0 to LActions.Count - 1 do
          Result.CompletedActions.Add(LActions[I].Value);
    except
      Result.Free;
      raise;
    end;
  finally
    LObject.Free;
  end;
end;

end.
