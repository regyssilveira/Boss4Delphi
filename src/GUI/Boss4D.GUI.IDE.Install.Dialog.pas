unit Boss4D.GUI.IDE.Install.Dialog;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.StdCtrls,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.GUI.IDE.Presenter,
  Boss4D.GUI.IDE.Install.Presenter;

type
  TBoss4DGUIIDEInstallDialog = class(TForm)
  private
    FBackend: IBoss4DIDEManagementBackend;
    FProfileIds: TStringList;
    FProfile: TComboBox;
    FPackage: TComboBox;
    FConflictPolicy: TComboBox;
    FOpenPolicy: TComboBox;
    FPreview: TMemo;
    FConfirm: TButton;
    FRequest: TBoss4DGUIIDEInstallRequest;
    procedure AddLabel(const ACaption: string; const ALeft,
      ATop: Integer);
    procedure LoadProfiles(const ASelectedProfile: string);
    procedure LoadPackages(const ASelectedPackage: string = '');
    procedure SelectionChanged(Sender: TObject);
    procedure ConfirmClick(Sender: TObject);
    function SelectedProfileId: string;
    function BuildRequest: TBoss4DGUIIDEInstallRequest;
  public
    constructor CreateWizard(AOwner: TComponent;
      const ABackend: IBoss4DIDEManagementBackend;
      const ASelectedProfile, ASelectedPackage: string;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AOpenPolicy: TBoss4DIDEOpenPolicy);
    destructor Destroy; override;
    class function Execute(AOwner: TComponent;
      const ABackend: IBoss4DIDEManagementBackend;
      const ASelectedProfile, ASelectedPackage: string;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AOpenPolicy: TBoss4DIDEOpenPolicy;
      out ARequest: TBoss4DGUIIDEInstallRequest): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.Dialogs;

procedure TBoss4DGUIIDEInstallDialog.AddLabel(const ACaption: string;
  const ALeft, ATop: Integer);
begin
  var LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := ALeft;
  LLabel.Top := ATop;
  LLabel.Caption := ACaption;
end;

constructor TBoss4DGUIIDEInstallDialog.CreateWizard(AOwner: TComponent;
  const ABackend: IBoss4DIDEManagementBackend;
  const ASelectedProfile, ASelectedPackage: string;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AOpenPolicy: TBoss4DIDEOpenPolicy);
begin
  inherited CreateNew(AOwner);
  if not Assigned(ABackend) then
    raise EArgumentNilException.Create('ABackend');
  FBackend := ABackend;
  FProfileIds := TStringList.Create;
  Caption := 'Instalacao guiada de componente na IDE';
  BorderStyle := bsSizeable;
  Position := poOwnerFormCenter;
  ClientWidth := 780;
  ClientHeight := 590;
  Constraints.MinWidth := 680;
  Constraints.MinHeight := 520;

  AddLabel('Perfil isolado', 16, 17);
  FProfile := TComboBox.Create(Self);
  FProfile.Parent := Self;
  FProfile.SetBounds(16, 35, 360, 24);
  FProfile.Style := csDropDownList;
  FProfile.OnChange := SelectionChanged;

  AddLabel('Package', 396, 17);
  FPackage := TComboBox.Create(Self);
  FPackage.Parent := Self;
  FPackage.SetBounds(396, 35, 368, 24);
  FPackage.Style := csDropDownList;
  FPackage.OnChange := SelectionChanged;

  AddLabel('Politica de conflito', 16, 75);
  FConflictPolicy := TComboBox.Create(Self);
  FConflictPolicy.Parent := Self;
  FConflictPolicy.SetBounds(16, 93, 360, 24);
  FConflictPolicy.Style := csDropDownList;
  FConflictPolicy.Items.AddStrings([
    'Bloquear', 'Avisar e continuar', 'Adotar registro existente',
    'Substituir registro']);
  FConflictPolicy.ItemIndex := Ord(AConflictPolicy);
  FConflictPolicy.OnChange := SelectionChanged;

  AddLabel('Se a IDE estiver aberta', 396, 75);
  FOpenPolicy := TComboBox.Create(Self);
  FOpenPolicy.Parent := Self;
  FOpenPolicy.SetBounds(396, 93, 368, 24);
  FOpenPolicy.Style := csDropDownList;
  FOpenPolicy.Items.AddStrings([
    'Bloquear', 'Adiar alteracoes de registro',
    'Aplicar mesmo com a IDE aberta']);
  FOpenPolicy.ItemIndex := Ord(AOpenPolicy);
  FOpenPolicy.OnChange := SelectionChanged;

  AddLabel('Preview completo antes da confirmacao', 16, 134);
  FPreview := TMemo.Create(Self);
  FPreview.Parent := Self;
  FPreview.SetBounds(16, 153, 748, 374);
  FPreview.Anchors := [akLeft, akTop, akRight, akBottom];
  FPreview.ReadOnly := True;
  FPreview.ScrollBars := ssBoth;
  FPreview.WordWrap := False;

  var LCancel := TButton.Create(Self);
  LCancel.Parent := Self;
  LCancel.Caption := 'Cancelar';
  LCancel.ModalResult := mrCancel;
  LCancel.Cancel := True;
  LCancel.SetBounds(580, 544, 88, 29);
  LCancel.Anchors := [akRight, akBottom];

  FConfirm := TButton.Create(Self);
  FConfirm.Parent := Self;
  FConfirm.Caption := 'Instalar';
  FConfirm.Default := True;
  FConfirm.SetBounds(676, 544, 88, 29);
  FConfirm.Anchors := [akRight, akBottom];
  FConfirm.OnClick := ConfirmClick;

  LoadProfiles(ASelectedProfile);
  LoadPackages(ASelectedPackage);
  SelectionChanged(nil);
end;

destructor TBoss4DGUIIDEInstallDialog.Destroy;
begin
  FProfileIds.Free;
  inherited Destroy;
end;

procedure TBoss4DGUIIDEInstallDialog.LoadProfiles(
  const ASelectedProfile: string);
begin
  FProfile.Items.Clear;
  FProfileIds.Clear;
  var LProfiles := FBackend.Profiles;
  try
    for var LProfile in LProfiles do
    begin
      FProfile.Items.Add(LProfile.Name + ' - Delphi ' +
        LProfile.Compiler + ' [' + LProfile.RegistryBranch + ']');
      FProfileIds.Add(LProfile.Id);
      if SameText(LProfile.Id, ASelectedProfile) then
        FProfile.ItemIndex := FProfile.Items.Count - 1;
    end;
  finally
    LProfiles.Free;
  end;
  if (FProfile.ItemIndex < 0) and (FProfile.Items.Count > 0) then
    FProfile.ItemIndex := 0;
end;

function TBoss4DGUIIDEInstallDialog.SelectedProfileId: string;
begin
  if (FProfile.ItemIndex >= 0) and
     (FProfile.ItemIndex < FProfileIds.Count) then
    Result := FProfileIds[FProfile.ItemIndex]
  else
    Result := '';
end;

procedure TBoss4DGUIIDEInstallDialog.LoadPackages(
  const ASelectedPackage: string);
begin
  FPackage.Items.Clear;
  if SelectedProfileId.IsEmpty then
    Exit;
  var LPackages := FBackend.Packages(SelectedProfileId);
  try
    for var LPackage in LPackages do
    begin
      FPackage.Items.Add(LPackage.Name);
      if SameText(LPackage.Name, ASelectedPackage) then
        FPackage.ItemIndex := FPackage.Items.Count - 1;
    end;
  finally
    LPackages.Free;
  end;
  if (FPackage.ItemIndex < 0) and (FPackage.Items.Count > 0) then
    FPackage.ItemIndex := 0;
end;

function TBoss4DGUIIDEInstallDialog.BuildRequest:
  TBoss4DGUIIDEInstallRequest;
begin
  if SelectedProfileId.IsEmpty then
    raise EArgumentException.Create('Selecione um perfil IDE.');
  if Trim(FPackage.Text) = '' then
    raise EArgumentException.Create('Selecione um package.');

  var LProfiles := FBackend.Profiles;
  try
    var LSelected: TBoss4DIDEProfileView := nil;
    for var LProfile in LProfiles do
      if SameText(LProfile.Id, SelectedProfileId) then
      begin
        LSelected := LProfile;
        Break;
      end;
    if not Assigned(LSelected) then
      raise EArgumentException.Create('O perfil selecionado nao existe.');
    var LTargets := FBackend.InstallTargets(
      LSelected.Id, FPackage.Text);
    try
      Result := TBoss4DGUIIDEInstallPresenter.BuildRequest(
        LSelected, FPackage.Text, LTargets,
        TBoss4DIDEConflictPolicy(FConflictPolicy.ItemIndex),
        TBoss4DIDEOpenPolicy(FOpenPolicy.ItemIndex));
    finally
      LTargets.Free;
    end;
  finally
    LProfiles.Free;
  end;
end;

procedure TBoss4DGUIIDEInstallDialog.SelectionChanged(Sender: TObject);
begin
  if Sender = FProfile then
    LoadPackages;
  try
    FRequest := BuildRequest;
    FPreview.Text := FRequest.Summary;
    FConfirm.Enabled := True;
  except
    on E: Exception do
    begin
      FPreview.Text := E.Message;
      FConfirm.Enabled := False;
    end;
  end;
end;

procedure TBoss4DGUIIDEInstallDialog.ConfirmClick(Sender: TObject);
begin
  try
    FRequest := BuildRequest;
    ModalResult := mrOk;
  except
    on E: Exception do
      MessageDlg(E.Message, mtWarning, [mbOK], 0);
  end;
end;

class function TBoss4DGUIIDEInstallDialog.Execute(AOwner: TComponent;
  const ABackend: IBoss4DIDEManagementBackend;
  const ASelectedProfile, ASelectedPackage: string;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AOpenPolicy: TBoss4DIDEOpenPolicy;
  out ARequest: TBoss4DGUIIDEInstallRequest): Boolean;
begin
  var LDialog := TBoss4DGUIIDEInstallDialog.CreateWizard(AOwner,
    ABackend, ASelectedProfile, ASelectedPackage, AConflictPolicy,
    AOpenPolicy);
  try
    Result := LDialog.ShowModal = mrOk;
    if Result then
      ARequest := LDialog.FRequest;
  finally
    LDialog.Free;
  end;
end;

end.
