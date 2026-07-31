unit Boss4D.GUI.IDE.Backend;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDEProfileApplication,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.GUI.IDE.Presenter;

type
  TBoss4DGUIIDEManagementBackend = class(TInterfacedObject,
    IBoss4DIDEManagementBackend)
  private
    FQuery: TBoss4DIDEManagementQuery;
    FProfiles: TBoss4DIDEProfileService;
    FOperations: TBoss4DIDEProfileApplication;
  public
    constructor Create(const AQuery: TBoss4DIDEManagementQuery;
      const AProfiles: TBoss4DIDEProfileService;
      const AOperations: TBoss4DIDEProfileApplication);
    function Profiles: TObjectList<TBoss4DIDEProfileView>;
    function Packages(const AProfileId: string):
      TObjectList<TBoss4DIDEPackageView>;
    function InstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
    function UninstallTargets(const AProfileId, APackage: string):
      TObjectList<TBoss4DIDETargetView>;
    function Install(const AProfileId, APackage: string;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AIDEOpenPolicy: TBoss4DIDEOpenPolicy): Integer;
    function Uninstall(const AProfileId, APackage: string): Integer;
    function Repair(const AProfileId: string): Integer;
    procedure Launch(const AProfileId: string);
    procedure CreateProfile(const AName, ADescription, ACompiler,
      AExecutable: string);
    procedure CloneProfile(const ASourceId, AName: string);
    procedure RemoveProfile(const AProfileId: string);
  end;

implementation

uses
  System.SysUtils;

constructor TBoss4DGUIIDEManagementBackend.Create(
  const AQuery: TBoss4DIDEManagementQuery;
  const AProfiles: TBoss4DIDEProfileService;
  const AOperations: TBoss4DIDEProfileApplication);
begin
  inherited Create;
  if not Assigned(AQuery) then
    raise EArgumentNilException.Create('AQuery');
  if not Assigned(AProfiles) then
    raise EArgumentNilException.Create('AProfiles');
  if not Assigned(AOperations) then
    raise EArgumentNilException.Create('AOperations');
  FQuery := AQuery;
  FProfiles := AProfiles;
  FOperations := AOperations;
end;

function TBoss4DGUIIDEManagementBackend.Profiles:
  TObjectList<TBoss4DIDEProfileView>;
begin
  Result := FQuery.Profiles;
end;

function TBoss4DGUIIDEManagementBackend.Packages(
  const AProfileId: string): TObjectList<TBoss4DIDEPackageView>;
begin
  Result := FQuery.Packages(AProfileId);
end;

function TBoss4DGUIIDEManagementBackend.InstallTargets(
  const AProfileId, APackage: string):
  TObjectList<TBoss4DIDETargetView>;
begin
  Result := FQuery.InstallTargets(AProfileId, APackage);
end;

function TBoss4DGUIIDEManagementBackend.UninstallTargets(
  const AProfileId, APackage: string):
  TObjectList<TBoss4DIDETargetView>;
begin
  Result := FQuery.UninstallTargets(AProfileId, APackage);
end;

function TBoss4DGUIIDEManagementBackend.Install(
  const AProfileId, APackage: string;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AIDEOpenPolicy: TBoss4DIDEOpenPolicy): Integer;
begin
  Result := FOperations.Install(AProfileId, APackage,
    AConflictPolicy, AIDEOpenPolicy).Affected;
end;

function TBoss4DGUIIDEManagementBackend.Uninstall(
  const AProfileId, APackage: string): Integer;
begin
  Result := FOperations.Uninstall(AProfileId, APackage).Affected;
end;

function TBoss4DGUIIDEManagementBackend.Repair(
  const AProfileId: string): Integer;
begin
  Result := FOperations.Repair(AProfileId).Affected;
end;

procedure TBoss4DGUIIDEManagementBackend.Launch(
  const AProfileId: string);
begin
  FProfiles.Launch(AProfileId);
end;

procedure TBoss4DGUIIDEManagementBackend.CreateProfile(
  const AName, ADescription, ACompiler, AExecutable: string);
begin
  var LProfile := FProfiles.CreateProfile(AName, ADescription,
    ACompiler, AExecutable);
  LProfile.Free;
end;

procedure TBoss4DGUIIDEManagementBackend.CloneProfile(
  const ASourceId, AName: string);
begin
  var LProfile := FProfiles.CloneProfile(ASourceId, AName);
  LProfile.Free;
end;

procedure TBoss4DGUIIDEManagementBackend.RemoveProfile(
  const AProfileId: string);
begin
  FProfiles.Remove(AProfileId);
end;

end.
