unit Boss4D.Core.Services.Pack;

interface

type
  TBoss4DPackResult = record
    OutputPath: string;
    Digest: string;
    FileCount: Integer;
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
  Result := LRelative.StartsWith('.git/', True) or
    LRelative.StartsWith('modules/', True) or
    LRelative.StartsWith('dist/', True) or
    LRelative.StartsWith('.codex-build/', True) or
    LRelative.StartsWith('scratch/', True) or
    LRelative.EndsWith('.dcu', True) or LRelative.EndsWith('.exe', True) or
    LRelative.EndsWith('.bpl', True) or LRelative.EndsWith('.dcp', True) or
    LRelative.EndsWith('.dsk', True);
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
  finally
    LFiles.Free;
  end;
end;

end.
