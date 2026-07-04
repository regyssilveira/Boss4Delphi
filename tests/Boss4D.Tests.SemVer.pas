unit Boss4D.Tests.SemVer;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsSemVer = class
  public
    [Test]
    procedure TestSimpleParse;

    [TestCase('TestNormalization1', 'v1.0.0,1.0.0')]
    [TestCase('TestNormalization2', '1.2,1.2.0')]
    [TestCase('TestNormalization3', '3,3.0.0')]
    [TestCase('TestNormalization4', '  v2.3.4-alpha  ,2.3.4-alpha')]
    procedure TestNormalizations(const AInput, AExpected: string);

    [Test]
    procedure TestComparisons;

    [Test]
    [TestCase('^1.2.3', '1.3.0', 'True')]
    [TestCase('^1.2.3', '2.0.0', 'False')]
    [TestCase('^1.2.3', '1.2.3-alpha', 'False')]
    [TestCase('~1.2.3', '1.2.5', 'True')]
    [TestCase('~1.2.3', '1.3.0', 'False')]
    [TestCase('1.2.x', '1.2.8', 'True')]
    [TestCase('1.2.x', '1.3.0', 'False')]
    [TestCase('>=1.0.0', '2.0.0', 'True')]
    [TestCase('<2.0.0', '2.0.0', 'False')]
    procedure TestRanges(const ARange, AVersion: string; const AExpected: string);
  end;

implementation

uses
  System.SysUtils, Boss4D.Core.Domain.SemVer;

{ TTestsSemVer }

procedure TTestsSemVer.TestSimpleParse;
begin
  var LVer := TBoss4DSemVer.Create('1.2.3-alpha.1+build.10');
  Assert.IsTrue(LVer.IsValid);
  Assert.AreEqual(1, LVer.Major);
  Assert.AreEqual(2, LVer.Minor);
  Assert.AreEqual(3, LVer.Patch);
  Assert.AreEqual('alpha.1', LVer.PreRelease);
  Assert.AreEqual('build.10', LVer.Build);
  Assert.AreEqual('1.2.3-alpha.1+build.10', LVer.ToString);
end;

procedure TTestsSemVer.TestNormalizations(const AInput, AExpected: string);
begin
  var LVer := TBoss4DSemVer.Create(AInput);
  Assert.IsTrue(LVer.IsValid);
  Assert.AreEqual(AExpected, LVer.ToString);
end;

procedure TTestsSemVer.TestComparisons;
begin
  var LVer1 := TBoss4DSemVer.Create('1.2.3');
  var LVer2 := TBoss4DSemVer.Create('1.2.4');
  var LVer3 := TBoss4DSemVer.Create('1.2.3-alpha');

  Assert.IsTrue(LVer1 < LVer2);
  Assert.IsTrue(LVer2 > LVer1);
  Assert.IsTrue(LVer1 = TBoss4DSemVer.Create('1.2.3'));
  Assert.IsTrue(LVer3 < LVer1); // Versão com pré-release é menor que sem pré-release
end;

procedure TTestsSemVer.TestRanges(const ARange, AVersion: string; const AExpected: string);
var
  LRange: TBoss4DSemVerRange;
  LExpectedBool, LActualBool: Boolean;
begin
  LRange := TBoss4DSemVerRange.Create(ARange);
  LExpectedBool := SameText(AExpected, 'True');
  LActualBool := LRange.IsSatisfiedBy(AVersion);
  Assert.AreEqual(LExpectedBool, LActualBool, Format('Range %s com Versao %s falhou.', [ARange, AVersion]));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsSemVer);

end.
