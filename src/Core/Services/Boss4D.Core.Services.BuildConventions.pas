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
  if SameText(LValue, '18.0') or SameText(LValue, 'd101') or
     SameText(LValue, '31.0') or SameText(LValue, 'VER310') then
    Exit(Convention('18.0', 'd101', '240', '31.0', 'VER310'));
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
