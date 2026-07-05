unit Boss4D.Core.Domain.Lock;

interface

uses
  System.Generics.Collections, Boss4D.Core.Domain.Dependency;

type
  { Representa os artefatos compilados de uma dependencia }
  TBoss4DDependencyArtifacts = class
  private
    FBin: TList<string>;
    FDcp: TList<string>;
    FDcu: TList<string>;
    FBpl: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    property Bin: TList<string> read FBin;
    property Dcp: TList<string> read FDcp;
    property Dcu: TList<string> read FDcu;
    property Bpl: TList<string> read FBpl;
  end;

  { Representa uma dependencia travada no arquivo lock }
  TBoss4DLockedDependency = class
  private
    FName: string;
    FVersion: string;
    FHash: string;
    FChecksum: string;
    FArtifacts: TBoss4DDependencyArtifacts;
    FChanged: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property Name: string read FName write FName;
    property Version: string read FVersion write FVersion;
    property Hash: string read FHash write FHash;
    property Checksum: string read FChecksum write FChecksum;
    property Artifacts: TBoss4DDependencyArtifacts read FArtifacts;
    property Changed: Boolean read FChanged write FChanged;
  end;

  { Entidade pura de dominio representando o arquivo boss.lock }
  TBoss4DLock = class
  private
    FHash: string;
    FUpdated: string;
    FInstalled: TObjectDictionary<string, TBoss4DLockedDependency>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddDependency(const ADep: TBoss4DDependency; const AVersion, AHash: string); overload;
    procedure AddDependency(const ADep: TBoss4DDependency; const AVersion, AHash, AChecksum: string); overload;
    function GetInstalled(const ADep: TBoss4DDependency; out ALockedDep: TBoss4DLockedDependency): Boolean;

    property Hash: string read FHash write FHash;
    property Updated: string read FUpdated write FUpdated;
    property Installed: TObjectDictionary<string, TBoss4DLockedDependency> read FInstalled;
  end;

implementation

{ TBoss4DDependencyArtifacts }

constructor TBoss4DDependencyArtifacts.Create;
begin
  inherited Create;
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
  FChanged := False;
end;

destructor TBoss4DLockedDependency.Destroy;
begin
  FArtifacts.Free;
  inherited Destroy;
end;

{ TBoss4DLock }

constructor TBoss4DLock.Create;
begin
  inherited Create;
  FInstalled := TObjectDictionary<string, TBoss4DLockedDependency>.Create([doOwnsValues]);
end;

destructor TBoss4DLock.Destroy;
begin
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
  if not FInstalled.TryGetValue(LKey, LLocked) then
  begin
    LLocked := TBoss4DLockedDependency.Create;
    LLocked.Name := ADep.Name;
    LLocked.Version := AVersion;
    LLocked.Hash := AHash;
    LLocked.Checksum := AChecksum;
    LLocked.Changed := True;
    FInstalled.Add(LKey, LLocked);
  end
  else
  begin
    LLocked.Version := AVersion;
    LLocked.Hash := AHash;
    LLocked.Checksum := AChecksum;
    LLocked.Changed := True;
  end;
end;

function TBoss4DLock.GetInstalled(const ADep: TBoss4DDependency; out ALockedDep: TBoss4DLockedDependency): Boolean;
begin
  Result := FInstalled.TryGetValue(ADep.GetKey, ALockedDep);
end;

end.
