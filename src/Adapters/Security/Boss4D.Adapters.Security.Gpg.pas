unit Boss4D.Adapters.Security.Gpg;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DGpgPackageSigner = class(TInterfacedObject, IBoss4DPackageSigner)
  private
    FRunner: IBoss4DProcessRunner;
    FGpgExecutable: string;
    class function DiscoverExecutable: string; static;
    function CommandExecutable: string;
  public
    constructor Create(const ARunner: IBoss4DProcessRunner;
      const AGpgExecutable: string = '');
    function Sign(const AArtifactPath, AKeyId: string): string;
    function Verify(const AArtifactPath, ASignaturePath: string): Boolean;
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

constructor TBoss4DGpgPackageSigner.Create(
  const ARunner: IBoss4DProcessRunner; const AGpgExecutable: string);
begin
  inherited Create;
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  FRunner := ARunner;
  FGpgExecutable := AGpgExecutable.Trim;
  if FGpgExecutable.IsEmpty then
    FGpgExecutable := DiscoverExecutable;
end;

function TBoss4DGpgPackageSigner.CommandExecutable: string;
begin
  Result := '"' + FGpgExecutable.Replace('"', '""') + '"';
end;

class function TBoss4DGpgPackageSigner.DiscoverExecutable: string;
const
  RELATIVE_CANDIDATES: array[0..2] of string = (
    'Git\usr\bin\gpg.exe',
    'GnuPG\bin\gpg.exe',
    'GNU\GnuPG\gpg.exe');
begin
  Result := GetEnvironmentVariable('BOSS4D_GPG').Trim;
  if not Result.IsEmpty then
    Exit;
  for var LRootName in TArray<string>.Create(
    'ProgramFiles', 'ProgramFiles(x86)') do
  begin
    var LRoot := GetEnvironmentVariable(LRootName);
    if LRoot.IsEmpty then
      Continue;
    for var LRelative in RELATIVE_CANDIDATES do
    begin
      var LCandidate := TPath.Combine(LRoot, LRelative);
      if TFile.Exists(LCandidate) then
        Exit(LCandidate);
    end;
  end;
  Result := 'gpg';
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
    '%s --batch --yes --armor --local-user "%s" --output "%s" ' +
    '--detach-sign "%s"', [CommandExecutable, AKeyId, Result,
      TPath.GetFullPath(AArtifactPath)]);
  if not FRunner.Execute(LCommand,
    TPath.GetDirectoryName(TPath.GetFullPath(AArtifactPath)), LOutput) then
    raise Exception.Create('Falha ao assinar pacote: ' + LOutput);
end;

function TBoss4DGpgPackageSigner.Verify(const AArtifactPath,
  ASignaturePath: string): Boolean;
var
  LOutput, LCommand: string;
begin
  LCommand := Format('%s --batch --verify "%s" "%s"',
    [CommandExecutable, TPath.GetFullPath(ASignaturePath),
      TPath.GetFullPath(AArtifactPath)]);
  Result := FRunner.Execute(LCommand,
    TPath.GetDirectoryName(TPath.GetFullPath(AArtifactPath)), LOutput);
end;

end.
