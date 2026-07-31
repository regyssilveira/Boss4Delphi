unit Boss4D.Tests.GUI.CatalogPresenter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DGUICatalogPresenterTests = class
  public
    [Test] procedure ExposesLatestAndRevokedVersionSummary;
  end;

implementation

uses
  System.Generics.Collections,
  Boss4D.Core.Services.PackageIndex,
  Boss4D.GUI.Catalog.Presenter;

procedure TBoss4DGUICatalogPresenterTests.ExposesLatestAndRevokedVersionSummary;
var
  LEntries: TObjectList<TBoss4DPackageIndexEntry>;
  LPresenter: TBoss4DGUICatalogPresenter;
begin
  LEntries := TObjectList<TBoss4DPackageIndexEntry>.Create(True);
  LPresenter := TBoss4DGUICatalogPresenter.Create;
  try
    var LEntry := TBoss4DPackageIndexEntry.Create;
    LEntry.Name := 'Horse';
    LEntry.Repository := 'github.com/hashload/horse';
    var LCurrent := TBoss4DPackageVersion.Create;
    LCurrent.Version := '3.2.1';
    LEntry.Versions.Add(LCurrent);
    var LRevoked := TBoss4DPackageVersion.Create;
    LRevoked.Version := '3.2.0';
    LRevoked.Revoked := True;
    LEntry.Versions.Add(LRevoked);
    LEntry.RefreshLatest;
    LEntries.Add(LEntry);
    var LRows := LPresenter.BuildRows(LEntries);
    Assert.AreEqual<Integer>(1, Length(LRows));
    Assert.AreEqual('Horse', LRows[0].Name);
    Assert.AreEqual('3.2.1', LRows[0].Version);
    Assert.AreEqual('2 versao(oes), 1 revogada(s)',
      LRows[0].VersionSummary);
  finally
    LPresenter.Free;
    LEntries.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DGUICatalogPresenterTests);

end.
