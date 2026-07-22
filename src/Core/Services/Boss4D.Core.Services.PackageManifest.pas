unit Boss4D.Core.Services.PackageManifest;

interface

type
  TBoss4DPackageManifest = class
  public
    class function AddRequires(const AContent: string;
      const ADependencies: TArray<string>): string; static;
  end;

implementation

uses
  System.SysUtils, System.RegularExpressions;

class function TBoss4DPackageManifest.AddRequires(const AContent: string;
  const ADependencies: TArray<string>): string;
var
  LMatch: TMatch;
  LBody, LUpdatedBody, LDependency: string;
begin
  LMatch := TRegEx.Match(AContent, '(?is)\brequires\b(?<body>[^;]*);');
  if not LMatch.Success then
    raise EArgumentException.Create('Clausula requires nao encontrada no DPK.');

  LBody := LMatch.Groups['body'].Value;
  LUpdatedBody := LBody;
  for LDependency in ADependencies do
  begin
    if LDependency.Trim.IsEmpty then
      Continue;
    if TRegEx.IsMatch(LUpdatedBody, '(?i)\b' +
      TRegEx.Escape(LDependency.Trim) + '\b') then
      Continue;
    if LUpdatedBody.Trim.IsEmpty then
      LUpdatedBody := sLineBreak + '  ' + LDependency.Trim
    else if LUpdatedBody.Trim.EndsWith(',') then
      LUpdatedBody := LUpdatedBody + sLineBreak + '  ' + LDependency.Trim
    else
      LUpdatedBody := LUpdatedBody.TrimRight + ',' + sLineBreak +
        '  ' + LDependency.Trim;
  end;

  Result := AContent.Substring(0, LMatch.Groups['body'].Index) +
    LUpdatedBody + AContent.Substring(LMatch.Groups['body'].Index +
    LMatch.Groups['body'].Length);
end;

end.
