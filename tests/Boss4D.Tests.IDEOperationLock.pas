unit Boss4D.Tests.IDEOperationLock;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsIDEOperationLock = class
  public
    [Test]
    procedure TestSerializesSameProfileAndToolchain;
    [Test]
    procedure TestDifferentProfilesHaveIndependentLocks;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Services.IDEOperationLock;

procedure TTestsIDEOperationLock.TestSerializesSameProfileAndToolchain;
var
  LDirectory: string;
  LLock: IBoss4DIDEOperationLock;
  LFirst: IBoss4DIDEOperationLease;
  LSecond: IBoss4DIDEOperationLease;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_lock_' + TGUID.NewGuid.ToString);
  LLock := TBoss4DFileIDEOperationLock.Create(LDirectory);
  try
    LFirst := LLock.Acquire('default', '37.0', 0);
    Assert.AreEqual('default|37.0', LFirst.Key);
    Assert.WillRaise(
      procedure
      begin
        LLock.Acquire('default', '37.0', 0);
      end,
      EBoss4DIDEOperationLockTimeout);
    LFirst := nil;
    LSecond := LLock.Acquire('default', '37.0', 0);
    Assert.AreEqual('default|37.0', LSecond.Key);
    LSecond := nil;
  finally
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestsIDEOperationLock.TestDifferentProfilesHaveIndependentLocks;
var
  LDirectory: string;
  LLock: IBoss4DIDEOperationLock;
  LDefault: IBoss4DIDEOperationLease;
  LIsolated: IBoss4DIDEOperationLease;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_lock_profiles_' + TGUID.NewGuid.ToString);
  LLock := TBoss4DFileIDEOperationLock.Create(LDirectory);
  try
    LDefault := LLock.Acquire('default', '37.0', 0);
    LIsolated := LLock.Acquire('isolated', '37.0', 0);
    Assert.AreNotEqual(LDefault.Key, LIsolated.Key);
    LIsolated := nil;
    LDefault := nil;
  finally
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEOperationLock);

end.
