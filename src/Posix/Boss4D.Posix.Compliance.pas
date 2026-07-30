unit Boss4D.Posix.Compliance;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DSbomFormat = (sfCycloneDX, sfSpdx);

  TBoss4DSbomOptions = record
    Format: TBoss4DSbomFormat;
    VexPath: string;
    Reproducible: Boolean;
    Strict: Boolean;
    Validate: Boolean;
  end;

procedure GenerateLockSbom(const ALockPath, AOutputPath: string;
  const AOptions: TBoss4DSbomOptions);
procedure ValidateGeneratedSbom(const APath: string;
  const AFormat: TBoss4DSbomFormat);
function DefaultSbomOptions(
  const AFormat: TBoss4DSbomFormat): TBoss4DSbomOptions;

implementation

uses
  fpjson, jsonparser, Boss4D.Posix.Core, Boss4D.Posix.Operations;

function DefaultSbomOptions(
  const AFormat: TBoss4DSbomFormat): TBoss4DSbomOptions;
begin
  Result.Format := AFormat;
  Result.VexPath := '';
  Result.Reproducible := False;
  Result.Strict := False;
  Result.Validate := False;
end;

function FindObject(const ARoot: TJSONObject; const AName: string): TJSONObject;
var
  LData: TJSONData;
begin
  Result := nil;
  LData := ARoot.Find(AName);
  if LData is TJSONObject then Result := TJSONObject(LData);
end;

function SafeId(const AValue: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValue) do
    if AValue[I] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-'] then
      Result := Result + AValue[I]
    else
      Result := Result + '-';
end;

function ChecksumValue(const AEntry: TJSONObject): string;
var
  LData: TJSONData;
  LObject: TJSONObject;
begin
  Result := '';
  LData := AEntry.Find('checksum');
  if not Assigned(LData) then Exit;
  if LData.JSONType = jtString then
  begin
    Result := LData.AsString;
    if Pos('sha256:', LowerCase(Result)) = 1 then Delete(Result, 1, 7);
  end
  else if LData is TJSONObject then
  begin
    LObject := TJSONObject(LData);
    Result := LObject.Get('value', '');
  end;
end;

function CreatedAt(const ALock: TJSONObject;
  const AReproducible: Boolean): string;
begin
  if AReproducible then Exit('1970-01-01T00:00:00Z');
  Result := ALock.Get('updated', '');
  if Result = '' then Result := FormatDateTime(
    'yyyy-mm-dd"T"hh:nn:ss"Z"', Now);
end;

procedure SaveJson(const APath: string; const AData: TJSONData);
var
  LStream: TStringList;
begin
  ForceDirectories(ExtractFileDir(ExpandFileName(APath)));
  LStream := TStringList.Create;
  try
    LStream.Text := AData.FormatJSON;
    LStream.SaveToFile(APath);
  finally
    LStream.Free;
  end;
end;

procedure AddCycloneDxVex(const ARoot: TJSONObject; const AVexPath: string);
var
  LVexData: TJSONData;
  LVexRoot, LVexItem, LVulnerability, LAnalysis: TJSONObject;
  LVexItems, LVulnerabilities, LAffects: TJSONArray;
  LStream: TFileStream;
  I: Integer;
  LComponent, LState: string;
begin
  if AVexPath = '' then Exit;
  LStream := TFileStream.Create(AVexPath, fmOpenRead or fmShareDenyWrite);
  try
    LVexData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  try
    if not (LVexData is TJSONObject) then
      raise Exception.Create('VEX root must be an object');
    LVexRoot := TJSONObject(LVexData);
    if not (LVexRoot.Find('vulnerabilities') is TJSONArray) then
      raise Exception.Create('VEX vulnerabilities array is required');
    LVexItems := TJSONArray(LVexRoot.Find('vulnerabilities'));
    LVulnerabilities := TJSONArray.Create;
    ARoot.Add('vulnerabilities', LVulnerabilities);
    for I := 0 to LVexItems.Count - 1 do
    begin
      if not (LVexItems.Items[I] is TJSONObject) then Continue;
      LVexItem := TJSONObject(LVexItems.Items[I]);
      LState := LVexItem.Get('state', '');
      if not (LState = 'affected') and not (LState = 'not_affected') and
         not (LState = 'fixed') and
         not (LState = 'under_investigation') then
        raise Exception.Create('unsupported VEX state: ' + LState);
      LVulnerability := TJSONObject.Create;
      LVulnerability.Add('id', LVexItem.Get('id', ''));
      LComponent := LVexItem.Get('component', '');
      if LComponent <> '' then
      begin
        LAffects := TJSONArray.Create;
        LAffects.Add(TJSONObject.Create(['ref', LComponent]));
        LVulnerability.Add('affects', LAffects);
      end;
      LAnalysis := TJSONObject.Create;
      LAnalysis.Add('state', LState);
      if LVexItem.Get('detail', '') <> '' then
        LAnalysis.Add('detail', LVexItem.Get('detail', ''));
      LVulnerability.Add('analysis', LAnalysis);
      LVulnerabilities.Add(LVulnerability);
    end;
  finally
    LVexData.Free;
  end;
end;

procedure GenerateCycloneDx(const ALock: TJSONObject; const AOutputPath,
  AVexPath: string; const AReproducible: Boolean);
var
  LRoot, LMetadata, LTool, LComponent, LEntry, LProperty,
    LHash, LDependency: TJSONObject;
  LTools, LComponents, LHashes, LDependencies, LDependsOn:
    TJSONArray;
  LInstalledObject: TJSONObject;
  I: Integer;
  LRepository, LName, LVersion, LRef, LChecksum: string;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.Add('bomFormat', 'CycloneDX');
    LRoot.Add('specVersion', '1.7');
    LRoot.Add('version', 1);
    LMetadata := TJSONObject.Create;
    LMetadata.Add('timestamp', CreatedAt(ALock, AReproducible));
    LTools := TJSONArray.Create;
    LTool := TJSONObject.Create;
    LTool.Add('vendor', 'Boss4D');
    LTool.Add('name', 'Boss4D Linux/FPC');
    LTool.Add('version', Boss4DVersion);
    LTools.Add(LTool);
    LMetadata.Add('tools', LTools);
    LRoot.Add('metadata', LMetadata);
    LComponents := TJSONArray.Create;
    LRoot.Add('components', LComponents);
    LDependencies := TJSONArray.Create;
    LRoot.Add('dependencies', LDependencies);
    LInstalledObject := FindObject(ALock, 'installedModules');
    if Assigned(LInstalledObject) then
      for I := 0 to LInstalledObject.Count - 1 do
      begin
        CheckCancelled;
        LRepository := LInstalledObject.Names[I];
        if not (LInstalledObject.Items[I] is TJSONObject) then Continue;
        LEntry := TJSONObject(LInstalledObject.Items[I]);
        LName := LEntry.Get('name', DependencyTarget(LRepository));
        LVersion := LEntry.Get('version', '0.0.0');
        LRef := 'boss4d:' + SafeId(LName) + '@' + SafeId(LVersion);
        LComponent := TJSONObject.Create;
        LComponent.Add('type', 'library');
        LComponent.Add('bom-ref', LRef);
        LComponent.Add('name', LName);
        LComponent.Add('version', LVersion);
        LComponent.Add('purl', 'pkg:generic/' + SafeId(LName) + '@' +
          SafeId(LVersion));
        LChecksum := ChecksumValue(LEntry);
        if LChecksum <> '' then
        begin
          LHashes := TJSONArray.Create;
          LHash := TJSONObject.Create;
          LHash.Add('alg', 'SHA-256');
          LHash.Add('content', LowerCase(LChecksum));
          LHashes.Add(LHash);
          LComponent.Add('hashes', LHashes);
        end;
        LProperty := TJSONObject.Create;
        LProperty.Add('name', 'boss4d:scope');
        LProperty.Add('value', LEntry.Get('scope', 'runtime'));
        LComponents.Add(LComponent);
        LComponent.Add('properties', TJSONArray.Create([LProperty]));
        LDependency := TJSONObject.Create;
        LDependency.Add('ref', LRef);
        LDependsOn := TJSONArray.Create;
        LDependency.Add('dependsOn', LDependsOn);
        LDependencies.Add(LDependency);
      end;
    AddCycloneDxVex(LRoot, AVexPath);
    SaveJson(AOutputPath, LRoot);
  finally
    LRoot.Free;
  end;
end;

procedure GenerateSpdx(const ALock: TJSONObject; const AOutputPath: string;
  const AReproducible: Boolean);
var
  LRoot, LCreation, LPackage, LEntry, LRelationship,
    LChecksumObject: TJSONObject;
  LCreators, LPackages, LRelationships, LChecksums: TJSONArray;
  LInstalled: TJSONObject;
  I: Integer;
  LRepository, LName, LVersion, LId, LChecksum: string;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.Add('spdxVersion', 'SPDX-2.3');
    LRoot.Add('dataLicense', 'CC0-1.0');
    LRoot.Add('SPDXID', 'SPDXRef-DOCUMENT');
    LRoot.Add('name', 'Boss4D lock SBOM');
    LRoot.Add('documentNamespace', 'https://boss4d.dev/sbom/' +
      SafeId(ALock.Get('hash', 'lock')));
    LCreation := TJSONObject.Create;
    LCreators := TJSONArray.Create;
    LCreators.Add('Tool: Boss4D-' + Boss4DVersion);
    LCreation.Add('creators', LCreators);
    LCreation.Add('created', CreatedAt(ALock, AReproducible));
    LRoot.Add('creationInfo', LCreation);
    LPackages := TJSONArray.Create;
    LRoot.Add('packages', LPackages);
    LRelationships := TJSONArray.Create;
    LRoot.Add('relationships', LRelationships);
    LInstalled := FindObject(ALock, 'installedModules');
    if Assigned(LInstalled) then
      for I := 0 to LInstalled.Count - 1 do
      begin
        CheckCancelled;
        LRepository := LInstalled.Names[I];
        if not (LInstalled.Items[I] is TJSONObject) then Continue;
        LEntry := TJSONObject(LInstalled.Items[I]);
        LName := LEntry.Get('name', DependencyTarget(LRepository));
        LVersion := LEntry.Get('version', '0.0.0');
        LId := 'SPDXRef-Package-' + SafeId(LName) + '-' + SafeId(LVersion);
        LPackage := TJSONObject.Create;
        LPackage.Add('name', LName);
        LPackage.Add('SPDXID', LId);
        LPackage.Add('versionInfo', LVersion);
        LPackage.Add('downloadLocation', LRepository);
        LPackage.Add('filesAnalyzed', False);
        LPackage.Add('licenseConcluded', 'NOASSERTION');
        LPackage.Add('licenseDeclared', 'NOASSERTION');
        LPackage.Add('copyrightText', 'NOASSERTION');
        LPackage.Add('comment', 'boss4d:scope=' +
          LEntry.Get('scope', 'runtime'));
        LChecksum := ChecksumValue(LEntry);
        if LChecksum <> '' then
        begin
          LChecksums := TJSONArray.Create;
          LChecksumObject := TJSONObject.Create;
          LChecksumObject.Add('algorithm', 'SHA256');
          LChecksumObject.Add('checksumValue', LowerCase(LChecksum));
          LChecksums.Add(LChecksumObject);
          LPackage.Add('checksums', LChecksums);
        end;
        LPackages.Add(LPackage);
        LRelationship := TJSONObject.Create;
        LRelationship.Add('spdxElementId', 'SPDXRef-DOCUMENT');
        LRelationship.Add('relationshipType', 'DESCRIBES');
        LRelationship.Add('relatedSpdxElement', LId);
        LRelationships.Add(LRelationship);
      end;
    SaveJson(AOutputPath, LRoot);
  finally
    LRoot.Free;
  end;
end;

procedure ValidateStrictLock(const ALock: TJSONObject);
var
  LRoot, LInstalled, LEntry: TJSONObject;
  I: Integer;
begin
  LRoot := FindObject(ALock, 'root');
  if not Assigned(LRoot) or (LRoot.Get('name', '') = '') or
     (LRoot.Get('version', '') = '') then
    raise Exception.Create('strict lock requires root identity');
  LInstalled := FindObject(ALock, 'installedModules');
  for I := 0 to LInstalled.Count - 1 do
  begin
    if not (LInstalled.Items[I] is TJSONObject) then
      raise Exception.Create('strict lock dependency must be an object');
    LEntry := TJSONObject(LInstalled.Items[I]);
    if (LEntry.Get('name', '') = '') or (LEntry.Get('version', '') = '') or
       (LEntry.Get('repository', '') = '') then
      raise Exception.Create('strict lock requires dependency identity');
    if not Assigned(LEntry.Find('checksum')) then
      raise Exception.Create('strict lock requires dependency checksum');
    if SameText(LEntry.Get('resolvedFrom', ''), 'git') and
       (LEntry.Get('revision', '') = '') then
      raise Exception.Create('strict lock requires Git revision');
    if not (LEntry.Find('dependencies') is TJSONArray) then
      raise Exception.Create('strict lock requires dependency graph');
  end;
end;

procedure ValidateGeneratedSbom(const APath: string;
  const AFormat: TBoss4DSbomFormat);
var
  LRoot: TJSONObject;
begin
  LRoot := LoadJsonObject(APath);
  try
    if AFormat = sfCycloneDX then
    begin
      if (LRoot.Get('bomFormat', '') <> 'CycloneDX') or
         (LRoot.Get('specVersion', '') <> '1.7') or
         not (LRoot.Find('components') is TJSONArray) or
         not (LRoot.Find('dependencies') is TJSONArray) then
        raise Exception.Create('generated CycloneDX document is invalid');
    end
    else if (LRoot.Get('spdxVersion', '') <> 'SPDX-2.3') or
       (LRoot.Get('SPDXID', '') <> 'SPDXRef-DOCUMENT') or
       not (LRoot.Find('creationInfo') is TJSONObject) or
       not (LRoot.Find('packages') is TJSONArray) or
       not (LRoot.Find('relationships') is TJSONArray) then
      raise Exception.Create('generated SPDX document is invalid');
  finally
    LRoot.Free;
  end;
end;

procedure GenerateLockSbom(const ALockPath, AOutputPath: string;
  const AOptions: TBoss4DSbomOptions);
var
  LLock: TJSONObject;
begin
  if not FileExists(ALockPath) then
    raise Exception.Create('lock not found: ' + ALockPath);
  if (AOptions.Format = sfSpdx) and (AOptions.VexPath <> '') then
    raise Exception.Create('VEX requires CycloneDX');
  LLock := LoadJsonObject(ALockPath);
  try
    if not Assigned(LLock.Find('installedModules')) then
      raise Exception.Create('lock installedModules object is required');
    if AOptions.Strict then ValidateStrictLock(LLock);
    if AOptions.Format = sfCycloneDX then
      GenerateCycloneDx(LLock, AOutputPath, AOptions.VexPath,
        AOptions.Reproducible)
    else
      GenerateSpdx(LLock, AOutputPath, AOptions.Reproducible);
    if AOptions.Validate then
      ValidateGeneratedSbom(AOutputPath, AOptions.Format);
  finally
    LLock.Free;
  end;
end;

end.
