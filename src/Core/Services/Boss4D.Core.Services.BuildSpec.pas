unit Boss4D.Core.Services.BuildSpec;

interface

uses
  Boss4D.Core.Domain.Package;

type
  TBoss4DBuildSpecDetector = class
  public
    class procedure Detect(const APackage: TBoss4DPackage;
      const ARootDirectory: string); overload; static;
    class procedure Detect(const APackage: TBoss4DPackage;
      const ARootDirectory: string;
      const ACompilers: TArray<string>); overload; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.RegularExpressions,
  System.Generics.Collections,
  System.Generics.Defaults,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildConventions;

type
  TDetectedProject = class
  private
    FProjectPath: string;
    FPackageName: string;
    FKind: string;
    FRequires: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property ProjectPath: string read FProjectPath write FProjectPath;
    property PackageName: string read FPackageName write FPackageName;
    property Kind: string read FKind write FKind;
    property Requires: TList<string> read FRequires;
  end;

constructor TDetectedProject.Create;
begin
  inherited Create;
  FRequires := TList<string>.Create;
end;

destructor TDetectedProject.Destroy;
begin
  FRequires.Free;
  inherited Destroy;
end;

function NormalizePath(const APath: string): string;
begin
  Result := StringReplace(APath, '\', '/', [rfReplaceAll]);
end;

function IsIgnoredDirectory(const ARootDirectory, AFileName: string): Boolean;
var
  LRelative: string;
begin
  LRelative := '/' + NormalizePath(ExtractRelativePath(
    IncludeTrailingPathDelimiter(ARootDirectory), AFileName)).ToLower;
  Result := LRelative.Contains('/.git/') or
    LRelative.Contains('/modules/') or
    LRelative.Contains('/artifacts/') or
    LRelative.Contains('/.boss4d-state/');
end;

function ExtractElement(const AContent, AName: string): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AContent, '(?is)<' + AName +
    '(?:\s[^>]*)?>(.*?)</' + AName + '>');
  if LMatch.Success then
    Result := LMatch.Groups[1].Value.Trim
  else
    Result := '';
end;

function FindPackageSource(const AProjectFile, AProjectContent: string): string;
begin
  Result := ExtractElement(AProjectContent, 'MainSource');
  if not Result.IsEmpty then
    Result := TPath.Combine(ExtractFilePath(AProjectFile), Result)
  else
    Result := ChangeFileExt(AProjectFile, '.dpk');
end;

procedure ReadPackageMetadata(const AFileName: string;
  const AProject: TDetectedProject);
var
  LContent: string;
  LMatch: TMatch;
  LRequiresMatch: TMatch;
  LIdentifier: TMatch;
begin
  AProject.PackageName := ChangeFileExt(ExtractFileName(AFileName), '');
  AProject.Kind := 'runtime';
  if not TFile.Exists(AFileName) then
    Exit;

  LContent := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  LMatch := TRegEx.Match(LContent,
    '(?im)^\s*package\s+([A-Za-z_][A-Za-z0-9_]*)\s*;');
  if LMatch.Success then
    AProject.PackageName := LMatch.Groups[1].Value;

  if TRegEx.IsMatch(LContent, '(?is)\{\$\s*DESIGNONLY\s*\}') then
    AProject.Kind := 'design'
  else if TRegEx.IsMatch(LContent, '(?is)\{\$\s*RUNONLY\s*\}') then
    AProject.Kind := 'runtime';

  LRequiresMatch := TRegEx.Match(LContent,
    '(?is)\brequires\b(.*?)(?:\bcontains\b|\bend\b)');
  if not LRequiresMatch.Success then
    Exit;

  LIdentifier := TRegEx.Match(LRequiresMatch.Groups[1].Value,
    '\b[A-Za-z_][A-Za-z0-9_]*\b');
  while LIdentifier.Success do
  begin
    if not AProject.Requires.Contains(LIdentifier.Value) then
      AProject.Requires.Add(LIdentifier.Value);
    LIdentifier := LIdentifier.NextMatch;
  end;
end;

class procedure TBoss4DBuildSpecDetector.Detect(
  const APackage: TBoss4DPackage; const ARootDirectory: string);
begin
  Detect(APackage, ARootDirectory,
    ['17.0', '18.0', '22.0', '23.0', '37.0']);
end;

class procedure TBoss4DBuildSpecDetector.Detect(
  const APackage: TBoss4DPackage; const ARootDirectory: string;
  const ACompilers: TArray<string>);
var
  LDetected: TObjectList<TDetectedProject>;
  LPackages: TDictionary<string, string>;
  LProjectFiles: TStringList;
  LRoot: string;
begin
  if not Assigned(APackage) then
    raise EArgumentNilException.Create('APackage');
  LRoot := TPath.GetFullPath(ARootDirectory);
  if not TDirectory.Exists(LRoot) then
    raise EDirectoryNotFoundException.CreateFmt(
      'Diretorio do projeto nao encontrado: %s.', [ARootDirectory]);
  if Length(ACompilers) = 0 then
    raise EArgumentException.Create(
      'Ao menos um compilador deve ser informado para a matriz.');

  LDetected := TObjectList<TDetectedProject>.Create(True);
  LPackages := TDictionary<string, string>.Create;
  LProjectFiles := TStringList.Create;
  try
    LProjectFiles.CaseSensitive := False;
    LProjectFiles.Sorted := True;
    for var LFile in TDirectory.GetFiles(LRoot, '*.dproj',
      TSearchOption.soAllDirectories) do
      if not IsIgnoredDirectory(LRoot, LFile) then
        LProjectFiles.Add(LFile);

    if LProjectFiles.Count = 0 then
      raise EFileNotFoundException.CreateFmt(
        'Nenhum projeto Delphi (.dproj) encontrado em %s.', [LRoot]);

    for var LFile in LProjectFiles do
    begin
      var LProject := TDetectedProject.Create;
      LProject.ProjectPath := NormalizePath(ExtractRelativePath(
        IncludeTrailingPathDelimiter(LRoot), LFile));
      var LProjectContent := TFile.ReadAllText(LFile, TEncoding.UTF8);
      ReadPackageMetadata(FindPackageSource(LFile, LProjectContent), LProject);
      if LPackages.ContainsKey(LProject.PackageName.ToLower) then
        raise EArgumentException.CreateFmt(
          'Package Delphi duplicado detectado: %s.', [LProject.PackageName]);
      LPackages.Add(LProject.PackageName.ToLower, LProject.ProjectPath);
      LDetected.Add(LProject);
    end;

    APackage.BuildMatrix.Compilers.Clear;
    APackage.BuildMatrix.Platforms.Clear;
    APackage.BuildMatrix.Configurations.Clear;
    APackage.BuildMatrix.Projects.Clear;
    for var LCompiler in ACompilers do
    begin
      var LConvention := TBoss4DBuildConventions.ResolveCompiler(LCompiler);
      if not APackage.BuildMatrix.Compilers.Contains(
        LConvention.BDSVersion) then
        APackage.BuildMatrix.Compilers.Add(LConvention.BDSVersion);
    end;
    APackage.BuildMatrix.Compilers.Sort;
    APackage.BuildMatrix.Platforms.Add('Win32');
    APackage.BuildMatrix.Platforms.Add('Win64');
    APackage.BuildMatrix.Configurations.Add('Debug');
    APackage.BuildMatrix.Configurations.Add('Release');
    APackage.BuildMatrix.DefaultCompiler :=
      APackage.BuildMatrix.Compilers[APackage.BuildMatrix.Compilers.Count - 1];
    APackage.BuildMatrix.DefaultPlatform := 'Win32';
    APackage.BuildMatrix.DefaultConfiguration := 'Debug';

    for var LDetectedProject in LDetected do
    begin
      var LBuildProject := TBoss4DBuildProject.Create;
      LBuildProject.Path := LDetectedProject.ProjectPath;
      LBuildProject.Kind := LDetectedProject.Kind;
      for var LRequired in LDetectedProject.Requires do
      begin
        var LDependencyPath := '';
        if LPackages.TryGetValue(LRequired.ToLower, LDependencyPath) and
           not SameText(LDependencyPath, LBuildProject.Path) then
          LBuildProject.DependsOn.Add(LDependencyPath);
      end;
      LBuildProject.DependsOn.Sort;
      APackage.BuildMatrix.Projects.Add(LBuildProject);
    end;
  finally
    LProjectFiles.Free;
    LPackages.Free;
    LDetected.Free;
  end;
end;

end.
