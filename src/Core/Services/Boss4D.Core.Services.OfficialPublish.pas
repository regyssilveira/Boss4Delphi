unit Boss4D.Core.Services.OfficialPublish;

interface

uses
  System.SysUtils, Boss4D.Core.Ports,
  Boss4D.Core.Services.RegistrySubmission;

type
  TBoss4DOfficialPublishOptions = record
    ProjectDirectory: string;
    PackageName: string;
    Publisher: string;
    Repository: string;
    SignerFingerprint: string;
    SigningKey: string;
    Version: string;
    ArtifactUrl: string;
    Description: string;
    License: string;
    ArtifactOutput: string;
    SubmissionOutput: string;
  end;

  TBoss4DOfficialPublishResult = record
    ArtifactPath: string;
    SignaturePath: string;
    ProvenancePath: string;
    SubmissionPath: string;
    Digest: string;
  end;

  TBoss4DOfficialPublishService = class
  private
    FSigner: IBoss4DPackageSigner;
    class procedure DeleteIfExists(const APath: string); static;
  public
    constructor Create(const ASigner: IBoss4DPackageSigner);
    function Prepare(const AOptions: TBoss4DOfficialPublishOptions):
      TBoss4DOfficialPublishResult;
  end;

implementation

uses
  System.IOUtils, System.Classes,
  Boss4D.Core.Services.Pack;

constructor TBoss4DOfficialPublishService.Create(
  const ASigner: IBoss4DPackageSigner);
begin
  inherited Create;
  if not Assigned(ASigner) then
    raise EArgumentNilException.Create('Signer');
  FSigner := ASigner;
end;

class procedure TBoss4DOfficialPublishService.DeleteIfExists(
  const APath: string);
begin
  if not APath.IsEmpty and TFile.Exists(APath) then
    TFile.Delete(APath);
end;

function TBoss4DOfficialPublishService.Prepare(
  const AOptions: TBoss4DOfficialPublishOptions):
  TBoss4DOfficialPublishResult;
var
  LPackService: TBoss4DPackService;
  LPack: TBoss4DPackResult;
  LSubmission: TBoss4DRegistrySubmission;
  LDocument: string;
  LEncoding: TEncoding;
begin
  Result := Default(TBoss4DOfficialPublishResult);
  if AOptions.ProjectDirectory.Trim.IsEmpty then
    raise EArgumentException.Create('Diretorio do projeto obrigatorio.');
  if AOptions.ArtifactOutput.Trim.IsEmpty then
    raise EArgumentException.Create('Saida do artefato obrigatoria.');
  if AOptions.SubmissionOutput.Trim.IsEmpty then
    raise EArgumentException.Create('Saida da submissao obrigatoria.');
  if AOptions.SigningKey.Trim.IsEmpty then
    raise EArgumentException.Create('Chave de assinatura obrigatoria.');

  Result.ArtifactPath := TPath.GetFullPath(AOptions.ArtifactOutput);
  Result.SubmissionPath := TPath.GetFullPath(AOptions.SubmissionOutput);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result.ArtifactPath));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result.SubmissionPath));
  LPackService := TBoss4DPackService.Create;
  try
    try
      LPack := LPackService.Execute(
        TPath.GetFullPath(AOptions.ProjectDirectory), Result.ArtifactPath);
      Result.ArtifactPath := LPack.OutputPath;
      Result.ProvenancePath := LPack.ProvenancePath;
      Result.Digest := LPack.Digest;
      Result.SignaturePath := FSigner.Sign(Result.ArtifactPath,
        AOptions.SigningKey);
      if Result.SignaturePath.IsEmpty or
         not TFile.Exists(Result.SignaturePath) or
         not FSigner.Verify(Result.ArtifactPath, Result.SignaturePath) then
        raise EBoss4DRegistrySubmission.Create(
          'Assinatura do pacote nao foi verificada.');

      LSubmission := Default(TBoss4DRegistrySubmission);
      LSubmission.PackageName := AOptions.PackageName;
      LSubmission.Publisher := AOptions.Publisher;
      LSubmission.Repository := AOptions.Repository;
      LSubmission.SignerFingerprint := AOptions.SignerFingerprint;
      LSubmission.Version := AOptions.Version;
      LSubmission.ArtifactUrl := AOptions.ArtifactUrl;
      LSubmission.Sha256 := Result.Digest;
      LSubmission.SignatureUrl := AOptions.ArtifactUrl + '.asc';
      LSubmission.ProvenanceUrl :=
        AOptions.ArtifactUrl + '.intoto.json';
      LSubmission.Description := AOptions.Description;
      LSubmission.License := AOptions.License;
      LDocument :=
        TBoss4DRegistrySubmissionService.BuildDocument(LSubmission);
      LEncoding := TUTF8Encoding.Create(False);
      try
        TFile.WriteAllText(Result.SubmissionPath, LDocument, LEncoding);
      finally
        LEncoding.Free;
      end;
    except
      DeleteIfExists(Result.SubmissionPath);
      DeleteIfExists(Result.SignaturePath);
      DeleteIfExists(Result.ProvenancePath);
      DeleteIfExists(Result.ArtifactPath);
      raise;
    end;
  finally
    LPackService.Free;
  end;
end;

end.
