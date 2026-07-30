unit Boss4D.Core.Services.Transaction;

interface

uses
  System.Generics.Collections;

type
  { Snapshot transacional dos artefatos mutaveis de um projeto Boss4D. }
  TBoss4DProjectTransaction = class
  private
    FProjectDirectory: string;
    FBackupDirectory: string;
    FTrackedFiles: TDictionary<string, Boolean>;
    FModulesExisted: Boolean;
    FCompleted: Boolean;
    procedure CopyDirectory(const ASource, ADestination: string);
    procedure Restore;
    procedure Cleanup;
  public
    constructor Create(const AProjectDirectory: string);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

implementation

uses
  System.SysUtils, System.IOUtils,
  Boss4D.Core.Domain.Consts;

constructor TBoss4DProjectTransaction.Create(const AProjectDirectory: string);
var
  LFileName: string;
  LSourcePath: string;
begin
  inherited Create;
  FProjectDirectory := TPath.GetFullPath(AProjectDirectory);
  FBackupDirectory := TPath.Combine(TPath.GetTempPath,
    'boss4d-transaction-' + TGUID.NewGuid.ToString);
  FTrackedFiles := TDictionary<string, Boolean>.Create;
  TDirectory.CreateDirectory(FBackupDirectory);

  for LFileName in TArray<string>.Create(FILE_PACKAGE, FILE_PACKAGE_LOCK) do
  begin
    LSourcePath := TPath.Combine(FProjectDirectory, LFileName);
    FTrackedFiles.Add(LFileName, TFile.Exists(LSourcePath));
    if TFile.Exists(LSourcePath) then
      TFile.Copy(LSourcePath, TPath.Combine(FBackupDirectory, LFileName), True);
  end;

  LSourcePath := TPath.Combine(FProjectDirectory, FOLDER_DEPENDENCIES);
  FModulesExisted := TDirectory.Exists(LSourcePath);
  if FModulesExisted then
    CopyDirectory(LSourcePath,
      TPath.Combine(FBackupDirectory, FOLDER_DEPENDENCIES));
end;

destructor TBoss4DProjectTransaction.Destroy;
begin
  if not FCompleted then
    Restore;
  Cleanup;
  FTrackedFiles.Free;
  inherited Destroy;
end;

procedure TBoss4DProjectTransaction.CopyDirectory(const ASource,
  ADestination: string);
var
  LDirectory: string;
  LFileName: string;
  LRelativePath: string;
begin
  TDirectory.CreateDirectory(ADestination);
  for LDirectory in TDirectory.GetDirectories(ASource, '*',
    TSearchOption.soAllDirectories) do
  begin
    LRelativePath := LDirectory.Substring(Length(IncludeTrailingPathDelimiter(
      ASource)));
    TDirectory.CreateDirectory(TPath.Combine(ADestination, LRelativePath));
  end;
  for LFileName in TDirectory.GetFiles(ASource, '*',
    TSearchOption.soAllDirectories) do
  begin
    LRelativePath := LFileName.Substring(Length(IncludeTrailingPathDelimiter(
      ASource)));
    TFile.Copy(LFileName, TPath.Combine(ADestination, LRelativePath), True);
  end;
end;

procedure TBoss4DProjectTransaction.Restore;
var
  LPair: TPair<string, Boolean>;
  LTargetPath: string;
  LModulesPath: string;
begin
  for LPair in FTrackedFiles do
  begin
    LTargetPath := TPath.Combine(FProjectDirectory, LPair.Key);
    if LPair.Value then
      TFile.Copy(TPath.Combine(FBackupDirectory, LPair.Key), LTargetPath, True)
    else if TFile.Exists(LTargetPath) then
      TFile.Delete(LTargetPath);
  end;

  LModulesPath := TPath.Combine(FProjectDirectory, FOLDER_DEPENDENCIES);
  if TDirectory.Exists(LModulesPath) then
    TDirectory.Delete(LModulesPath, True);
  if FModulesExisted then
    CopyDirectory(TPath.Combine(FBackupDirectory, FOLDER_DEPENDENCIES),
      LModulesPath);
end;

procedure TBoss4DProjectTransaction.Cleanup;
begin
  if TDirectory.Exists(FBackupDirectory) then
    TDirectory.Delete(FBackupDirectory, True);
end;

procedure TBoss4DProjectTransaction.Commit;
begin
  FCompleted := True;
  Cleanup;
end;

procedure TBoss4DProjectTransaction.Rollback;
begin
  if FCompleted then
    Exit;
  Restore;
  FCompleted := True;
  Cleanup;
end;

end.
