unit Boss4D.Core.Services.VersionHistory;

interface

type
  TBoss4DVersionHistoryService = class
  private
    FProjectDirectory: string;
    function HistoryDirectory: string;
    procedure CopyDirectory(const ASource, ADestination: string);
  public
    constructor Create(const AProjectDirectory: string);
    function Capture(const AAction, ADependency, AFromVersion,
      AToVersion: string): string;
    function RestoreLatest: string;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON,
  Boss4D.Core.Domain.Consts, Boss4D.Core.Services.Transaction;

procedure TBoss4DVersionHistoryService.CopyDirectory(const ASource,
  ADestination: string);
begin
  TDirectory.CreateDirectory(ADestination);
  for var LDirectory in TDirectory.GetDirectories(ASource, '*',
    TSearchOption.soAllDirectories) do
    TDirectory.CreateDirectory(TPath.Combine(ADestination,
      LDirectory.Substring(Length(IncludeTrailingPathDelimiter(ASource)))));
  for var LFileName in TDirectory.GetFiles(ASource, '*',
    TSearchOption.soAllDirectories) do
    TFile.Copy(LFileName, TPath.Combine(ADestination,
      LFileName.Substring(Length(IncludeTrailingPathDelimiter(ASource)))), True);
end;

constructor TBoss4DVersionHistoryService.Create(
  const AProjectDirectory: string);
begin
  inherited Create;
  FProjectDirectory := TPath.GetFullPath(AProjectDirectory);
end;

function TBoss4DVersionHistoryService.HistoryDirectory: string;
begin
  Result := TPath.Combine(TPath.Combine(FProjectDirectory, '.boss4d'),
    'version-history');
end;

function TBoss4DVersionHistoryService.Capture(const AAction, ADependency,
  AFromVersion, AToVersion: string): string;
var
  LSnapshotDirectory, LManifestPath, LLockPath: string;
  LMetadata: TJSONObject;
begin
  Result := FormatDateTime('yyyymmddhhnnsszzz', Now) + '-' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
  LSnapshotDirectory := TPath.Combine(HistoryDirectory, Result);
  TDirectory.CreateDirectory(LSnapshotDirectory);
  LManifestPath := TPath.Combine(FProjectDirectory, FILE_PACKAGE);
  LLockPath := TPath.Combine(FProjectDirectory, FILE_PACKAGE_LOCK);
  if not TFile.Exists(LManifestPath) then
    raise EFileNotFoundException.Create('boss.json nao encontrado.');
  TFile.Copy(LManifestPath,
    TPath.Combine(LSnapshotDirectory, FILE_PACKAGE), True);
  if TFile.Exists(LLockPath) then
    TFile.Copy(LLockPath,
      TPath.Combine(LSnapshotDirectory, FILE_PACKAGE_LOCK), True);
  var LModulesPath := TPath.Combine(FProjectDirectory, FOLDER_DEPENDENCIES);
  if TDirectory.Exists(LModulesPath) then
    CopyDirectory(LModulesPath,
      TPath.Combine(LSnapshotDirectory, FOLDER_DEPENDENCIES));
  LMetadata := TJSONObject.Create;
  try
    LMetadata.AddPair('id', Result);
    LMetadata.AddPair('action', AAction);
    LMetadata.AddPair('dependency', ADependency);
    LMetadata.AddPair('fromVersion', AFromVersion);
    LMetadata.AddPair('toVersion', AToVersion);
    LMetadata.AddPair('createdAt',
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now));
    LMetadata.AddPair('status', 'captured');
    TFile.WriteAllText(TPath.Combine(LSnapshotDirectory, 'metadata.json'),
      LMetadata.Format(2), TEncoding.UTF8);
  finally
    LMetadata.Free;
  end;
end;

function TBoss4DVersionHistoryService.RestoreLatest: string;
var
  LDirectories: TArray<string>;
  LLatest, LDirectory, LSnapshotManifest, LSnapshotLock: string;
  LTransaction: TBoss4DProjectTransaction;
begin
  Result := '';
  if not TDirectory.Exists(HistoryDirectory) then
    raise EFileNotFoundException.Create('Nenhum historico de versao encontrado.');
  LDirectories := TDirectory.GetDirectories(HistoryDirectory);
  LLatest := '';
  for LDirectory in LDirectories do
    if LLatest.IsEmpty or
       (CompareText(TPath.GetFileName(LDirectory),
         TPath.GetFileName(LLatest)) > 0) then
      LLatest := LDirectory;
  if LLatest.IsEmpty then
    raise EFileNotFoundException.Create('Nenhum historico de versao encontrado.');
  LSnapshotManifest := TPath.Combine(LLatest, FILE_PACKAGE);
  LSnapshotLock := TPath.Combine(LLatest, FILE_PACKAGE_LOCK);
  if not TFile.Exists(LSnapshotManifest) then
    raise EFileNotFoundException.Create('Snapshot sem boss.json: ' + LLatest);
  LTransaction := TBoss4DProjectTransaction.Create(FProjectDirectory);
  try
    TFile.Copy(LSnapshotManifest,
      TPath.Combine(FProjectDirectory, FILE_PACKAGE), True);
    if TFile.Exists(LSnapshotLock) then
      TFile.Copy(LSnapshotLock,
        TPath.Combine(FProjectDirectory, FILE_PACKAGE_LOCK), True)
    else if TFile.Exists(TPath.Combine(FProjectDirectory, FILE_PACKAGE_LOCK)) then
      TFile.Delete(TPath.Combine(FProjectDirectory, FILE_PACKAGE_LOCK));
    var LModulesPath := TPath.Combine(FProjectDirectory, FOLDER_DEPENDENCIES);
    if TDirectory.Exists(LModulesPath) then
      TDirectory.Delete(LModulesPath, True);
    if TDirectory.Exists(TPath.Combine(LLatest, FOLDER_DEPENDENCIES)) then
      CopyDirectory(TPath.Combine(LLatest, FOLDER_DEPENDENCIES), LModulesPath);
    LTransaction.Commit;
    Result := TPath.GetFileName(LLatest);
  finally
    LTransaction.Free;
  end;
end;

end.
