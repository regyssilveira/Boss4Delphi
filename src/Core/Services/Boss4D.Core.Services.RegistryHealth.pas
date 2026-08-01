unit Boss4D.Core.Services.RegistryHealth;

interface

uses
  System.SysUtils;

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

  TBoss4DRegistryHealthService = class
  public
    function Audit(const ARoot: string): TBoss4DRegistryHealthResult;
  end;

implementation

uses
  System.IOUtils, System.JSON, System.Generics.Collections,
  Boss4D.Core.Services.RegistrySubmission;

function LoadObject(const APath: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  if not TFile.Exists(APath) then
    raise EFileNotFoundException.Create('Registry file not found: ' + APath);
  LValue := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APath, TEncoding.UTF8));
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EConvertError.Create('Registry file must be an object: ' + APath);
  end;
  Result := TJSONObject(LValue);
end;

function IsPublisherTrusted(const APublishers, APackage: TJSONObject):
  Boolean;
var
  LPublisherId, LRepository, LFingerprint: string;
  LPublishers, LSigners, LRepositories: TJSONArray;
begin
  Result := False;
  LPublisherId := APackage.GetValue<string>('publisher', '');
  LRepository := APackage.GetValue<string>('distributionRepository',
    APackage.GetValue<string>('publisherRepository',
      APackage.GetValue<string>('repository', '')));
  LFingerprint := APackage.GetValue<string>('signerFingerprint', '');
  LPublishers := APublishers.GetValue<TJSONArray>('publishers');
  if not Assigned(LPublishers) then Exit;
  for var LValue in LPublishers do
  begin
    if not (LValue is TJSONObject) or
       (TJSONObject(LValue).GetValue<string>('id', '') <> LPublisherId) then
      Continue;
    LSigners := TJSONObject(LValue).GetValue<TJSONArray>('allowedSigners');
    LRepositories := TJSONObject(LValue).GetValue<TJSONArray>('repositories');
    if Assigned(LSigners) then
      for var LSigner in LSigners do
        if SameText(LSigner.Value, LFingerprint) and
           Assigned(LRepositories) then
          for var LPrefix in LRepositories do
            if LRepository.StartsWith(LPrefix.Value, True) then
              Exit(True);
    Exit;
  end;
end;

procedure AuditDocument(const ADocument, APublishers: TJSONObject;
  const ALegacy: Boolean; const ANames: TDictionary<string, Boolean>;
  var AResult: TBoss4DRegistryHealthResult);
var
  LPackages, LVersions: TJSONArray;
  LPackage: TJSONObject;
  LName, LKey: string;
begin
  LPackages := ADocument.GetValue<TJSONArray>('packages');
  if not Assigned(LPackages) then
  begin
    Inc(AResult.ErrorCount);
    Exit;
  end;
  for var LValue in LPackages do
  begin
    if not (LValue is TJSONObject) then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    LPackage := TJSONObject(LValue);
    LName := LPackage.GetValue<string>('name', '').Trim;
    if LName.IsEmpty or
       LPackage.GetValue<string>('repository', '').Trim.IsEmpty then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    LKey := TBoss4DRegistrySubmissionService.PackageSlug(LName);
    if ANames.ContainsKey(LKey) then
    begin
      Inc(AResult.ErrorCount);
      Continue;
    end;
    ANames.Add(LKey, True);
    Inc(AResult.PackageCount);
    if ALegacy then
    begin
      Inc(AResult.LegacyPackageCount);
      Inc(AResult.WarningCount);
      if LPackage.GetValue<string>('version', '').Trim.IsEmpty then
        Inc(AResult.WarningCount);
    end
    else
    begin
      LVersions := LPackage.GetValue<TJSONArray>('versions');
      if not Assigned(LVersions) or (LVersions.Count = 0) then
        Inc(AResult.ErrorCount);
      if IsPublisherTrusted(APublishers, LPackage) then
        Inc(AResult.TrustedPackageCount)
      else
        Inc(AResult.ErrorCount);
    end;
  end;
end;

function TBoss4DRegistryHealthService.Audit(
  const ARoot: string): TBoss4DRegistryHealthResult;
var
  LRoot, LIndexPath: string;
  LIndex, LPublishers, LDocument: TJSONObject;
  LNames, LReferences: TDictionary<string, Boolean>;
  LIncludes, LSparse: TJSONArray;
  LReference, LPath: string;
begin
  Result := Default(TBoss4DRegistryHealthResult);
  LRoot := TPath.GetFullPath(ARoot);
  LIndexPath := TPath.Combine(LRoot, 'registry\index-v2.json');
  LIndex := LoadObject(LIndexPath);
  LPublishers := LoadObject(TPath.Combine(
    LRoot, 'registry\publishers.json'));
  LNames := TDictionary<string, Boolean>.Create;
  LReferences := TDictionary<string, Boolean>.Create;
  try
    if LIndex.GetValue<Integer>('schemaVersion', 0) <> 2 then
      Inc(Result.ErrorCount);
    AuditDocument(LIndex, LPublishers, False, LNames, Result);
    LIncludes := LIndex.GetValue<TJSONArray>('includes');
    if Assigned(LIncludes) then
      for var LInclude in LIncludes do
      begin
        LReference := LInclude.Value.Replace('/', '\');
        if LReferences.ContainsKey(LReference.ToLower) then
        begin
          Inc(Result.ErrorCount);
          Continue;
        end;
        LReferences.Add(LReference.ToLower, True);
        LPath := TPath.GetFullPath(TPath.Combine(
          TPath.GetDirectoryName(LIndexPath), LReference));
        if not LPath.StartsWith(
          IncludeTrailingPathDelimiter(TPath.Combine(LRoot, 'registry')),
          True) or not TFile.Exists(LPath) then
        begin
          Inc(Result.ErrorCount);
          Continue;
        end;
        LDocument := LoadObject(LPath);
        try
          AuditDocument(LDocument, LPublishers, True, LNames, Result);
        finally
          LDocument.Free;
        end;
      end;
    LSparse := LIndex.GetValue<TJSONArray>('sparse');
    if Assigned(LSparse) then
      for var LSparseValue in LSparse do
      begin
        LReference := LSparseValue.Value.Replace('/', '\');
        if LReferences.ContainsKey(LReference.ToLower) then
        begin
          Inc(Result.ErrorCount);
          Continue;
        end;
        LReferences.Add(LReference.ToLower, True);
        LPath := TPath.GetFullPath(TPath.Combine(
          TPath.GetDirectoryName(LIndexPath), LReference));
        if not LPath.StartsWith(
          IncludeTrailingPathDelimiter(TPath.Combine(LRoot, 'registry')),
          True) or not TFile.Exists(LPath) then
        begin
          Inc(Result.ErrorCount);
          Continue;
        end;
        LDocument := LoadObject(LPath);
        try
          AuditDocument(LDocument, LPublishers, False, LNames, Result);
        finally
          LDocument.Free;
        end;
      end;
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
