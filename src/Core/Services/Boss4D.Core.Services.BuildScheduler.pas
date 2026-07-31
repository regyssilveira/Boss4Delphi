unit Boss4D.Core.Services.BuildScheduler;

interface

uses
  System.SysUtils,
  Boss4D.Core.Domain.BuildMatrix;

type
  EBoss4DBuildSchedulerError = class(Exception);

  TBoss4DBuildTargetWorker = reference to procedure(
    const ATarget: TBoss4DBuildTarget);
  TBoss4DBuildCancellationProbe = reference to function: Boolean;

  TBoss4DBuildScheduler = class
  public
    class function Execute(const ATargets: TBoss4DBuildTargetList;
      const AJobs: Integer; const AWorker: TBoss4DBuildTargetWorker;
      const ACancellation: TBoss4DBuildCancellationProbe = nil): Integer;
      static;
  end;

implementation

uses
  System.Classes,
  System.Threading,
  System.Generics.Collections,
  System.Generics.Defaults,
  Boss4D.Core.Services.BuildGraph;

type
  TBoss4DSchedulerState = class
  private
    FGuard: TObject;
    FFailed: Boolean;
    FCancelled: Boolean;
    FErrorMessage: string;
    FCompleted: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function ShouldStop: Boolean;
    procedure MarkCancelled;
    procedure MarkFailed(const ATarget: TBoss4DBuildTarget;
      const AMessage: string);
    procedure MarkCompleted;
    property Failed: Boolean read FFailed;
    property ErrorMessage: string read FErrorMessage;
    property Completed: Integer read FCompleted;
  end;

constructor TBoss4DSchedulerState.Create;
begin
  inherited Create;
  FGuard := TObject.Create;
end;

destructor TBoss4DSchedulerState.Destroy;
begin
  FGuard.Free;
  inherited Destroy;
end;

function TBoss4DSchedulerState.ShouldStop: Boolean;
begin
  TMonitor.Enter(FGuard);
  try
    Result := FFailed or FCancelled;
  finally
    TMonitor.Exit(FGuard);
  end;
end;

procedure TBoss4DSchedulerState.MarkCancelled;
begin
  TMonitor.Enter(FGuard);
  try
    FCancelled := True;
  finally
    TMonitor.Exit(FGuard);
  end;
end;

procedure TBoss4DSchedulerState.MarkFailed(
  const ATarget: TBoss4DBuildTarget; const AMessage: string);
begin
  TMonitor.Enter(FGuard);
  try
    if not FFailed then
    begin
      FFailed := True;
      FErrorMessage := Format('Target %s falhou: %s',
        [ATarget.ProjectPath, AMessage]);
    end;
  finally
    TMonitor.Exit(FGuard);
  end;
end;

procedure TBoss4DSchedulerState.MarkCompleted;
begin
  TMonitor.Enter(FGuard);
  try
    Inc(FCompleted);
  finally
    TMonitor.Exit(FGuard);
  end;
end;

function TargetKey(const ATarget: TBoss4DBuildTarget): string;
begin
  Result := ATarget.Identity.ToLower;
end;

function DependencyKey(const ATarget: TBoss4DBuildTarget;
  const AProjectPath: string): string;
begin
  Result := (ATarget.PackageName + '|' + AProjectPath + '|' +
    ATarget.Compiler + '|' + ATarget.Platform + '|' +
    ATarget.Configuration).ToLower;
end;

function ResourceKey(const ATarget: TBoss4DBuildTarget): string;
begin
  Result := (ATarget.PackageName + '|' + ATarget.Compiler + '|' +
    ATarget.Platform + '|' + ATarget.Configuration).ToLower;
end;

function CreateTargetTask(const ATarget: TBoss4DBuildTarget;
  const AWorker: TBoss4DBuildTargetWorker;
  const ACancellation: TBoss4DBuildCancellationProbe;
  const AState: TBoss4DSchedulerState): ITask;
begin
  Result := TTask.Run(
    procedure
    begin
      if AState.ShouldStop then
        Exit;
      if Assigned(ACancellation) and ACancellation() then
      begin
        AState.MarkCancelled;
        Exit;
      end;
      try
        AWorker(ATarget);
        AState.MarkCompleted;
      except
        on E: Exception do
          AState.MarkFailed(ATarget, E.Message);
      end;
    end);
end;

class function TBoss4DBuildScheduler.Execute(
  const ATargets: TBoss4DBuildTargetList; const AJobs: Integer;
  const AWorker: TBoss4DBuildTargetWorker;
  const ACancellation: TBoss4DBuildCancellationProbe): Integer;
var
  LCompleted: TDictionary<string, Boolean>;
  LRunningTargets: TList<TBoss4DBuildTarget>;
  LRunningTasks: TList<ITask>;
  LBusyResources: TDictionary<string, Boolean>;
  LPending: TList<TBoss4DBuildTarget>;
  LState: TBoss4DSchedulerState;
  LJobCount: Integer;
begin
  if not Assigned(ATargets) then
    raise EArgumentNilException.Create('ATargets');
  if not Assigned(AWorker) then
    raise EArgumentNilException.Create('AWorker');
  if Assigned(ACancellation) and ACancellation() then
    Exit(0);
  if ATargets.Count = 0 then
    Exit(0);

  LJobCount := AJobs;
  if LJobCount <= 0 then
    LJobCount := TThread.ProcessorCount;
  if LJobCount <= 0 then
    LJobCount := 1;

  TBoss4DBuildGraph.Sort(ATargets);
  LCompleted := TDictionary<string, Boolean>.Create;
  LRunningTargets := TList<TBoss4DBuildTarget>.Create;
  LRunningTasks := TList<ITask>.Create;
  LBusyResources := TDictionary<string, Boolean>.Create;
  LPending := TList<TBoss4DBuildTarget>.Create;
  LState := TBoss4DSchedulerState.Create;
  try
    for var LTarget in ATargets do
      LPending.Add(LTarget);

    while (LPending.Count > 0) or (LRunningTasks.Count > 0) do
    begin
      if Assigned(ACancellation) and ACancellation() then
        LState.MarkCancelled;

      if not LState.ShouldStop then
      begin
        var I := 0;
        while (I < LPending.Count) and
              (LRunningTasks.Count < LJobCount) do
        begin
          var LTarget := LPending[I];
          var LReady := True;
          for var LDependencyPath in LTarget.DependsOn do
            if not LCompleted.ContainsKey(
              DependencyKey(LTarget, LDependencyPath)) then
            begin
              LReady := False;
              Break;
            end;
          var LResource := ResourceKey(LTarget);
          if LReady and not LBusyResources.ContainsKey(LResource) then
          begin
            LBusyResources.Add(LResource, True);
            LRunningTargets.Add(LTarget);
            LRunningTasks.Add(CreateTargetTask(LTarget, AWorker,
              ACancellation, LState));
            LPending.Delete(I);
          end
          else
            Inc(I);
        end;
      end;

      if LRunningTasks.Count = 0 then
        Break;

      var LTasks := LRunningTasks.ToArray;
      var LFinished := TTask.WaitForAny(LTasks);
      var LFinishedTarget := LRunningTargets[LFinished];
      LBusyResources.Remove(ResourceKey(LFinishedTarget));
      if not LState.Failed then
        LCompleted.AddOrSetValue(TargetKey(LFinishedTarget), True);
      LRunningTasks.Delete(LFinished);
      LRunningTargets.Delete(LFinished);
    end;

    if LRunningTasks.Count > 0 then
      TTask.WaitForAll(LRunningTasks.ToArray);
    if LState.Failed then
      raise EBoss4DBuildSchedulerError.Create(LState.ErrorMessage);
    Result := LState.Completed;
  finally
    LState.Free;
    LPending.Free;
    LBusyResources.Free;
    LRunningTasks.Free;
    LRunningTargets.Free;
    LCompleted.Free;
  end;
end;

end.
