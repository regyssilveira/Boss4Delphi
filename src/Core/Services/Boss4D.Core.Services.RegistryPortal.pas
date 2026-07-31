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
    function ComposeFromFile(const ARegistryPath: string): string;
    function PackageTrust(const APackage: TJSONObject): string;
    function PackageSelectorData(const APackage: TJSONObject;
      const ASelector: string): string;
    function PackageVersionCount(const APackage: TJSONObject): Integer;
  public
    function Generate(const ARegistryContent: string): string;
    function GenerateFromFile(const ARegistryPath: string): string;
    function GenerateSearchIndexFromFile(
      const ARegistryPath: string): string;
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

function TBoss4DRegistryPortalService.ComposeFromFile(
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
    Result := LRoot.ToJSON;
  finally
    LVisited.Free;
    LRevocations.Free;
    LPackages.Free;
    LRoot.Free;
  end;
end;

function TBoss4DRegistryPortalService.GenerateFromFile(
  const ARegistryPath: string): string;
begin
  Result := Generate(ComposeFromFile(ARegistryPath));
end;

function TBoss4DRegistryPortalService.GenerateSearchIndexFromFile(
  const ARegistryPath: string): string;
var
  LComposed: TJSONObject;
  LOutput: TJSONObject;
  LOutputPackages: TJSONArray;
begin
  LComposed := TJSONObject.ParseJSONValue(
    ComposeFromFile(ARegistryPath)) as TJSONObject;
  LOutput := TJSONObject.Create;
  LOutputPackages := TJSONArray.Create;
  try
    var LPackages := LComposed.GetValue<TJSONArray>('packages');
    for var LPackageValue in LPackages do
    begin
      var LPackage := TJSONObject(LPackageValue);
      var LProjection := LPackage.Clone as TJSONObject;
      var LPublisherName := LProjection.GetValue<string>(
        '_publisherDisplayName', '');
      var LPublisherTrust := LProjection.GetValue<string>(
        '_publisherTrust', '');
      LProjection.RemovePair('_publisherDisplayName').Free;
      LProjection.RemovePair('_publisherTrust').Free;
      if not LPublisherName.IsEmpty then
        LProjection.AddPair('publisherDisplayName', LPublisherName);
      if not LPublisherTrust.IsEmpty then
        LProjection.AddPair('publisherTrust', LPublisherTrust);
      LOutputPackages.AddElement(LProjection);
    end;
    LOutput.AddPair('schemaVersion', TJSONNumber.Create(1));
    LOutput.AddPair('sourceProtocol', 'boss4d-registry-v2');
    LOutput.AddPair('packageCount',
      TJSONNumber.Create(LOutputPackages.Count));
    LOutput.AddPair('packages', LOutputPackages);
    LOutputPackages := nil;
    Result := LOutput.ToJSON;
  finally
    LOutputPackages.Free;
    LOutput.Free;
    LComposed.Free;
  end;
end;

function TBoss4DRegistryPortalService.EscapeHtml(
  const AValue: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AValue);
end;

function TBoss4DRegistryPortalService.PackageTrust(
  const APackage: TJSONObject): string;
begin
  Result := APackage.GetValue<string>('_publisherTrust', '');
  if Result.IsEmpty then
    Result := 'unregistered';
end;

function TBoss4DRegistryPortalService.PackageSelectorData(
  const APackage: TJSONObject; const ASelector: string): string;
var
  LValues: TList<string>;
  procedure AddVariants(const AVariantsValue: TJSONValue);
  begin
    if not (AVariantsValue is TJSONArray) then
      Exit;
    for var LVariantValue in TJSONArray(AVariantsValue) do
      if LVariantValue is TJSONObject then
      begin
        var LValue := TJSONObject(LVariantValue).GetValue<string>(
          ASelector, '');
        if not LValue.IsEmpty and not LValues.Contains(LValue) then
          LValues.Add(LValue);
      end;
  end;
begin
  LValues := TList<string>.Create;
  try
    AddVariants(APackage.GetValue('variants'));
    var LVersionsValue := APackage.GetValue('versions');
    if LVersionsValue is TJSONArray then
      for var LVersionValue in TJSONArray(LVersionsValue) do
        if LVersionValue is TJSONObject then
          AddVariants(TJSONObject(LVersionValue).GetValue('variants'));
    LValues.Sort;
    Result := string.Join(',', LValues.ToArray);
  finally
    LValues.Free;
  end;
end;

function TBoss4DRegistryPortalService.PackageVersionCount(
  const APackage: TJSONObject): Integer;
begin
  var LVersionsValue := APackage.GetValue('versions');
  if LVersionsValue is TJSONArray then
    Exit(TJSONArray(LVersionsValue).Count);
  if not APackage.GetValue<string>('version', '').IsEmpty then
    Exit(1);
  Result := 0;
end;

function TBoss4DRegistryPortalService.Generate(
  const ARegistryContent: string): string;
var
  LRoot: TJSONObject;
  LPackages: TJSONArray;
  LSchemaVersion: Integer;
  LVersionCount: Integer;
  LRegisteredCount: Integer;
  LVerifiedCount: Integer;
  LMigrationPercentage: Integer;
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
    LVersionCount := 0;
    LRegisteredCount := 0;
    LVerifiedCount := 0;
    for var LPackageValue in LPackages do
      if LPackageValue is TJSONObject then
      begin
        Inc(LVersionCount,
          PackageVersionCount(TJSONObject(LPackageValue)));
        if PackageTrust(TJSONObject(LPackageValue)) <> 'unregistered' then
          Inc(LRegisteredCount);
        if SameText(PackageTrust(TJSONObject(LPackageValue)),
          'authorized') then
          Inc(LVerifiedCount);
      end;
    if LPackages.Count = 0 then
      LMigrationPercentage := 100
    else
      LMigrationPercentage := Trunc(
        (LVerifiedCount * 100.0) / LPackages.Count);
    Result := '<!doctype html><html lang="en"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>Boss4D Public Registry</title><style>' +
      ':root{color-scheme:light dark;font-family:system-ui,sans-serif}' +
      'body{margin:0;background:#0b1020;color:#e8ecf7}' +
      'main{max-width:1180px;margin:auto;padding:2rem 1rem}' +
      'header{padding:2rem;border-radius:1.2rem;background:linear-gradient(135deg,#172554,#0f766e)}' +
      '.stats,.controls{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:1rem;margin:1.2rem 0}' +
      '.stat,.controls>*{padding:.85rem;border:1px solid #334155;border-radius:.75rem;background:#111827}' +
      '.stat strong{display:block;font-size:1.5rem}.controls label{display:grid;gap:.35rem}' +
      'input,select{font:inherit;padding:.7rem;border-radius:.5rem;border:1px solid #475569;background:#0f172a;color:inherit}' +
      '.submission{margin:1.2rem 0;padding:1rem 1.2rem;border:1px solid #0f766e;border-radius:.9rem;background:#102a2a}' +
      '.submission a{display:inline-block;padding:.65rem .9rem;border-radius:.55rem;background:#0f766e;color:#fff;font-weight:700;text-decoration:none}' +
      '#packages{list-style:none;padding:0;display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:1rem}' +
      '#packages li{padding:1rem;border:1px solid #334155;border-radius:.9rem;background:#111827}' +
      '.publisher,code,#packages span{display:inline-block;margin:.2rem;padding:.2rem .45rem;border-radius:.4rem;background:#1e293b}' +
      'a{color:#5eead4} [hidden]{display:none!important}' +
      '@media(max-width:700px){.stats,.controls{grid-template-columns:1fr}header{padding:1.25rem}}' +
      '</style></head><body><main><header><h1>Boss4D Public Registry</h1>' +
      '<p>Discover Delphi and Lazarus packages with explicit trust evidence.</p>' +
      '<p>Protocol v' + LSchemaVersion.ToString + '</p></header>' +
      '<section class="stats" aria-label="Catalog statistics">' +
      '<div class="stat"><strong id="visible-count">' +
      LPackages.Count.ToString + '</strong>visible packages</div>' +
      '<div class="stat"><strong>' + LVersionCount.ToString +
      '</strong>indexed versions</div><div class="stat"><strong>' +
      LRegisteredCount.ToString + '</strong>registered namespaces</div>' +
      '<div class="stat"><strong>' + LVerifiedCount.ToString +
      '</strong>verified packages</div><div class="stat"><strong>' +
      (LPackages.Count - LVerifiedCount).ToString +
      '</strong>legacy packages</div><div class="stat"><strong>' +
      LMigrationPercentage.ToString + '%</strong>verified migration</div>' +
      '</section><section id="community-submit" class="submission" aria-labelledby="community-submit-title">' +
      '<h2 id="community-submit-title">Submit a package</h2>' +
      '<p>Community submissions are welcome. Submission does not publish a package: catalog inclusion requires identity and evidence validation, automated checks and explicit maintainer approval.</p>' +
      '<a href="https://github.com/regyssilveira/Boss4Delphi/issues/new?template=registry-package-submission.yml">Submit package for review</a>' +
      '</section><section class="controls">' +
      '<label>Search<input id="package-search" type="search" placeholder="name or repository"></label>' +
      '<label>Trust<select id="trust-filter"><option value="">all</option>' +
      '<option value="authorized">authorized publisher</option>' +
      '<option value="namespace">registered namespace</option>' +
      '<option value="unregistered">unregistered</option></select></label>' +
      '<label>Migration<select id="migration-filter"><option value="">all</option>' +
      '<option value="verified">verified package</option>' +
      '<option value="legacy">legacy package</option></select></label>' +
      '<label>Platform<select id="platform-filter"><option value="">all</option></select></label>' +
      '<label>Compiler<select id="compiler-filter"><option value="">all</option></select></label>' +
      '</section><ul id="packages">';
    for var LValue in LPackages do
    begin
      var LPackage := TJSONObject(LValue);
      var LMigrationStatus := 'legacy';
      if SameText(PackageTrust(LPackage), 'authorized') then
        LMigrationStatus := 'verified';
      Result := Result + '<li data-package="' +
        EscapeHtml(LPackage.GetValue<string>('name', '') + ' ' +
          LPackage.GetValue<string>('repository', '')) +
        '" data-trust="' + EscapeHtml(PackageTrust(LPackage)) +
        '" data-migration="' + LMigrationStatus +
        '" data-platform="' + EscapeHtml(
          PackageSelectorData(LPackage, 'platform')) +
        '" data-compiler="' + EscapeHtml(
          PackageSelectorData(LPackage, 'compiler')) + '"><strong>' +
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
      'const cards=[...document.querySelectorAll("#packages li")];' +
      'const search=document.getElementById("package-search"),trust=document.getElementById("trust-filter"),' +
      'migration=document.getElementById("migration-filter"),platform=document.getElementById("platform-filter"),' +
      'compiler=document.getElementById("compiler-filter");' +
      'function options(select,key){const values=new Set();cards.forEach(c=>(c.dataset[key]||"").split(",").filter(Boolean).forEach(v=>values.add(v)));' +
      '[...values].sort().forEach(v=>select.add(new Option(v,v)));}' +
      'options(platform,"platform");options(compiler,"compiler");' +
      'function apply(){const q=search.value.toLowerCase();let visible=0;cards.forEach(c=>{' +
      'const show=c.dataset.package.toLowerCase().includes(q)&&(!trust.value||c.dataset.trust===trust.value)&&' +
      '(!migration.value||c.dataset.migration===migration.value)&&' +
      '(!platform.value||c.dataset.platform.split(",").includes(platform.value))&&' +
      '(!compiler.value||c.dataset.compiler.split(",").includes(compiler.value));c.hidden=!show;if(show)visible++;});' +
      'document.getElementById("visible-count").textContent=visible;}' +
      '[search,trust,migration,platform,compiler].forEach(x=>x.addEventListener("input",apply));' +
      '</script></body></html>';
  finally
    LRoot.Free;
  end;
end;

end.
