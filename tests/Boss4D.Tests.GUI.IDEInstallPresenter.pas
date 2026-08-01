unit Boss4D.Tests.GUI.IDEInstallPresenter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsGUIIDEInstallPresenter = class
  public
    [Test]
    procedure TestBuildRequestExposesTargetsPoliciesAndChanges;
    [Test]
    procedure TestBuildRequestRejectsMissingPackage;
    [Test]
    procedure TestBuildRequestRejectsEmptyTargets;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.GUI.IDE.Install.Presenter;

function NewProfile: TBoss4DIDEProfileView;
begin
  Result := TBoss4DIDEProfileView.Create;
  Result.Id := 'daily';
  Result.Name := 'Daily';
  Result.Compiler := '37.0';
  Result.RegistryBranch := 'Boss4D-daily';
end;

function NewTargets: TObjectList<TBoss4DIDETargetView>;
begin
  Result := TObjectList<TBoss4DIDETargetView>.Create(True);
  var LRuntime := TBoss4DIDETargetView.Create;
  LRuntime.Identity := 'HorseRuntime|37.0|Win32|Release';
  Result.Add(LRuntime);
  var LDesign := TBoss4DIDETargetView.Create;
  LDesign.Identity := 'HorseDesign|37.0|Win32|Release';
  Result.Add(LDesign);
end;

procedure TTestsGUIIDEInstallPresenter.
  TestBuildRequestExposesTargetsPoliciesAndChanges;
begin
  var LProfile := NewProfile;
  var LTargets := NewTargets;
  try
    var LRequest := TBoss4DGUIIDEInstallPresenter.BuildRequest(
      LProfile, 'horse', LTargets, TBoss4DIDEConflictPolicy.Replace,
      TBoss4DIDEOpenPolicy.Defer);
    Assert.AreEqual('daily', LRequest.ProfileId);
    Assert.AreEqual('Daily', LRequest.ProfileName);
    Assert.AreEqual('Boss4D-daily', LRequest.RegistryBranch);
    Assert.AreEqual('horse', LRequest.PackageName);
    Assert.AreEqual<Integer>(2, Length(LRequest.Targets));
    Assert.AreEqual<Integer>(4, Length(LRequest.Changes));
    Assert.AreEqual('Substituir registro',
      LRequest.ConflictPolicyLabel);
    Assert.AreEqual('Adiar alteracoes de registro',
      LRequest.OpenPolicyLabel);
    Assert.IsTrue(LRequest.Summary.Contains('HorseDesign'));
    Assert.IsTrue(LRequest.Summary.Contains('snapshot transacional'));
  finally
    LTargets.Free;
    LProfile.Free;
  end;
end;

procedure TTestsGUIIDEInstallPresenter.TestBuildRequestRejectsMissingPackage;
var
  LProfile: TBoss4DIDEProfileView;
  LTargets: TObjectList<TBoss4DIDETargetView>;
begin
  LProfile := NewProfile;
  LTargets := NewTargets;
  try
    Assert.WillRaise(
      procedure
      begin
        TBoss4DGUIIDEInstallPresenter.BuildRequest(
          LProfile, '', LTargets, TBoss4DIDEConflictPolicy.Fail,
          TBoss4DIDEOpenPolicy.Fail);
      end,
      EArgumentException);
  finally
    LTargets.Free;
    LProfile.Free;
  end;
end;

procedure TTestsGUIIDEInstallPresenter.TestBuildRequestRejectsEmptyTargets;
var
  LProfile: TBoss4DIDEProfileView;
  LTargets: TObjectList<TBoss4DIDETargetView>;
begin
  LProfile := NewProfile;
  LTargets := TObjectList<TBoss4DIDETargetView>.Create(True);
  try
    Assert.WillRaise(
      procedure
      begin
        TBoss4DGUIIDEInstallPresenter.BuildRequest(
          LProfile, 'horse', LTargets, TBoss4DIDEConflictPolicy.Fail,
          TBoss4DIDEOpenPolicy.Fail);
      end,
      EArgumentException);
  finally
    LTargets.Free;
    LProfile.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsGUIIDEInstallPresenter);

end.
