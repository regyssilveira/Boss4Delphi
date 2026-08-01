unit Boss4D.Tests.GUI.Logs;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestsGUILogs = class
  public
    [Test]
    procedure TestParsesLegacyLevelsAndIDEOrigin;
    [Test]
    procedure TestStoreFiltersAndSearchesStructuredEntries;
    [Test]
    procedure TestJsonExportPreservesStructuredFields;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  Boss4D.Core.Ports,
  Boss4D.GUI.Logs;

procedure TTestsGUILogs.TestParsesLegacyLevelsAndIDEOrigin;
begin
  var LEntry := TBoss4DGUILogs.ParseLegacy(
    '[IDE][ERRO] registro ausente', '2026-07-31T12:00:00');
  Assert.AreEqual(TBoss4DLogLevel.Error, LEntry.Level);
  Assert.AreEqual('IDE', LEntry.Source);
  Assert.AreEqual('registro ausente', LEntry.MessageText);
  Assert.AreEqual('2026-07-31T12:00:00', LEntry.OccurredAt);

  LEntry := TBoss4DGUILogs.ParseLegacy('[AVISO] cache antigo');
  Assert.AreEqual(TBoss4DLogLevel.Warning, LEntry.Level);
  Assert.AreEqual('cache antigo', LEntry.MessageText);
end;

procedure TTestsGUILogs.TestStoreFiltersAndSearchesStructuredEntries;
begin
  var LStore := TBoss4DGUILogStore.Create;
  try
    LStore.Add(TBoss4DGUILogEntry.Create(
      TBoss4DLogLevel.Info, 'GUI', 'instalacao iniciada'));
    LStore.Add(TBoss4DGUILogEntry.Create(
      TBoss4DLogLevel.Error, 'IDE', 'package nao registrado'));
    LStore.Add(TBoss4DGUILogEntry.Create(
      TBoss4DLogLevel.Warning, 'Cache', 'entrada antiga'));
    Assert.AreEqual<Integer>(3, LStore.Count);
    var LErrors := LStore.Query(TBoss4DGUILogFilter.ErrorLogs);
    Assert.AreEqual<Integer>(1, Length(LErrors));
    Assert.AreEqual('IDE', LErrors[0].Source);
    var LSearch := LStore.Query(
      TBoss4DGUILogFilter.AllLogs, 'antiga');
    Assert.AreEqual<Integer>(1, Length(LSearch));
    Assert.AreEqual('Cache', LSearch[0].Source);
    LStore.Clear;
    Assert.AreEqual<Integer>(0, LStore.Count);
  finally
    LStore.Free;
  end;
end;

procedure TTestsGUILogs.TestJsonExportPreservesStructuredFields;
begin
  var LEntries := TArray<TBoss4DGUILogEntry>.Create(
    TBoss4DGUILogEntry.Create(TBoss4DLogLevel.Error, 'IDE',
      'falha controlada', '2026-07-31T12:00:00'));
  var LJson := TBoss4DGUILogs.ToJson(LEntries);
  var LRoot := TJSONObject.ParseJSONValue(LJson) as TJSONObject;
  try
    Assert.IsNotNull(LRoot);
    Assert.AreEqual<Integer>(1,
      LRoot.GetValue<Integer>('schemaVersion', 0));
    var LItems := LRoot.GetValue<TJSONArray>('entries');
    Assert.AreEqual<Integer>(1, LItems.Count);
    Assert.AreEqual('erro',
      (LItems[0] as TJSONObject).GetValue<string>('level', ''));
    Assert.AreEqual('IDE',
      (LItems[0] as TJSONObject).GetValue<string>('source', ''));
  finally
    LRoot.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestsGUILogs);

end.
