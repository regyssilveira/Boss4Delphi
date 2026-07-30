unit Boss4D.Core.Services.BuildGraph;

interface

uses
  System.SysUtils,
  Boss4D.Core.Domain.BuildMatrix;

type
  EBoss4DBuildGraphError = class(Exception);

  TBoss4DBuildGraph = class
  public
    class procedure Sort(const ATargets: TBoss4DBuildTargetList); static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults;

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

procedure SortTargets(const ATargets: TList<TBoss4DBuildTarget>);
begin
  ATargets.Sort(TComparer<TBoss4DBuildTarget>.Construct(
    function(const ALeft, ARight: TBoss4DBuildTarget): Integer
    begin
      Result := CompareText(ALeft.Identity, ARight.Identity);
    end));
end;

class procedure TBoss4DBuildGraph.Sort(
  const ATargets: TBoss4DBuildTargetList);
var
  LByKey: TDictionary<string, TBoss4DBuildTarget>;
  LInDegree: TDictionary<string, Integer>;
  LDependents: TObjectDictionary<string, TList<TBoss4DBuildTarget>>;
  LReady: TList<TBoss4DBuildTarget>;
  LOrdered: TList<TBoss4DBuildTarget>;
  LRanks: TDictionary<string, Integer>;
  LCycle: TList<string>;
begin
  if not Assigned(ATargets) then
    raise EArgumentNilException.Create('ATargets');

  LByKey := TDictionary<string, TBoss4DBuildTarget>.Create;
  LInDegree := TDictionary<string, Integer>.Create;
  LDependents := TObjectDictionary<string, TList<TBoss4DBuildTarget>>.Create(
    [doOwnsValues]);
  LReady := TList<TBoss4DBuildTarget>.Create;
  LOrdered := TList<TBoss4DBuildTarget>.Create;
  LRanks := TDictionary<string, Integer>.Create;
  try
    for var LTarget in ATargets do
    begin
      var LKey := TargetKey(LTarget);
      if LByKey.ContainsKey(LKey) then
        raise EBoss4DBuildGraphError.CreateFmt(
          'Target duplicado no grafo: %s.', [LTarget.Identity]);
      LByKey.Add(LKey, LTarget);
      LInDegree.Add(LKey, 0);
      LDependents.Add(LKey, TList<TBoss4DBuildTarget>.Create);
    end;

    for var LTarget in ATargets do
      for var LDependencyPath in LTarget.DependsOn do
      begin
        var LDependencyKey := DependencyKey(LTarget, LDependencyPath);
        if not LByKey.ContainsKey(LDependencyKey) then
          raise EBoss4DBuildGraphError.CreateFmt(
            'Target dependente ausente: %s para %s|%s|%s.',
            [LDependencyPath, LTarget.Compiler, LTarget.Platform,
             LTarget.Configuration]);
        var LTargetKey := TargetKey(LTarget);
        LInDegree[LTargetKey] := LInDegree[LTargetKey] + 1;
        LDependents[LDependencyKey].Add(LTarget);
      end;

    for var LTarget in ATargets do
      if LInDegree[TargetKey(LTarget)] = 0 then
        LReady.Add(LTarget);
    SortTargets(LReady);

    while LReady.Count > 0 do
    begin
      var LCurrent := LReady[0];
      LReady.Delete(0);
      LOrdered.Add(LCurrent);
      for var LDependent in LDependents[TargetKey(LCurrent)] do
      begin
        var LDependentKey := TargetKey(LDependent);
        LInDegree[LDependentKey] := LInDegree[LDependentKey] - 1;
        if LInDegree[LDependentKey] = 0 then
          LReady.Add(LDependent);
      end;
      SortTargets(LReady);
    end;

    if LOrdered.Count <> ATargets.Count then
    begin
      LCycle := TList<string>.Create;
      try
        for var LTarget in ATargets do
          if LInDegree[TargetKey(LTarget)] > 0 then
            LCycle.Add(LTarget.ProjectPath);
        LCycle.Sort;
        raise EBoss4DBuildGraphError.Create(
          'Foi detectado um ciclo no grafo de build: ' +
          string.Join(' -> ', LCycle.ToArray) + '.');
      finally
        LCycle.Free;
      end;
    end;

    for var I := 0 to LOrdered.Count - 1 do
      LRanks.Add(TargetKey(LOrdered[I]), I);
    ATargets.Sort(TComparer<TBoss4DBuildTarget>.Construct(
      function(const ALeft, ARight: TBoss4DBuildTarget): Integer
      begin
        Result := LRanks[TargetKey(ALeft)] - LRanks[TargetKey(ARight)];
      end));
  finally
    LRanks.Free;
    LOrdered.Free;
    LReady.Free;
    LDependents.Free;
    LInDegree.Free;
    LByKey.Free;
  end;
end;

end.
