unit Boss4D.Tests.Platform;

interface

uses
  DUnitX.TestFramework, Boss4D.Core.Ports;

type
  TProcessRunnerMock = class(TInterfacedObject, IBoss4DProcessRunner)
  private
    FCommandLine: string;
    FWorkingDirectory: string;
    FOutput: string;
    FSuccess: Boolean;
  public
    constructor Create;
    function Execute(const ACommandLine, AWorkingDirectory: string;
      out AOutput: string): Boolean;
    property CommandLine: string read FCommandLine;
    property WorkingDirectory: string read FWorkingDirectory;
    property Output: string read FOutput write FOutput;
    property Success: Boolean read FSuccess write FSuccess;
  end;

  TPlatformEnvironmentMock = class(TInterfacedObject,
    IBoss4DPlatformEnvironment)
  private
    FWritablePath: string;
  public
    function PlatformName: string;
    function HomePath: string;
    function CurrentDirectory: string;
    procedure MakeFileWritable(const APath: string);
    function SupportsWindowsRegistry: Boolean;
    function SupportsGetIt: Boolean;
    property WritablePath: string read FWritablePath;
  end;

  TFileLinkServiceMock = class(TInterfacedObject, IBoss4DFileLinkService)
  private
    FTargetPath: string;
    FLinkPath: string;
  public
    function RemoveDirectoryLink(const ALinkPath: string): Boolean;
    function CreateDirectoryLink(const ATargetPath, ALinkPath: string): Boolean;
    property TargetPath: string read FTargetPath;
    property LinkPath: string read FLinkPath;
  end;

  [TestFixture]
  TTestsPlatform = class
  public
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestInjectedProcessRunner;
    [Test]
    procedure TestInjectedEnvironment;
    [Test]
    procedure TestInjectedFileLinks;
    [Test]
    procedure TestMissingConfigurationFailsExplicitly;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Platform,
  Boss4D.Core.Domain.Env, Boss4D.Adapters.Platform.Windows;

constructor TProcessRunnerMock.Create;
begin
  inherited Create;
  FSuccess := True;
end;

function TProcessRunnerMock.Execute(const ACommandLine,
  AWorkingDirectory: string; out AOutput: string): Boolean;
begin
  FCommandLine := ACommandLine;
  FWorkingDirectory := AWorkingDirectory;
  AOutput := FOutput;
  Result := FSuccess;
end;

function TPlatformEnvironmentMock.PlatformName: string;
begin
  Result := 'test-os';
end;

function TPlatformEnvironmentMock.HomePath: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'boss4d-platform-home');
end;

function TPlatformEnvironmentMock.CurrentDirectory: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'boss4d-platform-current');
end;

procedure TPlatformEnvironmentMock.MakeFileWritable(const APath: string);
begin
  FWritablePath := APath;
end;

function TPlatformEnvironmentMock.SupportsWindowsRegistry: Boolean;
begin
  Result := False;
end;

function TPlatformEnvironmentMock.SupportsGetIt: Boolean;
begin
  Result := False;
end;

function TFileLinkServiceMock.RemoveDirectoryLink(
  const ALinkPath: string): Boolean;
begin
  FLinkPath := ALinkPath;
  Result := True;
end;

function TFileLinkServiceMock.CreateDirectoryLink(
  const ATargetPath, ALinkPath: string): Boolean;
begin
  FTargetPath := ATargetPath;
  FLinkPath := ALinkPath;
  Result := True;
end;

procedure TTestsPlatform.TearDown;
begin
  ConfigureWindowsPlatform;
end;

procedure TTestsPlatform.TestInjectedProcessRunner;
var
  LRunner: IBoss4DProcessRunner;
  LEnvironment: IBoss4DPlatformEnvironment;
  LFileLinks: IBoss4DFileLinkService;
  LRunnerMock: TProcessRunnerMock;
  LOutput: string;
begin
  LRunner := TProcessRunnerMock.Create;
  LRunnerMock := LRunner as TProcessRunnerMock;
  LRunnerMock.Output := 'captured';
  LEnvironment := TPlatformEnvironmentMock.Create;
  LFileLinks := TFileLinkServiceMock.Create;
  ConfigureBoss4DPlatform(LRunner, LEnvironment, LFileLinks);
  Assert.IsTrue(ExecuteCommandLine('git --version', 'C:\workspace', LOutput));
  Assert.AreEqual('git --version', LRunnerMock.CommandLine);
  Assert.AreEqual('C:\workspace', LRunnerMock.WorkingDirectory);
  Assert.AreEqual('captured', LOutput);
end;

procedure TTestsPlatform.TestInjectedEnvironment;
var
  LRunner: IBoss4DProcessRunner;
  LEnvironment: IBoss4DPlatformEnvironment;
  LFileLinks: IBoss4DFileLinkService;
  LEnvironmentMock: TPlatformEnvironmentMock;
begin
  LRunner := TProcessRunnerMock.Create;
  LEnvironment := TPlatformEnvironmentMock.Create;
  LEnvironmentMock := LEnvironment as TPlatformEnvironmentMock;
  LFileLinks := TFileLinkServiceMock.Create;
  ConfigureBoss4DPlatform(LRunner, LEnvironment, LFileLinks);
  Assert.AreEqual('test-os', Boss4DPlatformEnvironment.PlatformName);
  Assert.AreEqual(LEnvironmentMock.CurrentDirectory, GetCurrentDir);
  Assert.IsFalse(Boss4DPlatformEnvironment.SupportsGetIt);
  Boss4DPlatformEnvironment.MakeFileWritable('readonly.txt');
  Assert.AreEqual('readonly.txt', LEnvironmentMock.WritablePath);
end;

procedure TTestsPlatform.TestInjectedFileLinks;
var
  LRunner: IBoss4DProcessRunner;
  LEnvironment: IBoss4DPlatformEnvironment;
  LFileLinks: IBoss4DFileLinkService;
  LFileLinksMock: TFileLinkServiceMock;
begin
  LRunner := TProcessRunnerMock.Create;
  LEnvironment := TPlatformEnvironmentMock.Create;
  LFileLinks := TFileLinkServiceMock.Create;
  LFileLinksMock := LFileLinks as TFileLinkServiceMock;
  ConfigureBoss4DPlatform(LRunner, LEnvironment, LFileLinks);
  Assert.IsTrue(Boss4DFileLinkService.CreateDirectoryLink(
    'C:\target', 'C:\link'));
  Assert.AreEqual('C:\target', LFileLinksMock.TargetPath);
  Assert.AreEqual('C:\link', LFileLinksMock.LinkPath);
  Assert.IsTrue(Boss4DFileLinkService.RemoveDirectoryLink('C:\link'));
end;

procedure TTestsPlatform.TestMissingConfigurationFailsExplicitly;
begin
  ResetBoss4DPlatform;
  Assert.WillRaise(
    procedure
    begin
      Boss4DProcessRunner;
    end,
    EInvalidOpException);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsPlatform);

end.
