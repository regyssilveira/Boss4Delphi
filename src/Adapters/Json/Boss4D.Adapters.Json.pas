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
  System.SysUtils, System.IOUtils, System.JSON, System.Generics.Collections;

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

// Subfunções auxiliares de Parse para TBoss4DLockJsonRepository.Load
procedure ParseLockArtifacts(const AArtifactsObj: TJSONObject; const ALockedDep: TBoss4DLockedDependency);
var
  LBinArr, LDcpArr, LDcuArr, LBplArr: TJSONArray;
begin
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
      Result.MainSrc := ReadString(LJSONObj, 'mainsrc');
      Result.BrowsingPath := ReadString(LJSONObj, 'browsingpath');

      ParsePackageProjects(LJSONObj, Result);
      ParsePackageScripts(LJSONObj, Result);
      ParsePackageDependencies(LJSONObj, Result);
      ParsePackageEngines(LJSONObj, Result);
      ParsePackageToolchain(LJSONObj, Result);
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

    if not APackage.MainSrc.IsEmpty then
      LJSONObj.AddPair('mainsrc', APackage.MainSrc);

    if not APackage.BrowsingPath.IsEmpty then
      LJSONObj.AddPair('browsingpath', APackage.BrowsingPath);

    SavePackageProjects(LJSONObj, APackage);
    SavePackageScripts(LJSONObj, APackage);
    SavePackageDependencies(LJSONObj, APackage);
    SavePackageEngines(LJSONObj, APackage);
    SavePackageToolchain(LJSONObj, APackage);

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
      Result.Hash := ReadString(LJSONObj, 'hash');
      Result.Updated := ReadString(LJSONObj, 'updated');

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
  LBinArr, LDcpArr, LDcuArr, LBplArr: TJSONArray;
  LJSONStr: string;
  LEncoding: TEncoding;
begin
  LJSONObj := TJSONObject.Create;
  try
    LJSONObj.AddPair('hash', ALock.Hash);
    LJSONObj.AddPair('updated', ALock.Updated);

    LInstalledObj := TJSONObject.Create;
    for var LPair in ALock.Installed do
    begin
      LDepObj := TJSONObject.Create;
      LDepObj.AddPair('name', LPair.Value.Name);
      LDepObj.AddPair('version', LPair.Value.Version);
      LDepObj.AddPair('hash', LPair.Value.Hash);

      // Artifacts
      LArtifactsObj := TJSONObject.Create;

      LBinArr := TJSONArray.Create;
      for var LArt in LPair.Value.Artifacts.Bin do LBinArr.Add(LArt);
      LArtifactsObj.AddPair('bin', LBinArr);

      LDcpArr := TJSONArray.Create;
      for var LArt in LPair.Value.Artifacts.Dcp do LDcpArr.Add(LArt);
      LArtifactsObj.AddPair('dcp', LDcpArr);

      LDcuArr := TJSONArray.Create;
      for var LArt in LPair.Value.Artifacts.Dcu do LDcuArr.Add(LArt);
      LArtifactsObj.AddPair('dcu', LDcuArr);

      LBplArr := TJSONArray.Create;
      for var LArt in LPair.Value.Artifacts.Bpl do LBplArr.Add(LArt);
      LArtifactsObj.AddPair('bpl', LBplArr);

      LDepObj.AddPair('artifacts', LArtifactsObj);

      LInstalledObj.AddPair(LPair.Key, LDepObj);
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
