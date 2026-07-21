unit Boss4D.Core.Domain.Lock;

interface

uses
  System.Generics.Collections, Boss4D.Core.Domain.Dependency;

type
  TBoss4DLockSchema = class
  public const
    CurrentVersion = 2;
  end;

  { Representa os artefatos compilados de uma dependencia }
  TBoss4DDependencyArtifacts = class
  private
    FBin: TList<string>;
    FDcp: TList<string>;
    FDcu: TList<string>;
    FBpl: TList<string>;
    FBase: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Bin: TList<string> read FBin;
    property Dcp: TList<string> read FDcp;
    property Dcu: TList<string> read FDcu;
    property Bpl: TList<string> read FBpl;
    property Base: string read FBase write FBase;
  end;

  { Representa uma dependencia travada no arquivo lock }
  TBoss4DLockedDependency = class
  private
    FName: string;
    FVersion: string;
    FHash: string;
    FChecksum: string;
    FChecksumAlgorithm: string;
    FRepository: string;
    FRevision: string;
    FResolvedFrom: string;
    FLicenseExpression: string;
    FLicenseSource: string;
    FDependencies: TList<string>;
    FArtifacts: TBoss4DDependencyArtifacts;
    FChanged: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property Hash: string read FHash write FHash;
    property Checksum: string read FChecksum write FChecksum;
    property ChecksumAlgorithm: string read FChecksumAlgorithm write FChecksumAlgorithm;
    property Repository: string read FRepository write FRepository;
    property Revision: string read FRevision write FRevision;
    property ResolvedFrom: string read FResolvedFrom write FResolvedFrom;
    property LicenseExpression: string read FLicenseExpression write FLicenseExpression;
    property LicenseSource: string read FLicenseSource write FLicenseSource;
    property Dependencies: TList<string> read FDependencies;
    property Artifacts: TBoss4DDependencyArtifacts read FArtifacts;
    property Changed: Boolean read FChanged write FChanged;
  end;

  { Entidade pura de dominio representando o arquivo boss.lock }
  TBoss4DLock = class
  private
    FLockVersion: Integer;
    FHash: string;
    FUpdated: string;
    FHasRootMetadata: Boolean;
    FRootName: string;
    FRootVersion: string;
    FRootDescription: string;
    FRootHomepage: string;
    FRootLicense: string;
    FRootDependencies: TList<string>;
    FInstalled: TObjectDictionary<string, TBoss4DLockedDependency>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddDependency(const ADep: TBoss4DDependency; const AVersion, AHash: string); overload;
    procedure AddDependency(const ADep: TBoss4DDependency; const AVersion, AHash, AChecksum: string); overload;
    function GetInstalled(const ADep: TBoss4DDependency; out ALockedDep: TBoss4DLockedDependency): Boolean;

    property Hash: string read FHash write FHash;
    property Updated: string read FUpdated write FUpdated;
    property HasRootMetadata: Boolean read FHasRootMetadata write FHasRootMetadata;
    property RootName: string read FRootName write FRootName;
    property RootVersion: string read FRootVersion write FRootVersion;
    property RootDescription: string read FRootDescription write FRootDescription;
    property RootHomepage: string read FRootHomepage write FRootHomepage;
    property RootLicense: string read FRootLicense write FRootLicense;
    property RootDependencies: TList<string> read FRootDependencies;
    property LockVersion: Integer read FLockVersion write FLockVersion;
    property Installed: TObjectDictionary<string, TBoss4DLockedDependency> read FInstalled;
  end;

implementation

{ TBoss4DDependencyArtifacts }

constructor TBoss4DDependencyArtifacts.Create;
begin
  inherited Create;
  FBase := 'project';
  FBin := TList<string>.Create;
  FDcp := TList<string>.Create;
  FDcu := TList<string>.Create;
  FBpl := TList<string>.Create;
end;

destructor TBoss4DDependencyArtifacts.Destroy;
begin
  FBpl.Free;
  FDcu.Free;
  FDcp.Free;
  FBin.Free;
  inherited Destroy;
end;

{ TBoss4DLockedDependency }

constructor TBoss4DLockedDependency.Create;
begin
  inherited Create;
  FArtifacts := TBoss4DDependencyArtifacts.Create;
  FDependencies := TList<string>.Create;
  FChecksumAlgorithm := 'SHA-256';
  FChanged := False;
end;

destructor TBoss4DLockedDependency.Destroy;
begin
  FDependencies.Free;
  FArtifacts.Free;
  inherited Destroy;
end;

{ TBoss4DLock }

constructor TBoss4DLock.Create;
begin
  inherited Create;
  FLockVersion := TBoss4DLockSchema.CurrentVersion;
  FRootDependencies := TList<string>.Create;
  FInstalled := TObjectDictionary<string, TBoss4DLockedDependency>.Create([doOwnsValues]);
end;

destructor TBoss4DLock.Destroy;
begin
  FRootDependencies.Free;
  FInstalled.Free;
  inherited Destroy;
end;

procedure TBoss4DLock.AddDependency(const ADep: TBoss4DDependency; const AVersion, AHash: string);
begin
  AddDependency(ADep, AVersion, AHash, '');
end;

procedure TBoss4DLock.AddDependency(const ADep: TBoss4DDependency; const AVersion, AHash, AChecksum: string);
var
  LKey: string;
  LLocked: TBoss4DLockedDependency;
begin
  LKey := ADep.GetKey;
  if not FInstalled.TryGetValue(LKey, LLocked) and
     not FInstalled.TryGetValue(ADep.GetLegacyKey, LLocked) then
  begin
    LLocked := TBoss4DLockedDependency.Create;
    LLocked.Name := ADep.Name;
    LLocked.Repository := ADep.GetCanonicalRepository;
    LLocked.Version := AVersion;
    LLocked.Hash := AHash;
    LLocked.Checksum := AChecksum;
    LLocked.Changed := True;
    FInstalled.Add(LKey, LLocked);
  end
  else
  begin
    LLocked.Repository := ADep.GetCanonicalRepository;
    LLocked.Version := AVersion;
    LLocked.Hash := AHash;
    LLocked.Checksum := AChecksum;
    LLocked.Changed := True;
  end;
end;

function TBoss4DLock.GetInstalled(const ADep: TBoss4DDependency; out ALockedDep: TBoss4DLockedDependency): Boolean;
begin
  Result := FInstalled.TryGetValue(ADep.GetKey, ALockedDep);
  if not Result then
    Result := FInstalled.TryGetValue(ADep.GetLegacyKey, ALockedDep);
end;

end.
