unit Boss4D.Posix.Core;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

type
  TBoss4DInstallOptions = record
    FrozenLockfile: Boolean;
    Locked: Boolean;
    Offline: Boolean;
    Production: Boolean;
    Resolution: string;
  end;

function Boss4DVersion: string;
function PlatformName: string;
function DefaultManifest: string;
function LoadJsonObject(const AFileName: string): TJSONObject;
function DependencyTarget(const ARepository: string): string;
function BuildCloneArguments(const ARepository, AVersion,
  ATarget: string): TStringList;
function ManifestFingerprint(const AManifest: TJSONObject): string;
function DirectorySha256(const ADirectory: string): string;
function CreateGitLockEvidence(const ARepository, AVersion, ATarget,
  AScope, ARevision: string): TJSONObject;
function SelectVersion(const AConstraint: string; const AVersions: TStrings;
  const AStrategy: string): string;
function ListProject(const ADirectory: string; const AProduction: Boolean): TStringList;
procedure InitProject(const ADirectory: string);
procedure AddDependency(const ADirectory, ARepository, AVersion: string;
  const ADevelopment: Boolean);
procedure RemoveDependency(const ADirectory, ARepository: string);
procedure RecordArtifactDependency(const ADirectory, ARepository,
  AVersion, ADigest, ATarget: string);
procedure InstallProject(const ADirectory: string); overload;
procedure InstallProject(const ADirectory: string;
  const AOptions: TBoss4DInstallOptions); overload;

implementation

uses
  jsonparser, process, Boss4D.Posix.Operations, Boss4D.Posix.Package;

const
  MANIFEST_FILE = 'boss.json';
  LOCK_FILE = 'boss-lock.json';
  MODULES_DIR = 'modules';

function Boss4DVersion: string;
begin
  Result := '1.5.0';
end;

function PlatformName: string;
begin
  {$ifdef linux}
  Result := 'linux';
  {$else}
  {$ifdef darwin}
  Result := 'macos';
  {$else}
  Result := 'posix';
  {$endif}
  {$endif}
end;

function DefaultManifest: string;
begin
  Result := '{"name":"app","version":"0.1.0","dependencies":{}}';
end;

function LoadJsonObject(const AFileName: string): TJSONObject;
var
  LStream: TFileStream;
  LData: TJSONData;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('JSON root must be an object');
  end;
  Result := TJSONObject(LData);
end;

procedure SaveJsonObject(const AFileName: string; const AObject: TJSONObject);
var
  LFile: TextFile;
begin
  AssignFile(LFile, AFileName);
  Rewrite(LFile);
  try
    WriteLn(LFile, AObject.FormatJSON);
  finally
    CloseFile(LFile);
  end;
end;

function FindObject(const ARoot: TJSONObject; const AName: string): TJSONObject;
var
  LData: TJSONData;
begin
  Result := nil;
  LData := ARoot.Find(AName);
  if LData is TJSONObject then
    Result := TJSONObject(LData);
end;

function EnsureObject(const ARoot: TJSONObject; const AName: string): TJSONObject;
begin
  Result := FindObject(ARoot, AName);
  if not Assigned(Result) then
  begin
    Result := TJSONObject.Create;
    ARoot.Add(AName, Result);
  end;
end;

function DependencyTarget(const ARepository: string): string;
var
  LValue: string;
begin
  LValue := ARepository;
  while (Length(LValue) > 0) and (LValue[Length(LValue)] = '/') do
    Delete(LValue, Length(LValue), 1);
  if LowerCase(ExtractFileExt(LValue)) = '.git' then
    Delete(LValue, Length(LValue) - 3, 4);
  Result := ExtractFileName(LValue);
end;

function BuildCloneArguments(const ARepository, AVersion,
  ATarget: string): TStringList;
begin
  Result := TStringList.Create;
  Result.Add('clone');
  Result.Add('--depth');
  Result.Add('1');
  if (AVersion <> '') and (AVersion <> '*') then
  begin
    Result.Add('--branch');
    Result.Add(AVersion);
  end;
  Result.Add(ARepository);
  Result.Add(ATarget);
end;

function ManifestFingerprint(const AManifest: TJSONObject): string;
var
  I: Integer;
  LHash: QWord;
  LValue: RawByteString;
begin
  { Stable FNV-1a fingerprint. It detects manifest/lock drift without changing
    the legacy boss.json shape. Artifact integrity continues to use SHA-256. }
  LValue := UTF8Encode(AManifest.AsJSON);
  LHash := QWord($CBF29CE484222325);
  for I := 1 to Length(LValue) do
  begin
    LHash := LHash xor Byte(LValue[I]);
    LHash := LHash * QWord($100000001B3);
  end;
  Result := LowerCase(IntToHex(LHash, 16));
end;

procedure CollectFiles(const ARoot, ADirectory: string;
  const AFiles: TStringList);
var
  LSearch: TSearchRec;
  LPath, LRelative: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') or
         (LSearch.Name = '.git') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        CollectFiles(ARoot, LPath, AFiles)
      else
      begin
        LRelative := Copy(LPath, Length(IncludeTrailingPathDelimiter(
          ARoot)) + 1, MaxInt);
        LRelative := StringReplace(LRelative, DirectorySeparator, '/',
          [rfReplaceAll]);
        AFiles.Add(LRelative);
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function DirectorySha256(const ADirectory: string): string;
var
  LFiles, LManifest: TStringList;
  LManifestPath, LPath: string;
  I: Integer;
begin
  if not DirectoryExists(ADirectory) then
    raise Exception.Create('directory not found: ' + ADirectory);
  LFiles := TStringList.Create;
  LManifest := TStringList.Create;
  try
    CollectFiles(ExpandFileName(ADirectory), ExpandFileName(ADirectory),
      LFiles);
    LFiles.Sort;
    for I := 0 to LFiles.Count - 1 do
    begin
      LPath := IncludeTrailingPathDelimiter(ADirectory) +
        StringReplace(LFiles[I], '/', DirectorySeparator, [rfReplaceAll]);
      LManifest.Add(Sha256File(LPath) + '  ' + LFiles[I]);
    end;
    LManifestPath := IncludeTrailingPathDelimiter(GetTempDir(False)) +
      'boss4d-tree-' + IntToHex(Random(MaxInt), 8) + '.txt';
    LManifest.SaveToFile(LManifestPath);
    try
      Result := Sha256File(LManifestPath);
    finally
      DeleteFile(LManifestPath);
    end;
  finally
    LManifest.Free;
    LFiles.Free;
  end;
end;

function CreateGitLockEvidence(const ARepository, AVersion, ATarget,
  AScope, ARevision: string): TJSONObject;
begin
  if Trim(ARevision) = '' then
    raise Exception.Create('Git revision is required for lock evidence');
  Result := TJSONObject.Create;
  Result.Add('name', DependencyTarget(ARepository));
  Result.Add('version', AVersion);
  Result.Add('repository', ARepository);
  Result.Add('resolvedFrom', 'git');
  Result.Add('scope', AScope);
  Result.Add('revision', Trim(ARevision));
  Result.Add('checksum', 'sha256:' + DirectorySha256(ATarget));
  Result.Add('target', 'modules/' + DependencyTarget(ARepository));
  Result.Add('dependencies', TJSONArray.Create);
end;

function StripVersionPrefix(const AValue: string): string;
begin
  Result := Trim(AValue);
  if (Length(Result) > 1) and ((Result[1] = 'v') or (Result[1] = 'V')) then
    Delete(Result, 1, 1);
end;

function VersionPart(const AVersion: string; const AIndex: Integer): Integer;
var
  LParts: TStringList;
  LValue: string;
begin
  Result := 0;
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '.';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := StripVersionPrefix(AVersion);
    if AIndex >= LParts.Count then Exit;
    LValue := LParts[AIndex];
    while (Length(LValue) > 0) and not (LValue[Length(LValue)] in ['0'..'9']) do
      Delete(LValue, Length(LValue), 1);
    TryStrToInt(LValue, Result);
  finally
    LParts.Free;
  end;
end;

function CompareVersions(const ALeft, ARight: string): Integer;
var
  I, LLeft, LRight: Integer;
begin
  Result := 0;
  for I := 0 to 2 do
  begin
    LLeft := VersionPart(ALeft, I);
    LRight := VersionPart(ARight, I);
    if LLeft < LRight then Exit(-1);
    if LLeft > LRight then Exit(1);
  end;
end;

function VersionMatches(const AVersion, AConstraint: string): Boolean;
var
  LConstraint: string;
begin
  LConstraint := Trim(AConstraint);
  if (LConstraint = '') or (LConstraint = '*') then Exit(True);
  if LConstraint[1] = '^' then
  begin
    Delete(LConstraint, 1, 1);
    Exit((VersionPart(AVersion, 0) = VersionPart(LConstraint, 0)) and
      (CompareVersions(AVersion, LConstraint) >= 0));
  end;
  if LConstraint[1] = '~' then
  begin
    Delete(LConstraint, 1, 1);
    Exit((VersionPart(AVersion, 0) = VersionPart(LConstraint, 0)) and
      (VersionPart(AVersion, 1) = VersionPart(LConstraint, 1)) and
      (CompareVersions(AVersion, LConstraint) >= 0));
  end;
  Result := SameText(StripVersionPrefix(AVersion),
    StripVersionPrefix(LConstraint));
end;

function SelectVersion(const AConstraint: string; const AVersions: TStrings;
  const AStrategy: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to AVersions.Count - 1 do
    if VersionMatches(AVersions[I], AConstraint) and
      ((Result = '') or
       (SameText(AStrategy, 'minimal') and
        (CompareVersions(AVersions[I], Result) < 0)) or
       (not SameText(AStrategy, 'minimal') and
        (CompareVersions(AVersions[I], Result) > 0))) then
      Result := AVersions[I];
end;

procedure InitProject(const ADirectory: string);
var
  LFile: TextFile;
  LPath: string;
begin
  LPath := IncludeTrailingPathDelimiter(ADirectory) + MANIFEST_FILE;
  if FileExists(LPath) then
    raise Exception.Create('boss.json already exists');
  AssignFile(LFile, LPath);
  Rewrite(LFile);
  try
    WriteLn(LFile, DefaultManifest);
  finally
    CloseFile(LFile);
  end;
end;

procedure AddDependency(const ADirectory, ARepository, AVersion: string;
  const ADevelopment: Boolean);
var
  LManifest, LDependencies: TJSONObject;
  LSection, LPath: string;
begin
  if Trim(ARepository) = '' then
    raise Exception.Create('repository is required');
  LPath := IncludeTrailingPathDelimiter(ADirectory) + MANIFEST_FILE;
  LManifest := LoadJsonObject(LPath);
  try
    if ADevelopment then LSection := 'devDependencies'
    else LSection := 'dependencies';
    LDependencies := EnsureObject(LManifest, LSection);
    LDependencies.Delete(ARepository);
    if AVersion = '' then LDependencies.Add(ARepository, '*')
    else LDependencies.Add(ARepository, AVersion);
    SaveJsonObject(LPath, LManifest);
  finally
    LManifest.Free;
  end;
end;

procedure RemoveDependency(const ADirectory, ARepository: string);
var
  LManifest, LDependencies: TJSONObject;
  LPath: string;
begin
  LPath := IncludeTrailingPathDelimiter(ADirectory) + MANIFEST_FILE;
  LManifest := LoadJsonObject(LPath);
  try
    LDependencies := FindObject(LManifest, 'dependencies');
    if Assigned(LDependencies) then LDependencies.Delete(ARepository);
    LDependencies := FindObject(LManifest, 'devDependencies');
    if Assigned(LDependencies) then LDependencies.Delete(ARepository);
    SaveJsonObject(LPath, LManifest);
  finally
    LManifest.Free;
  end;
end;

procedure RecordArtifactDependency(const ADirectory, ARepository,
  AVersion, ADigest, ATarget: string);
var
  LManifest, LLock, LInstalled, LEntry, LRoot: TJSONObject;
  LManifestPath, LLockPath: string;
begin
  AddDependency(ADirectory, ARepository, AVersion, False);
  LManifestPath := IncludeTrailingPathDelimiter(ADirectory) + MANIFEST_FILE;
  LLockPath := IncludeTrailingPathDelimiter(ADirectory) + LOCK_FILE;
  LManifest := LoadJsonObject(LManifestPath);
  try
    if FileExists(LLockPath) then
      LLock := LoadJsonObject(LLockPath)
    else
      LLock := TJSONObject.Create;
    try
      LLock.Delete('lockVersion');
      LLock.Add('lockVersion', 3);
      LLock.Delete('hash');
      LLock.Add('hash', ManifestFingerprint(LManifest));
      LRoot := FindObject(LLock, 'root');
      if not Assigned(LRoot) then
      begin
        LRoot := TJSONObject.Create;
        LRoot.Add('name', LManifest.Get('name', 'app'));
        LRoot.Add('version', LManifest.Get('version', '0.0.0'));
        LLock.Add('root', LRoot);
      end;
      LInstalled := EnsureObject(LLock, 'installedModules');
      LInstalled.Delete(ARepository);
      LEntry := TJSONObject.Create;
      LEntry.Add('name', DependencyTarget(ARepository));
      LEntry.Add('version', AVersion);
      LEntry.Add('repository', ARepository);
      LEntry.Add('resolvedFrom', 'registry-artifact');
      LEntry.Add('scope', 'runtime');
      LEntry.Add('checksum', 'sha256:' + LowerCase(ADigest));
      LEntry.Add('target', ATarget);
      LEntry.Add('dependencies', TJSONArray.Create);
      LInstalled.Add(ARepository, LEntry);
      SaveJsonObject(LLockPath, LLock);
    finally
      LLock.Free;
    end;
  finally
    LManifest.Free;
  end;
end;

procedure AppendDependencyList(const ARoot: TJSONObject; const ASection,
  AScope: string; const AResult: TStringList);
var
  I: Integer;
  LDependencies: TJSONObject;
begin
  LDependencies := FindObject(ARoot, ASection);
  if not Assigned(LDependencies) then Exit;
  for I := 0 to LDependencies.Count - 1 do
    AResult.Add(LDependencies.Names[I] + ' ' +
      LDependencies.Items[I].AsString + ' [' + AScope + ']');
end;

function ListProject(const ADirectory: string;
  const AProduction: Boolean): TStringList;
var
  LManifest: TJSONObject;
begin
  Result := TStringList.Create;
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(ADirectory) +
    MANIFEST_FILE);
  try
    AppendDependencyList(LManifest, 'dependencies', 'runtime', Result);
    if not AProduction then
      AppendDependencyList(LManifest, 'devDependencies', 'development', Result);
    Result.Sort;
  finally
    LManifest.Free;
  end;
end;

procedure RunGit(const AArguments: TStringList);
var
  LProcess: TProcess;
begin
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := 'git';
    LProcess.Parameters.Assign(AArguments);
    LProcess.Options := [poWaitOnExit];
    LProcess.Execute;
    if LProcess.ExitStatus <> 0 then
      raise Exception.CreateFmt('git failed with exit code %d',
        [LProcess.ExitStatus]);
  finally
    LProcess.Free;
  end;
end;

function ResolveGitVersion(const ARepository, AConstraint,
  AStrategy: string): string;
var
  LLines, LVersions: TStringList;
  LOutput, LLine, LPrefix: string;
  I, LPosition: Integer;
begin
  Result := AConstraint;
  if (AConstraint = '') or (AConstraint = '*') or
     not (AConstraint[1] in ['^', '~']) then Exit;
  LLines := TStringList.Create;
  LVersions := TStringList.Create;
  try
    if not RunCommand('git', ['ls-remote', '--tags', '--refs', ARepository],
      LOutput) then
      raise Exception.Create('unable to query versions for ' + ARepository);
    LLines.Text := LOutput;
    LPrefix := 'refs/tags/';
    for I := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[I];
      LPosition := Pos(LPrefix, LLine);
      if LPosition > 0 then
        LVersions.Add(Copy(LLine, LPosition + Length(LPrefix), MaxInt));
    end;
    Result := SelectVersion(AConstraint, LVersions, AStrategy);
    if Result = '' then
      raise Exception.CreateFmt('no version satisfies %s for %s',
        [AConstraint, ARepository]);
  finally
    LVersions.Free;
    LLines.Free;
  end;
end;

procedure DeleteDirectoryTree(const ADirectory: string);
var
  LSearch: TSearchRec;
  LPath: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) = 0 then
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        DeleteDirectoryTree(LPath)
      else
        DeleteFile(LPath);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  RemoveDir(ADirectory);
end;

procedure AddLockEntries(const ADirectory: string;
  const ALockInstalled, ADependencies: TJSONObject; const AScope: string;
  const AOptions: TBoss4DInstallOptions; const AExisting: TJSONObject;
  const ACreated: TStringList);
var
  I: Integer;
  LRepository, LVersion, LTarget, LStage, LRevision: string;
  LArguments: TStringList;
  LEntry, LExistingEntry: TJSONObject;
begin
  if not Assigned(ADependencies) then Exit;
  for I := 0 to ADependencies.Count - 1 do
  begin
    CheckCancelled;
    LRepository := ADependencies.Names[I];
    LVersion := ADependencies.Items[I].AsString;
    LTarget := IncludeTrailingPathDelimiter(ADirectory) + MODULES_DIR +
      DirectorySeparator + DependencyTarget(LRepository);
    LExistingEntry := nil;
    if Assigned(AExisting) and
       (AExisting.Find(LRepository) is TJSONObject) then
      LExistingEntry := TJSONObject(AExisting.Find(LRepository));
    if AOptions.Locked then
    begin
      if not Assigned(LExistingEntry) then
        raise Exception.Create('dependency is missing from lock: ' + LRepository);
      LVersion := LExistingEntry.Get('version', LVersion);
    end;
    if not AOptions.Locked and not AOptions.Offline then
      LVersion := ResolveGitVersion(LRepository, LVersion,
        AOptions.Resolution);
    if not DirectoryExists(LTarget) then
    begin
      if AOptions.Offline then
        raise Exception.Create('offline cache miss: ' + LRepository);
      LStage := LTarget + '.boss4d-stage';
      if DirectoryExists(LStage) then
        raise Exception.Create('stale install staging directory: ' + LStage);
      LArguments := BuildCloneArguments(LRepository, LVersion, LStage);
      try
        RunGit(LArguments);
      finally
        LArguments.Free;
      end;
      if not RenameFile(LStage, LTarget) then
        raise Exception.Create('unable to commit installed module: ' + LTarget);
      ACreated.Add(LTarget);
    end;
    if Assigned(LExistingEntry) and SameText(
       LExistingEntry.Get('resolvedFrom', ''), 'registry-artifact') then
    begin
      LEntry := TJSONObject.Create;
      LEntry.Add('name', DependencyTarget(LRepository));
      LEntry.Add('version', LVersion);
      LEntry.Add('repository', LRepository);
      LEntry.Add('scope', AScope);
      LEntry.Add('dependencies', TJSONArray.Create);
      LEntry.Add('resolvedFrom', 'registry-artifact');
      if Assigned(LExistingEntry.Find('checksum')) then
        LEntry.Add('checksum', LExistingEntry.Find('checksum').Clone);
      if LExistingEntry.Get('target', '') <> '' then
        LEntry.Add('target', LExistingEntry.Get('target', ''));
    end
    else
    begin
      if not RunCommand('git', ['-C', LTarget, 'rev-parse', 'HEAD'],
         LRevision) then
        raise Exception.Create('unable to resolve installed revision: ' +
          LRepository);
      LEntry := CreateGitLockEvidence(LRepository, LVersion, LTarget,
        AScope, LRevision);
    end;
    ALockInstalled.Add(LRepository, LEntry);
  end;
end;

procedure InstallProject(const ADirectory: string);
var
  LOptions: TBoss4DInstallOptions;
begin
  FillChar(LOptions, SizeOf(LOptions), 0);
  InstallProject(ADirectory, LOptions);
end;

procedure InstallProject(const ADirectory: string;
  const AOptions: TBoss4DInstallOptions);
var
  LManifest, LLock, LExistingLock, LExistingInstalled: TJSONObject;
  LRoot, LInstalled: TJSONObject;
  LCreated: TStringList;
  LManifestPath, LLockPath, LFingerprint: string;
  I: Integer;
begin
  CheckCancelled;
  LManifestPath := IncludeTrailingPathDelimiter(ADirectory) + MANIFEST_FILE;
  LLockPath := IncludeTrailingPathDelimiter(ADirectory) + LOCK_FILE;
  LManifest := LoadJsonObject(LManifestPath);
  LExistingLock := nil;
  LCreated := TStringList.Create;
  try
    try
      LFingerprint := ManifestFingerprint(LManifest);
      if FileExists(LLockPath) then
        LExistingLock := LoadJsonObject(LLockPath);
      if AOptions.FrozenLockfile then
      begin
        if not Assigned(LExistingLock) then
          raise Exception.Create('frozen lockfile requires boss-lock.json');
        if LExistingLock.Get('hash', '') <> LFingerprint then
          raise Exception.Create('boss.json and boss-lock.json are out of sync');
      end;
      if AOptions.Locked and not Assigned(LExistingLock) then
        raise Exception.Create('locked install requires boss-lock.json');
      LExistingInstalled := nil;
      if Assigned(LExistingLock) then
        LExistingInstalled := FindObject(LExistingLock, 'installedModules');
      ForceDirectories(IncludeTrailingPathDelimiter(ADirectory) + MODULES_DIR);
      LLock := TJSONObject.Create;
      try
        LLock.Add('lockVersion', 3);
        LLock.Add('hash', LFingerprint);
        LRoot := TJSONObject.Create;
        LRoot.Add('name', LManifest.Get('name', 'app'));
        LRoot.Add('version', LManifest.Get('version', '0.0.0'));
        LLock.Add('root', LRoot);
        LInstalled := TJSONObject.Create;
        LLock.Add('installedModules', LInstalled);
        AddLockEntries(ADirectory, LInstalled,
          FindObject(LManifest, 'dependencies'), 'runtime', AOptions,
          LExistingInstalled, LCreated);
        if not AOptions.Production then
          AddLockEntries(ADirectory, LInstalled,
            FindObject(LManifest, 'devDependencies'), 'development', AOptions,
            LExistingInstalled, LCreated);
        if not AOptions.FrozenLockfile then
          SaveJsonObject(LLockPath, LLock);
      finally
        LLock.Free;
      end;
    except
      for I := LCreated.Count - 1 downto 0 do
        if DirectoryExists(LCreated[I]) then
          DeleteDirectoryTree(LCreated[I]);
      raise;
    end;
  finally
    LCreated.Free;
    LExistingLock.Free;
    LManifest.Free;
  end;
end;

end.
