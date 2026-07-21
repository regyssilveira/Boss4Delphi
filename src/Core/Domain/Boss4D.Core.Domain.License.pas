unit Boss4D.Core.Domain.License;

interface

uses
  Boss4D.Core.Domain.Sbom;

type
  TBoss4DLicenseNormalizer = class
  private
    class function IsKnownSpdxId(const AValue: string): Boolean; static;
    class function IsSpdxExpression(const AValue: string): Boolean; static;
  public
    class function Normalize(const AValue, ASource: string): TBoss4DSbomLicense; static;
    class function KindName(const AKind: TBoss4DSbomLicenseKind): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressions;

class function TBoss4DLicenseNormalizer.IsKnownSpdxId(const AValue: string): Boolean;
const
  SPDX_IDS: array[0..30] of string = (
    '0BSD', 'Apache-1.1', 'Apache-2.0', 'Artistic-2.0', 'BSD-2-Clause',
    'BSD-3-Clause', 'BSL-1.0', 'CC0-1.0', 'EPL-1.0', 'EPL-2.0', 'GPL-2.0-only',
    'GPL-2.0-or-later', 'GPL-3.0-only', 'GPL-3.0-or-later', 'ISC', 'LGPL-2.0-only',
    'LGPL-2.0-or-later', 'LGPL-2.1-only', 'LGPL-2.1-or-later', 'LGPL-3.0-only',
    'LGPL-3.0-or-later', 'MIT', 'MPL-1.1', 'MPL-2.0', 'MS-PL', 'MS-RL',
    'Unlicense', 'WTFPL', 'Zlib', 'AGPL-3.0-only', 'AGPL-3.0-or-later');
begin
  for var LId in SPDX_IDS do
    if SameText(AValue, LId) then
      Exit(True);
  Result := False;
end;

class function TBoss4DLicenseNormalizer.IsSpdxExpression(const AValue: string): Boolean;
var
  LNormalized: string;
  LTokens: TArray<string>;
  LExpectLicense: Boolean;
begin
  LNormalized := AValue.Replace('(', ' ( ').Replace(')', ' ) ').Trim;
  LTokens := TRegEx.Split(LNormalized, '\s+');
  LExpectLicense := True;
  Result := Length(LTokens) > 0;
  for var LToken in LTokens do
  begin
    if LToken.IsEmpty or (LToken = '(') or (LToken = ')') then
      Continue;
    if SameText(LToken, 'AND') or SameText(LToken, 'OR') then
    begin
      if LExpectLicense then
        Exit(False);
      LExpectLicense := True;
      Continue;
    end;
    if SameText(LToken, 'WITH') then
    begin
      if LExpectLicense then
        Exit(False);
      // Excecoes SPDX sao nomes padronizados terminados em -exception.
      LExpectLicense := True;
      Continue;
    end;
    if not IsKnownSpdxId(LToken) and
       not TRegEx.IsMatch(LToken, '^[A-Za-z0-9.-]+-exception$') then
      Exit(False);
    LExpectLicense := False;
  end;
  Result := Result and not LExpectLicense;
end;

class function TBoss4DLicenseNormalizer.Normalize(const AValue,
  ASource: string): TBoss4DSbomLicense;
var
  LValue: string;
begin
  Result := TBoss4DSbomLicense.Create;
  Result.Source := ASource;
  LValue := AValue.Trim;
  if LValue.IsEmpty or SameText(LValue, 'Nao especificada') or SameText(LValue, 'NOASSERTION') then
  begin
    Result.Kind := MissingLicense;
    Exit;
  end;

  if SameText(LValue, 'Proprietary') or SameText(LValue, 'Commercial') or
     SameText(LValue, 'Closed Source') then
  begin
    Result.Kind := ProprietaryLicense;
    Result.Name := LValue;
  end
  else if IsSpdxExpression(LValue) then
  begin
    Result.Kind := SpdxExpressionLicense;
    Result.Expression := LValue;
  end
  else
  begin
    Result.Kind := NamedLicense;
    Result.Name := LValue;
  end;
end;

class function TBoss4DLicenseNormalizer.KindName(const AKind: TBoss4DSbomLicenseKind): string;
begin
  case AKind of
    SpdxExpressionLicense: Result := 'spdx-expression';
    NamedLicense: Result := 'named';
    ProprietaryLicense: Result := 'proprietary';
    MissingLicense: Result := 'missing';
  else
    Result := 'unknown';
  end;
end;

end.
