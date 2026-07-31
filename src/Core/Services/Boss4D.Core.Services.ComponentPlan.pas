unit Boss4D.Core.Services.ComponentPlan;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Domain.BuildMatrix;

type
  TBoss4DComponentState = (Declared, Compiled, Installed, Divergent, Broken);

  TBoss4DComponentStates = class
  public
    class function NameOf(const AState: TBoss4DComponentState): string;
      static;
  end;

  TBoss4DComponentStateResolver = reference to function(
    const AIdentity: TBoss4DComponentPackageIdentity):
    TBoss4DComponentState;

  TBoss4DComponentPlanItem = class
  private
    FIdentity: TBoss4DComponentPackageIdentity;
    FProjectPath: string;
    FDependencies: TList<string>;
    FState: TBoss4DComponentState;
  public
    constructor Create(
      const AIdentity: TBoss4DComponentPackageIdentity;
      const AProjectPath: string; const ADependencies: TList<string>;
      const AState: TBoss4DComponentState);
    destructor Destroy; override;
    property Identity: TBoss4DComponentPackageIdentity read FIdentity;
    property ProjectPath: string read FProjectPath;
    property Dependencies: TList<string> read FDependencies;
    property State: TBoss4DComponentState read FState;
  end;

  TBoss4DComponentPlan = class(TObjectList<TBoss4DComponentPlanItem>);

  TBoss4DComponentPlanner = class
  public
    class function Plan(const ATargets: TBoss4DBuildTargetList;
      const AProfile: string;
      const AStateResolver: TBoss4DComponentStateResolver = nil):
      TBoss4DComponentPlan; static;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.Core.Services.BuildGraph;

class function TBoss4DComponentStates.NameOf(
  const AState: TBoss4DComponentState): string;
begin
  case AState of
    TBoss4DComponentState.Compiled:
      Result := 'compiled';
    TBoss4DComponentState.Installed:
      Result := 'installed';
    TBoss4DComponentState.Divergent:
      Result := 'divergent';
    TBoss4DComponentState.Broken:
      Result := 'broken';
  else
    Result := 'declared';
  end;
end;

constructor TBoss4DComponentPlanItem.Create(
  const AIdentity: TBoss4DComponentPackageIdentity;
  const AProjectPath: string; const ADependencies: TList<string>;
  const AState: TBoss4DComponentState);
begin
  inherited Create;
  FIdentity := AIdentity;
  FProjectPath := AProjectPath;
  FState := AState;
  FDependencies := TList<string>.Create;
  FDependencies.AddRange(ADependencies);
end;

destructor TBoss4DComponentPlanItem.Destroy;
begin
  FDependencies.Free;
  inherited Destroy;
end;

class function TBoss4DComponentPlanner.Plan(
  const ATargets: TBoss4DBuildTargetList; const AProfile: string;
  const AStateResolver: TBoss4DComponentStateResolver):
  TBoss4DComponentPlan;
var
  LOrdered: TBoss4DBuildTargetList;
begin
  if not Assigned(ATargets) then
    raise EArgumentNilException.Create('ATargets');
  Result := TBoss4DComponentPlan.Create(True);
  LOrdered := TBoss4DBuildTargetList.Create(False);
  try
    try
      for var LTarget in ATargets do
        LOrdered.Add(LTarget);
      TBoss4DBuildGraph.Sort(LOrdered);
      for var LTarget in LOrdered do
      begin
        var LIdentity :=
          TBoss4DComponentPackageIdentity.FromTarget(LTarget, AProfile);
        var LState := TBoss4DComponentState.Declared;
        if Assigned(AStateResolver) then
          LState := AStateResolver(LIdentity);
        Result.Add(TBoss4DComponentPlanItem.Create(LIdentity,
          LTarget.ProjectPath, LTarget.DependsOn, LState));
      end;
    finally
      LOrdered.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
