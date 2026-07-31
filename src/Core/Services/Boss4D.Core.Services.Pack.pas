unit Boss4D.Core.Services.Pack;

interface

type
  TBoss4DPackResult = record
    OutputPath: string;
    Digest: string;
    FileCount: Integer;
    ProvenancePath: string;
  end;

  TBoss4DPackService = class
  private
    function IsExcluded(const ARoot, AFileName: string): Boolean;
  public
    function Execute(const ARootDirectory,
      AOutputPath: string): TBoss4DPackResult;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, System.NetEncoding,
  System.Generics.Collections, System.Hash;

function Sha256(const ABytes: TBytes): string;
var
  LHasher: THashSHA2;
begin
  LHasher := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  if Length(ABytes) > 0 then
    LHasher.Update(ABytes, Length(ABytes));
  Result := LHasher.HashAsString.ToLower;
end;

function TBoss4DPackService.IsExcluded(const ARoot,
  AFileName: string): Boolean;
var
  LRelative: string;
begin
  LRelative := AFileName.Substring(IncludeTrailingPathDelimiter(ARoot).Length)
    .Replace('\', '/');
  Result := SameText(LRelative, '.git') or
    LRelative.StartsWith('.git/', True) or
    LRelative.StartsWith('modules/', True) or
    LRelative.StartsWith('dist/', True) or
    LRelative.StartsWith('bin/', True) or
    LRelative.StartsWith('.codex-build/', True) or
    LRelative.StartsWith('.ci-build/', True) or
    LRelative.StartsWith('.fpc-build/', True) or
    LRelative.StartsWith('.release/', True) or
    LRelative.StartsWith('.release-test/', True) or
    LRelative.StartsWith('.scannerwork/', True) or
    LRelative.StartsWith('.benchmark-pack/', True) or
    LRelative.StartsWith('scratch/', True) or
    LRelative.StartsWith('tests/scratch/', True) or
    LRelative.StartsWith('tests/Win32/', True) or
    LRelative.StartsWith('tests/Win64/', True) or
    LRelative.StartsWith('src/Win32/', True) or
    LRelative.StartsWith('src/Win64/', True) or
    LRelative.StartsWith('installer/Output/', True) or
    LRelative.EndsWith('.dcu', True) or LRelative.EndsWith('.exe', True) or
    LRelative.EndsWith('.bpl', True) or LRelative.EndsWith('.dcp', True) or
    LRelative.EndsWith('.dsk', True) or LRelative.EndsWith('.map', True) or
    LRelative.EndsWith('.drc', True) or
    LRelative.EndsWith('.identcache', True);
end;

function TBoss4DPackService.Execute(const ARootDirectory,
  AOutputPath: string): TBoss4DPackResult;
var
  LRoot, LOutput, LRelative, LContent, LDigest: string;
  LFiles: TList<string>;
  LDocument, LFileObject: TJSONObject;
  LArray: TJSONArray;
  LBytes: TBytes;
begin
  Result := Default(TBoss4DPackResult);
  LRoot := TPath.GetFullPath(ARootDirectory);
  if not TFile.Exists(TPath.Combine(LRoot, 'boss.json')) then
    raise EFileNotFoundException.Create('boss.json nao encontrado.');
  LOutput := TPath.GetFullPath(AOutputPath);
  LFiles := TList<string>.Create;
  try
    for var LFile in TDirectory.GetFiles(LRoot, '*',
      TSearchOption.soAllDirectories) do
      if not IsExcluded(LRoot, LFile) and
         not SameText(TPath.GetFullPath(LFile), LOutput) then
        LFiles.Add(LFile);
    LFiles.Sort;
    LDocument := TJSONObject.Create;
    try
      LDocument.AddPair('format', 'boss4d-package');
      LDocument.AddPair('schemaVersion', TJSONNumber.Create(1));
      LArray := TJSONArray.Create;
      for var LFile in LFiles do
      begin
        LRelative := LFile.Substring(
          IncludeTrailingPathDelimiter(LRoot).Length).Replace('\', '/');
        if LRelative.StartsWith('../') or LRelative.Contains('/../') then
          raise EArgumentException.Create('Caminho fora da raiz: ' + LRelative);
        LBytes := TFile.ReadAllBytes(LFile);
        LDigest := Sha256(LBytes);
        LFileObject := TJSONObject.Create;
        LFileObject.AddPair('path', LRelative);
        LFileObject.AddPair('sha256', LDigest.ToLower);
        LFileObject.AddPair('content',
          TNetEncoding.Base64.EncodeBytesToString(LBytes));
        LArray.AddElement(LFileObject);
      end;
      LDocument.AddPair('files', LArray);
      LContent := LDocument.ToJSON;
    finally
      LDocument.Free;
    end;
    TDirectory.CreateDirectory(TPath.GetDirectoryName(LOutput));
    LBytes := TEncoding.UTF8.GetBytes(LContent);
    TFile.WriteAllBytes(LOutput, LBytes);
    Result.OutputPath := LOutput;
    Result.Digest := Sha256(LBytes);
    Result.FileCount := LFiles.Count;
    Result.ProvenancePath := LOutput + '.intoto.json';
    var LStatement := TJSONObject.Create;
    try
      LStatement.AddPair('_type',
        'https://in-toto.io/Statement/v1');
      LStatement.AddPair('predicateType',
        'https://boss4d.dev/pack/v1');
      var LSubject := TJSONArray.Create;
      var LSubjectEntry := TJSONObject.Create;
      LSubjectEntry.AddPair('name', TPath.GetFileName(LOutput));
      var LDigestObject := TJSONObject.Create;
      LDigestObject.AddPair('sha256', Result.Digest);
      LSubjectEntry.AddPair('digest', LDigestObject);
      LSubject.AddElement(LSubjectEntry);
      LStatement.AddPair('subject', LSubject);
      var LPredicate := TJSONObject.Create;
      LPredicate.AddPair('builder', 'boss4d/' + '1.6.0');
      LPredicate.AddPair('fileCount', TJSONNumber.Create(Result.FileCount));
      LStatement.AddPair('predicate', LPredicate);
      TFile.WriteAllBytes(Result.ProvenancePath,
        TEncoding.UTF8.GetBytes(LStatement.ToJSON));
    finally
      LStatement.Free;
    end;
  finally
    LFiles.Free;
  end;
end;

end.
