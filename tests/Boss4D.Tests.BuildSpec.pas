unit Boss4D.Tests.BuildSpec;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsBuildSpec = class
  public
    [Test]
    procedure TestDetectsRuntimeDesignAndLocalDependency;
    [Test]
    procedure TestDetectionIsDeterministicAndPreservesLegacyProjects;
    [Test]
    procedure TestDetectionRejectsMissingProjectsAndUnsupportedCompiler;
    [Test]
    procedure TestDetectsDelphiAndCppBuilderApplications;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Services.BuildSpec;

procedure WriteProject(const ARoot, AName, ADirective,
  ARequires: string);
var
  LDirectory: string;
begin
  LDirectory := TPath.Combine(ARoot, AName);
  TDirectory.CreateDirectory(LDirectory);
  TFile.WriteAllText(TPath.Combine(LDirectory, AName + '.dproj'),
    '<Project><PropertyGroup><MainSource>' + AName +
    '.dpk</MainSource></PropertyGroup></Project>', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(LDirectory, AName + '.dpk'),
    'package ' + AName + ';' + sLineBreak +
    '{$' + ADirective + '}' + sLineBreak +
    'requires' + sLineBreak + '  ' + ARequires + ';' + sLineBreak +
    'contains' + sLineBreak + 'end.', TEncoding.UTF8);
end;

procedure TTestsBuildSpec.TestDetectsRuntimeDesignAndLocalDependency;
var
  LRoot: string;
  LPackage: TBoss4DPackage;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_spec_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LRoot);
  try
    WriteProject(LRoot, 'Runtime', 'RUNONLY', 'rtl');
    WriteProject(LRoot, 'Design', 'DESIGNONLY', 'rtl, Runtime');
    TDirectory.CreateDirectory(TPath.Combine(LRoot, 'modules\ignored'));
    TFile.WriteAllText(TPath.Combine(LRoot,
      'modules\ignored\Ignored.dproj'), '<Project/>', TEncoding.UTF8);

    LPackage := TBoss4DPackage.Create;
    try
      LPackage.Name := 'component';
      TBoss4DBuildSpecDetector.Detect(LPackage, LRoot);

      Assert.AreEqual<Integer>(5, LPackage.BuildMatrix.Compilers.Count);
      Assert.AreEqual('17.0', LPackage.BuildMatrix.Compilers[0]);
      Assert.AreEqual('37.0', LPackage.BuildMatrix.DefaultCompiler);
      Assert.AreEqual<Integer>(2, LPackage.BuildMatrix.Platforms.Count);
      Assert.AreEqual<Integer>(2, LPackage.BuildMatrix.Projects.Count);
      Assert.AreEqual('Design/Design.dproj',
        LPackage.BuildMatrix.Projects[0].Path);
      Assert.AreEqual('design', LPackage.BuildMatrix.Projects[0].Kind);
      Assert.AreEqual<Integer>(1,
        LPackage.BuildMatrix.Projects[0].DependsOn.Count);
      Assert.AreEqual('Runtime/Runtime.dproj',
        LPackage.BuildMatrix.Projects[0].DependsOn[0]);
      Assert.AreEqual('runtime', LPackage.BuildMatrix.Projects[1].Kind);
    finally
      LPackage.Free;
    end;
  finally
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TTestsBuildSpec.TestDetectionIsDeterministicAndPreservesLegacyProjects;
var
  LRoot: string;
  LPackage: TBoss4DPackage;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_spec_stable_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LRoot);
  try
    WriteProject(LRoot, 'ZRuntime', 'RUNONLY', 'rtl');
    WriteProject(LRoot, 'ADesign', 'DESIGNONLY', 'ZRuntime');
    LPackage := TBoss4DPackage.Create;
    try
      LPackage.Projects.Add('legacy.dproj');
      TBoss4DBuildSpecDetector.Detect(LPackage, LRoot, ['d13', 'd11']);
      Assert.AreEqual('legacy.dproj', LPackage.Projects[0]);
      Assert.AreEqual('22.0', LPackage.BuildMatrix.Compilers[0]);
      Assert.AreEqual('37.0', LPackage.BuildMatrix.Compilers[1]);
      Assert.AreEqual('ADesign/ADesign.dproj',
        LPackage.BuildMatrix.Projects[0].Path);
      Assert.AreEqual('ZRuntime/ZRuntime.dproj',
        LPackage.BuildMatrix.Projects[1].Path);
    finally
      LPackage.Free;
    end;
  finally
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TTestsBuildSpec.TestDetectionRejectsMissingProjectsAndUnsupportedCompiler;
var
  LRoot: string;
  LPackage: TBoss4DPackage;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_spec_invalid_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LRoot);
  LPackage := TBoss4DPackage.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        TBoss4DBuildSpecDetector.Detect(LPackage, LRoot);
      end,
      EFileNotFoundException);
    WriteProject(LRoot, 'Runtime', 'RUNONLY', 'rtl');
    Assert.WillRaise(
      procedure
      begin
        TBoss4DBuildSpecDetector.Detect(LPackage, LRoot, ['d14']);
      end,
      EArgumentException);
  finally
    LPackage.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TTestsBuildSpec.TestDetectsDelphiAndCppBuilderApplications;
var
  LRoot: string;
  LPackage: TBoss4DPackage;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_spec_apps_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LRoot);
  try
    TFile.WriteAllText(TPath.Combine(LRoot, 'Server.dproj'),
      '<Project><PropertyGroup><MainSource>Server.dpr</MainSource>' +
      '</PropertyGroup></Project>', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRoot, 'Server.dpr'),
      'program Server; begin end.', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRoot, 'Client.cbproj'),
      '<Project><PropertyGroup><ProjectType>Application</ProjectType>' +
      '</PropertyGroup></Project>', TEncoding.UTF8);
    LPackage := TBoss4DPackage.Create;
    try
      LPackage.Name := 'mixed-apps';
      TBoss4DBuildSpecDetector.Detect(LPackage, LRoot, ['d13']);
      Assert.AreEqual<Integer>(2, LPackage.BuildMatrix.Projects.Count);
      Assert.AreEqual('Client.cbproj',
        LPackage.BuildMatrix.Projects[0].Path);
      Assert.AreEqual('application',
        LPackage.BuildMatrix.Projects[0].Kind);
      Assert.AreEqual('Server.dproj',
        LPackage.BuildMatrix.Projects[1].Path);
      Assert.AreEqual('application',
        LPackage.BuildMatrix.Projects[1].Kind);
    finally
      LPackage.Free;
    end;
  finally
    TDirectory.Delete(LRoot, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsBuildSpec);

end.
