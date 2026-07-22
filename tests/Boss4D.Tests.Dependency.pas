unit Boss4D.Tests.Dependency;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsDependency = class
  public
    [Test]
    procedure TestDependencyParse;

    [TestCase('Test1', 'github.com/hashload/horse,horse')]
    [TestCase('Test2', 'github.com/hashload/horse/,horse')]
    [TestCase('Test3', 'https://github.com/hashload/dataset-serialize,dataset-serialize')]
    [TestCase('Test4', 'github.com/hashload/horse.git,horse')]
    [TestCase('Test5', 'git@github.com:hashload/horse.git,horse')]
    procedure TestNameExtraction(const ARepo, AExpectedName: string);

    [Test]
    procedure TestSHA256Hash;

    [Test]
    procedure TestGetURL;

    [Test]
    procedure TestCanonicalRepositoryIdentity;

    [Test]
    procedure TestCollisionFreeStorageName;

    [Test]
    procedure TestParseCommandLine;
  end;

implementation

uses
  System.SysUtils,
  Boss4D.Core.Domain.Dependency;

{ TTestsDependency }

procedure TTestsDependency.TestDependencyParse;
begin
  var LDep := TBoss4DDependency.Parse('github.com/hashload/horse', 'v3.1.0:ssh');
  try
    Assert.AreEqual('github.com/hashload/horse', LDep.Repository);
    Assert.AreEqual('v3.1.0', LDep.Version);
    Assert.IsTrue(LDep.UseSSH);
  finally
    LDep.Free;
  end;
end;

procedure TTestsDependency.TestNameExtraction(const ARepo, AExpectedName: string);
begin
  var LDep := TBoss4DDependency.Create(ARepo, '1.0.0');
  try
    Assert.AreEqual(AExpectedName, LDep.Name);
  finally
    LDep.Free;
  end;
end;

procedure TTestsDependency.TestSHA256Hash;
begin
  var LDep1 := TBoss4DDependency.Create('github.com/hashload/horse', '1.0.0');
  var LDep2 := TBoss4DDependency.Create('GITHUB.COM/HASHLOAD/HORSE', '2.0.0');
  try
    // Hashes devem ser iguais ignorando maiusculas/minusculas
    Assert.AreEqual(LDep1.HashName, LDep2.HashName);
    Assert.AreEqual(64, Length(LDep1.HashName));
  finally
    LDep1.Free;
    LDep2.Free;
  end;
end;

procedure TTestsDependency.TestGetURL;
begin
  var LDepHttps := TBoss4DDependency.Create('github.com/hashload/horse', '1.0.0', False);
  var LDepSsh := TBoss4DDependency.Create('github.com/hashload/horse', '1.0.0', True);
  try
    Assert.AreEqual('https://github.com/hashload/horse', LDepHttps.GetURL);
    Assert.AreEqual('git@github.com:hashload/horse', LDepSsh.GetURL);
  finally
    LDepHttps.Free;
    LDepSsh.Free;
  end;
end;

procedure TTestsDependency.TestCanonicalRepositoryIdentity;
var
  LHTTPS, LSSH, LCredential: TBoss4DDependency;
begin
  LHTTPS := TBoss4DDependency.Create('https://GitHub.com/HashLoad/Horse.git/', '1.0.0');
  LSSH := TBoss4DDependency.Create('git@github.com:HashLoad/Horse.git', '1.0.0');
  LCredential := TBoss4DDependency.Create('https://secret-token@github.com/HashLoad/Horse.git', '1.0.0');
  try
    Assert.AreEqual('https://GitHub.com/HashLoad/Horse', LHTTPS.GetCanonicalRepository);
    Assert.AreEqual(LHTTPS.GetKey, LSSH.GetKey);
    Assert.AreEqual(LHTTPS.GetKey, LCredential.GetKey);
    Assert.AreEqual(LHTTPS.HashName, LSSH.HashName);
    Assert.AreEqual<Integer>(0, Pos('secret-token', LCredential.GetCanonicalRepository));
  finally
    LCredential.Free;
    LSSH.Free;
    LHTTPS.Free;
  end;
end;

procedure TTestsDependency.TestCollisionFreeStorageName;
var
  LFirst, LSecond, LSSH: TBoss4DDependency;
begin
  LFirst := TBoss4DDependency.Create('github.com/company-a/common', '1.0.0');
  LSecond := TBoss4DDependency.Create('gitlab.com/company-b/common', '1.0.0');
  LSSH := TBoss4DDependency.Create('git@github.com:company-a/common.git', '1.0.0');
  try
    Assert.AreNotEqual(LFirst.StorageName, LSecond.StorageName);
    Assert.AreEqual(LFirst.StorageName, LSSH.StorageName);
    Assert.IsTrue(LFirst.StorageName.StartsWith('common-'));
  finally
    LSSH.Free;
    LSecond.Free;
    LFirst.Free;
  end;
end;

procedure TTestsDependency.TestParseCommandLine;
begin
  // 1. Testa URL HTTPS com versao
  var LDep1 := TBoss4DDependency.ParseCommandLine('github.com/hashload/horse@^3.0.0');
  try
    Assert.AreEqual('github.com/hashload/horse', LDep1.Repository);
    Assert.AreEqual('^3.0.0', LDep1.Version);
  finally
    LDep1.Free;
  end;

  // 2. Testa URL SSH com dois '@' (Bug do SSH com versao)
  var LDep2 := TBoss4DDependency.ParseCommandLine('git@github.com:hashload/horse@v3.1.0');
  try
    Assert.AreEqual('git@github.com:hashload/horse', LDep2.Repository);
    Assert.AreEqual('v3.1.0', LDep2.Version);
  finally
    LDep2.Free;
  end;

  // 3. Testa URL SSH pura sem versao especificada
  var LDep3 := TBoss4DDependency.ParseCommandLine('git@github.com:hashload/horse');
  try
    Assert.AreEqual('git@github.com:hashload/horse', LDep3.Repository);
    Assert.AreEqual('>=0.0.0', LDep3.Version);
  finally
    LDep3.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsDependency);

end.
