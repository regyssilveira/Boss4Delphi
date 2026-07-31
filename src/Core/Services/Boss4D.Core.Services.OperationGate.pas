unit Boss4D.Core.Services.OperationGate;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.SyncObjs;

type
  TBoss4DKeyedOperationGate = class
  private
    FGuard: TObject;
    FSlots: TSemaphore;
    FActiveKeys: TDictionary<string, Boolean>;
    function NormalizeKey(const AKey: string): string;
  public
    constructor Create(const AMaximumConcurrency: Integer);
    destructor Destroy; override;
    procedure Enter(const AKey: string);
    procedure Leave(const AKey: string);
  end;

implementation

uses
  System.Classes;

constructor TBoss4DKeyedOperationGate.Create(
  const AMaximumConcurrency: Integer);
begin
  inherited Create;
  if AMaximumConcurrency < 1 then
    raise EArgumentOutOfRangeException.Create(
      'AMaximumConcurrency deve ser maior que zero.');
  FGuard := TObject.Create;
  FActiveKeys := TDictionary<string, Boolean>.Create;
  FSlots := TSemaphore.Create(nil, AMaximumConcurrency,
    AMaximumConcurrency, '');
end;

destructor TBoss4DKeyedOperationGate.Destroy;
begin
  FSlots.Free;
  FActiveKeys.Free;
  FGuard.Free;
  inherited Destroy;
end;

function TBoss4DKeyedOperationGate.NormalizeKey(const AKey: string): string;
begin
  Result := AKey.Trim.ToLower;
  if Result.IsEmpty then
    raise EArgumentException.Create('A chave da operacao nao pode ser vazia.');
end;

procedure TBoss4DKeyedOperationGate.Enter(const AKey: string);
var
  LKey: string;
begin
  LKey := NormalizeKey(AKey);
  TMonitor.Enter(FGuard);
  try
    while FActiveKeys.ContainsKey(LKey) do
      TMonitor.Wait(FGuard, INFINITE);
    FActiveKeys.Add(LKey, True);
  finally
    TMonitor.Exit(FGuard);
  end;
  if FSlots.WaitFor(INFINITE) <> wrSignaled then
  begin
    TMonitor.Enter(FGuard);
    try
      FActiveKeys.Remove(LKey);
      TMonitor.PulseAll(FGuard);
    finally
      TMonitor.Exit(FGuard);
    end;
    raise EInvalidOpException.Create(
      'Nao foi possivel adquirir uma vaga de operacao.');
  end;
end;

procedure TBoss4DKeyedOperationGate.Leave(const AKey: string);
var
  LKey: string;
begin
  LKey := NormalizeKey(AKey);
  TMonitor.Enter(FGuard);
  try
    if not FActiveKeys.ContainsKey(LKey) then
      raise EInvalidOpException.Create(
        'A operacao informada nao pertence a este gate.');
    FActiveKeys.Remove(LKey);
    TMonitor.PulseAll(FGuard);
  finally
    TMonitor.Exit(FGuard);
  end;
  FSlots.Release;
end;

end.
