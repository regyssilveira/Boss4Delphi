unit Boss4D.Tests.BuildDoctor;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsBuildDoctor = class
  private
    FRoot: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestReportsMatrixToolchainOutputUnitAndRegistryProblems;
    [Test]
    procedure TestHealthyProjectPasses;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildDoctor,
  Boss4D.Tests.Mocks;

procedure TTestsBuildDoctor.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_doctor_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRoot);
end;

procedure TTestsBuildDoctor.TearDown;
begin
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TTestsBuildDoctor.TestReportsMatrixToolchainOutputUnitAndRegistryProblems;
var
  LPackage: TBoss4DPackage;
  LProjectA: TBoss4DBuildProject;
  LProjectB: TBoss4DBuildProject;
  LMissing: TBoss4DBuildProject;
  LOutside: TBoss4DBuildProject;
  LDoctor: TBoss4DBuildDoctor;
  LResult: TBoss4DBuildDoctorResult;
begin
  TDirectory.CreateDirectory(TPath.Combine(FRoot, 'A'));
  TDirectory.CreateDirectory(TPath.Combine(FRoot, 'B'));
  TFile.WriteAllText(TPath.Combine(FRoot, 'A\Same.dproj'),
    '<Project/>', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(FRoot, 'B\Same.dproj'),
    '<Project/>', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(FRoot, 'A\First.pas'),
    'unit Shared.UnitName; interface implementation end.',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(FRoot, 'B\Second.pas'),
    'unit Shared.UnitName; interface implementation end.',
    TEncoding.UTF8);

  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'diagnostic';
    LPackage.BuildMatrix.Compilers.Add('18.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LProjectA := TBoss4DBuildProject.Create;
    LProjectA.Path := 'A/Same.dproj';
    LProjectA.DependsOn.Add('B/Same.dproj');
    LPackage.BuildMatrix.Projects.Add(LProjectA);
    LProjectB := TBoss4DBuildProject.Create;
    LProjectB.Path := 'B/Same.dproj';
    LProjectB.DependsOn.Add('A/Same.dproj');
    LPackage.BuildMatrix.Projects.Add(LProjectB);
    LMissing := TBoss4DBuildProject.Create;
    LMissing.Path := 'Missing.dproj';
    LPackage.BuildMatrix.Projects.Add(LMissing);
    LOutside := TBoss4DBuildProject.Create;
    LOutside.Path := '../Outside.dproj';
    LPackage.BuildMatrix.Projects.Add(LOutside);

    LDoctor := TBoss4DBuildDoctor.Create(TRegistryMock.Create,
      function: TArray<string>
      begin
        Result := TArray<string>.Create(
          'Component370|37.0|Win64');
      end);
    try
      LResult := LDoctor.Diagnose(LPackage, FRoot);
      try
        Assert.IsFalse(LResult.Passed);
        Assert.IsTrue(LResult.HasCode('MATRIX_GRAPH_INVALID'),
          'MATRIX_GRAPH_INVALID');
        Assert.IsTrue(LResult.HasCode('TOOLCHAIN_MISSING'),
          'TOOLCHAIN_MISSING');
        Assert.IsTrue(LResult.HasCode('PROJECT_MISSING'),
          'PROJECT_MISSING');
        Assert.IsTrue(LResult.HasCode('PROJECT_OUTSIDE_ROOT'),
          'PROJECT_OUTSIDE_ROOT');
        Assert.IsTrue(LResult.HasCode('OUTPUT_COLLISION'),
          'OUTPUT_COLLISION');
        Assert.IsTrue(LResult.HasCode('UNIT_COLLISION'),
          'UNIT_COLLISION');
        Assert.IsTrue(LResult.HasCode('IDE_REGISTRY_DRIFT'),
          'IDE_REGISTRY_DRIFT');
      finally
        LResult.Free;
      end;
    finally
      LDoctor.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildDoctor.TestHealthyProjectPasses;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LDoctor: TBoss4DBuildDoctor;
  LResult: TBoss4DBuildDoctorResult;
  LRegistry: TRegistryMock;
begin
  TDirectory.CreateDirectory(TPath.Combine(FRoot, 'packages\d13'));
  TFile.WriteAllText(TPath.Combine(FRoot,
    'packages\d13\Runtime370.dproj'),
    '<Project/>', TEncoding.UTF8);
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := 'healthy';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'packages/{alias}/Runtime{libsuffix}.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LRegistry := TRegistryMock.Create;
    LRegistry.Path37 := FRoot;
    LDoctor := TBoss4DBuildDoctor.Create(LRegistry);
    try
      LResult := LDoctor.Diagnose(LPackage, FRoot);
      try
        Assert.IsTrue(LResult.Passed);
        Assert.AreEqual<Integer>(0, LResult.Issues.Count);
      finally
        LResult.Free;
      end;
    finally
      LDoctor.Free;
    end;
  finally
    LPackage.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsBuildDoctor);

end.
