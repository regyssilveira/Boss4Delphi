unit Boss4D.Tests.IDEOperationResult;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsIDEOperationResult = class
  public
    [Test]
    procedure TestPersistsFailureAndRecoveryInstruction;
    [Test]
    procedure TestPersistsSuccessfulCompletedActions;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Services.IDEOperationResult;

procedure TTestsIDEOperationResult.TestPersistsFailureAndRecoveryInstruction;
var
  LDirectory: string;
  LStore: TBoss4DJsonIDEOperationResultStore;
  LResult: TBoss4DIDEOperationResult;
  LLoaded: TBoss4DIDEOperationResult;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_result_failure_' + TGUID.NewGuid.ToString);
  LStore := TBoss4DJsonIDEOperationResultStore.Create(LDirectory);
  LResult := TBoss4DIDEOperationResult.New(
    'cascade-uninstall', 'isolated', 'core');
  try
    LResult.CompletedActions.Add('uninstall app');
    LResult.Fail('simulated failure',
      'Execute repair no perfil isolated e repita o uninstall.');
    LStore.Save(LResult);
    LLoaded := LStore.LoadLatest;
    try
      Assert.AreEqual(TBoss4DIDEOperationStatus.Failed, LLoaded.Status);
      Assert.AreEqual('simulated failure', LLoaded.ErrorMessage);
      Assert.IsTrue(LLoaded.RecoveryInstruction.Contains('repair'));
      Assert.AreEqual<Integer>(1, LLoaded.CompletedActions.Count);
      Assert.IsTrue(TFile.Exists(TPath.Combine(LDirectory,
        LResult.OperationId + '.json')));
    finally
      LLoaded.Free;
    end;
  finally
    LResult.Free;
    LStore.Free;
    TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestsIDEOperationResult.TestPersistsSuccessfulCompletedActions;
var
  LDirectory: string;
  LStore: TBoss4DJsonIDEOperationResultStore;
  LResult: TBoss4DIDEOperationResult;
  LLoaded: TBoss4DIDEOperationResult;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_result_success_' + TGUID.NewGuid.ToString);
  LStore := TBoss4DJsonIDEOperationResultStore.Create(LDirectory);
  LResult := TBoss4DIDEOperationResult.New(
    'install', 'default', 'component');
  try
    LResult.CompletedActions.Add('register ComponentDesign');
    LResult.Complete;
    LStore.Save(LResult);
    LLoaded := LStore.LoadLatest;
    try
      Assert.AreEqual(TBoss4DIDEOperationStatus.Succeeded,
        LLoaded.Status);
      Assert.AreEqual('', LLoaded.RecoveryInstruction);
      Assert.AreEqual('register ComponentDesign',
        LLoaded.CompletedActions[0]);
    finally
      LLoaded.Free;
    end;
  finally
    LResult.Free;
    LStore.Free;
    TDirectory.Delete(LDirectory, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEOperationResult);

end.
