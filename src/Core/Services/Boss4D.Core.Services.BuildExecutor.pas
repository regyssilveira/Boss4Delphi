unit Boss4D.Core.Services.BuildExecutor;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.ArtifactCache,
  Boss4D.Core.Services.BuildState,
  Boss4D.Core.Services.BuildScheduler;

type
  TBoss4DBuildExecutor = class
  private
    FCompiler: IBoss4DCompiler;
    FArtifactCache: TBoss4DArtifactCacheService;
    FBuildState: TBoss4DBuildStateService;
    FLastExplanations: TList<string>;
    FBuiltCount: Integer;
    FSkippedCount: Integer;
    FRestoredCount: Integer;
    FGuard: TObject;
    function ResolveProjectPath(const ARootDirectory,
      ADeclaredPath: string): string;
  public
    constructor Create(const ACompiler: IBoss4DCompiler);
    destructor Destroy; override;
    function Execute(const APackage: TBoss4DPackage;
      const ADependency: TBoss4DDependency; const ALock: TBoss4DLock;
      const ARootDirectory: string; const ASelection: TBoss4DBuildSelection;
      const ASourceChecksum: string; const AForce: Boolean = False;
      const AJobs: Integer = 1;
      const ACancellation: TBoss4DBuildCancellationProbe = nil): Integer;
    property LastExplanations: TList<string> read FLastExplanations;
    property BuiltCount: Integer read FBuiltCount;
    property SkippedCount: Integer read FSkippedCount;
    property RestoredCount: Integer read FRestoredCount;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Defaults,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.BuildMatrix,
  Boss4D.Core.Services.BuildGraph,
  Boss4D.Core.Services.BuildPaths;

constructor TBoss4DBuildExecutor.Create(const ACompiler: IBoss4DCompiler);
begin
  inherited Create;
  if not Assigned(ACompiler) then
    raise EArgumentNilException.Create('ACompiler');
  FCompiler := ACompiler;
  FArtifactCache := TBoss4DArtifactCacheService.Create;
  FBuildState := TBoss4DBuildStateService.Create;
  FLastExplanations := TList<string>.Create;
  FGuard := TObject.Create;
end;

destructor TBoss4DBuildExecutor.Destroy;
begin
  FGuard.Free;
  FLastExplanations.Free;
  FBuildState.Free;
  FArtifactCache.Free;
  inherited Destroy;
end;

function TBoss4DBuildExecutor.ResolveProjectPath(const ARootDirectory,
  ADeclaredPath: string): string;
var
  LRoot: string;
begin
  if not TDirectory.Exists(ARootDirectory) then
    raise EDirectoryNotFoundException.CreateFmt(
      'Diretorio raiz do build nao encontrado: %s.', [ARootDirectory]);
  LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ARootDirectory));
  Result := TPath.GetFullPath(TPath.Combine(ARootDirectory, ADeclaredPath));
  if not Result.StartsWith(LRoot, True) then
    raise EArgumentException.CreateFmt(
      'Projeto da matriz fora da raiz do pacote: %s.', [ADeclaredPath]);
  if not TFile.Exists(Result) then
    raise EFileNotFoundException.CreateFmt(
      'Projeto da matriz nao encontrado: %s.', [ADeclaredPath]);
end;

function TBoss4DBuildExecutor.Execute(const APackage: TBoss4DPackage;
  const ADependency: TBoss4DDependency; const ALock: TBoss4DLock;
  const ARootDirectory: string; const ASelection: TBoss4DBuildSelection;
  const ASourceChecksum: string; const AForce: Boolean;
  const AJobs: Integer;
  const ACancellation: TBoss4DBuildCancellationProbe): Integer;
var
  LTargets: TBoss4DBuildTargetList;
  LFingerprints: TDictionary<string, string>;
begin
  if not Assigned(APackage) then
    raise EArgumentNilException.Create('APackage');
  if not Assigned(ADependency) then
    raise EArgumentNilException.Create('ADependency');
  if not Assigned(ALock) then
    raise EArgumentNilException.Create('ALock');

  FBuiltCount := 0;
  FSkippedCount := 0;
  FRestoredCount := 0;
  FLastExplanations.Clear;
  LTargets := TBoss4DBuildMatrixExpander.Expand(APackage, ASelection);
  TDirectory.CreateDirectory(TPath.Combine(GetBossHome, 'artifact-cache'));
  for var LTarget in LTargets do
    TDirectory.CreateDirectory(TBoss4DBuildPaths.TargetRoot(GetModulesDir,
      ADependency.StorageName, LTarget.Compiler, LTarget.Platform,
      LTarget.Configuration));
  LFingerprints := TDictionary<string, string>.Create;
  try
    Result := TBoss4DBuildScheduler.Execute(LTargets, AJobs,
      procedure(const LTarget: TBoss4DBuildTarget)
      begin
        var LProjectPath := ResolveProjectPath(ARootDirectory,
          LTarget.ProjectPath);
        var LTargetRoot := TBoss4DBuildPaths.TargetRoot(GetModulesDir,
          ADependency.StorageName, LTarget.Compiler, LTarget.Platform,
          LTarget.Configuration);
        var LDependencyFingerprints := TList<string>.Create;
        try
          for var LDependencyPath in LTarget.DependsOn do
          begin
            var LDependencyIdentity := (LTarget.PackageName + '|' +
              LDependencyPath + '|' + LTarget.Compiler + '|' +
              LTarget.Platform + '|' + LTarget.Configuration).ToLower;
            var LDependencyFingerprint := '';
            TMonitor.Enter(FGuard);
            try
              if not LFingerprints.TryGetValue(LDependencyIdentity,
                LDependencyFingerprint) then
                raise EBoss4DBuildGraphError.CreateFmt(
                  'Fingerprint da dependencia ainda indisponivel: %s.',
                  [LDependencyIdentity]);
            finally
              TMonitor.Exit(FGuard);
            end;
            LDependencyFingerprints.Add(LDependencyFingerprint);
          end;
          var LDecision := FBuildState.Evaluate(LTarget, LProjectPath,
            LTargetRoot, LDependencyFingerprints.ToArray, AForce);
          TMonitor.Enter(FGuard);
          try
            FLastExplanations.Add(LTarget.Identity + ': ' +
              FBuildState.Explain(LDecision));
          finally
            TMonitor.Exit(FGuard);
          end;
          if not LDecision.ShouldBuild then
          begin
            TMonitor.Enter(FGuard);
            try
              Inc(FSkippedCount);
              LFingerprints.Add(LTarget.Identity.ToLower,
                LDecision.Fingerprint);
            finally
              TMonitor.Exit(FGuard);
            end;
            Exit;
          end;

          var LCacheFingerprint := ASourceChecksum + '|' +
            LDecision.Fingerprint;
          if not AForce and FArtifactCache.Restore(ADependency,
            LCacheFingerprint, LTarget.Platform, LTarget.Compiler,
            LTarget.Configuration, LTargetRoot) then
          begin
            FBuildState.Save(LTarget, LTargetRoot, LDecision);
            TMonitor.Enter(FGuard);
            try
              Inc(FRestoredCount);
            finally
              TMonitor.Exit(FGuard);
            end;
          end
          else
          begin
            if not FCompiler.Compile(LProjectPath, ADependency, ALock,
              LTarget.Platform, LTarget.Compiler,
              LTarget.Configuration) then
              raise Exception.CreateFmt('Falha ao compilar target %s.',
                [LTarget.Identity]);
            FBuildState.Save(LTarget, LTargetRoot, LDecision);
            FArtifactCache.Store(ADependency, LCacheFingerprint,
              LTarget.Platform, LTarget.Compiler, LTarget.Configuration,
              LTargetRoot);
            TMonitor.Enter(FGuard);
            try
              Inc(FBuiltCount);
            finally
              TMonitor.Exit(FGuard);
            end;
          end;
          TMonitor.Enter(FGuard);
          try
            LFingerprints.Add(LTarget.Identity.ToLower,
              LDecision.Fingerprint);
          finally
            TMonitor.Exit(FGuard);
          end;
        finally
          LDependencyFingerprints.Free;
        end;
      end,
      ACancellation);
    FLastExplanations.Sort(TComparer<string>.Construct(
      function(const ALeft, ARight: string): Integer
      begin
        Result := CompareText(ALeft, ARight);
      end));
  finally
    LFingerprints.Free;
    LTargets.Free;
  end;
end;

end.
