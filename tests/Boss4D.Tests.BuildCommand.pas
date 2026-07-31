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
    procedure TestRejectsIDEAssetOutsidePackageRoot;
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
  var LBinDirectory := TPath.Combine(LRoot, 'bin');
  TDirectory.CreateDirectory(LBinDirectory);
  TFile.WriteAllText(TPath.Combine(LBinDirectory, 'ComponentRuntime.dll'),
    'test-dll', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(LRoot, 'ComponentHelp.chm'),
    'test-help', TEncoding.UTF8);
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
    '--explain', '--register', '--affected', '--all-installed',
    '--conflict', 'replace', '--remote-cache', 'R:\boss4d-cache'));
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
  Assert.IsTrue(LOptions.AllInstalledIDEs);
  Assert.AreEqual(TBoss4DIDEConflictPolicy.Replace,
    LOptions.ConflictPolicy);
  Assert.AreEqual('R:\boss4d-cache', LOptions.RemoteCachePath);
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
  LRuntimePath: string;
  LHelpFile: string;
  LToolPath: string;
  LTemplatePath: string;
  LRegistryKey: string;
  LRegistryValue: string;
begin
  TFile.WriteAllText(TPath.Combine(FRoot, 'Design.dproj'),
    '<Project/>', TEncoding.UTF8);
  TDirectory.CreateDirectory(TPath.Combine(FRoot, 'ide'));
  TFile.WriteAllText(TPath.Combine(FRoot, 'ide\component-tool.exe'),
    'test-tool', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(FRoot, 'ide\component-template.zip'),
    'test-template', TEncoding.UTF8);
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
    LPackage.IDEAssets.Tools.Add('ide/component-tool.exe');
    LPackage.IDEAssets.Templates.Add('ide/component-template.zip');
    var LDeclaredRegistryValue := TBoss4DIDERegistryValue.Create;
    LDeclaredRegistryValue.Key :=
      'Software\Embarcadero\BDS\{compiler}\ComponentVendor';
    LDeclaredRegistryValue.Name := 'TemplatePath';
    LDeclaredRegistryValue.Value := '{templates}';
    LPackage.IDEAssets.RegistryValues.Add(LDeclaredRegistryValue);
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
        LRuntimePath := ARegistration.RuntimePath;
        LToolPath := ARegistration.ToolPath;
        if ARegistration.HelpFiles.Count > 0 then
          LHelpFile := ARegistration.HelpFiles[0];
        if ARegistration.RegistryValues.Count > 0 then
        begin
          LRegistryKey := ARegistration.RegistryValues[0].Key;
          LRegistryValue := ARegistration.RegistryValues[0].Value;
        end;
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
      Assert.IsTrue(TFile.Exists(TPath.Combine(LRuntimePath,
        'ComponentRuntime.dll')));
      Assert.IsTrue(TFile.Exists(LHelpFile));
      Assert.IsTrue(TFile.Exists(TPath.Combine(LToolPath,
        'component-tool.exe')));
      LTemplatePath := TPath.Combine(TPath.GetDirectoryName(LToolPath),
        'templates\component-template.zip');
      Assert.IsTrue(TFile.Exists(LTemplatePath));
      Assert.AreEqual(
        'Software\Embarcadero\BDS\37.0\ComponentVendor', LRegistryKey);
      Assert.AreEqual(TPath.GetDirectoryName(LTemplatePath), LRegistryValue);
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

procedure TTestsBuildCommand.TestRejectsIDEAssetOutsidePackageRoot;
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LLock: TBoss4DLock;
  LCommand: TBoss4DBuildCommand;
  LOptions: TBoss4DBuildCommandOptions;
  LOutsideFile: string;
begin
  TFile.WriteAllText(TPath.Combine(FRoot, 'Design.dproj'),
    '<Project/>', TEncoding.UTF8);
  LOutsideFile := TPath.Combine(TPath.GetDirectoryName(FRoot),
    'outside-ide-asset.exe');
  TFile.WriteAllText(LOutsideFile, 'outside', TEncoding.UTF8);
  LPackage := TBoss4DPackage.Create;
  LLock := TBoss4DLock.Create;
  try
    LPackage.Name := 'unsafe-assets';
    LPackage.Version := '1.0.0';
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := 'Design.dproj';
    LProject.Kind := 'design';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LPackage.IDEAssets.Tools.Add('../outside-ide-asset.exe');
    LOptions := TBoss4DBuildCommandOptions.Parse(TArray<string>.Create(
      'build', '--register', '--force'));
    LCommand := TBoss4DBuildCommand.Create(
      TBuildCommandCompilerMock.Create, nil,
      procedure(const ARegistration: TBoss4DIDERegistration)
      begin
      end);
    try
      Assert.WillRaise(
        procedure
        begin
          LCommand.Execute(LPackage, LLock, FRoot, LOptions);
        end,
        EArgumentException);
    finally
      LCommand.Free;
    end;
  finally
    if TFile.Exists(LOutsideFile) then
      TFile.Delete(LOutsideFile);
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
