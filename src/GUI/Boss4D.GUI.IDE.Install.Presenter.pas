unit Boss4D.GUI.IDE.Install.Presenter;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEProcessPolicy;

type
  TBoss4DGUIIDEInstallRequest = record
    ProfileId: string;
    ProfileName: string;
    Compiler: string;
    RegistryBranch: string;
    PackageName: string;
    ConflictPolicy: TBoss4DIDEConflictPolicy;
    OpenPolicy: TBoss4DIDEOpenPolicy;
    Targets: TArray<string>;
    Changes: TArray<string>;
    function ConflictPolicyLabel: string;
    function OpenPolicyLabel: string;
    function Summary: string;
  end;

  TBoss4DGUIIDEInstallPresenter = class
  public
    class function BuildRequest(const AProfile: TBoss4DIDEProfileView;
      const APackageName: string;
      const ATargets: TObjectList<TBoss4DIDETargetView>;
      const AConflictPolicy: TBoss4DIDEConflictPolicy;
      const AOpenPolicy: TBoss4DIDEOpenPolicy):
      TBoss4DGUIIDEInstallRequest; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils;

function TBoss4DGUIIDEInstallRequest.ConflictPolicyLabel: string;
begin
  case ConflictPolicy of
    TBoss4DIDEConflictPolicy.Fail: Result := 'Bloquear';
    TBoss4DIDEConflictPolicy.Warn: Result := 'Avisar e continuar';
    TBoss4DIDEConflictPolicy.Adopt: Result := 'Adotar registro existente';
    TBoss4DIDEConflictPolicy.Replace: Result := 'Substituir registro';
  else
    Result := 'Desconhecida';
  end;
end;

function TBoss4DGUIIDEInstallRequest.OpenPolicyLabel: string;
begin
  case OpenPolicy of
    TBoss4DIDEOpenPolicy.Fail: Result := 'Bloquear se a IDE estiver aberta';
    TBoss4DIDEOpenPolicy.Defer: Result := 'Adiar alteracoes de registro';
    TBoss4DIDEOpenPolicy.Force: Result := 'Aplicar mesmo com a IDE aberta';
  else
    Result := 'Desconhecida';
  end;
end;

function TBoss4DGUIIDEInstallRequest.Summary: string;
begin
  Result := Format(
    'Perfil: %s (%s)%sCompilador: %s%sRegistry branch: %s%s' +
    'Package: %s%sConflitos: %s%sIDE aberta: %s%s%sTargets (%d):%s%s%s%s' +
    'Mudancas planejadas:%s%s',
    [ProfileName, ProfileId, sLineBreak, Compiler, sLineBreak,
     RegistryBranch, sLineBreak, PackageName, sLineBreak,
     ConflictPolicyLabel, sLineBreak, OpenPolicyLabel, sLineBreak,
     sLineBreak, Length(Targets), sLineBreak,
     IfThen(Length(Targets) = 0, '  (nenhum)', '  ' +
       string.Join(sLineBreak + '  ', Targets)), sLineBreak, sLineBreak,
     sLineBreak, '  ' + string.Join(sLineBreak + '  ', Changes)]);
end;

class function TBoss4DGUIIDEInstallPresenter.BuildRequest(
  const AProfile: TBoss4DIDEProfileView; const APackageName: string;
  const ATargets: TObjectList<TBoss4DIDETargetView>;
  const AConflictPolicy: TBoss4DIDEConflictPolicy;
  const AOpenPolicy: TBoss4DIDEOpenPolicy): TBoss4DGUIIDEInstallRequest;
begin
  if not Assigned(AProfile) then
    raise EArgumentNilException.Create('AProfile');
  if AProfile.Id.Trim.IsEmpty then
    raise EArgumentException.Create('O perfil IDE e obrigatorio.');
  if APackageName.Trim.IsEmpty then
    raise EArgumentException.Create('O package e obrigatorio.');
  if not Assigned(ATargets) then
    raise EArgumentNilException.Create('ATargets');
  if ATargets.Count = 0 then
    raise EArgumentException.Create(
      'Nenhum target compativel foi encontrado para o package.');

  Result := Default(TBoss4DGUIIDEInstallRequest);
  Result.ProfileId := AProfile.Id.Trim;
  Result.ProfileName := AProfile.Name.Trim;
  Result.Compiler := AProfile.Compiler.Trim;
  Result.RegistryBranch := AProfile.RegistryBranch.Trim;
  Result.PackageName := APackageName.Trim;
  Result.ConflictPolicy := AConflictPolicy;
  Result.OpenPolicy := AOpenPolicy;
  SetLength(Result.Targets, ATargets.Count);
  for var I := 0 to ATargets.Count - 1 do
  begin
    if ATargets[I].Identity.Trim.IsEmpty then
      raise EArgumentException.CreateFmt(
        'O target %d nao possui identidade.', [I + 1]);
    Result.Targets[I] := ATargets[I].Identity.Trim;
  end;
  Result.Changes := TArray<string>.Create(
    'Criar snapshot transacional para permitir undo',
    Format('Compilar/restaurar %d target(s)', [ATargets.Count]),
    'Registrar os artefatos na branch isolada ' +
      Result.RegistryBranch,
    'Adicionar ' + Result.PackageName +
      ' ao inventario do perfil');
end;

end.
