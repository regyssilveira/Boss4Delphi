unit Boss4D.Posix.Publish;

{$mode objfpc}{$H+}

interface

type
  TBoss4DPublishOptions = record
    RegistryUrl: string;
    Token: string;
    DryRun: Boolean;
    RequireCleanGit: Boolean;
    RunTests: Boolean;
    Official: Boolean;
    Publisher: string;
    Repository: string;
    SignerFingerprint: string;
    SigningKey: string;
    ArtifactUrl: string;
    ArtifactOutput: string;
    SubmissionOutput: string;
  end;

  TBoss4DPublishPoster = function(const AUrl, APayload, AToken: string;
    out AResponse: string): Integer of object;
  TBoss4DPackageSigner = function(const AArtifactPath, AKeyId: string;
    out ASignaturePath: string): Boolean of object;

  TBoss4DOfficialPublishResult = record
    ArtifactPath: string;
    SignaturePath: string;
    ProvenancePath: string;
    SubmissionPath: string;
    Digest: string;
  end;

  TBoss4DPosixPublishService = class
  private
    FPoster: TBoss4DPublishPoster;
    FSigner: TBoss4DPackageSigner;
    procedure Validate(const AProjectDirectory: string;
      const AOptions: TBoss4DPublishOptions);
  public
    constructor Create(const APoster: TBoss4DPublishPoster = nil;
      const ASigner: TBoss4DPackageSigner = nil);
    function BuildPayload(const AProjectDirectory: string): string;
    function BuildOfficialDocument(const AProjectDirectory,
      ADigest: string; const AOptions: TBoss4DPublishOptions): string;
    function PrepareOfficial(const AProjectDirectory: string;
      const AOptions: TBoss4DPublishOptions): TBoss4DOfficialPublishResult;
    function Execute(const AProjectDirectory: string;
      const AOptions: TBoss4DPublishOptions): string;
  end;

implementation

uses
  Classes, SysUtils, fpjson, jsonparser, fphttpclient, opensslsockets,
  process, base64, Boss4D.Posix.Core, Boss4D.Posix.Pack;

function LoadObject(const APath: string): TJSONObject;
var
  LStream: TFileStream;
  LData: TJSONData;
begin
  if not FileExists(APath) then raise Exception.Create(
    ExtractFileName(APath) + ' not found');
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
  finally
    LStream.Free;
  end;
  if not (LData is TJSONObject) then
  begin
    LData.Free;
    raise Exception.Create(ExtractFileName(APath) + ' must be an object');
  end;
  Result := TJSONObject(LData);
end;

function ReadFileBytes(const APath: string): RawByteString;
var
  LStream: TFileStream;
begin
  Result := '';
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then LStream.ReadBuffer(Result[1], LStream.Size);
  finally
    LStream.Free;
  end;
end;

function RunShell(const ACommand, ADirectory: string): Boolean;
var
  LProcess: TProcess;
begin
  LProcess := TProcess.Create(nil);
  try
    LProcess.Executable := '/bin/sh';
    LProcess.Parameters.Add('-c');
    LProcess.Parameters.Add(ACommand);
    LProcess.CurrentDirectory := ADirectory;
    LProcess.Options := [poWaitOnExit];
    LProcess.Execute;
    Result := LProcess.ExitStatus = 0;
  finally
    LProcess.Free;
  end;
end;

function NativePost(const AUrl, APayload, AToken: string;
  out AResponse: string): Integer;
var
  LClient: TFPHTTPClient;
  LBody, LReply: TStringStream;
begin
  LClient := TFPHTTPClient.Create(nil);
  LBody := TStringStream.Create(APayload, TEncoding.UTF8);
  LReply := TStringStream.Create('', TEncoding.UTF8);
  try
    LClient.AllowRedirect := True;
    LClient.AddHeader('Content-Type', 'application/json');
    LClient.AddHeader('Authorization', 'Bearer ' + AToken);
    LClient.RequestBody := LBody;
    try
      LClient.Post(AUrl, LReply);
    except
      on E: EHTTPClient do
        if LClient.ResponseStatusCode = 0 then raise;
    end;
    Result := LClient.ResponseStatusCode;
    AResponse := LReply.DataString;
  finally
    LReply.Free;
    LBody.Free;
    LClient.Free;
  end;
end;

function NativeSign(const AArtifactPath, AKeyId: string;
  out ASignaturePath: string): Boolean;
var
  LOutput: string;
begin
  ASignaturePath := AArtifactPath + '.asc';
  Result := RunCommand('gpg',
    ['--batch', '--yes', '--armor', '--detach-sign',
     '--local-user', AKeyId, '--output', ASignaturePath, AArtifactPath],
    LOutput);
  if Result then
    Result := RunCommand('gpg',
      ['--batch', '--verify', ASignaturePath, AArtifactPath], LOutput);
end;

constructor TBoss4DPosixPublishService.Create(
  const APoster: TBoss4DPublishPoster;
  const ASigner: TBoss4DPackageSigner);
begin
  inherited Create;
  FPoster := APoster;
  FSigner := ASigner;
end;

procedure TBoss4DPosixPublishService.Validate(const AProjectDirectory: string;
  const AOptions: TBoss4DPublishOptions);
var
  LManifest, LLock, LRoot, LInstalled, LEntry, LScripts: TJSONObject;
  I: Integer;
  LTestCommand: string;
begin
  LManifest := LoadObject(IncludeTrailingPathDelimiter(AProjectDirectory) +
    'boss.json');
  LLock := LoadObject(IncludeTrailingPathDelimiter(AProjectDirectory) +
    'boss-lock.json');
  try
    if (Trim(LManifest.Get('name', '')) = '') or
       (Trim(LManifest.Get('version', '')) = '') then
      raise Exception.Create('package name and version are required');
    if LLock.Get('lockVersion', 0) <> 3 then
      raise Exception.Create('publish requires lock v3');
    if not (LLock.Find('root') is TJSONObject) then
      raise Exception.Create('lock root metadata is required');
    LRoot := TJSONObject(LLock.Find('root'));
    if not SameText(LRoot.Get('name', ''), LManifest.Get('name', '')) or
       (LRoot.Get('version', '') <> LManifest.Get('version', '')) then
      raise Exception.Create('manifest and lock root metadata differ');
    if not (LLock.Find('installedModules') is TJSONObject) then
      raise Exception.Create('lock installedModules metadata is required');
    LInstalled := TJSONObject(LLock.Find('installedModules'));
    for I := 0 to LInstalled.Count - 1 do
      if LInstalled.Items[I] is TJSONObject then
      begin
        LEntry := TJSONObject(LInstalled.Items[I]);
        if (Trim(LEntry.Get('checksum', '')) = '') or
           ((Trim(LEntry.Get('revision', '')) = '') and
            not SameText(LEntry.Get('resolvedFrom', ''),
              'registry-artifact')) then
          raise Exception.Create(
            'all dependencies require revision and checksum');
      end;
    if AOptions.RequireCleanGit and
       not RunShell('test -z "$(git status --porcelain)"',
         AProjectDirectory) then
      raise Exception.Create('worktree has uncommitted changes');
    if AOptions.RunTests and (LManifest.Find('scripts') is TJSONObject) then
    begin
      LScripts := TJSONObject(LManifest.Find('scripts'));
      LTestCommand := LScripts.Get('test', '');
      if (LTestCommand <> '') and not RunShell(LTestCommand,
        AProjectDirectory) then
        raise Exception.Create('test script failed');
    end;
  finally
    LLock.Free;
    LManifest.Free;
  end;
end;

function TBoss4DPosixPublishService.BuildPayload(
  const AProjectDirectory: string): string;
var
  LManifest, LLock, LPayload, LArtifact: TJSONObject;
  LPack: TBoss4DPosixPackResult;
  LTemp: string;
begin
  LManifest := LoadObject(IncludeTrailingPathDelimiter(AProjectDirectory) +
    'boss.json');
  LLock := LoadObject(IncludeTrailingPathDelimiter(AProjectDirectory) +
    'boss-lock.json');
  LTemp := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'boss4d-publish-' + IntToHex(Random(MaxInt), 8) + '.b4dpkg';
  try
    LPack := PackProject(AProjectDirectory, LTemp);
    LPayload := TJSONObject.Create;
    try
      LPayload.Add('schemaVersion', 1);
      LPayload.Add('name', LManifest.Get('name', ''));
      LPayload.Add('version', LManifest.Get('version', ''));
      LPayload.Add('description', LManifest.Get('description', ''));
      LPayload.Add('license', LManifest.Get('license', ''));
      LPayload.Add('lockVersion', LLock.Get('lockVersion', 0));
      LArtifact := TJSONObject.Create;
      LArtifact.Add('format', 'boss4d-package-v1');
      LArtifact.Add('sha256', LPack.Digest);
      LArtifact.Add('content', EncodeStringBase64(ReadFileBytes(
        LPack.OutputPath)));
      LArtifact.Add('provenance', EncodeStringBase64(ReadFileBytes(
        LPack.ProvenancePath)));
      LPayload.Add('artifact', LArtifact);
      LPayload.Add('dependencies',
        LLock.Find('installedModules').Clone);
      Result := LPayload.AsJSON;
    finally
      LPayload.Free;
    end;
  finally
    DeleteFile(LTemp);
    DeleteFile(LTemp + '.intoto.json');
    LLock.Free;
    LManifest.Free;
  end;
end;

function IsHex(const AValue: string; const ALength: Integer): Boolean;
var
  I: Integer;
begin
  Result := Length(AValue) = ALength;
  if not Result then Exit;
  for I := 1 to Length(AValue) do
    if not (AValue[I] in ['0'..'9', 'a'..'f', 'A'..'F']) then Exit(False);
end;

function IsNormalizedPublisher(const AValue: string): Boolean;
var
  I: Integer;
begin
  Result := (AValue <> '') and (AValue[1] <> '-') and
    (AValue[Length(AValue)] <> '-');
  if not Result then Exit;
  for I := 1 to Length(AValue) do
    if not (AValue[I] in ['a'..'z', '0'..'9', '-']) or
       ((AValue[I] = '-') and (I > 1) and (AValue[I - 1] = '-')) then
      Exit(False);
end;

function IsExactSemVer(const AValue: string): Boolean;
var
  LCore: string;
  LParts: TStringList;
  I, J: Integer;
begin
  LCore := AValue;
  I := Pos('-', LCore);
  J := Pos('+', LCore);
  if (I = 0) or ((J > 0) and (J < I)) then I := J;
  if I > 0 then Delete(LCore, I, MaxInt);
  LParts := TStringList.Create;
  try
    LParts.Delimiter := '.';
    LParts.StrictDelimiter := True;
    LParts.DelimitedText := LCore;
    Result := LParts.Count = 3;
    if not Result then Exit;
    for I := 0 to LParts.Count - 1 do
    begin
      if LParts[I] = '' then Exit(False);
      for J := 1 to Length(LParts[I]) do
        if not (LParts[I][J] in ['0'..'9']) then Exit(False);
    end;
  finally
    LParts.Free;
  end;
end;

function IsHttps(const AValue: string): Boolean;
begin
  Result := (Pos('https://', LowerCase(AValue)) = 1) and
    (Pos(' ', AValue) = 0);
end;

function RepositoryPartCount(const AValue: string): Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 1 to Length(AValue) do
    if AValue[I] = '/' then Inc(Result);
end;

function TBoss4DPosixPublishService.BuildOfficialDocument(
  const AProjectDirectory, ADigest: string;
  const AOptions: TBoss4DPublishOptions): string;
var
  LManifest, LRoot, LPackage, LVersion: TJSONObject;
  LPackages, LVersions: TJSONArray;
begin
  if not IsNormalizedPublisher(AOptions.Publisher) then
    raise Exception.Create('publisher must be a normalized lowercase ID');
  if (AOptions.Repository = '') or
     (RepositoryPartCount(AOptions.Repository) <> 3) or
     (Pos(' ', AOptions.Repository) > 0) then
    raise Exception.Create('repository must use host/owner/name');
  if not IsHex(AOptions.SignerFingerprint, 40) then
    raise Exception.Create('signer fingerprint must contain 40 hex characters');
  if not IsHex(ADigest, 64) then
    raise Exception.Create('SHA-256 must contain 64 hex characters');
  if not IsHttps(AOptions.ArtifactUrl) then
    raise Exception.Create('artifact URL must use absolute HTTPS');
  LManifest := LoadObject(IncludeTrailingPathDelimiter(AProjectDirectory) +
    'boss.json');
  try
    if not IsExactSemVer(LManifest.Get('version', '')) then
      raise Exception.Create('version must be exact SemVer');
    LRoot := TJSONObject.Create;
    try
      LRoot.Add('schemaVersion', 2);
      LPackages := TJSONArray.Create;
      LRoot.Add('packages', LPackages);
      LPackage := TJSONObject.Create;
      LPackages.Add(LPackage);
      LPackage.Add('name', LManifest.Get('name', ''));
      LPackage.Add('publisher', AOptions.Publisher);
      LPackage.Add('repository', AOptions.Repository);
      LPackage.Add('signerFingerprint',
        UpperCase(AOptions.SignerFingerprint));
      LPackage.Add('description', LManifest.Get('description', ''));
      LPackage.Add('license', LManifest.Get('license', ''));
      LVersions := TJSONArray.Create;
      LPackage.Add('versions', LVersions);
      LVersion := TJSONObject.Create;
      LVersions.Add(LVersion);
      LVersion.Add('version', LManifest.Get('version', ''));
      LVersion.Add('artifact', AOptions.ArtifactUrl);
      LVersion.Add('sha256', LowerCase(ADigest));
      LVersion.Add('signature', AOptions.ArtifactUrl + '.asc');
      LVersion.Add('provenance',
        AOptions.ArtifactUrl + '.intoto.json');
      Result := LRoot.AsJSON;
    finally
      LRoot.Free;
    end;
  finally
    LManifest.Free;
  end;
end;

function TBoss4DPosixPublishService.PrepareOfficial(
  const AProjectDirectory: string;
  const AOptions: TBoss4DPublishOptions): TBoss4DOfficialPublishResult;
var
  LPack: TBoss4DPosixPackResult;
  LDocument: string;
  LOutput: TStringList;
  LSigned: Boolean;
begin
  Result.ArtifactPath := ExpandFileName(AOptions.ArtifactOutput);
  Result.SubmissionPath := ExpandFileName(AOptions.SubmissionOutput);
  Result.SignaturePath := '';
  Result.ProvenancePath := '';
  Result.Digest := '';
  if AOptions.SigningKey = '' then
    raise Exception.Create('signing key is required');
  if AOptions.ArtifactOutput = '' then
    raise Exception.Create('artifact output is required');
  if AOptions.SubmissionOutput = '' then
    raise Exception.Create('submission output is required');
  ForceDirectories(ExtractFileDir(Result.ArtifactPath));
  ForceDirectories(ExtractFileDir(Result.SubmissionPath));
  try
    LPack := PackProject(AProjectDirectory, Result.ArtifactPath);
    Result.ArtifactPath := LPack.OutputPath;
    Result.ProvenancePath := LPack.ProvenancePath;
    Result.Digest := LPack.Digest;
    if Assigned(FSigner) then
      LSigned := FSigner(Result.ArtifactPath, AOptions.SigningKey,
        Result.SignaturePath)
    else
      LSigned := NativeSign(Result.ArtifactPath, AOptions.SigningKey,
        Result.SignaturePath);
    if not LSigned or not FileExists(Result.SignaturePath) then
      raise Exception.Create('package signature was not verified');
    LDocument := BuildOfficialDocument(AProjectDirectory,
      Result.Digest, AOptions);
    LOutput := TStringList.Create;
    try
      LOutput.Text := LDocument;
      LOutput.SaveToFile(Result.SubmissionPath);
    finally
      LOutput.Free;
    end;
  except
    if FileExists(Result.SubmissionPath) then DeleteFile(Result.SubmissionPath);
    if FileExists(Result.SignaturePath) then DeleteFile(Result.SignaturePath);
    if FileExists(Result.ProvenancePath) then DeleteFile(Result.ProvenancePath);
    if FileExists(Result.ArtifactPath) then DeleteFile(Result.ArtifactPath);
    raise;
  end;
end;

function TBoss4DPosixPublishService.Execute(const AProjectDirectory: string;
  const AOptions: TBoss4DPublishOptions): string;
var
  LUrl, LResponse: string;
  LStatus: Integer;
begin
  Validate(AProjectDirectory, AOptions);
  Result := BuildPayload(AProjectDirectory);
  if AOptions.DryRun then Exit;
  if Trim(AOptions.RegistryUrl) = '' then
    raise Exception.Create('publish registry is required');
  if AOptions.Token = '' then raise Exception.Create('publish token is required');
  LUrl := AOptions.RegistryUrl;
  while (Length(LUrl) > 0) and (LUrl[Length(LUrl)] = '/') do
    Delete(LUrl, Length(LUrl), 1);
  LUrl := LUrl + '/packages';
  if Assigned(FPoster) then
    LStatus := FPoster(LUrl, Result, AOptions.Token, LResponse)
  else
    LStatus := NativePost(LUrl, Result, AOptions.Token, LResponse);
  if LStatus = 409 then
    raise Exception.Create('package version already exists and is immutable');
  if (LStatus < 200) or (LStatus >= 300) then
    raise Exception.CreateFmt('registry returned HTTP %d: %s',
      [LStatus, LResponse]);
end;

end.
