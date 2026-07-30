unit Boss4D.Core.Services.Conformance;

interface

type
  TBoss4DConformanceResult = record
    Passed: Boolean;
    PackageCount: Integer;
    ErrorMessage: string;
  end;

  TBoss4DConformanceService = class
  public
    function ValidateRegistryContent(
      const AContent: string): TBoss4DConformanceResult;
    function ValidatePackageFile(
      const APackagePath: string): TBoss4DConformanceResult;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.IOUtils, System.Hash,
  System.NetEncoding, System.Generics.Collections;

function Sha256(const ABytes: TBytes): string;
var
  LHasher: THashSHA2;
begin
  LHasher := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  if Length(ABytes) > 0 then
    LHasher.Update(ABytes, Length(ABytes));
  Result := LHasher.HashAsString.ToLower;
end;

function TBoss4DConformanceService.ValidateRegistryContent(
  const AContent: string): TBoss4DConformanceResult;
var
  LRoot: TJSONObject;
  LPackages, LIncludes, LVersions: TJSONArray;
  LNames, LRepositories: TDictionary<string, Byte>;
  LSchemaVersion: Integer;
begin
  Result := Default(TBoss4DConformanceResult);
  LRoot := TJSONObject.ParseJSONValue(AContent) as TJSONObject;
  if not Assigned(LRoot) then
  begin
    Result.ErrorMessage := 'Registry must be a JSON object.';
    Exit;
  end;
  try
    LSchemaVersion := LRoot.GetValue<Integer>('schemaVersion', 0);
    if not (LSchemaVersion in [1, 2]) then
    begin
      Result.ErrorMessage := 'Unsupported registry schema.';
      Exit;
    end;
    LPackages := nil;
    if LRoot.GetValue('packages') is TJSONArray then
      LPackages := TJSONArray(LRoot.GetValue('packages'));
    LIncludes := nil;
    if LRoot.GetValue('includes') is TJSONArray then
      LIncludes := TJSONArray(LRoot.GetValue('includes'));
    if not Assigned(LPackages) and
       ((LSchemaVersion = 1) or not Assigned(LIncludes)) then
    begin
      Result.ErrorMessage := 'Registry packages array is required.';
      Exit;
    end;
    if Assigned(LIncludes) then
      for var LInclude in LIncludes do
        if not (LInclude is TJSONString) or LInclude.Value.Trim.IsEmpty or
           LInclude.Value.Replace('\', '/').Contains('../') then
        begin
          Result.ErrorMessage := 'Registry includes must use safe references.';
          Exit;
        end;
    LNames := TDictionary<string, Byte>.Create;
    LRepositories := TDictionary<string, Byte>.Create;
    try
      if Assigned(LPackages) then
      for var LValue in LPackages do
      begin
        if not (LValue is TJSONObject) or
           TJSONObject(LValue).GetValue<string>('name', '').Trim.IsEmpty or
           TJSONObject(LValue).GetValue<string>('repository', '').Trim.IsEmpty then
        begin
          Result.ErrorMessage := 'Every package needs name and repository.';
          Exit;
        end;
        var LName := TJSONObject(LValue).GetValue<string>('name', '')
          .Trim.ToLower;
        var LRepository := TJSONObject(LValue).GetValue<string>(
          'repository', '').Trim.ToLower;
        if LNames.ContainsKey(LName) then
        begin
          Result.ErrorMessage := 'Package names must be unique.';
          Exit;
        end;
        if LRepositories.ContainsKey(LRepository) then
        begin
          Result.ErrorMessage := 'Package repositories must be unique.';
          Exit;
        end;
        LNames.Add(LName, 0);
        LRepositories.Add(LRepository, 0);
        var LArtifact := TJSONObject(LValue).GetValue<string>('artifact', '');
        var LDigest := TJSONObject(LValue).GetValue<string>('sha256', '');
        if LArtifact.IsEmpty <> LDigest.IsEmpty then
        begin
          Result.ErrorMessage := 'Artifact and sha256 must be declared together.';
          Exit;
        end;
        LVersions := nil;
        if TJSONObject(LValue).GetValue('versions') is TJSONArray then
          LVersions := TJSONArray(TJSONObject(LValue).GetValue('versions'));
        if Assigned(LVersions) then
          for var LVersionValue in LVersions do
          begin
            if not (LVersionValue is TJSONObject) or
               TJSONObject(LVersionValue).GetValue<string>('version', '')
                 .Trim.IsEmpty then
            begin
              Result.ErrorMessage := 'Every release needs a version.';
              Exit;
            end;
            LArtifact := TJSONObject(LVersionValue).GetValue<string>(
              'artifact', '');
            LDigest := TJSONObject(LVersionValue).GetValue<string>(
              'sha256', '');
            if LArtifact.IsEmpty <> LDigest.IsEmpty then
            begin
              Result.ErrorMessage :=
                'Release artifact and sha256 must be declared together.';
              Exit;
            end;
            var LVariants: TJSONArray := nil;
            if TJSONObject(LVersionValue).GetValue('variants') is TJSONArray then
              LVariants := TJSONArray(
                TJSONObject(LVersionValue).GetValue('variants'));
            if Assigned(LVariants) then
              for var LVariantValue in LVariants do
              begin
                if not (LVariantValue is TJSONObject) then
                begin
                  Result.ErrorMessage := 'Every variant must be an object.';
                  Exit;
                end;
                LArtifact := TJSONObject(LVariantValue).GetValue<string>(
                  'artifact', '');
                LDigest := TJSONObject(LVariantValue).GetValue<string>(
                  'sha256', '');
                if LArtifact.IsEmpty or LDigest.IsEmpty then
                begin
                  Result.ErrorMessage :=
                    'Every variant needs artifact and sha256.';
                  Exit;
                end;
              end;
          end;
      end;
    finally
      LRepositories.Free;
      LNames.Free;
    end;
    if Assigned(LPackages) then
      Result.PackageCount := LPackages.Count;
    Result.Passed := True;
  finally
    LRoot.Free;
  end;
end;

function TBoss4DConformanceService.ValidatePackageFile(
  const APackagePath: string): TBoss4DConformanceResult;
var
  LRoot: TJSONObject;
  LFiles: TJSONArray;
  LBytes: TBytes;
begin
  Result := Default(TBoss4DConformanceResult);
  LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APackagePath, TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LRoot) then
  begin
    Result.ErrorMessage := 'Package must be a JSON object.';
    Exit;
  end;
  try
    if (LRoot.GetValue<string>('format', '') <> 'boss4d-package') or
       (LRoot.GetValue<Integer>('schemaVersion', 0) <> 1) then
    begin
      Result.ErrorMessage := 'Unsupported package format.';
      Exit;
    end;
    LFiles := LRoot.GetValue<TJSONArray>('files');
    if not Assigned(LFiles) then
    begin
      Result.ErrorMessage := 'Package files array is required.';
      Exit;
    end;
    for var LValue in LFiles do
    begin
      var LFile := TJSONObject(LValue);
      var LPath := LFile.GetValue<string>('path', '');
      if LPath.IsEmpty or LPath.StartsWith('/') or LPath.Contains('../') then
      begin
        Result.ErrorMessage := 'Unsafe package path.';
        Exit;
      end;
      LBytes := TNetEncoding.Base64.DecodeStringToBytes(
        LFile.GetValue<string>('content', ''));
      if not SameText(Sha256(LBytes),
        LFile.GetValue<string>('sha256', '')) then
      begin
        Result.ErrorMessage := 'Package file digest mismatch.';
        Exit;
      end;
    end;
    Result.PackageCount := LFiles.Count;
    Result.Passed := True;
  finally
    LRoot.Free;
  end;
end;

end.
