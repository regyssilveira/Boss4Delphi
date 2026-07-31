unit Boss4D.Tests.BuildCoordinator;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Services.IDEDiscovery;

type
  TCoordinatorCompilerMock = class(TInterfacedObject, IBoss4DCompiler)
  private
    FProjects: TList<string>;
    FTargets: TList<string>;
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
    property Projects: TList<string> read FProjects;
    property Targets: TList<string> read FTargets;
  end;

  TCoordinatorDiscoveryMock = class(TInterfacedObject,
    IBoss4DIDEDiscovery)
  public
    function Discover: TBoss4DIDEInstallationList;
  end;

  [TestFixture]
  TTestsBuildCoordinator = class
  private
    FRoot: string;
    procedure CreatePackage(const ARoot, AName: string;
      const ADependency: string = '');
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestBuildsChangedPackageAndTransitiveDependentsInOrder;
    [Test]
    procedure TestBuildsEveryCompatibleInstalledIDE;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Boss4D.Adapters.Json,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildCommand,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.BuildCoordinator;

constructor TCoordinatorCompilerMock.Create;
begin
  inherited Create;
  FProjects := TList<string>.Create;
  FTargets := TList<string>.Create;
end;

destructor TCoordinatorCompilerMock.Destroy;
begin
  FTargets.Free;
  FProjects.Free;
  inherited Destroy;
end;

function TCoordinatorCompilerMock.BuildSearchPath(
  const ADep: TBoss4DDependency; const APlatform: string): string;
begin
  Result := '';
end;

function TCoordinatorCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock): Boolean;
begin
  Result := Compile(AProjectPath, ADep, ARootLock, '', '', '');
end;

function TCoordinatorCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
  const APlatform, ACompilerVersion: string): Boolean;
begin
  Result := Compile(AProjectPath, ADep, ARootLock, APlatform,
    ACompilerVersion, '');
end;

function TCoordinatorCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
  const APlatform, ACompilerVersion, AConfiguration: string): Boolean;
begin
  FProjects.Add(TPath.GetFileName(AProjectPath));
  FTargets.Add(ACompilerVersion + '|' + APlatform + '|' + AConfiguration);
  Result := True;
end;

function TCoordinatorDiscoveryMock.Discover: TBoss4DIDEInstallationList;
begin
  Result := TBoss4DIDEInstallationList.Create(True);
  var LInstallation := TBoss4DIDEInstallation.Create;
  LInstallation.Compiler := '23.0';
  LInstallation.Platforms.Add('Win32');
  Result.Add(LInstallation);
  LInstallation := TBoss4DIDEInstallation.Create;
  LInstallation.Compiler := '37.0';
  LInstallation.Platforms.Add('Win64');
  Result.Add(LInstallation);
end;

procedure TTestsBuildCoordinator.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-coordinator-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRoot);
end;

procedure TTestsBuildCoordinator.TestBuildsEveryCompatibleInstalledIDE;
var
  LPackageRoot: string;
  LInventory: TBoss4DBuildInventory;
  LCompiler: TCoordinatorCompilerMock;
  LCoordinator: TBoss4DBuildCoordinator;
  LOptions: TBoss4DBuildCommandOptions;
  LPackage: TBoss4DPackage;
  LRepository: IBoss4DPackageRepository;
begin
  LPackageRoot := TPath.Combine(FRoot, 'component');
  CreatePackage(LPackageRoot, 'component');
  LRepository := TBoss4DPackageJsonRepository.Create;
  LPackage := LRepository.Load(TPath.Combine(LPackageRoot, 'boss.json'));
  try
    LPackage.BuildMatrix.Compilers.Clear;
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Clear;
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LRepository.Save(LPackage, TPath.Combine(LPackageRoot, 'boss.json'));
  finally
    LPackage.Free;
  end;
  LInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(FRoot, 'inventory.json'));
  LCompiler := TCoordinatorCompilerMock.Create;
  try
    LOptions := TBoss4DBuildCommandOptions.Parse(
      TArray<string>.Create('build', '--all-installed', '--force'));
    LOptions.RegisterTargets := False;
    LCoordinator := TBoss4DBuildCoordinator.Create(LCompiler, nil,
      LRepository, TBoss4DLockJsonRepository.Create, nil, LInventory,
      TCoordinatorDiscoveryMock.Create);
    try
      LCoordinator.Execute(LPackageRoot, LOptions);
      Assert.AreEqual<Integer>(2, LCompiler.Targets.Count);
      Assert.AreEqual<string>('23.0|Win32|Release',
        LCompiler.Targets[0]);
      Assert.AreEqual<string>('37.0|Win64|Release',
        LCompiler.Targets[1]);
    finally
      LCoordinator.Free;
    end;
  finally
    LInventory.Free;
  end;
end;

procedure TTestsBuildCoordinator.TearDown;
begin
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TTestsBuildCoordinator.CreatePackage(const ARoot, AName,
  ADependency: string);
var
  LPackage: TBoss4DPackage;
  LProject: TBoss4DBuildProject;
  LRepository: IBoss4DPackageRepository;
begin
  TDirectory.CreateDirectory(ARoot);
  TFile.WriteAllText(TPath.Combine(ARoot, AName + '.dproj'),
    '<Project/>', TEncoding.UTF8);
  LPackage := TBoss4DPackage.Create;
  try
    LPackage.Name := AName;
    LPackage.Version := '1.0.0';
    if not ADependency.IsEmpty then
      LPackage.Dependencies.Add(ADependency, '^1.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LProject := TBoss4DBuildProject.Create;
    LProject.Path := AName + '.dproj';
    LPackage.BuildMatrix.Projects.Add(LProject);
    LRepository := TBoss4DPackageJsonRepository.Create;
    LRepository.Save(LPackage, TPath.Combine(ARoot, 'boss.json'));
  finally
    LPackage.Free;
  end;
end;

procedure TTestsBuildCoordinator.
  TestBuildsChangedPackageAndTransitiveDependentsInOrder;
var
  LCoreRoot: string;
  LMiddlewareRoot: string;
  LAppRoot: string;
  LInventory: TBoss4DBuildInventory;
  LCompiler: TCoordinatorCompilerMock;
  LCoordinator: TBoss4DBuildCoordinator;
  LOptions: TBoss4DBuildCommandOptions;
  LResult: TBoss4DBuildCommandResult;
begin
  LCoreRoot := TPath.Combine(FRoot, 'core');
  LMiddlewareRoot := TPath.Combine(FRoot, 'middleware');
  LAppRoot := TPath.Combine(FRoot, 'app');
  CreatePackage(LCoreRoot, 'core');
  CreatePackage(LMiddlewareRoot, 'middleware', 'core');
  CreatePackage(LAppRoot, 'app', 'middleware');
  LInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(FRoot, 'inventory.json'));
  LCompiler := TCoordinatorCompilerMock.Create;
  try
    LInventory.RegisterPackage('core', LCoreRoot, []);
    LInventory.RegisterPackage('middleware', LMiddlewareRoot,
      TArray<string>.Create('core'));
    LInventory.RegisterPackage('app', LAppRoot,
      TArray<string>.Create('middleware'));
    LOptions := TBoss4DBuildCommandOptions.Parse(
      TArray<string>.Create('build', '--with-dependents', '--force'));
    LCoordinator := TBoss4DBuildCoordinator.Create(LCompiler, nil,
      TBoss4DPackageJsonRepository.Create,
      TBoss4DLockJsonRepository.Create, nil, LInventory);
    try
      LResult := LCoordinator.Execute(LCoreRoot, LOptions);
      Assert.AreEqual(3, LResult.Built);
      Assert.AreEqual<Integer>(3, LCompiler.Projects.Count);
      Assert.AreEqual<string>('core.dproj', LCompiler.Projects[0]);
      Assert.AreEqual<string>('middleware.dproj', LCompiler.Projects[1]);
      Assert.AreEqual<string>('app.dproj', LCompiler.Projects[2]);
    finally
      LCoordinator.Free;
    end;
  finally
    LInventory.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsBuildCoordinator);

end.
