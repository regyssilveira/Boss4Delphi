unit Boss4D.Tests.ComponentPlan;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsComponentPlan = class
  public
    [Test]
    procedure TestPlanOrdersRuntimeBeforeDesignAndResolvesState;
    [Test]
    procedure TestStateNamesAreStable;
  end;

implementation

uses
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.ComponentPlan;

procedure TTestsComponentPlan.TestPlanOrdersRuntimeBeforeDesignAndResolvesState;
var
  LTargets: TBoss4DBuildTargetList;
  LRuntime: TBoss4DBuildTarget;
  LDesign: TBoss4DBuildTarget;
  LPlan: TBoss4DComponentPlan;
begin
  LTargets := TBoss4DBuildTargetList.Create(True);
  try
    LDesign := TBoss4DBuildTarget.Create;
    LDesign.PackageName := 'owner';
    LDesign.ComponentName := 'Design';
    LDesign.ProjectPath := 'Design.dproj';
    LDesign.Role := TBoss4DBuildProjectRole.DesignPackage;
    LDesign.IDEPackageDescription := 'Design integration';
    LDesign.PalettePage := 'Boss4D';
    LDesign.Compiler := '37.0';
    LDesign.Platform := 'Win32';
    LDesign.Configuration := 'Release';
    LDesign.DependsOn.Add('Runtime.dproj');
    LTargets.Add(LDesign);
    LRuntime := TBoss4DBuildTarget.Create;
    LRuntime.PackageName := 'owner';
    LRuntime.ComponentName := 'Runtime';
    LRuntime.ProjectPath := 'Runtime.dproj';
    LRuntime.Role := TBoss4DBuildProjectRole.RuntimePackage;
    LRuntime.Compiler := '37.0';
    LRuntime.Platform := 'Win32';
    LRuntime.Configuration := 'Release';
    LTargets.Add(LRuntime);

    LPlan := TBoss4DComponentPlanner.Plan(LTargets, 'isolated',
      function(const AIdentity: TBoss4DComponentPackageIdentity):
        TBoss4DComponentState
      begin
        if AIdentity.Role =
          TBoss4DBuildProjectRole.RuntimePackage then
          Result := TBoss4DComponentState.Installed
        else
          Result := TBoss4DComponentState.Compiled;
      end);
    try
      Assert.AreEqual<Integer>(2, LPlan.Count);
      Assert.AreEqual('Runtime.dproj', LPlan[0].ProjectPath);
      Assert.AreEqual(TBoss4DComponentState.Installed, LPlan[0].State);
      Assert.AreEqual('isolated', LPlan[0].Identity.Profile);
      Assert.AreEqual('Design.dproj', LPlan[1].ProjectPath);
      Assert.AreEqual(TBoss4DComponentState.Compiled, LPlan[1].State);
      Assert.AreEqual('Design integration',
        LPlan[1].IDEPackageDescription);
      Assert.AreEqual('Boss4D', LPlan[1].PalettePage);
      Assert.AreEqual<Integer>(1, LPlan[1].Dependencies.Count);
    finally
      LPlan.Free;
    end;
  finally
    LTargets.Free;
  end;
end;

procedure TTestsComponentPlan.TestStateNamesAreStable;
begin
  Assert.AreEqual('declared', TBoss4DComponentStates.NameOf(
    TBoss4DComponentState.Declared));
  Assert.AreEqual('compiled', TBoss4DComponentStates.NameOf(
    TBoss4DComponentState.Compiled));
  Assert.AreEqual('installed', TBoss4DComponentStates.NameOf(
    TBoss4DComponentState.Installed));
  Assert.AreEqual('divergent', TBoss4DComponentStates.NameOf(
    TBoss4DComponentState.Divergent));
  Assert.AreEqual('broken', TBoss4DComponentStates.NameOf(
    TBoss4DComponentState.Broken));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsComponentPlan);

end.
