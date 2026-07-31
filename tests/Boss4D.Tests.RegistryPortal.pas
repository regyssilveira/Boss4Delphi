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
    [Test] procedure ComposesLocalIncludesSparseAndRevocations;
    [Test] procedure RejectsReferenceOutsideRegistryRoot;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Boss4D.Core.Services.RegistryPortal;

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
      '"version":"3.1.0"}]}', TEncoding.UTF8);
    TFile.WriteAllText(TPath.Combine(LRoot, 'packages\dext.json'),
      '{"schemaVersion":2,"packages":[{"name":"Dext",' +
      '"repository":"github.com/regyssilveira/dext","versions":[' +
      '{"version":"1.0.0","sha256":"abc"}]}]}', TEncoding.UTF8);
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
      '"provenance":"horse.intoto.json"},{"version":"3.1.0",' +
      '"revoked":true}]}]}');
    Assert.IsTrue(LHtml.Contains('Protocol v2'));
    Assert.IsTrue(LHtml.Contains('3.2.1'));
    Assert.IsTrue(LHtml.Contains('SHA-256'));
    Assert.IsTrue(LHtml.Contains('signature'));
    Assert.IsTrue(LHtml.Contains('provenance'));
    Assert.IsTrue(LHtml.Contains('3.1.0 (revoked)'));
    Assert.IsTrue(LHtml.Contains('id="package-search"'));
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DRegistryPortalTests);

end.
