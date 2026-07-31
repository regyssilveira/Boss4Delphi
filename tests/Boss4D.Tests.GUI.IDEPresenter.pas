unit Boss4D.Tests.GUI.IDEPresenter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsGUIIDEPresenter = class
  public
    [Test]
    procedure TestRefreshSelectionAndPreviewsDriveView;
    [Test]
    procedure TestBackendFailureIsReportedByView;
    [Test]
    procedure TestTimelineMapsOperationAndRecovery;
    [Test]
    procedure TestTimelineRejectsNilOperation;
    [Test]
    procedure TestProfileDashboardMapsHealthAndComparesPackages;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.Core.Services.IDEOperationResult,
  Boss4D.GUI.IDE.Timeline,
  Boss4D.GUI.IDE.Dashboard,
  Boss4D.GUI.IDE.Presenter;

type
  TBackendMock = class(TInterfacedObject, IBoss4DIDEManagementBackend)
  public
    Fail: Boolean;
    LastAction: string;
    LastConflictPolicy: TBoss4DIDEConflictPolicy;
    LastOpenPolicy: TBoss4DIDEOpenPolicy;
    function Profiles: TObjectList<TBoss4DIDEProfileView>;
    function Packages(const AProfileId: string):
      TObjectList<TBoss4DIDEPackageView>;
    function InstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
    function UninstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
    function Install(const AProfileId, APackage: string;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AIDEOpenPolicy: TBoss4DIDEOpenPolicy): Integer;
    function Uninstall(const AProfileId, APackage: string): Integer;
    function Repair(const AProfileId: string): Integer;
    function Undo: Integer;
    function History: TArray<TBoss4DGUITimelineRow>;
    function Dashboard: TArray<TBoss4DGUIProfileDashboardRow>;
    procedure Snapshot(const AProfileId, APath: string);
    function Diff(const AProfileId, APath: string): TList<string>;
    procedure RestoreSnapshot(const APath: string);
    procedure Launch(const AProfileId: string);
    procedure CreateProfile(const AName, ADescription, ACompiler,
      AExecutable: string);
    procedure CloneProfile(const ASourceId, AName: string);
    procedure RemoveProfile(const AProfileId: string);
    procedure ConfigureTarget(const AProfileId, APlatform,
      AConfiguration: string);
  end;

  TViewMock = class(TInterfacedObject, IBoss4DIDEManagementView)
  public
    Profiles: TList<string>;
    Packages: TList<string>;
    Targets: TList<string>;
    Timeline: TArray<TBoss4DGUITimelineRow>;
    DashboardRows: TArray<TBoss4DGUIProfileDashboardRow>;
    Selected: string;
    Status: string;
    Error: string;
    Platform: string;
    Configuration: string;
    constructor Create;
    destructor Destroy; override;
    procedure ClearProfiles;
    procedure AddProfile(const AId, AName, ACompiler,
      ARegistryBranch: string; const APackageCount: Integer);
    procedure SelectProfile(const AId: string);
    procedure SelectTarget(const APlatform, AConfiguration: string);
    procedure ClearPackages;
    procedure AddPackage(const AName, ARootDirectory: string;
      const AInstalled: Boolean);
    procedure ClearTargets;
    procedure AddTarget(const AIdentity: string);
    procedure ShowHistory(
      const ARows: TArray<TBoss4DGUITimelineRow>);
    procedure ShowDashboard(
      const ARows: TArray<TBoss4DGUIProfileDashboardRow>);
    procedure ShowIDEStatus(const AMessage: string);
    procedure ShowIDEError(const AMessage: string);
  end;

function TBackendMock.Profiles: TObjectList<TBoss4DIDEProfileView>;
begin
  if Fail then
    raise Exception.Create('backend unavailable');
  Result := TObjectList<TBoss4DIDEProfileView>.Create(True);
  var LProfile := TBoss4DIDEProfileView.Create;
  LProfile.Id := 'daily';
  LProfile.Name := 'Daily';
  LProfile.Compiler := '37.0';
  LProfile.RegistryBranch := 'Boss4D-daily';
  LProfile.DefaultPlatform := 'Win32';
  LProfile.DefaultConfiguration := 'Release';
  LProfile.PackageCount := 1;
  Result.Add(LProfile);
end;

function TBackendMock.Packages(
  const AProfileId: string): TObjectList<TBoss4DIDEPackageView>;
begin
  Result := TObjectList<TBoss4DIDEPackageView>.Create(True);
  var LPackage := TBoss4DIDEPackageView.Create;
  LPackage.Name := 'horse';
  LPackage.RootDirectory := 'C:\packages\horse';
  LPackage.Installed := True;
  Result.Add(LPackage);
end;

function TBackendMock.InstallTargets(const AProfileId,
  APackage: string): TObjectList<TBoss4DIDETargetView>;
begin
  Result := TObjectList<TBoss4DIDETargetView>.Create(True);
  var LTarget := TBoss4DIDETargetView.Create;
  LTarget.Identity := 'HorseDesign|37.0|Win32|Release';
  Result.Add(LTarget);
end;

function TBackendMock.UninstallTargets(const AProfileId,
  APackage: string): TObjectList<TBoss4DIDETargetView>;
begin
  Result := TObjectList<TBoss4DIDETargetView>.Create(True);
  var LTarget := TBoss4DIDETargetView.Create;
  LTarget.Identity := 'HorseDesign.bpl';
  Result.Add(LTarget);
end;

function TBackendMock.Install(const AProfileId, APackage: string;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AIDEOpenPolicy: TBoss4DIDEOpenPolicy): Integer;
begin
  LastAction := 'install:' + AProfileId + ':' + APackage;
  LastConflictPolicy := AConflictPolicy;
  LastOpenPolicy := AIDEOpenPolicy;
  Result := 1;
end;

function TBackendMock.Uninstall(const AProfileId,
  APackage: string): Integer;
begin
  LastAction := 'uninstall:' + AProfileId + ':' + APackage;
  Result := 1;
end;

function TBackendMock.Repair(const AProfileId: string): Integer;
begin
  LastAction := 'repair:' + AProfileId;
  Result := 2;
end;

function TBackendMock.Undo: Integer;
begin
  LastAction := 'undo';
  Result := 3;
end;

function TBackendMock.History: TArray<TBoss4DGUITimelineRow>;
begin
  LastAction := 'history';
  SetLength(Result, 1);
  Result[0].Status := 'succeeded';
  Result[0].Kind := 'profile-install';
  Result[0].Profile := 'daily';
  Result[0].Target := 'horse';
end;

procedure TBackendMock.Snapshot(const AProfileId, APath: string);
begin
  LastAction := 'snapshot:' + AProfileId + ':' + APath;
end;

function TBackendMock.Diff(const AProfileId,
  APath: string): TList<string>;
begin
  LastAction := 'diff:' + AProfileId + ':' + APath;
  Result := TList<string>.Create;
  Result.Add('packages');
end;

procedure TBackendMock.RestoreSnapshot(const APath: string);
begin
  LastAction := 'restore:' + APath;
end;

procedure TBackendMock.Launch(const AProfileId: string);
begin
  LastAction := 'launch:' + AProfileId;
end;

procedure TBackendMock.CreateProfile(const AName, ADescription,
  ACompiler, AExecutable: string);
begin
  LastAction := 'create:' + AName;
end;

procedure TBackendMock.CloneProfile(const ASourceId, AName: string);
begin
  LastAction := 'clone:' + ASourceId + ':' + AName;
end;

procedure TBackendMock.RemoveProfile(const AProfileId: string);
begin
  LastAction := 'remove:' + AProfileId;
end;

procedure TBackendMock.ConfigureTarget(const AProfileId, APlatform,
  AConfiguration: string);
begin
  LastAction := 'target:' + AProfileId + ':' + APlatform + ':' +
    AConfiguration;
end;

constructor TViewMock.Create;
begin
  inherited Create;
  Profiles := TList<string>.Create;
  Packages := TList<string>.Create;
  Targets := TList<string>.Create;
end;

destructor TViewMock.Destroy;
begin
  Targets.Free;
  Packages.Free;
  Profiles.Free;
  inherited Destroy;
end;

procedure TViewMock.ClearProfiles;
begin
  Profiles.Clear;
end;

procedure TViewMock.AddProfile(const AId, AName, ACompiler,
  ARegistryBranch: string; const APackageCount: Integer);
begin
  Profiles.Add(AId);
end;

procedure TViewMock.SelectProfile(const AId: string);
begin
  Selected := AId;
end;

procedure TViewMock.SelectTarget(const APlatform,
  AConfiguration: string);
begin
  Platform := APlatform;
  Configuration := AConfiguration;
end;

procedure TViewMock.ClearPackages;
begin
  Packages.Clear;
end;

procedure TViewMock.AddPackage(const AName, ARootDirectory: string;
  const AInstalled: Boolean);
begin
  Packages.Add(AName);
end;

procedure TViewMock.ClearTargets;
begin
  Targets.Clear;
end;

procedure TViewMock.AddTarget(const AIdentity: string);
begin
  Targets.Add(AIdentity);
end;

function TBackendMock.Dashboard:
  TArray<TBoss4DGUIProfileDashboardRow>;
begin
  LastAction := 'dashboard';
  SetLength(Result, 1);
  Result[0].Id := 'daily';
  Result[0].Name := 'Daily';
  Result[0].Compiler := '37.0';
  Result[0].Packages := TArray<string>.Create('horse');
end;

procedure TViewMock.ShowHistory(
  const ARows: TArray<TBoss4DGUITimelineRow>);
begin
  Timeline := Copy(ARows);
end;

procedure TViewMock.ShowDashboard(
  const ARows: TArray<TBoss4DGUIProfileDashboardRow>);
begin
  DashboardRows := Copy(ARows);
end;

procedure TViewMock.ShowIDEStatus(const AMessage: string);
begin
  Status := AMessage;
end;

procedure TViewMock.ShowIDEError(const AMessage: string);
begin
  Error := AMessage;
end;

procedure TTestsGUIIDEPresenter.TestRefreshSelectionAndPreviewsDriveView;
begin
  var LBackendObject := TBackendMock.Create;
  var LBackend: IBoss4DIDEManagementBackend := LBackendObject;
  var LViewObject := TViewMock.Create;
  var LView: IBoss4DIDEManagementView := LViewObject;
  var LPresenter := TBoss4DIDEManagementPresenter.Create(
    LBackend, LView);
  try
    LPresenter.Refresh;
    Assert.AreEqual('daily', LPresenter.SelectedProfile);
    Assert.AreEqual('daily', LViewObject.Selected);
    Assert.AreEqual<Integer>(1, LViewObject.Profiles.Count);
    Assert.AreEqual<Integer>(1, LViewObject.Packages.Count);
    Assert.AreEqual('Win32', LViewObject.Platform);
    Assert.AreEqual('Release', LViewObject.Configuration);
    LPresenter.PreviewInstall('horse');
    Assert.AreEqual('HorseDesign|37.0|Win32|Release',
      LViewObject.Targets[0]);
    LPresenter.PreviewUninstall('horse');
    Assert.AreEqual('HorseDesign.bpl', LViewObject.Targets[0]);
    LPresenter.Install('horse', TBoss4DIDEConflictPolicy.Replace,
      TBoss4DIDEOpenPolicy.Defer);
    Assert.AreEqual('install:daily:horse', LBackendObject.LastAction);
    Assert.AreEqual(TBoss4DIDEConflictPolicy.Replace,
      LBackendObject.LastConflictPolicy);
    Assert.AreEqual(TBoss4DIDEOpenPolicy.Defer,
      LBackendObject.LastOpenPolicy);
    LPresenter.Uninstall('horse');
    Assert.AreEqual('uninstall:daily:horse', LBackendObject.LastAction);
    LPresenter.Repair;
    Assert.AreEqual('repair:daily', LBackendObject.LastAction);
    LPresenter.Undo;
    Assert.AreEqual('undo', LBackendObject.LastAction);
    Assert.IsTrue(LViewObject.Status.Contains('3'));
    LPresenter.History;
    Assert.AreEqual('history', LBackendObject.LastAction);
    Assert.AreEqual<Integer>(1, Length(LViewObject.Timeline));
    Assert.AreEqual('profile-install', LViewObject.Timeline[0].Kind);
    LPresenter.Dashboard;
    Assert.AreEqual('dashboard', LBackendObject.LastAction);
    Assert.AreEqual<Integer>(1, Length(LViewObject.DashboardRows));
    Assert.AreEqual('Daily', LViewObject.DashboardRows[0].Name);
    LPresenter.Snapshot('daily.json');
    Assert.AreEqual('snapshot:daily:daily.json',
      LBackendObject.LastAction);
    LPresenter.Diff('daily.json');
    Assert.AreEqual('diff:daily:daily.json', LBackendObject.LastAction);
    Assert.AreEqual('packages', LViewObject.Targets[0]);
    LPresenter.RestoreSnapshot('daily.json');
    Assert.AreEqual('restore:daily.json', LBackendObject.LastAction);
    LPresenter.Launch;
    Assert.AreEqual('launch:daily', LBackendObject.LastAction);
    LPresenter.CloneProfile('Review');
    Assert.AreEqual('clone:daily:Review', LBackendObject.LastAction);
    LPresenter.CreateProfile('Clean', '', '37.0', '');
    Assert.AreEqual('create:Clean', LBackendObject.LastAction);
    LPresenter.RemoveProfile;
    Assert.AreEqual('remove:daily', LBackendObject.LastAction);
    LPresenter.ConfigureTarget('Win64', 'Debug');
    Assert.AreEqual('target:daily:Win64:Debug',
      LBackendObject.LastAction);
  finally
    LPresenter.Free;
  end;
end;

procedure TTestsGUIIDEPresenter.TestBackendFailureIsReportedByView;
begin
  var LBackendObject := TBackendMock.Create;
  LBackendObject.Fail := True;
  var LBackend: IBoss4DIDEManagementBackend := LBackendObject;
  var LViewObject := TViewMock.Create;
  var LView: IBoss4DIDEManagementView := LViewObject;
  var LPresenter := TBoss4DIDEManagementPresenter.Create(
    LBackend, LView);
  try
    LPresenter.Refresh;
    Assert.AreEqual('backend unavailable', LViewObject.Error);
  finally
    LPresenter.Free;
  end;
end;

procedure TTestsGUIIDEPresenter.TestTimelineMapsOperationAndRecovery;
begin
  var LOperation := TBoss4DIDEOperationResult.New(
    'profile-install', 'daily', 'horse');
  try
    LOperation.Status := TBoss4DIDEOperationStatus.Succeeded;
    LOperation.CompletedAt := '2026-07-31T12:01:00';
    LOperation.UndoSnapshot := 'before.json';
    LOperation.CompletedActions.Add('package registered');
    LOperation.CompletedActions.Add('library path updated');
    var LRow := TBoss4DGUITimeline.FromOperation(LOperation);
    Assert.AreEqual('succeeded', LRow.Status);
    Assert.AreEqual('profile-install', LRow.Kind);
    Assert.AreEqual('daily', LRow.Profile);
    Assert.AreEqual('horse', LRow.Target);
    Assert.AreEqual('package registered, library path updated',
      LRow.Actions);
    Assert.IsTrue(LRow.CanUndo);
    Assert.IsTrue(LRow.Detail.Contains('Desfazer: disponivel'));
  finally
    LOperation.Free;
  end;
end;

procedure TTestsGUIIDEPresenter.TestTimelineRejectsNilOperation;
begin
  Assert.WillRaise(
    procedure
    begin
      TBoss4DGUITimeline.FromOperation(nil);
    end,
    EArgumentNilException);
end;

procedure TTestsGUIIDEPresenter.TestProfileDashboardMapsHealthAndComparesPackages;
begin
  var LProfile := TBoss4DIDEProfileView.Create;
  var LPackages := TObjectList<TBoss4DIDEPackageView>.Create(True);
  try
    LProfile.Id := 'daily';
    LProfile.Name := 'Daily';
    LProfile.Compiler := '37.0';
    LProfile.RegistryBranch := 'Boss4D-daily';
    LProfile.DefaultPlatform := 'Win64';
    LProfile.DefaultConfiguration := 'Release';
    for var LName in TArray<string>.Create('horse', 'dext') do
    begin
      var LPackage := TBoss4DIDEPackageView.Create;
      LPackage.Name := LName;
      LPackage.Installed := True;
      LPackages.Add(LPackage);
    end;
    var LDaily := TBoss4DGUIProfileDashboard.BuildRow(
      LProfile, LPackages, TArray<string>.Create('Known Packages'));
    Assert.AreEqual('Com drift', LDaily.State);
    Assert.AreEqual<Integer>(2, Length(LDaily.Packages));

    var LReview := LDaily;
    LReview.Name := 'Review';
    LReview.Packages := TArray<string>.Create('horse', 'jwt');
    LReview.Drift := nil;
    Assert.AreEqual('Saudavel', LReview.State);
    var LComparison := TBoss4DGUIProfileDashboard.Compare(
      LDaily, LReview);
    Assert.AreEqual('dext', LComparison.OnlyLeft[0]);
    Assert.AreEqual('horse', LComparison.Shared[0]);
    Assert.AreEqual('jwt', LComparison.OnlyRight[0]);
    Assert.IsTrue(LComparison.Summary.Contains('Compartilhados'));
  finally
    LPackages.Free;
    LProfile.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsGUIIDEPresenter);

end.
