unit Boss4D.Posix.Tools;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DToolCompiler = function(const ASourceDirectory, AOutputPath: string):
    Boolean of object;

  TBoss4DPosixToolService = class
  private
    FHome: string;
    FCompiler: TBoss4DToolCompiler;
    function PrepareSource(const ASource: string;
      out ATemporary: Boolean): string;
    function Compile(const ASourceDirectory, AOutputPath: string): Boolean;
    procedure RecordTool(const AName, ASource, ADigest: string);
  public
    constructor Create(const AHome: string = '';
      const ACompiler: TBoss4DToolCompiler = nil);
    function Install(const ASource, AName: string): string;
    procedure Uninstall(const AName: string);
    function List: TStringList;
  end;

implementation

uses
  process, BaseUnix, fpjson, jsonparser, Boss4D.Posix.Package,
  Boss4D.Posix.Workflows;

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

function CloneSource(const ASource, ATarget: string): Boolean;
var
  LProcess: TProcess;
  LToken: string;
  I: Integer;
begin
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := 'git';
    LProcess.Parameters.Add('clone');
    LProcess.Parameters.Add('--depth');
    LProcess.Parameters.Add('1');
    LProcess.Parameters.Add(NormalizeRepositoryUrl(ASource));
    LProcess.Parameters.Add(ATarget);
    LToken := CredentialForRepository(ASource);
    if LToken <> '' then
    begin
      for I := 1 to GetEnvironmentVariableCount do
        LProcess.Environment.Add(GetEnvironmentString(I));
      LProcess.Environment.Add('GIT_CONFIG_COUNT=1');
      LProcess.Environment.Add('GIT_CONFIG_KEY_0=http.extraHeader');
      LProcess.Environment.Add('GIT_CONFIG_VALUE_0=Authorization: Bearer ' +
        LToken);
    end;
    LProcess.Options := [poWaitOnExit];
    LProcess.Execute;
    Result := LProcess.ExitStatus = 0;
  finally
    LProcess.Free;
  end;
end;

function FindProject(const ADirectory: string): string;
var
  LSearch: TSearchRec;
  LPath: string;
begin
  Result := '';
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*.lpr',
    faAnyFile, LSearch) = 0 then
  try
    repeat
      if (LSearch.Attr and faDirectory) = 0 then
        Exit(IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faDirectory, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') or
         (LSearch.Name = '.git') or
         ((LSearch.Attr and faDirectory) = 0) then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      Result := FindProject(LPath);
      if Result <> '' then Exit;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function NativeCompile(const ASourceDirectory, AOutputPath: string): Boolean;
var
  LProject, LOutput: string;
begin
  LProject := FindProject(ASourceDirectory);
  if LProject = '' then
    raise Exception.Create('FPC .lpr project was not found');
  ForceDirectories(ExtractFileDir(AOutputPath));
  Result := RunCommand('fpc',
    ['-B', '-o' + AOutputPath, LProject], LOutput);
end;

constructor TBoss4DPosixToolService.Create(const AHome: string;
  const ACompiler: TBoss4DToolCompiler);
begin
  inherited Create;
  FHome := AHome;
  if FHome = '' then
  begin
    FHome := GetEnvironmentVariable('BOSS_HOME');
    if FHome = '' then
      FHome := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
        '.boss';
  end;
  FHome := ExpandFileName(FHome);
  FCompiler := ACompiler;
end;

function TBoss4DPosixToolService.PrepareSource(const ASource: string;
  out ATemporary: Boolean): string;
begin
  ATemporary := not DirectoryExists(ASource);
  if not ATemporary then Exit(ExpandFileName(ASource));
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'boss4d-tool-' + IntToHex(Random(MaxInt), 8);
  if not CloneSource(ASource, Result) then
    raise Exception.Create('unable to clone tool source');
end;

function TBoss4DPosixToolService.Compile(const ASourceDirectory,
  AOutputPath: string): Boolean;
begin
  if Assigned(FCompiler) then
    Result := FCompiler(ASourceDirectory, AOutputPath)
  else
    Result := NativeCompile(ASourceDirectory, AOutputPath);
end;

function LoadTools(const APath: string): TJSONObject;
var
  LStream: TFileStream;
  LData: TJSONData;
begin
  if not FileExists(APath) then Exit(TJSONObject.Create);
  LStream := TFileStream.Create(APath, fmOpenRead);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('global tools registry is invalid');
  end;
  Result := TJSONObject(LData);
end;

procedure SaveTools(const APath: string; const ARoot: TJSONObject);
var
  LContent: TStringList;
begin
  ForceDirectories(ExtractFileDir(APath));
  LContent := TStringList.Create;
  try
    LContent.Text := ARoot.FormatJSON;
    LContent.SaveToFile(APath);
  finally
    LContent.Free;
  end;
end;

procedure TBoss4DPosixToolService.RecordTool(const AName, ASource,
  ADigest: string);
var
  LPath: string;
  LRoot, LEntry: TJSONObject;
begin
  LPath := IncludeTrailingPathDelimiter(FHome) + 'tools.json';
  LRoot := LoadTools(LPath);
  try
    LRoot.Delete(AName);
    LEntry := TJSONObject.Create;
    LEntry.Add('source', ASource);
    LEntry.Add('sha256', ADigest);
    LRoot.Add(AName, LEntry);
    SaveTools(LPath, LRoot);
  finally
    LRoot.Free;
  end;
end;

function TBoss4DPosixToolService.Install(const ASource,
  AName: string): string;
var
  LSource, LName, LStage, LBackup: string;
  LTemporary: Boolean;
begin
  if Trim(ASource) = '' then raise Exception.Create('tool source is required');
  LSource := PrepareSource(ASource, LTemporary);
  try
    LName := AName;
    if LName = '' then
    begin
      LName := ExtractFileName(ExcludeTrailingPathDelimiter(ASource));
      if LowerCase(ExtractFileExt(LName)) = '.git' then
        LName := ChangeFileExt(LName, '');
    end;
    if (LName = '') or (Pos(DirectorySeparator, LName) > 0) or
       (LName = '.') or (LName = '..') then
      raise Exception.Create('invalid tool name');
    Result := IncludeTrailingPathDelimiter(FHome) + 'bin' +
      DirectorySeparator + LName;
    ForceDirectories(ExtractFileDir(Result));
    LStage := Result + '.stage';
    LBackup := Result + '.previous';
    if FileExists(LStage) then DeleteFile(LStage);
    if not Compile(LSource, LStage) or not FileExists(LStage) then
      raise Exception.Create('tool compilation failed');
    fpChmod(PChar(LStage), &755);
    if FileExists(LBackup) then DeleteFile(LBackup);
    if FileExists(Result) and not RenameFile(Result, LBackup) then
      raise Exception.Create('unable to backup installed tool');
    try
      if not RenameFile(LStage, Result) then
        raise Exception.Create('unable to install global tool');
      RecordTool(LName, ASource, Sha256File(Result));
      DeleteFile(LBackup);
    except
      if FileExists(LBackup) and not FileExists(Result) then
        RenameFile(LBackup, Result);
      raise;
    end;
  finally
    if LTemporary then DeleteTree(LSource);
  end;
end;

procedure TBoss4DPosixToolService.Uninstall(const AName: string);
var
  LRegistry, LBinary: string;
  LRoot: TJSONObject;
begin
  LBinary := IncludeTrailingPathDelimiter(FHome) + 'bin' +
    DirectorySeparator + AName;
  if FileExists(LBinary) then DeleteFile(LBinary);
  LRegistry := IncludeTrailingPathDelimiter(FHome) + 'tools.json';
  LRoot := LoadTools(LRegistry);
  try
    LRoot.Delete(AName);
    SaveTools(LRegistry, LRoot);
  finally
    LRoot.Free;
  end;
end;

function TBoss4DPosixToolService.List: TStringList;
var
  LRoot: TJSONObject;
  I: Integer;
begin
  Result := TStringList.Create;
  LRoot := LoadTools(IncludeTrailingPathDelimiter(FHome) + 'tools.json');
  try
    for I := 0 to LRoot.Count - 1 do Result.Add(LRoot.Names[I]);
    Result.Sort;
  finally
    LRoot.Free;
  end;
end;

end.
