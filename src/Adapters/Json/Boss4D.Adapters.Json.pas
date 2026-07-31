unit Boss4D.Adapters.Json;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Package, Boss4D.Core.Domain.Lock;

type
  { Persistencia JSON do boss.json }
  TBoss4DPackageJsonRepository = class(TInterfacedObject, IBoss4DPackageRepository)
  public
    function Load(const APackagePath: string): TBoss4DPackage;
    procedure Save(const APackage: TBoss4DPackage; const APackagePath: string);
    function Exists(const APackagePath: string): Boolean;
  end;

  { Persistencia JSON do boss-lock.json }
  TBoss4DLockJsonRepository = class(TInterfacedObject, IBoss4DLockRepository)
  public
    function Load(const ALockPath: string): TBoss4DLock;
    procedure Save(const ALock: TBoss4DLock; const ALockPath: string);
    function Exists(const ALockPath: string): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, System.Generics.Collections,
  System.Generics.Defaults, Boss4D.Core.Domain.BuildMatrix;

// Funcoes auxiliares locais de leitura segura para evitar excecoes no System.JSON
function ReadString(const AObj: TJSONObject; const AKey: string): string;
var
  LVal: TJSONValue;
begin
  Result := '';
  if Assigned(AObj) then
  begin
    LVal := AObj.FindValue(AKey);
    if Assigned(LVal) then
      Result := LVal.Value;
  end;
end;

function ReadBool(const AObj: TJSONObject; const AKey: string): Boolean;
var
  LVal: TJSONValue;
begin
  Result := False;
  if Assigned(AObj) then
  begin
    LVal := AObj.FindValue(AKey);
    if Assigned(LVal) and (LVal is TJSONBool) then
      Result := TJSONBool(LVal).AsBoolean;
  end;
end;

function ReadInteger(const AObj: TJSONObject; const AKey: string; const ADefault: Integer): Integer;
var
  LVal: TJSONValue;
begin
  Result := ADefault;
  if Assigned(AObj) then
  begin
    LVal := AObj.FindValue(AKey);
    if Assigned(LVal) and not TryStrToInt(LVal.Value, Result) then
      Result := ADefault;
  end;
end;

function ReadObject(const AObj: TJSONObject; const AKey: string): TJSONObject;
var
  LVal: TJSONValue;
begin
  Result := nil;
  if Assigned(AObj) then
  begin
    LVal := AObj.FindValue(AKey);
    if Assigned(LVal) and (LVal is TJSONObject) then
      Result := TJSONObject(LVal);
  end;
end;

function ReadArray(const AObj: TJSONObject; const AKey: string): TJSONArray;
var
  LVal: TJSONValue;
begin
  Result := nil;
  if Assigned(AObj) then
  begin
    LVal := AObj.FindValue(AKey);
    if Assigned(LVal) and (LVal is TJSONArray) then
      Result := TJSONArray(LVal);
  end;
end;

procedure ParseLockMetadata(const ADepObj: TJSONObject; const ADependency: TBoss4DLockedDependency);
var
  LChecksumValue: TJSONValue;
  LChecksumObj: TJSONObject;
  LLicenseObj: TJSONObject;
  LDependenciesArr: TJSONArray;
begin
  ADependency.Repository := ReadString(ADepObj, 'repository');
  ADependency.Revision := ReadString(ADepObj, 'revision');
  ADependency.ResolvedFrom := ReadString(ADepObj, 'resolvedFrom');

  LChecksumValue := ADepObj.FindValue('checksum');
  if LChecksumValue is TJSONObject then
  begin
    LChecksumObj := TJSONObject(LChecksumValue);
    ADependency.ChecksumAlgorithm := ReadString(LChecksumObj, 'algorithm');
    ADependency.Checksum := ReadString(LChecksumObj, 'value');
  end
  else if Assigned(LChecksumValue) then
  begin
    // Compatibilidade com boss-lock.json v1, que armazenava apenas o valor.
    ADependency.ChecksumAlgorithm := 'SHA-256';
    ADependency.Checksum := LChecksumValue.Value;
  end;

  LLicenseObj := ReadObject(ADepObj, 'license');
  if Assigned(LLicenseObj) then
  begin
    ADependency.LicenseExpression := ReadString(LLicenseObj, 'expression');
    ADependency.LicenseSource := ReadString(LLicenseObj, 'source');
  end;

  LDependenciesArr := ReadArray(ADepObj, 'dependencies');
  if Assigned(LDependenciesArr) then
    for var I := 0 to LDependenciesArr.Count - 1 do
      ADependency.Dependencies.Add(LDependenciesArr[I].Value.ToLower);
end;

// Subfunções auxiliares de Parse para TBoss4DPackageJsonRepository.Load
procedure ParsePackageProjects(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LArr: TJSONArray;
begin
  LArr := ReadArray(AJSONObj, 'projects');
  if Assigned(LArr) then
  begin
    for var I := 0 to LArr.Count - 1 do
      APackage.Projects.Add(LArr[I].Value);
  end;
end;

procedure ParsePackageScripts(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
begin
  LObj := ReadObject(AJSONObj, 'scripts');
  if Assigned(LObj) then
  begin
    for var LPair in LObj do
      APackage.Scripts.Add(LPair.JsonString.Value, LPair.JsonValue.Value);
  end;
end;

procedure ParsePackageDependencies(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
begin
  LObj := ReadObject(AJSONObj, 'dependencies');
  if Assigned(LObj) then
  begin
    for var LPair in LObj do
      APackage.Dependencies.Add(LPair.JsonString.Value, LPair.JsonValue.Value);
  end;
end;

procedure ParsePackageDevDependencies(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
begin
  LObj := ReadObject(AJSONObj, 'devDependencies');
  if Assigned(LObj) then
    for var LPair in LObj do
      APackage.DevDependencies.Add(LPair.JsonString.Value,
        LPair.JsonValue.Value);
end;

procedure ParsePackageSbomComponents(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LSbomObj: TJSONObject;
  LComponents: TJSONArray;
begin
  LSbomObj := ReadObject(AJSONObj, 'sbom');
  if not Assigned(LSbomObj) then
    Exit;
  LComponents := ReadArray(LSbomObj, 'components');
  if not Assigned(LComponents) then
    Exit;

  for var I := 0 to LComponents.Count - 1 do
  begin
    if not (LComponents[I] is TJSONObject) then
      Continue;
    var LObj := TJSONObject(LComponents[I]);
    var LComponent := TBoss4DManualComponent.Create;
    LComponent.Id := ReadString(LObj, 'id');
    LComponent.Name := ReadString(LObj, 'name');
    LComponent.Version := ReadString(LObj, 'version');
    LComponent.ComponentType := ReadString(LObj, 'type');
    LComponent.Description := ReadString(LObj, 'description');
    LComponent.License := ReadString(LObj, 'license');
    LComponent.Repository := ReadString(LObj, 'repository');
    LComponent.Source := ReadString(LObj, 'source');
    var LHashObj := ReadObject(LObj, 'hash');
    if Assigned(LHashObj) then
    begin
      LComponent.HashAlgorithm := ReadString(LHashObj, 'algorithm');
      LComponent.HashValue := ReadString(LHashObj, 'value');
    end;
    APackage.SbomComponents.Add(LComponent);
  end;
end;

procedure ParsePackageEngines(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
  LArr: TJSONArray;
begin
  LObj := ReadObject(AJSONObj, 'engines');
  if Assigned(LObj) then
  begin
    APackage.Engines.Compiler := ReadString(LObj, 'compiler');
    LArr := ReadArray(LObj, 'platforms');
    if Assigned(LArr) then
    begin
      for var I := 0 to LArr.Count - 1 do
        APackage.Engines.Platforms.Add(LArr[I].Value);
    end;
  end;
end;

procedure ParsePackageToolchain(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
begin
  LObj := ReadObject(AJSONObj, 'toolchain');
  if Assigned(LObj) then
  begin
    APackage.Toolchain.Compiler := ReadString(LObj, 'compiler');
    APackage.Toolchain.Platform := ReadString(LObj, 'platform');
    APackage.Toolchain.Path := ReadString(LObj, 'path');
    APackage.Toolchain.Strict := ReadBool(LObj, 'strict');
  end;
end;

procedure ParseStringArray(const AObject: TJSONObject; const AName: string;
  const ADestination: TList<string>);
var
  LArray: TJSONArray;
begin
  LArray := ReadArray(AObject, AName);
  if not Assigned(LArray) then
    Exit;
  for var I := 0 to LArray.Count - 1 do
    if LArray[I] is TJSONString then
      ADestination.Add(LArray[I].Value);
end;

procedure ParsePackageBuildMatrix(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LMatrixObject: TJSONObject;
  LDefaultsObject: TJSONObject;
  LProjectsArray: TJSONArray;
begin
  LMatrixObject := ReadObject(AJSONObj, 'buildMatrix');
  if not Assigned(LMatrixObject) then
    Exit;

  ParseStringArray(LMatrixObject, 'compilers',
    APackage.BuildMatrix.Compilers);
  ParseStringArray(LMatrixObject, 'platforms',
    APackage.BuildMatrix.Platforms);
  ParseStringArray(LMatrixObject, 'configurations',
    APackage.BuildMatrix.Configurations);

  LDefaultsObject := ReadObject(LMatrixObject, 'defaults');
  if Assigned(LDefaultsObject) then
  begin
    APackage.BuildMatrix.DefaultCompiler :=
      ReadString(LDefaultsObject, 'compiler');
    APackage.BuildMatrix.DefaultPlatform :=
      ReadString(LDefaultsObject, 'platform');
    APackage.BuildMatrix.DefaultConfiguration :=
      ReadString(LDefaultsObject, 'configuration');
  end;

  LProjectsArray := ReadArray(LMatrixObject, 'projects');
  if not Assigned(LProjectsArray) then
    Exit;
  for var I := 0 to LProjectsArray.Count - 1 do
  begin
    if not (LProjectsArray[I] is TJSONObject) then
      Continue;
    var LProjectObject := TJSONObject(LProjectsArray[I]);
    var LProject := TBoss4DBuildProject.Create;
    try
      LProject.Path := ReadString(LProjectObject, 'path');
      LProject.PackageName := ReadString(LProjectObject, 'packageName');
      var LIDEObject := ReadObject(LProjectObject, 'ide');
      if Assigned(LIDEObject) then
      begin
        LProject.IDEPackageDescription :=
          ReadString(LIDEObject, 'description');
        LProject.PalettePage := ReadString(LIDEObject, 'palettePage');
      end;
      LProject.Kind := ReadString(LProjectObject, 'kind');
      if LProject.Kind.IsEmpty then
        LProject.Kind := 'runtime';
      ParseStringArray(LProjectObject, 'dependsOn', LProject.DependsOn);
      var LDependenciesArray := ReadArray(LProjectObject, 'dependencies');
      if Assigned(LDependenciesArray) then
        for var LDependencyIndex := 0 to
          LDependenciesArray.Count - 1 do
          if LDependenciesArray[LDependencyIndex] is TJSONObject then
          begin
            var LDependencyObject :=
              TJSONObject(LDependenciesArray[LDependencyIndex]);
            var LDependency := TBoss4DBuildDependency.Create;
            try
              LDependency.Path := ReadString(LDependencyObject, 'path');
              LDependency.Optional := ReadBool(LDependencyObject,
                'optional');
              ParseStringArray(LDependencyObject, 'compilers',
                LDependency.Compilers);
              ParseStringArray(LDependencyObject, 'platforms',
                LDependency.Platforms);
              ParseStringArray(LDependencyObject, 'configurations',
                LDependency.Configurations);
              LProject.Dependencies.Add(LDependency);
              LDependency := nil;
            finally
              LDependency.Free;
            end;
          end;
      ParseStringArray(LProjectObject, 'compilers', LProject.Compilers);
      ParseStringArray(LProjectObject, 'platforms', LProject.Platforms);
      ParseStringArray(LProjectObject, 'configurations',
        LProject.Configurations);
      APackage.BuildMatrix.Projects.Add(LProject);
      LProject := nil;
    finally
      LProject.Free;
    end;
  end;
end;

procedure ParsePackageIDEAssets(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LAssetsObject: TJSONObject;
  LRegistryArray: TJSONArray;
begin
  LAssetsObject := ReadObject(AJSONObj, 'ideAssets');
  if not Assigned(LAssetsObject) then
    Exit;

  ParseStringArray(LAssetsObject, 'tools', APackage.IDEAssets.Tools);
  ParseStringArray(LAssetsObject, 'templates', APackage.IDEAssets.Templates);
  LRegistryArray := ReadArray(LAssetsObject, 'registry');
  if not Assigned(LRegistryArray) then
    Exit;
  for var I := 0 to LRegistryArray.Count - 1 do
  begin
    if not (LRegistryArray[I] is TJSONObject) then
      Continue;
    var LObject := TJSONObject(LRegistryArray[I]);
    var LValue := TBoss4DIDERegistryValue.Create;
    LValue.Key := ReadString(LObject, 'key');
    LValue.Name := ReadString(LObject, 'name');
    LValue.Value := ReadString(LObject, 'value');
    APackage.IDEAssets.RegistryValues.Add(LValue);
  end;
end;

// Subfunções auxiliares de Save para TBoss4DPackageJsonRepository.Save
procedure SavePackageProjects(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LProjectsArr: TJSONArray;
begin
  if APackage.Projects.Count > 0 then
  begin
    LProjectsArr := TJSONArray.Create;
    for var LProj in APackage.Projects do
      LProjectsArr.Add(LProj);
    AJSONObj.AddPair('projects', LProjectsArr);
  end;
end;

procedure SavePackageScripts(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LScriptsObj: TJSONObject;
begin
  if APackage.Scripts.Count > 0 then
  begin
    LScriptsObj := TJSONObject.Create;
    for var LPair in APackage.Scripts do
      LScriptsObj.AddPair(LPair.Key, LPair.Value);
    AJSONObj.AddPair('scripts', LScriptsObj);
  end;
end;

procedure SavePackageDependencies(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LDepsObj: TJSONObject;
begin
  if APackage.Dependencies.Count > 0 then
  begin
    LDepsObj := TJSONObject.Create;
    for var LPair in APackage.Dependencies do
      LDepsObj.AddPair(LPair.Key, LPair.Value);
    AJSONObj.AddPair('dependencies', LDepsObj);
  end;
end;

procedure ParsePackageTrust(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
  LSigners: TJSONArray;
begin
  LObj := ReadObject(AJSONObj, 'trust');
  if not Assigned(LObj) then Exit;
  APackage.Trust.RequireSignedCommits :=
    ReadBool(LObj, 'requireSignedCommits');
  APackage.Trust.RequireSignedTags := ReadBool(LObj, 'requireSignedTags');
  LSigners := ReadArray(LObj, 'allowedSigners');
  if Assigned(LSigners) then
    for var I := 0 to LSigners.Count - 1 do
      APackage.Trust.AllowedSigners.Add(LSigners[I].Value);
end;

procedure SavePackageDevDependencies(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LDepsObj: TJSONObject;
begin
  if APackage.DevDependencies.Count = 0 then
    Exit;
  LDepsObj := TJSONObject.Create;
  for var LPair in APackage.DevDependencies do
    LDepsObj.AddPair(LPair.Key, LPair.Value);
  AJSONObj.AddPair('devDependencies', LDepsObj);
end;

procedure SavePackageEngines(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LEnginesObj: TJSONObject;
  LPlatformsArr: TJSONArray;
begin
  if not APackage.Engines.Compiler.IsEmpty or (APackage.Engines.Platforms.Count > 0) then
  begin
    LEnginesObj := TJSONObject.Create;
    if not APackage.Engines.Compiler.IsEmpty then
      LEnginesObj.AddPair('compiler', APackage.Engines.Compiler);

    if APackage.Engines.Platforms.Count > 0 then
    begin
      LPlatformsArr := TJSONArray.Create;
      for var LPlat in APackage.Engines.Platforms do
        LPlatformsArr.Add(LPlat);
      LEnginesObj.AddPair('platforms', LPlatformsArr);
    end;
    AJSONObj.AddPair('engines', LEnginesObj);
  end;
end;

procedure SavePackageTrust(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LObj: TJSONObject;
  LSigners: TJSONArray;
begin
  if not APackage.Trust.RequireSignedCommits and
     not APackage.Trust.RequireSignedTags and
     (APackage.Trust.AllowedSigners.Count = 0) then Exit;
  LObj := TJSONObject.Create;
  LObj.AddPair('requireSignedCommits',
    TJSONBool.Create(APackage.Trust.RequireSignedCommits));
  LObj.AddPair('requireSignedTags',
    TJSONBool.Create(APackage.Trust.RequireSignedTags));
  LSigners := TJSONArray.Create;
  for var LSigner in APackage.Trust.AllowedSigners do
    LSigners.Add(LSigner);
  LObj.AddPair('allowedSigners', LSigners);
  AJSONObj.AddPair('trust', LObj);
end;

procedure SavePackageToolchain(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LToolchainObj: TJSONObject;
begin
  if not APackage.Toolchain.Compiler.IsEmpty or not APackage.Toolchain.Platform.IsEmpty then
  begin
    LToolchainObj := TJSONObject.Create;
    LToolchainObj.AddPair('compiler', APackage.Toolchain.Compiler);
    LToolchainObj.AddPair('platform', APackage.Toolchain.Platform);
    LToolchainObj.AddPair('path', APackage.Toolchain.Path);
    LToolchainObj.AddPair('strict', TJSONBool.Create(APackage.Toolchain.Strict));
    AJSONObj.AddPair('toolchain', LToolchainObj);
  end;
end;

function CreateSortedStringArray(const AValues: TList<string>): TJSONArray;
var
  LSorted: TList<string>;
begin
  Result := TJSONArray.Create;
  LSorted := TList<string>.Create;
  try
    LSorted.AddRange(AValues);
    LSorted.Sort(TComparer<string>.Construct(
      function(const ALeft, ARight: string): Integer
      begin
        Result := CompareText(ALeft, ARight);
      end));
    for var LValue in LSorted do
      Result.Add(LValue);
  finally
    LSorted.Free;
  end;
end;

procedure AddStringArrayIfPresent(const AObject: TJSONObject;
  const AName: string; const AValues: TList<string>);
begin
  if AValues.Count > 0 then
    AObject.AddPair(AName, CreateSortedStringArray(AValues));
end;

procedure SavePackageBuildMatrix(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LMatrixObject: TJSONObject;
  LDefaultsObject: TJSONObject;
  LProjectsArray: TJSONArray;
  LProjects: TList<TBoss4DBuildProject>;
begin
  if not APackage.BuildMatrix.IsDeclared then
    Exit;

  LMatrixObject := TJSONObject.Create;
  AddStringArrayIfPresent(LMatrixObject, 'compilers',
    APackage.BuildMatrix.Compilers);
  AddStringArrayIfPresent(LMatrixObject, 'platforms',
    APackage.BuildMatrix.Platforms);
  AddStringArrayIfPresent(LMatrixObject, 'configurations',
    APackage.BuildMatrix.Configurations);

  if not APackage.BuildMatrix.DefaultCompiler.IsEmpty or
     not APackage.BuildMatrix.DefaultPlatform.IsEmpty or
     not APackage.BuildMatrix.DefaultConfiguration.IsEmpty then
  begin
    LDefaultsObject := TJSONObject.Create;
    if not APackage.BuildMatrix.DefaultCompiler.IsEmpty then
      LDefaultsObject.AddPair('compiler',
        APackage.BuildMatrix.DefaultCompiler);
    if not APackage.BuildMatrix.DefaultPlatform.IsEmpty then
      LDefaultsObject.AddPair('platform',
        APackage.BuildMatrix.DefaultPlatform);
    if not APackage.BuildMatrix.DefaultConfiguration.IsEmpty then
      LDefaultsObject.AddPair('configuration',
        APackage.BuildMatrix.DefaultConfiguration);
    LMatrixObject.AddPair('defaults', LDefaultsObject);
  end;

  if APackage.BuildMatrix.Projects.Count > 0 then
  begin
    LProjectsArray := TJSONArray.Create;
    LProjects := TList<TBoss4DBuildProject>.Create;
    try
      for var LProject in APackage.BuildMatrix.Projects do
        LProjects.Add(LProject);
      LProjects.Sort(TComparer<TBoss4DBuildProject>.Construct(
        function(const ALeft, ARight: TBoss4DBuildProject): Integer
        begin
          Result := CompareText(ALeft.Path, ARight.Path);
        end));
      for var LProject in LProjects do
      begin
        var LProjectObject := TJSONObject.Create;
        LProjectObject.AddPair('path', LProject.Path);
        if not LProject.PackageName.IsEmpty then
          LProjectObject.AddPair('packageName', LProject.PackageName);
        if not LProject.IDEPackageDescription.IsEmpty or
           not LProject.PalettePage.IsEmpty then
        begin
          var LIDEObject := TJSONObject.Create;
          if not LProject.IDEPackageDescription.IsEmpty then
            LIDEObject.AddPair('description',
              LProject.IDEPackageDescription);
          if not LProject.PalettePage.IsEmpty then
            LIDEObject.AddPair('palettePage', LProject.PalettePage);
          LProjectObject.AddPair('ide', LIDEObject);
        end;
        LProjectObject.AddPair('kind', LProject.Kind);
        AddStringArrayIfPresent(LProjectObject, 'dependsOn',
          LProject.DependsOn);
        if LProject.Dependencies.Count > 0 then
        begin
          var LDependenciesArray := TJSONArray.Create;
          for var LDependency in LProject.Dependencies do
          begin
            var LDependencyObject := TJSONObject.Create;
            LDependencyObject.AddPair('path', LDependency.Path);
            if LDependency.Optional then
              LDependencyObject.AddPair('optional', TJSONBool.Create(True));
            AddStringArrayIfPresent(LDependencyObject, 'compilers',
              LDependency.Compilers);
            AddStringArrayIfPresent(LDependencyObject, 'platforms',
              LDependency.Platforms);
            AddStringArrayIfPresent(LDependencyObject, 'configurations',
              LDependency.Configurations);
            LDependenciesArray.AddElement(LDependencyObject);
          end;
          LProjectObject.AddPair('dependencies', LDependenciesArray);
        end;
        AddStringArrayIfPresent(LProjectObject, 'compilers',
          LProject.Compilers);
        AddStringArrayIfPresent(LProjectObject, 'platforms',
          LProject.Platforms);
        AddStringArrayIfPresent(LProjectObject, 'configurations',
          LProject.Configurations);
        LProjectsArray.AddElement(LProjectObject);
      end;
    finally
      LProjects.Free;
    end;
    LMatrixObject.AddPair('projects', LProjectsArray);
  end;
  AJSONObj.AddPair('buildMatrix', LMatrixObject);
end;

procedure SavePackageIDEAssets(const AJSONObj: TJSONObject;
  const APackage: TBoss4DPackage);
var
  LAssetsObject: TJSONObject;
  LRegistryArray: TJSONArray;
begin
  if not APackage.IDEAssets.IsDeclared then
    Exit;

  LAssetsObject := TJSONObject.Create;
  AddStringArrayIfPresent(LAssetsObject, 'tools', APackage.IDEAssets.Tools);
  AddStringArrayIfPresent(LAssetsObject, 'templates',
    APackage.IDEAssets.Templates);
  if APackage.IDEAssets.RegistryValues.Count > 0 then
  begin
    LRegistryArray := TJSONArray.Create;
    for var LValue in APackage.IDEAssets.RegistryValues do
    begin
      var LObject := TJSONObject.Create;
      LObject.AddPair('key', LValue.Key);
      LObject.AddPair('name', LValue.Name);
      LObject.AddPair('value', LValue.Value);
      LRegistryArray.AddElement(LObject);
    end;
    LAssetsObject.AddPair('registry', LRegistryArray);
  end;
  AJSONObj.AddPair('ideAssets', LAssetsObject);
end;

// Subfunções auxiliares de Parse para TBoss4DLockJsonRepository.Load
procedure ParseLockArtifacts(const AArtifactsObj: TJSONObject; const ALockedDep: TBoss4DLockedDependency);
var
  LBinArr, LDcpArr, LDcuArr, LBplArr: TJSONArray;
begin
  ALockedDep.Artifacts.Base := ReadString(AArtifactsObj, 'base');
  if ALockedDep.Artifacts.Base.IsEmpty then
    ALockedDep.Artifacts.Base := 'project';
  LBinArr := ReadArray(AArtifactsObj, 'bin');
  if Assigned(LBinArr) then
    for var I := 0 to LBinArr.Count - 1 do ALockedDep.Artifacts.Bin.Add(LBinArr[I].Value);

  LDcpArr := ReadArray(AArtifactsObj, 'dcp');
  if Assigned(LDcpArr) then
    for var I := 0 to LDcpArr.Count - 1 do ALockedDep.Artifacts.Dcp.Add(LDcpArr[I].Value);

  LDcuArr := ReadArray(AArtifactsObj, 'dcu');
  if Assigned(LDcuArr) then
    for var I := 0 to LDcuArr.Count - 1 do ALockedDep.Artifacts.Dcu.Add(LDcuArr[I].Value);

  LBplArr := ReadArray(AArtifactsObj, 'bpl');
  if Assigned(LBplArr) then
    for var I := 0 to LBplArr.Count - 1 do ALockedDep.Artifacts.Bpl.Add(LBplArr[I].Value);
end;

procedure ParsePackageWorkspaces(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LArr: TJSONArray;
begin
  LArr := ReadArray(AJSONObj, 'workspaces');
  if Assigned(LArr) then
  begin
    for var I := 0 to LArr.Count - 1 do
      APackage.Workspaces.Add(LArr[I].Value);
  end;
end;

procedure SavePackageWorkspaces(const AJSONObj: TJSONObject; const APackage: TBoss4DPackage);
var
  LWorkspacesArr: TJSONArray;
begin
  if APackage.Workspaces.Count > 0 then
  begin
    LWorkspacesArr := TJSONArray.Create;
    for var LWork in APackage.Workspaces do
      LWorkspacesArr.Add(LWork);
    AJSONObj.AddPair('workspaces', LWorkspacesArr);
  end;
end;

{ TBoss4DPackageJsonRepository }

function TBoss4DPackageJsonRepository.Exists(const APackagePath: string): Boolean;
begin
  Result := TFile.Exists(APackagePath);
end;

function TBoss4DPackageJsonRepository.Load(const APackagePath: string): TBoss4DPackage;
var
  LJSONStr: string;
  LJSONObj: TJSONObject;
begin
  Result := TBoss4DPackage.Create;
  try
    if not TFile.Exists(APackagePath) then
      Exit;

    LJSONStr := TFile.ReadAllText(APackagePath, TEncoding.UTF8);
    var LParsedValue := TJSONObject.ParseJSONValue(LJSONStr);
    if not Assigned(LParsedValue) or not (LParsedValue is TJSONObject) then
    begin
      LParsedValue.Free;
      Exit;
    end;

    LJSONObj := LParsedValue as TJSONObject;
    try
      Result.Name := ReadString(LJSONObj, 'name');
      Result.Description := ReadString(LJSONObj, 'description');
      Result.Version := ReadString(LJSONObj, 'version');
      Result.Homepage := ReadString(LJSONObj, 'homepage');
      Result.IDEProfile := ReadString(LJSONObj, 'ideProfile');
      Result.License := ReadString(LJSONObj, 'license');
      Result.MainSrc := ReadString(LJSONObj, 'mainsrc');
      Result.BrowsingPath := ReadString(LJSONObj, 'browsingpath');

      ParsePackageProjects(LJSONObj, Result);
      ParsePackageScripts(LJSONObj, Result);
      ParsePackageDependencies(LJSONObj, Result);
      ParsePackageDevDependencies(LJSONObj, Result);
      ParsePackageSbomComponents(LJSONObj, Result);
      ParsePackageEngines(LJSONObj, Result);
      ParsePackageToolchain(LJSONObj, Result);
      ParsePackageBuildMatrix(LJSONObj, Result);
      ParsePackageIDEAssets(LJSONObj, Result);
      ParsePackageTrust(LJSONObj, Result);
      ParsePackageWorkspaces(LJSONObj, Result);
    finally
      LJSONObj.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TBoss4DPackageJsonRepository.Save(const APackage: TBoss4DPackage; const APackagePath: string);
var
  LJSONObj: TJSONObject;
  LJSONStr: string;
  LEncoding: TEncoding;
begin
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('name', APackage.Name);
    LJSONObj.AddPair('description', APackage.Description);
    LJSONObj.AddPair('version', APackage.Version);
    LJSONObj.AddPair('homepage', APackage.Homepage);
    if not APackage.IDEProfile.IsEmpty then
      LJSONObj.AddPair('ideProfile', APackage.IDEProfile);

    if not APackage.License.IsEmpty then
      LJSONObj.AddPair('license', APackage.License);

    if not APackage.MainSrc.IsEmpty then
      LJSONObj.AddPair('mainsrc', APackage.MainSrc);

    if not APackage.BrowsingPath.IsEmpty then
      LJSONObj.AddPair('browsingpath', APackage.BrowsingPath);

    SavePackageProjects(LJSONObj, APackage);
    SavePackageScripts(LJSONObj, APackage);
    SavePackageDependencies(LJSONObj, APackage);
    SavePackageDevDependencies(LJSONObj, APackage);

    if APackage.SbomComponents.Count > 0 then
    begin
      var LSbomObj := TJSONObject.Create;
      var LComponentsArr := TJSONArray.Create;
      for var LComponent in APackage.SbomComponents do
      begin
        var LComponentObj := TJSONObject.Create;
        if not LComponent.Id.IsEmpty then LComponentObj.AddPair('id', LComponent.Id);
        LComponentObj.AddPair('name', LComponent.Name);
        if not LComponent.Version.IsEmpty then LComponentObj.AddPair('version', LComponent.Version);
        if not LComponent.ComponentType.IsEmpty then LComponentObj.AddPair('type', LComponent.ComponentType);
        if not LComponent.Description.IsEmpty then LComponentObj.AddPair('description', LComponent.Description);
        if not LComponent.License.IsEmpty then LComponentObj.AddPair('license', LComponent.License);
        if not LComponent.Repository.IsEmpty then LComponentObj.AddPair('repository', LComponent.Repository);
        if not LComponent.Source.IsEmpty then LComponentObj.AddPair('source', LComponent.Source);
        if not LComponent.HashValue.IsEmpty then
        begin
          var LHashObj := TJSONObject.Create;
          LHashObj.AddPair('algorithm', LComponent.HashAlgorithm);
          LHashObj.AddPair('value', LComponent.HashValue);
          LComponentObj.AddPair('hash', LHashObj);
        end;
        LComponentsArr.AddElement(LComponentObj);
      end;
      LSbomObj.AddPair('components', LComponentsArr);
      LJSONObj.AddPair('sbom', LSbomObj);
    end;
    SavePackageEngines(LJSONObj, APackage);
    SavePackageToolchain(LJSONObj, APackage);
    SavePackageBuildMatrix(LJSONObj, APackage);
    SavePackageIDEAssets(LJSONObj, APackage);
    SavePackageTrust(LJSONObj, APackage);
    SavePackageWorkspaces(LJSONObj, APackage);

    LJSONStr := LJSONObj.Format(2);
    LEncoding := TUTF8Encoding.Create(False); // UTF-8 sem BOM para compatibilidade com o parser Go original
    try
      TFile.WriteAllText(APackagePath, LJSONStr, LEncoding);
    finally
      LEncoding.Free;
    end;
  finally
    LJSONObj.Free;
  end;
end;

{ TBoss4DLockJsonRepository }

function TBoss4DLockJsonRepository.Exists(const ALockPath: string): Boolean;
begin
  Result := TFile.Exists(ALockPath);
end;

function TBoss4DLockJsonRepository.Load(const ALockPath: string): TBoss4DLock;
var
  LJSONStr: string;
  LJSONObj: TJSONObject;
begin
  Result := TBoss4DLock.Create;
  try
    if not TFile.Exists(ALockPath) then
      Exit;

    LJSONStr := TFile.ReadAllText(ALockPath, TEncoding.UTF8);
    var LParsedValue := TJSONObject.ParseJSONValue(LJSONStr);
    if not Assigned(LParsedValue) or not (LParsedValue is TJSONObject) then
    begin
      LParsedValue.Free;
      Exit;
    end;

    LJSONObj := LParsedValue as TJSONObject;
    try
      Result.LockVersion := ReadInteger(LJSONObj, 'lockVersion', 1);
      if Result.LockVersion > TBoss4DLockSchema.CurrentVersion then
        raise EConvertError.CreateFmt(
          'Versao de boss-lock.json nao suportada: %d (maximo suportado: %d).',
          [Result.LockVersion, TBoss4DLockSchema.CurrentVersion]);
      Result.Hash := ReadString(LJSONObj, 'hash');
      Result.Updated := ReadString(LJSONObj, 'updated');

      var LRootObj := ReadObject(LJSONObj, 'root');
      if Assigned(LRootObj) then
      begin
        Result.HasRootMetadata := True;
        Result.RootName := ReadString(LRootObj, 'name');
        Result.RootVersion := ReadString(LRootObj, 'version');
        Result.RootDescription := ReadString(LRootObj, 'description');
        Result.RootHomepage := ReadString(LRootObj, 'homepage');
        Result.RootLicense := ReadString(LRootObj, 'license');
        var LRootDeps := ReadArray(LRootObj, 'dependencies');
        if Assigned(LRootDeps) then
          for var I := 0 to LRootDeps.Count - 1 do
            Result.RootDependencies.Add(LRootDeps[I].Value);
        var LRootDevDeps := ReadArray(LRootObj, 'devDependencies');
        if Assigned(LRootDevDeps) then
          for var I := 0 to LRootDevDeps.Count - 1 do
            Result.RootDevDependencies.Add(LRootDevDeps[I].Value);
      end;

      var LInstalledObj := ReadObject(LJSONObj, 'installedModules');
      if Assigned(LInstalledObj) then
      begin
        for var LPair in LInstalledObj do
        begin
          var LDepObj := LPair.JsonValue as TJSONObject;
          if Assigned(LDepObj) then
          begin
            var LLockedDep := TBoss4DLockedDependency.Create;
            LLockedDep.Name := ReadString(LDepObj, 'name');
            LLockedDep.Version := ReadString(LDepObj, 'version');
            LLockedDep.Hash := ReadString(LDepObj, 'hash');
            LLockedDep.Scope := ReadString(LDepObj, 'scope');
            if LLockedDep.Scope.IsEmpty then
              LLockedDep.Scope := 'runtime';
            ParseLockMetadata(LDepObj, LLockedDep);

            var LArtifactsObj := ReadObject(LDepObj, 'artifacts');
            if Assigned(LArtifactsObj) then
              ParseLockArtifacts(LArtifactsObj, LLockedDep);

            // Insere no dicionario com chave em minusculas
            Result.Installed.Add(LPair.JsonString.Value.ToLower, LLockedDep);
          end;
        end;
      end;
    finally
      LJSONObj.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TBoss4DLockJsonRepository.Save(const ALock: TBoss4DLock; const ALockPath: string);
var
  LJSONObj: TJSONObject;
  LInstalledObj: TJSONObject;
  LDepObj: TJSONObject;
  LArtifactsObj: TJSONObject;
  LChecksumObj: TJSONObject;
  LLicenseObj: TJSONObject;
  LDependenciesArr: TJSONArray;
  LBinArr, LDcpArr, LDcuArr, LBplArr: TJSONArray;
  LJSONStr: string;
  LEncoding: TEncoding;
  LInstalledKeys: TList<string>;
  LDependencyKeys: TList<string>;
  LRootObj: TJSONObject;
  LRootDependenciesArr: TJSONArray;
  LRootDevDependenciesArr: TJSONArray;
begin
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('lockVersion', TJSONNumber.Create(TBoss4DLockSchema.CurrentVersion));
    LJSONObj.AddPair('hash', ALock.Hash);
    LJSONObj.AddPair('updated', ALock.Updated);

    if ALock.HasRootMetadata then
    begin
      LRootObj := TJSONObject.Create;
      LRootObj.AddPair('name', ALock.RootName);
      LRootObj.AddPair('version', ALock.RootVersion);
      if not ALock.RootDescription.IsEmpty then LRootObj.AddPair('description', ALock.RootDescription);
      if not ALock.RootHomepage.IsEmpty then LRootObj.AddPair('homepage', ALock.RootHomepage);
      if not ALock.RootLicense.IsEmpty then LRootObj.AddPair('license', ALock.RootLicense);
      LRootDependenciesArr := TJSONArray.Create;
      LDependencyKeys := TList<string>.Create;
      try
        LDependencyKeys.AddRange(ALock.RootDependencies);
        LDependencyKeys.Sort;
        for var LDependencyKey in LDependencyKeys do LRootDependenciesArr.Add(LDependencyKey);
      finally
        LDependencyKeys.Free;
      end;
      LRootObj.AddPair('dependencies', LRootDependenciesArr);
      LRootDevDependenciesArr := TJSONArray.Create;
      LDependencyKeys := TList<string>.Create;
      try
        LDependencyKeys.AddRange(ALock.RootDevDependencies);
        LDependencyKeys.Sort;
        for var LDependencyKey in LDependencyKeys do
          LRootDevDependenciesArr.Add(LDependencyKey);
      finally
        LDependencyKeys.Free;
      end;
      LRootObj.AddPair('devDependencies', LRootDevDependenciesArr);
      LJSONObj.AddPair('root', LRootObj);
    end;

    LInstalledObj := TJSONObject.Create;
    LInstalledKeys := TList<string>.Create;
    try
      for var LInstalledKey in ALock.Installed.Keys do
        LInstalledKeys.Add(LInstalledKey);
      LInstalledKeys.Sort;

      for var LInstalledKey in LInstalledKeys do
      begin
        var LLockedDependency := ALock.Installed[LInstalledKey];
        LDepObj := TJSONObject.Create;
        LDepObj.AddPair('name', LLockedDependency.Name);
        LDepObj.AddPair('version', LLockedDependency.Version);
        LDepObj.AddPair('hash', LLockedDependency.Hash);
        LDepObj.AddPair('scope', LLockedDependency.Scope);

        if not LLockedDependency.Repository.IsEmpty then
          LDepObj.AddPair('repository', LLockedDependency.Repository);
        if not LLockedDependency.Revision.IsEmpty then
          LDepObj.AddPair('revision', LLockedDependency.Revision);
        if not LLockedDependency.ResolvedFrom.IsEmpty then
          LDepObj.AddPair('resolvedFrom', LLockedDependency.ResolvedFrom);

        if not LLockedDependency.Checksum.IsEmpty then
        begin
          LChecksumObj := TJSONObject.Create;
          LChecksumObj.AddPair('algorithm', LLockedDependency.ChecksumAlgorithm);
          LChecksumObj.AddPair('value', LLockedDependency.Checksum);
          LDepObj.AddPair('checksum', LChecksumObj);
        end;

        if not LLockedDependency.LicenseExpression.IsEmpty or not LLockedDependency.LicenseSource.IsEmpty then
        begin
          LLicenseObj := TJSONObject.Create;
          if not LLockedDependency.LicenseExpression.IsEmpty then
            LLicenseObj.AddPair('expression', LLockedDependency.LicenseExpression);
          if not LLockedDependency.LicenseSource.IsEmpty then
            LLicenseObj.AddPair('source', LLockedDependency.LicenseSource);
          LDepObj.AddPair('license', LLicenseObj);
        end;

        LDependenciesArr := TJSONArray.Create;
        LDependencyKeys := TList<string>.Create;
        try
          LDependencyKeys.AddRange(LLockedDependency.Dependencies);
          LDependencyKeys.Sort;
          for var LDependencyKey in LDependencyKeys do
            LDependenciesArr.Add(LDependencyKey);
        finally
          LDependencyKeys.Free;
        end;
        LDepObj.AddPair('dependencies', LDependenciesArr);

      // Artifacts
      LArtifactsObj := TJSONObject.Create;
      LArtifactsObj.AddPair('base', LLockedDependency.Artifacts.Base);

      LBinArr := TJSONArray.Create;
        for var LArt in LLockedDependency.Artifacts.Bin do LBinArr.Add(LArt);
      LArtifactsObj.AddPair('bin', LBinArr);

      LDcpArr := TJSONArray.Create;
        for var LArt in LLockedDependency.Artifacts.Dcp do LDcpArr.Add(LArt);
      LArtifactsObj.AddPair('dcp', LDcpArr);

      LDcuArr := TJSONArray.Create;
        for var LArt in LLockedDependency.Artifacts.Dcu do LDcuArr.Add(LArt);
      LArtifactsObj.AddPair('dcu', LDcuArr);

      LBplArr := TJSONArray.Create;
        for var LArt in LLockedDependency.Artifacts.Bpl do LBplArr.Add(LArt);
      LArtifactsObj.AddPair('bpl', LBplArr);

      LDepObj.AddPair('artifacts', LArtifactsObj);

        LInstalledObj.AddPair(LInstalledKey, LDepObj);
      end;
    finally
      LInstalledKeys.Free;
    end;

    LJSONObj.AddPair('installedModules', LInstalledObj);

    LJSONStr := LJSONObj.Format(2);
    LEncoding := TUTF8Encoding.Create(False); // UTF-8 sem BOM para compatibilidade com o parser Go original
    try
      TFile.WriteAllText(ALockPath, LJSONStr, LEncoding);
    finally
      LEncoding.Free;
    end;
  finally
    LJSONObj.Free;
  end;
end;

end.
