unit Boss4D.Posix.Update;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DUpdateFetcher = function: string of object;
  TBoss4DUpdateDownloader = function(const AUrl,
    ATarget: string): Boolean of object;
  TBoss4DUpdateExtractor = function(const AArchive,
    ATargetDirectory: string): Boolean of object;

  TBoss4DUpdateResult = record
    Updated: Boolean;
    Version: string;
  end;

  TBoss4DPosixUpdateService = class
  private
    FFetcher: TBoss4DUpdateFetcher;
    FDownloader: TBoss4DUpdateDownloader;
    FExtractor: TBoss4DUpdateExtractor;
  public
    constructor Create; overload;
    constructor Create(const AFetcher: TBoss4DUpdateFetcher;
      const ADownloader: TBoss4DUpdateDownloader;
      const AExtractor: TBoss4DUpdateExtractor); overload;
    function Execute(const ACurrentVersion,
      AExecutablePath: string): TBoss4DUpdateResult;
  end;

function CompareVersions(const ALeft, ARight: string): Integer;

implementation

uses
  fpjson, jsonparser, fphttpclient, opensslsockets, process, BaseUnix,
  Boss4D.Posix.Package, Boss4D.Posix.Core;

constructor TBoss4DPosixUpdateService.Create;
begin
  Create(nil, nil, nil);
end;

function VersionPart(const AVersion: string; const AIndex: Integer): Integer;
var
  LValue: string;
  LParts: TStringList;
begin
  LValue := AVersion;
  if (Length(LValue) > 0) and (LowerCase(LValue[1]) = 'v') then Delete(LValue, 1, 1);
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '.';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := LValue;
    if AIndex < LParts.Count then Result := StrToIntDef(LParts[AIndex], 0)
    else Result := 0;
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

function NativeFetchRelease: string;
var
  LClient: TFPHTTPClient;
begin
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.AllowRedirect := True;
    LClient.AddHeader('Accept', 'application/vnd.github+json');
    LClient.AddHeader('User-Agent', 'Boss4D/' + Boss4DVersion);
    Result := LClient.Get(
      'https://api.github.com/repos/regyssilveira/Boss4Delphi/releases/latest');
  finally
    LClient.Free;
  end;
end;

function NativeDownload(const AUrl, ATarget: string): Boolean;
var
  LClient: TFPHTTPClient;
  LStream: TFileStream;
begin
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.AllowRedirect := True;
    LStream := TFileStream.Create(ATarget, fmCreate);
    try
      LClient.Get(AUrl, LStream);
      Result := True;
    finally
      LStream.Free;
    end;
  finally
    LClient.Free;
  end;
end;

function NativeExtract(const AArchive, ATargetDirectory: string): Boolean;
var
  LOutput: string;
begin
  ForceDirectories(ATargetDirectory);
  Result := RunCommand('tar',
    ['-xzf', AArchive, '-C', ATargetDirectory], LOutput);
end;

constructor TBoss4DPosixUpdateService.Create(
  const AFetcher: TBoss4DUpdateFetcher;
  const ADownloader: TBoss4DUpdateDownloader;
  const AExtractor: TBoss4DUpdateExtractor);
begin
  inherited Create;
  FFetcher := AFetcher;
  FDownloader := ADownloader;
  FExtractor := AExtractor;
end;

function FindAssetUrl(const AAssets: TJSONArray; const AName: string): string;
var
  I: Integer;
  LAsset: TJSONObject;
begin
  Result := '';
  for I := 0 to AAssets.Count - 1 do
    if AAssets.Items[I] is TJSONObject then
    begin
      LAsset := TJSONObject(AAssets.Items[I]);
      if SameText(LAsset.Get('name', ''), AName) then
        Exit(LAsset.Get('browser_download_url', ''));
    end;
end;

function ReadExpectedHash(const APath, AAssetName: string): string;
var
  LLines: TStringList;
  I: Integer;
  LLine: string;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(APath);
    for I := 0 to LLines.Count - 1 do
    begin
      LLine := Trim(LLines[I]);
      if (Length(LLine) >= 66) and
         SameText(Trim(Copy(LLine, 67, MaxInt)), AAssetName) then
        Exit(LowerCase(Copy(LLine, 1, 64)));
    end;
  finally
    LLines.Free;
  end;
end;

function FindExtractedBinary(const ADirectory: string): string;
var
  LSearch: TSearchRec;
  LPath: string;
begin
  Result := '';
  LPath := IncludeTrailingPathDelimiter(ADirectory) + 'boss4d';
  if FileExists(LPath) then Exit(LPath);
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faDirectory, LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') or
         ((LSearch.Attr and faDirectory) = 0) then Continue;
      Result := FindExtractedBinary(
        IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name);
      if Result <> '' then Exit;
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function TBoss4DPosixUpdateService.Execute(const ACurrentVersion,
  AExecutablePath: string): TBoss4DUpdateResult;
const
  ASSET_NAME = 'boss4d-linux-x86_64.tar.gz';
var
  LData: TJSONData;
  LRoot: TJSONObject;
  LAssets: TJSONArray;
  LRelease, LAssetUrl, LChecksumsUrl, LTemp, LArchive, LChecksums,
    LExtract, LBinary, LExpected, LBackup: string;
  LDownloaded, LExtracted: Boolean;
begin
  Result.Updated := False;
  Result.Version := ACurrentVersion;
  if Assigned(FFetcher) then LRelease := FFetcher()
  else LRelease := NativeFetchRelease;
  LData := GetJSON(LRelease);
  try
    if not (LData is TJSONObject) then
      raise Exception.Create('release response root must be an object');
    LRoot := TJSONObject(LData);
    Result.Version := LRoot.Get('tag_name', '');
    if Result.Version = '' then raise Exception.Create('release tag is missing');
    if CompareVersions(ACurrentVersion, Result.Version) >= 0 then Exit;
    if not (LRoot.Find('assets') is TJSONArray) then
      raise Exception.Create('release assets are missing');
    LAssets := TJSONArray(LRoot.Find('assets'));
    LAssetUrl := FindAssetUrl(LAssets, ASSET_NAME);
    LChecksumsUrl := FindAssetUrl(LAssets, 'SHA256SUMS.txt');
    if (LAssetUrl = '') or (LChecksumsUrl = '') then
      raise Exception.Create('Linux update assets are missing');
  finally
    LData.Free;
  end;
  LTemp := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'boss4d-update-' + IntToHex(Random(MaxInt), 8);
  LArchive := IncludeTrailingPathDelimiter(LTemp) + ASSET_NAME;
  LChecksums := IncludeTrailingPathDelimiter(LTemp) + 'SHA256SUMS.txt';
  LExtract := IncludeTrailingPathDelimiter(LTemp) + 'extract';
  LBackup := ExpandFileName(AExecutablePath) + '.previous';
  ForceDirectories(LTemp);
  if Assigned(FDownloader) then
  begin
    LDownloaded := FDownloader(LAssetUrl, LArchive) and
      FDownloader(LChecksumsUrl, LChecksums);
  end
  else
    LDownloaded := NativeDownload(LAssetUrl, LArchive) and
      NativeDownload(LChecksumsUrl, LChecksums);
  if not LDownloaded then raise Exception.Create('update download failed');
  LExpected := ReadExpectedHash(LChecksums, ASSET_NAME);
  if (LExpected = '') or not SameText(Sha256File(LArchive), LExpected) then
    raise Exception.Create('update SHA-256 mismatch');
  if Assigned(FExtractor) then
    LExtracted := FExtractor(LArchive, LExtract)
  else
    LExtracted := NativeExtract(LArchive, LExtract);
  if not LExtracted then raise Exception.Create('update extraction failed');
  LBinary := FindExtractedBinary(LExtract);
  if LBinary = '' then raise Exception.Create('updated binary is missing');
  if FileExists(LBackup) then DeleteFile(LBackup);
  if FileExists(AExecutablePath) and not RenameFile(AExecutablePath, LBackup) then
    raise Exception.Create('unable to backup current executable');
  try
    if not RenameFile(LBinary, AExecutablePath) then
      raise Exception.Create('unable to install updated executable');
    fpChmod(PChar(AExecutablePath), &755);
    DeleteFile(LBackup);
  except
    if FileExists(LBackup) and not FileExists(AExecutablePath) then
      RenameFile(LBackup, AExecutablePath);
    raise;
  end;
  Result.Updated := True;
end;

end.
