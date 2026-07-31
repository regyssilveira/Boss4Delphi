unit Boss4D.Posix.RegistryCheckout;

{$mode objfpc}{$H+}

interface

type
  TBoss4DRegistryCheckoutResult = record
    PackagePath: string;
    IndexPath: string;
    PackageName: string;
    Version: string;
    Appended: Boolean;
  end;

function ApplyRegistrySubmission(const ARoot, ASubmissionPath: string;
  const AAppendVersion: Boolean): TBoss4DRegistryCheckoutResult;
function RegistryPackageSlug(const AName: string): string;

implementation

uses
  Classes, SysUtils, fpjson, jsonparser;

function LoadObject(const APath: string): TJSONObject;
var
  LStream: TFileStream;
  LData: TJSONData;
begin
  if not FileExists(APath) then
    raise Exception.Create('required Registry file not found: ' + APath);
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create('Registry document must be an object: ' + APath);
  end;
  Result := TJSONObject(LData);
end;

procedure SaveObject(const APath: string; const AObject: TJSONObject);
var
  LOutput: TStringList;
begin
  LOutput := TStringList.Create;
  try
    LOutput.Text := AObject.AsJSON;
    LOutput.SaveToFile(APath);
  finally
    LOutput.Free;
  end;
end;

function RegistryPackageSlug(const AName: string): string;
var
  I: Integer;
  LDash: Boolean;
begin
  Result := '';
  LDash := False;
  for I := 1 to Length(AName) do
    if AName[I] in ['a'..'z', 'A'..'Z', '0'..'9'] then
    begin
      Result := Result + LowerCase(AName[I]);
      LDash := False;
    end
    else if (Result <> '') and not LDash then
    begin
      Result := Result + '-';
      LDash := True;
    end;
  while (Length(Result) > 0) and (Result[Length(Result)] = '-') do
    Delete(Result, Length(Result), 1);
  if Result = '' then
    raise Exception.Create('package name must contain letters or digits');
end;

function ArrayHasValue(const AArray: TJSONArray;
  const AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not Assigned(AArray) then Exit;
  for I := 0 to AArray.Count - 1 do
    if SameText(AArray.Items[I].AsString, AValue) then Exit(True);
end;

function RepositoryAllowed(const AArray: TJSONArray;
  const ARepository: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not Assigned(AArray) then Exit;
  for I := 0 to AArray.Count - 1 do
    if Pos(LowerCase(AArray.Items[I].AsString),
      LowerCase(ARepository)) = 1 then Exit(True);
end;

function SparseValue(const AValue: TJSONData): string;
begin
  if AValue is TJSONString then Exit(AValue.AsString);
  if AValue is TJSONObject then
    Exit(TJSONObject(AValue).Get('path', ''));
  Result := '';
end;

procedure ValidatePublisher(const APublishers: TJSONObject;
  const APublisherId, ARepository, AFingerprint: string);
var
  LEntries, LSigners, LRepositories: TJSONArray;
  LPublisher: TJSONObject;
  LFound, LSignerAllowed, LRepositoryAllowed: Boolean;
  I: Integer;
begin
  LFound := False;
  LSignerAllowed := False;
  LRepositoryAllowed := False;
  if APublishers.Find('publishers') is TJSONArray then
  begin
    LEntries := TJSONArray(APublishers.Find('publishers'));
    for I := 0 to LEntries.Count - 1 do
      if LEntries.Items[I] is TJSONObject then
      begin
        LPublisher := TJSONObject(LEntries.Items[I]);
        if LPublisher.Get('id', '') <> APublisherId then Continue;
        LFound := True;
        if LPublisher.Find('allowedSigners') is TJSONArray then
        begin
          LSigners := TJSONArray(LPublisher.Find('allowedSigners'));
          LSignerAllowed := ArrayHasValue(LSigners, AFingerprint);
        end;
        if LPublisher.Find('repositories') is TJSONArray then
        begin
          LRepositories := TJSONArray(LPublisher.Find('repositories'));
          LRepositoryAllowed := RepositoryAllowed(
            LRepositories, ARepository);
        end;
        Break;
      end;
  end;
  if not LFound then
    raise Exception.Create('publisher is not registered: ' + APublisherId);
  if not LSignerAllowed then
    raise Exception.Create('fingerprint is not authorized for publisher');
  if not LRepositoryAllowed then
    raise Exception.Create('repository is outside publisher scope');
end;

function SparseContains(const AIndex: TJSONObject;
  const APath: string): Boolean;
var
  LArray: TJSONArray;
  I: Integer;
begin
  Result := False;
  if not (AIndex.Find('sparse') is TJSONArray) then Exit;
  LArray := TJSONArray(AIndex.Find('sparse'));
  for I := 0 to LArray.Count - 1 do
    if SameText(SparseValue(LArray.Items[I]), APath) then Exit(True);
end;

type
  TSubmissionIdentity = record
    PackageObject: TJSONObject;
    VersionObject: TJSONObject;
    PackageName: string;
    VersionName: string;
    PublisherId: string;
    Repository: string;
    Fingerprint: string;
  end;

function ReadSubmission(const ASubmission: TJSONObject):
  TSubmissionIdentity;
var
  LPackages, LVersions: TJSONArray;
begin
  Result := Default(TSubmissionIdentity);
  if ASubmission.Get('schemaVersion', 0) <> 2 then
    raise Exception.Create('submission must use schemaVersion 2');
  if not (ASubmission.Find('packages') is TJSONArray) then
    raise Exception.Create('submission packages array is required');
  LPackages := TJSONArray(ASubmission.Find('packages'));
  if (LPackages.Count <> 1) or
     not (LPackages.Items[0] is TJSONObject) then
    raise Exception.Create('submission must contain exactly one package');
  Result.PackageObject := TJSONObject(LPackages.Items[0]);
  if not (Result.PackageObject.Find('versions') is TJSONArray) then
    raise Exception.Create('submission versions array is required');
  LVersions := TJSONArray(Result.PackageObject.Find('versions'));
  if (LVersions.Count <> 1) or
     not (LVersions.Items[0] is TJSONObject) then
    raise Exception.Create('submission must contain exactly one version');
  Result.VersionObject := TJSONObject(LVersions.Items[0]);
  Result.PackageName := Result.PackageObject.Get('name', '');
  Result.VersionName := Result.VersionObject.Get('version', '');
  Result.PublisherId := Result.PackageObject.Get('publisher', '');
  Result.Repository := Result.PackageObject.Get('repository', '');
  Result.Fingerprint := UpperCase(
    Result.PackageObject.Get('signerFingerprint', ''));
end;

function ApplyRegistrySubmission(const ARoot, ASubmissionPath: string;
  const AAppendVersion: Boolean): TBoss4DRegistryCheckoutResult;
var
  LRoot, LPublishersPath, LPackageDirectory,
    LSparsePath, LOriginalIndex, LOriginalPackage, LPublisherId,
    LRepository, LFingerprint: string;
  LSubmission, LPublishers, LIndex, LExisting,
    LVersion, LExistingPackage: TJSONObject;
  LSparseArray, LExistingPackages,
    LExistingVersions: TJSONArray;
  LPackageExisted, LSparsePresent: Boolean;
  LSortedSparse: TStringList;
  LIdentity: TSubmissionIdentity;
  I: Integer;
begin
  Result.PackagePath := '';
  Result.IndexPath := '';
  Result.PackageName := '';
  Result.Version := '';
  Result.Appended := AAppendVersion;
  LRoot := ExpandFileName(ARoot);
  LPublishersPath := IncludeTrailingPathDelimiter(LRoot) +
    'registry/publishers.json';
  Result.IndexPath := IncludeTrailingPathDelimiter(LRoot) +
    'registry/index-v2.json';
  LPackageDirectory := IncludeTrailingPathDelimiter(LRoot) +
    'registry/packages';
  LSubmission := LoadObject(ExpandFileName(ASubmissionPath));
  LPublishers := LoadObject(LPublishersPath);
  LIndex := LoadObject(Result.IndexPath);
  LExisting := nil;
  try
    LIdentity := ReadSubmission(LSubmission);
    LVersion := LIdentity.VersionObject;
    Result.PackageName := LIdentity.PackageName;
    Result.Version := LIdentity.VersionName;
    LPublisherId := LIdentity.PublisherId;
    LRepository := LIdentity.Repository;
    LFingerprint := LIdentity.Fingerprint;
    Result.PackagePath := IncludeTrailingPathDelimiter(LPackageDirectory) +
      RegistryPackageSlug(Result.PackageName) + '.json';
    LSparsePath := 'packages/' + ExtractFileName(Result.PackagePath);

    ValidatePublisher(LPublishers, LPublisherId, LRepository, LFingerprint);
    LSparsePresent := SparseContains(LIndex, LSparsePath);
    LPackageExisted := FileExists(Result.PackagePath);
    if LPackageExisted and not AAppendVersion then
      raise Exception.Create('package metadata already exists; use append');
    if not LPackageExisted and AAppendVersion then
      raise Exception.Create('cannot append to a missing package');
    if not AAppendVersion and LSparsePresent then
      raise Exception.Create('sparse entry already exists');
    if AAppendVersion and not LSparsePresent then
      raise Exception.Create('existing package is missing from sparse index');

    LOriginalIndex := LIndex.AsJSON;
    if LPackageExisted then
      with TStringList.Create do
      try
        LoadFromFile(Result.PackagePath);
        LOriginalPackage := Text;
      finally
        Free;
      end
    else
      LOriginalPackage := '';
    try
      if AAppendVersion then
      begin
        LExisting := LoadObject(Result.PackagePath);
        if not (LExisting.Find('packages') is TJSONArray) then
          raise Exception.Create('existing package identities are missing');
        LExistingPackages := TJSONArray(LExisting.Find('packages'));
        if (LExistingPackages.Count <> 1) or
           not (LExistingPackages.Items[0] is TJSONObject) then
          raise Exception.Create('existing package must contain one identity');
        LExistingPackage := TJSONObject(LExistingPackages.Items[0]);
        if (LExistingPackage.Get('name', '') <> Result.PackageName) or
           (LExistingPackage.Get('publisher', '') <> LPublisherId) or
           (LExistingPackage.Get('repository', '') <> LRepository) or
           not SameText(LExistingPackage.Get('signerFingerprint', ''),
             LFingerprint) then
          raise Exception.Create(
            'append cannot change identity, repository, or signer');
        if not (LExistingPackage.Find('versions') is TJSONArray) then
          raise Exception.Create('existing package versions are missing');
        LExistingVersions :=
          TJSONArray(LExistingPackage.Find('versions'));
        for I := 0 to LExistingVersions.Count - 1 do
          if (LExistingVersions.Items[I] is TJSONObject) and
             (TJSONObject(LExistingVersions.Items[I]).Get('version', '') =
                Result.Version) then
            raise Exception.Create(
              'version already exists and is immutable: ' + Result.Version);
        LExistingVersions.Add(LVersion.Clone);
        SaveObject(Result.PackagePath, LExisting);
      end
      else
      begin
        ForceDirectories(LPackageDirectory);
        SaveObject(Result.PackagePath, LSubmission);
        LSortedSparse := TStringList.Create;
        try
          LSortedSparse.Sorted := True;
          LSortedSparse.Duplicates := dupIgnore;
          if LIndex.Find('sparse') is TJSONArray then
          begin
            LSparseArray := TJSONArray(LIndex.Find('sparse'));
            for I := 0 to LSparseArray.Count - 1 do
              if SparseValue(LSparseArray.Items[I]) <> '' then
                LSortedSparse.Add(SparseValue(LSparseArray.Items[I]));
          end;
          LSortedSparse.Add(LSparsePath);
          LIndex.Delete('sparse');
          LSparseArray := TJSONArray.Create;
          for I := 0 to LSortedSparse.Count - 1 do
            LSparseArray.Add(LSortedSparse[I]);
          LIndex.Add('sparse', LSparseArray);
        finally
          LSortedSparse.Free;
        end;
        SaveObject(Result.IndexPath, LIndex);
      end;
    except
      with TStringList.Create do
      try
        if LPackageExisted then
        begin
          Text := LOriginalPackage;
          SaveToFile(Result.PackagePath);
        end
        else if FileExists(Result.PackagePath) then
          DeleteFile(Result.PackagePath);
        Text := LOriginalIndex;
        SaveToFile(Result.IndexPath);
      finally
        Free;
      end;
      raise;
    end;
  finally
    LExisting.Free;
    LIndex.Free;
    LPublishers.Free;
    LSubmission.Free;
  end;
end;

end.
