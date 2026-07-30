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
  end;

function Boss4DVersion: string;
function PlatformName: string;
function DefaultManifest: string;
function LoadJsonObject(const AFileName: string): TJSONObject;
function DependencyTarget(const ARepository: string): string;
function BuildCloneArguments(const ARepository, AVersion,
  ATarget: string): TStringList;
function ManifestFingerprint(const AManifest: TJSONObject): string;
function ListProject(const ADirectory: string; const AProduction: Boolean): TStringList;
procedure InitProject(const ADirectory: string);
procedure AddDependency(const ADirectory, ARepository, AVersion: string;
  const ADevelopment: Boolean);
procedure RemoveDependency(const ADirectory, ARepository: string);
procedure InstallProject(const ADirectory: string); overload;
procedure InstallProject(const ADirectory: string;
  const AOptions: TBoss4DInstallOptions); overload;

implementation

uses
  jsonparser, process;

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

procedure AddLockEntries(const ADirectory: string; const AManifest,
  ALockInstalled: TJSONObject; const ASection, AScope: string;
  const AOptions: TBoss4DInstallOptions; const AExisting: TJSONObject;
  const ACreated: TStringList);
var
  I: Integer;
  LDependencies: TJSONObject;
  LRepository, LVersion, LTarget, LStage: string;
  LArguments: TStringList;
  LEntry, LExistingEntry: TJSONObject;
begin
  LDependencies := FindObject(AManifest, ASection);
  if not Assigned(LDependencies) then Exit;
  for I := 0 to LDependencies.Count - 1 do
  begin
    LRepository := LDependencies.Names[I];
    LVersion := LDependencies.Items[I].AsString;
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
    LEntry := TJSONObject.Create;
    LEntry.Add('name', DependencyTarget(LRepository));
    LEntry.Add('version', LVersion);
    LEntry.Add('repository', LRepository);
    LEntry.Add('resolvedFrom', 'git');
    LEntry.Add('scope', AScope);
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
        AddLockEntries(ADirectory, LManifest, LInstalled, 'dependencies',
          'runtime', AOptions, LExistingInstalled, LCreated);
        if not AOptions.Production then
          AddLockEntries(ADirectory, LManifest, LInstalled, 'devDependencies',
            'development', AOptions, LExistingInstalled, LCreated);
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
