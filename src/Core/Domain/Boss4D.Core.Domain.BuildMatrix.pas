unit Boss4D.Core.Domain.BuildMatrix;

interface

uses
  System.Generics.Collections;

type
  TBoss4DBuildProject = class
  private
    FPath: string;
    FKind: string;
    FDependsOn: TList<string>;
    FCompilers: TList<string>;
    FPlatforms: TList<string>;
    FConfigurations: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    property Path: string read FPath write FPath;
    property Kind: string read FKind write FKind;
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
    FProjectPath: string;
    FProjectKind: string;
    FCompiler: string;
    FPlatform: string;
    FConfiguration: string;
    FDependsOn: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function Identity: string;
    property PackageName: string read FPackageName write FPackageName;
    property ProjectPath: string read FProjectPath write FProjectPath;
    property ProjectKind: string read FProjectKind write FProjectKind;
    property Compiler: string read FCompiler write FCompiler;
    property Platform: string read FPlatform write FPlatform;
    property Configuration: string read FConfiguration write FConfiguration;
    property DependsOn: TList<string> read FDependsOn;
  end;

  TBoss4DBuildTargetList = class(TObjectList<TBoss4DBuildTarget>);

implementation

uses
  System.SysUtils;

constructor TBoss4DBuildProject.Create;
begin
  inherited Create;
  FKind := 'runtime';
  FDependsOn := TList<string>.Create;
  FCompilers := TList<string>.Create;
  FPlatforms := TList<string>.Create;
  FConfigurations := TList<string>.Create;
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

end.
