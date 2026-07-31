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
    function Undo: Integer;
    function History: TList<string>;
    procedure Launch(const AProfileId: string);
    procedure CreateProfile(const AName, ADescription, ACompiler,
      AExecutable: string);
    procedure CloneProfile(const ASourceId, AName: string);
    procedure RemoveProfile(const AProfileId: string);
    procedure ConfigureTarget(const AProfileId, APlatform,
      AConfiguration: string);
  end;

implementation

uses
  System.SysUtils,
  Boss4D.Core.Services.IDEOperationResult;

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

function TBoss4DGUIIDEManagementBackend.Undo: Integer;
begin
  Result := FOperations.UndoLatest.Affected;
end;

function TBoss4DGUIIDEManagementBackend.History: TList<string>;
begin
  Result := TList<string>.Create;
  var LHistory := FOperations.History;
  try
    for var LItem in LHistory do
      Result.Add(Format('%s | %s | %s | %s | %s',
        [LItem.StartedAt,
         TBoss4DIDEOperationStatuses.NameOf(LItem.Status),
         LItem.Kind, LItem.Profile, LItem.Target]));
  finally
    LHistory.Free;
  end;
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

procedure TBoss4DGUIIDEManagementBackend.ConfigureTarget(
  const AProfileId, APlatform, AConfiguration: string);
begin
  FProfiles.ConfigureTarget(AProfileId, APlatform, AConfiguration);
end;

end.
