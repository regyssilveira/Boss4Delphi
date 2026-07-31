unit Boss4D.GUI.IDE.Timeline.Dialog;

interface

uses
  System.Classes,
  Vcl.Forms,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  Boss4D.GUI.IDE.Timeline;

type
  TBoss4DGUITimelineDialog = class(TForm)
  private
    FRows: TArray<TBoss4DGUITimelineRow>;
    FList: TListView;
    FDetail: TMemo;
    procedure SelectRow(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure Populate;
  public
    constructor CreateTimeline(AOwner: TComponent;
      const ARows: TArray<TBoss4DGUITimelineRow>);
    class procedure Execute(AOwner: TComponent;
      const ARows: TArray<TBoss4DGUITimelineRow>); static;
  end;

implementation

uses
  Vcl.Controls,
  Vcl.ExtCtrls;

constructor TBoss4DGUITimelineDialog.CreateTimeline(
  AOwner: TComponent; const ARows: TArray<TBoss4DGUITimelineRow>);
begin
  inherited CreateNew(AOwner);
  Caption := 'Historico de operacoes da IDE';
  Position := poOwnerFormCenter;
  Width := 980;
  Height := 560;
  BorderStyle := bsSizeable;
  FRows := Copy(ARows);

  FList := TListView.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.ViewStyle := vsReport;
  FList.ReadOnly := True;
  FList.RowSelect := True;
  FList.GridLines := True;
  FList.HideSelection := False;
  FList.OnSelectItem := SelectRow;
  with FList.Columns.Add do begin Caption := 'Inicio'; Width := 155; end;
  with FList.Columns.Add do begin Caption := 'Estado'; Width := 85; end;
  with FList.Columns.Add do begin Caption := 'Operacao'; Width := 145; end;
  with FList.Columns.Add do begin Caption := 'Perfil'; Width := 110; end;
  with FList.Columns.Add do begin Caption := 'Target'; Width := 190; end;
  with FList.Columns.Add do begin Caption := 'Desfazer'; Width := 75; end;

  var LSplitter := TSplitter.Create(Self);
  LSplitter.Parent := Self;
  LSplitter.Align := alBottom;

  FDetail := TMemo.Create(Self);
  FDetail.Parent := Self;
  FDetail.Align := alBottom;
  FDetail.Height := 155;
  FDetail.ReadOnly := True;
  FDetail.ScrollBars := ssVertical;
  FDetail.Text := 'Selecione uma operacao para ver os detalhes.';

  var LButtons := TPanel.Create(Self);
  LButtons.Parent := Self;
  LButtons.Align := alBottom;
  LButtons.Height := 46;
  LButtons.BevelOuter := bvNone;
  var LClose := TButton.Create(Self);
  LClose.Parent := LButtons;
  LClose.Caption := 'Fechar';
  LClose.ModalResult := mrClose;
  LClose.Default := True;
  LClose.Cancel := True;
  LClose.Align := alRight;
  LClose.Width := 90;

  Populate;
end;

class procedure TBoss4DGUITimelineDialog.Execute(AOwner: TComponent;
  const ARows: TArray<TBoss4DGUITimelineRow>);
begin
  var LDialog := TBoss4DGUITimelineDialog.CreateTimeline(AOwner, ARows);
  try
    LDialog.ShowModal;
  finally
    LDialog.Free;
  end;
end;

procedure TBoss4DGUITimelineDialog.Populate;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for var I := 0 to High(FRows) do
    begin
      var LItem := FList.Items.Add;
      LItem.Caption := FRows[I].StartedAt;
      LItem.SubItems.Add(FRows[I].Status);
      LItem.SubItems.Add(FRows[I].Kind);
      LItem.SubItems.Add(FRows[I].Profile);
      LItem.SubItems.Add(FRows[I].Target);
      if FRows[I].CanUndo then
        LItem.SubItems.Add('Sim')
      else
        LItem.SubItems.Add('Nao');
      LItem.Data := Pointer(I);
    end;
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TBoss4DGUITimelineDialog.SelectRow(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  if not Selected then
    Exit;
  var LIndex := NativeInt(Item.Data);
  if (LIndex < 0) or (LIndex > High(FRows)) then
    Exit;
  FDetail.Text := FRows[LIndex].Detail;
end;

end.
