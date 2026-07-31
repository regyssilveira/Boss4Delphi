unit Boss4D.Tests.VersionHistory;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsVersionHistory = class
  private
    FDirectory: string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure CapturesAndRestoresManifestAndLock;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Services.VersionHistory;

procedure TTestsVersionHistory.Setup;
begin
  FDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d-version-history-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FDirectory);
end;

procedure TTestsVersionHistory.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TTestsVersionHistory.CapturesAndRestoresManifestAndLock;
var
  LService: TBoss4DVersionHistoryService;
  LId: string;
begin
  TFile.WriteAllText(TPath.Combine(FDirectory, 'boss.json'),
    '{"dependencies":{"example":"1.0.0"}}', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(FDirectory, 'boss-lock.json'),
    '{"lockVersion":3,"hash":"before"}', TEncoding.UTF8);
  TDirectory.CreateDirectory(TPath.Combine(FDirectory, 'modules'));
  TFile.WriteAllText(TPath.Combine(TPath.Combine(FDirectory, 'modules'),
    'state.txt'), 'before', TEncoding.UTF8);
  LService := TBoss4DVersionHistoryService.Create(FDirectory);
  try
    LId := LService.Capture('upgrade', 'example', '1.0.0', '2.0.0');
    Assert.IsTrue(TFile.Exists(TPath.Combine(TPath.Combine(
      TPath.Combine(FDirectory, '.boss4d'), 'version-history'),
      TPath.Combine(LId, 'metadata.json'))));
    TFile.WriteAllText(TPath.Combine(FDirectory, 'boss.json'),
      '{"dependencies":{"example":"2.0.0"}}', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(FDirectory, 'boss-lock.json'),
      '{"lockVersion":3,"hash":"after"}', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(TPath.Combine(FDirectory, 'modules'),
      'state.txt'), 'after', TEncoding.UTF8);
    Assert.AreEqual(LId, LService.RestoreLatest);
    Assert.IsTrue(TFile.ReadAllText(TPath.Combine(FDirectory,
      'boss.json')).Contains('"1.0.0"'));
    Assert.IsTrue(TFile.ReadAllText(TPath.Combine(FDirectory,
      'boss-lock.json')).Contains('"before"'));
    Assert.AreEqual('before', TFile.ReadAllText(TPath.Combine(
      TPath.Combine(FDirectory, 'modules'), 'state.txt')));
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsVersionHistory);

end.
