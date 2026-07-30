unit Boss4D.Tests.Resolver;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBoss4DResolverTests = class
  public
    [Test] procedure SelectsHighestCompatible;
    [Test] procedure SelectsMinimalCompatible;
    [Test] procedure IgnoresInvalidAndOutOfRange;
    [Test] procedure IsIndependentOfInputOrder;
  end;

implementation

uses
  Boss4D.Core.Services.Resolver;

procedure TBoss4DResolverTests.SelectsHighestCompatible;
var
  LResolver: TBoss4DVersionResolver;
begin
  LResolver := TBoss4DVersionResolver.Create;
  try
    Assert.AreEqual('1.9.0', LResolver.Resolve('^1.2.0',
      TArray<string>.Create('1.2.0', '2.0.0', '1.9.0'),
      HighestCompatible));
  finally
    LResolver.Free;
  end;
end;

procedure TBoss4DResolverTests.SelectsMinimalCompatible;
var
  LResolver: TBoss4DVersionResolver;
begin
  LResolver := TBoss4DVersionResolver.Create;
  try
    Assert.AreEqual('1.2.0', LResolver.Resolve('^1.2.0',
      TArray<string>.Create('1.9.0', '1.2.0', '1.5.0'),
      MinimalCompatible));
  finally
    LResolver.Free;
  end;
end;

procedure TBoss4DResolverTests.IgnoresInvalidAndOutOfRange;
var
  LResolver: TBoss4DVersionResolver;
begin
  LResolver := TBoss4DVersionResolver.Create;
  try
    Assert.AreEqual('', LResolver.Resolve('^1.2.0',
      TArray<string>.Create('main', '2.0.0'), HighestCompatible));
  finally
    LResolver.Free;
  end;
end;

procedure TBoss4DResolverTests.IsIndependentOfInputOrder;
var
  LResolver: TBoss4DVersionResolver;
  LFirst, LSecond: string;
begin
  LResolver := TBoss4DVersionResolver.Create;
  try
    LFirst := LResolver.Resolve('^1.0.0',
      TArray<string>.Create('1.2.0', '1.0.0', '1.1.0'),
      MinimalCompatible);
    LSecond := LResolver.Resolve('^1.0.0',
      TArray<string>.Create('1.1.0', '1.2.0', '1.0.0'),
      MinimalCompatible);
    Assert.AreEqual(LFirst, LSecond);
  finally
    LResolver.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBoss4DResolverTests);

end.
