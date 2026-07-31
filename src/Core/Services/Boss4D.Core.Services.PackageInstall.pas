unit Boss4D.Core.Services.PackageInstall;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DPackageInstallRequest = record
    PackageName: string;
    Version: string;
    Platform: string;
    Compiler: string;
    ArtifactUrl: string;
    Sha256: string;
    SignatureUrl: string;
    ProvenanceUrl: string;
    TargetDirectory: string;
  end;

  TBoss4DPackageInstallResult = record
    Installed: Boolean;
    FileCount: Integer;
    Digest: string;
  end;

  TBoss4DPackageInstallService = class
  private
    FHttp: IBoss4DHttpClient;
    FSigner: IBoss4DPackageSigner;
    function VerifyProvenance(const APath, AExpectedDigest: string): Boolean;
  public
    constructor Create(const AHttp: IBoss4DHttpClient;
      const ASigner: IBoss4DPackageSigner = nil);
    function Execute(const ARequest: TBoss4DPackageInstallRequest):
      TBoss4DPackageInstallResult;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, System.Hash,
  System.NetEncoding, Boss4D.Core.Services.Conformance;

function FileSha256(const APath: string): string;
begin
  var LBytes := TFile.ReadAllBytes(APath);
  var LHasher := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  if Length(LBytes) > 0 then
    LHasher.Update(LBytes, Length(LBytes));
  Result := LHasher.HashAsString.ToLower;
end;

procedure DeleteIfExists(const ADirectory: string);
begin
  if TDirectory.Exists(ADirectory) then
    TDirectory.Delete(ADirectory, True);
end;

constructor TBoss4DPackageInstallService.Create(const AHttp: IBoss4DHttpClient;
  const ASigner: IBoss4DPackageSigner);
begin
  inherited Create;
  if not Assigned(AHttp) then
    raise EArgumentNilException.Create('AHttp');
  FHttp := AHttp;
  FSigner := ASigner;
end;

function TBoss4DPackageInstallService.VerifyProvenance(const APath,
  AExpectedDigest: string): Boolean;
begin
  Result := False;
  var LValue := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APath, TEncoding.UTF8));
  try
    if not (LValue is TJSONObject) then Exit;
    var LRoot := TJSONObject(LValue);
    if LRoot.GetValue<string>('_type', '') <>
       'https://in-toto.io/Statement/v1' then Exit;
    var LSubjects := LRoot.GetValue<TJSONArray>('subject');
    if not Assigned(LSubjects) then Exit;
    for var LSubjectValue in LSubjects do
      if LSubjectValue is TJSONObject then
      begin
        var LDigest := TJSONObject(LSubjectValue)
          .GetValue<TJSONObject>('digest');
        if Assigned(LDigest) and SameText(
          LDigest.GetValue<string>('sha256', ''), AExpectedDigest) then
          Exit(True);
      end;
  finally
    LValue.Free;
  end;
end;

function TBoss4DPackageInstallService.Execute(
  const ARequest: TBoss4DPackageInstallRequest):
  TBoss4DPackageInstallResult;
var
  LTempRoot, LArtifact, LSignature, LProvenance, LStage, LBackup: string;
  LRoot: TJSONObject;
begin
  Result := Default(TBoss4DPackageInstallResult);
  if ARequest.ArtifactUrl.Trim.IsEmpty or ARequest.Sha256.Trim.IsEmpty then
    raise EArgumentException.Create('Artifact URL and SHA-256 are required.');
  if ARequest.TargetDirectory.Trim.IsEmpty then
    raise EArgumentException.Create('Target directory is required.');

  LTempRoot := TPath.Combine(TPath.GetTempPath,
    'boss4d-package-' + TGUID.NewGuid.ToString);
  LArtifact := TPath.Combine(LTempRoot, 'package.b4dpkg');
  LSignature := LArtifact + '.asc';
  LProvenance := LArtifact + '.intoto.json';
  LStage := TPath.GetFullPath(ARequest.TargetDirectory) + '.boss4d-stage';
  LBackup := TPath.GetFullPath(ARequest.TargetDirectory) + '.boss4d-backup';
  TDirectory.CreateDirectory(LTempRoot);
  DeleteIfExists(LStage);
  DeleteIfExists(LBackup);
  try
    var LStatus := FHttp.DownloadToFile(ARequest.ArtifactUrl, LArtifact);
    if (LStatus < 200) or (LStatus >= 300) then
      raise Exception.CreateFmt('Artifact download failed with HTTP %d.',
        [LStatus]);
    Result.Digest := FileSha256(LArtifact);
    if not SameText(Result.Digest, ARequest.Sha256) then
      raise Exception.Create('Artifact SHA-256 mismatch.');

    var LConformance := TBoss4DConformanceService.Create;
    try
      var LValidation := LConformance.ValidatePackageFile(LArtifact);
      if not LValidation.Passed then
        raise Exception.Create('Invalid package: ' + LValidation.ErrorMessage);
      Result.FileCount := LValidation.PackageCount;
    finally
      LConformance.Free;
    end;

    if not ARequest.SignatureUrl.Trim.IsEmpty then
    begin
      if not Assigned(FSigner) then
        raise Exception.Create('Package signature was declared but no verifier is available.');
      LStatus := FHttp.DownloadToFile(ARequest.SignatureUrl, LSignature);
      if (LStatus < 200) or (LStatus >= 300) or
         not FSigner.Verify(LArtifact, LSignature) then
        raise Exception.Create('Package signature verification failed.');
    end;

    if not ARequest.ProvenanceUrl.Trim.IsEmpty then
    begin
      LStatus := FHttp.DownloadToFile(ARequest.ProvenanceUrl, LProvenance);
      if (LStatus < 200) or (LStatus >= 300) or
         not VerifyProvenance(LProvenance, Result.Digest) then
        raise Exception.Create('Package provenance verification failed.');
    end;

    TDirectory.CreateDirectory(LStage);
    LRoot := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(LArtifact, TEncoding.UTF8)) as TJSONObject;
    try
      var LFiles := LRoot.GetValue<TJSONArray>('files');
      for var LFileValue in LFiles do
      begin
        var LFile := TJSONObject(LFileValue);
        var LRelative := LFile.GetValue<string>('path', '');
        var LTarget := TPath.GetFullPath(TPath.Combine(LStage,
          LRelative.Replace('/', TPath.DirectorySeparatorChar)));
        if not LTarget.StartsWith(
          IncludeTrailingPathDelimiter(TPath.GetFullPath(LStage)), True) then
          raise Exception.Create('Package path escaped staging directory.');
        TDirectory.CreateDirectory(TPath.GetDirectoryName(LTarget));
        TFile.WriteAllBytes(LTarget, TNetEncoding.Base64.DecodeStringToBytes(
          LFile.GetValue<string>('content', '')));
      end;
    finally
      LRoot.Free;
    end;

    var LReceipt := TJSONObject.Create;
    try
      LReceipt.AddPair('schemaVersion', TJSONNumber.Create(1));
      LReceipt.AddPair('name', ARequest.PackageName);
      LReceipt.AddPair('version', ARequest.Version);
      LReceipt.AddPair('platform', ARequest.Platform);
      LReceipt.AddPair('compiler', ARequest.Compiler);
      LReceipt.AddPair('artifact', ARequest.ArtifactUrl);
      LReceipt.AddPair('sha256', Result.Digest);
      LReceipt.AddPair('signature', ARequest.SignatureUrl);
      LReceipt.AddPair('provenance', ARequest.ProvenanceUrl);
      LReceipt.AddPair('signatureVerified',
        TJSONBool.Create(not ARequest.SignatureUrl.Trim.IsEmpty));
      LReceipt.AddPair('provenanceVerified',
        TJSONBool.Create(not ARequest.ProvenanceUrl.Trim.IsEmpty));
      TFile.WriteAllText(TPath.Combine(LStage, '.boss4d-package.json'),
        LReceipt.Format(2), TEncoding.UTF8);
    finally
      LReceipt.Free;
    end;

    if TDirectory.Exists(ARequest.TargetDirectory) then
      TDirectory.Move(ARequest.TargetDirectory, LBackup);
    try
      TDirectory.Move(LStage, ARequest.TargetDirectory);
      DeleteIfExists(LBackup);
    except
      if TDirectory.Exists(LBackup) and
         not TDirectory.Exists(ARequest.TargetDirectory) then
        TDirectory.Move(LBackup, ARequest.TargetDirectory);
      raise;
    end;
    Result.Installed := True;
  finally
    DeleteIfExists(LStage);
    DeleteIfExists(LBackup);
    DeleteIfExists(LTempRoot);
  end;
end;

end.
