unit Boss4D.Core.Services.IDEDiscovery;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.BuildMatrix;

type
  TBoss4DIDEInstallation = class
  private
    FCompiler: string;
    FRootDirectory: string;
    FPlatforms: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property Compiler: string read FCompiler write FCompiler;
    property RootDirectory: string read FRootDirectory write FRootDirectory;
    property Platforms: TList<string> read FPlatforms;
  end;

  TBoss4DIDEInstallationList = class(
    TObjectList<TBoss4DIDEInstallation>);

  IBoss4DIDEDiscovery = interface
    ['{DB7DD7C6-0B70-4FF5-A249-49C9543479DF}']
    function Discover: TBoss4DIDEInstallationList;
  end;

  TBoss4DRegistryIDEDiscovery = class(TInterfacedObject,
    IBoss4DIDEDiscovery)
  private
    FRegistry: IBoss4DRegistryService;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService);
    function Discover: TBoss4DIDEInstallationList;
  end;

  TBoss4DMultiIDEPlanner = class
  public
    class function Plan(const APackage: TBoss4DPackage;
      const AInstallations: TBoss4DIDEInstallationList):
      TArray<TBoss4DBuildSelection>; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Defaults;

constructor TBoss4DIDEInstallation.Create;
begin
  inherited Create;
  FPlatforms := TList<string>.Create;
end;

destructor TBoss4DIDEInstallation.Destroy;
begin
  FPlatforms.Free;
  inherited Destroy;
end;

constructor TBoss4DRegistryIDEDiscovery.Create(
  const ARegistry: IBoss4DRegistryService);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  FRegistry := ARegistry;
end;

function TBoss4DRegistryIDEDiscovery.Discover:
  TBoss4DIDEInstallationList;
begin
  Result := TBoss4DIDEInstallationList.Create(True);
  try
    for var LVersion in FRegistry.GetInstalledDelphiVersions do
    begin
      var LRoot := FRegistry.GetDelphiPath(LVersion);
      if LRoot.Trim.IsEmpty or not TDirectory.Exists(LRoot) then
        Continue;
      var LInstallation := TBoss4DIDEInstallation.Create;
      LInstallation.Compiler := LVersion;
      LInstallation.RootDirectory := TPath.GetFullPath(LRoot);
      var LBin := TPath.Combine(LInstallation.RootDirectory, 'bin');
      if TFile.Exists(TPath.Combine(LBin, 'dcc32.exe')) then
        LInstallation.Platforms.Add('Win32');
      if TFile.Exists(TPath.Combine(LBin, 'dcc64.exe')) then
        LInstallation.Platforms.Add('Win64');
      if LInstallation.Platforms.Count > 0 then
        Result.Add(LInstallation)
      else
        LInstallation.Free;
    end;
    Result.Sort(TComparer<TBoss4DIDEInstallation>.Construct(
      function(const ALeft, ARight: TBoss4DIDEInstallation): Integer
      begin
        Result := CompareText(ALeft.Compiler, ARight.Compiler);
      end));
  except
    Result.Free;
    raise;
  end;
end;

class function TBoss4DMultiIDEPlanner.Plan(const APackage: TBoss4DPackage;
  const AInstallations: TBoss4DIDEInstallationList):
  TArray<TBoss4DBuildSelection>;
var
  LSelections: TList<TBoss4DBuildSelection>;
  LKeys: TDictionary<string, Boolean>;
begin
  if not Assigned(APackage) then
    raise EArgumentNilException.Create('APackage');
  if not Assigned(AInstallations) then
    raise EArgumentNilException.Create('AInstallations');
  LSelections := TList<TBoss4DBuildSelection>.Create;
  LKeys := TDictionary<string, Boolean>.Create;
  try
    for var LInstallation in AInstallations do
      if APackage.BuildMatrix.Compilers.Contains(LInstallation.Compiler) then
        for var LPlatform in LInstallation.Platforms do
          if APackage.BuildMatrix.Platforms.Contains(LPlatform) then
            for var LConfiguration in APackage.BuildMatrix.Configurations do
            begin
              var LKey := (LInstallation.Compiler + '|' + LPlatform + '|' +
                LConfiguration).ToLower;
              if not LKeys.ContainsKey(LKey) then
              begin
                LKeys.Add(LKey, True);
                LSelections.Add(TBoss4DBuildSelection.Create(
                  LInstallation.Compiler, LPlatform, LConfiguration));
              end;
            end;
    LSelections.Sort(TComparer<TBoss4DBuildSelection>.Construct(
      function(const ALeft, ARight: TBoss4DBuildSelection): Integer
      begin
        Result := CompareText(
          ALeft.Compiler + '|' + ALeft.Platform + '|' + ALeft.Configuration,
          ARight.Compiler + '|' + ARight.Platform + '|' +
          ARight.Configuration);
      end));
    Result := LSelections.ToArray;
  finally
    LKeys.Free;
    LSelections.Free;
  end;
end;

end.
