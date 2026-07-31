unit Boss4D.Tests.OperationGate;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsOperationGate = class
  public
    [Test]
    procedure TestLimitsGlobalConcurrency;
    [Test]
    procedure TestSerializesSameKey;
    [Test]
    procedure TestRejectsInvalidLimit;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  Boss4D.Core.Services.OperationGate;

procedure UpdateMaximum(const ACurrent: Integer; var AMaximum: Integer);
var
  LObserved: Integer;
begin
  repeat
    LObserved := AMaximum;
    if ACurrent <= LObserved then
      Exit;
  until TInterlocked.CompareExchange(AMaximum, ACurrent, LObserved) =
    LObserved;
end;

procedure TTestsOperationGate.TestLimitsGlobalConcurrency;
var
  LGate: TBoss4DKeyedOperationGate;
  LTasks: TArray<ITask>;
  LActive: Integer;
  LMaximum: Integer;
  function CreateGateTask(const AKey: string): ITask;
  begin
    Result := TTask.Run(
      procedure
      var
        LCurrent: Integer;
      begin
        LGate.Enter(AKey);
        try
          LCurrent := TInterlocked.Increment(LActive);
          UpdateMaximum(LCurrent, LMaximum);
          TThread.Sleep(100);
          TInterlocked.Decrement(LActive);
        finally
          LGate.Leave(AKey);
        end;
      end);
  end;
begin
  LActive := 0;
  LMaximum := 0;
  LGate := TBoss4DKeyedOperationGate.Create(2);
  try
    SetLength(LTasks, 6);
    for var I := 0 to High(LTasks) do
      LTasks[I] := CreateGateTask('package-' + I.ToString);
    TTask.WaitForAll(LTasks);
    Assert.IsTrue(LMaximum > 1,
      'Chaves independentes devem executar concorrentemente.');
    Assert.IsTrue(LMaximum <= 2,
      'O limite global de concorrencia deve ser respeitado.');
  finally
    LGate.Free;
  end;
end;

procedure TTestsOperationGate.TestRejectsInvalidLimit;
begin
  Assert.WillRaise(
    procedure
    begin
      TBoss4DKeyedOperationGate.Create(0).Free;
    end,
    EArgumentOutOfRangeException);
end;

procedure TTestsOperationGate.TestSerializesSameKey;
var
  LGate: TBoss4DKeyedOperationGate;
  LTasks: TArray<ITask>;
  LActive: Integer;
  LMaximum: Integer;
begin
  LActive := 0;
  LMaximum := 0;
  LGate := TBoss4DKeyedOperationGate.Create(4);
  try
    SetLength(LTasks, 4);
    for var I := 0 to High(LTasks) do
      LTasks[I] := TTask.Run(
        procedure
        var
          LCurrent: Integer;
        begin
          LGate.Enter('shared-cache');
          try
            LCurrent := TInterlocked.Increment(LActive);
            UpdateMaximum(LCurrent, LMaximum);
            TThread.Sleep(20);
            TInterlocked.Decrement(LActive);
          finally
            LGate.Leave('shared-cache');
          end;
        end);
    TTask.WaitForAll(LTasks);
    Assert.AreEqual(1, LMaximum);
  finally
    LGate.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsOperationGate);

end.
