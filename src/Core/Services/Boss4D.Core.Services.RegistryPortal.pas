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
        var LRepository := LPackage.GetValue<string>(
          'distributionRepository',
          LPackage.GetValue<string>('publisherRepository',
            LPackage.GetValue<string>('repository', '')));
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
      ':root{font-family:Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;color:#25272a;background:#f7f7f5}' +
      '*{box-sizing:border-box}body{margin:0;line-height:1.55}' +
      'a{color:#176b5d;text-underline-offset:.18em}a:hover{color:#0c4d43}' +
      '.site-header{border-bottom:1px solid #deded9;background:#fff}' +
      '.site-header div{max-width:1040px;margin:auto;padding:1rem 1.25rem;display:flex;align-items:center;justify-content:space-between;gap:1rem}' +
      '.brand{font-weight:700;color:#25272a;text-decoration:none;letter-spacing:-.02em}' +
      '.site-header nav{display:flex;gap:1rem;font-size:.9rem}' +
      'main{max-width:1040px;margin:auto;padding:0 1.25rem 4rem}' +
      '.intro{padding:4.5rem 0 3rem;max-width:700px}' +
      '.eyebrow{margin:0 0 .75rem;color:#176b5d;font-size:.78rem;font-weight:700;letter-spacing:.09em;text-transform:uppercase}' +
      'h1{margin:0;font-size:clamp(2.2rem,6vw,4.25rem);line-height:1.02;letter-spacing:-.055em;font-weight:720}' +
      '.lede{margin:1.25rem 0 0;max-width:620px;color:#656762;font-size:1.1rem}' +
      '.stats{display:flex;flex-wrap:wrap;gap:.65rem 1.75rem;padding:1.1rem 0;border-top:1px solid #deded9;border-bottom:1px solid #deded9;color:#656762;font-size:.86rem}' +
      '.stat strong{color:#25272a;font-size:1rem;margin-right:.3rem}' +
      '.submission{margin:3rem 0;display:grid;grid-template-columns:minmax(0,1fr) auto;align-items:center;gap:1.5rem;padding:1.4rem 0;border-bottom:1px solid #deded9}' +
      '.submission h2,.catalog-heading h2{margin:0;font-size:1.15rem;letter-spacing:-.02em}' +
      '.submission p{margin:.35rem 0 0;color:#656762;max-width:680px}' +
      '.button{display:inline-block;padding:.62rem .9rem;border:1px solid #b8bab4;border-radius:.35rem;background:#fff;color:#25272a;font-weight:650;text-decoration:none;white-space:nowrap}' +
      '.button:hover{border-color:#176b5d;color:#176b5d}' +
      '.catalog-heading{display:flex;align-items:end;justify-content:space-between;gap:1rem;margin-bottom:1rem}' +
      '.catalog-heading p{margin:0;color:#777973;font-size:.88rem}' +
      '.controls{display:grid;grid-template-columns:2fr repeat(4,1fr);gap:.65rem;margin-bottom:1.5rem}' +
      '.controls label{display:grid;gap:.35rem;color:#656762;font-size:.76rem;font-weight:650}' +
      'input,select{width:100%;font:inherit;color:#25272a;padding:.65rem .7rem;border:1px solid #d1d2cd;border-radius:.35rem;background:#fff}' +
      'input:focus,select:focus{outline:2px solid #91c7bc;outline-offset:1px;border-color:#176b5d}' +
      '#packages{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));border-top:1px solid #deded9}' +
      '#packages li{min-width:0;padding:1.3rem 1.3rem 1.3rem 0;border-bottom:1px solid #deded9}' +
      '#packages li:nth-child(odd){border-right:1px solid #deded9}' +
      '#packages li:nth-child(even){padding-left:1.3rem}' +
      '.package-name{display:inline-block;font-size:1.04rem;overflow-wrap:anywhere}' +
      '.publisher,.evidence,code{display:inline-block;margin:.35rem .25rem 0 0;padding:.12rem .38rem;border-radius:.25rem;background:#ecece8;color:#555752;font-size:.72rem}' +
      '.publisher{background:#e2f0ec;color:#176b5d}' +
      '#packages li p{min-height:3em;margin:.8rem 0;color:#656762;font-size:.91rem}' +
      '.repository{font-size:.86rem;font-weight:650}' +
      '.empty{padding:2rem 0;color:#656762;border-bottom:1px solid #deded9}' +
      '.site-footer{max-width:1040px;margin:auto;padding:1.5rem 1.25rem;border-top:1px solid #deded9;color:#777973;font-size:.82rem;display:flex;justify-content:space-between;gap:1rem}' +
      '[hidden]{display:none!important}' +
      '@media(max-width:820px){.controls{grid-template-columns:repeat(2,1fr)}.controls label:first-child{grid-column:1/-1}}' +
      '@media(max-width:640px){.intro{padding:3rem 0 2.25rem}.site-header nav a:first-child{display:none}.submission{grid-template-columns:1fr}.controls,#packages{grid-template-columns:1fr}#packages li:nth-child(odd){border-right:0}#packages li:nth-child(even){padding-left:0}.site-footer{display:block}}' +
      '</style></head><body><header class="site-header"><div>' +
      '<a class="brand" href=".">Boss4D</a><nav aria-label="Main navigation">' +
      '<a href="https://github.com/regyssilveira/Boss4Delphi">Project</a>' +
      '<a href="https://github.com/regyssilveira/Boss4Delphi#readme">Documentation</a>' +
      '</nav></div></header><main><section class="intro">' +
      '<p class="eyebrow">Public registry · Protocol v' +
      LSchemaVersion.ToString + '</p><h1>Packages for Delphi and Lazarus.</h1>' +
      '<p class="lede">A community catalog with clear publisher identity, version evidence and review before publication.</p>' +
      '</section>' +
      '<section class="stats" aria-label="Catalog statistics">' +
      '<div class="stat"><strong id="visible-count" aria-live="polite">' +
      LPackages.Count.ToString + '</strong>packages</div>' +
      '<div class="stat"><strong>' + LVersionCount.ToString +
      '</strong>versions</div><div class="stat"><strong>' +
      LRegisteredCount.ToString + '</strong>registered</div>' +
      '<div class="stat"><strong>' + LVerifiedCount.ToString +
      '</strong>verified</div><div class="stat"><strong>' +
      (LPackages.Count - LVerifiedCount).ToString +
      '</strong>legacy</div><div class="stat"><strong>' +
      LMigrationPercentage.ToString + '%</strong>migration</div>' +
      '</section><section id="community-submit" class="submission" aria-labelledby="community-submit-title">' +
      '<div><h2 id="community-submit-title">Add your package</h2>' +
      '<p>Submissions go through identity and evidence checks, followed by maintainer review. Nothing is published automatically.</p></div>' +
      '<a class="button" href="https://github.com/regyssilveira/Boss4Delphi/issues/new?template=registry-package-submission.yml">Submit for review</a>' +
      '</section><div class="catalog-heading"><h2>Catalog</h2>' +
      '<p>Filter by name, trust, platform or compiler.</p></div>' +
      '<section class="controls" aria-label="Package filters">' +
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
          PackageSelectorData(LPackage, 'compiler')) +
        '"><strong class="package-name">' +
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
                Result := Result + ' <span class="evidence">SHA-256</span>';
              if not LVersion.GetValue<string>('signature', '').IsEmpty then
                Result := Result + ' <span class="evidence">signature</span>';
              if not LVersion.GetValue<string>('provenance', '').IsEmpty then
                Result := Result + ' <span class="evidence">provenance</span>';
              Result := Result + '</div>';
            end;
        end
        else if not LPackage.GetValue<string>('version', '').IsEmpty then
          Result := Result + ' <code>' +
            EscapeHtml(LPackage.GetValue<string>('version', '')) + '</code>';
      end;
      Result := Result + '<p>' +
        EscapeHtml(LPackage.GetValue<string>('description', '')) +
        '</p><a class="repository" href="https://' +
        EscapeHtml(LPackage.GetValue<string>('repository', '')) +
        '">View repository</a></li>';
    end;
    Result := Result + '</ul><p id="empty-state" class="empty" hidden>No packages match these filters.</p></main>' +
      '<footer class="site-footer"><span>Boss4D Public Registry</span>' +
      '<span>Community maintained · Reviewed submissions</span></footer><script>' +
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
      'document.getElementById("visible-count").textContent=visible;' +
      'document.getElementById("empty-state").hidden=visible!==0;}' +
      '[search,trust,migration,platform,compiler].forEach(x=>x.addEventListener("input",apply));' +
      '</script></body></html>';
  finally
    LRoot.Free;
  end;
end;

end.
