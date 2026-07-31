unit Boss4D.Tests.BuildInventory;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsBuildInventory = class
  private
    FDirectory: string;
    FPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestPersistsDeterministicallyAndLoads;
    [Test]
    procedure TestFindsDirectAndTransitiveDependents;
    [Test]
    procedure TestBuildOrderPlacesDependenciesBeforeConsumers;
    [Test]
    procedure TestRejectsCycles;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Services.BuildInventory;

procedure TTestsBuildInventory.Setup;
begin
  FDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d-inventory-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDirectory);
  FPath := TPath.Combine(FDirectory, 'build-inventory.json');
end;

procedure TTestsBuildInventory.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TTestsBuildInventory.TestPersistsDeterministicallyAndLoads;
var
  LInventory: TBoss4DBuildInventory;
  LReloaded: TBoss4DBuildInventory;
  LFirst: string;
begin
  LInventory := TBoss4DBuildInventory.Create(FPath);
  try
    LInventory.RegisterPackage('App', TPath.Combine(FDirectory, 'app'),
      TArray<string>.Create('Core', 'UI'));
    LInventory.RegisterPackage('Core', TPath.Combine(FDirectory, 'core'), []);
    LInventory.Save;
    LFirst := TFile.ReadAllText(FPath, TEncoding.UTF8);
    LInventory.Save;
    Assert.AreEqual<string>(LFirst,
      TFile.ReadAllText(FPath, TEncoding.UTF8));
  finally
    LInventory.Free;
  end;

  LReloaded := TBoss4DBuildInventory.Create(FPath);
  try
    LReloaded.Load;
    Assert.IsTrue(LReloaded.Contains('APP'));
    Assert.AreEqual<string>(TPath.GetFullPath(
      TPath.Combine(FDirectory, 'app')),
      LReloaded.GetPackage('app').RootDirectory);
  finally
    LReloaded.Free;
  end;
end;

procedure TTestsBuildInventory.TestFindsDirectAndTransitiveDependents;
var
  LInventory: TBoss4DBuildInventory;
  LDependents: TArray<string>;
begin
  LInventory := TBoss4DBuildInventory.Create(FPath);
  try
    LInventory.RegisterPackage('core', FDirectory, []);
    LInventory.RegisterPackage('middleware', FDirectory,
      TArray<string>.Create('core'));
    LInventory.RegisterPackage('app', FDirectory,
      TArray<string>.Create('middleware'));
    LInventory.RegisterPackage('other', FDirectory, []);

    LDependents := LInventory.DependentsOf('core', False);
    Assert.AreEqual<Integer>(1, Length(LDependents));
    Assert.AreEqual<string>('middleware', LDependents[0]);
    LDependents := LInventory.DependentsOf('core');
    Assert.AreEqual<Integer>(2, Length(LDependents));
    Assert.AreEqual<string>('app', LDependents[0]);
    Assert.AreEqual<string>('middleware', LDependents[1]);
  finally
    LInventory.Free;
  end;
end;

procedure TTestsBuildInventory.TestBuildOrderPlacesDependenciesBeforeConsumers;
var
  LInventory: TBoss4DBuildInventory;
  LOrder: TArray<string>;
begin
  LInventory := TBoss4DBuildInventory.Create(FPath);
  try
    LInventory.RegisterPackage('core', FDirectory, []);
    LInventory.RegisterPackage('middleware', FDirectory,
      TArray<string>.Create('core'));
    LInventory.RegisterPackage('app', FDirectory,
      TArray<string>.Create('middleware'));
    LOrder := LInventory.BuildOrder(
      TArray<string>.Create('app', 'middleware', 'core'));
    Assert.AreEqual<Integer>(3, Length(LOrder));
    Assert.AreEqual<string>('core', LOrder[0]);
    Assert.AreEqual<string>('middleware', LOrder[1]);
    Assert.AreEqual<string>('app', LOrder[2]);
  finally
    LInventory.Free;
  end;
end;

procedure TTestsBuildInventory.TestRejectsCycles;
var
  LInventory: TBoss4DBuildInventory;
begin
  LInventory := TBoss4DBuildInventory.Create(FPath);
  try
    LInventory.RegisterPackage('a', FDirectory,
      TArray<string>.Create('b'));
    Assert.WillRaise(
      procedure
      begin
        LInventory.RegisterPackage('b', FDirectory,
          TArray<string>.Create('a'));
      end,
      EBoss4DBuildInventoryError);
    Assert.IsFalse(LInventory.Contains('b'),
      'A failed registration must roll back the inventory mutation.');
  finally
    LInventory.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsBuildInventory);

end.
