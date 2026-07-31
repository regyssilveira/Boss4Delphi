unit Boss4D.Tests.RegistryPortal;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DRegistryPortalTests = class
  public
    [Test] procedure GeneratesPackageCatalog;
    [Test] procedure EscapesUntrustedMetadata;
    [Test] procedure RejectsUnknownSchema;
    [Test] procedure GeneratesVersionedV2CatalogWithTrustEvidence;
    [Test] procedure ReportsVerifiedMigrationProgress;
    [Test] procedure OffersReviewedCommunitySubmission;
    [Test] procedure ComposesLocalIncludesSparseAndRevocations;
    [Test] procedure RejectsReferenceOutsideRegistryRoot;
    [Test] procedure GeneratesConsolidatedSearchIndex;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON,
  Boss4D.Core.Services.RegistryPortal;

function CountOccurrences(const AText, AValue: string): Integer;
var
  LOffset: Integer;
begin
  Result := 0;
  LOffset := 1;
  repeat
    LOffset := Pos(AValue, AText, LOffset);
    if LOffset = 0 then
      Exit;
    Inc(Result);
    Inc(LOffset, AValue.Length);
  until False;
end;

procedure TBoss4DRegistryPortalTests.ComposesLocalIncludesSparseAndRevocations;
var
  LService: TBoss4DRegistryPortalService;
  LRoot: string;
  LHtml: string;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-portal-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(TPath.Combine(LRoot, 'packages'));
  try
    TFile.WriteAllText(TPath.Combine(LRoot, 'legacy.json'),
      '{"schemaVersion":1,"includes":["index.json"],"packages":[' +
      '{"name":"Horse","repository":"github.com/hashload/horse",' +
      '"version":"3.1.0"},{"name":"BossCompat",' +
      '"repository":"github.com/regyssilveira/compat"}]}', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRoot, 'packages\dext.json'),
      '{"schemaVersion":2,"packages":[{"name":"Dext",' +
      '"publisher":"boss4d","signerFingerprint":' +
      '"1111111111111111111111111111111111111111",' +
      '"repository":"github.com/regyssilveira/dext","versions":[' +
      '{"version":"1.0.0","sha256":"abc"}]}]}', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRoot, 'publishers.json'),
      '{"schemaVersion":1,"publishers":[{"id":"boss4d",' +
      '"displayName":"Boss4D Project","repositories":[' +
      '"github.com/regyssilveira/"],"allowedSigners":[' +
      '"1111111111111111111111111111111111111111"]}]}',
      TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRoot, 'index.json'),
      '{"schemaVersion":2,"includes":["legacy.json"],' +
      '"sparse":[{"path":"packages/dext.json"}],"revocations":[' +
      '{"name":"Dext","version":"1.0.0","reason":"security"}],' +
      '"packages":[]}', TEncoding.UTF8);
    LService := TBoss4DRegistryPortalService.Create;
    try
      LHtml := LService.GenerateFromFile(
        TPath.Combine(LRoot, 'index.json'));
      Assert.IsTrue(LHtml.Contains('Horse'));
      Assert.IsTrue(LHtml.Contains('Dext'));
      Assert.IsTrue(LHtml.Contains('1.0.0 (revoked)'));
      Assert.IsTrue(LHtml.Contains(
        'authorized publisher: Boss4D Project'));
      Assert.IsTrue(LHtml.Contains(
        'registered namespace: Boss4D Project'));
      Assert.AreEqual(1,
        CountOccurrences(LHtml, '<strong>Horse</strong>'),
        'Ciclos de includes devem ser carregados uma unica vez.');
    finally
      LService.Free;
    end;
  finally
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TBoss4DRegistryPortalTests.GeneratesPackageCatalog;
var
  LService: TBoss4DRegistryPortalService;
  LHtml: string;
begin
  LService := TBoss4DRegistryPortalService.Create;
  try
    LHtml := LService.Generate('{"schemaVersion":1,"packages":[' +
      '{"name":"Horse","repository":"github.com/hashload/horse",' +
      '"version":"3.2.0","description":"Web framework"}]}');
    Assert.IsTrue(LHtml.Contains('Horse'));
    Assert.IsTrue(LHtml.Contains('Protocol v1'));
  finally
    LService.Free;
  end;
end;

procedure TBoss4DRegistryPortalTests.EscapesUntrustedMetadata;
var
  LService: TBoss4DRegistryPortalService;
  LHtml: string;
begin
  LService := TBoss4DRegistryPortalService.Create;
  try
    LHtml := LService.Generate('{"schemaVersion":1,"packages":[' +
      '{"name":"<script>alert(1)</script>",' +
      '"repository":"example.test/repo"}]}');
    Assert.IsFalse(LHtml.Contains('<script>alert(1)</script>'));
    Assert.IsTrue(LHtml.Contains('&lt;script&gt;'));
  finally
    LService.Free;
  end;
end;

procedure TBoss4DRegistryPortalTests.RejectsUnknownSchema;
var
  LService: TBoss4DRegistryPortalService;
begin
  LService := TBoss4DRegistryPortalService.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        LService.Generate('{"schemaVersion":3,"packages":[]}');
      end, EArgumentException);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DRegistryPortalTests.GeneratesConsolidatedSearchIndex;
var
  LService: TBoss4DRegistryPortalService;
  LRootDirectory: string;
  LIndex: TJSONObject;
begin
  LRootDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d-search-index-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LRootDirectory);
  try
    TFile.WriteAllText(TPath.Combine(LRootDirectory, 'publishers.json'),
      '{"schemaVersion":1,"publishers":[{"id":"boss4d",' +
      '"displayName":"Boss4D Project","repositories":[' +
      '"github.com/regyssilveira/"],"allowedSigners":[]}]}',
      TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRootDirectory, 'index.json'),
      '{"schemaVersion":2,"packages":[{"name":"Dext",' +
      '"repository":"github.com/regyssilveira/dext",' +
      '"description":"Framework","license":"Apache-2.0"}]}',
      TEncoding.UTF8);
    LService := TBoss4DRegistryPortalService.Create;
    try
      LIndex := TJSONObject.ParseJSONValue(
        LService.GenerateSearchIndexFromFile(
          TPath.Combine(LRootDirectory, 'index.json'))) as TJSONObject;
      try
        Assert.AreEqual(1, LIndex.GetValue<Integer>('schemaVersion'));
        Assert.AreEqual(1, LIndex.GetValue<Integer>('packageCount'));
        Assert.AreEqual('boss4d-registry-v2',
          LIndex.GetValue<string>('sourceProtocol'));
        var LPackages := LIndex.GetValue<TJSONArray>('packages');
        var LPackage := LPackages.Items[0] as TJSONObject;
        Assert.AreEqual('Dext', LPackage.GetValue<string>('name'));
        Assert.AreEqual('Boss4D Project',
          LPackage.GetValue<string>('publisherDisplayName'));
        Assert.AreEqual('namespace',
          LPackage.GetValue<string>('publisherTrust'));
        Assert.IsFalse(LIndex.ToJSON.Contains('_publisher'));
      finally
        LIndex.Free;
      end;
    finally
      LService.Free;
    end;
  finally
    TDirectory.Delete(LRootDirectory, True);
  end;
end;

procedure TBoss4DRegistryPortalTests.RejectsReferenceOutsideRegistryRoot;
var
  LService: TBoss4DRegistryPortalService;
  LRoot: string;
begin
  LRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-portal-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(LRoot);
  try
    TFile.WriteAllText(TPath.Combine(LRoot, 'index.json'),
      '{"schemaVersion":2,"includes":["../outside.json"],"packages":[]}',
      TEncoding.UTF8);
    LService := TBoss4DRegistryPortalService.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          LService.GenerateFromFile(TPath.Combine(LRoot, 'index.json'));
        end,
        EArgumentException);
    finally
      LService.Free;
    end;
  finally
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TBoss4DRegistryPortalTests.GeneratesVersionedV2CatalogWithTrustEvidence;
var
  LService: TBoss4DRegistryPortalService;
  LHtml: string;
begin
  LService := TBoss4DRegistryPortalService.Create;
  try
    LHtml := LService.Generate('{"schemaVersion":2,"packages":[' +
      '{"name":"Horse","repository":"github.com/hashload/horse",' +
      '"description":"Web framework","versions":[' +
      '{"version":"3.2.1","sha256":"abc","signature":"horse.asc",' +
      '"provenance":"horse.intoto.json","variants":[{"platform":"Win64",' +
      '"compiler":"37.0"}]},{"version":"3.1.0",' +
      '"revoked":true}]}]}');
    Assert.IsTrue(LHtml.Contains('Protocol v2'));
    Assert.IsTrue(LHtml.Contains('3.2.1'));
    Assert.IsTrue(LHtml.Contains('SHA-256'));
    Assert.IsTrue(LHtml.Contains('signature'));
    Assert.IsTrue(LHtml.Contains('provenance'));
    Assert.IsTrue(LHtml.Contains('3.1.0 (revoked)'));
    Assert.IsTrue(LHtml.Contains('id="package-search"'));
    Assert.IsTrue(LHtml.Contains('id="trust-filter"'));
    Assert.IsTrue(LHtml.Contains('id="platform-filter"'));
    Assert.IsTrue(LHtml.Contains('id="compiler-filter"'));
    Assert.IsTrue(LHtml.Contains('data-platform="Win64"'));
    Assert.IsTrue(LHtml.Contains('data-compiler="37.0"'));
    Assert.IsTrue(LHtml.Contains('id="visible-count"'));
    Assert.IsTrue(LHtml.Contains('@media(max-width:700px)'));
  finally
    LService.Free;
  end;
end;

procedure TBoss4DRegistryPortalTests.ReportsVerifiedMigrationProgress;
var
  LService: TBoss4DRegistryPortalService;
  LHtml: string;
begin
  LService := TBoss4DRegistryPortalService.Create;
  try
    LHtml := LService.Generate('{"schemaVersion":2,"packages":[' +
      '{"name":"Verified","repository":"github.com/demo/verified",' +
      '"_publisherTrust":"authorized","versions":[{"version":"1.0.0"}]},' +
      '{"name":"Reserved","repository":"github.com/demo/reserved",' +
      '"_publisherTrust":"namespace","version":"1.0.0"},' +
      '{"name":"Legacy","repository":"github.com/other/legacy"}]}');
    Assert.IsTrue(LHtml.Contains(
      '<strong>1</strong>verified packages'));
    Assert.IsTrue(LHtml.Contains(
      '<strong>2</strong>legacy packages'));
    Assert.IsTrue(LHtml.Contains(
      '<strong>33%</strong>verified migration'));
    Assert.IsTrue(LHtml.Contains(
      '<option value="verified">verified package</option>'));
    Assert.IsTrue(LHtml.Contains(
      '<option value="legacy">legacy package</option>'));
    Assert.IsTrue(LHtml.Contains('data-migration="verified"'));
    Assert.IsTrue(LHtml.Contains('data-migration="legacy"'));
  finally
    LService.Free;
  end;
end;

procedure TBoss4DRegistryPortalTests.OffersReviewedCommunitySubmission;
var
  LService: TBoss4DRegistryPortalService;
  LHtml: string;
begin
  LService := TBoss4DRegistryPortalService.Create;
  try
    LHtml := LService.Generate('{"schemaVersion":2,"packages":[]}');
    Assert.IsTrue(LHtml.Contains('id="community-submit"'));
    Assert.IsTrue(LHtml.Contains(
      'issues/new?template=registry-package-submission.yml'));
    Assert.IsTrue(LHtml.Contains('Submission does not publish a package'));
    Assert.IsTrue(LHtml.Contains(
      'automated checks and explicit maintainer approval'));
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DRegistryPortalTests);

end.
