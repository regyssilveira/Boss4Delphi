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
  end;

  TBoss4DPublishPoster = function(const AUrl, APayload, AToken: string;
    out AResponse: string): Integer of object;

  TBoss4DPosixPublishService = class
  private
    FPoster: TBoss4DPublishPoster;
    procedure Validate(const AProjectDirectory: string;
      const AOptions: TBoss4DPublishOptions);
  public
    constructor Create(const APoster: TBoss4DPublishPoster = nil);
    function BuildPayload(const AProjectDirectory: string): string;
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

constructor TBoss4DPosixPublishService.Create(
  const APoster: TBoss4DPublishPoster);
begin
  inherited Create;
  FPoster := APoster;
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
