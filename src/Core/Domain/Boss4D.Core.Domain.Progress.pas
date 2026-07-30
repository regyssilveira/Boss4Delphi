unit Boss4D.Core.Domain.Progress;

interface

uses
  System.SysUtils;

type
  TBoss4DProgressPhase = (Waiting, Resolving, Downloading, Verifying,
    Installing, Compiling, Cached, Completed, Failed);

  TBoss4DProgressEvent = record
    OperationId: string;
    PackageName: string;
    Phase: TBoss4DProgressPhase;
    Current: Integer;
    Total: Integer;
    Message: string;
    Timestamp: TDateTime;
    class function Create(const AOperationId, APackageName: string;
      const APhase: TBoss4DProgressPhase; const ACurrent, ATotal: Integer;
      const AMessage: string): TBoss4DProgressEvent; static;
  end;

  IBoss4DProgressOutput = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60010}']
    procedure Write(const AText: string);
    procedure WriteLine(const AText: string);
    function IsInteractive: Boolean;
  end;

  IBoss4DProgressReporter = interface
    ['{69527D56-F14E-43D4-A746-2D7227D60011}']
    procedure Report(const AEvent: TBoss4DProgressEvent);
  end;

function Boss4DProgressPhaseName(const APhase: TBoss4DProgressPhase): string;

implementation

class function TBoss4DProgressEvent.Create(const AOperationId,
  APackageName: string; const APhase: TBoss4DProgressPhase;
  const ACurrent, ATotal: Integer;
  const AMessage: string): TBoss4DProgressEvent;
begin
  Result.OperationId := AOperationId;
  Result.PackageName := APackageName;
  Result.Phase := APhase;
  Result.Current := ACurrent;
  Result.Total := ATotal;
  Result.Message := AMessage;
  Result.Timestamp := Now;
end;

function Boss4DProgressPhaseName(
  const APhase: TBoss4DProgressPhase): string;
const
  NAMES: array[TBoss4DProgressPhase] of string = ('waiting', 'resolving',
    'downloading', 'verifying', 'installing', 'compiling', 'cached',
    'completed', 'failed');
begin
  Result := NAMES[APhase];
end;

end.
