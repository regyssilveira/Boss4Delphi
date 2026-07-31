unit Boss4D.Tests.ComponentRemoval;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsComponentRemoval = class
  public
    [Test]
    procedure TestRequiresExplicitCascadeForDependents;
    [Test]
    procedure TestCascadeRemovesConsumersBeforeDependencies;
    [Test]
    procedure TestFailurePersistsRecoveryWithoutChangingInventory;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.ComponentRemoval,
  Boss4D.Core.Services.IDEOperationResult;

procedure Populate(const AInventory: TBoss4DBuildInventory;
  const ARoot: string);
begin
  AInventory.RegisterPackage('core', ARoot, []);
  AInventory.RegisterPackage('middleware', ARoot,
    TArray<string>.Create('core'));
  AInventory.RegisterPackage('app', ARoot,
    TArray<string>.Create('middleware'));
end;

procedure TTestsComponentRemoval.TestRequiresExplicitCascadeForDependents;
var
  LDirectory: string;
  LInventory: TBoss4DBuildInventory;
  LService: TBoss4DComponentRemovalService;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_removal_guard_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LDirectory);
  LInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(LDirectory, 'inventory.json'));
  try
    Populate(LInventory, LDirectory);
    LService := TBoss4DComponentRemovalService.Create(LInventory,
      function(const AOwnerPackage: string): Integer
      begin
        Result := 1;
      end);
    try
      Assert.WillRaise(
        procedure
        var
          LPlan: TBoss4DComponentRemovalPlan;
        begin
          LPlan := LService.Plan('core', False);
          LPlan.Free;
        end,
        EBoss4DDependentComponents);
      Assert.IsTrue(LInventory.Contains('core'));
    finally
      LService.Free;
    end;
  finally
    LInventory.Free;
    TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestsComponentRemoval.TestCascadeRemovesConsumersBeforeDependencies;
var
  LDirectory: string;
  LInventory: TBoss4DBuildInventory;
  LService: TBoss4DComponentRemovalService;
  LPlan: TBoss4DComponentRemovalPlan;
  LCalls: TList<string>;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_removal_cascade_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LDirectory);
  LInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(LDirectory, 'inventory.json'));
  LCalls := TList<string>.Create;
  try
    Populate(LInventory, LDirectory);
    LService := TBoss4DComponentRemovalService.Create(LInventory,
      function(const AOwnerPackage: string): Integer
      begin
        LCalls.Add(AOwnerPackage);
        Result := 1;
      end);
    try
      LPlan := LService.Plan('core', True);
      try
        Assert.AreEqual<Integer>(3, LPlan.Products.Count);
        Assert.AreEqual('app', LPlan.Products[0]);
        Assert.AreEqual('middleware', LPlan.Products[1]);
        Assert.AreEqual('core', LPlan.Products[2]);
        Assert.AreEqual<Integer>(3, LService.Execute(LPlan));
      finally
        LPlan.Free;
      end;
      Assert.AreEqual('app', LCalls[0]);
      Assert.AreEqual('middleware', LCalls[1]);
      Assert.AreEqual('core', LCalls[2]);
      Assert.IsFalse(LInventory.Contains('app'));
      Assert.IsFalse(LInventory.Contains('middleware'));
      Assert.IsFalse(LInventory.Contains('core'));
    finally
      LService.Free;
    end;
  finally
    LCalls.Free;
    LInventory.Free;
    TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestsComponentRemoval.TestFailurePersistsRecoveryWithoutChangingInventory;
var
  LDirectory: string;
  LInventory: TBoss4DBuildInventory;
  LService: TBoss4DComponentRemovalService;
  LPlan: TBoss4DComponentRemovalPlan;
  LStoreObject: TBoss4DJsonIDEOperationResultStore;
  LStore: IBoss4DIDEOperationResultStore;
  LResult: TBoss4DIDEOperationResult;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_removal_result_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LDirectory);
  LInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(LDirectory, 'inventory.json'));
  LStoreObject := TBoss4DJsonIDEOperationResultStore.Create(
    TPath.Combine(LDirectory, 'results'));
  LStore := LStoreObject;
  try
    Populate(LInventory, LDirectory);
    LService := TBoss4DComponentRemovalService.Create(LInventory,
      function(const AOwnerPackage: string): Integer
      begin
        if SameText(AOwnerPackage, 'middleware') then
          raise Exception.Create('simulated uninstall failure');
        Result := 1;
      end,
      LStore, 'isolated');
    try
      LPlan := LService.Plan('core', True);
      try
        Assert.WillRaise(
          procedure
          begin
            LService.Execute(LPlan);
          end,
          Exception);
      finally
        LPlan.Free;
      end;
    finally
      LService.Free;
    end;
    Assert.IsTrue(LInventory.Contains('app'));
    Assert.IsTrue(LInventory.Contains('middleware'));
    Assert.IsTrue(LInventory.Contains('core'));
    LResult := LStoreObject.LoadLatest;
    try
      Assert.AreEqual(TBoss4DIDEOperationStatus.Failed, LResult.Status);
      Assert.AreEqual<Integer>(1, LResult.CompletedActions.Count);
      Assert.AreEqual('uninstall app', LResult.CompletedActions[0]);
      Assert.IsTrue(LResult.RecoveryInstruction.Contains('doctor'));
      Assert.AreEqual('isolated', LResult.Profile);
    finally
      LResult.Free;
    end;
  finally
    LStore := nil;
    LInventory.Free;
    TDirectory.Delete(LDirectory, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsComponentRemoval);

end.
