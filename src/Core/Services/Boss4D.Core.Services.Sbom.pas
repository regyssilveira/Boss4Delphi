unit Boss4D.Core.Services.Sbom;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.Sbom;

type
  EBoss4DSbomValidation = class(Exception);

  TBoss4DSbomOptions = record
    StrictMode: Boolean;
    ValidateOutput: Boolean;
    ReproducibleOutput: Boolean;
    LockOnly: Boolean;
    HasRootComponentType: Boolean;
    RootComponentType: TBoss4DSbomComponentType;
    OutputFormat: string;
  end;

  TBoss4DSbomBuilder = class
  private
    function RootComponentId(const APackage: TBoss4DPackage): string;
    function LockedComponentId(const ADependency: TBoss4DLockedDependency): string;
    procedure AddIssue(const ADocument: TBoss4DSbomDocument; const AMessage: string;
      const AStrict: Boolean);
  public
    function Build(const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
      const AStrict: Boolean = False): TBoss4DSbomDocument;
  end;

  TBoss4DSbomService = class
  private
    FPackageRepository: IBoss4DPackageRepository;
    FLockRepository: IBoss4DLockRepository;
    FWriter: IBoss4DSbomWriter;
    FCollectors: TList<IBoss4DSbomCollector>;
    FTransformers: TList<IBoss4DSbomTransformer>;
    FSigner: IBoss4DSbomSigner;
  public
    constructor Create(const APackageRepository: IBoss4DPackageRepository;
      const ALockRepository: IBoss4DLockRepository; const AWriter: IBoss4DSbomWriter);
    destructor Destroy; override;
    procedure AddCollector(const ACollector: IBoss4DSbomCollector);
    procedure AddTransformer(const ATransformer: IBoss4DSbomTransformer);
    procedure SetSigner(const ASigner: IBoss4DSbomSigner);
    function Generate(const APackagePath, ALockPath: string;
      const AOptions: TBoss4DSbomOptions): string;
  end;

implementation

uses
  System.IOUtils,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.License;

function NormalizeIdPart(const AValue: string): string;
begin
  Result := AValue.Trim.ToLower.Replace(' ', '-');
end;

function ManualComponentType(const AValue: string): TBoss4DSbomComponentType;
begin
  if SameText(AValue, 'application') then Exit(ApplicationComponent);
  if SameText(AValue, 'framework') then Exit(FrameworkComponent);
  if SameText(AValue, 'tool') then Exit(ToolComponent);
  if SameText(AValue, 'file') then Exit(FileComponent);
  Result := LibraryComponent;
end;

function TBoss4DSbomBuilder.RootComponentId(const APackage: TBoss4DPackage): string;
begin
  Result := 'boss4d:root:' + NormalizeIdPart(APackage.Name) + '@' + NormalizeIdPart(APackage.Version);
end;

function TBoss4DSbomBuilder.LockedComponentId(const ADependency: TBoss4DLockedDependency): string;
var
  LIdentityVersion: string;
begin
  LIdentityVersion := ADependency.Revision;
  if LIdentityVersion.IsEmpty then
    LIdentityVersion := ADependency.Version;
  Result := 'boss4d:git:' + NormalizeIdPart(ADependency.Repository) + '@' +
    NormalizeIdPart(LIdentityVersion);
end;

procedure TBoss4DSbomBuilder.AddIssue(const ADocument: TBoss4DSbomDocument;
  const AMessage: string; const AStrict: Boolean);
begin
  if AStrict then
    raise EBoss4DSbomValidation.Create(AMessage);
  ADocument.Issues.Add(AMessage);
end;

function TBoss4DSbomBuilder.Build(const APackage: TBoss4DPackage; const ALock: TBoss4DLock;
  const AStrict: Boolean = False): TBoss4DSbomDocument;
var
  LIdByLockKey: TDictionary<string, string>;
  LInstalledKeys: TList<string>;
  LDeclaredKeys: TList<string>;
  LDependencyKeys: TList<string>;
  LRoot: TBoss4DSbomComponent;
  LRootRelation: TBoss4DSbomRelationship;
begin
  if not Assigned(APackage) then
    raise EArgumentNilException.Create('APackage');
  if not Assigned(ALock) then
    raise EArgumentNilException.Create('ALock');

  Result := TBoss4DSbomDocument.Create;
  LIdByLockKey := TDictionary<string, string>.Create;
  LInstalledKeys := TList<string>.Create;
  LDeclaredKeys := TList<string>.Create;
  LDependencyKeys := TList<string>.Create;
  try
    try
      Result.ToolName := 'Boss4D';
    Result.ToolVersion := '1.0.1';
    Result.Lifecycle := 'build';
    Result.Coverage := 'boss-managed-dependencies';
    Result.Completeness := Incomplete;

    if ALock.LockVersion < TBoss4DLockSchema.CurrentVersion then
      AddIssue(Result, 'O lock v1 nao contem metadados suficientes para um SBOM auditavel.', AStrict);

    LRoot := TBoss4DSbomComponent.Create;
    LRoot.Id := RootComponentId(APackage);
    LRoot.Name := APackage.Name;
    LRoot.Version := APackage.Version;
    LRoot.Description := APackage.Description;
    LRoot.ComponentType := ApplicationComponent;
    if not APackage.Homepage.IsEmpty then
    begin
      var LHomepage := TBoss4DSbomExternalReference.Create;
      LHomepage.ReferenceType := Website;
      LHomepage.URL := APackage.Homepage;
      LRoot.ExternalReferences.Add(LHomepage);
    end;
    if not APackage.License.IsEmpty then
      LRoot.Licenses.Add(TBoss4DLicenseNormalizer.Normalize(APackage.License, 'boss.json'));
    Result.RootComponentId := LRoot.Id;
    Result.Components.Add(LRoot);

    for var LInstalledKey in ALock.Installed.Keys do
      LInstalledKeys.Add(LInstalledKey);
    LInstalledKeys.Sort;

    for var LInstalledKey in LInstalledKeys do
    begin
      var LLocked := ALock.Installed[LInstalledKey];
      if LLocked.Repository.IsEmpty then
        AddIssue(Result, 'Dependencia sem repositorio: ' + LLocked.Name, AStrict);
      if LLocked.Revision.IsEmpty then
        AddIssue(Result, 'Dependencia sem revisao resolvida: ' + LLocked.Name, AStrict);
      if LLocked.Checksum.IsEmpty then
        AddIssue(Result, 'Dependencia sem checksum: ' + LLocked.Name, AStrict);

      var LComponent := TBoss4DSbomComponent.Create;
      LComponent.Id := LockedComponentId(LLocked);
      LComponent.Name := LLocked.Name;
      LComponent.Version := LLocked.Version;
      LComponent.Revision := LLocked.Revision;
      LComponent.ComponentType := LibraryComponent;
      LComponent.Properties.AddOrSetValue('boss4d:resolvedFrom', LLocked.ResolvedFrom);
      LComponent.Properties.AddOrSetValue('boss4d:lockKey', LInstalledKey);

      if not LLocked.Checksum.IsEmpty then
      begin
        var LHash := TBoss4DSbomHash.Create;
        LHash.Algorithm := LLocked.ChecksumAlgorithm;
        LHash.Value := LLocked.Checksum;
        LComponent.Hashes.Add(LHash);
      end;
      if not LLocked.LicenseExpression.IsEmpty then
        LComponent.Licenses.Add(TBoss4DLicenseNormalizer.Normalize(
          LLocked.LicenseExpression, LLocked.LicenseSource));
      if not LLocked.Repository.IsEmpty then
      begin
        var LVCS := TBoss4DSbomExternalReference.Create;
        LVCS.ReferenceType := VCS;
        LVCS.URL := LLocked.Repository;
        LComponent.ExternalReferences.Add(LVCS);
      end;

      Result.Components.Add(LComponent);
      LIdByLockKey.AddOrSetValue(LInstalledKey.ToLower, LComponent.Id);
      if not LLocked.Repository.IsEmpty then
        LIdByLockKey.AddOrSetValue(LLocked.Repository.ToLower, LComponent.Id);
    end;

    for var LManual in APackage.SbomComponents do
    begin
      if LManual.Name.IsEmpty then
      begin
        AddIssue(Result, 'Componente SBOM manual sem nome.', AStrict);
        Continue;
      end;
      if LManual.Version.IsEmpty then
        AddIssue(Result, 'Componente SBOM manual sem versao: ' + LManual.Name, AStrict);

      var LManualComponent := TBoss4DSbomComponent.Create;
      if not LManual.Id.IsEmpty then
        LManualComponent.Id := 'boss4d:manual:' + NormalizeIdPart(LManual.Id)
      else
        LManualComponent.Id := 'boss4d:manual:' + NormalizeIdPart(LManual.Name) + '@' +
          NormalizeIdPart(LManual.Version);
      LManualComponent.Name := LManual.Name;
      LManualComponent.Version := LManual.Version;
      LManualComponent.Description := LManual.Description;
      LManualComponent.ComponentType := ManualComponentType(LManual.ComponentType);
      LManualComponent.Properties.AddOrSetValue('boss4d:declaredBy', 'boss.json');
      if not LManual.Source.IsEmpty then
      begin
        LManualComponent.Properties.AddOrSetValue('boss4d:source', LManual.Source.ToLower);
        LManualComponent.Properties.AddOrSetValue('boss4d:usage', 'declared');
      end;
      if not LManual.License.IsEmpty then
        LManualComponent.Licenses.Add(TBoss4DLicenseNormalizer.Normalize(
          LManual.License, 'boss.json:sbom.components'));
      if not LManual.Repository.IsEmpty then
      begin
        var LManualVCS := TBoss4DSbomExternalReference.Create;
        LManualVCS.ReferenceType := VCS;
        LManualVCS.URL := LManual.Repository;
        LManualComponent.ExternalReferences.Add(LManualVCS);
      end;
      if not LManual.HashValue.IsEmpty then
      begin
        var LManualHash := TBoss4DSbomHash.Create;
        LManualHash.Algorithm := LManual.HashAlgorithm;
        LManualHash.Value := LManual.HashValue;
        LManualComponent.Hashes.Add(LManualHash);
      end;
      Result.Components.Add(LManualComponent);
    end;

    LRootRelation := TBoss4DSbomRelationship.Create;
    LRootRelation.ComponentId := LRoot.Id;
    Result.Relationships.Add(LRootRelation);
    for var LDeclaredKey in APackage.Dependencies.Keys do
      LDeclaredKeys.Add(LDeclaredKey);
    LDeclaredKeys.Sort;
    for var LDeclaredKey in LDeclaredKeys do
    begin
      var LDeclared := TBoss4DDependency.Parse(LDeclaredKey, APackage.Dependencies[LDeclaredKey]);
      try
        var LLockedDependency: TBoss4DLockedDependency;
        if ALock.GetInstalled(LDeclared, LLockedDependency) then
          LRootRelation.DependsOn.Add(LockedComponentId(LLockedDependency))
        else
          AddIssue(Result, 'Dependencia declarada nao encontrada no lock: ' + LDeclaredKey, AStrict);
      finally
        LDeclared.Free;
      end;
    end;
    for var LManual in APackage.SbomComponents do
    begin
      var LManualId: string;
      if not LManual.Id.IsEmpty then
        LManualId := 'boss4d:manual:' + NormalizeIdPart(LManual.Id)
      else
        LManualId := 'boss4d:manual:' + NormalizeIdPart(LManual.Name) + '@' +
          NormalizeIdPart(LManual.Version);
      if Assigned(Result.FindComponent(LManualId)) then
        LRootRelation.DependsOn.Add(LManualId);
    end;

    for var LInstalledKey in LInstalledKeys do
    begin
      var LLocked := ALock.Installed[LInstalledKey];
      var LRelationship := TBoss4DSbomRelationship.Create;
      LRelationship.ComponentId := LockedComponentId(LLocked);
      Result.Relationships.Add(LRelationship);
      LDependencyKeys.Clear;
      LDependencyKeys.AddRange(LLocked.Dependencies);
      LDependencyKeys.Sort;
      for var LDependencyKey in LDependencyKeys do
      begin
        var LTargetId: string;
        if LIdByLockKey.TryGetValue(LDependencyKey.ToLower, LTargetId) then
          LRelationship.DependsOn.Add(LTargetId)
        else
          AddIssue(Result, Format('Relacao aponta para componente ausente: %s -> %s',
            [LInstalledKey, LDependencyKey]), AStrict);
      end;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    LDependencyKeys.Free;
    LDeclaredKeys.Free;
    LInstalledKeys.Free;
    LIdByLockKey.Free;
  end;
end;

constructor TBoss4DSbomService.Create(const APackageRepository: IBoss4DPackageRepository;
  const ALockRepository: IBoss4DLockRepository; const AWriter: IBoss4DSbomWriter);
begin
  inherited Create;
  FPackageRepository := APackageRepository;
  FLockRepository := ALockRepository;
  FWriter := AWriter;
  FCollectors := TList<IBoss4DSbomCollector>.Create;
  FTransformers := TList<IBoss4DSbomTransformer>.Create;
end;

destructor TBoss4DSbomService.Destroy;
begin
  FTransformers.Free;
  FCollectors.Free;
  inherited Destroy;
end;

procedure TBoss4DSbomService.AddTransformer(const ATransformer: IBoss4DSbomTransformer);
begin
  if Assigned(ATransformer) then FTransformers.Add(ATransformer);
end;

procedure TBoss4DSbomService.SetSigner(const ASigner: IBoss4DSbomSigner);
begin
  FSigner := ASigner;
end;

procedure TBoss4DSbomService.AddCollector(const ACollector: IBoss4DSbomCollector);
begin
  if Assigned(ACollector) then
    FCollectors.Add(ACollector);
end;

function TBoss4DSbomService.Generate(const APackagePath, ALockPath: string;
  const AOptions: TBoss4DSbomOptions): string;
var
  LPackage: TBoss4DPackage;
  LLock: TBoss4DLock;
  LBuilder: TBoss4DSbomBuilder;
  LDocument: TBoss4DSbomDocument;
  LValidationError: string;
  LGetItCollected, LToolchainCollected, LArtifactsCollected: Boolean;
  LProjectDirectory: string;
begin
  if not FLockRepository.Exists(ALockPath) then
    raise EBoss4DSbomValidation.Create('Arquivo boss-lock.json nao encontrado: ' + ALockPath);

  LLock := FLockRepository.Load(ALockPath);
  if AOptions.LockOnly then
  begin
    LPackage := TBoss4DPackage.Create;
    if LLock.HasRootMetadata then
    begin
      LPackage.Name := LLock.RootName;
      LPackage.Version := LLock.RootVersion;
      LPackage.Description := LLock.RootDescription;
      LPackage.Homepage := LLock.RootHomepage;
      LPackage.License := LLock.RootLicense;
      for var LRootDependency in LLock.RootDependencies do
        LPackage.Dependencies.AddOrSetValue(LRootDependency, '*');
    end
    else if AOptions.StrictMode then
    begin
      LPackage.Free;
      LLock.Free;
      raise EBoss4DSbomValidation.Create(
        'Lock-only estrito requer metadados root no boss-lock.json v2. Execute boss4d install.');
    end
    else
    begin
      LPackage.Name := TPath.GetFileName(TPath.GetDirectoryName(TPath.GetFullPath(ALockPath)));
      LPackage.Version := '';
    end;
    LProjectDirectory := TPath.GetDirectoryName(TPath.GetFullPath(ALockPath));
  end
  else
  begin
    if not FPackageRepository.Exists(APackagePath) then
    begin
      LLock.Free;
      raise EBoss4DSbomValidation.Create('Arquivo boss.json nao encontrado: ' + APackagePath);
    end;
    LPackage := FPackageRepository.Load(APackagePath);
    LProjectDirectory := TPath.GetDirectoryName(TPath.GetFullPath(APackagePath));
  end;
  LBuilder := TBoss4DSbomBuilder.Create;
  LGetItCollected := False;
  LToolchainCollected := False;
  LArtifactsCollected := False;
  try
    LDocument := LBuilder.Build(LPackage, LLock, AOptions.StrictMode);
    try
      for var LCollector in FCollectors do
        try
          var LIssueCountBefore := LDocument.Issues.Count;
          LCollector.Collect(LDocument, LPackage, LLock,
            LProjectDirectory);
          if AOptions.StrictMode and (LDocument.Issues.Count > LIssueCountBefore) then
            raise EBoss4DSbomValidation.Create(LDocument.Issues[LIssueCountBefore]);
          if SameText(LCollector.Name, 'getit') then LGetItCollected := True;
          if SameText(LCollector.Name, 'delphi-toolchain') then LToolchainCollected := True;
          if SameText(LCollector.Name, 'binary-artifacts') then LArtifactsCollected := True;
        except
          on E: Exception do
            if AOptions.StrictMode then
              raise EBoss4DSbomValidation.CreateFmt('Coletor %s falhou: %s',
                [LCollector.Name, E.Message])
            else
              LDocument.Issues.Add(Format('Coletor %s indisponivel: %s',
                [LCollector.Name, E.Message]));
        end;
      if LGetItCollected and LToolchainCollected and LArtifactsCollected and
         (LDocument.Issues.Count = 0) then
        LDocument.Completeness := Complete
      else
        LDocument.Completeness := Incomplete;
      for var LTransformer in FTransformers do
        LTransformer.Transform(LDocument);
      if AOptions.HasRootComponentType then
        LDocument.FindComponent(LDocument.RootComponentId).ComponentType := AOptions.RootComponentType;
      Result := FWriter.Serialize(LDocument, AOptions.ReproducibleOutput);
      if AOptions.ValidateOutput and not FWriter.Validate(Result, LValidationError) then
        raise EBoss4DSbomValidation.Create('SBOM invalido: ' + LValidationError);
      if Assigned(FSigner) then
        Result := FSigner.Sign(Result, AOptions.OutputFormat);
    finally
      LDocument.Free;
    end;
  finally
    LBuilder.Free;
    LLock.Free;
    LPackage.Free;
  end;
end;

end.
