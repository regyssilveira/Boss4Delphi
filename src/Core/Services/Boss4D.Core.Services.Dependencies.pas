unit Boss4D.Core.Services.Dependencies;

interface

uses
  System.Generics.Collections, System.Generics.Defaults, Boss4D.Core.Ports,
  Boss4D.Core.Domain.Lock;

type
  TBoss4DDependencyInfo = record
    Key: string;
    Version: string;
    Direct: Boolean;
    Scope: string;
  end;

  TBoss4DDependencyService = class
  private
    FPackageRepo: IBoss4DPackageRepository;
    FLockRepo: IBoss4DLockRepository;
    FLogger: IBoss4DLogger;
    function ResolveDeclaredKey(const ARequested: string;
      const ADependencies: TDictionary<string, string>): string;
    procedure VisitReachable(const AKey: string; const ALock: TBoss4DLock;
      const AReachable: TDictionary<string, Boolean>);
  public
    constructor Create(const APackageRepo: IBoss4DPackageRepository;
      const ALockRepo: IBoss4DLockRepository; const ALogger: IBoss4DLogger);
    procedure Remove(const ADependency: string);
    function List: TArray<TBoss4DDependencyInfo>;
    function Why(const ADependency: string): TArray<string>;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Consts, Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.Transaction;

constructor TBoss4DDependencyService.Create(
  const APackageRepo: IBoss4DPackageRepository;
  const ALockRepo: IBoss4DLockRepository; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FPackageRepo := APackageRepo;
  FLockRepo := ALockRepo;
  FLogger := ALogger;
end;

function TBoss4DDependencyService.ResolveDeclaredKey(const ARequested: string;
  const ADependencies: TDictionary<string, string>): string;
var
  LRequested: string;
  LDep: TBoss4DDependency;
  LKey: string;
begin
  Result := '';
  LRequested := ARequested;
  try
    LDep := TBoss4DDependency.ParseCommandLine(ARequested);
    try
      LRequested := LDep.Repository;
    finally
      LDep.Free;
    end;
  except
    on E: Exception do
      FLogger.Log(TBoss4DLogLevel.Debug,
        'Entrada tratada como nome de dependencia: ' + E.Message);
  end;
  for LKey in ADependencies.Keys do
    if SameText(LKey, LRequested) or
       SameText(TPath.GetFileName(LKey), LRequested) then
      Exit(LKey);
end;

procedure TBoss4DDependencyService.VisitReachable(const AKey: string;
  const ALock: TBoss4DLock; const AReachable: TDictionary<string, Boolean>);
var
  LLocked: TBoss4DLockedDependency;
  LChild: string;
begin
  if AReachable.ContainsKey(AKey) then
    Exit;
  AReachable.Add(AKey, True);
  if ALock.Installed.TryGetValue(AKey, LLocked) then
    for LChild in LLocked.Dependencies do
      VisitReachable(LChild, ALock, AReachable);
end;

procedure TBoss4DDependencyService.Remove(const ADependency: string);
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDeclaredKey: string;
  LLockPath: string;
  LReachable: TDictionary<string, Boolean>;
  LKeys: TArray<string>;
  LKey: string;
  LDep: TBoss4DDependency;
  LTransaction: TBoss4DProjectTransaction;
  LRemovedStorage: TList<string>;
  LLocked: TBoss4DLockedDependency;
  LModulePath: string;
  LIsDevelopment: Boolean;
begin
  LTransaction := TBoss4DProjectTransaction.Create(GetCurrentDir);
  LRemovedStorage := TList<string>.Create;
  try
    LPkg := FPackageRepo.Load(GetBossFile);
    try
      LDeclaredKey := ResolveDeclaredKey(ADependency, LPkg.Dependencies);
      LIsDevelopment := False;
      if LDeclaredKey.IsEmpty then
      begin
        LDeclaredKey := ResolveDeclaredKey(ADependency,
          LPkg.DevDependencies);
        LIsDevelopment := not LDeclaredKey.IsEmpty;
      end;
      if LDeclaredKey.IsEmpty then
        raise EArgumentException.CreateFmt(
          'Dependencia nao declarada: %s', [ADependency]);
      if LIsDevelopment then
        LPkg.DevDependencies.Remove(LDeclaredKey)
      else
        LPkg.RemoveDependency(LDeclaredKey);
      FPackageRepo.Save(LPkg, GetBossFile);
    finally
      LPkg.Free;
    end;

    LLockPath := TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK);
    LLock := FLockRepo.Load(LLockPath);
    try
      LReachable := TDictionary<string, Boolean>.Create;
      try
        LLock.RootDependencies.Clear;
        LLock.RootDevDependencies.Clear;
        LPkg := FPackageRepo.Load(GetBossFile);
        try
          for LKey in LPkg.Dependencies.Keys do
          begin
            LDep := TBoss4DDependency.Parse(LKey, LPkg.Dependencies[LKey]);
            try
              LLock.RootDependencies.Add(LDep.GetKey);
              VisitReachable(LDep.GetKey, LLock, LReachable);
            finally
              LDep.Free;
            end;
          end;
          for LKey in LPkg.DevDependencies.Keys do
          begin
            LDep := TBoss4DDependency.Parse(LKey,
              LPkg.DevDependencies[LKey]);
            try
              LLock.RootDevDependencies.Add(LDep.GetKey);
              VisitReachable(LDep.GetKey, LLock, LReachable);
            finally
              LDep.Free;
            end;
          end;
        finally
          LPkg.Free;
        end;
        LKeys := LLock.Installed.Keys.ToArray;
        for LKey in LKeys do
          if not LReachable.ContainsKey(LKey) then
          begin
            if LLock.Installed.TryGetValue(LKey, LLocked) then
            begin
              LDep := TBoss4DDependency.Create(LLocked.Repository, '');
              try
                if not LRemovedStorage.Contains(LDep.StorageName) then
                  LRemovedStorage.Add(LDep.StorageName);
              finally
                LDep.Free;
              end;
            end;
            LLock.Installed.Remove(LKey);
          end;
        FLockRepo.Save(LLock, LLockPath);
      finally
        LReachable.Free;
      end;
    finally
      LLock.Free;
    end;
    for LKey in LRemovedStorage do
    begin
      LModulePath := TPath.Combine(GetModulesDir, LKey);
      if TDirectory.Exists(LModulePath) then
        TDirectory.Delete(LModulePath, True);
    end;
    LTransaction.Commit;
    FLogger.Log(TBoss4DLogLevel.Info,
      'Dependencia removida: ' + LDeclaredKey);
  finally
    LRemovedStorage.Free;
    LTransaction.Free;
  end;
end;

function TBoss4DDependencyService.List: TArray<TBoss4DDependencyInfo>;
var
  LPkg: TBoss4DPackage;
  LLock: TBoss4DLock;
  LDirect: TDictionary<string, Boolean>;
  LItems: TList<TBoss4DDependencyInfo>;
  LDep: TBoss4DDependency;
  LPair: TPair<string, TBoss4DLockedDependency>;
  LInfo: TBoss4DDependencyInfo;
begin
  LPkg := FPackageRepo.Load(GetBossFile);
  LLock := FLockRepo.Load(TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK));
  LDirect := TDictionary<string, Boolean>.Create;
  LItems := TList<TBoss4DDependencyInfo>.Create;
  try
    for var LManifestPair in LPkg.Dependencies do
    begin
      LDep := TBoss4DDependency.Parse(LManifestPair.Key, LManifestPair.Value);
      try
        LDirect.AddOrSetValue(LDep.GetKey, True);
      finally
        LDep.Free;
      end;
    end;
    for var LManifestPair in LPkg.DevDependencies do
    begin
      LDep := TBoss4DDependency.Parse(LManifestPair.Key, LManifestPair.Value);
      try
        LDirect.AddOrSetValue(LDep.GetKey, True);
      finally
        LDep.Free;
      end;
    end;
    for LPair in LLock.Installed do
    begin
      LInfo.Key := LPair.Key;
      LInfo.Version := LPair.Value.Version;
      LInfo.Direct := LDirect.ContainsKey(LPair.Key);
      LInfo.Scope := LPair.Value.Scope;
      LItems.Add(LInfo);
    end;
    LItems.Sort(TComparer<TBoss4DDependencyInfo>.Construct(
      function(const ALeft, ARight: TBoss4DDependencyInfo): Integer
      begin
        Result := CompareText(ALeft.Key, ARight.Key);
      end));
    Result := LItems.ToArray;
  finally
    LItems.Free;
    LDirect.Free;
    LLock.Free;
    LPkg.Free;
  end;
end;

function TBoss4DDependencyService.Why(
  const ADependency: string): TArray<string>;
var
  LLock: TBoss4DLock;
  LTarget: string;
  LQueue: TQueue<TArray<string>>;
  LVisited: TDictionary<string, Boolean>;
  LPath, LNext: TArray<string>;
  LLocked: TBoss4DLockedDependency;
  LChild, LRoot: string;
begin
  LTarget := ADependency.ToLower;
  LLock := FLockRepo.Load(TPath.Combine(GetCurrentDir, FILE_PACKAGE_LOCK));
  LQueue := TQueue<TArray<string>>.Create;
  LVisited := TDictionary<string, Boolean>.Create;
  try
    for LRoot in LLock.RootDependencies do
      LQueue.Enqueue(TArray<string>.Create(LRoot));
    while LQueue.Count > 0 do
    begin
      LPath := LQueue.Dequeue;
      LRoot := LPath[High(LPath)];
      if SameText(LRoot, LTarget) or
         SameText(TPath.GetFileName(LRoot), LTarget) then
        Exit(LPath);
      if LVisited.ContainsKey(LRoot) then
        Continue;
      LVisited.Add(LRoot, True);
      if LLock.Installed.TryGetValue(LRoot, LLocked) then
        for LChild in LLocked.Dependencies do
        begin
          LNext := Copy(LPath);
          SetLength(LNext, Length(LNext) + 1);
          LNext[High(LNext)] := LChild;
          LQueue.Enqueue(LNext);
        end;
    end;
    Result := nil;
  finally
    LVisited.Free;
    LQueue.Free;
    LLock.Free;
  end;
end;

end.
