unit Boss4D.Posix.Pack;

{$mode objfpc}{$H+}

interface

type
  TBoss4DPosixPackResult = record
    OutputPath: string;
    Digest: string;
    FileCount: Integer;
    ProvenancePath: string;
  end;

function PackProject(const ARootDirectory,
  AOutputPath: string): TBoss4DPosixPackResult;

implementation

uses
  Classes, SysUtils, fpjson, base64, Boss4D.Posix.Package,
  Boss4D.Posix.Core;

function IsExcluded(const ARelative: string): Boolean;
var
  LPath: string;
begin
  LPath := LowerCase(StringReplace(ARelative, '\', '/', [rfReplaceAll]));
  Result := (Pos('.git/', LPath) = 1) or (Pos('modules/', LPath) = 1) or
    (Pos('dist/', LPath) = 1) or (Pos('.codex-build/', LPath) = 1) or
    (Pos('scratch/', LPath) = 1) or
    (ExtractFileExt(LPath) = '.dcu') or (ExtractFileExt(LPath) = '.exe') or
    (ExtractFileExt(LPath) = '.bpl') or (ExtractFileExt(LPath) = '.dcp') or
    (ExtractFileExt(LPath) = '.dsk');
end;

procedure CollectFiles(const ARoot, ADirectory, AOutput: string;
  const AFiles: TStrings);
var
  LSearch: TSearchRec;
  LPath, LRelative: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile,
    LSearch) <> 0 then Exit;
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      LRelative := Copy(LPath, Length(IncludeTrailingPathDelimiter(ARoot)) + 1,
        MaxInt);
      if IsExcluded(LRelative) then Continue;
      if (LSearch.Attr and faDirectory) <> 0 then
        CollectFiles(ARoot, LPath, AOutput, AFiles)
      else if not SameText(ExpandFileName(LPath), ExpandFileName(AOutput)) then
        AFiles.Add(LPath);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
end;

function ReadRaw(const APath: string): RawByteString;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then LStream.ReadBuffer(Result[1], LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure SaveUtf8(const APath, AContent: string);
var
  LStream: TStringStream;
begin
  ForceDirectories(ExtractFileDir(ExpandFileName(APath)));
  LStream := TStringStream.Create(AContent, TEncoding.UTF8);
  try
    LStream.SaveToFile(APath);
  finally
    LStream.Free;
  end;
end;

function PackProject(const ARootDirectory,
  AOutputPath: string): TBoss4DPosixPackResult;
var
  LRoot, LRelative, LRaw: string;
  LFiles: TStringList;
  LDocument, LFileObject, LStatement, LSubjectEntry, LDigestObject,
    LPredicate: TJSONObject;
  LArray, LSubject: TJSONArray;
  I: Integer;
begin
  Result.OutputPath := ExpandFileName(AOutputPath);
  Result.Digest := '';
  Result.FileCount := 0;
  Result.ProvenancePath := Result.OutputPath + '.intoto.json';
  LRoot := ExpandFileName(ARootDirectory);
  if not FileExists(IncludeTrailingPathDelimiter(LRoot) + 'boss.json') then
    raise Exception.Create('boss.json not found');
  LFiles := TStringList.Create;
  try
    LFiles.Sorted := True;
    CollectFiles(LRoot, LRoot, Result.OutputPath, LFiles);
    LDocument := TJSONObject.Create;
    try
      LDocument.Add('format', 'boss4d-package');
      LDocument.Add('schemaVersion', 1);
      LArray := TJSONArray.Create;
      LDocument.Add('files', LArray);
      for I := 0 to LFiles.Count - 1 do
      begin
        LRelative := StringReplace(Copy(LFiles[I],
          Length(IncludeTrailingPathDelimiter(LRoot)) + 1, MaxInt), '\', '/',
          [rfReplaceAll]);
        LRaw := ReadRaw(LFiles[I]);
        LFileObject := TJSONObject.Create;
        LFileObject.Add('path', LRelative);
        LFileObject.Add('sha256', Sha256File(LFiles[I]));
        LFileObject.Add('content', EncodeStringBase64(LRaw));
        LArray.Add(LFileObject);
      end;
      SaveUtf8(Result.OutputPath, LDocument.AsJSON);
    finally
      LDocument.Free;
    end;
    Result.Digest := Sha256File(Result.OutputPath);
    Result.FileCount := LFiles.Count;
    LStatement := TJSONObject.Create;
    try
      LStatement.Add('_type', 'https://in-toto.io/Statement/v1');
      LStatement.Add('predicateType', 'https://boss4d.dev/pack/v1');
      LSubject := TJSONArray.Create;
      LStatement.Add('subject', LSubject);
      LSubjectEntry := TJSONObject.Create;
      LSubjectEntry.Add('name', 'package.b4dpkg');
      LDigestObject := TJSONObject.Create;
      LDigestObject.Add('sha256', Result.Digest);
      LSubjectEntry.Add('digest', LDigestObject);
      LSubject.Add(LSubjectEntry);
      LPredicate := TJSONObject.Create;
      LPredicate.Add('builder', 'boss4d/' + Boss4DVersion);
      LPredicate.Add('fileCount', Result.FileCount);
      LStatement.Add('predicate', LPredicate);
      SaveUtf8(Result.ProvenancePath, LStatement.AsJSON);
    finally
      LStatement.Free;
    end;
  finally
    LFiles.Free;
  end;
end;

end.
