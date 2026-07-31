unit Boss4D.Core.Services.RegistryPortal;

interface

uses
  System.JSON,
  System.Generics.Collections;

type
  TBoss4DRegistryPortalService = class
  private
    function EscapeHtml(const AValue: string): string;
    function ResolveLocalReference(const ARootDirectory,
      ASourcePath, AReference: string): string;
    procedure LoadDocument(const ARootDirectory, ASourcePath: string;
      const APackages, ARevocations: TJSONArray;
      const AVisited: TDictionary<string, Boolean>);
    procedure LoadReferences(const ARootDirectory, ASourcePath: string;
      const ARoot: TJSONObject; const AName: string;
      const APackages, ARevocations: TJSONArray;
      const AVisited: TDictionary<string, Boolean>);
    procedure ApplyRevocations(const APackages, ARevocations: TJSONArray);
    function RepositoryMatchesPublisher(const ARepository: string;
      const APublisher: TJSONObject): Boolean;
    function SignerMatchesPublisher(const AFingerprint: string;
      const APublisher: TJSONObject): Boolean;
    procedure AnnotatePublishers(const APackages: TJSONArray;
      const APublisherContent: string);
  public
    function Generate(const ARegistryContent: string): string;
    function GenerateFromFile(const ARegistryPath: string): string;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.NetEncoding;

function TBoss4DRegistryPortalService.ResolveLocalReference(
  const ARootDirectory, ASourcePath, AReference: string): string;
var
  LRoot: string;
begin
  if AReference.StartsWith('http://', True) or
     AReference.StartsWith('https://', True) then
    raise EArgumentException.Create(
      'O portal local nao carrega referencias HTTP; materialize o registry.');
  if TPath.IsPathRooted(AReference) then
    Result := TPath.GetFullPath(AReference)
  else
    Result := TPath.GetFullPath(TPath.Combine(
      TPath.GetDirectoryName(ASourcePath), AReference));
  LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ARootDirectory));
  if not Result.StartsWith(LRoot, True) then
    raise EArgumentException.CreateFmt(
      'Referencia fora da raiz do registry: %s.', [AReference]);
end;

procedure TBoss4DRegistryPortalService.LoadReferences(
  const ARootDirectory, ASourcePath: string; const ARoot: TJSONObject;
  const AName: string; const APackages, ARevocations: TJSONArray;
  const AVisited: TDictionary<string, Boolean>);
begin
  var LReferenceValue := ARoot.GetValue(AName);
  if not (LReferenceValue is TJSONArray) then
    Exit;
  var LReferences := TJSONArray(LReferenceValue);
  for var LValue in LReferences do
  begin
    var LReference := '';
    if LValue is TJSONString then
      LReference := LValue.Value
    else if LValue is TJSONObject then
      LReference := TJSONObject(LValue).GetValue<string>('path', '');
    if LReference.Trim.IsEmpty then
      raise EArgumentException.CreateFmt(
        'Referencia vazia em %s.', [AName]);
    LoadDocument(ARootDirectory,
      ResolveLocalReference(ARootDirectory, ASourcePath, LReference),
      APackages, ARevocations, AVisited);
  end;
end;

procedure TBoss4DRegistryPortalService.LoadDocument(
  const ARootDirectory, ASourcePath: string;
  const APackages, ARevocations: TJSONArray;
  const AVisited: TDictionary<string, Boolean>);
var
  LRoot: TJSONObject;
begin
  var LSource := TPath.GetFullPath(ASourcePath);
  if AVisited.ContainsKey(LSource.ToLower) then
    Exit;
  AVisited.Add(LSource.ToLower, True);
  if not TFile.Exists(LSource) then
    raise EFileNotFoundException.CreateFmt(
      'Documento do registry nao encontrado: %s.', [LSource]);
  LRoot := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(LSource, TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.CreateFmt(
      'Documento do registry invalido: %s.', [LSource]);
  try
    var LSchema := LRoot.GetValue<Integer>('schemaVersion', 0);
    if not (LSchema in [1, 2]) then
      raise EArgumentException.CreateFmt(
        'Schema de registry nao suportado em %s.', [LSource]);
    var LPackagesValue := LRoot.GetValue('packages');
    if LPackagesValue is TJSONArray then
    begin
      var LLocalPackages := TJSONArray(LPackagesValue);
      for var LPackage in LLocalPackages do
        APackages.AddElement(LPackage.Clone as TJSONValue);
    end;
    var LRevocationsValue := LRoot.GetValue('revocations');
    if LRevocationsValue is TJSONArray then
    begin
      var LLocalRevocations := TJSONArray(LRevocationsValue);
      for var LRevocation in LLocalRevocations do
        ARevocations.AddElement(LRevocation.Clone as TJSONValue);
    end;
    LoadReferences(ARootDirectory, LSource, LRoot, 'includes',
      APackages, ARevocations, AVisited);
    LoadReferences(ARootDirectory, LSource, LRoot, 'sparse',
      APackages, ARevocations, AVisited);
  finally
    LRoot.Free;
  end;
end;

procedure TBoss4DRegistryPortalService.ApplyRevocations(
  const APackages, ARevocations: TJSONArray);
begin
  for var LRevocationValue in ARevocations do
  begin
    if not (LRevocationValue is TJSONObject) then
      Continue;
    var LRevocation := TJSONObject(LRevocationValue);
    for var LPackageValue in APackages do
    begin
      if not (LPackageValue is TJSONObject) then
        Continue;
      var LPackage := TJSONObject(LPackageValue);
      if not SameText(LPackage.GetValue<string>('name', ''),
        LRevocation.GetValue<string>('name', '')) then
        Continue;
      var LVersionsValue := LPackage.GetValue('versions');
      if not (LVersionsValue is TJSONArray) then
        Continue;
      var LVersions := TJSONArray(LVersionsValue);
      for var LVersionValue in LVersions do
        if (LVersionValue is TJSONObject) and
           SameText(TJSONObject(LVersionValue).GetValue<string>(
             'version', ''), LRevocation.GetValue<string>('version', '')) then
        begin
          var LVersion := TJSONObject(LVersionValue);
          LVersion.RemovePair('revoked').Free;
          LVersion.AddPair('revoked', TJSONBool.Create(True));
          LVersion.RemovePair('revocationReason').Free;
          LVersion.AddPair('revocationReason',
            LRevocation.GetValue<string>('reason', ''));
        end;
    end;
  end;
end;

function TBoss4DRegistryPortalService.RepositoryMatchesPublisher(
  const ARepository: string; const APublisher: TJSONObject): Boolean;
begin
  Result := False;
  var LRepositoriesValue := APublisher.GetValue('repositories');
  if not (LRepositoriesValue is TJSONArray) then
    Exit;
  for var LRepositoryValue in TJSONArray(LRepositoriesValue) do
    if (LRepositoryValue is TJSONString) and
       ARepository.StartsWith(LRepositoryValue.Value, True) then
      Exit(True);
end;

function TBoss4DRegistryPortalService.SignerMatchesPublisher(
  const AFingerprint: string; const APublisher: TJSONObject): Boolean;
begin
  Result := False;
  if AFingerprint.Trim.IsEmpty then
    Exit;
  var LSignersValue := APublisher.GetValue('allowedSigners');
  if not (LSignersValue is TJSONArray) then
    Exit;
  for var LSignerValue in TJSONArray(LSignersValue) do
    if (LSignerValue is TJSONString) and
       SameText(AFingerprint, LSignerValue.Value) then
      Exit(True);
end;

procedure TBoss4DRegistryPortalService.AnnotatePublishers(
  const APackages: TJSONArray; const APublisherContent: string);
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.ParseJSONValue(APublisherContent) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.Create('Cadastro de publishers invalido.');
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EArgumentException.Create(
        'Schema do cadastro de publishers nao suportado.');
    var LPublishersValue := LRoot.GetValue('publishers');
    if not (LPublishersValue is TJSONArray) then
      raise EArgumentException.Create('Cadastro sem publishers.');
    for var LPackageValue in APackages do
    begin
      if not (LPackageValue is TJSONObject) then
        Continue;
      var LPackage := TJSONObject(LPackageValue);
      var LRepository := LPackage.GetValue<string>('repository', '');
      var LDeclaredPublisher := LPackage.GetValue<string>('publisher', '');
      var LSelected: TJSONObject := nil;
      for var LPublisherValue in TJSONArray(LPublishersValue) do
      begin
        if not (LPublisherValue is TJSONObject) then
          Continue;
        var LPublisher := TJSONObject(LPublisherValue);
        if (not LDeclaredPublisher.IsEmpty and
            SameText(LDeclaredPublisher,
              LPublisher.GetValue<string>('id', ''))) or
           (LDeclaredPublisher.IsEmpty and
            RepositoryMatchesPublisher(LRepository, LPublisher)) then
        begin
          LSelected := LPublisher;
          Break;
        end;
      end;
      if not Assigned(LSelected) or
         not RepositoryMatchesPublisher(LRepository, LSelected) then
        Continue;
      LPackage.AddPair('_publisherDisplayName',
        LSelected.GetValue<string>('displayName',
          LSelected.GetValue<string>('id', '')));
      if SignerMatchesPublisher(
        LPackage.GetValue<string>('signerFingerprint', ''), LSelected) then
        LPackage.AddPair('_publisherTrust', 'authorized')
      else
        LPackage.AddPair('_publisherTrust', 'namespace');
    end;
  finally
    LRoot.Free;
  end;
end;

function TBoss4DRegistryPortalService.GenerateFromFile(
  const ARegistryPath: string): string;
var
  LRoot: TJSONObject;
  LPackages: TJSONArray;
  LRevocations: TJSONArray;
  LVisited: TDictionary<string, Boolean>;
begin
  var LSource := TPath.GetFullPath(ARegistryPath);
  LRoot := TJSONObject.Create;
  LPackages := TJSONArray.Create;
  LRevocations := TJSONArray.Create;
  LVisited := TDictionary<string, Boolean>.Create;
  try
    LoadDocument(TPath.GetDirectoryName(LSource), LSource,
      LPackages, LRevocations, LVisited);
    var LPublisherPath := TPath.Combine(
      TPath.GetDirectoryName(LSource), 'publishers.json');
    if TFile.Exists(LPublisherPath) then
      AnnotatePublishers(LPackages,
        TFile.ReadAllText(LPublisherPath, TEncoding.UTF8));
    ApplyRevocations(LPackages, LRevocations);
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(2));
    LRoot.AddPair('packages', LPackages);
    LPackages := nil;
    Result := Generate(LRoot.ToJSON);
  finally
    LVisited.Free;
    LRevocations.Free;
    LPackages.Free;
    LRoot.Free;
  end;
end;

function TBoss4DRegistryPortalService.EscapeHtml(
  const AValue: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AValue);
end;

function TBoss4DRegistryPortalService.Generate(
  const ARegistryContent: string): string;
var
  LRoot: TJSONObject;
  LPackages: TJSONArray;
  LSchemaVersion: Integer;
begin
  LRoot := TJSONObject.ParseJSONValue(ARegistryContent) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.Create('Registry invalido.');
  LSchemaVersion := LRoot.GetValue<Integer>('schemaVersion', 0);
  if not (LSchemaVersion in [1, 2]) then
  begin
    LRoot.Free;
    raise EArgumentException.Create('Schema de registry nao suportado.');
  end;
  try
    LPackages := LRoot.GetValue<TJSONArray>('packages');
    if not Assigned(LPackages) then
      raise EArgumentException.Create('Registry sem packages.');
    Result := '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>Boss4D Public Registry</title></head><body>' +
      '<main><h1>Boss4D Public Registry</h1><p>Protocol v' +
      LSchemaVersion.ToString + '</p>' +
      '<label for="package-search">Search packages</label>' +
      '<input id="package-search" type="search" placeholder="name or repository">' +
      '<ul id="packages">';
    for var LValue in LPackages do
    begin
      var LPackage := TJSONObject(LValue);
      Result := Result + '<li data-package="' +
        EscapeHtml(LPackage.GetValue<string>('name', '') + ' ' +
          LPackage.GetValue<string>('repository', '')) + '"><strong>' +
        EscapeHtml(LPackage.GetValue<string>('name', '')) +
        '</strong>';
      var LPublisherName := LPackage.GetValue<string>(
        '_publisherDisplayName', '');
      if not LPublisherName.IsEmpty then
      begin
        var LPublisherLabel := 'registered namespace';
        if SameText(LPackage.GetValue<string>('_publisherTrust', ''),
          'authorized') then
          LPublisherLabel := 'authorized publisher';
        Result := Result + ' <span class="publisher" title="' +
          EscapeHtml(LPublisherLabel) + '">' +
          EscapeHtml(LPublisherLabel + ': ' + LPublisherName) + '</span>';
      end;
      if LSchemaVersion = 1 then
        Result := Result + ' <code>' +
          EscapeHtml(LPackage.GetValue<string>('version', '')) + '</code>'
      else
      begin
        var LVersionsValue := LPackage.GetValue('versions');
        if LVersionsValue is TJSONArray then
        begin
          var LVersions := TJSONArray(LVersionsValue);
          for var LVersionValue in LVersions do
            if LVersionValue is TJSONObject then
            begin
              var LVersion := TJSONObject(LVersionValue);
              Result := Result + '<div><code>' +
                EscapeHtml(LVersion.GetValue<string>('version', ''));
              if LVersion.GetValue<Boolean>('revoked', False) then
                Result := Result + ' (revoked)';
              Result := Result + '</code>';
              if not LVersion.GetValue<string>('sha256', '').IsEmpty then
                Result := Result + ' <span>SHA-256</span>';
              if not LVersion.GetValue<string>('signature', '').IsEmpty then
                Result := Result + ' <span>signature</span>';
              if not LVersion.GetValue<string>('provenance', '').IsEmpty then
                Result := Result + ' <span>provenance</span>';
              Result := Result + '</div>';
            end;
        end
        else if not LPackage.GetValue<string>('version', '').IsEmpty then
          Result := Result + ' <code>' +
            EscapeHtml(LPackage.GetValue<string>('version', '')) + '</code>';
      end;
      Result := Result + '<p>' +
        EscapeHtml(LPackage.GetValue<string>('description', '')) +
        '</p><a href="https://' +
        EscapeHtml(LPackage.GetValue<string>('repository', '')) +
        '">repository</a></li>';
    end;
    Result := Result + '</ul></main><script>' +
      'document.getElementById("package-search").addEventListener("input",function(){' +
      'var q=this.value.toLowerCase();document.querySelectorAll("#packages li").forEach(' +
      'function(x){x.hidden=x.dataset.package.toLowerCase().indexOf(q)<0;});});' +
      '</script></body></html>';
  finally
    LRoot.Free;
  end;
end;

end.
