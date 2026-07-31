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
    procedure TestCapabilityLevelsCoverLegacyPlatformsAndCppBuilder;
    [Test]
    procedure TestMatrixExpandsSupportedCrossPlatformApplication;
    [Test]
    procedure TestMatrixRejectsUnsupportedDesignPlatform;
    [Test]
    procedure TestCppBuilderUsesNativeMSBuildOutputProperties;
    [Test]
    procedure TestCapabilityCatalogCoversEveryLegacyCompiler;
    [Test]
    procedure TestMatrixExpandsTokensInProjectsAndDependencies;
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
    [Test]
    procedure TestBuildSchedulerStartsReadyDependentWithoutLevelBarrier;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Classes,
  System.Generics.Collections,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildMatrix,
  Boss4D.Core.Services.BuildConventions,
  Boss4D.Core.Services.BuildCapabilities,
  Boss4D.Core.Services.BuildPaths,
  Boss4D.Core.Services.ArtifactCache,
  Boss4D.Core.Services.BuildGraph,
  Boss4D.Core.Services.BuildScheduler,
  Boss4D.Adapters.Compiler;

procedure TTestsBuildMatrix.TestDelphiConventionsCoverSupportedCompilers;
var
  LConvention: TBoss4DDelphiConvention;
begin
  LConvention := TBoss4DBuildConventions.ResolveCompiler('xe');
  Assert.AreEqual('8.0', LConvention.BDSVersion);
  Assert.AreEqual('150', LConvention.PackageSuffix);
  Assert.AreEqual('VER220', LConvention.CompilerSymbol);

  LConvention := TBoss4DBuildConventions.ResolveCompiler('d104');
  Assert.AreEqual('21.0', LConvention.BDSVersion);
  Assert.AreEqual('270', LConvention.PackageSuffix);
  Assert.AreEqual('VER340', LConvention.CompilerSymbol);

  LConvention := TBoss4DBuildConventions.ResolveCompiler('d10');
  Assert.AreEqual('17.0', LConvention.BDSVersion);
  Assert.AreEqual('230', LConvention.PackageSuffix);
  Assert.AreEqual('30.0', LConvention.CompilerVersion);
  Assert.AreEqual('VER300', LConvention.CompilerSymbol);

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
      TBoss4DBuildConventions.ResolveCompiler('d14');
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

procedure TTestsBuildMatrix.TestMatrixExpandsTokensInProjectsAndDependencies;
var
  LPackage: TBoss4DPackage;
  LRuntime: TBoss4DBuildProject;
  LDesign: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'tokenized';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LRuntime := TBoss4DBuildProject.Create;
    LRuntime.Path := 'packages/{alias}/Runtime{libsuffix}.dproj';
    LPackage.BuildMatrix.Projects.Add(LRuntime);
    LDesign := TBoss4DBuildProject.Create;
    LDesign.Path := 'packages/{alias}/Design{libsuffix}.dproj';
    LDesign.Kind := 'design';
    LDesign.DependsOn.Add(
      'packages/{alias}/Runtime{libsuffix}.dproj');
    LPackage.BuildMatrix.Projects.Add(LDesign);

    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      Assert.AreEqual<Integer>(2, LTargets.Count);
      Assert.AreEqual('packages/d13/Design370.dproj',
        LTargets[0].ProjectPath);
      Assert.AreEqual<Integer>(1, LTargets[0].DependsOn.Count);
      Assert.AreEqual('packages/d13/Runtime370.dproj',
        LTargets[0].DependsOn[0]);
      TBoss4DBuildGraph.Sort(LTargets);
      Assert.AreEqual('packages/d13/Runtime370.dproj',
        LTargets[0].ProjectPath);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
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

procedure TTestsBuildMatrix.TestBuildSchedulerStartsReadyDependentWithoutLevelBarrier;
var
  LFastRoot: TBoss4DBuildProject;
  LFastConsumer: TBoss4DBuildProject;
  LSlowRoot: TBoss4DBuildProject;
  LPackage: TBoss4DPackage;
  LTargets: TBoss4DBuildTargetList;
  LOrder: TList<string>;
  LGuard: TObject;
begin
  LOrder := TList<string>.Create;
  LGuard := TObject.Create;
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'ready-scheduler';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');

    LFastRoot := TBoss4DBuildProject.Create;
    LFastRoot.Path := 'FastRuntime.dproj';
    LPackage.BuildMatrix.Projects.Add(LFastRoot);
    LFastConsumer := TBoss4DBuildProject.Create;
    LFastConsumer.Path := 'FastDesign.dproj';
    LFastConsumer.DependsOn.Add('FastRuntime.dproj');
    LPackage.BuildMatrix.Projects.Add(LFastConsumer);
    LSlowRoot := TBoss4DBuildProject.Create;
    LSlowRoot.Path := 'SlowRuntime.dproj';
    LPackage.BuildMatrix.Projects.Add(LSlowRoot);

    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      TBoss4DBuildScheduler.Execute(LTargets, 2,
        procedure(const ATarget: TBoss4DBuildTarget)
        begin
          if SameText(ATarget.ProjectPath, 'SlowRuntime.dproj') then
            TThread.Sleep(300)
          else
            TThread.Sleep(20);
          TMonitor.Enter(LGuard);
          try
            LOrder.Add(ATarget.ProjectPath);
          finally
            TMonitor.Exit(LGuard);
          end;
        end);
      Assert.AreEqual<Integer>(3, LOrder.Count);
      Assert.AreEqual<string>('FastRuntime.dproj', LOrder[0]);
      Assert.AreEqual<string>('FastDesign.dproj', LOrder[1],
        'A dependency-ready target must not wait for an unrelated slow root.');
      Assert.AreEqual<string>('SlowRuntime.dproj', LOrder[2]);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
    LGuard.Free;
    LOrder.Free;
  end;
end;

procedure TTestsBuildMatrix.TestCapabilityLevelsCoverLegacyPlatformsAndCppBuilder;
var
  LCapability: TBoss4DBuildCapability;
begin
  LCapability := TBoss4DBuildCapabilities.Evaluate('17.0', 'Win32',
    'runtime', 'Runtime.dproj');
  Assert.AreEqual(TBoss4DSupportLevel.Certified, LCapability.Level);

  LCapability := TBoss4DBuildCapabilities.Evaluate('8.0', 'Win32',
    'runtime', 'Legacy.dproj');
  Assert.AreEqual(TBoss4DSupportLevel.Experimental, LCapability.Level);

  LCapability := TBoss4DBuildCapabilities.Evaluate('8.0', 'Win64',
    'runtime', 'Legacy.dproj');
  Assert.AreEqual(TBoss4DSupportLevel.Unsupported, LCapability.Level);

  LCapability := TBoss4DBuildCapabilities.Evaluate('23.0', 'Linux64',
    'application', 'Server.dproj');
  Assert.AreEqual(TBoss4DSupportLevel.Compatible, LCapability.Level);

  LCapability := TBoss4DBuildCapabilities.Evaluate('37.0', 'Win64',
    'application', 'CppApp.cbproj');
  Assert.AreEqual(TBoss4DSupportLevel.Experimental, LCapability.Level);

  LCapability := TBoss4DBuildCapabilities.Evaluate('23.0', 'Linux64',
    'design', 'Design.dproj');
  Assert.AreEqual(TBoss4DSupportLevel.Unsupported, LCapability.Level);
end;

procedure TTestsBuildMatrix.TestMatrixExpandsSupportedCrossPlatformApplication;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LTargets: TBoss4DBuildTargetList;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'linux-server';
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Platforms.Add('Linux64');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Server.dproj';
    LProject.Kind := 'application';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
      TBoss4DBuildSelection.All);
    try
      Assert.AreEqual<Integer>(1, LTargets.Count);
      Assert.AreEqual('Linux64', LTargets[0].Platform);
      Assert.AreEqual('application', LTargets[0].ProjectKind);
    finally
      LTargets.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestMatrixRejectsUnsupportedDesignPlatform;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
begin
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'invalid-design';
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Platforms.Add('Linux64');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Design.dproj';
    LProject.Kind := 'design';
    LPackage.BuildMatrix.Projects.Add(LProject);
    Assert.WillRaise(
      procedure
      begin
        var LTargets := TBoss4DBuildMatrixExpander.Expand(LPackage,
          TBoss4DBuildSelection.All);
        LTargets.Free;
      end,
      EArgumentException);
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildMatrix.TestCppBuilderUsesNativeMSBuildOutputProperties;
begin
  var LParameters :=
    TBoss4DDelphiCompilerAdapter.BuildCppOutputParameters(
      'C:\target\bin', 'C:\target\obj', 'C:\deps\include');
  Assert.IsTrue(LParameters.Contains(
    '/p:FinalOutputDir="C:\target\bin"'));
  Assert.IsTrue(LParameters.Contains(
    '/p:IntermediateOutputDir="C:\target\obj"'));
  Assert.IsTrue(LParameters.Contains(
    '/p:IncludePath="C:\deps\include;$(IncludePath)"'));
  Assert.IsTrue(LParameters.Contains(
    '/p:LibraryPath="C:\deps\include;$(LibraryPath)"'));
  Assert.IsFalse(LParameters.Contains('DCC_'));
end;

procedure TTestsBuildMatrix.TestCapabilityCatalogCoversEveryLegacyCompiler;
begin
  Assert.AreEqual<Integer>(16,
    Length(TBoss4DBuildCapabilities.SupportedCompilers));
  for var LCompiler in TBoss4DBuildCapabilities.SupportedCompilers do
    Assert.IsFalse(
      TBoss4DBuildConventions.ResolveCompiler(LCompiler).Alias.IsEmpty);
  Assert.AreEqual('xe',
    TBoss4DBuildCapabilities.SupportedCompilers[0]);
  Assert.AreEqual('d13',
    TBoss4DBuildCapabilities.SupportedCompilers[15]);
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
