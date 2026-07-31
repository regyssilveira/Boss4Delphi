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

function ApplyRegistrySubmission(const ARoot, ASubmissionPath: string;
  const AAppendVersion: Boolean): TBoss4DRegistryCheckoutResult;
var
  LRoot, LPublishersPath, LPackageDirectory,
    LSparsePath, LOriginalIndex, LOriginalPackage, LPublisherId,
    LRepository, LFingerprint: string;
  LSubmission, LPublishers, LIndex, LExisting,
    LPackage, LVersion, LPublisher, LExistingPackage: TJSONObject;
  LPackages, LVersions, LPublisherEntries, LSigners, LRepositories,
    LSparseArray, LExistingPackages, LExistingVersions: TJSONArray;
  LFoundPublisher, LSignerAllowed, LRepositoryAllowed,
    LPackageExisted, LSparsePresent: Boolean;
  LSortedSparse: TStringList;
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
    if LSubmission.Get('schemaVersion', 0) <> 2 then
      raise Exception.Create('submission must use schemaVersion 2');
    if not (LSubmission.Find('packages') is TJSONArray) then
      raise Exception.Create('submission packages array is required');
    LPackages := TJSONArray(LSubmission.Find('packages'));
    if (LPackages.Count <> 1) or
       not (LPackages.Items[0] is TJSONObject) then
      raise Exception.Create('submission must contain exactly one package');
    LPackage := TJSONObject(LPackages.Items[0]);
    if not (LPackage.Find('versions') is TJSONArray) then
      raise Exception.Create('submission versions array is required');
    LVersions := TJSONArray(LPackage.Find('versions'));
    if (LVersions.Count <> 1) or
       not (LVersions.Items[0] is TJSONObject) then
      raise Exception.Create('submission must contain exactly one version');
    LVersion := TJSONObject(LVersions.Items[0]);
    Result.PackageName := LPackage.Get('name', '');
    Result.Version := LVersion.Get('version', '');
    LPublisherId := LPackage.Get('publisher', '');
    LRepository := LPackage.Get('repository', '');
    LFingerprint := UpperCase(LPackage.Get('signerFingerprint', ''));
    Result.PackagePath := IncludeTrailingPathDelimiter(LPackageDirectory) +
      RegistryPackageSlug(Result.PackageName) + '.json';
    LSparsePath := 'packages/' + ExtractFileName(Result.PackagePath);

    LFoundPublisher := False;
    LSignerAllowed := False;
    LRepositoryAllowed := False;
    if LPublishers.Find('publishers') is TJSONArray then
    begin
      LPublisherEntries := TJSONArray(LPublishers.Find('publishers'));
      for I := 0 to LPublisherEntries.Count - 1 do
        if LPublisherEntries.Items[I] is TJSONObject then
        begin
          LPublisher := TJSONObject(LPublisherEntries.Items[I]);
          if LPublisher.Get('id', '') <> LPublisherId then Continue;
          LFoundPublisher := True;
          if LPublisher.Find('allowedSigners') is TJSONArray then
          begin
            LSigners := TJSONArray(LPublisher.Find('allowedSigners'));
            LSignerAllowed := ArrayHasValue(LSigners, LFingerprint);
          end;
          if LPublisher.Find('repositories') is TJSONArray then
          begin
            LRepositories := TJSONArray(LPublisher.Find('repositories'));
            LRepositoryAllowed :=
              RepositoryAllowed(LRepositories, LRepository);
          end;
          Break;
        end;
    end;
    if not LFoundPublisher then
      raise Exception.Create('publisher is not registered: ' + LPublisherId);
    if not LSignerAllowed then
      raise Exception.Create('fingerprint is not authorized for publisher');
    if not LRepositoryAllowed then
      raise Exception.Create('repository is outside publisher scope');

    LSparsePresent := False;
    if LIndex.Find('sparse') is TJSONArray then
    begin
      LSparseArray := TJSONArray(LIndex.Find('sparse'));
      for I := 0 to LSparseArray.Count - 1 do
        if SameText(SparseValue(LSparseArray.Items[I]), LSparsePath) then
          LSparsePresent := True;
    end;
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
