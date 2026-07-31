unit Boss4D.Core.Services.ComponentRemoval;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Services.BuildInventory;

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
  public
    constructor Create(const AInventory: TBoss4DBuildInventory;
      const AUninstall: TBoss4DProductUninstallHandler);
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
  const AUninstall: TBoss4DProductUninstallHandler);
begin
  inherited Create;
  if not Assigned(AInventory) then
    raise EArgumentNilException.Create('AInventory');
  if not Assigned(AUninstall) then
    raise EArgumentNilException.Create('AUninstall');
  FInventory := AInventory;
  FUninstall := AUninstall;
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
  Result := 0;
  for var LProduct in APlan.Products do
    Inc(Result, FUninstall(LProduct));
  for var LProduct in APlan.Products do
    FInventory.RemovePackage(LProduct);
  if APlan.Products.Count > 0 then
    FInventory.Save;
end;

end.
