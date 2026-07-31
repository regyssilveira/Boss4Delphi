unit Boss4D.Posix.RegistryHealth;

{$mode objfpc}{$H+}

interface

type
  TBoss4DRegistryHealthResult = record
    Passed: Boolean;
    PackageCount: Integer;
    LegacyPackageCount: Integer;
    TrustedPackageCount: Integer;
    WarningCount: Integer;
    ErrorCount: Integer;
    Summary: string;
  end;

function AuditRegistryHealth(const ARoot: string):
  TBoss4DRegistryHealthResult;

implementation

uses
  Classes, SysUtils, fpjson, jsonparser;

function LoadObject(const APath: string): TJSONObject;
var
  LStream: TFileStream;
  LValue: TJSONData;
begin
  if not FileExists(APath) then
    raise Exception.Create('Registry file not found: ' + APath);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LValue := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise Exception.Create('Registry file must be an object: ' + APath);
  end;
  Result := TJSONObject(LValue);
end;

function ArrayContains(const AArray: TJSONArray;
  const AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not Assigned(AArray) then Exit;
  for I := 0 to AArray.Count - 1 do
    if SameText(AArray.Items[I].AsString, AValue) then Exit(True);
end;

function IsPublisherTrusted(const APublishers,
  APackage: TJSONObject): Boolean;
var
  LEntries, LSigners, LRepositories: TJSONArray;
  LPublisher: TJSONObject;
  LPublisherId, LRepository, LFingerprint: string;
  I, J: Integer;
begin
  Result := False;
  if not (APublishers.Find('publishers') is TJSONArray) then Exit;
  LEntries := TJSONArray(APublishers.Find('publishers'));
  LPublisherId := APackage.Get('publisher', '');
  LRepository := APackage.Get('repository', '');
  LFingerprint := APackage.Get('signerFingerprint', '');
  for I := 0 to LEntries.Count - 1 do
    if LEntries.Items[I] is TJSONObject then
    begin
      LPublisher := TJSONObject(LEntries.Items[I]);
      if LPublisher.Get('id', '') <> LPublisherId then Continue;
      if not (LPublisher.Find('allowedSigners') is TJSONArray) or
         not (LPublisher.Find('repositories') is TJSONArray) then Exit;
      LSigners := TJSONArray(LPublisher.Find('allowedSigners'));
      LRepositories := TJSONArray(LPublisher.Find('repositories'));
      if not ArrayContains(LSigners, LFingerprint) then Exit;
      for J := 0 to LRepositories.Count - 1 do
        if Pos(LowerCase(LRepositories.Items[J].AsString),
          LowerCase(LRepository)) = 1 then Exit(True);
      Exit;
    end;
end;

procedure AuditDocument(const ADocument, APublishers: TJSONObject;
  const ALegacy: Boolean; const ANames: TStringList;
  var AResult: TBoss4DRegistryHealthResult);
var
  LPackages, LVersions: TJSONArray;
  LPackage: TJSONObject;
  LName: string;
  I: Integer;
begin
  if not (ADocument.Find('packages') is TJSONArray) then
  begin
    Inc(AResult.ErrorCount);
    Exit;
  end;
  LPackages := TJSONArray(ADocument.Find('packages'));
  for I := 0 to LPackages.Count - 1 do
  begin
    if not (LPackages.Items[I] is TJSONObject) then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    LPackage := TJSONObject(LPackages.Items[I]);
    LName := Trim(LPackage.Get('name', ''));
    if (LName = '') or (Trim(LPackage.Get('repository', '')) = '') then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    if ANames.IndexOf(LName) >= 0 then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    ANames.Add(LName);
    Inc(AResult.PackageCount);
    if ALegacy then
    begin
      Inc(AResult.LegacyPackageCount);
      Inc(AResult.WarningCount);
      if Trim(LPackage.Get('version', '')) = '' then
        Inc(AResult.WarningCount);
    end
    else
    begin
      if LPackage.Find('versions') is TJSONArray then
        LVersions := TJSONArray(LPackage.Find('versions'))
      else
        LVersions := nil;
      if not Assigned(LVersions) or (LVersions.Count = 0) then
        Inc(AResult.ErrorCount);
      if IsPublisherTrusted(APublishers, LPackage) then
        Inc(AResult.TrustedPackageCount)
      else
        Inc(AResult.ErrorCount);
    end;
  end;
end;

function ReferenceValue(const AValue: TJSONData): string;
begin
  if AValue is TJSONString then Exit(AValue.AsString);
  if AValue is TJSONObject then
    Exit(TJSONObject(AValue).Get('path', ''));
  Result := '';
end;

procedure AuditReferences(const ARoot, AIndexDirectory: string;
  const AReferences: TJSONArray; const ALegacy: Boolean;
  const APublishers: TJSONObject; const ANames,
  ASeenReferences: TStringList; var AResult: TBoss4DRegistryHealthResult);
var
  LReference, LPath: string;
  LDocument: TJSONObject;
  I: Integer;
begin
  if not Assigned(AReferences) then Exit;
  for I := 0 to AReferences.Count - 1 do
  begin
    LReference := ReferenceValue(AReferences.Items[I]);
    if (LReference = '') or
       (ASeenReferences.IndexOf(LReference) >= 0) then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    ASeenReferences.Add(LReference);
    LPath := ExpandFileName(IncludeTrailingPathDelimiter(
      AIndexDirectory) + LReference);
    if (Pos(IncludeTrailingPathDelimiter(ARoot), LPath) <> 1) or
       not FileExists(LPath) then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    LDocument := LoadObject(LPath);
    try
      AuditDocument(LDocument, APublishers, ALegacy, ANames, AResult);
    finally
      LDocument.Free;
    end;
  end;
end;

function AuditRegistryHealth(const ARoot: string):
  TBoss4DRegistryHealthResult;
var
  LRoot, LIndexPath: string;
  LIndex, LPublishers: TJSONObject;
  LIncludes, LSparse: TJSONArray;
  LNames, LReferences: TStringList;
begin
  Result := Default(TBoss4DRegistryHealthResult);
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot)) + 'registry';
  LIndexPath := IncludeTrailingPathDelimiter(LRoot) + 'index-v2.json';
  LIndex := LoadObject(LIndexPath);
  LPublishers := LoadObject(
    IncludeTrailingPathDelimiter(LRoot) + 'publishers.json');
  LNames := TStringList.Create;
  LReferences := TStringList.Create;
  try
    LNames.CaseSensitive := False;
    LNames.Sorted := True;
    LNames.Duplicates := dupIgnore;
    LReferences.CaseSensitive := False;
    LReferences.Sorted := True;
    LReferences.Duplicates := dupIgnore;
    if LIndex.Get('schemaVersion', 0) <> 2 then Inc(Result.ErrorCount);
    AuditDocument(LIndex, LPublishers, False, LNames, Result);
    if LIndex.Find('includes') is TJSONArray then
      LIncludes := TJSONArray(LIndex.Find('includes'))
    else
      LIncludes := nil;
    if LIndex.Find('sparse') is TJSONArray then
      LSparse := TJSONArray(LIndex.Find('sparse'))
    else
      LSparse := nil;
    AuditReferences(LRoot, ExtractFileDir(LIndexPath), LIncludes, True,
      LPublishers, LNames, LReferences, Result);
    AuditReferences(LRoot, ExtractFileDir(LIndexPath), LSparse, False,
      LPublishers, LNames, LReferences, Result);
    Result.Passed := Result.ErrorCount = 0;
    Result.Summary := Format(
      'packages=%d; legacy=%d; trusted=%d; warnings=%d; errors=%d',
      [Result.PackageCount, Result.LegacyPackageCount,
       Result.TrustedPackageCount, Result.WarningCount,
       Result.ErrorCount]);
  finally
    LReferences.Free;
    LNames.Free;
    LPublishers.Free;
    LIndex.Free;
  end;
end;

end.
