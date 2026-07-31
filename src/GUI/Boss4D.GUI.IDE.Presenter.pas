unit Boss4D.GUI.IDE.Presenter;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy;

type
  IBoss4DIDEManagementBackend = interface
    ['{30C556C8-FEC5-4488-B8F0-93BADE0E30CB}']
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

  IBoss4DIDEManagementView = interface
    ['{4813DF90-50CF-4409-8789-A0251AE23885}']
    procedure ClearProfiles;
    procedure AddProfile(const AId, AName, ACompiler,
      ARegistryBranch: string; const APackageCount: Integer);
    procedure SelectProfile(const AId: string);
    procedure ClearPackages;
    procedure AddPackage(const AName, ARootDirectory: string;
      const AInstalled: Boolean);
    procedure ClearTargets;
    procedure AddTarget(const AIdentity: string);
    procedure ShowIDEStatus(const AMessage: string);
    procedure ShowIDEError(const AMessage: string);
  end;

  TBoss4DIDEManagementPresenter = class
  private
    FBackend: IBoss4DIDEManagementBackend;
    FView: IBoss4DIDEManagementView;
    FSelectedProfile: string;
    procedure LoadPackages;
  public
    constructor Create(const ABackend: IBoss4DIDEManagementBackend;
      const AView: IBoss4DIDEManagementView);
    procedure Refresh;
    procedure ChooseProfile(const AProfileId: string);
    procedure PreviewInstall(const APackage: string);
    procedure PreviewUninstall(const APackage: string);
    procedure Install(const APackage: string;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AIDEOpenPolicy: TBoss4DIDEOpenPolicy);
    procedure Uninstall(const APackage: string);
    procedure Repair;
    procedure Launch;
    procedure CreateProfile(const AName, ADescription, ACompiler,
      AExecutable: string);
    procedure CloneProfile(const AName: string);
    procedure RemoveProfile;
    property SelectedProfile: string read FSelectedProfile;
  end;

implementation

uses
  System.SysUtils;

constructor TBoss4DIDEManagementPresenter.Create(
  const ABackend: IBoss4DIDEManagementBackend;
  const AView: IBoss4DIDEManagementView);
begin
  inherited Create;
  if not Assigned(ABackend) then
    raise EArgumentNilException.Create('ABackend');
  if not Assigned(AView) then
    raise EArgumentNilException.Create('AView');
  FBackend := ABackend;
  FView := AView;
end;

procedure TBoss4DIDEManagementPresenter.Refresh;
begin
  try
    FView.ClearProfiles;
    var LProfiles := FBackend.Profiles;
    try
      for var LProfile in LProfiles do
        FView.AddProfile(LProfile.Id, LProfile.Name, LProfile.Compiler,
          LProfile.RegistryBranch, LProfile.PackageCount);
      if LProfiles.Count = 0 then
      begin
        FSelectedProfile := '';
        FView.ClearPackages;
        FView.ClearTargets;
        FView.ShowIDEStatus('Nenhum perfil IDE configurado.');
        Exit;
      end;
      var LFound := False;
      for var LProfile in LProfiles do
        if SameText(LProfile.Id, FSelectedProfile) then
        begin
          LFound := True;
          Break;
        end;
      if not LFound then
        FSelectedProfile := LProfiles[0].Id;
      FView.SelectProfile(FSelectedProfile);
      LoadPackages;
      FView.ShowIDEStatus(Format('%d perfil(is) carregado(s).',
        [LProfiles.Count]));
    finally
      LProfiles.Free;
    end;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.LoadPackages;
begin
  FView.ClearPackages;
  FView.ClearTargets;
  if FSelectedProfile.IsEmpty then
    Exit;
  var LPackages := FBackend.Packages(FSelectedProfile);
  try
    for var LPackage in LPackages do
      FView.AddPackage(LPackage.Name, LPackage.RootDirectory,
        LPackage.Installed);
  finally
    LPackages.Free;
  end;
end;

procedure TBoss4DIDEManagementPresenter.ChooseProfile(
  const AProfileId: string);
begin
  if AProfileId.Trim.IsEmpty then
    Exit;
  try
    FSelectedProfile := AProfileId.Trim;
    LoadPackages;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.PreviewInstall(
  const APackage: string);
begin
  try
    if FSelectedProfile.IsEmpty or APackage.Trim.IsEmpty then
      raise EArgumentException.Create(
        'Selecione um perfil e um package.');
    FView.ClearTargets;
    var LTargets := FBackend.InstallTargets(
      FSelectedProfile, APackage);
    try
      for var LTarget in LTargets do
        FView.AddTarget(LTarget.Identity);
      FView.ShowIDEStatus(Format(
        'Preview de instalacao: %d target(s).', [LTargets.Count]));
    finally
      LTargets.Free;
    end;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.PreviewUninstall(
  const APackage: string);
begin
  try
    if FSelectedProfile.IsEmpty or APackage.Trim.IsEmpty then
      raise EArgumentException.Create(
        'Selecione um perfil e um package.');
    FView.ClearTargets;
    var LTargets := FBackend.UninstallTargets(
      FSelectedProfile, APackage);
    try
      for var LTarget in LTargets do
        FView.AddTarget(LTarget.Identity);
      FView.ShowIDEStatus(Format(
        'Preview de remocao: %d target(s).', [LTargets.Count]));
    finally
      LTargets.Free;
    end;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.Install(const APackage: string;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AIDEOpenPolicy: TBoss4DIDEOpenPolicy);
begin
  try
    if FSelectedProfile.IsEmpty or APackage.Trim.IsEmpty then
      raise EArgumentException.Create(
        'Selecione um perfil e um package.');
    var LAffected := FBackend.Install(FSelectedProfile, APackage,
      AConflictPolicy, AIDEOpenPolicy);
    LoadPackages;
    FView.ShowIDEStatus(Format(
      'Instalacao concluida: %d registro(s) afetado(s).', [LAffected]));
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.Uninstall(
  const APackage: string);
begin
  try
    if FSelectedProfile.IsEmpty or APackage.Trim.IsEmpty then
      raise EArgumentException.Create(
        'Selecione um perfil e um package.');
    var LAffected := FBackend.Uninstall(FSelectedProfile, APackage);
    LoadPackages;
    FView.ShowIDEStatus(Format(
      'Remocao concluida: %d registro(s) afetado(s).', [LAffected]));
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.Repair;
begin
  try
    if FSelectedProfile.IsEmpty then
      raise EArgumentException.Create('Selecione um perfil.');
    var LAffected := FBackend.Repair(FSelectedProfile);
    LoadPackages;
    FView.ShowIDEStatus(Format(
      'Reparo concluido: %d registro(s) corrigido(s).', [LAffected]));
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.Launch;
begin
  try
    if FSelectedProfile.IsEmpty then
      raise EArgumentException.Create('Selecione um perfil.');
    FBackend.Launch(FSelectedProfile);
    FView.ShowIDEStatus('IDE iniciada com o perfil selecionado.');
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.CreateProfile(
  const AName, ADescription, ACompiler, AExecutable: string);
begin
  try
    FBackend.CreateProfile(AName, ADescription, ACompiler, AExecutable);
    FSelectedProfile := '';
    Refresh;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.CloneProfile(
  const AName: string);
begin
  try
    if FSelectedProfile.IsEmpty then
      raise EArgumentException.Create('Selecione um perfil.');
    FBackend.CloneProfile(FSelectedProfile, AName);
    FSelectedProfile := '';
    Refresh;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

procedure TBoss4DIDEManagementPresenter.RemoveProfile;
begin
  try
    if FSelectedProfile.IsEmpty then
      raise EArgumentException.Create('Selecione um perfil.');
    FBackend.RemoveProfile(FSelectedProfile);
    FSelectedProfile := '';
    Refresh;
  except
    on E: Exception do
      FView.ShowIDEError(E.Message);
  end;
end;

end.
