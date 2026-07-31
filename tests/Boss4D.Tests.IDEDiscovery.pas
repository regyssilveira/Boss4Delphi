unit Boss4D.Tests.IDEDiscovery;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsIDEDiscovery = class
  private
    FRoot: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestDiscoversOnlyInstalledCompilerPlatforms;
    [Test]
    procedure TestPlannerKeepsOnlyPackageCompatibleTargets;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.IDEDiscovery;

type
  TDiscoveryRegistryMock = class(TInterfacedObject,
    IBoss4DRegistryService)
  private
    FPaths: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const AVersion, APath: string);
    function GetInstalledDelphiVersions: TArray<string>;
    function GetDelphiPath(const AVersion: string): string;
  end;

constructor TDiscoveryRegistryMock.Create;
begin
  inherited Create;
  FPaths := TDictionary<string, string>.Create;
end;

destructor TDiscoveryRegistryMock.Destroy;
begin
  FPaths.Free;
  inherited Destroy;
end;

procedure TDiscoveryRegistryMock.Add(const AVersion, APath: string);
begin
  FPaths.Add(AVersion, APath);
end;

function TDiscoveryRegistryMock.GetInstalledDelphiVersions: TArray<string>;
begin
  Result := FPaths.Keys.ToArray;
end;

function TDiscoveryRegistryMock.GetDelphiPath(
  const AVersion: string): string;
begin
  if not FPaths.TryGetValue(AVersion, Result) then
    Result := '';
end;

procedure TTestsIDEDiscovery.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-ide-discovery-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRoot);
end;

procedure TTestsIDEDiscovery.TearDown;
begin
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TTestsIDEDiscovery.TestDiscoversOnlyInstalledCompilerPlatforms;
var
  LRegistry: TDiscoveryRegistryMock;
  LDiscovery: IBoss4DIDEDiscovery;
  LInstallations: TBoss4DIDEInstallationList;
begin
  var LDelphi12 := TPath.Combine(FRoot, 'd12');
  var LDelphi13 := TPath.Combine(FRoot, 'd13');
  TDirectory.CreateDirectory(TPath.Combine(LDelphi12, 'bin'));
  TDirectory.CreateDirectory(TPath.Combine(LDelphi13, 'bin'));
  TFile.WriteAllText(TPath.Combine(LDelphi12, 'bin\dcc32.exe'), '');
  TFile.WriteAllText(TPath.Combine(LDelphi13, 'bin\dcc32.exe'), '');
  TFile.WriteAllText(TPath.Combine(LDelphi13, 'bin\dcc64.exe'), '');
  LRegistry := TDiscoveryRegistryMock.Create;
  LRegistry.Add('37.0', LDelphi13);
  LRegistry.Add('23.0', LDelphi12);
  LRegistry.Add('18.0', TPath.Combine(FRoot, 'missing'));
  LDiscovery := TBoss4DRegistryIDEDiscovery.Create(LRegistry);
  LInstallations := LDiscovery.Discover;
  try
    Assert.AreEqual<Integer>(2, LInstallations.Count);
    Assert.AreEqual<string>('23.0', LInstallations[0].Compiler);
    Assert.AreEqual<Integer>(1, LInstallations[0].Platforms.Count);
    Assert.AreEqual<string>('Win32', LInstallations[0].Platforms[0]);
    Assert.AreEqual<string>('37.0', LInstallations[1].Compiler);
    Assert.AreEqual<Integer>(2, LInstallations[1].Platforms.Count);
  finally
    LInstallations.Free;
  end;
end;

procedure TTestsIDEDiscovery.TestPlannerKeepsOnlyPackageCompatibleTargets;
var
  LPackage: TBoss4DPackage;
  LInstallations: TBoss4DIDEInstallationList;
  LInstallation: TBoss4DIDEInstallation;
  LSelections: TArray<TBoss4DBuildSelection>;
begin
  LPackage := TBoss4DPackage.Create;
  LInstallations := TBoss4DIDEInstallationList.Create(True);
  try
    LPackage.BuildMatrix.Compilers.Add('23.0');
    LPackage.BuildMatrix.Compilers.Add('37.0');
    LPackage.BuildMatrix.Platforms.Add('Win32');
    LPackage.BuildMatrix.Platforms.Add('Win64');
    LPackage.BuildMatrix.Configurations.Add('Release');
    LInstallation := TBoss4DIDEInstallation.Create;
    LInstallation.Compiler := '23.0';
    LInstallation.Platforms.Add('Win32');
    LInstallations.Add(LInstallation);
    LInstallation := TBoss4DIDEInstallation.Create;
    LInstallation.Compiler := '37.0';
    LInstallation.Platforms.Add('Win64');
    LInstallations.Add(LInstallation);
    LInstallation := TBoss4DIDEInstallation.Create;
    LInstallation.Compiler := '22.0';
    LInstallation.Platforms.Add('Win32');
    LInstallations.Add(LInstallation);

    LSelections := TBoss4DMultiIDEPlanner.Plan(LPackage, LInstallations);
    Assert.AreEqual<Integer>(2, Length(LSelections));
    Assert.AreEqual<string>('23.0', LSelections[0].Compiler);
    Assert.AreEqual<string>('Win32', LSelections[0].Platform);
    Assert.AreEqual<string>('37.0', LSelections[1].Compiler);
    Assert.AreEqual<string>('Win64', LSelections[1].Platform);
  finally
    LInstallations.Free;
    LPackage.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEDiscovery);

end.
