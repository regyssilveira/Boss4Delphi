unit Boss4D.GUI.Operation.Presenter;

interface

type
  TBoss4DGUIOperationState = (GUIIdle, GUIRunning, GUISucceeded, GUIFailed,
    GUICancelled);

  TBoss4DGUIOperationPresenter = class
  private
    FState: TBoss4DGUIOperationState;
    FAttempt: Integer;
    FStartedAt: UInt64;
    FFinishedAt: UInt64;
    FErrorMessage: string;
  public
    constructor Create;
    procedure Start(const ATick: UInt64);
    procedure Complete(const ATick: UInt64);
    procedure Fail(const AMessage: string; const ATick: UInt64);
    procedure Cancel(const ATick: UInt64);
    function CanCancel: Boolean;
    function CanRetry: Boolean;
    function ElapsedMilliseconds(const ATick: UInt64): UInt64;
    function ElapsedText(const ATick: UInt64): string;
    property State: TBoss4DGUIOperationState read FState;
    property Attempt: Integer read FAttempt;
    property ErrorMessage: string read FErrorMessage;
  end;

implementation

uses
  System.SysUtils;

constructor TBoss4DGUIOperationPresenter.Create;
begin
  inherited Create;
  FState := GUIIdle;
end;

procedure TBoss4DGUIOperationPresenter.Start(const ATick: UInt64);
begin
  if FState = GUIRunning then
    raise EInvalidOpException.Create('Ja existe uma operacao em andamento.');
  Inc(FAttempt);
  FStartedAt := ATick;
  FFinishedAt := 0;
  FErrorMessage := '';
  FState := GUIRunning;
end;

procedure TBoss4DGUIOperationPresenter.Complete(const ATick: UInt64);
begin
  if FState <> GUIRunning then
    raise EInvalidOpException.Create('A operacao nao esta em andamento.');
  FFinishedAt := ATick;
  FState := GUISucceeded;
end;

procedure TBoss4DGUIOperationPresenter.Fail(const AMessage: string;
  const ATick: UInt64);
begin
  if FState <> GUIRunning then
    raise EInvalidOpException.Create('A operacao nao esta em andamento.');
  FFinishedAt := ATick;
  FErrorMessage := AMessage;
  FState := GUIFailed;
end;

procedure TBoss4DGUIOperationPresenter.Cancel(const ATick: UInt64);
begin
  if FState <> GUIRunning then
    raise EInvalidOpException.Create('A operacao nao esta em andamento.');
  FFinishedAt := ATick;
  FState := GUICancelled;
end;

function TBoss4DGUIOperationPresenter.CanCancel: Boolean;
begin
  Result := FState = GUIRunning;
end;

function TBoss4DGUIOperationPresenter.CanRetry: Boolean;
begin
  Result := FState in [GUIFailed, GUICancelled];
end;

function TBoss4DGUIOperationPresenter.ElapsedMilliseconds(
  const ATick: UInt64): UInt64;
var
  LEnd: UInt64;
begin
  if FState = GUIIdle then
    Exit(0);
  if FState = GUIRunning then
    LEnd := ATick
  else
    LEnd := FFinishedAt;
  if LEnd < FStartedAt then
    Exit(0);
  Result := LEnd - FStartedAt;
end;

function TBoss4DGUIOperationPresenter.ElapsedText(
  const ATick: UInt64): string;
var
  LSeconds: UInt64;
begin
  LSeconds := ElapsedMilliseconds(ATick) div 1000;
  Result := Format('%d:%2.2d', [LSeconds div 60, LSeconds mod 60]);
end;

end.
