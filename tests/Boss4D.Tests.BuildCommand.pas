unit Boss4D.Tests.BuildCommand;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock;

type
  TBuildCommandCompilerMock = class(TInterfacedObject, IBoss4DCompiler)
  private
    FCalls: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function Compile(const AProjectPath: string;
      const ADep: TBoss4DDependency;
      const ARootLock: TBoss4DLock): Boolean; overload;
    function Compile(const AProjectPath: string;
      const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
      const APlatform, ACompilerVersion: string): Boolean; overload;
    function Compile(const AProjectPath: string;
      const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
      const APlatform, ACompilerVersion,
      AConfiguration: string): Boolean; overload;
    function BuildSearchPath(const ADep: TBoss4DDependency;
      const APlatform: string = ''): string;
    property Calls: TList<string> read FCalls;
  end;

  [TestFixture]
  TTestsBuildCommand = class
  private
    FRoot: string;
    FPreviousDirectory: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestParsesIndependentAxesAndExecutionFlags;
    [Test]
    procedure TestFullSelectsAndForcesEveryAxis;
    [Test]
    procedure TestExecutesSelectedTargetsAndPlansIDERegistration;
    [Test]
    procedure TestRejectsInvalidJobs;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Services.BuildPaths,
  Boss4D.Core.Services.BuildCommand,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.IDERegistration;

constructor TBuildCommandCompilerMock.Create;
begin
  inherited Create;
  FCalls := TList<string>.Create;
end;

destructor TBuildCommandCompilerMock.Destroy;
begin
  FCalls.Free;
  inherited Destroy;
end;

function TBuildCommandCompilerMock.BuildSearchPath(
  const ADep: TBoss4DDependency; const APlatform: string): string;
begin
  Result := '';
end;

function TBuildCommandCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock): Boolean;
begin
  Result := Compile(AProjectPath, ADep, ARootLock, '', '', '');
end;

function TBuildCommandCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
  const APlatform, ACompilerVersion: string): Boolean;
begin
  Result := Compile(AProjectPath, ADep, ARootLock, APlatform,
    ACompilerVersion, '');
end;

function TBuildCommandCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
  const APlatform, ACompilerVersion, AConfiguration: string): Boolean;
var
  LRoot: string;
  LBplDirectory: string;
begin
  FCalls.Add(ACompilerVersion + '|' + APlatform + '|' + AConfiguration);
  LRoot := TBoss4DBuildPaths.TargetRoot(GetModulesDir, ADep.StorageName,
    ACompilerVersion, APlatform, AConfiguration);
  LBplDirectory := TPath.Combine(LRoot, 'bpl');
  TDirectory.CreateDirectory(LBplDirectory);
  TFile.WriteAllText(TPath.Combine(LBplDirectory,
    'Component' + ACompilerVersion.Replace('.', '') + '.bpl'),
    'test-bpl', TEncoding.UTF8);
  Result := True;
end;

procedure TTestsBuildCommand.Setup;
begin
  FPreviousDirectory := TDirectory.GetCurrentDirectory;
  FRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d_build_command_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRoot);
  TDirectory.SetCurrentDirectory(FRoot);
end;

procedure TTestsBuildCommand.TearDown;
begin
  TDirectory.SetCurrentDirectory(FPreviousDirectory);
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TTestsBuildCommand.TestParsesIndependentAxesAndExecutionFlags;
var
  LOptions: TBoss4DBuildCommandOptions;
begin
  LOptions := TBoss4DBuildCommandOptions.Parse(TArray<string>.Create(
    'build', '--compiler', 'all', '--platform', 'win64',
    '--configuration', 'release', '--jobs', '4', '--force',
    '--explain', '--register', '--affected'));
  Assert.IsTrue(LOptions.Selection.CompilerAll);
  Assert.IsFalse(LOptions.Selection.PlatformAll);
  Assert.AreEqual('Win64', LOptions.Selection.Platform);
  Assert.AreEqual('Release', LOptions.Selection.Configuration);
  Assert.AreEqual(4, LOptions.Jobs);
  Assert.IsTrue(LOptions.Force);
  Assert.IsTrue(LOptions.Explain);
  Assert.IsTrue(LOptions.RegisterTargets);
  Assert.IsTrue(LOptions.Affected);
  Assert.IsTrue(LOptions.WithDependents);
end;

procedure TTestsBuildCommand.TestFullSelectsAndForcesEveryAxis;
var
  LOptions: TBoss4DBuildCommandOptions;
begin
  LOptions := TBoss4DBuildCommandOptions.Parse(
    TArray<string>.Create('build', '--full'));
  Assert.IsTrue(LOptions.Selection.AllTargets);
  Assert.IsTrue(LOptions.Force);
end;

procedure TTestsBuildCommand.TestExecutesSelectedTargetsAndPlansIDERegistration;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LLock: TBoss4DLock;
  LCompiler: TBuildCommandCompilerMock;
  LCommand: TBoss4DBuildCommand;
  LOptions: TBoss4DBuildCommandOptions;
  LResult: TBoss4DBuildCommandResult;
  LRegisteredCompiler: string;
  LRegisteredPlatform: string;
  LRegisteredBpl: string;
  LInventory: TBoss4DBuildInventory;
  LInventoryPath: string;
begin
  TFile.WriteAllText(TPath.Combine(FRoot, 'Design.dproj'),
    '<Project/>', TEncoding.UTF8);
  LPackage := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  LCompiler := TBuildCommandCompilerMock.Create;
  LInventoryPath := TPath.Combine(FRoot, 'build-inventory.json');
  LInventory := TBoss4DBuildInventory.Create(LInventoryPath);
  try
    LPackage.Name := 'component-' + TGUID.NewGuid.ToString;
    LPackage.Version := '1.0.0';
    LPackage.Dependencies.Add('runtime-base', '^1.0');
    LPackage.DevDependencies.Add('test-base', '^1.0');
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Debug');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Design.dproj';
    LProject.Kind := 'design';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LOptions := TBoss4DBuildCommandOptions.Parse(TArray<string>.Create(
      'build', '--compiler', 'all', '--platform', 'Win64',
      '--configuration', 'Release', '--jobs', '2', '--force',
      '--register'));
    LCommand := TBoss4DBuildCommand.Create(LCompiler, nil,
      procedure(const ARegistration: TBoss4DIDERegistration)
      begin
        LRegisteredCompiler := ARegistration.Compiler;
        LRegisteredPlatform := ARegistration.Platform;
        LRegisteredBpl := ARegistration.BplPath;
      end,
      LInventory);
    try
      LResult := LCommand.Execute(LPackage, LLock, FRoot, LOptions);
      Assert.AreEqual(2, LResult.Scheduled);
      Assert.AreEqual(2, LResult.Built);
      Assert.AreEqual(2, LResult.Registered);
      Assert.AreEqual<Integer>(2, LCompiler.Calls.Count);
      Assert.AreEqual('37.0', LRegisteredCompiler);
      Assert.AreEqual('Win64', LRegisteredPlatform);
      Assert.IsTrue(TFile.Exists(LRegisteredBpl));
      Assert.IsTrue(TFile.Exists(LInventoryPath));
      Assert.IsTrue(LInventory.Contains(LPackage.Name));
      Assert.AreEqual<Integer>(2,
        LInventory.GetPackage(LPackage.Name).Dependencies.Count);
    finally
      LCommand.Free;
    end;
  finally
    LInventory.Free;
    LLock.Free;
    LPackage.Free;
  end;
end;

procedure TTestsBuildCommand.TestRejectsInvalidJobs;
begin
  Assert.WillRaise(
    procedure
    begin
      TBoss4DBuildCommandOptions.Parse(
        TArray<string>.Create('build', '--jobs', '0'));
    end,
    EArgumentException);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsBuildCommand);

end.
