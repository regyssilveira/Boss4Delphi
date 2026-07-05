unit Boss4D.Core.Domain.Dependency;

interface


type
  { Representa uma dependencia individual do projeto }
  TBoss4DDependency = class
  private
    FRepository: string;
    FVersion: string;
    FUseSSH: Boolean;

    function GetSSHUrl: string;
  public
    constructor Create(const ARepository: string; const AVersion: string; const AUseSSH: Boolean = False);
    function HashName: string;
    function Name: string;
    function GetURL: string;
    function GetKey: string;

    class function Parse(const ARepo: string; const AVersionInfo: string): TBoss4DDependency; static;
    class function ParseCommandLine(const ADepStr: string): TBoss4DDependency; static;

    property Repository: string read FRepository write FRepository;
    property Version: string read FVersion write FVersion;
    property UseSSH: Boolean read FUseSSH write FUseSSH;
  end;

implementation

uses
  System.SysUtils, System.RegularExpressions, System.Hash;

{ TBoss4DDependency }

constructor TBoss4DDependency.Create(const ARepository: string; const AVersion: string; const AUseSSH: Boolean = False);
begin
  inherited Create;
  FRepository := ARepository.Trim;
  FVersion := AVersion.Trim;
  FUseSSH := AUseSSH;
end;

function TBoss4DDependency.HashName: string;
begin
  // Utiliza a classe nativa THashSHA2 do Delphi para computar o hash SHA-256 do repositorio em minusculas
  Result := THashSHA2.GetHashString(FRepository.ToLower).ToLower;
end;

function TBoss4DDependency.GetKey: string;
begin
  Result := FRepository.ToLower;
end;

function TBoss4DDependency.Name: string;
var
  LMatch: TMatch;
begin
  // Extrai o nome da dependencia (a ultima parte do caminho do repositorio)
  // Ex: "github.com/hashload/horse" -> "horse"
  LMatch := TRegEx.Match(FRepository, '[^/]+(:?/$|$)');
  if LMatch.Success then
    Result := LMatch.Value.Replace('/', '', [rfReplaceAll])
  else
    Result := FRepository;

  if Result.EndsWith('.git', True) then
    Result := Result.Substring(0, Result.Length - 4);
end;

function TBoss4DDependency.GetSSHUrl: string;
var
  LMatch: TMatch;
  LProvider, LRepoPath: string;
begin
  if FRepository.Contains('@') then
    Exit(FRepository);

  // Divide o provedor do restante do caminho
  // Ex: "github.com/hashload/horse" -> "git@github.com:hashload/horse"
  LMatch := TRegEx.Match(FRepository, '([\w\d.]*)(?:/)(.*)');
  if LMatch.Success and (LMatch.Groups.Count > 2) then
  begin
    LProvider := LMatch.Groups[1].Value;
    LRepoPath := LMatch.Groups[2].Value;
    Result := 'git@' + LProvider + ':' + LRepoPath;
  end;
end;

function TBoss4DDependency.GetURL: string;
begin
  if FUseSSH then
    Exit(GetSSHUrl);

  // Se ja possuir prefixo HTTP/HTTPS ou for um caminho de arquivo/intranet, retorna diretamente
  if TRegEx.IsMatch(FRepository, '^(https?|file):\/\/') or FRepository.StartsWith('\\') or TRegEx.IsMatch(FRepository, '^[a-zA-Z]:\\') then
    Exit(FRepository);

  Result := 'https://' + FRepository;
end;

class function TBoss4DDependency.Parse(const ARepo: string; const AVersionInfo: string): TBoss4DDependency;
var
  LParts: TArray<string>;
  LVersion: string;
  LUseSSH: Boolean;
begin
  LParts := AVersionInfo.Split([':']);
  LVersion := LParts[0];
  LUseSSH := (Length(LParts) > 1) and SameText(LParts[1], 'ssh');

  Result := TBoss4DDependency.Create(ARepo, LVersion, LUseSSH);
end;

class function TBoss4DDependency.ParseCommandLine(const ADepStr: string): TBoss4DDependency;
var
  LRepo, LVer: string;
  LLastAtIdx, LFirstAtIdx: Integer;
begin
  LRepo := ADepStr;
  LVer := '>=0.0.0';
  LLastAtIdx := ADepStr.LastIndexOf('@');

  if LLastAtIdx >= 0 then
  begin
    LFirstAtIdx := ADepStr.IndexOf('@');
    // Se houver mais de um '@' (ex: git@github.com...@v1)
    // ou se o '@' ocorrer apos a primeira barra '/' (ex: github.com/user/repo@v1)
    if (LLastAtIdx <> LFirstAtIdx) or (LLastAtIdx > ADepStr.IndexOf('/')) then
    begin
      LRepo := ADepStr.Substring(0, LLastAtIdx);
      LVer := ADepStr.Substring(LLastAtIdx + 1);
    end;
  end;
  Result := TBoss4DDependency.Create(LRepo, LVer);
end;

end.
