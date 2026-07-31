unit Boss4D.Tests.IDEProcessPolicy;

interface

uses
  DUnitX.TestFramework,
  Boss4D.Core.Services.IDEProcessPolicy;

type
  TIDEProcessProbeMock = class(TInterfacedObject, IBoss4DIDEProcessProbe)
  private
    FRunning: Boolean;
  public
    constructor Create(const ARunning: Boolean);
    function IsRunning(const AExecutableName: string): Boolean;
  end;

  [TestFixture]
  TTestsIDEProcessPolicy = class
  public
    [Test]
    procedure TestFailDeferAndForceAreExplicit;
    [Test]
    procedure TestClosedIDEAlwaysProceeds;
    [Test]
    procedure TestDeferredRegistrationDoesNotMutateIDE;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Tests.Mocks;

constructor TIDEProcessProbeMock.Create(const ARunning: Boolean);
begin
  inherited Create;
  FRunning := ARunning;
end;

function TIDEProcessProbeMock.IsRunning(
  const AExecutableName: string): Boolean;
begin
  Result := FRunning;
end;

procedure TTestsIDEProcessPolicy.TestFailDeferAndForceAreExplicit;
var
  LProbe: IBoss4DIDEProcessProbe;
begin
  LProbe := TIDEProcessProbeMock.Create(True);
  Assert.WillRaise(
    procedure
    begin
      TBoss4DIDEProcessPolicy.Evaluate(LProbe, 'bds.exe',
        TBoss4DIDEOpenPolicy.Fail);
    end,
    EBoss4DIDERunning);
  Assert.AreEqual(TBoss4DIDEOpenDecision.Deferred,
    TBoss4DIDEProcessPolicy.Evaluate(LProbe, 'bds.exe',
      TBoss4DIDEOpenPolicy.Defer));
  Assert.AreEqual(TBoss4DIDEOpenDecision.Proceed,
    TBoss4DIDEProcessPolicy.Evaluate(LProbe, 'bds.exe',
      TBoss4DIDEOpenPolicy.Force));
end;

procedure TTestsIDEProcessPolicy.TestClosedIDEAlwaysProceeds;
begin
  Assert.AreEqual(TBoss4DIDEOpenDecision.Proceed,
    TBoss4DIDEProcessPolicy.Evaluate(
      TIDEProcessProbeMock.Create(False), 'bds.exe',
      TBoss4DIDEOpenPolicy.Fail));
end;

procedure TTestsIDEProcessPolicy.TestDeferredRegistrationDoesNotMutateIDE;
var
  LDirectory: string;
  LInventoryPath: string;
  LStore: TIDERegistryStoreMock;
  LService: TBoss4DIDERegistrationService;
  LRegistration: TBoss4DIDERegistration;
  LPlan: TBoss4DIDERegistrationPlan;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_defer_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LDirectory);
  LInventoryPath := TPath.Combine(LDirectory, 'inventory.json');
  LStore := TIDERegistryStoreMock.Create;
  LService := TBoss4DIDERegistrationService.Create(LStore,
    LInventoryPath, nil, nil, 'default', 30000,
    TIDEProcessProbeMock.Create(True), 'bds.exe');
  LRegistration := TBoss4DIDERegistration.Create;
  try
    LRegistration.PackageName := 'DeferredDesign';
    LRegistration.OwnerPackage := 'DeferredProduct';
    LRegistration.Compiler := '37.0';
    LRegistration.Platform := 'Win32';
    LRegistration.BplPath := 'C:\deferred\DeferredDesign.bpl';
    LRegistration.IDEOpenPolicy := TBoss4DIDEOpenPolicy.Defer;
    LPlan := LService.PlanRegistration(LRegistration);
    try
      Assert.AreEqual(TBoss4DIDEPlanDisposition.Deferred,
        LPlan.Disposition);
      Assert.IsTrue(LPlan.Changes.Count > 0,
        'Preview adiado ainda deve mostrar as mudancas.');
    finally
      LPlan.Free;
    end;
    LService.RegisterTarget(LRegistration);
    Assert.AreEqual<Integer>(0, LStore.WriteCount);
    Assert.IsFalse(TFile.Exists(LInventoryPath));
  finally
    LRegistration.Free;
    LService.Free;
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEProcessPolicy);

end.
