unit Boss4D.Tests.Mocks;

interface

uses
  System.Generics.Collections, Boss4D.Core.Ports, Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Lock, Boss4D.Core.Services.IDERegistration;

type
  { Mock para simulacao do cliente Git }
  TGitClientMock = class(TInterfacedObject, IBoss4DGitClient)
  private
    FTags: TDictionary<string, TArray<string>>;
    FCacheMap: TDictionary<string, string>;
    FFailCheckout: Boolean;
    FNetworkCallCount: Integer;
    FLastCheckoutVersion: string;
    FCommitSignatureValid: Boolean;
    FTagSignatureValid: Boolean;
    FSigner: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddMockTags(const ARepository: string; const ATags: TArray<string>);

    procedure CloneCache(const ADep: TBoss4DDependency; const ATargetDir: string);
    procedure UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
    function GetVersions(const ACacheDir: string): TArray<string>;
    function ResolveRevision(const ACacheDir: string; const AVersion: string): string;
    function VerifyCommit(const ACacheDir, ARevision: string;
      out ASigner: string): Boolean;
    function VerifyTag(const ACacheDir, ATag: string;
      out ASigner: string): Boolean;
    procedure Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
    property FailCheckout: Boolean read FFailCheckout write FFailCheckout;
    property NetworkCallCount: Integer read FNetworkCallCount;
    property LastCheckoutVersion: string read FLastCheckoutVersion;
    property CommitSignatureValid: Boolean read FCommitSignatureValid write FCommitSignatureValid;
    property TagSignatureValid: Boolean read FTagSignatureValid write FTagSignatureValid;
    property Signer: string read FSigner write FSigner;
  end;

  { Mock para simulacao do cliente HTTP }
  THttpClientMock = class(TInterfacedObject, IBoss4DHttpClient)
  private
    FResponses: TDictionary<string, string>;
    FResponseCodes: TDictionary<string, Integer>;
    FAuthorizedPostCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    function Get(const AURL: string; out AResponse: string): Integer;
    function PostJson(const AURL, ABody: string;
      out AResponse: string): Integer;
    function PostJsonAuthorized(const AURL, ABody, ABearerToken: string;
      out AResponse: string): Integer;
    function DownloadToFile(const AURL, ATargetPath: string): Integer;
    procedure AddResponse(const AURL, AResponse: string;
      const AStatusCode: Integer = 200);
    property AuthorizedPostCount: Integer read FAuthorizedPostCount;
  end;

  { Mock para simulacao do Compilador Delphi }
  TCompilerMock = class(TInterfacedObject, IBoss4DCompiler)
  private
    FCompiledProjects: TList<string>;
    FLastPlatform: string;
    FLastCompilerVersion: string;
    FLastConfiguration: string;
    FSearchPath: string;
    FGuard: TObject;
  public
    constructor Create;
    destructor Destroy; override;
    function Compile(const AProjectPath: string; const ADep: TBoss4DDependency;
      const ARootLock: TBoss4DLock): Boolean; overload;
    function Compile(const AProjectPath: string; const ADep: TBoss4DDependency;
      const ARootLock: TBoss4DLock; const APlatform,
      ACompilerVersion: string): Boolean; overload;
    function Compile(const AProjectPath: string; const ADep: TBoss4DDependency;
      const ARootLock: TBoss4DLock; const APlatform, ACompilerVersion,
      AConfiguration: string): Boolean; overload;
    function BuildSearchPath(const ADep: TBoss4DDependency; const APlatform: string = ''): string;
    property CompiledProjects: TList<string> read FCompiledProjects;
    property LastPlatform: string read FLastPlatform;
    property LastCompilerVersion: string read FLastCompilerVersion;
    property LastConfiguration: string read FLastConfiguration;
    property SearchPath: string read FSearchPath write FSearchPath;
  end;

  TIDERegistryStoreMock = class(TInterfacedObject,
    IBoss4DIDERegistryStore)
  private
    FValues: TDictionary<string, string>;
    FWriteCount: Integer;
    FFailOnWrite: Integer;
    function CompositeKey(const AKey, AName: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    function TryRead(const AKey, AName: string; out AValue: string): Boolean;
    procedure WriteValue(const AKey, AName, AValue: string);
    procedure DeleteValue(const AKey, AName: string);
    function ListValueNames(const AKey: string): TArray<string>;
    function GetValue(const AKey, AName: string): string;
    procedure SeedValue(const AKey, AName, AValue: string);
    property FailOnWrite: Integer read FFailOnWrite write FFailOnWrite;
    property WriteCount: Integer read FWriteCount;
  end;

  { Mock para simulacao do Registro do Windows }
  TRegistryMock = class(TInterfacedObject, IBoss4DRegistryService)
  private
    FPath22: string;
    FPath23: string;
    FPath37: string;
  public
    constructor Create;
    function GetInstalledDelphiVersions: TArray<string>;
    function GetDelphiPath(const AVersion: string): string;

    property Path22: string read FPath22 write FPath22;
    property Path23: string read FPath23 write FPath23;
    property Path37: string read FPath37 write FPath37;
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

{ TGitClientMock }

constructor TGitClientMock.Create;
begin
  inherited Create;
  FTags := TDictionary<string, TArray<string>>.Create;
  FCacheMap := TDictionary<string, string>.Create;
  FCommitSignatureValid := True;
  FTagSignatureValid := True;
  FSigner := 'trusted@example.com';
end;

destructor TGitClientMock.Destroy;
begin
  FCacheMap.Free;
  FTags.Free;
  inherited Destroy;
end;

procedure TGitClientMock.AddMockTags(const ARepository: string; const ATags: TArray<string>);
begin
  FTags.Add(ARepository.ToLower, ATags);
end;

procedure TGitClientMock.CloneCache(const ADep: TBoss4DDependency; const ATargetDir: string);
begin
  Inc(FNetworkCallCount);
  // Mapeia o nome final do diretorio (que e o hash) para o repositorio
  var LFolder := TPath.GetFileName(ATargetDir).ToLower;
  FCacheMap.AddOrSetValue(LFolder, ADep.Repository.ToLower);

  // Apenas simula a criacao do diretorio de cache local
  if not TDirectory.Exists(ATargetDir) then
    TDirectory.CreateDirectory(ATargetDir);

  if ADep.Repository.Contains('fake_tool') then
  begin
    TFile.WriteAllText(TPath.Combine(ATargetDir, 'fake_tool.dproj'), 'fake dproj content');
    TFile.WriteAllText(TPath.Combine(ATargetDir, 'fake_tool.exe'), 'fake exe content');
  end;
end;

procedure TGitClientMock.UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
begin
  Inc(FNetworkCallCount);
end;

function TGitClientMock.GetVersions(const ACacheDir: string): TArray<string>;
begin
  var LFolder := TPath.GetFileName(ACacheDir).ToLower;
  var LRepo: string;
  if FCacheMap.TryGetValue(LFolder, LRepo) then
  begin
    if FTags.ContainsKey(LRepo) then
      Exit(FTags[LRepo]);
  end;

  // Retorno padrao se nao mapeado
  Result := TArray<string>.Create('v1.0.0', 'v1.1.0', 'v2.0.0');
end;

function TGitClientMock.ResolveRevision(const ACacheDir: string; const AVersion: string): string;
begin
  Result := '0123456789abcdef0123456789abcdef01234567';
end;

procedure TGitClientMock.Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
begin
  FLastCheckoutVersion := AVersion;
  if TDirectory.Exists(ATargetDir) then
    TDirectory.Delete(ATargetDir, True);
  if FFailCheckout then
    raise Exception.Create('Falha de checkout simulada');
  // Simula a criacao do diretorio destino do modulo
  TDirectory.CreateDirectory(ATargetDir);

  // Cria um arquivo boss.json mockado na dependencia se nao existir
  var LRepository := '';
  FCacheMap.TryGetValue(TPath.GetFileName(ACacheDir).ToLower, LRepository);
  var LPkgPath := TPath.Combine(ATargetDir, 'boss.json');
  if not TFile.Exists(LPkgPath) then
  begin
    var LName := TPath.GetFileName(ATargetDir);
    if LRepository.Contains('invalid_project') then
      TFile.WriteAllText(LPkgPath, '{"name": "' + LName +
        '", "version": "1.0.0' +
        '", "projects": ["../escape.dproj"], "dependencies": {}}')
    else if LRepository.Contains('declared_projects') then
    begin
      TDirectory.CreateDirectory(TPath.Combine(ATargetDir, 'src'));
      TDirectory.CreateDirectory(TPath.Combine(ATargetDir, 'examples'));
      TFile.WriteAllText(TPath.Combine(ATargetDir, 'src\runtime.dproj'), 'runtime');
      TFile.WriteAllText(TPath.Combine(ATargetDir, 'src\runtime.lpk'), 'lazarus');
      TFile.WriteAllText(TPath.Combine(ATargetDir, 'examples\demo.dproj'), 'demo');
      TFile.WriteAllText(LPkgPath, '{"name": "' + LName +
        '", "version": "1.0.0' +
        '", "projects": ["src/runtime.dproj", "src/runtime.lpk"], "dependencies": {}}');
    end
    else
      TFile.WriteAllText(LPkgPath, '{"name": "' + LName + '", "version": "1.0.0", "dependencies": {}}');
  end;
end;

{ THttpClientMock }

constructor THttpClientMock.Create;
begin
  inherited Create;
  FResponses := TDictionary<string, string>.Create;
  FResponseCodes := TDictionary<string, Integer>.Create;
end;

destructor THttpClientMock.Destroy;
begin
  FResponseCodes.Free;
  FResponses.Free;
  inherited Destroy;
end;


function THttpClientMock.Get(const AURL: string; out AResponse: string): Integer;
begin
  AResponse := '';
  if FResponses.TryGetValue(AURL.ToLower, AResponse) then
  begin
    Exit(FResponseCodes[AURL.ToLower]);
  end;
  Result := 404; // Not Found padrao
end;

function THttpClientMock.DownloadToFile(const AURL,
  ATargetPath: string): Integer;
var
  LResponse: string;
begin
  Result := Get(AURL, LResponse);
  if (Result >= 200) and (Result < 300) then
    TFile.WriteAllBytes(ATargetPath, TEncoding.UTF8.GetBytes(LResponse));
end;

function TGitClientMock.VerifyCommit(const ACacheDir, ARevision: string;
  out ASigner: string): Boolean;
begin
  ASigner := FSigner;
  Result := FCommitSignatureValid;
end;

function TGitClientMock.VerifyTag(const ACacheDir, ATag: string;
  out ASigner: string): Boolean;
begin
  ASigner := FSigner;
  Result := FTagSignatureValid;
end;

procedure THttpClientMock.AddResponse(const AURL, AResponse: string;
  const AStatusCode: Integer);
begin
  FResponses.AddOrSetValue(AURL.ToLower, AResponse);
  FResponseCodes.AddOrSetValue(AURL.ToLower, AStatusCode);
end;

function THttpClientMock.PostJson(const AURL, ABody: string;
  out AResponse: string): Integer;
begin
  Result := Get(AURL, AResponse);
end;

function THttpClientMock.PostJsonAuthorized(const AURL, ABody,
  ABearerToken: string; out AResponse: string): Integer;
begin
  Inc(FAuthorizedPostCount);
  Result := Get(AURL, AResponse);
end;

{ TCompilerMock }

constructor TCompilerMock.Create;
begin
  inherited Create;
  FCompiledProjects := TList<string>.Create;
  FGuard := TObject.Create;
end;

destructor TCompilerMock.Destroy;
begin
  FGuard.Free;
  FCompiledProjects.Free;
  inherited Destroy;
end;

function TCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock): Boolean;
begin
  Result := Compile(AProjectPath, ADep, ARootLock, '', '', '');
end;

function TCompilerMock.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
  const APlatform, ACompilerVersion: string): Boolean;
begin
  Result := Compile(AProjectPath, ADep, ARootLock, APlatform,
    ACompilerVersion, '');
end;

function TCompilerMock.Compile(const AProjectPath: string; const ADep: TBoss4DDependency;
  const ARootLock: TBoss4DLock; const APlatform, ACompilerVersion,
  AConfiguration: string): Boolean;
begin
  TMonitor.Enter(FGuard);
  try
    FCompiledProjects.Add(AProjectPath);
    FLastPlatform := APlatform;
    FLastCompilerVersion := ACompilerVersion;
    FLastConfiguration := AConfiguration;
  finally
    TMonitor.Exit(FGuard);
  end;
  Result := True;
end;

function TCompilerMock.BuildSearchPath(const ADep: TBoss4DDependency; const APlatform: string = ''): string;
begin
  Result := FSearchPath;
end;

constructor TIDERegistryStoreMock.Create;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
end;

destructor TIDERegistryStoreMock.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

function TIDERegistryStoreMock.CompositeKey(const AKey,
  AName: string): string;
begin
  Result := AKey.ToLower + '|' + AName.ToLower;
end;

function TIDERegistryStoreMock.TryRead(const AKey, AName: string;
  out AValue: string): Boolean;
begin
  Result := FValues.TryGetValue(CompositeKey(AKey, AName), AValue);
end;

procedure TIDERegistryStoreMock.WriteValue(const AKey, AName,
  AValue: string);
begin
  Inc(FWriteCount);
  if (FFailOnWrite > 0) and (FWriteCount = FFailOnWrite) then
    raise Exception.Create('simulated registry write failure');
  FValues.AddOrSetValue(CompositeKey(AKey, AName), AValue);
end;

procedure TIDERegistryStoreMock.DeleteValue(const AKey, AName: string);
begin
  FValues.Remove(CompositeKey(AKey, AName));
end;

function TIDERegistryStoreMock.ListValueNames(
  const AKey: string): TArray<string>;
var
  LNames: TList<string>;
  LPrefix: string;
begin
  LNames := TList<string>.Create;
  try
    LPrefix := AKey.ToLower + '|';
    for var LCompositeKey in FValues.Keys do
      if LCompositeKey.StartsWith(LPrefix) then
        LNames.Add(LCompositeKey.Substring(LPrefix.Length));
    LNames.Sort;
    Result := LNames.ToArray;
  finally
    LNames.Free;
  end;
end;

function TIDERegistryStoreMock.GetValue(const AKey, AName: string): string;
begin
  if not TryRead(AKey, AName, Result) then
    Result := '';
end;

procedure TIDERegistryStoreMock.SeedValue(const AKey, AName,
  AValue: string);
begin
  FValues.AddOrSetValue(CompositeKey(AKey, AName), AValue);
end;

{ TRegistryMock }

constructor TRegistryMock.Create;
begin
  inherited Create;
  FPath22 := 'C:\Delphi11_Mock';
  FPath23 := 'C:\Delphi12_Mock';
  FPath37 := 'C:\Delphi13_Mock';
end;

function TRegistryMock.GetInstalledDelphiVersions: TArray<string>;
begin
  Result := TArray<string>.Create('22.0', '23.0', '37.0');
end;

function TRegistryMock.GetDelphiPath(const AVersion: string): string;
begin
  if AVersion = '22.0' then
    Result := FPath22
  else if AVersion = '23.0' then
    Result := FPath23
  else if AVersion = '37.0' then
    Result := FPath37
  else
    Result := '';
end;

end.
