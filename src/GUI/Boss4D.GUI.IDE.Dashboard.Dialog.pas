unit Boss4D.GUI.IDE.Dashboard.Dialog;

interface

uses
  System.Classes,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Boss4D.GUI.IDE.Dashboard;

type
  TBoss4DGUIProfileDashboardDialog = class(TForm)
  private
    FRows: TArray<TBoss4DGUIProfileDashboardRow>;
    FList: TListView;
    FDetail: TMemo;
    procedure CompareProfiles(Sender: TObject);
    procedure SelectProfile(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure Populate;
  public
    constructor CreateDashboard(AOwner: TComponent;
      const ARows: TArray<TBoss4DGUIProfileDashboardRow>);
    class function Execute(AOwner: TComponent;
      const ARows: TArray<TBoss4DGUIProfileDashboardRow>): string; static;
  end;

implementation

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Dialogs;

constructor TBoss4DGUIProfileDashboardDialog.CreateDashboard(
  AOwner: TComponent;
  const ARows: TArray<TBoss4DGUIProfileDashboardRow>);
begin
  inherited CreateNew(AOwner);
  Caption := 'Dashboard de perfis da IDE';
  Position := poOwnerFormCenter;
  Width := 1050;
  Height := 590;
  BorderStyle := bsSizeable;
  FRows := Copy(ARows);

  FList := TListView.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.ViewStyle := vsReport;
  FList.ReadOnly := True;
  FList.RowSelect := True;
  FList.MultiSelect := True;
  FList.GridLines := True;
  FList.HideSelection := False;
  FList.OnSelectItem := SelectProfile;
  with FList.Columns.Add do begin Caption := 'Perfil'; Width := 130; end;
  with FList.Columns.Add do begin Caption := 'Compilador'; Width := 90; end;
  with FList.Columns.Add do begin Caption := 'Target'; Width := 125; end;
  with FList.Columns.Add do begin Caption := 'Registry branch'; Width := 180; end;
  with FList.Columns.Add do begin Caption := 'Produtos'; Width := 70; end;
  with FList.Columns.Add do begin Caption := 'Saude'; Width := 100; end;
  with FList.Columns.Add do begin Caption := 'Drift'; Width := 240; end;

  var LSplitter := TSplitter.Create(Self);
  LSplitter.Parent := Self;
  LSplitter.Align := alBottom;

  FDetail := TMemo.Create(Self);
  FDetail.Parent := Self;
  FDetail.Align := alBottom;
  FDetail.Height := 165;
  FDetail.ReadOnly := True;
  FDetail.ScrollBars := ssVertical;
  FDetail.Text :=
    'Selecione um perfil para detalhes ou dois para comparar.';

  var LButtons := TPanel.Create(Self);
  LButtons.Parent := Self;
  LButtons.Align := alBottom;
  LButtons.Height := 46;
  LButtons.BevelOuter := bvNone;

  var LCompare := TButton.Create(Self);
  LCompare.Parent := LButtons;
  LCompare.Caption := 'Comparar selecionados';
  LCompare.SetBounds(8, 9, 155, 28);
  LCompare.OnClick := CompareProfiles;

  var LLaunch := TButton.Create(Self);
  LLaunch.Parent := LButtons;
  LLaunch.Caption := 'Abrir IDE';
  LLaunch.ModalResult := mrOk;
  LLaunch.SetBounds(845, 9, 90, 28);

  var LClose := TButton.Create(Self);
  LClose.Parent := LButtons;
  LClose.Caption := 'Fechar';
  LClose.ModalResult := mrCancel;
  LClose.Cancel := True;
  LClose.SetBounds(940, 9, 90, 28);

  Populate;
end;

class function TBoss4DGUIProfileDashboardDialog.Execute(
  AOwner: TComponent;
  const ARows: TArray<TBoss4DGUIProfileDashboardRow>): string;
begin
  Result := '';
  var LDialog := TBoss4DGUIProfileDashboardDialog.CreateDashboard(
    AOwner, ARows);
  try
    if (LDialog.ShowModal = mrOk) and
       Assigned(LDialog.FList.Selected) then
      Result := ARows[LDialog.FList.Selected.Index].Id;
  finally
    LDialog.Free;
  end;
end;

procedure TBoss4DGUIProfileDashboardDialog.Populate;
begin
  FList.Items.BeginUpdate;
  try
    for var I := 0 to High(FRows) do
    begin
      var LItem := FList.Items.Add;
      LItem.Caption := FRows[I].Name;
      LItem.SubItems.Add(FRows[I].Compiler);
      LItem.SubItems.Add(FRows[I].Platform + '/' +
        FRows[I].Configuration);
      LItem.SubItems.Add(FRows[I].RegistryBranch);
      LItem.SubItems.Add(Length(FRows[I].Packages).ToString);
      LItem.SubItems.Add(FRows[I].State);
      LItem.SubItems.Add(FRows[I].DriftSummary);
    end;
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TBoss4DGUIProfileDashboardDialog.SelectProfile(
  Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if not Selected then
    Exit;
  var LRow := FRows[Item.Index];
  FDetail.Text := Format(
    'Perfil: %s%sDescricao: %s%sCompilador: %s%sTarget: %s/%s%s' +
    'Registry branch: %s%sProdutos instalados: %s%sDrift: %s',
    [LRow.Name, sLineBreak, LRow.Description, sLineBreak,
     LRow.Compiler, sLineBreak, LRow.Platform, LRow.Configuration,
     sLineBreak, LRow.RegistryBranch, sLineBreak, LRow.PackageSummary,
     sLineBreak, LRow.DriftSummary]);
end;

procedure TBoss4DGUIProfileDashboardDialog.CompareProfiles(
  Sender: TObject);
begin
  var LSelected: TArray<Integer>;
  for var I := 0 to FList.Items.Count - 1 do
    if FList.Items[I].Selected then
    begin
      SetLength(LSelected, Length(LSelected) + 1);
      LSelected[High(LSelected)] := I;
    end;
  if Length(LSelected) <> 2 then
  begin
    MessageDlg('Selecione exatamente dois perfis para comparar.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  FDetail.Text := TBoss4DGUIProfileDashboard.Compare(
    FRows[LSelected[0]], FRows[LSelected[1]]).Summary;
end;

end.
