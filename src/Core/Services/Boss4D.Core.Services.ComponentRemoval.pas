unit Boss4D.Core.Services.ComponentRemoval;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Services.BuildInventory,
  Boss4D.Core.Services.IDEOperationResult;

type
  EBoss4DDependentComponents = class(Exception);

  TBoss4DProductUninstallHandler = reference to function(
    const AOwnerPackage: string): Integer;

  TBoss4DComponentRemovalPlan = class
  private
    FProducts: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property Products: TList<string> read FProducts;
  end;

  TBoss4DComponentRemovalService = class
  private
    FInventory: TBoss4DBuildInventory;
    FUninstall: TBoss4DProductUninstallHandler;
    FResultStore: IBoss4DIDEOperationResultStore;
    FProfile: string;
  public
    constructor Create(const AInventory: TBoss4DBuildInventory;
      const AUninstall: TBoss4DProductUninstallHandler;
      const AResultStore: IBoss4DIDEOperationResultStore = nil;
      const AProfile: string = 'default');
    function Plan(const AOwnerPackage: string;
      const ACascade: Boolean): TBoss4DComponentRemovalPlan;
    function Execute(const APlan: TBoss4DComponentRemovalPlan): Integer;
  end;

implementation

constructor TBoss4DComponentRemovalPlan.Create;
begin
  inherited Create;
  FProducts := TList<string>.Create;
end;

destructor TBoss4DComponentRemovalPlan.Destroy;
begin
  FProducts.Free;
  inherited Destroy;
end;

constructor TBoss4DComponentRemovalService.Create(
  const AInventory: TBoss4DBuildInventory;
  const AUninstall: TBoss4DProductUninstallHandler;
  const AResultStore: IBoss4DIDEOperationResultStore;
  const AProfile: string);
begin
  inherited Create;
  if not Assigned(AInventory) then
    raise EArgumentNilException.Create('AInventory');
  if not Assigned(AUninstall) then
    raise EArgumentNilException.Create('AUninstall');
  FInventory := AInventory;
  FUninstall := AUninstall;
  FResultStore := AResultStore;
  FProfile := AProfile.Trim;
  if FProfile.IsEmpty then
    raise EArgumentException.Create('O perfil da IDE e obrigatorio.');
end;

function TBoss4DComponentRemovalService.Plan(
  const AOwnerPackage: string;
  const ACascade: Boolean): TBoss4DComponentRemovalPlan;
begin
  if AOwnerPackage.Trim.IsEmpty then
    raise EArgumentException.Create(
      'O produto para remocao e obrigatorio.');
  if not FInventory.Contains(AOwnerPackage) then
    raise EBoss4DBuildInventoryError.CreateFmt(
      'Produto nao registrado no inventario: %s.', [AOwnerPackage]);
  var LDependents := FInventory.DependentsOf(AOwnerPackage);
  if (Length(LDependents) > 0) and not ACascade then
    raise EBoss4DDependentComponents.CreateFmt(
      'O produto %s possui dependentes: %s. Use cascade explicitamente.',
      [AOwnerPackage, string.Join(', ', LDependents)]);
  var LSelected := TList<string>.Create;
  try
    LSelected.Add(AOwnerPackage);
    if ACascade then
      LSelected.AddRange(LDependents);
    var LBuildOrder := FInventory.BuildOrder(LSelected.ToArray);
    Result := TBoss4DComponentRemovalPlan.Create;
    for var I := High(LBuildOrder) downto Low(LBuildOrder) do
      Result.Products.Add(LBuildOrder[I]);
  finally
    LSelected.Free;
  end;
end;

function TBoss4DComponentRemovalService.Execute(
  const APlan: TBoss4DComponentRemovalPlan): Integer;
begin
  if not Assigned(APlan) then
    raise EArgumentNilException.Create('APlan');
  if APlan.Products.Count = 0 then
    Exit(0);
  Result := 0;
  var LOperation := TBoss4DIDEOperationResult.New(
    'cascade-uninstall', FProfile,
    APlan.Products[APlan.Products.Count - 1]);
  try
    try
      for var LProduct in APlan.Products do
      begin
        Inc(Result, FUninstall(LProduct));
        LOperation.CompletedActions.Add('uninstall ' + LProduct);
      end;
      for var LProduct in APlan.Products do
        FInventory.RemovePackage(LProduct);
      FInventory.Save;
      LOperation.Complete;
      if Assigned(FResultStore) then
        FResultStore.Save(LOperation);
    except
      on E: Exception do
      begin
        LOperation.Fail(E.Message,
          'Execute doctor e repair no perfil ' + FProfile +
          ' e repita o uninstall em cascata. Acoes concluidas: ' +
          string.Join(', ', LOperation.CompletedActions.ToArray));
        if Assigned(FResultStore) then
          FResultStore.Save(LOperation);
        raise;
      end;
    end;
  finally
    LOperation.Free;
  end;
end;

end.
