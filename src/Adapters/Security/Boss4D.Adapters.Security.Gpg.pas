unit Boss4D.Adapters.Security.Gpg;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DGpgPackageSigner = class(TInterfacedObject, IBoss4DPackageSigner)
  private
    FRunner: IBoss4DProcessRunner;
  public
    constructor Create(const ARunner: IBoss4DProcessRunner);
    function Sign(const AArtifactPath, AKeyId: string): string;
    function Verify(const AArtifactPath, ASignaturePath: string): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

constructor TBoss4DGpgPackageSigner.Create(
  const ARunner: IBoss4DProcessRunner);
begin
  inherited Create;
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  FRunner := ARunner;
end;

function TBoss4DGpgPackageSigner.Sign(const AArtifactPath,
  AKeyId: string): string;
var
  LOutput, LCommand: string;
begin
  if AKeyId.Trim.IsEmpty then
    raise EArgumentException.Create('Informe o identificador da chave GPG.');
  Result := TPath.GetFullPath(AArtifactPath) + '.asc';
  LCommand := Format(
    'gpg --batch --yes --armor --local-user "%s" --output "%s" ' +
    '--detach-sign "%s"', [AKeyId, Result, TPath.GetFullPath(AArtifactPath)]);
  if not FRunner.Execute(LCommand,
    TPath.GetDirectoryName(TPath.GetFullPath(AArtifactPath)), LOutput) then
    raise Exception.Create('Falha ao assinar pacote: ' + LOutput);
end;

function TBoss4DGpgPackageSigner.Verify(const AArtifactPath,
  ASignaturePath: string): Boolean;
var
  LOutput, LCommand: string;
begin
  LCommand := Format('gpg --batch --verify "%s" "%s"',
    [TPath.GetFullPath(ASignaturePath), TPath.GetFullPath(AArtifactPath)]);
  Result := FRunner.Execute(LCommand,
    TPath.GetDirectoryName(TPath.GetFullPath(AArtifactPath)), LOutput);
end;

end.
