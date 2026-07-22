unit Boss4D.Core.Services.SourceNormalizer;

interface

uses
  System.SysUtils;

type
  TBoss4DSourceNormalizer = class
  private
    class function IsDelphiSource(const AFileName: string): Boolean; static;
    class function IsBinary(const AContent: TBytes): Boolean; static;
  public
    class function NormalizeFileToCRLF(const AFileName: string): Boolean; static;
    class procedure NormalizeDirectoryToCRLF(const ADirectory: string); static;
  end;

implementation

uses
  System.IOUtils;

class function TBoss4DSourceNormalizer.IsDelphiSource(
  const AFileName: string): Boolean;
var
  LExtension: string;
begin
  LExtension := TPath.GetExtension(AFileName).ToLower;
  Result := (LExtension = '.pas') or (LExtension = '.inc') or
    (LExtension = '.dfm') or (LExtension = '.dpk') or
    (LExtension = '.dproj') or (LExtension = '.lpi') or
    (LExtension = '.lpk');
end;

class function TBoss4DSourceNormalizer.IsBinary(const AContent: TBytes): Boolean;
begin
  for var LByte in AContent do
    if LByte = 0 then
      Exit(True);
  Result := False;
end;

class function TBoss4DSourceNormalizer.NormalizeFileToCRLF(
  const AFileName: string): Boolean;
var
  LContent, LNormalized: TBytes;
  LIndex, LOutputIndex: Integer;
begin
  Result := False;
  LContent := TFile.ReadAllBytes(AFileName);
  if IsBinary(LContent) then
    Exit;
  SetLength(LNormalized, Length(LContent) * 2);
  LOutputIndex := 0;
  for LIndex := 0 to High(LContent) do
  begin
    if (LContent[LIndex] = 10) and
       ((LIndex = 0) or (LContent[LIndex - 1] <> 13)) then
    begin
      LNormalized[LOutputIndex] := 13;
      Inc(LOutputIndex);
      Result := True;
    end;
    LNormalized[LOutputIndex] := LContent[LIndex];
    Inc(LOutputIndex);
  end;
  if Result then
  begin
    SetLength(LNormalized, LOutputIndex);
    TFile.WriteAllBytes(AFileName, LNormalized);
  end;
end;

class procedure TBoss4DSourceNormalizer.NormalizeDirectoryToCRLF(
  const ADirectory: string);
begin
  if not TDirectory.Exists(ADirectory) then
    Exit;
  for var LFileName in TDirectory.GetFiles(ADirectory, '*',
    TSearchOption.soAllDirectories) do
    if IsDelphiSource(LFileName) then
      NormalizeFileToCRLF(LFileName);
end;

end.
