unit Boss4D.Adapters.Sbom.CycloneDX;

interface

uses
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Sbom;

type
  TBoss4DCycloneDXWriter = class(TInterfacedObject, IBoss4DSbomWriter)
  public
    function Serialize(const ADocument: TBoss4DSbomDocument;
      const AReproducible: Boolean = False): string;
    function Validate(const AContent: string; out AError: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  System.DateUtils;

function ComponentTypeName(const AType: TBoss4DSbomComponentType): string;
begin
  case AType of
    ApplicationComponent: Result := 'application';
    LibraryComponent: Result := 'library';
    FrameworkComponent: Result := 'framework';
    ToolComponent: Result := 'application';
    FileComponent: Result := 'file';
  else
    Result := 'application';
  end;
end;

function ReferenceTypeName(const AType: TBoss4DSbomReferenceType): string;
begin
  case AType of
    VCS: Result := 'vcs';
    Website: Result := 'website';
    Distribution: Result := 'distribution';
    Documentation: Result := 'documentation';
  else
    Result := 'other';
  end;
end;

function AggregateName(const ACompleteness: TBoss4DSbomCompleteness): string;
begin
  case ACompleteness of
    Complete: Result := 'complete';
    Incomplete: Result := 'incomplete';
  else
    Result := 'unknown';
  end;
end;

function ComponentToJSON(const AComponent: TBoss4DSbomComponent): TJSONObject;
var
  LArray: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('bom-ref', AComponent.Id);
  Result.AddPair('type', ComponentTypeName(AComponent.ComponentType));
  Result.AddPair('name', AComponent.Name);
  if not AComponent.Version.IsEmpty then
    Result.AddPair('version', AComponent.Version);
  if not AComponent.Description.IsEmpty then
    Result.AddPair('description', AComponent.Description);

  if AComponent.Hashes.Count > 0 then
  begin
    LArray := TJSONArray.Create;
    for var LHash in AComponent.Hashes do
    begin
      var LHashObj := TJSONObject.Create;
      LHashObj.AddPair('alg', LHash.Algorithm);
      LHashObj.AddPair('content', LHash.Value);
      LArray.AddElement(LHashObj);
    end;
    Result.AddPair('hashes', LArray);
  end;

  if AComponent.Licenses.Count > 0 then
  begin
    LArray := TJSONArray.Create;
    for var LLicense in AComponent.Licenses do
    begin
      var LChoice := TJSONObject.Create;
      if LLicense.Kind = SpdxExpressionLicense then
        LChoice.AddPair('expression', LLicense.Expression)
      else
      begin
        var LLicenseObj := TJSONObject.Create;
        if not LLicense.Name.IsEmpty then
          LLicenseObj.AddPair('name', LLicense.Name)
        else
          LLicenseObj.AddPair('name', 'NOASSERTION');
        LChoice.AddPair('license', LLicenseObj);
      end;
      LArray.AddElement(LChoice);
    end;
    Result.AddPair('licenses', LArray);
  end;

  if AComponent.ExternalReferences.Count > 0 then
  begin
    LArray := TJSONArray.Create;
    for var LReference in AComponent.ExternalReferences do
    begin
      var LRefObj := TJSONObject.Create;
      LRefObj.AddPair('type', ReferenceTypeName(LReference.ReferenceType));
      LRefObj.AddPair('url', LReference.URL);
      LArray.AddElement(LRefObj);
    end;
    Result.AddPair('externalReferences', LArray);
  end;

  if AComponent.Properties.Count > 0 then
  begin
    LArray := TJSONArray.Create;
    var LPropertyNames := TList<string>.Create;
    try
      for var LPropertyName in AComponent.Properties.Keys do
        LPropertyNames.Add(LPropertyName);
      LPropertyNames.Sort;
      for var LPropertyName in LPropertyNames do
      begin
        var LPropertyObj := TJSONObject.Create;
        LPropertyObj.AddPair('name', LPropertyName);
        LPropertyObj.AddPair('value', AComponent.Properties[LPropertyName]);
        LArray.AddElement(LPropertyObj);
      end;
    finally
      LPropertyNames.Free;
    end;
    Result.AddPair('properties', LArray);
  end;
end;

function NewSerialNumber: string;
begin
  Result := 'urn:uuid:' + TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').ToLower;
end;

function TBoss4DCycloneDXWriter.Serialize(const ADocument: TBoss4DSbomDocument;
  const AReproducible: Boolean = False): string;
var
  LRoot: TJSONObject;
  LMetadata: TJSONObject;
  LArray: TJSONArray;
  LRootComponent: TBoss4DSbomComponent;
begin
  if not Assigned(ADocument) then
    raise EArgumentNilException.Create('ADocument');
  LRootComponent := ADocument.FindComponent(ADocument.RootComponentId);
  if not Assigned(LRootComponent) then
    raise EArgumentException.Create('O componente raiz do SBOM nao foi encontrado.');

  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('$schema', 'https://cyclonedx.org/schema/bom-1.7.schema.json');
    LRoot.AddPair('bomFormat', 'CycloneDX');
    LRoot.AddPair('specVersion', '1.7');
    if not AReproducible then
      LRoot.AddPair('serialNumber', NewSerialNumber);
    LRoot.AddPair('version', TJSONNumber.Create(1));

    LMetadata := TJSONObject.Create;
    if not AReproducible then
      LMetadata.AddPair('timestamp',
        FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(Now)));
    LArray := TJSONArray.Create;
    var LLifecycle := TJSONObject.Create;
    LLifecycle.AddPair('phase', ADocument.Lifecycle);
    LArray.AddElement(LLifecycle);
    LMetadata.AddPair('lifecycles', LArray);

    var LTools := TJSONObject.Create;
    LArray := TJSONArray.Create;
    var LTool := TJSONObject.Create;
    LTool.AddPair('type', 'application');
    LTool.AddPair('name', ADocument.ToolName);
    LTool.AddPair('version', ADocument.ToolVersion);
    LArray.AddElement(LTool);
    LTools.AddPair('components', LArray);
    LMetadata.AddPair('tools', LTools);
    LMetadata.AddPair('component', ComponentToJSON(LRootComponent));
    LRoot.AddPair('metadata', LMetadata);

    LArray := TJSONArray.Create;
    for var LComponent in ADocument.Components do
      if not SameText(LComponent.Id, ADocument.RootComponentId) then
        LArray.AddElement(ComponentToJSON(LComponent));
    LRoot.AddPair('components', LArray);

    LArray := TJSONArray.Create;
    for var LRelationship in ADocument.Relationships do
    begin
      var LDependencyObj := TJSONObject.Create;
      LDependencyObj.AddPair('ref', LRelationship.ComponentId);
      var LDependsOn := TJSONArray.Create;
      for var LTarget in LRelationship.DependsOn do
        LDependsOn.Add(LTarget);
      LDependencyObj.AddPair('dependsOn', LDependsOn);
      LArray.AddElement(LDependencyObj);
    end;
    LRoot.AddPair('dependencies', LArray);

    LArray := TJSONArray.Create;
    var LComposition := TJSONObject.Create;
    LComposition.AddPair('aggregate', AggregateName(ADocument.Completeness));
    var LAssemblies := TJSONArray.Create;
    LAssemblies.Add(ADocument.RootComponentId);
    LComposition.AddPair('assemblies', LAssemblies);
    var LCompositionDependencies := TJSONArray.Create;
    LCompositionDependencies.Add(ADocument.RootComponentId);
    LComposition.AddPair('dependencies', LCompositionDependencies);
    LArray.AddElement(LComposition);
    LRoot.AddPair('compositions', LArray);

    LArray := TJSONArray.Create;
    var LCoverage := TJSONObject.Create;
    LCoverage.AddPair('name', 'boss4d:coverage');
    LCoverage.AddPair('value', ADocument.Coverage);
    LArray.AddElement(LCoverage);
    for var I := 0 to ADocument.Issues.Count - 1 do
    begin
      var LIssue := TJSONObject.Create;
      LIssue.AddPair('name', Format('boss4d:issue:%d', [I + 1]));
      LIssue.AddPair('value', ADocument.Issues[I]);
      LArray.AddElement(LIssue);
    end;
    LRoot.AddPair('properties', LArray);

    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

function TBoss4DCycloneDXWriter.Validate(const AContent: string; out AError: string): Boolean;
var
  LValue: TJSONValue;
  LRoot: TJSONObject;
  LKnownRefs: TDictionary<string, Boolean>;
begin
  AError := '';
  Result := False;
  LValue := TJSONObject.ParseJSONValue(AContent);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    AError := 'O conteudo nao e um objeto JSON.';
    Exit;
  end;
  LRoot := TJSONObject(LValue);
  LKnownRefs := TDictionary<string, Boolean>.Create;
  try
    if LRoot.GetValue<string>('bomFormat', '') <> 'CycloneDX' then
      raise EConvertError.Create('bomFormat deve ser CycloneDX.');
    if LRoot.GetValue<string>('specVersion', '') <> '1.7' then
      raise EConvertError.Create('specVersion deve ser 1.7.');

    var LMetadata := LRoot.GetValue<TJSONObject>('metadata');
    if not Assigned(LMetadata) then
      raise EConvertError.Create('metadata e obrigatorio.');
    var LMetadataComponent := LMetadata.GetValue<TJSONObject>('component');
    if not Assigned(LMetadataComponent) then
      raise EConvertError.Create('metadata.component e obrigatorio.');
    var LRootRef := LMetadataComponent.GetValue<string>('bom-ref', '');
    if LRootRef.IsEmpty then
      raise EConvertError.Create('metadata.component.bom-ref e obrigatorio.');
    LKnownRefs.Add(LRootRef, True);

    var LComponents := LRoot.GetValue<TJSONArray>('components');
    if Assigned(LComponents) then
      for var I := 0 to LComponents.Count - 1 do
      begin
        if not (LComponents[I] is TJSONObject) then
          raise EConvertError.Create('components contem item invalido.');
        var LRef := TJSONObject(LComponents[I]).GetValue<string>('bom-ref', '');
        if LRef.IsEmpty then
          raise EConvertError.Create('Componente sem bom-ref.');
        if LKnownRefs.ContainsKey(LRef) then
          raise EConvertError.Create('bom-ref duplicado: ' + LRef);
        LKnownRefs.Add(LRef, True);
      end;

    var LDependencies := LRoot.GetValue<TJSONArray>('dependencies');
    if Assigned(LDependencies) then
      for var I := 0 to LDependencies.Count - 1 do
      begin
        var LDependency := LDependencies[I] as TJSONObject;
        var LRef := LDependency.GetValue<string>('ref', '');
        if not LKnownRefs.ContainsKey(LRef) then
          raise EConvertError.Create('Relacao com ref desconhecido: ' + LRef);
        var LDependsOn := LDependency.GetValue<TJSONArray>('dependsOn');
        if Assigned(LDependsOn) then
          for var J := 0 to LDependsOn.Count - 1 do
            if not LKnownRefs.ContainsKey(LDependsOn[J].Value) then
              raise EConvertError.Create('Relacao aponta para ref desconhecido: ' + LDependsOn[J].Value);
      end;
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
  end;
  LKnownRefs.Free;
  LRoot.Free;
end;

end.
