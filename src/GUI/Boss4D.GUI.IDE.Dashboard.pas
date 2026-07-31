unit Boss4D.GUI.IDE.Dashboard;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery;

type
  TBoss4DGUIProfileDashboardRow = record
    Id: string;
    Name: string;
    Description: string;
    Compiler: string;
    RegistryBranch: string;
    Platform: string;
    Configuration: string;
    Packages: TArray<string>;
    Drift: TArray<string>;
    function State: string;
    function PackageSummary: string;
    function DriftSummary: string;
  end;

  TBoss4DGUIProfileComparison = record
    LeftName: string;
    RightName: string;
    OnlyLeft: TArray<string>;
    Shared: TArray<string>;
    OnlyRight: TArray<string>;
    function Summary: string;
  end;

  TBoss4DGUIProfileDashboard = class
  public
    class function BuildRow(const AProfile: TBoss4DIDEProfileView;
      const APackages: TObjectList<TBoss4DIDEPackageView>;
      const ADrift: TArray<string>): TBoss4DGUIProfileDashboardRow; static;
    class function Compare(
      const ALeft, ARight: TBoss4DGUIProfileDashboardRow):
      TBoss4DGUIProfileComparison; static;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Defaults;

function JoinedOrNone(const AItems: TArray<string>): string;
begin
  if Length(AItems) = 0 then
    Exit('nenhum');
  Result := string.Join(', ', AItems);
end;

function ContainsText(const AItems: TArray<string>;
  const AValue: string): Boolean;
begin
  for var LItem in AItems do
    if SameText(LItem, AValue) then
      Exit(True);
  Result := False;
end;

function TBoss4DGUIProfileDashboardRow.State: string;
begin
  if Length(Drift) = 0 then
    Result := 'Saudavel'
  else
    Result := 'Com drift';
end;

function TBoss4DGUIProfileDashboardRow.PackageSummary: string;
begin
  Result := JoinedOrNone(Packages);
end;

function TBoss4DGUIProfileDashboardRow.DriftSummary: string;
begin
  Result := JoinedOrNone(Drift);
end;

function TBoss4DGUIProfileComparison.Summary: string;
begin
  Result := Format(
    '%s somente: %s%sCompartilhados: %s%s%s somente: %s',
    [LeftName, JoinedOrNone(OnlyLeft), sLineBreak,
     JoinedOrNone(Shared), sLineBreak, RightName,
     JoinedOrNone(OnlyRight)]);
end;

class function TBoss4DGUIProfileDashboard.BuildRow(
  const AProfile: TBoss4DIDEProfileView;
  const APackages: TObjectList<TBoss4DIDEPackageView>;
  const ADrift: TArray<string>): TBoss4DGUIProfileDashboardRow;
begin
  if not Assigned(AProfile) then
    raise EArgumentNilException.Create('AProfile');
  if not Assigned(APackages) then
    raise EArgumentNilException.Create('APackages');
  Result.Id := AProfile.Id;
  Result.Name := AProfile.Name;
  Result.Description := AProfile.Description;
  Result.Compiler := AProfile.Compiler;
  Result.RegistryBranch := AProfile.RegistryBranch;
  Result.Platform := AProfile.DefaultPlatform;
  Result.Configuration := AProfile.DefaultConfiguration;
  var LInstalled := TList<string>.Create;
  try
    for var LPackage in APackages do
      if LPackage.Installed then
        LInstalled.Add(LPackage.Name);
    LInstalled.Sort(TComparer<string>.Default);
    Result.Packages := LInstalled.ToArray;
  finally
    LInstalled.Free;
  end;
  Result.Drift := Copy(ADrift);
end;

class function TBoss4DGUIProfileDashboard.Compare(
  const ALeft, ARight: TBoss4DGUIProfileDashboardRow):
  TBoss4DGUIProfileComparison;
begin
  Result.LeftName := ALeft.Name;
  Result.RightName := ARight.Name;
  var LOnlyLeft := TList<string>.Create;
  var LShared := TList<string>.Create;
  var LOnlyRight := TList<string>.Create;
  try
    for var LPackage in ALeft.Packages do
      if ContainsText(ARight.Packages, LPackage) then
        LShared.Add(LPackage)
      else
        LOnlyLeft.Add(LPackage);
    for var LPackage in ARight.Packages do
      if not ContainsText(ALeft.Packages, LPackage) then
        LOnlyRight.Add(LPackage);
    LOnlyLeft.Sort;
    LShared.Sort;
    LOnlyRight.Sort;
    Result.OnlyLeft := LOnlyLeft.ToArray;
    Result.Shared := LShared.ToArray;
    Result.OnlyRight := LOnlyRight.ToArray;
  finally
    LOnlyRight.Free;
    LShared.Free;
    LOnlyLeft.Free;
  end;
end;

end.
