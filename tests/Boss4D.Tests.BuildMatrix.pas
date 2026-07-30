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
    procedure TestLegacyManifestExpandsSingleCompatibleTarget;
    [Test]
    procedure TestInvalidSelectionFailsBeforeBuild;
    [Test]
    procedure TestDefaultsChooseSingleTarget;
    [Test]
    procedure TestProjectConstraintOutsideMatrixFails;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildMatrix;

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
