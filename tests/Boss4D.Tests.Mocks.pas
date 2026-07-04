unit Boss4D.Tests.Mocks;

interface

uses
  System.SysUtils, System.Generics.Collections, System.IOUtils, Boss4D.Core.Ports,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Package;

type
  { Mock para simulacao do cliente Git }
  TGitClientMock = class(TInterfacedObject, IBoss4DGitClient)
  private
    FTags: TDictionary<string, TArray<string>>;
    FCacheMap: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddMockTags(const ARepository: string; const ATags: TArray<string>);

    procedure CloneCache(const ADep: TBoss4DDependency; const ATargetDir: string);
    procedure UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
    function GetVersions(const ACacheDir: string): TArray<string>;
    procedure Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
  end;

  { Mock para simulacao do cliente HTTP }
  THttpClientMock = class(TInterfacedObject, IBoss4DHttpClient)
  private
    FResponses: TDictionary<string, string>;
    FResponseCodes: TDictionary<string, Integer>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddMockResponse(const AURL: string; const AResponse: string; const ACode: Integer = 200);

    function Get(const AURL: string; out AResponse: string): Integer;
  end;

  { Mock para simulacao do Compilador Delphi }
  TCompilerMock = class(TInterfacedObject, IBoss4DCompiler)
  public
    function Compile(const ADprojPath: string; const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock): Boolean;
    function BuildSearchPath(const ADep: TBoss4DDependency): string;
  end;

  { Mock para simulacao do Registro do Windows }
  TRegistryMock = class(TInterfacedObject, IBoss4DRegistryService)
  private
    FPath22: string;
    FPath23: string;
  public
    constructor Create;
    function GetInstalledDelphiVersions: TArray<string>;
    function GetDelphiPath(const AVersion: string): string;

    property Path22: string read FPath22 write FPath22;
    property Path23: string read FPath23 write FPath23;
  end;

implementation

{ TGitClientMock }

constructor TGitClientMock.Create;
begin
  inherited Create;
  FTags := TDictionary<string, TArray<string>>.Create;
  FCacheMap := TDictionary<string, string>.Create;
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
  // Mapeia o nome final do diretorio (que e o hash) para o repositorio
  var LFolder := TPath.GetFileName(ATargetDir).ToLower;
  FCacheMap.AddOrSetValue(LFolder, ADep.Repository.ToLower);

  // Apenas simula a criacao do diretorio de cache local
  if not TDirectory.Exists(ATargetDir) then
    TDirectory.CreateDirectory(ATargetDir);
end;

procedure TGitClientMock.UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
begin
  // No-op
end;

function TGitClientMock.GetVersions(const ACacheDir: string): TArray<string>;
begin
  var LFolder := TPath.GetFileName(ACacheDir).ToLower;
  var LRepo: string;
  
  if FCacheMap.TryGetValue(LFolder, LRepo) then
  begin
    if FTags.ContainsKey(LRepo) then
      Exit(FTags.Items[LRepo]);
  end;
  
  // Retorno padrao se nao mapeado
  Result := TArray<string>.Create('v1.0.0', 'v1.1.0', 'v2.0.0');
end;

procedure TGitClientMock.Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
begin
  // Simula a criacao do diretorio destino do modulo
  if not TDirectory.Exists(ATargetDir) then
    TDirectory.CreateDirectory(ATargetDir);

  // Cria um arquivo boss.json mockado na dependencia se nao existir
  var LPkgPath := TPath.Combine(ATargetDir, 'boss.json');
  if not TFile.Exists(LPkgPath) then
  begin
    var LName := TPath.GetFileName(ATargetDir);
    TFile.WriteAllText(LPkgPath, '{"name": "' + LName + '", "version": "' + AVersion + '", "dependencies": {}}');
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

procedure THttpClientMock.AddMockResponse(const AURL: string; const AResponse: string; const ACode: Integer = 200);
begin
  FResponses.Add(AURL.ToLower, AResponse);
  FResponseCodes.Add(AURL.ToLower, ACode);
end;

function THttpClientMock.Get(const AURL: string; out AResponse: string): Integer;
begin
  AResponse := '';
  if FResponses.TryGetValue(AURL.ToLower, AResponse) then
  begin
    Exit(FResponseCodes.Items[AURL.ToLower]);
  end;
  Result := 404; // Not Found padrao
end;

{ TCompilerMock }

function TCompilerMock.Compile(const ADprojPath: string; const ADep: TBoss4DDependency;
  const ARootLock: TBoss4DLock): Boolean;
begin
  // Apenas simula sucesso de compilacao
  Result := True;
end;

function TCompilerMock.BuildSearchPath(const ADep: TBoss4DDependency): string;
begin
  Result := '';
end;

{ TRegistryMock }

constructor TRegistryMock.Create;
begin
  inherited Create;
  FPath22 := 'C:\Delphi11_Mock';
  FPath23 := 'C:\Delphi12_Mock';
end;

function TRegistryMock.GetInstalledDelphiVersions: TArray<string>;
begin
  Result := TArray<string>.Create('22.0', '23.0');
end;

function TRegistryMock.GetDelphiPath(const AVersion: string): string;
begin
  if AVersion = '22.0' then
    Result := FPath22
  else if AVersion = '23.0' then
    Result := FPath23
  else
    Result := '';
end;

end.
