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
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.GUI.IDE.Presenter;

type
  TBackendMock = class(TInterfacedObject, IBoss4DIDEManagementBackend)
  public
    Fail: Boolean;
    function Profiles: TObjectList<TBoss4DIDEProfileView>;
    function Packages(const AProfileId: string):
      TObjectList<TBoss4DIDEPackageView>;
    function InstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
    function UninstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
  end;

  TViewMock = class(TInterfacedObject, IBoss4DIDEManagementView)
  public
    Profiles: TList<string>;
    Packages: TList<string>;
    Targets: TList<string>;
    Selected: string;
    Status: string;
    Error: string;
    constructor Create;
    destructor Destroy; override;
    procedure ClearProfiles;
    procedure AddProfile(const AId, AName, ACompiler,
      ARegistryBranch: string; const APackageCount: Integer);
    procedure SelectProfile(const AId: string);
    procedure ClearPackages;
    procedure AddPackage(const AName, ARootDirectory: string;
      const AInstalled: Boolean);
    procedure ClearTargets;
    procedure AddTarget(const AIdentity: string);
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
  var LBackend: IBoss4DIDEManagementBackend := TBackendMock.Create;
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
    LPresenter.PreviewInstall('horse');
    Assert.AreEqual('HorseDesign|37.0|Win32|Release',
      LViewObject.Targets[0]);
    LPresenter.PreviewUninstall('horse');
    Assert.AreEqual('HorseDesign.bpl', LViewObject.Targets[0]);
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

initialization
  TDUnitX.RegisterTestFixture(TTestsGUIIDEPresenter);

end.
