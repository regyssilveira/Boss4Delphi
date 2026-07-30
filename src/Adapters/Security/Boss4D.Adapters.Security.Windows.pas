unit Boss4D.Adapters.Security.Windows;

interface

uses
  Boss4D.Core.Ports;

type
  TBoss4DWindowsCredentialStore = class(TInterfacedObject,
    IBoss4DCredentialStore)
  private
    function TargetName(const AName: string): string;
  public
    procedure SetSecret(const AName, AValue: string);
    function GetSecret(const AName: string): string;
    procedure DeleteSecret(const AName: string);
  end;

implementation

uses
  System.SysUtils, Winapi.Windows, Winapi.WinCred;

const
  ERROR_CREDENTIAL_NOT_FOUND = 1168;

function TBoss4DWindowsCredentialStore.TargetName(
  const AName: string): string;
begin
  Result := 'Boss4D/' + LowerCase(AName);
end;

procedure TBoss4DWindowsCredentialStore.SetSecret(const AName,
  AValue: string);
var
  LCredential: CREDENTIAL;
  LBytes: TBytes;
  LTarget: string;
begin
  LTarget := TargetName(AName);
  LBytes := TEncoding.UTF8.GetBytes(AValue);
  FillChar(LCredential, SizeOf(LCredential), 0);
  LCredential.&Type := CRED_TYPE_GENERIC;
  LCredential.TargetName := PChar(LTarget);
  LCredential.CredentialBlobSize := Length(LBytes);
  if Length(LBytes) > 0 then
    LCredential.CredentialBlob := @LBytes[0];
  LCredential.Persist := CRED_PERSIST_LOCAL_MACHINE;
  if not CredWrite(@LCredential, 0) then
    RaiseLastOSError;
end;

function TBoss4DWindowsCredentialStore.GetSecret(
  const AName: string): string;
var
  LCredential: PCREDENTIAL;
  LBytes: TBytes;
begin
  Result := '';
  LCredential := nil;
  if not CredRead(PChar(TargetName(AName)), CRED_TYPE_GENERIC, 0,
    LCredential) then
    Exit;
  try
    SetLength(LBytes, LCredential.CredentialBlobSize);
    if Length(LBytes) > 0 then
      Move(LCredential.CredentialBlob^, LBytes[0], Length(LBytes));
    Result := TEncoding.UTF8.GetString(LBytes);
  finally
    CredFree(LCredential);
  end;
end;

procedure TBoss4DWindowsCredentialStore.DeleteSecret(
  const AName: string);
begin
  if not CredDelete(PChar(TargetName(AName)), CRED_TYPE_GENERIC, 0) and
     (GetLastError <> ERROR_CREDENTIAL_NOT_FOUND) then
    RaiseLastOSError;
end;

end.
