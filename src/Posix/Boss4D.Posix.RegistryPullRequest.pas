unit Boss4D.Posix.RegistryPullRequest;

{$mode objfpc}{$H+}

interface

type
  TBoss4DRegistryCommandRunner = function(const ACommand,
    ADirectory: string; out AOutput: string): Boolean of object;

  TBoss4DRegistryPullRequestOptions = record
    RegistryRoot: string;
    PackageName: string;
    Version: string;
    Branch: string;
    PushRemote: string;
    BaseBranch: string;
    PullRequestRepository: string;
    PullRequestHead: string;
  end;

  TBoss4DRegistryPullRequestSession = record
    OriginalBranch: string;
    Branch: string;
  end;

  TBoss4DRegistryPullRequestResult = record
    Branch: string;
    PullRequestUrl: string;
  end;

  TBoss4DPosixRegistryPullRequestService = class
  private
    FRunner: TBoss4DRegistryCommandRunner;
    function Execute(const ACommand, ADirectory: string;
      out AOutput: string): Boolean;
    procedure Run(const ACommand, ADirectory, AFailure: string;
      out AOutput: string);
    class function ManagedPath(const ARoot, APath: string;
      const APackage: Boolean): string; static;
  public
    constructor Create(const ARunner: TBoss4DRegistryCommandRunner = nil);
    class function DefaultBranch(const APackageName,
      AVersion: string): string; static;
    function Start(const AOptions: TBoss4DRegistryPullRequestOptions):
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
  Classes, SysUtils, Process;

function ShellQuote(const AValue: string): string;
begin
  if (Pos(#10, AValue) > 0) or (Pos(#13, AValue) > 0) then
    raise Exception.Create('unsafe command-line value');
  Result := QuotedStr(AValue);
end;

procedure ValidateToken(const AName, AValue: string;
  const AAllowSlash, AAllowColon: Boolean);
var
  I: Integer;
begin
  if Trim(AValue) = '' then raise Exception.Create(AName + ' is required');
  for I := 1 to Length(AValue) do
    if not (AValue[I] in ['a'..'z', 'A'..'Z', '0'..'9',
      '-', '_', '.']) and
       not (AAllowSlash and (AValue[I] = '/')) and
       not (AAllowColon and (AValue[I] = ':')) then
      raise Exception.Create(AName + ' contains invalid characters');
end;

function NativeRun(const ACommand, ADirectory: string;
  out AOutput: string): Boolean;
var
  LProcess: TProcess;
  LBuffer: array[0..4095] of Byte;
  LRead: LongInt;
  LStream: TMemoryStream;
begin
  Result := False;
  AOutput := '';
  LProcess := TProcess.Create(nil);
  LStream := TMemoryStream.Create;
  try
    LProcess.Executable := '/bin/sh';
    LProcess.Parameters.Add('-c');
    LProcess.Parameters.Add(ACommand);
    LProcess.CurrentDirectory := ADirectory;
    LProcess.Options := [poUsePipes, poStderrToOutPut];
    LProcess.Execute;
    repeat
      LRead := LProcess.Output.Read(LBuffer, SizeOf(LBuffer));
      if LRead > 0 then LStream.WriteBuffer(LBuffer, LRead);
    until LRead = 0;
    LProcess.WaitOnExit;
    SetLength(AOutput, LStream.Size);
    if LStream.Size > 0 then
    begin
      LStream.Position := 0;
      LStream.ReadBuffer(AOutput[1], LStream.Size);
    end;
    Result := LProcess.ExitStatus = 0;
  finally
    LStream.Free;
    LProcess.Free;
  end;
end;

constructor TBoss4DPosixRegistryPullRequestService.Create(
  const ARunner: TBoss4DRegistryCommandRunner);
begin
  inherited Create;
  FRunner := ARunner;
end;

function TBoss4DPosixRegistryPullRequestService.Execute(
  const ACommand, ADirectory: string; out AOutput: string): Boolean;
begin
  if Assigned(FRunner) then
    Result := FRunner(ACommand, ADirectory, AOutput)
  else
    Result := NativeRun(ACommand, ADirectory, AOutput);
end;

procedure TBoss4DPosixRegistryPullRequestService.Run(
  const ACommand, ADirectory, AFailure: string; out AOutput: string);
begin
  AOutput := '';
  if not Execute(ACommand, ADirectory, AOutput) then
  begin
    if Trim(AOutput) <> '' then
      raise Exception.Create(AFailure + ': ' + Trim(AOutput));
    raise Exception.Create(AFailure);
  end;
end;

class function TBoss4DPosixRegistryPullRequestService.DefaultBranch(
  const APackageName, AVersion: string): string;
var
  LValue: string;
  I: Integer;
begin
  LValue := LowerCase(APackageName + '-' + AVersion);
  Result := '';
  for I := 1 to Length(LValue) do
    if LValue[I] in ['a'..'z', '0'..'9', '-', '_', '.'] then
      Result := Result + LValue[I]
    else if (Result = '') or (Result[Length(Result)] <> '-') then
      Result := Result + '-';
  while (Result <> '') and (Result[Length(Result)] = '-') do
    Delete(Result, Length(Result), 1);
  Result := 'boss4d/package-' + Result;
end;

class function TBoss4DPosixRegistryPullRequestService.ManagedPath(
  const ARoot, APath: string; const APackage: Boolean): string;
var
  LRoot, LPath: string;
begin
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(ARoot));
  LPath := ExpandFileName(APath);
  if Pos(LRoot, LPath) <> 1 then
    raise Exception.Create('submission file is outside Registry checkout');
  Result := Copy(LPath, Length(LRoot) + 1, MaxInt);
  if APackage then
  begin
    if (Pos('registry/packages/', Result) <> 1) or
       (ExtractFileExt(Result) <> '.json') then
      raise Exception.Create('invalid package metadata path');
  end
  else if Result <> 'registry/index-v2.json' then
    raise Exception.Create('invalid Registry index path');
end;

function TBoss4DPosixRegistryPullRequestService.Start(
  const AOptions: TBoss4DRegistryPullRequestOptions):
  TBoss4DRegistryPullRequestSession;
var
  LOutput: string;
begin
  Result := Default(TBoss4DRegistryPullRequestSession);
  ValidateToken('branch', AOptions.Branch, True, False);
  ValidateToken('remote', AOptions.PushRemote, False, False);
  ValidateToken('base branch', AOptions.BaseBranch, True, False);
  ValidateToken('PR repository', AOptions.PullRequestRepository, True, False);
  ValidateToken('PR head', AOptions.PullRequestHead, True, True);
  if not DirectoryExists(ExpandFileName(AOptions.RegistryRoot)) then
    raise Exception.Create('Registry checkout not found');
  Run('git status --porcelain', AOptions.RegistryRoot,
    'cannot inspect Registry checkout', LOutput);
  if Trim(LOutput) <> '' then
    raise Exception.Create('Registry checkout has local changes');
  Run('git branch --show-current', AOptions.RegistryRoot,
    'cannot identify current branch', LOutput);
  Result.OriginalBranch := Trim(LOutput);
  if Result.OriginalBranch = '' then
    raise Exception.Create('Registry checkout is in detached HEAD');
  Run('git switch -c ' + ShellQuote(AOptions.Branch),
    AOptions.RegistryRoot, 'cannot create publication branch', LOutput);
  Result.Branch := AOptions.Branch;
end;

procedure TBoss4DPosixRegistryPullRequestService.Cancel(
  const AOptions: TBoss4DRegistryPullRequestOptions;
  const ASession: TBoss4DRegistryPullRequestSession;
  const APackagePath, AIndexPath: string);
var
  LOutput, LPackage, LIndex: string;
begin
  if ASession.Branch = '' then Exit;
  LPackage := ManagedPath(AOptions.RegistryRoot, APackagePath, True);
  LIndex := ManagedPath(AOptions.RegistryRoot, AIndexPath, False);
  Run('git restore -- ' + ShellQuote(LIndex), AOptions.RegistryRoot,
    'cannot restore Registry index', LOutput);
  Execute('git restore -- ' + ShellQuote(LPackage),
    AOptions.RegistryRoot, LOutput);
  if FileExists(APackagePath) then
    Run('git clean -f -- ' + ShellQuote(LPackage), AOptions.RegistryRoot,
      'cannot remove new package metadata', LOutput);
  Run('git switch ' + ShellQuote(ASession.OriginalBranch),
    AOptions.RegistryRoot, 'cannot restore original branch', LOutput);
  Run('git branch -D ' + ShellQuote(ASession.Branch),
    AOptions.RegistryRoot, 'cannot remove temporary branch', LOutput);
end;

function TBoss4DPosixRegistryPullRequestService.Submit(
  const AOptions: TBoss4DRegistryPullRequestOptions;
  const ASession: TBoss4DRegistryPullRequestSession;
  const APackagePath, AIndexPath: string):
  TBoss4DRegistryPullRequestResult;
var
  LOutput, LPackage, LIndex, LTitle, LBody: string;
begin
  Result := Default(TBoss4DRegistryPullRequestResult);
  if ASession.Branch <> AOptions.Branch then
    raise Exception.Create('publication session does not match branch');
  LPackage := ManagedPath(AOptions.RegistryRoot, APackagePath, True);
  LIndex := ManagedPath(AOptions.RegistryRoot, AIndexPath, False);
  LTitle := Format('registry: publish %s@%s',
    [AOptions.PackageName, AOptions.Version]);
  LBody := Format('Automated Boss4D Registry submission for %s@%s.',
    [AOptions.PackageName, AOptions.Version]);
  Run('git add -- ' + ShellQuote(LIndex) + ' ' + ShellQuote(LPackage),
    AOptions.RegistryRoot, 'cannot stage Registry metadata', LOutput);
  Run('git commit -m ' + ShellQuote(LTitle), AOptions.RegistryRoot,
    'cannot create Registry commit', LOutput);
  Run('git push --set-upstream ' + ShellQuote(AOptions.PushRemote) + ' ' +
    ShellQuote(AOptions.Branch), AOptions.RegistryRoot,
    'cannot push publication branch', LOutput);
  Run('gh pr create --repo ' + ShellQuote(AOptions.PullRequestRepository) +
    ' --base ' + ShellQuote(AOptions.BaseBranch) + ' --head ' +
    ShellQuote(AOptions.PullRequestHead) + ' --title ' +
    ShellQuote(LTitle) + ' --body ' + ShellQuote(LBody),
    AOptions.RegistryRoot, 'cannot open Registry pull request', LOutput);
  Result.Branch := AOptions.Branch;
  Result.PullRequestUrl := Trim(LOutput);
  if Pos('https://', Result.PullRequestUrl) <> 1 then
    raise Exception.Create('GitHub CLI did not return pull request URL');
end;

end.
