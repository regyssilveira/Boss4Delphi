unit Boss4D.Posix.Workflows;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DSecretToolRunner = function(const AArguments: TStrings;
    const AInput: string; out AOutput: string): Boolean of object;

  TBoss4DPosixCredentialStore = class
  private
    FRunner: TBoss4DSecretToolRunner;
    function Execute(const AArguments: TStrings; const AInput: string;
      out AOutput: string): Boolean;
  public
    constructor Create(const ARunner: TBoss4DSecretToolRunner = nil);
    procedure Store(const AProvider, AToken: string);
    function Retrieve(const AProvider: string): string;
    procedure Remove(const AProvider: string);
  end;

function MaskSecret(const AText, ASecret: string): string;
function NormalizeRepositoryUrl(const ARepository: string): string;
function CredentialForRepository(const ARepository: string): string;
function DirectorySize(const ADirectory: string): Int64;
function CleanCacheDirectory(const ADirectory: string): Integer;
function PruneCacheDirectory(const ADirectory: string;
  const ABefore: TDateTime): Integer;
function LinkDeclaredWorkspaces(const AProjectDirectory: string): Integer;

implementation

uses
  process, BaseUnix, fpjson, jsonparser, DateUtils;

function MaskSecret(const AText, ASecret: string): string;
begin
  Result := AText;
  if ASecret <> '' then
    Result := StringReplace(Result, ASecret, '***', [rfReplaceAll]);
end;

function NormalizeRepositoryUrl(const ARepository: string): string;
begin
  Result := ARepository;
  if (Pos('github.com/', LowerCase(Result)) = 1) or
     (Pos('gitlab.com/', LowerCase(Result)) = 1) then
    Result := 'https://' + Result;
end;

function CredentialForRepository(const ARepository: string): string;
var
  LProvider: string;
  LStore: TBoss4DPosixCredentialStore;
begin
  Result := '';
  if Pos('github.com/', LowerCase(ARepository)) > 0 then
  begin
    LProvider := 'github';
    Result := GetEnvironmentVariable('BOSS4D_GITHUB_TOKEN');
    if Result = '' then Result := GetEnvironmentVariable('GITHUB_TOKEN');
  end
  else if Pos('gitlab.com/', LowerCase(ARepository)) > 0 then
  begin
    LProvider := 'gitlab';
    Result := GetEnvironmentVariable('BOSS4D_GITLAB_TOKEN');
    if Result = '' then Result := GetEnvironmentVariable('GITLAB_TOKEN');
  end
  else
    Exit;
  if Result = '' then
  begin
    LStore := TBoss4DPosixCredentialStore.Create;
    try
      Result := LStore.Retrieve(LProvider);
    finally
      LStore.Free;
    end;
  end;
end;

function DefaultSecretToolRun(const AArguments: TStrings;
  const AInput: string; out AOutput: string): Boolean;
var
  LProcess: TProcess;
  I: Integer;
  LInput: RawByteString;
  LOutput: TStringStream;
begin
  if FileSearch('secret-tool', GetEnvironmentVariable('PATH')) = '' then
    Exit(False);
  LProcess := TProcess.Create(nil);
  LOutput := TStringStream.Create('');
  try
    LProcess.Executable := 'secret-tool';
    for I := 0 to AArguments.Count - 1 do
      LProcess.Parameters.Add(AArguments[I]);
    LProcess.Options := [poUsePipes];
    LProcess.Execute;
    LInput := UTF8Encode(AInput);
    if Length(LInput) > 0 then
      LProcess.Input.WriteBuffer(LInput[1], Length(LInput));
    LProcess.CloseInput;
    while LProcess.Running do Sleep(1);
    LOutput.CopyFrom(LProcess.Output, 0);
    AOutput := Trim(LOutput.DataString);
    Result := LProcess.ExitStatus = 0;
  finally
    LOutput.Free;
    LProcess.Free;
  end;
end;

constructor TBoss4DPosixCredentialStore.Create(
  const ARunner: TBoss4DSecretToolRunner);
begin
  inherited Create;
  FRunner := ARunner;
end;

function TBoss4DPosixCredentialStore.Execute(const AArguments: TStrings;
  const AInput: string; out AOutput: string): Boolean;
begin
  if Assigned(FRunner) then
    Result := FRunner(AArguments, AInput, AOutput)
  else
    Result := DefaultSecretToolRun(AArguments, AInput, AOutput);
end;

procedure TBoss4DPosixCredentialStore.Store(const AProvider,
  AToken: string);
var
  LArguments: TStringList;
  LOutput: string;
begin
  if Trim(AProvider) = '' then raise Exception.Create('provider is required');
  if AToken = '' then raise Exception.Create('token is required');
  LArguments := TStringList.Create;
  try
    LArguments.Add('store');
    LArguments.Add('--label=Boss4D ' + LowerCase(AProvider));
    LArguments.Add('service');
    LArguments.Add('Boss4D');
    LArguments.Add('provider');
    LArguments.Add(LowerCase(AProvider));
    if not Execute(LArguments, AToken, LOutput) then
      raise Exception.Create('Secret Service is unavailable');
  finally
    LArguments.Free;
  end;
end;

function TBoss4DPosixCredentialStore.Retrieve(
  const AProvider: string): string;
var
  LArguments: TStringList;
begin
  Result := '';
  LArguments := TStringList.Create;
  try
    LArguments.Add('lookup');
    LArguments.Add('service');
    LArguments.Add('Boss4D');
    LArguments.Add('provider');
    LArguments.Add(LowerCase(AProvider));
    if not Execute(LArguments, '', Result) then Result := '';
  finally
    LArguments.Free;
  end;
end;

procedure TBoss4DPosixCredentialStore.Remove(const AProvider: string);
var
  LArguments: TStringList;
  LOutput: string;
begin
  LArguments := TStringList.Create;
  try
    LArguments.Add('clear');
    LArguments.Add('service');
    LArguments.Add('Boss4D');
    LArguments.Add('provider');
    LArguments.Add(LowerCase(AProvider));
    if not Execute(LArguments, '', LOutput) then
      raise Exception.Create('credential was not removed');
  finally
    LArguments.Free;
  end;
end;

function DirectorySize(const ADirectory: string): Int64;
var
  LSearch: TSearchRec;
  LPath: string;
begin
  Result := 0;
  if not DirectoryExists(ADirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        Inc(Result, DirectorySize(LPath))
      else
        Inc(Result, LSearch.Size);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

procedure DeleteTree(const ADirectory: string);
var
  LSearch: TSearchRec;
  LPath: string;
begin
  if not DirectoryExists(ADirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) = 0 then
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

procedure ValidateCacheTarget(const ADirectory: string);
var
  LPath: string;
begin
  LPath := ExcludeTrailingPathDelimiter(ExpandFileName(ADirectory));
  if (LPath = '') or (LPath = DirectorySeparator) or
     SameText(LPath, ExcludeTrailingPathDelimiter(
       GetEnvironmentVariable('HOME'))) then
    raise Exception.Create('unsafe cache directory');
end;

function CleanCacheDirectory(const ADirectory: string): Integer;
var
  LSearch: TSearchRec;
  LPath: string;
begin
  ValidateCacheTarget(ADirectory);
  Result := 0;
  if not DirectoryExists(ADirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then DeleteTree(LPath)
      else DeleteFile(LPath);
      Inc(Result);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function PruneCacheDirectory(const ADirectory: string;
  const ABefore: TDateTime): Integer;
var
  LSearch: TSearchRec;
  LPath: string;
  LModified: TDateTime;
begin
  ValidateCacheTarget(ADirectory);
  Result := 0;
  if not DirectoryExists(ADirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faDirectory, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') or
         ((LSearch.Attr and faDirectory) = 0) then Continue;
      LModified := FileDateToDateTime(LSearch.Time);
      if LModified < ABefore then
      begin
        LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
        DeleteTree(LPath);
        Inc(Result);
      end;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function LoadObject(const APath: string): TJSONObject;
var
  LStream: TFileStream;
  LData: TJSONData;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('manifest root must be an object');
  end;
  Result := TJSONObject(LData);
end;

procedure LinkWorkspace(const ARoot, AWorkspace: string;
  var ACount: Integer);
var
  LTarget, LLink: string;
begin
  LTarget := IncludeTrailingPathDelimiter(ARoot) + 'modules';
  LLink := IncludeTrailingPathDelimiter(AWorkspace) + 'modules';
  ForceDirectories(LTarget);
  if DirectoryExists(LLink) or FileExists(LLink) then Exit;
  if fpSymlink(PChar(LTarget), PChar(LLink)) <> 0 then
    raise Exception.Create('unable to link workspace modules: ' + AWorkspace);
  Inc(ACount);
end;

procedure ExpandWorkspace(const ARoot, APattern: string; var ACount: Integer);
var
  LBase, LWorkspace: string;
  LSearch: TSearchRec;
begin
  if (Length(APattern) >= 2) and
     (Copy(APattern, Length(APattern) - 1, 2) = '/*') then
  begin
    LBase := IncludeTrailingPathDelimiter(ARoot) +
      Copy(APattern, 1, Length(APattern) - 2);
    if FindFirst(IncludeTrailingPathDelimiter(LBase) + '*',
      faDirectory, LSearch) <> 0 then Exit;
    try
      repeat
        if (LSearch.Name = '.') or (LSearch.Name = '..') or
           ((LSearch.Attr and faDirectory) = 0) then Continue;
        LWorkspace := IncludeTrailingPathDelimiter(LBase) + LSearch.Name;
        LinkWorkspace(ARoot, LWorkspace, ACount);
      until FindNext(LSearch) <> 0;
    finally
      FindClose(LSearch);
    end;
  end
  else
  begin
    LWorkspace := IncludeTrailingPathDelimiter(ARoot) + APattern;
    if DirectoryExists(LWorkspace) then
      LinkWorkspace(ARoot, LWorkspace, ACount);
  end;
end;

function LinkDeclaredWorkspaces(const AProjectDirectory: string): Integer;
var
  LManifest: TJSONObject;
  LWorkspaces: TJSONArray;
  I: Integer;
begin
  Result := 0;
  LManifest := LoadObject(IncludeTrailingPathDelimiter(AProjectDirectory) +
    'boss.json');
  try
    if not (LManifest.Find('workspaces') is TJSONArray) then Exit;
    LWorkspaces := TJSONArray(LManifest.Find('workspaces'));
    for I := 0 to LWorkspaces.Count - 1 do
      ExpandWorkspace(ExpandFileName(AProjectDirectory),
        LWorkspaces.Strings[I], Result);
  finally
    LManifest.Free;
  end;
end;

end.
