unit Boss4D.Tests.Documentation;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DDocumentationTests = class
  private
    FRoot: string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure GeneratesSearchableSiteFromXmlAndPascalDoc;
    [Test] procedure CanExcludeDependencySources;
    [Test] procedure EscapesUntrustedDocumentation;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
  Boss4D.Core.Services.Documentation;

procedure TBoss4DDocumentationTests.Setup;
begin
  FRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-doc-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRoot);
  TDirectory.CreateDirectory(TPath.Combine(FRoot, 'modules\dependency'));
  TFile.WriteAllText(TPath.Combine(FRoot, 'Sample.pas'),
    'unit Sample;' + sLineBreak +
    'interface' + sLineBreak +
    '/// <summary>Greets a user.</summary>' + sLineBreak +
    'procedure Greet;' + sLineBreak +
    '{** Stores a person. }' + sLineBreak +
    'TPerson = class' + sLineBreak +
    'end;' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(FRoot, 'modules\dependency\Dependency.pas'),
    'unit Dependency;' + sLineBreak + 'interface' + sLineBreak +
    '/// Dependency API' + sLineBreak + 'function Resolve: Boolean;' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
end;

procedure TBoss4DDocumentationTests.TearDown;
begin
  if TDirectory.Exists(FRoot) then
    TDirectory.Delete(FRoot, True);
end;

procedure TBoss4DDocumentationTests.GeneratesSearchableSiteFromXmlAndPascalDoc;
var
  LService: TBoss4DDocumentationService;
  LResult: TBoss4DDocumentationResult;
  LOutput: string;
  LIndex: TJSONObject;
begin
  LOutput := TPath.Combine(FRoot, 'docs-api');
  LService := TBoss4DDocumentationService.Create;
  try
    LResult := LService.Generate(FRoot, LOutput, True);
    Assert.AreEqual(2, LResult.Files);
    Assert.AreEqual(3, LResult.Symbols);
    var LHtml := TFile.ReadAllText(TPath.Combine(LOutput, 'index.html'));
    Assert.IsTrue(LHtml.Contains('id="api-search"'));
    Assert.IsTrue(LHtml.Contains('Greet'));
    Assert.IsTrue(LHtml.Contains('TPerson'));
    Assert.IsTrue(LHtml.Contains('Resolve'));
    LIndex := TJSONObject.ParseJSONValue(TFile.ReadAllText(
      TPath.Combine(LOutput, 'search-index.json'))) as TJSONObject;
    try
      Assert.AreEqual(3, LIndex.GetValue<Integer>('symbolCount'));
    finally
      LIndex.Free;
    end;
  finally
    LService.Free;
  end;
end;

procedure TBoss4DDocumentationTests.CanExcludeDependencySources;
var
  LService: TBoss4DDocumentationService;
  LResult: TBoss4DDocumentationResult;
begin
  LService := TBoss4DDocumentationService.Create;
  try
    LResult := LService.Generate(FRoot, TPath.Combine(FRoot, 'site'), False);
    Assert.AreEqual(1, LResult.Files);
    Assert.AreEqual(2, LResult.Symbols);
  finally
    LService.Free;
  end;
end;

procedure TBoss4DDocumentationTests.EscapesUntrustedDocumentation;
var
  LService: TBoss4DDocumentationService;
  LOutput: string;
begin
  TFile.WriteAllText(TPath.Combine(FRoot, 'Unsafe.pas'),
    'unit Unsafe;' + sLineBreak + 'interface' + sLineBreak +
    '/// <script>alert(1)</script>' + sLineBreak +
    'procedure Unsafe;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  LOutput := TPath.Combine(FRoot, 'site');
  LService := TBoss4DDocumentationService.Create;
  try
    LService.Generate(FRoot, LOutput, False);
    var LHtml := TFile.ReadAllText(TPath.Combine(LOutput, 'index.html'));
    Assert.IsFalse(LHtml.Contains('<script>alert(1)</script>'));
    Assert.IsTrue(LHtml.Contains('alert(1)'));
  finally
    LService.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DDocumentationTests);

end.
