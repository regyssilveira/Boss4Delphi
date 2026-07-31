unit Boss4D.Core.Services.RegistryCheckout;

interface

uses
  System.SysUtils, System.JSON;

type
  TBoss4DRegistryCheckoutResult = record
    PackagePath: string;
    IndexPath: string;
    PackageName: string;
    Version: string;
    Appended: Boolean;
  end;

  EBoss4DRegistryCheckout = class(Exception);

  TBoss4DRegistryCheckoutService = class
  private
    class function LoadObject(const APath: string): TJSONObject; static;
    class procedure SaveObject(const APath: string;
      const AObject: TJSONObject); static;
    class function SparseContains(const AIndex: TJSONObject;
      const APath: string): Boolean; static;
    class procedure ValidatePublisher(const APublishers: TJSONObject;
      const APublisherId, ARepository, AFingerprint: string); static;
  public
    function Apply(const ARoot, ASubmissionPath: string;
      const AAppendVersion: Boolean): TBoss4DRegistryCheckoutResult;
  end;

implementation

uses
  System.IOUtils, System.Classes, System.Generics.Collections,
  Boss4D.Core.Services.RegistrySubmission;

class function TBoss4DRegistryCheckoutService.LoadObject(
  const APath: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  if not TFile.Exists(APath) then
    raise EBoss4DRegistryCheckout.Create(
      'Arquivo obrigatorio do Registry nao encontrado: ' + APath);
  LValue := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(APath, TEncoding.UTF8));
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EBoss4DRegistryCheckout.Create(
      'Documento JSON precisa ser um objeto: ' + APath);
  end;
  Result := TJSONObject(LValue);
end;

class procedure TBoss4DRegistryCheckoutService.SaveObject(
  const APath: string; const AObject: TJSONObject);
var
  LEncoding: TEncoding;
begin
  LEncoding := TUTF8Encoding.Create(False);
  try
    TFile.WriteAllText(APath, AObject.ToJSON +
      sLineBreak, LEncoding);
  finally
    LEncoding.Free;
  end;
end;

class function TBoss4DRegistryCheckoutService.SparseContains(
  const AIndex: TJSONObject; const APath: string): Boolean;
var
  LArray: TJSONArray;
begin
  Result := False;
  LArray := AIndex.GetValue<TJSONArray>('sparse');
  if not Assigned(LArray) then
    Exit;
  for var LValue in LArray do
    if ((LValue is TJSONString) and SameText(LValue.Value, APath)) or
       ((LValue is TJSONObject) and
        SameText(TJSONObject(LValue).GetValue<string>('path', ''), APath)) then
      Exit(True);
end;

class procedure TBoss4DRegistryCheckoutService.ValidatePublisher(
  const APublishers: TJSONObject; const APublisherId, ARepository,
  AFingerprint: string);
var
  LPublisherArray, LSignerArray, LRepositoryArray: TJSONArray;
  LPublisher: TJSONObject;
  LFound, LSignerAllowed, LRepositoryAllowed: Boolean;
begin
  LFound := False;
  LSignerAllowed := False;
  LRepositoryAllowed := False;
  LPublisherArray := APublishers.GetValue<TJSONArray>('publishers');
  if Assigned(LPublisherArray) then
    for var LValue in LPublisherArray do
    begin
      if not (LValue is TJSONObject) then
        Continue;
      LPublisher := TJSONObject(LValue);
      if LPublisher.GetValue<string>('id', '') <> APublisherId then
        Continue;
      LFound := True;
      LSignerArray := LPublisher.GetValue<TJSONArray>('allowedSigners');
      if Assigned(LSignerArray) then
        for var LSigner in LSignerArray do
          if SameText(LSigner.Value, AFingerprint) then
            LSignerAllowed := True;
      LRepositoryArray := LPublisher.GetValue<TJSONArray>('repositories');
      if Assigned(LRepositoryArray) then
        for var LRepositoryPrefix in LRepositoryArray do
          if ARepository.StartsWith(LRepositoryPrefix.Value, True) then
            LRepositoryAllowed := True;
      Break;
    end;
  if not LFound then
    raise EBoss4DRegistryCheckout.Create(
      'Publisher nao cadastrado: ' + APublisherId);
  if not LSignerAllowed then
    raise EBoss4DRegistryCheckout.Create(
      'Fingerprint nao autorizado para o publisher.');
  if not LRepositoryAllowed then
    raise EBoss4DRegistryCheckout.Create(
      'Repositorio fora do escopo do publisher.');
end;

function TBoss4DRegistryCheckoutService.Apply(const ARoot,
  ASubmissionPath: string;
  const AAppendVersion: Boolean): TBoss4DRegistryCheckoutResult;
var
  LRoot, LPublishersPath, LIndexPath, LPackageDirectory, LPackagePath,
    LOriginalIndex, LOriginalPackage, LPublisherId, LRepository,
    LFingerprint, LSparsePath: string;
  LSubmissionObject, LPublishersObject, LIndexObject,
    LExistingObject: TJSONObject;
  LSubmission, LPublishers, LIndex, LExisting, LPackage,
    LVersion, LExistingPackage: TJSONObject;
  LPackageArray, LVersionArray, LSparseArray, LExistingPackages,
    LExistingVersions: TJSONArray;
  LPackageExisted, LSparsePresent: Boolean;
  I: Integer;
  LSparse: TStringList;
  LPair: TJSONPair;
begin
  Result := Default(TBoss4DRegistryCheckoutResult);
  LRoot := TPath.GetFullPath(ARoot);
  LPublishersPath := TPath.Combine(LRoot, 'registry\publishers.json');
  LIndexPath := TPath.Combine(LRoot, 'registry\index-v2.json');
  LPackageDirectory := TPath.Combine(LRoot, 'registry\packages');
  LSubmissionObject := LoadObject(TPath.GetFullPath(ASubmissionPath));
  LPublishersObject := LoadObject(LPublishersPath);
  LIndexObject := LoadObject(LIndexPath);
  LExistingObject := nil;
  try
    LSubmission := LSubmissionObject;
    LPublishers := LPublishersObject;
    LIndex := LIndexObject;
    if LSubmission.GetValue<Integer>('schemaVersion', 0) <> 2 then
      raise EBoss4DRegistryCheckout.Create(
        'Submissao precisa usar schemaVersion 2.');
    LPackageArray := LSubmission.GetValue<TJSONArray>('packages');
    if not Assigned(LPackageArray) or (LPackageArray.Count <> 1) or
       not (LPackageArray[0] is TJSONObject) then
      raise EBoss4DRegistryCheckout.Create(
        'Submissao precisa conter exatamente um pacote.');
    LPackage := TJSONObject(LPackageArray[0]);
    LVersionArray := LPackage.GetValue<TJSONArray>('versions');
    if not Assigned(LVersionArray) or (LVersionArray.Count <> 1) or
       not (LVersionArray[0] is TJSONObject) then
      raise EBoss4DRegistryCheckout.Create(
        'Submissao precisa conter exatamente uma versao.');
    LVersion := TJSONObject(LVersionArray[0]);
    Result.PackageName := LPackage.GetValue<string>('name', '');
    Result.Version := LVersion.GetValue<string>('version', '');
    LPublisherId := LPackage.GetValue<string>('publisher', '');
    LRepository := LPackage.GetValue<string>('repository', '');
    LFingerprint :=
      LPackage.GetValue<string>('signerFingerprint', '').ToUpper;
    LPackagePath := TPath.Combine(LPackageDirectory,
      TBoss4DRegistrySubmissionService.PackageSlug(
        Result.PackageName) + '.json');
    LSparsePath := 'packages/' +
      TPath.GetFileName(LPackagePath).Replace('\', '/');
    Result.PackagePath := LPackagePath;
    Result.IndexPath := LIndexPath;
    Result.Appended := AAppendVersion;

    LSparsePresent := SparseContains(LIndex, LSparsePath);
    ValidatePublisher(LPublishers, LPublisherId, LRepository, LFingerprint);

    LPackageExisted := TFile.Exists(LPackagePath);
    if LPackageExisted and not AAppendVersion then
      raise EBoss4DRegistryCheckout.Create(
        'Metadado do pacote ja existe; use append.');
    if not LPackageExisted and AAppendVersion then
      raise EBoss4DRegistryCheckout.Create(
        'Nao e possivel anexar versao a pacote inexistente.');
    if not AAppendVersion and LSparsePresent then
      raise EBoss4DRegistryCheckout.Create(
        'Entrada sparse ja existe para o pacote.');
    if AAppendVersion and not LSparsePresent then
      raise EBoss4DRegistryCheckout.Create(
        'Pacote existente nao esta referenciado no indice sparse.');

    LOriginalIndex := TFile.ReadAllText(LIndexPath, TEncoding.UTF8);
    if LPackageExisted then
      LOriginalPackage := TFile.ReadAllText(LPackagePath, TEncoding.UTF8)
    else
      LOriginalPackage := '';
    try
      if AAppendVersion then
      begin
        LExistingObject := LoadObject(LPackagePath);
        LExisting := LExistingObject;
        LExistingPackages := LExisting.GetValue<TJSONArray>('packages');
        if not Assigned(LExistingPackages) or
           (LExistingPackages.Count <> 1) or
           not (LExistingPackages[0] is TJSONObject) then
          raise EBoss4DRegistryCheckout.Create(
            'Pacote existente precisa conter uma identidade.');
        LExistingPackage :=
          TJSONObject(LExistingPackages[0]);
        if (LExistingPackage.GetValue<string>('name', '') <>
              Result.PackageName) or
           (LExistingPackage.GetValue<string>('publisher', '') <>
              LPublisherId) or
           (LExistingPackage.GetValue<string>('repository', '') <>
              LRepository) or
           not SameText(LExistingPackage.GetValue<string>(
              'signerFingerprint', ''), LFingerprint) then
          raise EBoss4DRegistryCheckout.Create(
            'Append nao pode alterar identidade, repositorio ou signer.');
        LExistingVersions :=
          LExistingPackage.GetValue<TJSONArray>('versions');
        if not Assigned(LExistingVersions) then
          raise EBoss4DRegistryCheckout.Create(
            'Pacote existente nao possui versions.');
        for I := 0 to LExistingVersions.Count - 1 do
          if (LExistingVersions[I] is TJSONObject) and
             (TJSONObject(LExistingVersions[I])
                .GetValue<string>('version', '') = Result.Version) then
            raise EBoss4DRegistryCheckout.Create(
              'Versao ja existe e e imutavel: ' + Result.Version);
        LExistingVersions.AddElement(LVersion.Clone as TJSONValue);
        SaveObject(LPackagePath, LExisting);
      end
      else
      begin
        TDirectory.CreateDirectory(LPackageDirectory);
        SaveObject(LPackagePath, LSubmission);
        LSparse := TStringList.Create;
        try
          LSparse.Sorted := True;
          LSparse.Duplicates := dupIgnore;
          LSparseArray := LIndex.GetValue<TJSONArray>('sparse');
          if Assigned(LSparseArray) then
            for I := 0 to LSparseArray.Count - 1 do
              if LSparseArray[I] is TJSONString then
                LSparse.Add(LSparseArray[I].Value)
              else if LSparseArray[I] is TJSONObject then
                LSparse.Add(TJSONObject(LSparseArray[I])
                  .GetValue<string>('path', ''));
          LSparse.Add(LSparsePath);
          LPair := LIndex.RemovePair('sparse');
          LPair.Free;
          LSparseArray := TJSONArray.Create;
          for I := 0 to LSparse.Count - 1 do
            LSparseArray.Add(LSparse[I]);
          LIndex.AddPair('sparse', LSparseArray);
        finally
          LSparse.Free;
        end;
        SaveObject(LIndexPath, LIndex);
      end;
    except
      if LPackageExisted then
        TFile.WriteAllText(LPackagePath, LOriginalPackage, TEncoding.UTF8)
      else if TFile.Exists(LPackagePath) then
        TFile.Delete(LPackagePath);
      TFile.WriteAllText(LIndexPath, LOriginalIndex, TEncoding.UTF8);
      raise;
    end;
  finally
    LExistingObject.Free;
    LIndexObject.Free;
    LPublishersObject.Free;
    LSubmissionObject.Free;
  end;
end;

end.
