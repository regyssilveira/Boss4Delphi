unit Boss4D.Posix.Project;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DScriptRunner = function(const ACommand,
    ADirectory: string): Boolean of object;
  TBoss4DVersionProvider = function(const ARepository,
    AConstraint: string): string of object;

function DependencyTree(const ADirectory: string): TStringList;
function WhyDependency(const ADirectory, ADependency: string): TStringList;
function OutdatedDependencies(const ADirectory: string;
  const AProvider: TBoss4DVersionProvider = nil): TStringList;
procedure RunProjectScript(const ADirectory, AName: string;
  const ARunner: TBoss4DScriptRunner = nil);
procedure UpdateProject(const ADirectory: string);

implementation

uses
  fpjson, process, Boss4D.Posix.Core;

function FindObject(const ARoot: TJSONObject;
  const AName: string): TJSONObject;
begin
  Result := nil;
  if ARoot.Find(AName) is TJSONObject then
    Result := TJSONObject(ARoot.Find(AName));
end;

function RunNativeScript(const ACommand, ADirectory: string): Boolean;
var
  LProcess: TProcess;
begin
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := '/bin/sh';
    LProcess.Parameters.Add('-lc');
    LProcess.Parameters.Add(ACommand);
    LProcess.CurrentDirectory := ADirectory;
    LProcess.Options := [poWaitOnExit];
    LProcess.Execute;
    Result := LProcess.ExitStatus = 0;
  finally
    LProcess.Free;
  end;
end;

function DependencyTree(const ADirectory: string): TStringList;
var
  LLock, LInstalled, LEntry: TJSONObject;
  LKeys: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  LLock := LoadJsonObject(IncludeTrailingPathDelimiter(ADirectory) +
    'boss-lock.json');
  LKeys := TStringList.Create;
  try
    LInstalled := FindObject(LLock, 'installedModules');
    if not Assigned(LInstalled) then Exit;
    for I := 0 to LInstalled.Count - 1 do LKeys.Add(LInstalled.Names[I]);
    LKeys.Sort;
    for I := 0 to LKeys.Count - 1 do
    begin
      LEntry := TJSONObject(LInstalled.Find(LKeys[I]));
      Result.Add(LKeys[I] + '@' + LEntry.Get('version', '') + ' [' +
        LEntry.Get('scope', 'runtime') + ']');
    end;
  finally
    LKeys.Free;
    LLock.Free;
  end;
end;

function WhyDependency(const ADirectory,
  ADependency: string): TStringList;
var
  LTree: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  LTree := DependencyTree(ADirectory);
  try
    for I := 0 to LTree.Count - 1 do
      if (Pos(LowerCase(ADependency) + '@', LowerCase(LTree[I])) = 1) or
         (Pos('/' + LowerCase(ADependency) + '@',
           LowerCase(LTree[I])) > 0) then
        Result.Add('root -> ' + LTree[I]);
  finally
    LTree.Free;
  end;
end;

function NativeLatest(const ARepository, AConstraint: string): string;
begin
  Result := ResolveLatestVersion(ARepository, AConstraint);
end;

procedure AppendOutdated(const AManifest, AInstalled: TJSONObject;
  const ASection: string; const AProvider: TBoss4DVersionProvider;
  const AResult: TStrings);
var
  LDependencies, LEntry: TJSONObject;
  I: Integer;
  LRepository, LConstraint, LCurrent, LLatest: string;
begin
  LDependencies := FindObject(AManifest, ASection);
  if not Assigned(LDependencies) then Exit;
  for I := 0 to LDependencies.Count - 1 do
  begin
    LRepository := LDependencies.Names[I];
    LConstraint := LDependencies.Items[I].AsString;
    LCurrent := '';
    if Assigned(AInstalled) and
       (AInstalled.Find(LRepository) is TJSONObject) then
    begin
      LEntry := TJSONObject(AInstalled.Find(LRepository));
      LCurrent := LEntry.Get('version', '');
    end;
    if Assigned(AProvider) then
      LLatest := AProvider(LRepository, LConstraint)
    else
      LLatest := NativeLatest(LRepository, LConstraint);
    if (LLatest <> '') and not SameText(LCurrent, LLatest) then
      AResult.Add(LRepository + ' ' + LCurrent + ' -> ' + LLatest);
  end;
end;

function OutdatedDependencies(const ADirectory: string;
  const AProvider: TBoss4DVersionProvider): TStringList;
var
  LManifest, LLock, LInstalled: TJSONObject;
begin
  Result := TStringList.Create;
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(ADirectory) +
    'boss.json');
  LLock := LoadJsonObject(IncludeTrailingPathDelimiter(ADirectory) +
    'boss-lock.json');
  try
    LInstalled := FindObject(LLock, 'installedModules');
    AppendOutdated(LManifest, LInstalled, 'dependencies', AProvider, Result);
    AppendOutdated(LManifest, LInstalled, 'devDependencies', AProvider, Result);
    Result.Sort;
  finally
    LLock.Free;
    LManifest.Free;
  end;
end;

procedure RunProjectScript(const ADirectory, AName: string;
  const ARunner: TBoss4DScriptRunner);
var
  LManifest, LScripts: TJSONObject;
  LCommand: string;
begin
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(ADirectory) +
    'boss.json');
  try
    LScripts := FindObject(LManifest, 'scripts');
    if not Assigned(LScripts) or not Assigned(LScripts.Find(AName)) then
      raise Exception.Create('project script not found: ' + AName);
    LCommand := LScripts.Get(AName, '');
    if Assigned(ARunner) then
    begin
      if not ARunner(LCommand, ADirectory) then
        raise Exception.Create('project script failed: ' + AName);
    end
    else if not RunNativeScript(LCommand, ADirectory) then
      raise Exception.Create('project script failed: ' + AName);
  finally
    LManifest.Free;
  end;
end;

procedure CopyFileBytes(const ASource, ATarget: string);
var
  LInput, LOutput: TFileStream;
begin
  LInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    LOutput := TFileStream.Create(ATarget, fmCreate);
    try
      LOutput.CopyFrom(LInput, 0);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

procedure DeleteTree(const ADirectory: string);
var
  LSearch: TSearchRec;
  LPath: string;
begin
  if not DirectoryExists(ADirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile,
    LSearch) = 0 then
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then DeleteTree(LPath)
      else DeleteFile(LPath);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  RemoveDir(ADirectory);
end;

procedure CopyTree(const ASource, ATarget: string);
var
  LSearch: TSearchRec;
  LSourcePath, LTargetPath: string;
begin
  if not DirectoryExists(ASource) then Exit;
  ForceDirectories(ATarget);
  if FindFirst(IncludeTrailingPathDelimiter(ASource) + '*', faAnyFile,
    LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LSourcePath := IncludeTrailingPathDelimiter(ASource) + LSearch.Name;
      LTargetPath := IncludeTrailingPathDelimiter(ATarget) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        CopyTree(LSourcePath, LTargetPath)
      else
        CopyFileBytes(LSourcePath, LTargetPath);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

procedure RestoreArtifactTargets(const ALockPath, ABackupModules,
  AModules: string);
var
  LLock, LInstalled, LEntry: TJSONObject;
  I: Integer;
  LTarget, LRelative: string;
begin
  if not FileExists(ALockPath) then Exit;
  LLock := LoadJsonObject(ALockPath);
  try
    LInstalled := FindObject(LLock, 'installedModules');
    if not Assigned(LInstalled) then Exit;
    for I := 0 to LInstalled.Count - 1 do
      if LInstalled.Items[I] is TJSONObject then
      begin
        LEntry := TJSONObject(LInstalled.Items[I]);
        if not SameText(LEntry.Get('resolvedFrom', ''),
          'registry-artifact') then Continue;
        LTarget := StringReplace(LEntry.Get('target', ''), '\', '/',
          [rfReplaceAll]);
        if Pos('modules/', LowerCase(LTarget)) <> 1 then
          raise Exception.Create('unsafe artifact update target: ' + LTarget);
        LRelative := Copy(LTarget, Length('modules/') + 1, MaxInt);
        if (LRelative = '') or (Pos('../', LRelative) > 0) then
          raise Exception.Create('unsafe artifact update target: ' + LTarget);
        CopyTree(IncludeTrailingPathDelimiter(ABackupModules) + LRelative,
          IncludeTrailingPathDelimiter(AModules) + LRelative);
      end;
  finally
    LLock.Free;
  end;
end;

procedure UpdateProject(const ADirectory: string);
var
  LModules, LModulesBackup, LLock, LLockBackup: string;
  LOptions: TBoss4DInstallOptions;
begin
  LModules := IncludeTrailingPathDelimiter(ADirectory) + 'modules';
  LModulesBackup := LModules + '.boss4d-update-backup';
  LLock := IncludeTrailingPathDelimiter(ADirectory) + 'boss-lock.json';
  LLockBackup := LLock + '.boss4d-update-backup';
  if DirectoryExists(LModulesBackup) or FileExists(LLockBackup) then
    raise Exception.Create('stale update backup exists');
  if DirectoryExists(LModules) and not RenameFile(LModules, LModulesBackup) then
    raise Exception.Create('unable to stage modules update');
  if FileExists(LLock) then CopyFileBytes(LLock, LLockBackup);
  try
    RestoreArtifactTargets(LLock, LModulesBackup, LModules);
    FillChar(LOptions, SizeOf(LOptions), 0);
    LOptions.Resolution := 'highest';
    InstallProject(ADirectory, LOptions);
    DeleteTree(LModulesBackup);
    DeleteFile(LLockBackup);
  except
    DeleteTree(LModules);
    if DirectoryExists(LModulesBackup) then
      RenameFile(LModulesBackup, LModules);
    if FileExists(LLockBackup) then
    begin
      DeleteFile(LLock);
      RenameFile(LLockBackup, LLock);
    end;
    raise;
  end;
end;

end.
