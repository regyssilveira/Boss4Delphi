unit Boss4D.Core.Services.RegistryPullRequest;

interface

uses
  System.SysUtils, Boss4D.Core.Ports;

type
  TBoss4DRegistryPullRequestOptions = record
    RegistryRoot: string;
    PackageName: string;
    Version: string;
    Branch: string;
    PushRemote: string;
    BaseBranch: string;
    PullRequestRepository: string;
  end;

  TBoss4DRegistryPullRequestSession = record
    OriginalBranch: string;
    Branch: string;
  end;

  TBoss4DRegistryPullRequestResult = record
    Branch: string;
    PullRequestUrl: string;
  end;

  EBoss4DRegistryPullRequest = class(Exception);

  TBoss4DRegistryPullRequestService = class
  private
    FRunner: IBoss4DProcessRunner;
    class function Quote(const AValue: string): string; static;
    class procedure ValidateToken(const AName, AValue: string;
      const AAllowSlash: Boolean = False); static;
    class function ManagedPath(const ARoot, APath: string;
      const APackage: Boolean): string; static;
    procedure Run(const ACommand, ARoot, AFailure: string;
      out AOutput: string);
  public
    constructor Create(const ARunner: IBoss4DProcessRunner);
    class function DefaultBranch(const APackageName,
      AVersion: string): string; static;
    function Start(
      const AOptions: TBoss4DRegistryPullRequestOptions):
      TBoss4DRegistryPullRequestSession;
    procedure Cancel(const AOptions: TBoss4DRegistryPullRequestOptions;
      const ASession: TBoss4DRegistryPullRequestSession;
      const APackagePath, AIndexPath: string);
    function Submit(const AOptions: TBoss4DRegistryPullRequestOptions;
      const ASession: TBoss4DRegistryPullRequestSession;
      const APackagePath, AIndexPath: string):
      TBoss4DRegistryPullRequestResult;
  end;

implementation

uses
  System.IOUtils, System.Character, System.StrUtils;

class function TBoss4DRegistryPullRequestService.Quote(
  const AValue: string): string;
begin
  if AValue.Contains('"') or AValue.Contains(#13) or
     AValue.Contains(#10) then
    raise EBoss4DRegistryPullRequest.Create(
      'Valor inseguro para linha de comando.');
  Result := '"' + AValue + '"';
end;

class procedure TBoss4DRegistryPullRequestService.ValidateToken(
  const AName, AValue: string; const AAllowSlash: Boolean);
begin
  if AValue.Trim.IsEmpty then
    raise EBoss4DRegistryPullRequest.Create(AName + ' obrigatorio.');
  for var LChar in AValue do
    if not (LChar.IsLetterOrDigit or CharInSet(LChar,
      ['-', '_', '.']) or (AAllowSlash and (LChar = '/'))) then
      raise EBoss4DRegistryPullRequest.Create(
        AName + ' contem caracteres invalidos.');
end;

class function TBoss4DRegistryPullRequestService.ManagedPath(
  const ARoot, APath: string; const APackage: Boolean): string;
var
  LRoot, LPath: string;
begin
  LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ARoot));
  LPath := TPath.GetFullPath(APath);
  if not LPath.StartsWith(LRoot, True) then
    raise EBoss4DRegistryPullRequest.Create(
      'Arquivo da submissao esta fora do checkout.');
  Result := LPath.Substring(LRoot.Length);
  if APackage then
  begin
    if not Result.StartsWith('registry\packages\', True) or
       not Result.EndsWith('.json', True) then
      raise EBoss4DRegistryPullRequest.Create(
        'Metadado do pacote possui caminho invalido.');
  end
  else if not SameText(Result, 'registry\index-v2.json') then
    raise EBoss4DRegistryPullRequest.Create(
      'Indice do Registry possui caminho invalido.');
end;

procedure TBoss4DRegistryPullRequestService.Run(const ACommand,
  ARoot, AFailure: string; out AOutput: string);
begin
  AOutput := '';
  if not FRunner.Execute(ACommand, ARoot, AOutput) then
    raise EBoss4DRegistryPullRequest.Create(AFailure +
      IfThen(AOutput.Trim.IsEmpty, '', ': ' + AOutput.Trim));
end;

constructor TBoss4DRegistryPullRequestService.Create(
  const ARunner: IBoss4DProcessRunner);
begin
  inherited Create;
  if not Assigned(ARunner) then
    raise EArgumentNilException.Create('ARunner');
  FRunner := ARunner;
end;

class function TBoss4DRegistryPullRequestService.DefaultBranch(
  const APackageName, AVersion: string): string;
var
  LValue: string;
begin
  LValue := (APackageName + '-' + AVersion).ToLower;
  Result := '';
  for var LChar in LValue do
    if LChar.IsLetterOrDigit or CharInSet(LChar, ['-', '_', '.']) then
      Result := Result + LChar
    else if not Result.EndsWith('-') then
      Result := Result + '-';
  Result := 'boss4d/package-' + Result.Trim(['-']);
end;

function TBoss4DRegistryPullRequestService.Start(
  const AOptions: TBoss4DRegistryPullRequestOptions):
  TBoss4DRegistryPullRequestSession;
var
  LOutput: string;
begin
  Result := Default(TBoss4DRegistryPullRequestSession);
  ValidateToken('branch', AOptions.Branch, True);
  ValidateToken('remote', AOptions.PushRemote);
  ValidateToken('base branch', AOptions.BaseBranch, True);
  ValidateToken('PR repository', AOptions.PullRequestRepository, True);
  if not TDirectory.Exists(TPath.GetFullPath(AOptions.RegistryRoot)) then
    raise EBoss4DRegistryPullRequest.Create(
      'Checkout do Registry nao encontrado.');
  Run('git status --porcelain', AOptions.RegistryRoot,
    'Nao foi possivel consultar o checkout', LOutput);
  if not LOutput.Trim.IsEmpty then
    raise EBoss4DRegistryPullRequest.Create(
      'Checkout do Registry possui alteracoes locais.');
  Run('git branch --show-current', AOptions.RegistryRoot,
    'Nao foi possivel identificar a branch atual', LOutput);
  Result.OriginalBranch := LOutput.Trim;
  if Result.OriginalBranch.IsEmpty then
    raise EBoss4DRegistryPullRequest.Create(
      'Checkout do Registry esta em detached HEAD.');
  Run('git switch -c ' + Quote(AOptions.Branch),
    AOptions.RegistryRoot, 'Nao foi possivel criar a branch', LOutput);
  Result.Branch := AOptions.Branch;
end;

procedure TBoss4DRegistryPullRequestService.Cancel(
  const AOptions: TBoss4DRegistryPullRequestOptions;
  const ASession: TBoss4DRegistryPullRequestSession;
  const APackagePath, AIndexPath: string);
var
  LOutput, LPackage, LIndex: string;
begin
  if ASession.Branch.IsEmpty then
    Exit;
  LPackage := ManagedPath(AOptions.RegistryRoot, APackagePath, True);
  LIndex := ManagedPath(AOptions.RegistryRoot, AIndexPath, False);
  Run('git restore -- ' + Quote(LIndex),
    AOptions.RegistryRoot, 'Nao foi possivel restaurar o Registry', LOutput);
  FRunner.Execute('git restore -- ' + Quote(LPackage),
    AOptions.RegistryRoot, LOutput);
  if TFile.Exists(APackagePath) then
    Run('git clean -f -- ' + Quote(LPackage),
      AOptions.RegistryRoot, 'Nao foi possivel remover pacote novo', LOutput);
  Run('git switch ' + Quote(ASession.OriginalBranch),
    AOptions.RegistryRoot, 'Nao foi possivel restaurar a branch', LOutput);
  Run('git branch -D ' + Quote(ASession.Branch),
    AOptions.RegistryRoot, 'Nao foi possivel remover a branch temporaria',
    LOutput);
end;

function TBoss4DRegistryPullRequestService.Submit(
  const AOptions: TBoss4DRegistryPullRequestOptions;
  const ASession: TBoss4DRegistryPullRequestSession;
  const APackagePath, AIndexPath: string):
  TBoss4DRegistryPullRequestResult;
var
  LOutput, LTitle, LBody, LPackage, LIndex: string;
begin
  Result := Default(TBoss4DRegistryPullRequestResult);
  if ASession.Branch <> AOptions.Branch then
    raise EBoss4DRegistryPullRequest.Create(
      'Sessao de publicacao nao corresponde a branch solicitada.');
  LTitle := Format('registry: publish %s@%s',
    [AOptions.PackageName, AOptions.Version]);
  LBody := Format(
    'Automated Boss4D Registry submission for %s@%s.',
    [AOptions.PackageName, AOptions.Version]);
  LPackage := ManagedPath(AOptions.RegistryRoot, APackagePath, True);
  LIndex := ManagedPath(AOptions.RegistryRoot, AIndexPath, False);
  Run('git add -- ' + Quote(LIndex) + ' ' + Quote(LPackage),
    AOptions.RegistryRoot, 'Nao foi possivel preparar os metadados', LOutput);
  Run('git commit -m ' + Quote(LTitle), AOptions.RegistryRoot,
    'Nao foi possivel criar o commit', LOutput);
  Run('git push --set-upstream ' + Quote(AOptions.PushRemote) + ' ' +
    Quote(AOptions.Branch), AOptions.RegistryRoot,
    'Nao foi possivel enviar a branch', LOutput);
  Run('gh pr create --repo ' + Quote(AOptions.PullRequestRepository) +
    ' --base ' + Quote(AOptions.BaseBranch) + ' --head ' +
    Quote(AOptions.Branch) + ' --title ' + Quote(LTitle) +
    ' --body ' + Quote(LBody), AOptions.RegistryRoot,
    'Nao foi possivel abrir o pull request', LOutput);
  Result.Branch := AOptions.Branch;
  Result.PullRequestUrl := LOutput.Trim;
  if not Result.PullRequestUrl.StartsWith('https://') then
    raise EBoss4DRegistryPullRequest.Create(
      'GitHub CLI nao retornou a URL do pull request.');
end;

end.
