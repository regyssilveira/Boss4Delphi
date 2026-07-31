unit Boss4D.Core.Services.BuildConventions;

interface

type
  TBoss4DDelphiConvention = record
    BDSVersion: string;
    Alias: string;
    PackageSuffix: string;
    CompilerVersion: string;
    CompilerSymbol: string;
  end;

  TBoss4DBuildConventions = class
  public
    class function ResolveCompiler(
      const AValue: string): TBoss4DDelphiConvention; static;
    class function ExpandPath(const APath, ACompiler, APlatform,
      AConfiguration: string): string; static;
  end;

implementation

uses
  System.SysUtils;

function Convention(const ABDSVersion, AAlias, APackageSuffix,
  ACompilerVersion, ACompilerSymbol: string): TBoss4DDelphiConvention;
begin
  Result.BDSVersion := ABDSVersion;
  Result.Alias := AAlias;
  Result.PackageSuffix := APackageSuffix;
  Result.CompilerVersion := ACompilerVersion;
  Result.CompilerSymbol := ACompilerSymbol;
end;

class function TBoss4DBuildConventions.ResolveCompiler(
  const AValue: string): TBoss4DDelphiConvention;
var
  LValue: string;
begin
  LValue := AValue.Trim;
  if SameText(LValue, '8.0') or SameText(LValue, 'xe') or
     SameText(LValue, 'VER220') then
    Exit(Convention('8.0', 'xe', '150', '22.0', 'VER220'));
  if SameText(LValue, '9.0') or SameText(LValue, 'xe2') or
     SameText(LValue, 'VER230') then
    Exit(Convention('9.0', 'xe2', '160', '23.0', 'VER230'));
  if SameText(LValue, '10.0') or SameText(LValue, 'xe3') or
     SameText(LValue, 'VER240') then
    Exit(Convention('10.0', 'xe3', '170', '24.0', 'VER240'));
  if SameText(LValue, '11.0') or SameText(LValue, 'xe4') or
     SameText(LValue, 'VER250') then
    Exit(Convention('11.0', 'xe4', '180', '25.0', 'VER250'));
  if SameText(LValue, '12.0') or SameText(LValue, 'xe5') or
     SameText(LValue, 'VER260') then
    Exit(Convention('12.0', 'xe5', '190', '26.0', 'VER260'));
  if SameText(LValue, '14.0') or SameText(LValue, 'xe6') or
     SameText(LValue, 'VER270') then
    Exit(Convention('14.0', 'xe6', '200', '27.0', 'VER270'));
  if SameText(LValue, '15.0') or SameText(LValue, 'xe7') or
     SameText(LValue, 'VER280') then
    Exit(Convention('15.0', 'xe7', '210', '28.0', 'VER280'));
  if SameText(LValue, '16.0') or SameText(LValue, 'xe8') or
     SameText(LValue, 'VER290') then
    Exit(Convention('16.0', 'xe8', '220', '29.0', 'VER290'));
  if SameText(LValue, '17.0') or SameText(LValue, 'd10') or
     SameText(LValue, '30.0') or SameText(LValue, 'VER300') then
    Exit(Convention('17.0', 'd10', '230', '30.0', 'VER300'));
  if SameText(LValue, '18.0') or SameText(LValue, 'd101') or
     SameText(LValue, '31.0') or SameText(LValue, 'VER310') then
    Exit(Convention('18.0', 'd101', '240', '31.0', 'VER310'));
  if SameText(LValue, '19.0') or SameText(LValue, 'd102') or
     SameText(LValue, '32.0') or SameText(LValue, 'VER320') then
    Exit(Convention('19.0', 'd102', '250', '32.0', 'VER320'));
  if SameText(LValue, '20.0') or SameText(LValue, 'd103') or
     SameText(LValue, '33.0') or SameText(LValue, 'VER330') then
    Exit(Convention('20.0', 'd103', '260', '33.0', 'VER330'));
  if SameText(LValue, '21.0') or SameText(LValue, 'd104') or
     SameText(LValue, '34.0') or SameText(LValue, 'VER340') then
    Exit(Convention('21.0', 'd104', '270', '34.0', 'VER340'));
  if SameText(LValue, '22.0') or SameText(LValue, 'd11') or
     SameText(LValue, '35.0') or SameText(LValue, 'VER350') then
    Exit(Convention('22.0', 'd11', '280', '35.0', 'VER350'));
  if SameText(LValue, '23.0') or SameText(LValue, 'd12') or
     SameText(LValue, '36.0') or SameText(LValue, 'VER360') then
    Exit(Convention('23.0', 'd12', '290', '36.0', 'VER360'));
  if SameText(LValue, '37.0') or SameText(LValue, 'd13') or
     SameText(LValue, '37') or SameText(LValue, 'VER370') then
    Exit(Convention('37.0', 'd13', '370', '37.0', 'VER370'));

  raise EArgumentException.CreateFmt(
    'Compilador Delphi nao suportado: %s.', [AValue]);
end;

class function TBoss4DBuildConventions.ExpandPath(const APath, ACompiler,
  APlatform, AConfiguration: string): string;
var
  LConvention: TBoss4DDelphiConvention;
begin
  LConvention := ResolveCompiler(ACompiler);
  Result := APath;
  Result := StringReplace(Result, '{compiler}', LConvention.BDSVersion,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{alias}', LConvention.Alias,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{libsuffix}', LConvention.PackageSuffix,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{platform}', APlatform,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{configuration}', AConfiguration,
    [rfReplaceAll, rfIgnoreCase]);
end;

end.
