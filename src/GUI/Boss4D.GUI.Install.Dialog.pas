unit Boss4D.GUI.Install.Dialog;

interface

uses
  System.Classes, Vcl.Forms, Vcl.StdCtrls,
  Boss4D.GUI.Install.Presenter;

type
  TBoss4DGUIInstallDialog = class(TForm)
  private
    FPackageName: string;
    FVersion: TComboBox;
    FCompiler: TComboBox;
    FPlatform: TComboBox;
    FFallback: TCheckBox;
    FPreview: TMemo;
    procedure SelectionChanged(Sender: TObject);
    procedure ConfirmClick(Sender: TObject);
    function BuildRequest: TBoss4DGUIInstallRequest;
    procedure AddLabel(const ACaption: string; const ATop: Integer);
  public
    constructor CreateWizard(AOwner: TComponent; const APackageName: string;
      const AVersions: TArray<string>);
    class function Execute(AOwner: TComponent; const APackageName: string;
      const AVersions: TArray<string>;
      out ARequest: TBoss4DGUIInstallRequest): Boolean; static;
  end;

implementation

uses
  System.SysUtils, Vcl.Controls, Vcl.Dialogs;

procedure TBoss4DGUIInstallDialog.AddLabel(const ACaption: string;
  const ATop: Integer);
begin
  var LLabel := TLabel.Create(Self);
  LLabel.Parent := Self;
  LLabel.Left := 16;
  LLabel.Top := ATop;
  LLabel.Caption := ACaption;
end;

constructor TBoss4DGUIInstallDialog.CreateWizard(AOwner: TComponent;
  const APackageName: string; const AVersions: TArray<string>);
begin
  inherited CreateNew(AOwner);
  FPackageName := APackageName;
  Caption := 'Instalacao guiada - ' + APackageName;
  BorderStyle := bsDialog;
  Position := poOwnerFormCenter;
  ClientWidth := 520;
  ClientHeight := 340;

  AddLabel('Versao', 18);
  FVersion := TComboBox.Create(Self);
  FVersion.Parent := Self;
  FVersion.SetBounds(16, 36, 220, 24);
  FVersion.Style := csDropDownList;
  for var LVersion in AVersions do
    FVersion.Items.Add(LVersion);
  if FVersion.Items.Count > 0 then
    FVersion.ItemIndex := 0;
  FVersion.OnChange := SelectionChanged;

  AddLabel('Compilador', 72);
  FCompiler := TComboBox.Create(Self);
  FCompiler.Parent := Self;
  FCompiler.SetBounds(16, 90, 220, 24);
  FCompiler.Style := csDropDownList;
  FCompiler.Items.AddStrings(['d13', 'd12', 'd11', 'd10.1', 'd10']);
  FCompiler.ItemIndex := 0;
  FCompiler.OnChange := SelectionChanged;

  AddLabel('Plataforma', 126);
  FPlatform := TComboBox.Create(Self);
  FPlatform.Parent := Self;
  FPlatform.SetBounds(16, 144, 220, 24);
  FPlatform.Style := csDropDownList;
  FPlatform.Items.AddStrings(['Win32', 'Win64', 'Linux64', 'OSXARM64']);
  FPlatform.ItemIndex := 0;
  FPlatform.OnChange := SelectionChanged;

  FFallback := TCheckBox.Create(Self);
  FFallback.Parent := Self;
  FFallback.SetBounds(16, 182, 470, 24);
  FFallback.Caption := 'Usar fontes Git se o artefato verificado falhar';
  FFallback.Checked := True;
  FFallback.OnClick := SelectionChanged;

  AddLabel('Comando CLI equivalente', 216);
  FPreview := TMemo.Create(Self);
  FPreview.Parent := Self;
  FPreview.SetBounds(16, 234, 488, 50);
  FPreview.ReadOnly := True;

  var LCancel := TButton.Create(Self);
  LCancel.Parent := Self;
  LCancel.SetBounds(334, 300, 80, 27);
  LCancel.Caption := 'Cancelar';
  LCancel.ModalResult := mrCancel;

  var LConfirm := TButton.Create(Self);
  LConfirm.Parent := Self;
  LConfirm.SetBounds(424, 300, 80, 27);
  LConfirm.Caption := 'Instalar';
  LConfirm.OnClick := ConfirmClick;
  DefaultMonitor := dmActiveForm;
  SelectionChanged(nil);
end;

function TBoss4DGUIInstallDialog.BuildRequest: TBoss4DGUIInstallRequest;
begin
  Result := Default(TBoss4DGUIInstallRequest);
  Result.PackageName := FPackageName;
  Result.Version := FVersion.Text;
  Result.Compiler := FCompiler.Text;
  Result.Platform := FPlatform.Text;
  Result.AllowSourceFallback := FFallback.Checked;
end;

procedure TBoss4DGUIInstallDialog.SelectionChanged(Sender: TObject);
begin
  try
    FPreview.Text :=
      TBoss4DGUIInstallPresenter.BuildEquivalentCommand(BuildRequest);
  except
    on E: EArgumentException do
      FPreview.Text := E.Message;
  end;
end;

procedure TBoss4DGUIInstallDialog.ConfirmClick(Sender: TObject);
begin
  try
    TBoss4DGUIInstallPresenter.Validate(BuildRequest);
    ModalResult := mrOk;
  except
    on E: EArgumentException do
      MessageDlg(E.Message, mtWarning, [mbOK], 0);
  end;
end;

class function TBoss4DGUIInstallDialog.Execute(AOwner: TComponent;
  const APackageName: string; const AVersions: TArray<string>;
  out ARequest: TBoss4DGUIInstallRequest): Boolean;
begin
  var LDialog := TBoss4DGUIInstallDialog.CreateWizard(AOwner,
    APackageName, AVersions);
  try
    Result := LDialog.ShowModal = mrOk;
    if Result then
      ARequest := LDialog.BuildRequest;
  finally
    LDialog.Free;
  end;
end;

end.
