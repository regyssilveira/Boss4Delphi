unit Boss4D.Core.Services.BuildMatrix;

interface

uses
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix;

type
  TBoss4DBuildMatrixExpander = class
  public
    class function Expand(const APackage: TBoss4DPackage;
      const ASelection: TBoss4DBuildSelection): TBoss4DBuildTargetList; static;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Generics.Defaults;

function ContainsText(const AValues: TList<string>;
  const AValue: string): Boolean;
begin
  Result := False;
  for var LItem in AValues do
    if SameText(LItem, AValue) then
      Exit(True);
end;

function SortedCopy(const AValues: TList<string>): TList<string>;
begin
  Result := TList<string>.Create;
  Result.AddRange(AValues);
  Result.Sort(TComparer<string>.Construct(
    function(const ALeft, ARight: string): Integer
    begin
      Result := CompareText(ALeft, ARight);
    end));
end;

procedure ValidateUniqueValues(const AValues: TList<string>;
  const ALabel: string);
var
  LSeen: TDictionary<string, Boolean>;
begin
  LSeen := TDictionary<string, Boolean>.Create;
  try
    for var LValue in AValues do
    begin
      if LValue.Trim.IsEmpty then
        raise EArgumentException.CreateFmt(
          '%s contem um valor vazio.', [ALabel]);
      var LKey := LValue.ToLower;
      if LSeen.ContainsKey(LKey) then
        raise EArgumentException.CreateFmt(
          '%s contem um valor duplicado: %s.', [ALabel, LValue]);
      LSeen.Add(LKey, True);
    end;
  finally
    LSeen.Free;
  end;
end;

procedure ValidateSubset(const AProjectPath, ALabel: string;
  const AValues, AGlobalValues: TList<string>);
begin
  for var LValue in AValues do
    if not ContainsText(AGlobalValues, LValue) then
      raise EArgumentException.CreateFmt(
        'Projeto %s declara %s "%s" fora da buildMatrix.',
        [AProjectPath, ALabel, LValue]);
end;

procedure ValidateMatrix(const AMatrix: TBoss4DBuildMatrix);
var
  LSeenProjects: TDictionary<string, Boolean>;
begin
  if AMatrix.Compilers.Count = 0 then
    raise EArgumentException.Create(
      'buildMatrix.compilers deve declarar ao menos um compilador.');
  if AMatrix.Platforms.Count = 0 then
    raise EArgumentException.Create(
      'buildMatrix.platforms deve declarar ao menos uma plataforma.');
  if AMatrix.Configurations.Count = 0 then
    raise EArgumentException.Create(
      'buildMatrix.configurations deve declarar ao menos uma configuracao.');
  if AMatrix.Projects.Count = 0 then
    raise EArgumentException.Create(
      'buildMatrix.projects deve declarar ao menos um projeto.');

  ValidateUniqueValues(AMatrix.Compilers, 'buildMatrix.compilers');
  ValidateUniqueValues(AMatrix.Platforms, 'buildMatrix.platforms');
  ValidateUniqueValues(AMatrix.Configurations,
    'buildMatrix.configurations');
  if not AMatrix.DefaultCompiler.IsEmpty and
     not ContainsText(AMatrix.Compilers, AMatrix.DefaultCompiler) then
    raise EArgumentException.CreateFmt(
      'Compilador default "%s" nao pertence a buildMatrix.',
      [AMatrix.DefaultCompiler]);
  if not AMatrix.DefaultPlatform.IsEmpty and
     not ContainsText(AMatrix.Platforms, AMatrix.DefaultPlatform) then
    raise EArgumentException.CreateFmt(
      'Plataforma default "%s" nao pertence a buildMatrix.',
      [AMatrix.DefaultPlatform]);
  if not AMatrix.DefaultConfiguration.IsEmpty and
     not ContainsText(AMatrix.Configurations,
       AMatrix.DefaultConfiguration) then
    raise EArgumentException.CreateFmt(
      'Configuracao default "%s" nao pertence a buildMatrix.',
      [AMatrix.DefaultConfiguration]);

  for var LPlatform in AMatrix.Platforms do
    if not SameText(LPlatform, 'Win32') and
       not SameText(LPlatform, 'Win64') then
      raise EArgumentException.CreateFmt(
        'Plataforma nao suportada na matriz Delphi: %s.', [LPlatform]);
  for var LConfiguration in AMatrix.Configurations do
    if not SameText(LConfiguration, 'Debug') and
       not SameText(LConfiguration, 'Release') then
      raise EArgumentException.CreateFmt(
        'Configuracao nao suportada na matriz Delphi: %s.',
        [LConfiguration]);

  LSeenProjects := TDictionary<string, Boolean>.Create;
  try
    for var LProject in AMatrix.Projects do
    begin
      if LProject.Path.Trim.IsEmpty then
        raise EArgumentException.Create(
          'Um projeto da matriz possui path vazio.');
      if not SameText(LProject.Kind, 'runtime') and
         not SameText(LProject.Kind, 'design') then
        raise EArgumentException.CreateFmt(
          'Tipo de projeto nao suportado: %s.', [LProject.Kind]);
      var LKey := LProject.Path.ToLower;
      if LSeenProjects.ContainsKey(LKey) then
        raise EArgumentException.CreateFmt(
          'Projeto duplicado na matriz: %s.', [LProject.Path]);
      LSeenProjects.Add(LKey, True);
      ValidateUniqueValues(LProject.Compilers,
        'compilers do projeto ' + LProject.Path);
      ValidateUniqueValues(LProject.Platforms,
        'platforms do projeto ' + LProject.Path);
      ValidateUniqueValues(LProject.Configurations,
        'configurations do projeto ' + LProject.Path);
      ValidateSubset(LProject.Path, 'compilador', LProject.Compilers,
        AMatrix.Compilers);
      ValidateSubset(LProject.Path, 'plataforma', LProject.Platforms,
        AMatrix.Platforms);
      ValidateSubset(LProject.Path, 'configuracao',
        LProject.Configurations, AMatrix.Configurations);
    end;
  finally
    LSeenProjects.Free;
  end;
end;

function SelectValues(const AValues: TList<string>;
  const AExplicitValue, ADefaultValue, ALabel: string;
  const AAllTargets: Boolean): TList<string>;
begin
  Result := SortedCopy(AValues);
  if AAllTargets then
    Exit;

  var LSelected := AExplicitValue;
  if LSelected.IsEmpty then
    LSelected := ADefaultValue;
  if LSelected.IsEmpty and (Result.Count > 0) then
    LSelected := Result[0];

  if not ContainsText(AValues, LSelected) then
  begin
    Result.Free;
    raise EArgumentException.CreateFmt(
      '%s "%s" nao pertence a buildMatrix.', [ALabel, LSelected]);
  end;
  Result.Clear;
  Result.Add(LSelected);
end;

function ProjectAllows(const AProjectValues: TList<string>;
  const AValue: string): Boolean;
begin
  Result := (AProjectValues.Count = 0) or
    ContainsText(AProjectValues, AValue);
end;

class function TBoss4DBuildMatrixExpander.Expand(
  const APackage: TBoss4DPackage;
  const ASelection: TBoss4DBuildSelection): TBoss4DBuildTargetList;
var
  LCompilers: TList<string>;
  LPlatforms: TList<string>;
  LConfigurations: TList<string>;
begin
  if not Assigned(APackage) then
    raise EArgumentNilException.Create('APackage');

  Result := TBoss4DBuildTargetList.Create(True);
  try
    if not APackage.BuildMatrix.IsDeclared then
    begin
      var LCompiler := ASelection.Compiler;
      if LCompiler.IsEmpty then
        LCompiler := APackage.Toolchain.Compiler;
      if LCompiler.IsEmpty then
        LCompiler := APackage.Engines.Compiler;

      var LPlatform := ASelection.Platform;
      if LPlatform.IsEmpty then
        LPlatform := APackage.Toolchain.Platform;
      if LPlatform.IsEmpty and (APackage.Engines.Platforms.Count > 0) then
        LPlatform := APackage.Engines.Platforms[0];
      if LPlatform.IsEmpty then
        LPlatform := 'Win32';

      var LConfiguration := ASelection.Configuration;
      if LConfiguration.IsEmpty then
        LConfiguration := 'Debug';

      for var LProjectPath in APackage.Projects do
      begin
        var LTarget := TBoss4DBuildTarget.Create;
        LTarget.PackageName := APackage.Name;
        LTarget.ProjectPath := LProjectPath;
        LTarget.ProjectKind := 'runtime';
        LTarget.Compiler := LCompiler;
        LTarget.Platform := LPlatform;
        LTarget.Configuration := LConfiguration;
        Result.Add(LTarget);
      end;
      Exit;
    end;

    ValidateMatrix(APackage.BuildMatrix);
    LCompilers := SelectValues(APackage.BuildMatrix.Compilers,
      ASelection.Compiler, APackage.BuildMatrix.DefaultCompiler, 'Compilador',
      ASelection.CompilerAll);
    try
      LPlatforms := SelectValues(APackage.BuildMatrix.Platforms,
        ASelection.Platform, APackage.BuildMatrix.DefaultPlatform, 'Plataforma',
        ASelection.PlatformAll);
      try
        LConfigurations := SelectValues(APackage.BuildMatrix.Configurations,
          ASelection.Configuration, APackage.BuildMatrix.DefaultConfiguration,
          'Configuracao', ASelection.ConfigurationAll);
        try
          for var LProject in APackage.BuildMatrix.Projects do
            for var LCompiler in LCompilers do
              if ProjectAllows(LProject.Compilers, LCompiler) then
                for var LPlatform in LPlatforms do
                  if ProjectAllows(LProject.Platforms, LPlatform) then
                    for var LConfiguration in LConfigurations do
                      if ProjectAllows(LProject.Configurations,
                        LConfiguration) then
                      begin
                        var LTarget := TBoss4DBuildTarget.Create;
                        LTarget.PackageName := APackage.Name;
                        LTarget.ProjectPath := LProject.Path;
                        LTarget.ProjectKind := LProject.Kind;
                        LTarget.Compiler := LCompiler;
                        LTarget.Platform := LPlatform;
                        LTarget.Configuration := LConfiguration;
                        LTarget.DependsOn.AddRange(LProject.DependsOn);
                        Result.Add(LTarget);
                      end;
        finally
          LConfigurations.Free;
        end;
      finally
        LPlatforms.Free;
      end;
    finally
      LCompilers.Free;
    end;

    if Result.Count = 0 then
      raise EArgumentException.Create(
        'A selecao nao produz nenhum target de build.');
    Result.Sort(TComparer<TBoss4DBuildTarget>.Construct(
      function(const ALeft, ARight: TBoss4DBuildTarget): Integer
      begin
        Result := CompareText(ALeft.Identity, ARight.Identity);
      end));
  except
    Result.Free;
    raise;
  end;
end;

end.
