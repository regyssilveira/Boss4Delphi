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
    property Cancelled: Boolean read FCancelled;
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

function CreateGroupTask(const AGroup: TList<TBoss4DBuildTarget>;
  const AWorker: TBoss4DBuildTargetWorker;
  const ACancellation: TBoss4DBuildCancellationProbe;
  const AState: TBoss4DSchedulerState): ITask;
begin
  Result := TTask.Run(
    procedure
    begin
      for var LTarget in AGroup do
      begin
        if AState.ShouldStop then
          Exit;
        if Assigned(ACancellation) and ACancellation() then
        begin
          AState.MarkCancelled;
          Exit;
        end;
        try
          AWorker(LTarget);
          AState.MarkCompleted;
        except
          on E: Exception do
          begin
            AState.MarkFailed(LTarget, E.Message);
            Exit;
          end;
        end;
      end;
    end);
end;

class function TBoss4DBuildScheduler.Execute(
  const ATargets: TBoss4DBuildTargetList; const AJobs: Integer;
  const AWorker: TBoss4DBuildTargetWorker;
  const ACancellation: TBoss4DBuildCancellationProbe): Integer;
var
  LLevels: TDictionary<string, Integer>;
  LGroups: TObjectDictionary<string, TList<TBoss4DBuildTarget>>;
  LGroupList: TList<TList<TBoss4DBuildTarget>>;
  LState: TBoss4DSchedulerState;
  LMaximumLevel: Integer;
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
  LLevels := TDictionary<string, Integer>.Create;
  LState := TBoss4DSchedulerState.Create;
  try
    LMaximumLevel := 0;
    for var LTarget in ATargets do
    begin
      var LLevel := 0;
      for var LDependencyPath in LTarget.DependsOn do
      begin
        var LDependencyKey := DependencyKey(LTarget, LDependencyPath);
        if not LLevels.ContainsKey(LDependencyKey) then
          raise EBoss4DBuildSchedulerError.CreateFmt(
            'Nivel da dependencia nao encontrado: %s.',
            [LDependencyPath]);
        if LLevels[LDependencyKey] + 1 > LLevel then
          LLevel := LLevels[LDependencyKey] + 1;
      end;
      LLevels.Add(TargetKey(LTarget), LLevel);
      if LLevel > LMaximumLevel then
        LMaximumLevel := LLevel;
    end;

    for var LLevel := 0 to LMaximumLevel do
    begin
      if LState.ShouldStop then
        Break;
      if Assigned(ACancellation) and ACancellation() then
      begin
        LState.MarkCancelled;
        Break;
      end;

      LGroups := TObjectDictionary<string,
        TList<TBoss4DBuildTarget>>.Create([doOwnsValues]);
      LGroupList := TList<TList<TBoss4DBuildTarget>>.Create;
      try
        for var LTarget in ATargets do
          if LLevels[TargetKey(LTarget)] = LLevel then
          begin
            var LResourceKey := ResourceKey(LTarget);
            if not LGroups.ContainsKey(LResourceKey) then
              LGroups.Add(LResourceKey,
                TList<TBoss4DBuildTarget>.Create);
            LGroups[LResourceKey].Add(LTarget);
          end;
        for var LGroup in LGroups.Values do
          LGroupList.Add(LGroup);
        LGroupList.Sort(TComparer<TList<TBoss4DBuildTarget>>.Construct(
          function(const ALeft,
            ARight: TList<TBoss4DBuildTarget>): Integer
          begin
            Result := CompareText(ALeft[0].Identity, ARight[0].Identity);
          end));

        var LOffset := 0;
        while LOffset < LGroupList.Count do
        begin
          var LBatchSize := LJobCount;
          if LOffset + LBatchSize > LGroupList.Count then
            LBatchSize := LGroupList.Count - LOffset;
          var LTasks: TArray<ITask>;
          SetLength(LTasks, LBatchSize);
          for var I := 0 to LBatchSize - 1 do
            LTasks[I] := CreateGroupTask(LGroupList[LOffset + I],
              AWorker, ACancellation, LState);
          TTask.WaitForAll(LTasks);
          Inc(LOffset, LBatchSize);
          if LState.ShouldStop then
            Break;
        end;
      finally
        LGroupList.Free;
        LGroups.Free;
      end;
    end;

    if LState.Failed then
      raise EBoss4DBuildSchedulerError.Create(LState.ErrorMessage);
    Result := LState.Completed;
  finally
    LState.Free;
    LLevels.Free;
  end;
end;

end.
