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
  end;

implementation

uses
  System.SysUtils, Boss4D.Core.Services.RegistryPortal;

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
    Assert.IsFalse(LHtml.Contains('<script>'));
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
        LService.Generate('{"schemaVersion":2,"packages":[]}');
      end, EArgumentException);
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DRegistryPortalTests);

end.
