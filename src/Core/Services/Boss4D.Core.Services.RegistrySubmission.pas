unit Boss4D.Core.Services.RegistrySubmission;

interface

uses
  System.SysUtils;

type
  TBoss4DRegistrySubmission = record
    PackageName: string;
    Publisher: string;
    Repository: string;
    SignerFingerprint: string;
    Version: string;
    ArtifactUrl: string;
    Sha256: string;
    SignatureUrl: string;
    ProvenanceUrl: string;
    Description: string;
    License: string;
  end;

  EBoss4DRegistrySubmission = class(Exception);

  TBoss4DRegistrySubmissionService = class
  private
    class procedure Validate(const ASubmission: TBoss4DRegistrySubmission);
      static;
  public
    class function PackageSlug(const AName: string): string; static;
    class function BuildDocument(
      const ASubmission: TBoss4DRegistrySubmission): string; static;
  end;

implementation

uses
  System.JSON, System.RegularExpressions,
  Boss4D.Core.Domain.SemVer;

class function TBoss4DRegistrySubmissionService.PackageSlug(
  const AName: string): string;
begin
  Result := TRegEx.Replace(AName.Trim.ToLower, '[^a-z0-9]+', '-');
  Result := Result.Trim(['-']);
  if Result.IsEmpty then
    raise EBoss4DRegistrySubmission.Create(
      'Nome do pacote precisa conter letras ou numeros.');
end;

class procedure TBoss4DRegistrySubmissionService.Validate(
  const ASubmission: TBoss4DRegistrySubmission);

  procedure RequireHttps(const AName, AValue: string);
  begin
    if not AValue.StartsWith('https://', True) or
       AValue.Contains(' ') then
      raise EBoss4DRegistrySubmission.Create(
        AName + ' precisa ser uma URL HTTPS absoluta.');
  end;

begin
  PackageSlug(ASubmission.PackageName);
  if not TRegEx.IsMatch(ASubmission.Publisher,
    '^[a-z0-9]+(?:-[a-z0-9]+)*$') then
    raise EBoss4DRegistrySubmission.Create(
      'Publisher precisa ser um ID minusculo normalizado.');
  if not TRegEx.IsMatch(ASubmission.Repository,
    '^[A-Za-z0-9.-]+/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') then
    raise EBoss4DRegistrySubmission.Create(
      'Repositorio precisa usar host/owner/name.');
  if not TRegEx.IsMatch(ASubmission.SignerFingerprint,
    '^[0-9a-fA-F]{40}$') then
    raise EBoss4DRegistrySubmission.Create(
      'Fingerprint precisa conter 40 caracteres hexadecimais.');
  if not TBoss4DSemVer.Create(ASubmission.Version).IsValid then
    raise EBoss4DRegistrySubmission.Create(
      'Versao precisa ser SemVer valida.');
  if not TRegEx.IsMatch(ASubmission.Sha256, '^[0-9a-fA-F]{64}$') then
    raise EBoss4DRegistrySubmission.Create(
      'SHA-256 precisa conter 64 caracteres hexadecimais.');
  RequireHttps('Artefato', ASubmission.ArtifactUrl);
  RequireHttps('Assinatura', ASubmission.SignatureUrl);
  RequireHttps('Proveniencia', ASubmission.ProvenanceUrl);
end;

class function TBoss4DRegistrySubmissionService.BuildDocument(
  const ASubmission: TBoss4DRegistrySubmission): string;
var
  LRoot, LPackage, LVersion: TJSONObject;
  LPackages, LVersions: TJSONArray;
begin
  Validate(ASubmission);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(2));
    LPackages := TJSONArray.Create;
    LRoot.AddPair('packages', LPackages);
    LPackage := TJSONObject.Create;
    LPackages.AddElement(LPackage);
    LPackage.AddPair('name', ASubmission.PackageName);
    LPackage.AddPair('publisher', ASubmission.Publisher);
    LPackage.AddPair('repository', ASubmission.Repository);
    LPackage.AddPair('signerFingerprint',
      ASubmission.SignerFingerprint.ToUpper);
    LPackage.AddPair('description', ASubmission.Description);
    LPackage.AddPair('license', ASubmission.License);
    LVersions := TJSONArray.Create;
    LPackage.AddPair('versions', LVersions);
    LVersion := TJSONObject.Create;
    LVersions.AddElement(LVersion);
    LVersion.AddPair('version', ASubmission.Version);
    LVersion.AddPair('artifact', ASubmission.ArtifactUrl);
    LVersion.AddPair('sha256', ASubmission.Sha256.ToLower);
    LVersion.AddPair('signature', ASubmission.SignatureUrl);
    LVersion.AddPair('provenance', ASubmission.ProvenanceUrl);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

end.
