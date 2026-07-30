unit Boss4D.Posix.Config;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DPosixConfig = class
  private
    FPath: string;
    function LoadRoot: TObject;
    procedure SaveRegistries(const ARegistries: TStrings);
  public
    constructor Create(const APath: string = '');
    function Registries: TStringList;
    procedure AddRegistry(const ASource: string);
    procedure RemoveRegistry(const ASource: string);
  end;

function DefaultConfigPath: string;

implementation

uses
  fpjson, jsonparser;

function DefaultConfigPath: string;
var
  LHome: string;
begin
  LHome := GetEnvironmentVariable('BOSS_HOME');
  if LHome = '' then
    LHome := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
      '.boss';
  Result := IncludeTrailingPathDelimiter(LHome) + 'boss.cfg.json';
end;

constructor TBoss4DPosixConfig.Create(const APath: string);
begin
  inherited Create;
  if APath = '' then FPath := DefaultConfigPath
  else FPath := ExpandFileName(APath);
end;

function TBoss4DPosixConfig.LoadRoot: TObject;
var
  LStream: TFileStream;
  LData: TJSONData;
begin
  if not FileExists(FPath) then Exit(TJSONObject.Create);
  LStream := TFileStream.Create(FPath, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('global config root must be an object');
  end;
  Result := LData;
end;

function TBoss4DPosixConfig.Registries: TStringList;
var
  LRoot: TJSONObject;
  LData: TJSONData;
  LArray: TJSONArray;
  I: Integer;
begin
  Result := TStringList.Create;
  LRoot := TJSONObject(LoadRoot);
  try
    LData := LRoot.Find('registries');
    if not (LData is TJSONArray) then Exit;
    LArray := TJSONArray(LData);
    for I := 0 to LArray.Count - 1 do
      if Result.IndexOf(LArray.Strings[I]) < 0 then
        Result.Add(LArray.Strings[I]);
  finally
    LRoot.Free;
  end;
end;

procedure TBoss4DPosixConfig.SaveRegistries(const ARegistries: TStrings);
var
  LRoot: TJSONObject;
  LArray: TJSONArray;
  LStream: TStringList;
  I: Integer;
begin
  LRoot := TJSONObject(LoadRoot);
  try
    LRoot.Delete('registries');
    LArray := TJSONArray.Create;
    for I := 0 to ARegistries.Count - 1 do
      LArray.Add(ARegistries[I]);
    LRoot.Add('registries', LArray);
    ForceDirectories(ExtractFileDir(FPath));
    LStream := TStringList.Create;
    try
      LStream.Text := LRoot.FormatJSON;
      LStream.SaveToFile(FPath);
    finally
      LStream.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TBoss4DPosixConfig.AddRegistry(const ASource: string);
var
  LRegistries: TStringList;
begin
  if Trim(ASource) = '' then
    raise Exception.Create('registry source is required');
  LRegistries := Registries;
  try
    if LRegistries.IndexOf(ASource) < 0 then LRegistries.Add(ASource);
    SaveRegistries(LRegistries);
  finally
    LRegistries.Free;
  end;
end;

procedure TBoss4DPosixConfig.RemoveRegistry(const ASource: string);
var
  LRegistries: TStringList;
  I: Integer;
begin
  LRegistries := Registries;
  try
    for I := LRegistries.Count - 1 downto 0 do
      if SameText(LRegistries[I], ASource) then LRegistries.Delete(I);
    SaveRegistries(LRegistries);
  finally
    LRegistries.Free;
  end;
end;

end.
