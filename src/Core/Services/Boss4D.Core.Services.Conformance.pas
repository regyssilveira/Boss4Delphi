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
  LPackages: TJSONArray;
  LNames, LRepositories: TDictionary<string, Byte>;
begin
  Result := Default(TBoss4DConformanceResult);
  LRoot := TJSONObject.ParseJSONValue(AContent) as TJSONObject;
  if not Assigned(LRoot) then
  begin
    Result.ErrorMessage := 'Registry must be a JSON object.';
    Exit;
  end;
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
    begin
      Result.ErrorMessage := 'Unsupported registry schema.';
      Exit;
    end;
    LPackages := LRoot.GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
    begin
      Result.ErrorMessage := 'Registry packages array is required.';
      Exit;
    end;
    LNames := TDictionary<string, Byte>.Create;
    LRepositories := TDictionary<string, Byte>.Create;
    try
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
      end;
    finally
      LRepositories.Free;
      LNames.Free;
    end;
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
