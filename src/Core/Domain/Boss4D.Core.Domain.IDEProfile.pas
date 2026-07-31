unit Boss4D.Core.Domain.IDEProfile;

interface

uses
  System.Generics.Collections;

type
  TBoss4DIDEProfile = class
  private
    FSchemaVersion: Integer;
    FId: string;
    FName: string;
    FDescription: string;
    FCompiler: string;
    FExecutable: string;
    FRegistryBranch: string;
    FDefaultPlatform: string;
    FDefaultConfiguration: string;
    FInventoryPath: string;
    FPackages: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function Clone: TBoss4DIDEProfile;
    function RegistryRoot: string;
    property SchemaVersion: Integer read FSchemaVersion write FSchemaVersion;
    property Id: string read FId write FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Compiler: string read FCompiler write FCompiler;
    property Executable: string read FExecutable write FExecutable;
    property RegistryBranch: string read FRegistryBranch
      write FRegistryBranch;
    property DefaultPlatform: string read FDefaultPlatform
      write FDefaultPlatform;
    property DefaultConfiguration: string read FDefaultConfiguration
      write FDefaultConfiguration;
    property InventoryPath: string read FInventoryPath write FInventoryPath;
    property Packages: TList<string> read FPackages;
  end;

implementation

uses
  System.SysUtils;

constructor TBoss4DIDEProfile.Create;
begin
  inherited Create;
  FSchemaVersion := 1;
  FDefaultPlatform := 'Win32';
  FDefaultConfiguration := 'Release';
  FPackages := TList<string>.Create;
end;

destructor TBoss4DIDEProfile.Destroy;
begin
  FPackages.Free;
  inherited Destroy;
end;

function TBoss4DIDEProfile.Clone: TBoss4DIDEProfile;
begin
  Result := TBoss4DIDEProfile.Create;
  Result.SchemaVersion := FSchemaVersion;
  Result.Id := FId;
  Result.Name := FName;
  Result.Description := FDescription;
  Result.Compiler := FCompiler;
  Result.Executable := FExecutable;
  Result.RegistryBranch := FRegistryBranch;
  Result.DefaultPlatform := FDefaultPlatform;
  Result.DefaultConfiguration := FDefaultConfiguration;
  Result.InventoryPath := FInventoryPath;
  Result.Packages.AddRange(FPackages);
end;

function TBoss4DIDEProfile.RegistryRoot: string;
begin
  if SameText(FId, 'default') or SameText(FRegistryBranch, 'BDS') then
    Exit('Software\Embarcadero\BDS');
  Result := 'Software\Embarcadero\' + FRegistryBranch;
end;

end.
