unit Boss4D.Tests.LegacyIDE;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DLegacyIDETests = class
  public
    [Test] procedure MetadataIsStable;
    [Test] procedure CommandQuotesExecutable;
  end;

implementation

uses
  Boss4D.IDE.Legacy.Metadata;

procedure TBoss4DLegacyIDETests.MetadataIsStable;
begin
  Assert.AreEqual('Boss4D.Legacy.IDEWizard', BOSS4D_LEGACY_WIZARD_ID);
  Assert.IsTrue(BOSS4D_LEGACY_WIZARD_NAME <> '');
end;

procedure TBoss4DLegacyIDETests.CommandQuotesExecutable;
begin
  Assert.AreEqual('"C:\My Project\boss4d.exe" install',
    Boss4DLegacyCommand('boss4d.exe', 'C:\My Project'));
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DLegacyIDETests);

end.
