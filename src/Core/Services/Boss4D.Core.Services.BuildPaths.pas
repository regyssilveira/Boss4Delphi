unit Boss4D.Core.Services.BuildPaths;

interface

type
  TBoss4DBuildPaths = class
  private
    class function RequireSegment(const AValue, ALabel: string): string; static;
  public
    class function TargetRoot(const AModulesRoot, APackage,
      ACompiler, APlatform, AConfiguration: string): string; static;
    class function OutputDirectory(const AModulesRoot, APackage,
      ACompiler, APlatform, AConfiguration, AOutputKind: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

class function TBoss4DBuildPaths.RequireSegment(const AValue,
  ALabel: string): string;
begin
  Result := AValue.Trim;
  if Result.IsEmpty then
    raise EArgumentException.CreateFmt('%s nao pode ser vazio.', [ALabel]);
  if (Result = '.') or (Result = '..') or Result.Contains('/') or
     Result.Contains('\') or Result.Contains(':') then
    raise EArgumentException.CreateFmt(
      '%s contem um segmento de path invalido: %s.', [ALabel, AValue]);
end;

class function TBoss4DBuildPaths.TargetRoot(const AModulesRoot, APackage,
  ACompiler, APlatform, AConfiguration: string): string;
begin
  if AModulesRoot.Trim.IsEmpty then
    raise EArgumentException.Create('A raiz de modulos nao pode ser vazia.');
  Result := TPath.Combine(AModulesRoot, 'artifacts');
  Result := TPath.Combine(Result, RequireSegment(APackage, 'Pacote'));
  Result := TPath.Combine(Result, RequireSegment(ACompiler, 'Compilador'));
  Result := TPath.Combine(Result, RequireSegment(APlatform, 'Plataforma'));
  Result := TPath.Combine(Result,
    RequireSegment(AConfiguration, 'Configuracao'));
end;

class function TBoss4DBuildPaths.OutputDirectory(const AModulesRoot,
  APackage, ACompiler, APlatform, AConfiguration,
  AOutputKind: string): string;
begin
  Result := TPath.Combine(TargetRoot(AModulesRoot, APackage, ACompiler,
    APlatform, AConfiguration), RequireSegment(AOutputKind, 'Tipo de output'));
end;

end.
