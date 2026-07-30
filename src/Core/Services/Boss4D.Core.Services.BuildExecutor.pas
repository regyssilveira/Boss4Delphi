unit Boss4D.Core.Services.BuildExecutor;

interface

uses
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.ArtifactCache;

type
  TBoss4DBuildExecutor = class
  private
    FCompiler: IBoss4DCompiler;
    FArtifactCache: TBoss4DArtifactCacheService;
    function ResolveProjectPath(const ARootDirectory,
      ADeclaredPath: string): string;
  public
    constructor Create(const ACompiler: IBoss4DCompiler);
    destructor Destroy; override;
    function Execute(const APackage: TBoss4DPackage;
      const ADependency: TBoss4DDependency; const ALock: TBoss4DLock;
      const ARootDirectory: string; const ASelection: TBoss4DBuildSelection;
      const ASourceChecksum: string): Integer;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.BuildMatrix,
  Boss4D.Core.Services.BuildPaths;

constructor TBoss4DBuildExecutor.Create(const ACompiler: IBoss4DCompiler);
begin
  inherited Create;
  if not Assigned(ACompiler) then
    raise EArgumentNilException.Create('ACompiler');
  FCompiler := ACompiler;
  FArtifactCache := TBoss4DArtifactCacheService.Create;
end;

destructor TBoss4DBuildExecutor.Destroy;
begin
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
  const ASourceChecksum: string): Integer;
var
  LTargets: TBoss4DBuildTargetList;
begin
  if not Assigned(APackage) then
    raise EArgumentNilException.Create('APackage');
  if not Assigned(ADependency) then
    raise EArgumentNilException.Create('ADependency');
  if not Assigned(ALock) then
    raise EArgumentNilException.Create('ALock');

  Result := 0;
  LTargets := TBoss4DBuildMatrixExpander.Expand(APackage, ASelection);
  try
    for var LTarget in LTargets do
    begin
      var LProjectPath := ResolveProjectPath(ARootDirectory,
        LTarget.ProjectPath);
      var LTargetRoot := TBoss4DBuildPaths.TargetRoot(GetModulesDir,
        ADependency.StorageName, LTarget.Compiler, LTarget.Platform,
        LTarget.Configuration);
      if not FArtifactCache.Restore(ADependency, ASourceChecksum,
        LTarget.Platform, LTarget.Compiler, LTarget.Configuration,
        LTargetRoot) then
      begin
        if not FCompiler.Compile(LProjectPath, ADependency, ALock,
          LTarget.Platform, LTarget.Compiler, LTarget.Configuration) then
          raise Exception.CreateFmt('Falha ao compilar target %s.',
            [LTarget.Identity]);
        FArtifactCache.Store(ADependency, ASourceChecksum,
          LTarget.Platform, LTarget.Compiler, LTarget.Configuration,
          LTargetRoot);
      end;
      Inc(Result);
    end;
  finally
    LTargets.Free;
  end;
end;

end.
