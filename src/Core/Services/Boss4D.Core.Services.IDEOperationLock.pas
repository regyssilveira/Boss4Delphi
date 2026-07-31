unit Boss4D.Core.Services.IDEOperationLock;

interface

uses
  System.SysUtils;

type
  EBoss4DIDEOperationLockTimeout = class(Exception);

  IBoss4DIDEOperationLease = interface
    ['{762E41F7-1597-42D8-A025-DBA50CB6B586}']
    function Key: string;
  end;

  IBoss4DIDEOperationLock = interface
    ['{D5713F3A-37A8-48AC-A4EC-EBD4C3FC82DD}']
    function Acquire(const AProfile, ACompiler: string;
      const ATimeoutMilliseconds: Cardinal = 30000):
      IBoss4DIDEOperationLease;
  end;

  TBoss4DFileIDEOperationLock = class(TInterfacedObject,
    IBoss4DIDEOperationLock)
  private
    FDirectory: string;
  public
    constructor Create(const ADirectory: string);
    function Acquire(const AProfile, ACompiler: string;
      const ATimeoutMilliseconds: Cardinal = 30000):
      IBoss4DIDEOperationLease;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.Hash,
  Winapi.Windows;

type
  TBoss4DFileIDEOperationLease = class(TInterfacedObject,
    IBoss4DIDEOperationLease)
  private
    FKey: string;
    FStream: TFileStream;
  public
    constructor Create(const AKey: string; const AStream: TFileStream);
    destructor Destroy; override;
    function Key: string;
  end;

constructor TBoss4DFileIDEOperationLease.Create(const AKey: string;
  const AStream: TFileStream);
begin
  inherited Create;
  FKey := AKey;
  FStream := AStream;
end;

destructor TBoss4DFileIDEOperationLease.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TBoss4DFileIDEOperationLease.Key: string;
begin
  Result := FKey;
end;

constructor TBoss4DFileIDEOperationLock.Create(const ADirectory: string);
begin
  inherited Create;
  if ADirectory.Trim.IsEmpty then
    raise EArgumentException.Create(
      'O diretorio de locks da IDE e obrigatorio.');
  FDirectory := TPath.GetFullPath(ADirectory);
end;

function TBoss4DFileIDEOperationLock.Acquire(
  const AProfile, ACompiler: string;
  const ATimeoutMilliseconds: Cardinal): IBoss4DIDEOperationLease;
var
  LStream: TFileStream;
  LStart: UInt64;
  LKey: string;
  LPath: string;
begin
  if AProfile.Trim.IsEmpty then
    raise EArgumentException.Create('O perfil da IDE e obrigatorio.');
  if ACompiler.Trim.IsEmpty then
    raise EArgumentException.Create('O compilador da IDE e obrigatorio.');
  TDirectory.CreateDirectory(FDirectory);
  LKey := LowerCase(AProfile.Trim + '|' + ACompiler.Trim);
  LPath := TPath.Combine(FDirectory,
    THashSHA2.GetHashString(LKey).ToLower + '.lock');
  LStart := GetTickCount64;
  repeat
    LStream := nil;
    try
      LStream := TFileStream.Create(LPath,
        fmCreate or fmShareExclusive);
      Exit(TBoss4DFileIDEOperationLease.Create(LKey, LStream));
    except
      on E: EStreamError do
      begin
        LStream.Free;
        if (GetTickCount64 - LStart) >= ATimeoutMilliseconds then
          raise EBoss4DIDEOperationLockTimeout.CreateFmt(
            'Timeout aguardando lock da IDE para %s.', [LKey]);
        Sleep(10);
      end;
    end;
  until False;
end;

end.
