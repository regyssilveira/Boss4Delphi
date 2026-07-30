unit Boss4D.Tests.BuildMatrix;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsBuildMatrix = class
  public
    [Test]
    procedure TestDeclarativeMatrixExpandsDeterministically;
    [Test]
    procedure TestExplicitSelectionFiltersTargets;
    [Test]
    procedure TestSelectionCanExpandAxesIndependently;
    [Test]
    procedure TestDelphiConventionsCoverSupportedCompilers;
    [Test]
    procedure TestDelphiConventionsExpandTargetPath;
    [Test]
    procedure TestLegacyManifestExpandsSingleCompatibleTarget;
    [Test]
    procedure TestInvalidSelectionFailsBeforeBuild;
    [Test]
    procedure TestDefaultsChooseSingleTarget;
    [Test]
    procedure TestProjectConstraintOutsideMatrixFails;
    [Test]
    procedure TestTargetOutputPathsAreCollisionFree;
    [Test]
    procedure TestArtifactCacheKeyIncludesCompleteTarget;
    [Test]
    procedure TestBuildGraphOrdersDependenciesBeforeConsumers;
    [Test]
    procedure TestBuildGraphRejectsMissingDependencyTarget;
    [Test]
    procedure TestBuildGraphRejectsCycles;
    [Test]
    procedure TestBuildSchedulerRunsIsolatedTargetsInParallel;
    [Test]
    procedure TestBuildSchedulerSerializesSharedOutputRoot;
    [Test]
    procedure TestBuildSchedulerHonorsCancellation;
    [Test]
    procedure TestBuildSchedulerStopsDependentsAfterFailure;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Classes,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildMatrix,
  Boss4D.Core.Services.BuildConventions,
  Boss4D.Core.Services.BuildPaths,
  Boss4D.Core.Services.ArtifactCache,
  Boss4D.Core.Services.BuildGraph,
  Boss4D.Core.Services.BuildScheduler;

procedure TTestsBuildMatrix.TestDelphiConventionsCoverSupportedCompilers;
var
  LConvention: TBoss4DDelphiConvention;
begin
  LConvention := TBoss4DBuildConventions.ResolveCompiler('d101');
  Assert.AreEqual('18.0', LConvention.BDSVersion);
  Assert.AreEqual('240', LConvention.PackageSuffix);
  Assert.AreEqual('31.0', LConvention.CompilerVersion);
  Assert.AreEqual('VER310', LConvention.CompilerSymbol);

  LConvention := TBoss4DBuildConventions.ResolveCompiler('d11');
  Assert.AreEqual('22.0', LConvention.BDSVersion);
  Assert.AreEqual('280', LConvention.PackageSuffix);
  Assert.AreEqual('VER350', LConvention.CompilerSymbol);

  LConvention := TBoss4DBuildConventions.ResolveCompiler('d12');
  Assert.AreEqual('23.0', LConvention.BDSVersion);
  Assert.AreEqual('290', LConvention.PackageSuffix);
  Assert.AreEqual('VER360', LConvention.CompilerSymbol);

  LConvention := TBoss4DBuildConventions.ResolveCompiler('d13');
  Assert.AreEqual('37.0', LConvention.BDSVersion);
  Assert.AreEqual('370', LConvention.PackageSuffix);
  Assert.AreEqual('VER370', LConvention.CompilerSymbol);

  Assert.WillRaise(
    procedure
    begin
      TBoss4DBuildConventions.ResolveCompiler('d10');
    end,
    EArgumentException);
end;

procedure TTestsBuildMatrix.TestDelphiConventionsExpandTargetPath;
begin
  Assert.AreEqual(
    'packages\d13\37.0\Win64\Release\Component370.dproj',
    TBoss4DBuildConventions.ExpandPath(
      'packages\{alias}\{compiler}\{platform}\{configuration}' +
      '\Component{libsuffix}.dproj', '37.0', 'Win64', 'Release'));
end;

procedure TTestsBuildMatrix.TestArtifactCacheKeyIncludesCompleteTarget;
var
  LBase: string;
begin
  LBase := TBoss4DArtifactCacheService.BuildCacheKey(
    'github.com/example/component', 'source-checksum', '37.0', 'Win32',
    'Debug');
  Assert.AreNotEqual(LBase, TBoss4DArtifactCacheService.BuildCacheKey(
    'github.com/example/other', 'source-checksum', '37.0', 'Win32',
    'Debug'));
  Assert.AreNotEqual(LBase, TBoss4DArtifactCacheService.BuildCacheKey(
    'github.com/example/component', 'source-checksum', '23.0', 'Win32',
    'Debug'));
  Assert.AreNotEqual(LBase, TBoss4DArtifactCacheService.BuildCacheKey(
    'github.com/example/component', 'source-checksum', '37.0', 'Win64',
    'Debug'));
  Assert.AreNotEqual(LBase, TBoss4DArtifactCacheService.BuildCacheKey(
    'github.com/example/component', 'source-checksum', '37.0', 'Win32',
    'Release'));
end;

procedure TTestsBuildMatrix.TestBuildSchedulerHonorsCancellation;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LCalls: Integer;
  LCompleted: Integer;
  LCancelled: Boolean;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'cancelled-build';
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Component.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      LCalls := 0;
      LCancelled := False;
      LCompleted := TBoss4DBuildScheduler.Execute(LTargets, 1,
        procedure(const ATarget: TBoss4DBuildTarget)
        begin
          Inc(LCalls);
          LCancelled := True;
        end,
        function: Boolean
        begin
          Result := LCancelled;
        end);
      Assert.AreEqual<Integer>(1, LCompleted);
      Assert.AreEqual<Integer>(1, LCalls,
        'O cancelamento deve impedir o agendamento dos targets restantes.');
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestBuildSchedulerRunsIsolatedTargetsInParallel;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LGuard: TObject;
  LCurrent: Integer;
  LMaximum: Integer;
  LCompleted: Integer;
begin
  LPackage := TBoss4DPackage.Create;
  LGuard := TObject.Create;
  try
    LPackage.Name := 'parallel-build';
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Component.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      LCurrent := 0;
      LMaximum := 0;
      LCompleted := TBoss4DBuildScheduler.Execute(LTargets, 4,
        procedure(const ATarget: TBoss4DBuildTarget)
        begin
          TMonitor.Enter(LGuard);
          try
            Inc(LCurrent);
            if LCurrent > LMaximum then
              LMaximum := LCurrent;
          finally
            TMonitor.Exit(LGuard);
          end;
          TThread.Sleep(75);
          TMonitor.Enter(LGuard);
          try
            Dec(LCurrent);
          finally
            TMonitor.Exit(LGuard);
          end;
        end);
      Assert.AreEqual<Integer>(4, LCompleted);
      Assert.IsTrue(LMaximum > 1,
        'Targets com outputs isolados devem executar concorrentemente.');
    finally
      LTargets.Free;
    end;
  finally
    LGuard.Free;
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestBuildSchedulerSerializesSharedOutputRoot;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LGuard: TObject;
  LCurrent: Integer;
  LMaximum: Integer;
begin
  LPackage := TBoss4DPackage.Create;
  LGuard := TObject.Create;
  try
    LPackage.Name := 'shared-output-build';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'First.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Second.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      LCurrent := 0;
      LMaximum := 0;
      TBoss4DBuildScheduler.Execute(LTargets, 2,
        procedure(const ATarget: TBoss4DBuildTarget)
        begin
          TMonitor.Enter(LGuard);
          try
            Inc(LCurrent);
            if LCurrent > LMaximum then
              LMaximum := LCurrent;
          finally
            TMonitor.Exit(LGuard);
          end;
          TThread.Sleep(30);
          TMonitor.Enter(LGuard);
          try
            Dec(LCurrent);
          finally
            TMonitor.Exit(LGuard);
          end;
        end);
      Assert.AreEqual<Integer>(1, LMaximum,
        'Projetos que compartilham output devem ser serializados.');
    finally
      LTargets.Free;
    end;
  finally
    LGuard.Free;
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestBuildSchedulerStopsDependentsAfterFailure;
var
  LPackage: TBoss4DPackage;
  LRuntime: TBoss4DBuildProject;
  LDesign: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LDesignCalls: Integer;
  LRaised: Boolean;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'failed-build';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LRuntime := TBoss4DBuildProject.Create;
    LRuntime.Path := 'Runtime.dproj';
    LPackage.BuildMatrix.Projects.Add(LRuntime);
    LDesign := TBoss4DBuildProject.Create;
    LDesign.Path := 'Design.dproj';
    LDesign.DependsOn.Add('Runtime.dproj');
    LPackage.BuildMatrix.Projects.Add(LDesign);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      LDesignCalls := 0;
      LRaised := False;
      try
        TBoss4DBuildScheduler.Execute(LTargets, 2,
          procedure(const ATarget: TBoss4DBuildTarget)
          begin
            if ATarget.ProjectPath.EndsWith('Runtime.dproj') then
              raise Exception.Create('runtime failed');
            Inc(LDesignCalls);
          end);
      except
        on E: EBoss4DBuildSchedulerError do
        begin
          LRaised := True;
          Assert.IsTrue(E.Message.Contains('Runtime.dproj'));
          Assert.IsTrue(E.Message.Contains('runtime failed'));
        end;
      end;
      Assert.IsTrue(LRaised);
      Assert.AreEqual<Integer>(0, LDesignCalls,
        'Consumidores nao podem executar depois da falha da dependencia.');
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestBuildGraphOrdersDependenciesBeforeConsumers;
var
  LPackage: TBoss4DPackage;
  LRuntime: TBoss4DBuildProject;
  LDesign: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'graph-component';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LDesign := TBoss4DBuildProject.Create;
    LDesign.Path := 'packages/Design.dproj';
    LDesign.Kind := 'design';
    LDesign.DependsOn.Add('packages/Runtime.dproj');
    LPackage.BuildMatrix.Projects.Add(LDesign);
    LRuntime := TBoss4DBuildProject.Create;
    LRuntime.Path := 'packages/Runtime.dproj';
    LPackage.BuildMatrix.Projects.Add(LRuntime);

    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      Assert.IsTrue(LTargets[0].ProjectPath.EndsWith('Design.dproj'),
        'A expansao lexical deve demonstrar que o grafo altera a ordem.');
      TBoss4DBuildGraph.Sort(LTargets);
      Assert.IsTrue(LTargets[0].ProjectPath.EndsWith('Runtime.dproj'));
      Assert.IsTrue(LTargets[1].ProjectPath.EndsWith('Design.dproj'));
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestBuildGraphRejectsCycles;
var
  LPackage: TBoss4DPackage;
  LProjectA: TBoss4DBuildProject;
  LProjectB: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LRaised: Boolean;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'cyclic-component';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LProjectA := TBoss4DBuildProject.Create;
    LProjectA.Path := 'A.dproj';
    LProjectA.DependsOn.Add('B.dproj');
    LPackage.BuildMatrix.Projects.Add(LProjectA);
    LProjectB := TBoss4DBuildProject.Create;
    LProjectB.Path := 'B.dproj';
    LProjectB.DependsOn.Add('A.dproj');
    LPackage.BuildMatrix.Projects.Add(LProjectB);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      LRaised := False;
      try
        TBoss4DBuildGraph.Sort(LTargets);
      except
        on E: EBoss4DBuildGraphError do
        begin
          LRaised := True;
          Assert.IsTrue(E.Message.Contains('ciclo'));
          Assert.IsTrue(E.Message.Contains('A.dproj'));
          Assert.IsTrue(E.Message.Contains('B.dproj'));
        end;
      end;
      Assert.IsTrue(LRaised, 'Ciclos devem impedir o build.');
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestBuildGraphRejectsMissingDependencyTarget;
var
  LPackage: TBoss4DPackage;
  LDesign: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LRaised: Boolean;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'missing-target';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LDesign := TBoss4DBuildProject.Create;
    LDesign.Path := 'Design.dproj';
    LDesign.DependsOn.Add('Runtime.dproj');
    LPackage.BuildMatrix.Projects.Add(LDesign);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      LRaised := False;
      try
        TBoss4DBuildGraph.Sort(LTargets);
      except
        on E: EBoss4DBuildGraphError do
        begin
          LRaised := True;
          Assert.IsTrue(E.Message.Contains('Runtime.dproj'));
          Assert.IsTrue(E.Message.Contains('37.0|Win64|Release'));
        end;
      end;
      Assert.IsTrue(LRaised,
        'Dependencias sem target compativel devem impedir o build.');
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestDeclarativeMatrixExpandsDeterministically;
var
  LPackage: TBoss4DPackage;
  LRuntime: TBoss4DBuildProject;
  LDesign: TBoss4DBuildProject;
  LSelection: TBoss4DBuildSelection;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'sample-component';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Compilers.Add('22.0');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LPackage.BuildMatrix.Configurations.Add('Debug');

    LRuntime := TBoss4DBuildProject.Create;
    LRuntime.Path := 'packages/runtime.dproj';
    LRuntime.Kind := 'runtime';
    LPackage.BuildMatrix.Projects.Add(LRuntime);

    LDesign := TBoss4DBuildProject.Create;
    LDesign.Path := 'packages/design.dproj';
    LDesign.Kind := 'design';
    LDesign.DependsOn.Add('packages/runtime.dproj');
    LPackage.BuildMatrix.Projects.Add(LDesign);

    LSelection := TBoss4DBuildSelection.All;
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage, LSelection);
    try
      Assert.AreEqual<Integer>(16, LTargets.Count);
      Assert.AreEqual(
        'sample-component|packages/design.dproj|22.0|Win32|Debug',
        LTargets[0].Identity);
      Assert.AreEqual(
        'sample-component|packages/runtime.dproj|37.0|Win64|Release',
        LTargets[15].Identity);
      Assert.AreEqual('design', LTargets[0].ProjectKind);
      Assert.AreEqual<Integer>(1, LTargets[0].DependsOn.Count);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestDefaultsChooseSingleTarget;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'defaults-component';
    LPackage.BuildMatrix.Compilers.Add('22.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LPackage.BuildMatrix.DefaultCompiler := '37.0';
    LPackage.BuildMatrix.DefaultPlatform := 'Win64';
    LPackage.BuildMatrix.DefaultConfiguration := 'Release';
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'source/component.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);

    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.Default);
    try
      Assert.AreEqual<Integer>(1, LTargets.Count);
      Assert.AreEqual('37.0', LTargets[0].Compiler);
      Assert.AreEqual('Win64', LTargets[0].Platform);
      Assert.AreEqual('Release', LTargets[0].Configuration);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestExplicitSelectionFiltersTargets;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LSelection: TBoss4DBuildSelection;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'filtered-component';
    LPackage.BuildMatrix.Compilers.Add('22.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'source/component.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);

    LSelection := TBoss4DBuildSelection.Create('37.0', 'Win64', 'Release');
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage, LSelection);
    try
      Assert.AreEqual<Integer>(1, LTargets.Count);
      Assert.AreEqual('37.0', LTargets[0].Compiler);
      Assert.AreEqual('Win64', LTargets[0].Platform);
      Assert.AreEqual('Release', LTargets[0].Configuration);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestSelectionCanExpandAxesIndependently;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LSelection: TBoss4DBuildSelection;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'mixed-selection';
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Component.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);

    LSelection := TBoss4DBuildSelection.Create('', 'Win64', 'Release',
      True, False, False);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage, LSelection);
    try
      Assert.AreEqual<Integer>(2, LTargets.Count);
      Assert.AreEqual('23.0', LTargets[0].Compiler);
      Assert.AreEqual('Win64', LTargets[0].Platform);
      Assert.AreEqual('Release', LTargets[0].Configuration);
      Assert.AreEqual('37.0', LTargets[1].Compiler);
      Assert.AreEqual('Win64', LTargets[1].Platform);
      Assert.AreEqual('Release', LTargets[1].Configuration);
      Assert.IsFalse(LSelection.AllTargets);
      Assert.IsTrue(LSelection.CompilerAll);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestLegacyManifestExpandsSingleCompatibleTarget;
var
  LPackage: TBoss4DPackage;
  LSelection: TBoss4DBuildSelection;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'legacy-component';
    LPackage.Projects.Add('source/legacy.dproj');
    LPackage.Toolchain.Compiler := '23.0';
    LPackage.Toolchain.Platform := 'Win64';

    LSelection := TBoss4DBuildSelection.Default;
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage, LSelection);
    try
      Assert.AreEqual<Integer>(1, LTargets.Count);
      Assert.AreEqual('source/legacy.dproj', LTargets[0].ProjectPath);
      Assert.AreEqual('23.0', LTargets[0].Compiler);
      Assert.AreEqual('Win64', LTargets[0].Platform);
      Assert.AreEqual('Debug', LTargets[0].Configuration);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestProjectConstraintOutsideMatrixFails;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
  LRaised: Boolean;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'invalid-project-filter';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'source/component.dproj';
    LProject.Compilers.Add('22.0');
    LPackage.BuildMatrix.Projects.Add(LProject);

    LRaised := False;
    LTargets := nil;
    try
      try
        LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
          TBoss4DBuildSelection.All);
      except
        on E: EArgumentException do
        begin
          LRaised := True;
          Assert.IsTrue(E.Message.Contains('22.0'));
          Assert.IsTrue(E.Message.Contains('source/component.dproj'));
        end;
      end;
      Assert.IsTrue(LRaised,
        'Filtros de projeto fora dos eixos globais devem ser recusados.');
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestTargetOutputPathsAreCollisionFree;
var
  LRoot: string;
  LWin32Debug: string;
  LWin64Debug: string;
  LWin32Release: string;
  LDelphi12Debug: string;
begin
  LRoot := TPath.Combine('C:\workspace', 'modules');
  LWin32Debug := TBoss4DBuildPaths.OutputDirectory(LRoot,
    'sample-component', '37.0', 'Win32', 'Debug', 'dcu');
  LWin64Debug := TBoss4DBuildPaths.OutputDirectory(LRoot,
    'sample-component', '37.0', 'Win64', 'Debug', 'dcu');
  LWin32Release := TBoss4DBuildPaths.OutputDirectory(LRoot,
    'sample-component', '37.0', 'Win32', 'Release', 'dcu');
  LDelphi12Debug := TBoss4DBuildPaths.OutputDirectory(LRoot,
    'sample-component', '23.0', 'Win32', 'Debug', 'dcu');

  Assert.AreNotEqual(LWin32Debug, LWin64Debug);
  Assert.AreNotEqual(LWin32Debug, LWin32Release);
  Assert.AreNotEqual(LWin32Debug, LDelphi12Debug);
  Assert.IsTrue(LWin32Debug.EndsWith(TPath.Combine('37.0',
    TPath.Combine('Win32', TPath.Combine('Debug', 'dcu')))));
end;

procedure TTestsBuildMatrix.TestInvalidSelectionFailsBeforeBuild;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LSelection: TBoss4DBuildSelection;
  LTargets: TBoss4DBuildTargetList;
  LRaised: Boolean;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'invalid-selection';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'source/component.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);

    LRaised := False;
    LTargets := nil;
    LSelection := TBoss4DBuildSelection.Create('37.0', 'Linux64', 'Debug');
    try
      try
        LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage, LSelection);
      except
        on E: EArgumentException do
        begin
          LRaised := True;
          Assert.IsTrue(E.Message.Contains('Linux64'));
        end;
      end;
      Assert.IsTrue(LRaised,
        'Uma selecao fora da matriz deve falhar antes do build.');
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsBuildMatrix);

end.
