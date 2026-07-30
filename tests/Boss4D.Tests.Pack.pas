unit Boss4D.Tests.Pack;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DPackTests = class
  public
    [Test] procedure ProducesDeterministicPackage;
    [Test] procedure ExcludesBuildAndDependencyContent;
    [Test] procedure RequiresManifest;
    [Test] procedure ExcludesPreviousBenchmarkArtifacts;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Services.Pack;

procedure TBoss4DPackTests.ProducesDeterministicPackage;
var
  LRoot, LFirst, LSecond: string;
  LService: TBoss4DPackService;
  LResult1, LResult2: TBoss4DPackResult;
begin
  LRoot := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  TDirectory.CreateDirectory(TPath.Combine(LRoot, 'src'));
  TFile.WriteAllText(TPath.Combine(LRoot, 'boss.json'),
    '{"name":"demo","version":"1.0.0"}');
  TFile.WriteAllText(TPath.Combine(LRoot, 'src\demo.pas'), 'unit demo;');
  LFirst := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName + '.b4dpkg');
  LSecond := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName + '.b4dpkg');
  LService := TBoss4DPackService.Create;
  try
    LResult1 := LService.Execute(LRoot, LFirst);
    LResult2 := LService.Execute(LRoot, LSecond);
    Assert.AreEqual(LResult1.Digest, LResult2.Digest);
    Assert.AreEqual(TFile.ReadAllText(LFirst), TFile.ReadAllText(LSecond));
    Assert.AreEqual<Integer>(2, LResult1.FileCount);
    Assert.IsTrue(TFile.ReadAllText(LResult1.ProvenancePath).Contains(
      LResult1.Digest));
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
    TFile.Delete(LFirst);
    TFile.Delete(LSecond);
    TFile.Delete(LFirst + '.intoto.json');
    TFile.Delete(LSecond + '.intoto.json');
  end;
end;

procedure TBoss4DPackTests.ExcludesBuildAndDependencyContent;
var
  LRoot, LOutput, LContent: string;
  LService: TBoss4DPackService;
begin
  LRoot := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  TDirectory.CreateDirectory(TPath.Combine(LRoot, 'modules\dep'));
  TFile.WriteAllText(TPath.Combine(LRoot, 'boss.json'), '{}');
  TFile.WriteAllText(TPath.Combine(LRoot, 'modules\dep\secret.pas'), 'skip');
  LOutput := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName + '.b4dpkg');
  LService := TBoss4DPackService.Create;
  try
    LService.Execute(LRoot, LOutput);
    LContent := TFile.ReadAllText(LOutput);
    Assert.IsFalse(LContent.Contains('secret.pas'));
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
    TFile.Delete(LOutput);
    TFile.Delete(LOutput + '.intoto.json');
  end;
end;

procedure TBoss4DPackTests.RequiresManifest;
var
  LRoot: string;
  LService: TBoss4DPackService;
begin
  LRoot := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  TDirectory.CreateDirectory(LRoot);
  LService := TBoss4DPackService.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        LService.Execute(LRoot, TPath.Combine(LRoot, 'x.b4dpkg'));
      end, EFileNotFoundException);
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TBoss4DPackTests.ExcludesPreviousBenchmarkArtifacts;
var
  LRoot, LOutput, LContent: string;
  LService: TBoss4DPackService;
begin
  LRoot := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  TDirectory.CreateDirectory(TPath.Combine(LRoot, '.benchmark-pack'));
  TFile.WriteAllText(TPath.Combine(LRoot, 'boss.json'), '{}');
  TFile.WriteAllText(TPath.Combine(LRoot,
    '.benchmark-pack\previous.b4dpkg'), 'recursive payload');
  LOutput := TPath.Combine(TPath.GetTempPath,
    TPath.GetRandomFileName + '.b4dpkg');
  LService := TBoss4DPackService.Create;
  try
    LService.Execute(LRoot, LOutput);
    LContent := TFile.ReadAllText(LOutput);
    Assert.IsFalse(LContent.Contains('previous.b4dpkg'));
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
    TFile.Delete(LOutput);
    TFile.Delete(LOutput + '.intoto.json');
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DPackTests);

end.
