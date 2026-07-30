unit Boss4D.Posix.Core;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson;

function Boss4DVersion: string;
function PlatformName: string;
function DefaultManifest: string;
function LoadJsonObject(const AFileName: string): TJSONObject;
function DependencyTarget(const ARepository: string): string;
function BuildCloneArguments(const ARepository, AVersion,
  ATarget: string): TStringList;
procedure InitProject(const ADirectory: string);
procedure InstallProject(const ADirectory: string);

implementation

uses
  jsonparser, process;

function Boss4DVersion: string;
begin
  Result := '1.4.0';
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

procedure InitProject(const ADirectory: string);
var
  LFile: TextFile;
  LPath: string;
begin
  LPath := IncludeTrailingPathDelimiter(ADirectory) + 'boss.json';
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

procedure InstallProject(const ADirectory: string);
var
  LManifest, LDependencies: TJSONObject;
  I: Integer;
  LRepository, LVersion, LTarget: string;
  LProcess: TProcess;
  LArguments: TStringList;
begin
  LManifest := LoadJsonObject(IncludeTrailingPathDelimiter(ADirectory) +
    'boss.json');
  try
    LDependencies := LManifest.Objects['dependencies'];
    if not Assigned(LDependencies) then
      Exit;
    ForceDirectories(IncludeTrailingPathDelimiter(ADirectory) + 'modules');
    for I := 0 to LDependencies.Count - 1 do
    begin
      LRepository := LDependencies.Names[I];
      LVersion := LDependencies.Strings[LRepository];
      LTarget := IncludeTrailingPathDelimiter(ADirectory) + 'modules' +
        DirectorySeparator + DependencyTarget(LRepository);
      if DirectoryExists(LTarget) then
        Continue;
      LArguments := BuildCloneArguments(LRepository, LVersion, LTarget);
      LProcess := TProcess.Create(nil);
      try
        LProcess.Executable := 'git';
        LProcess.Parameters.Assign(LArguments);
        LProcess.Options := [poWaitOnExit];
        LProcess.Execute;
        if LProcess.ExitStatus <> 0 then
          raise Exception.CreateFmt('git clone failed for %s',
            [LRepository]);
      finally
        LProcess.Free;
        LArguments.Free;
      end;
    end;
  finally
    LManifest.Free;
  end;
end;

end.
