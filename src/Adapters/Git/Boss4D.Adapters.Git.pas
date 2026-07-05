unit Boss4D.Adapters.Git;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Dependency;

type
  { Adaptador Git usando execucao de subprocessos git.exe nativos }
  TBoss4DGitCliAdapter = class(TInterfacedObject, IBoss4DGitClient)
  private
    FGitShallow: Boolean;

    function ExecuteGit(const AArgs: string; const AWorkingDir: string; out AOutput: string): Boolean;
  public
    constructor Create(const AGitShallow: Boolean = False);

    procedure CloneCache(const ADep: TBoss4DDependency; const ATargetDir: string);
    procedure UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
    function GetVersions(const ACacheDir: string): TArray<string>;
    procedure Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Boss4D.Core.Domain.Env;

{ TBoss4DGitCliAdapter }

constructor TBoss4DGitCliAdapter.Create(const AGitShallow: Boolean = False);
begin
  inherited Create;
  FGitShallow := AGitShallow;
end;

function TBoss4DGitCliAdapter.ExecuteGit(const AArgs: string; const AWorkingDir: string; out AOutput: string): Boolean;
begin
  Result := ExecuteCommandLine('git ' + AArgs, AWorkingDir, AOutput);
end;

procedure TBoss4DGitCliAdapter.CloneCache(const ADep: TBoss4DDependency; const ATargetDir: string);
var
  LArgs: string;
  LOutput: string;
begin
  // Cria diretorio pai se nao existir
  var LParentDir := TDirectory.GetParent(ATargetDir);
  if not TDirectory.Exists(LParentDir) then
    TDirectory.CreateDirectory(LParentDir);

  LArgs := 'clone ';
  if FGitShallow then
    LArgs := LArgs + '--depth=1 ';

  LArgs := LArgs + '"' + ADep.GetURL + '" "' + ATargetDir + '"';

  if not ExecuteGit(LArgs, '', LOutput) then
    raise Exception.CreateFmt('Erro ao clonar o repositorio %s: %s', [ADep.Repository, LOutput]);
end;

procedure TBoss4DGitCliAdapter.UpdateCache(const ADep: TBoss4DDependency; const ACacheDir: string);
var
  LOutput: string;
begin
  // Executa um git fetch para atualizar as tags/branches locais no cache
  if not ExecuteGit('fetch --all --tags', ACacheDir, LOutput) then
    raise Exception.CreateFmt('Erro ao atualizar cache do repositorio %s: %s', [ADep.Repository, LOutput]);
end;

function TBoss4DGitCliAdapter.GetVersions(const ACacheDir: string): TArray<string>;
var
  LOutput: string;
  LResultList: TList<string>;
  LLines: TArray<string>;
begin
  LResultList := TList<string>.Create;
  try
    // Obtem todas as tags do git no repositorio
    if ExecuteGit('tag', ACacheDir, LOutput) then
    begin
      LLines := LOutput.Split([sLineBreak, #10, #13], TStringSplitOptions.ExcludeEmpty);
      for var LLine in LLines do
      begin
        var LCleanTag := LLine.Trim;
        if not LCleanTag.IsEmpty then
          LResultList.Add(LCleanTag);
      end;
    end;
    Result := LResultList.ToArray;
  finally
    LResultList.Free;
  end;
end;

procedure TBoss4DGitCliAdapter.Checkout(const ACacheDir: string; const AVersion: string; const ATargetDir: string);
var
  LOutput: string;
begin
  // Garante que a pasta destino esta limpa e existe
  if TDirectory.Exists(ATargetDir) then
    TDirectory.Delete(ATargetDir, True);
  TDirectory.CreateDirectory(ATargetDir);

  // Copia o repositorio do cache para a pasta destino (sem a pasta .git para manter limpo, ou clonando localmente)
  // Fazemos um clone local do cache para a pasta destino, o que e muito mais rapido e mantem integridade
  if not ExecuteGit('clone "' + ACacheDir + '" "' + ATargetDir + '"', '', LOutput) then
    raise Exception.CreateFmt('Erro ao criar clone local para checkout: %s', [LOutput]);

  // Efetua o checkout da versao desejada no destino (se informada)
  if not AVersion.IsEmpty then
  begin
    if not ExecuteGit('checkout "' + AVersion + '"', ATargetDir, LOutput) then
      raise Exception.CreateFmt('Erro ao efetuar checkout da versao %s: %s', [AVersion, LOutput]);
  end;

  // Remove a pasta .git no destino para nao poluir o projeto com sub-repositorios git
  var LGitFolder := TPath.Combine(ATargetDir, '.git');
  if TDirectory.Exists(LGitFolder) then
  begin
    // Remove atributos de somente leitura nos arquivos da pasta .git para evitar erros de permissao
    TDirectory.SetAttributes(LGitFolder, [TFileAttribute.faDirectory]);
    TDirectory.Delete(LGitFolder, True);
  end;
end;

end.
