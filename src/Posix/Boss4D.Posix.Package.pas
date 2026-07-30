unit Boss4D.Posix.Package;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBoss4DSignatureVerifier = function(const AArtifactPath,
    ASignaturePath: string): Boolean of object;

  TBoss4DPackageRequest = record
    ArtifactUrl: string;
    Sha256: string;
    SignatureUrl: string;
    ProvenanceUrl: string;
    TargetDirectory: string;
  end;

  TBoss4DPackageResult = record
    Installed: Boolean;
    FileCount: Integer;
    Digest: string;
  end;

  TBoss4DPackageService = class
  private
    FVerifier: TBoss4DSignatureVerifier;
    function VerifySignature(const AArtifactPath,
      ASignaturePath: string): Boolean;
  public
    constructor Create(const AVerifier: TBoss4DSignatureVerifier = nil);
    function Install(const ARequest: TBoss4DPackageRequest):
      TBoss4DPackageResult;
  end;

function Sha256File(const APath: string): string;

implementation

uses
  fpjson, jsonparser, fphttpclient, opensslsockets, process, base64;

function IsHttp(const AValue: string): Boolean;
begin
  Result := (Pos('http://', LowerCase(AValue)) = 1) or
    (Pos('https://', LowerCase(AValue)) = 1);
end;

procedure CopyStream(const ASource, ATarget: string);
var
  LInput, LOutput: TFileStream;
begin
  LInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    LOutput := TFileStream.Create(ATarget, fmCreate);
    try
      LOutput.CopyFrom(LInput, 0);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

procedure Download(const ALocation, ATarget: string);
var
  LClient: TFPHTTPClient;
  LOutput: TFileStream;
begin
  if not IsHttp(ALocation) then
  begin
    CopyStream(ExpandFileName(ALocation), ATarget);
    Exit;
  end;
  LClient := TFPHTTPClient.Create(nil);
  try
    LClient.AllowRedirect := True;
    LOutput := TFileStream.Create(ATarget, fmCreate);
    try
      LClient.Get(ALocation, LOutput);
    finally
      LOutput.Free;
    end;
  finally
    LClient.Free;
  end;
end;

function Sha256File(const APath: string): string;
var
  LOutput: string;
begin
  if not RunCommand('sha256sum', [APath], LOutput) then
    raise Exception.Create('sha256sum failed for ' + APath);
  Result := LowerCase(Copy(Trim(LOutput), 1, 64));
  if Length(Result) <> 64 then
    raise Exception.Create('invalid sha256sum output');
end;

procedure DeleteDirectoryTree(const ADirectory: string);
var
  LSearch: TSearchRec;
  LPath: string;
begin
  if not DirectoryExists(ADirectory) then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*',
    faAnyFile, LSearch) = 0 then
  try
    repeat
      if (LSearch.Name = '.') or (LSearch.Name = '..') then Continue;
      LPath := IncludeTrailingPathDelimiter(ADirectory) + LSearch.Name;
      if (LSearch.Attr and faDirectory) <> 0 then
        DeleteDirectoryTree(LPath)
      else
        DeleteFile(LPath);
    until FindNext(LSearch) <> 0;
  finally
    FindClose(LSearch);
  end;
  RemoveDir(ADirectory);
end;

function SafeTarget(const AStage, ARelative: string): string;
var
  LNormalized, LRoot: string;
begin
  LNormalized := StringReplace(ARelative, '/', DirectorySeparator,
    [rfReplaceAll]);
  if (LNormalized = '') or (LNormalized = '..') or
     (LNormalized[1] = DirectorySeparator) or
     (Pos('..' + DirectorySeparator, LNormalized) > 0) or
     (Pos(DirectorySeparator + '..', LNormalized) > 0) or
     (ExtractFileDrive(LNormalized) <> '') then
    raise Exception.Create('unsafe package path: ' + ARelative);
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(AStage));
  Result := ExpandFileName(LRoot + LNormalized);
  if Pos(LRoot, Result) <> 1 then
    raise Exception.Create('package path escaped staging: ' + ARelative);
end;

function VerifyProvenance(const APath, ADigest: string): Boolean;
var
  LData: TJSONData;
  LRoot, LSubject, LDigest: TJSONObject;
  LSubjects: TJSONArray;
  LStream: TFileStream;
  I: Integer;
begin
  Result := False;
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    LData := GetJSON(LStream);
    try
      if not (LData is TJSONObject) then Exit;
      LRoot := TJSONObject(LData);
      if LRoot.Get('_type', '') <> 'https://in-toto.io/Statement/v1' then Exit;
      if not (LRoot.Find('subject') is TJSONArray) then Exit;
      LSubjects := TJSONArray(LRoot.Find('subject'));
      for I := 0 to LSubjects.Count - 1 do
        if LSubjects.Items[I] is TJSONObject then
        begin
          LSubject := TJSONObject(LSubjects.Items[I]);
          if LSubject.Find('digest') is TJSONObject then
          begin
            LDigest := TJSONObject(LSubject.Find('digest'));
            if SameText(LDigest.Get('sha256', ''), ADigest) then Exit(True);
          end;
        end;
    finally
      LData.Free;
    end;
  finally
    LStream.Free;
  end;
end;

constructor TBoss4DPackageService.Create(
  const AVerifier: TBoss4DSignatureVerifier);
begin
  inherited Create;
  FVerifier := AVerifier;
end;

function TBoss4DPackageService.VerifySignature(const AArtifactPath,
  ASignaturePath: string): Boolean;
var
  LOutput: string;
begin
  if Assigned(FVerifier) then Exit(FVerifier(AArtifactPath, ASignaturePath));
  try
    Result := RunCommand('gpg',
      ['--batch', '--verify', ASignaturePath, AArtifactPath], LOutput);
  except
    on E: Exception do
      raise Exception.Create('GPG is required to verify package signatures: ' +
        E.Message);
  end;
end;

function TBoss4DPackageService.Install(const ARequest: TBoss4DPackageRequest):
  TBoss4DPackageResult;
var
  LTemp, LArtifact, LSignature, LProvenance, LStage, LBackup: string;
  LData: TJSONData;
  LRoot, LFile: TJSONObject;
  LFiles: TJSONArray;
  LDecoded: RawByteString;
  LStream, LJsonStream: TFileStream;
  I: Integer;
  LTarget: string;
begin
  Result.Installed := False;
  Result.FileCount := 0;
  Result.Digest := '';
  if (ARequest.ArtifactUrl = '') or (ARequest.Sha256 = '') then
    raise Exception.Create('artifact URL and SHA-256 are required');
  if ARequest.TargetDirectory = '' then
    raise Exception.Create('target directory is required');
  LTemp := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'boss4d-package-' + IntToHex(Random(MaxInt), 8);
  LArtifact := IncludeTrailingPathDelimiter(LTemp) + 'package.b4dpkg';
  LSignature := LArtifact + '.asc';
  LProvenance := LArtifact + '.intoto.json';
  LStage := ExpandFileName(ARequest.TargetDirectory) + '.boss4d-stage';
  LBackup := ExpandFileName(ARequest.TargetDirectory) + '.boss4d-backup';
  ForceDirectories(LTemp);
  DeleteDirectoryTree(LStage);
  DeleteDirectoryTree(LBackup);
  try
    Download(ARequest.ArtifactUrl, LArtifact);
    Result.Digest := Sha256File(LArtifact);
    if not SameText(Result.Digest, ARequest.Sha256) then
      raise Exception.Create('artifact SHA-256 mismatch');
    if ARequest.SignatureUrl <> '' then
    begin
      Download(ARequest.SignatureUrl, LSignature);
      if not VerifySignature(LArtifact, LSignature) then
        raise Exception.Create('package signature verification failed');
    end;
    if ARequest.ProvenanceUrl <> '' then
    begin
      Download(ARequest.ProvenanceUrl, LProvenance);
      if not VerifyProvenance(LProvenance, Result.Digest) then
        raise Exception.Create('package provenance verification failed');
    end;
    LJsonStream := TFileStream.Create(LArtifact,
      fmOpenRead or fmShareDenyWrite);
    try
      LData := GetJSON(LJsonStream);
      try
        if not (LData is TJSONObject) then
          raise Exception.Create('package root must be an object');
        LRoot := TJSONObject(LData);
        if (LRoot.Get('format', '') <> 'boss4d-package') or
           (LRoot.Get('schemaVersion', 0) <> 1) then
          raise Exception.Create('unsupported package format');
        if not (LRoot.Find('files') is TJSONArray) then
          raise Exception.Create('package files array is required');
        LFiles := TJSONArray(LRoot.Find('files'));
        ForceDirectories(LStage);
        for I := 0 to LFiles.Count - 1 do
        begin
          if not (LFiles.Items[I] is TJSONObject) then
            raise Exception.Create('package file entry must be an object');
          LFile := TJSONObject(LFiles.Items[I]);
          LTarget := SafeTarget(LStage, LFile.Get('path', ''));
          ForceDirectories(ExtractFileDir(LTarget));
          LDecoded := DecodeStringBase64(LFile.Get('content', ''));
          LStream := TFileStream.Create(LTarget, fmCreate);
          try
            if Length(LDecoded) > 0 then
              LStream.WriteBuffer(LDecoded[1], Length(LDecoded));
          finally
            LStream.Free;
          end;
          if not SameText(Sha256File(LTarget), LFile.Get('sha256', '')) then
            raise Exception.Create('package file digest mismatch: ' +
              LFile.Get('path', ''));
          Inc(Result.FileCount);
        end;
      finally
        LData.Free;
      end;
    finally
      LJsonStream.Free;
    end;
    if DirectoryExists(ARequest.TargetDirectory) and
       not RenameFile(ARequest.TargetDirectory, LBackup) then
      raise Exception.Create('unable to backup package target');
    try
      if not RenameFile(LStage, ARequest.TargetDirectory) then
        raise Exception.Create('unable to commit package target');
      DeleteDirectoryTree(LBackup);
    except
      if DirectoryExists(LBackup) and
         not DirectoryExists(ARequest.TargetDirectory) then
        RenameFile(LBackup, ARequest.TargetDirectory);
      raise;
    end;
    Result.Installed := True;
  finally
    DeleteDirectoryTree(LStage);
    DeleteDirectoryTree(LBackup);
    DeleteDirectoryTree(LTemp);
  end;
end;

end.
