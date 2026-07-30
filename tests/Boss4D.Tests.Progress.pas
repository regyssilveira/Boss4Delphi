unit Boss4D.Tests.Progress;

interface

uses
  DUnitX.TestFramework, System.Generics.Collections,
  Boss4D.Core.Domain.Progress;

type
  TProgressOutputMock = class(TInterfacedObject, IBoss4DProgressOutput)
  private
    FLines: TList<string>;
    FWrites: TList<string>;
    FInteractive: Boolean;
  public
    constructor Create(const AInteractive: Boolean = False);
    destructor Destroy; override;
    procedure Write(const AText: string);
    procedure WriteLine(const AText: string);
    function IsInteractive: Boolean;
    property Lines: TList<string> read FLines;
    property Writes: TList<string> read FWrites;
  end;

  [TestFixture]
  TBoss4DProgressTests = class
  public
    [Test] procedure PlainFormatsKnownAndUnknownTotals;
    [Test] procedure JsonProducesValidJsonLine;
    [Test] procedure QuietProducesNoOutput;
    [Test] procedure InteractiveUsesInPlaceOutput;
    [Test] procedure FailureIsRendered;
    [Test] procedure ConcurrentEventsRemainWhole;
  end;

implementation

uses
  System.JSON, System.SysUtils, System.Threading,
  Boss4D.Core.Services.Progress;

constructor TProgressOutputMock.Create(const AInteractive: Boolean);
begin
  inherited Create;
  FLines := TList<string>.Create;
  FWrites := TList<string>.Create;
  FInteractive := AInteractive;
end;

destructor TProgressOutputMock.Destroy;
begin
  FWrites.Free;
  FLines.Free;
  inherited Destroy;
end;

procedure TProgressOutputMock.Write(const AText: string);
begin
  FWrites.Add(AText);
end;

procedure TProgressOutputMock.WriteLine(const AText: string);
begin
  FLines.Add(AText);
end;

function TProgressOutputMock.IsInteractive: Boolean;
begin
  Result := FInteractive;
end;

procedure TBoss4DProgressTests.PlainFormatsKnownAndUnknownTotals;
var
  LOutput: TProgressOutputMock;
  LReporter: IBoss4DProgressReporter;
begin
  LOutput := TProgressOutputMock.Create;
  LReporter := TBoss4DProgressReporter.Create(LOutput, 'plain');
  LReporter.Report(TBoss4DProgressEvent.Create('1', 'horse',
    Downloading, 1, 3, 'baixando'));
  LReporter.Report(TBoss4DProgressEvent.Create('1', 'horse',
    Resolving, 0, 0, 'resolvendo'));
  Assert.AreEqual('[downloading] horse [1/3] - baixando', LOutput.Lines[0]);
  Assert.AreEqual('[resolving] horse - resolvendo', LOutput.Lines[1]);
end;

procedure TBoss4DProgressTests.JsonProducesValidJsonLine;
var
  LOutput: TProgressOutputMock;
  LReporter: IBoss4DProgressReporter;
  LJson: TJSONValue;
begin
  LOutput := TProgressOutputMock.Create;
  LReporter := TBoss4DProgressReporter.Create(LOutput, 'json');
  LReporter.Report(TBoss4DProgressEvent.Create('op-1', 'horse',
    Completed, 1, 1, 'ok'));
  LJson := TJSONObject.ParseJSONValue(LOutput.Lines[0]);
  try
    Assert.IsNotNull(LJson);
    Assert.AreEqual('completed',
      LJson.GetValue<string>('phase'));
    Assert.AreEqual('op-1',
      LJson.GetValue<string>('operationId'));
  finally
    LJson.Free;
  end;
end;

procedure TBoss4DProgressTests.QuietProducesNoOutput;
var
  LOutput: TProgressOutputMock;
  LReporter: IBoss4DProgressReporter;
begin
  LOutput := TProgressOutputMock.Create;
  LReporter := TBoss4DNullProgressReporter.Create;
  LReporter.Report(TBoss4DProgressEvent.Create('1', 'horse',
    Waiting, 0, 0, ''));
  Assert.AreEqual<Integer>(0, LOutput.Lines.Count);
  Assert.AreEqual<Integer>(0, LOutput.Writes.Count);
end;

procedure TBoss4DProgressTests.InteractiveUsesInPlaceOutput;
var
  LOutput: TProgressOutputMock;
  LReporter: IBoss4DProgressReporter;
begin
  LOutput := TProgressOutputMock.Create(True);
  LReporter := TBoss4DProgressReporter.Create(LOutput, 'interactive');
  LReporter.Report(TBoss4DProgressEvent.Create('1', 'horse',
    Compiling, 1, 2, ''));
  Assert.AreEqual<Integer>(1, LOutput.Writes.Count);
  Assert.IsTrue(LOutput.Writes[0].StartsWith(#13));
end;

procedure TBoss4DProgressTests.FailureIsRendered;
var
  LOutput: TProgressOutputMock;
  LReporter: IBoss4DProgressReporter;
begin
  LOutput := TProgressOutputMock.Create;
  LReporter := TBoss4DProgressReporter.Create(LOutput, 'plain');
  LReporter.Report(TBoss4DProgressEvent.Create('1', 'horse',
    Failed, 0, 0, 'network error'));
  Assert.IsTrue(LOutput.Lines[0].Contains('[failed]'));
  Assert.IsTrue(LOutput.Lines[0].Contains('network error'));
end;

procedure TBoss4DProgressTests.ConcurrentEventsRemainWhole;
var
  LOutput: TProgressOutputMock;
  LReporter: IBoss4DProgressReporter;
  LTasks: TArray<ITask>;
  LProc: TProc;
begin
  LOutput := TProgressOutputMock.Create;
  LReporter := TBoss4DProgressReporter.Create(LOutput, 'plain');
  SetLength(LTasks, 8);
  for var I := 0 to High(LTasks) do
  begin
    LProc := procedure
    begin
      LReporter.Report(TBoss4DProgressEvent.Create('parallel',
        'package', Downloading, 1, 1, 'ok'));
    end;
    LTasks[I] := TTask.Run(LProc);
  end;
  TTask.WaitForAll(LTasks);
  Assert.AreEqual(Length(LTasks), LOutput.Lines.Count);
  for var LLine in LOutput.Lines do
    Assert.AreEqual('[downloading] package [1/1] - ok', LLine);
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DProgressTests);

end.
