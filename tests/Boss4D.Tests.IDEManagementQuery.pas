unit Boss4D.Tests.IDEManagementQuery;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsIDEManagementQuery = class
  private
    FDirectory: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestListsProfilesAndPackagesAsDetachedViews;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDEManagementQuery;

procedure TTestsIDEManagementQuery.Setup;
begin
  FDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d_management_query_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDirectory);
end;

procedure TTestsIDEManagementQuery.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TTestsIDEManagementQuery.TestListsProfilesAndPackagesAsDetachedViews;
begin
  var LStore := TBoss4DIDEProfileStore.Create(
    TPath.Combine(FDirectory, 'profiles.json'));
  var LProfiles := TBoss4DIDEProfileService.Create(LStore,
    TPath.Combine(FDirectory, 'profiles'));
  var LInventory := TBoss4DBuildInventory.Create(
    TPath.Combine(FDirectory, 'inventory.json'));
  try
    var LProfile := LProfiles.CreateProfile('Daily IDE', 'Daily work',
      '37.0', 'C:\Delphi\bin\bds.exe');
    try
      LProfiles.AddPackage(LProfile.Id, 'Component.A');
    finally
      LProfile.Free;
    end;
    LInventory.RegisterPackage('Component.A',
      TPath.Combine(FDirectory, 'component-a'), []);
    LInventory.RegisterPackage('Component.B',
      TPath.Combine(FDirectory, 'component-b'), ['Component.A']);

    var LQuery := TBoss4DIDEManagementQuery.Create(
      LProfiles, LInventory);
    try
      var LProfileViews := LQuery.Profiles;
      try
        Assert.AreEqual<Integer>(1, LProfileViews.Count);
        Assert.AreEqual('daily-ide', LProfileViews[0].Id);
        Assert.AreEqual<Integer>(1, LProfileViews[0].PackageCount);
      finally
        LProfileViews.Free;
      end;
      var LPackageViews := LQuery.Packages('daily-ide');
      try
        Assert.AreEqual<Integer>(2, LPackageViews.Count);
        Assert.AreEqual('Component.A', LPackageViews[0].Name);
        Assert.IsTrue(LPackageViews[0].Installed);
        Assert.AreEqual('Component.B', LPackageViews[1].Name);
        Assert.IsFalse(LPackageViews[1].Installed);
        Assert.AreEqual<Integer>(1,
          Length(LPackageViews[1].Dependencies));
      finally
        LPackageViews.Free;
      end;
    finally
      LQuery.Free;
    end;
  finally
    LInventory.Free;
    LProfiles.Free;
    LStore.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsIDEManagementQuery);

end.
