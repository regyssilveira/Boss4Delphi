unit Boss4D.Tests.RegistryPullRequest;

interface

uses
  System.Generics.Collections, DUnitX.TestFramework,
  Boss4D.Core.Ports,
  Boss4D.Core.Services.RegistryPullRequest;

type
  TRegistryCommandRunnerMock = class(TInterfacedObject,
    IBoss4DProcessRunner)
  private
    FCommands: TList<string>;
    FFailAt: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(const ACommandLine, AWorkingDirectory: string;
      out AOutput: string): Boolean;
    property Commands: TList<string> read FCommands;
    property FailAt: Integer read FFailAt write FFailAt;
  end;

  [TestFixture]
  TTestsRegistryPullRequest = class
  private
    FDirectory: string;
    function Options: TBoss4DRegistryPullRequestOptions;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure TestStartAndSubmitUseExactFiles;
    [Test] procedure TestDirtyCheckoutIsRejected;
    [Test] procedure TestCancelRestoresBranch;
    [Test] procedure TestSubmitFailurePreservesMetadataForRetry;
    [Test] procedure TestUnsafeBranchIsRejected;
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

constructor TRegistryCommandRunnerMock.Create;
begin
  inherited;
  FCommands := TList<string>.Create;
  FFailAt := -1;
end;

destructor TRegistryCommandRunnerMock.Destroy;
begin
  FCommands.Free;
  inherited;
end;

function TRegistryCommandRunnerMock.Execute(const ACommandLine,
  AWorkingDirectory: string; out AOutput: string): Boolean;
begin
  FCommands.Add(ACommandLine);
  Result := FCommands.Count <> FFailAt;
  if ACommandLine = 'git branch --show-current' then
    AOutput := 'main'
  else if ACommandLine.StartsWith('gh pr create') then
    AOutput := 'https://github.com/example/registry/pull/7'
  else if (ACommandLine = 'git status --porcelain') and
          (FFailAt = 0) then
    AOutput := ' M registry/index-v2.json'
  else
    AOutput := '';
end;

procedure TTestsRegistryPullRequest.Setup;
begin
  FDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_registry_pr_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDirectory);
end;

procedure TTestsRegistryPullRequest.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

function TTestsRegistryPullRequest.Options:
  TBoss4DRegistryPullRequestOptions;
begin
  Result := Default(TBoss4DRegistryPullRequestOptions);
  Result.RegistryRoot := FDirectory;
  Result.PackageName := 'Horse';
  Result.Version := '3.2.1';
  Result.Branch :=
    TBoss4DRegistryPullRequestService.DefaultBranch(
      Result.PackageName, Result.Version);
  Result.PushRemote := 'origin';
  Result.BaseBranch := 'main';
  Result.PullRequestRepository := 'regyssilveira/Boss4Delphi';
  Result.PullRequestHead := Result.Branch;
end;

procedure TTestsRegistryPullRequest.TestStartAndSubmitUseExactFiles;
var
  LRunner: TRegistryCommandRunnerMock;
  LService: TBoss4DRegistryPullRequestService;
  LSession: TBoss4DRegistryPullRequestSession;
  LResult: TBoss4DRegistryPullRequestResult;
  LOptions: TBoss4DRegistryPullRequestOptions;
  LPackage, LIndex: string;
begin
  LRunner := TRegistryCommandRunnerMock.Create;
  LService := TBoss4DRegistryPullRequestService.Create(LRunner);
  try
    LOptions := Options;
    LPackage := TPath.Combine(FDirectory,
      'registry\packages\horse.json');
    LIndex := TPath.Combine(FDirectory, 'registry\index-v2.json');
    LSession := LService.Start(LOptions);
    LResult := LService.Submit(LOptions, LSession, LPackage, LIndex);
    Assert.AreEqual(LOptions.Branch, LResult.Branch);
    Assert.AreEqual('https://github.com/example/registry/pull/7',
      LResult.PullRequestUrl);
    Assert.IsTrue(LRunner.Commands[3].Contains(
      '"registry\index-v2.json"'));
    Assert.IsFalse(LRunner.Commands[3].Contains('git add .'));
    Assert.IsTrue(LRunner.Commands[5].Contains(
      'push --set-upstream "origin"'));
    Assert.IsTrue(LRunner.Commands[6].Contains(
      '--head "boss4d/package-horse-3.2.1"'));
  finally
    LService.Free;
  end;
end;

procedure TTestsRegistryPullRequest.TestDirtyCheckoutIsRejected;
var
  LRunner: TRegistryCommandRunnerMock;
  LService: TBoss4DRegistryPullRequestService;
begin
  LRunner := TRegistryCommandRunnerMock.Create;
  LRunner.FailAt := 0;
  LService := TBoss4DRegistryPullRequestService.Create(LRunner);
  try
    Assert.WillRaise(
      procedure
      begin
        LService.Start(Options);
      end,
      EBoss4DRegistryPullRequest);
  finally
    LService.Free;
  end;
end;

procedure TTestsRegistryPullRequest.TestCancelRestoresBranch;
var
  LRunner: TRegistryCommandRunnerMock;
  LService: TBoss4DRegistryPullRequestService;
  LSession: TBoss4DRegistryPullRequestSession;
  LOptions: TBoss4DRegistryPullRequestOptions;
  LPackage, LIndex: string;
begin
  LRunner := TRegistryCommandRunnerMock.Create;
  LService := TBoss4DRegistryPullRequestService.Create(LRunner);
  try
    LOptions := Options;
    LSession := LService.Start(LOptions);
    LPackage := TPath.Combine(FDirectory,
      'registry\packages\horse.json');
    LIndex := TPath.Combine(FDirectory, 'registry\index-v2.json');
    LService.Cancel(LOptions, LSession, LPackage, LIndex);
    Assert.IsTrue(LRunner.Commands.Contains(
      'git switch "main"'));
    Assert.IsTrue(LRunner.Commands.Contains(
      'git branch -D "' + LOptions.Branch + '"'));
  finally
    LService.Free;
  end;
end;

procedure TTestsRegistryPullRequest.TestSubmitFailurePreservesMetadataForRetry;
var
  LRunner: TRegistryCommandRunnerMock;
  LService: TBoss4DRegistryPullRequestService;
  LSession: TBoss4DRegistryPullRequestSession;
  LOptions: TBoss4DRegistryPullRequestOptions;
  LPackage, LIndex: string;
begin
  LRunner := TRegistryCommandRunnerMock.Create;
  LService := TBoss4DRegistryPullRequestService.Create(LRunner);
  try
    LOptions := Options;
    LPackage := TPath.Combine(FDirectory,
      'registry\packages\horse.json');
    LIndex := TPath.Combine(FDirectory, 'registry\index-v2.json');
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LPackage));
    TFile.WriteAllText(LPackage, '{}');
    TFile.WriteAllText(LIndex, '{}');
    LSession := LService.Start(LOptions);
    LRunner.FailAt := 6;
    Assert.WillRaise(
      procedure
      begin
        LService.Submit(LOptions, LSession, LPackage, LIndex);
      end,
      EBoss4DRegistryPullRequest);
    Assert.IsTrue(TFile.Exists(LPackage));
    Assert.IsTrue(TFile.Exists(LIndex));
  finally
    LService.Free;
  end;
end;

procedure TTestsRegistryPullRequest.TestUnsafeBranchIsRejected;
var
  LRunner: TRegistryCommandRunnerMock;
  LService: TBoss4DRegistryPullRequestService;
  LOptions: TBoss4DRegistryPullRequestOptions;
begin
  LRunner := TRegistryCommandRunnerMock.Create;
  LService := TBoss4DRegistryPullRequestService.Create(LRunner);
  try
    LOptions := Options;
    LOptions.Branch := 'branch & calc';
    Assert.WillRaise(
      procedure
      begin
        LService.Start(LOptions);
      end,
      EBoss4DRegistryPullRequest);
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsRegistryPullRequest);

end.
