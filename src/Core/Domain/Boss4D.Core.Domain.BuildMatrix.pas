unit Boss4D.Core.Domain.BuildMatrix;

interface

uses
  System.Generics.Collections;

type
  TBoss4DBuildProjectRole = (RuntimePackage, DesignPackage, Application,
    Tool, Binary);

  TBoss4DBuildProjectRoles = class
  public
    class function Parse(const AValue: string): TBoss4DBuildProjectRole;
      static;
    class function NameOf(const AValue: TBoss4DBuildProjectRole): string;
      static;
  end;

  TBoss4DBuildProject = class
  private
    FPath: string;
    FPackageName: string;
    FKind: string;
    FDependsOn: TList<string>;
    FCompilers: TList<string>;
    FPlatforms: TList<string>;
    FConfigurations: TList<string>;
    function GetRole: TBoss4DBuildProjectRole;
    procedure SetRole(const AValue: TBoss4DBuildProjectRole);
  public
    constructor Create;
    destructor Destroy; override;
    property Path: string read FPath write FPath;
    property PackageName: string read FPackageName write FPackageName;
    property Kind: string read FKind write FKind;
    property Role: TBoss4DBuildProjectRole read GetRole write SetRole;
    property DependsOn: TList<string> read FDependsOn;
    property Compilers: TList<string> read FCompilers;
    property Platforms: TList<string> read FPlatforms;
    property Configurations: TList<string> read FConfigurations;
  end;

  TBoss4DBuildMatrix = class
  private
    FCompilers: TList<string>;
    FPlatforms: TList<string>;
    FConfigurations: TList<string>;
    FProjects: TObjectList<TBoss4DBuildProject>;
    FDefaultCompiler: string;
    FDefaultPlatform: string;
    FDefaultConfiguration: string;
  public
    constructor Create;
    destructor Destroy; override;
    function IsDeclared: Boolean;
    property Compilers: TList<string> read FCompilers;
    property Platforms: TList<string> read FPlatforms;
    property Configurations: TList<string> read FConfigurations;
    property Projects: TObjectList<TBoss4DBuildProject> read FProjects;
    property DefaultCompiler: string read FDefaultCompiler
      write FDefaultCompiler;
    property DefaultPlatform: string read FDefaultPlatform
      write FDefaultPlatform;
    property DefaultConfiguration: string read FDefaultConfiguration
      write FDefaultConfiguration;
  end;

  TBoss4DBuildSelection = record
  private
    FCompiler: string;
    FPlatform: string;
    FConfiguration: string;
    FCompilerAll: Boolean;
    FPlatformAll: Boolean;
    FConfigurationAll: Boolean;
    function GetAllTargets: Boolean;
  public
    constructor Create(const ACompiler, APlatform,
      AConfiguration: string); overload;
    constructor Create(const ACompiler, APlatform, AConfiguration: string;
      const ACompilerAll, APlatformAll, AConfigurationAll: Boolean); overload;
    class function All: TBoss4DBuildSelection; static;
    class function Default: TBoss4DBuildSelection; static;
    property Compiler: string read FCompiler;
    property Platform: string read FPlatform;
    property Configuration: string read FConfiguration;
    property CompilerAll: Boolean read FCompilerAll;
    property PlatformAll: Boolean read FPlatformAll;
    property ConfigurationAll: Boolean read FConfigurationAll;
    property AllTargets: Boolean read GetAllTargets;
  end;

  TBoss4DBuildTarget = class
  private
    FPackageName: string;
    FComponentName: string;
    FProjectPath: string;
    FProjectKind: string;
    FCompiler: string;
    FPlatform: string;
    FConfiguration: string;
    FDependsOn: TList<string>;
    function GetRole: TBoss4DBuildProjectRole;
    procedure SetRole(const AValue: TBoss4DBuildProjectRole);
  public
    constructor Create;
    destructor Destroy; override;
    function Identity: string;
    property PackageName: string read FPackageName write FPackageName;
    property ComponentName: string read FComponentName write FComponentName;
    property ProjectPath: string read FProjectPath write FProjectPath;
    property ProjectKind: string read FProjectKind write FProjectKind;
    property Role: TBoss4DBuildProjectRole read GetRole write SetRole;
    property Compiler: string read FCompiler write FCompiler;
    property Platform: string read FPlatform write FPlatform;
    property Configuration: string read FConfiguration write FConfiguration;
    property DependsOn: TList<string> read FDependsOn;
  end;

  TBoss4DBuildTargetList = class(TObjectList<TBoss4DBuildTarget>);

  TBoss4DComponentPackageIdentity = record
  private
    FOwnerPackage: string;
    FPackageName: string;
    FRole: TBoss4DBuildProjectRole;
    FCompiler: string;
    FPlatform: string;
    FConfiguration: string;
    FProfile: string;
  public
    class function FromTarget(const ATarget: TBoss4DBuildTarget;
      const AProfile: string = 'default'):
      TBoss4DComponentPackageIdentity; static;
    function Key: string;
    property OwnerPackage: string read FOwnerPackage;
    property PackageName: string read FPackageName;
    property Role: TBoss4DBuildProjectRole read FRole;
    property Compiler: string read FCompiler;
    property Platform: string read FPlatform;
    property Configuration: string read FConfiguration;
    property Profile: string read FProfile;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

class function TBoss4DBuildProjectRoles.Parse(
  const AValue: string): TBoss4DBuildProjectRole;
begin
  if SameText(AValue, 'runtime') then
    Exit(TBoss4DBuildProjectRole.RuntimePackage);
  if SameText(AValue, 'design') then
    Exit(TBoss4DBuildProjectRole.DesignPackage);
  if SameText(AValue, 'application') then
    Exit(TBoss4DBuildProjectRole.Application);
  if SameText(AValue, 'tool') then
    Exit(TBoss4DBuildProjectRole.Tool);
  if SameText(AValue, 'binary') then
    Exit(TBoss4DBuildProjectRole.Binary);
  raise EArgumentException.CreateFmt(
    'Tipo de projeto nao suportado: %s.', [AValue]);
end;

class function TBoss4DBuildProjectRoles.NameOf(
  const AValue: TBoss4DBuildProjectRole): string;
begin
  case AValue of
    TBoss4DBuildProjectRole.DesignPackage:
      Result := 'design';
    TBoss4DBuildProjectRole.Application:
      Result := 'application';
    TBoss4DBuildProjectRole.Tool:
      Result := 'tool';
    TBoss4DBuildProjectRole.Binary:
      Result := 'binary';
  else
    Result := 'runtime';
  end;
end;

constructor TBoss4DBuildProject.Create;
begin
  inherited Create;
  FKind := 'runtime';
  FDependsOn := TList<string>.Create;
  FCompilers := TList<string>.Create;
  FPlatforms := TList<string>.Create;
  FConfigurations := TList<string>.Create;
end;

function TBoss4DBuildProject.GetRole: TBoss4DBuildProjectRole;
begin
  Result := TBoss4DBuildProjectRoles.Parse(FKind);
end;

procedure TBoss4DBuildProject.SetRole(
  const AValue: TBoss4DBuildProjectRole);
begin
  FKind := TBoss4DBuildProjectRoles.NameOf(AValue);
end;

destructor TBoss4DBuildProject.Destroy;
begin
  FConfigurations.Free;
  FPlatforms.Free;
  FCompilers.Free;
  FDependsOn.Free;
  inherited Destroy;
end;

constructor TBoss4DBuildMatrix.Create;
begin
  inherited Create;
  FCompilers := TList<string>.Create;
  FPlatforms := TList<string>.Create;
  FConfigurations := TList<string>.Create;
  FProjects := TObjectList<TBoss4DBuildProject>.Create(True);
end;

destructor TBoss4DBuildMatrix.Destroy;
begin
  FProjects.Free;
  FConfigurations.Free;
  FPlatforms.Free;
  FCompilers.Free;
  inherited Destroy;
end;

function TBoss4DBuildMatrix.IsDeclared: Boolean;
begin
  Result := (FCompilers.Count > 0) or (FPlatforms.Count > 0) or
    (FConfigurations.Count > 0) or (FProjects.Count > 0);
end;

constructor TBoss4DBuildSelection.Create(const ACompiler, APlatform,
  AConfiguration: string);
begin
  Create(ACompiler, APlatform, AConfiguration, False, False, False);
end;

constructor TBoss4DBuildSelection.Create(const ACompiler, APlatform,
  AConfiguration: string; const ACompilerAll, APlatformAll,
  AConfigurationAll: Boolean);
begin
  FCompiler := ACompiler;
  FPlatform := APlatform;
  FConfiguration := AConfiguration;
  FCompilerAll := ACompilerAll;
  FPlatformAll := APlatformAll;
  FConfigurationAll := AConfigurationAll;
end;

class function TBoss4DBuildSelection.All: TBoss4DBuildSelection;
begin
  Result := System.Default(TBoss4DBuildSelection);
  Result.FCompilerAll := True;
  Result.FPlatformAll := True;
  Result.FConfigurationAll := True;
end;

class function TBoss4DBuildSelection.Default: TBoss4DBuildSelection;
begin
  Result := System.Default(TBoss4DBuildSelection);
end;

function TBoss4DBuildSelection.GetAllTargets: Boolean;
begin
  Result := FCompilerAll and FPlatformAll and FConfigurationAll;
end;

constructor TBoss4DBuildTarget.Create;
begin
  inherited Create;
  FDependsOn := TList<string>.Create;
end;

function TBoss4DBuildTarget.GetRole: TBoss4DBuildProjectRole;
begin
  Result := TBoss4DBuildProjectRoles.Parse(FProjectKind);
end;

procedure TBoss4DBuildTarget.SetRole(
  const AValue: TBoss4DBuildProjectRole);
begin
  FProjectKind := TBoss4DBuildProjectRoles.NameOf(AValue);
end;

destructor TBoss4DBuildTarget.Destroy;
begin
  FDependsOn.Free;
  inherited Destroy;
end;

function TBoss4DBuildTarget.Identity: string;
begin
  Result := FPackageName + '|' + FProjectPath + '|' + FCompiler + '|' +
    FPlatform + '|' + FConfiguration;
end;

class function TBoss4DComponentPackageIdentity.FromTarget(
  const ATarget: TBoss4DBuildTarget;
  const AProfile: string): TBoss4DComponentPackageIdentity;
begin
  if not Assigned(ATarget) then
    raise EArgumentNilException.Create('ATarget');
  Result := Default(TBoss4DComponentPackageIdentity);
  Result.FOwnerPackage := ATarget.PackageName.Trim;
  Result.FPackageName := ATarget.ComponentName.Trim;
  if Result.FPackageName.IsEmpty then
    Result.FPackageName :=
      TPath.GetFileNameWithoutExtension(ATarget.ProjectPath);
  Result.FRole := ATarget.Role;
  Result.FCompiler := ATarget.Compiler.Trim;
  Result.FPlatform := ATarget.Platform.Trim;
  Result.FConfiguration := ATarget.Configuration.Trim;
  Result.FProfile := AProfile.Trim;
  if Result.FProfile.IsEmpty then
    Result.FProfile := 'default';
end;

function TBoss4DComponentPackageIdentity.Key: string;
begin
  Result := LowerCase(FOwnerPackage + '|' + FPackageName + '|' +
    TBoss4DBuildProjectRoles.NameOf(FRole) + '|' + FCompiler + '|' +
    FPlatform + '|' + FConfiguration + '|' + FProfile);
end;

end.
