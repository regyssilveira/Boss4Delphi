unit Boss4D.Adapters.Sbom.Spdx;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Sbom;

type
  TBoss4DSpdxWriter = class(TInterfacedObject, IBoss4DSbomWriter)
  public
    function Serialize(const ADocument: TBoss4DSbomDocument;
      const AReproducible: Boolean = False): string;
    function Validate(const AContent: string; out AError: string): Boolean;
  end;

implementation

uses
  System.SysUtils, System.JSON, System.DateUtils, System.Hash,
  System.Generics.Collections, System.Generics.Defaults;

function SpdxId(const AId: string): string;
begin
  Result := 'SPDXRef-' + THashSHA2.GetHashString(AId).Substring(0, 20);
end;

function DeclaredLicense(const AComponent: TBoss4DSbomComponent): string;
begin
  Result := 'NOASSERTION';
  for var LLicense in AComponent.Licenses do
    if (LLicense.Kind = SpdxExpressionLicense) and not LLicense.Expression.IsEmpty then
      Exit(LLicense.Expression);
end;

function ComponentPackage(const AComponent: TBoss4DSbomComponent): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AComponent.Name);
  Result.AddPair('SPDXID', SpdxId(AComponent.Id));
  if not AComponent.Version.IsEmpty then Result.AddPair('versionInfo', AComponent.Version);
  Result.AddPair('downloadLocation', 'NOASSERTION');
  Result.AddPair('filesAnalyzed', TJSONFalse.Create);
  Result.AddPair('licenseConcluded', 'NOASSERTION');
  Result.AddPair('licenseDeclared', DeclaredLicense(AComponent));
  Result.AddPair('copyrightText', 'NOASSERTION');
  if not AComponent.Description.IsEmpty then Result.AddPair('description', AComponent.Description);
  if AComponent.Hashes.Count > 0 then
  begin
    var LChecksums := TJSONArray.Create;
    for var LHash in AComponent.Hashes do
    begin
      var LChecksum := TJSONObject.Create;
      LChecksum.AddPair('algorithm', LHash.Algorithm.Replace('-', '').ToUpper);
      LChecksum.AddPair('checksumValue', LHash.Value.ToLower);
      LChecksums.AddElement(LChecksum);
    end;
    Result.AddPair('checksums', LChecksums);
  end;
end;

function TBoss4DSpdxWriter.Serialize(const ADocument: TBoss4DSbomDocument;
  const AReproducible: Boolean): string;
var
  LRoot: TJSONObject;
  LCreation: TJSONObject;
  LCreators, LPackages, LRelationships: TJSONArray;
  LComponents: TList<TBoss4DSbomComponent>;
begin
  LRoot := TJSONObject.Create;
  LComponents := TList<TBoss4DSbomComponent>.Create;
  try
    LRoot.AddPair('spdxVersion', 'SPDX-2.3');
    LRoot.AddPair('dataLicense', 'CC0-1.0');
    LRoot.AddPair('SPDXID', 'SPDXRef-DOCUMENT');
    var LRootComponent := ADocument.FindComponent(ADocument.RootComponentId);
    LRoot.AddPair('name', LRootComponent.Name + '-sbom');
    LRoot.AddPair('documentNamespace', 'https://boss4d.dev/spdx/' +
      THashSHA2.GetHashString(ADocument.RootComponentId).ToLower);
    var LDescribed := TJSONArray.Create;
    LDescribed.Add(SpdxId(ADocument.RootComponentId));
    LRoot.AddPair('documentDescribes', LDescribed);

    LCreation := TJSONObject.Create;
    LCreators := TJSONArray.Create;
    LCreators.Add('Tool: ' + ADocument.ToolName + '-' + ADocument.ToolVersion);
    LCreation.AddPair('creators', LCreators);
    if AReproducible then
      LCreation.AddPair('created', '1970-01-01T00:00:00Z')
    else
      LCreation.AddPair('created', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(Now)));
    LRoot.AddPair('creationInfo', LCreation);

    LComponents.AddRange(ADocument.Components);
    LComponents.Sort(TComparer<TBoss4DSbomComponent>.Construct(
      function(const ALeft, ARight: TBoss4DSbomComponent): Integer
      begin Result := CompareText(ALeft.Id, ARight.Id); end));
    LPackages := TJSONArray.Create;
    for var LComponent in LComponents do LPackages.AddElement(ComponentPackage(LComponent));
    LRoot.AddPair('packages', LPackages);

    LRelationships := TJSONArray.Create;
    var LDescribes := TJSONObject.Create;
    LDescribes.AddPair('spdxElementId', 'SPDXRef-DOCUMENT');
    LDescribes.AddPair('relationshipType', 'DESCRIBES');
    LDescribes.AddPair('relatedSpdxElement', SpdxId(ADocument.RootComponentId));
    LRelationships.AddElement(LDescribes);
    for var LRelationship in ADocument.Relationships do
      for var LTarget in LRelationship.DependsOn do
      begin
        var LRelation := TJSONObject.Create;
        LRelation.AddPair('spdxElementId', SpdxId(LRelationship.ComponentId));
        LRelation.AddPair('relationshipType', 'DEPENDS_ON');
        LRelation.AddPair('relatedSpdxElement', SpdxId(LTarget));
        LRelationships.AddElement(LRelation);
      end;
    LRoot.AddPair('relationships', LRelationships);
    Result := LRoot.ToJSON;
  finally
    LComponents.Free;
    LRoot.Free;
  end;
end;

function TBoss4DSpdxWriter.Validate(const AContent: string; out AError: string): Boolean;
var
  LValue: TJSONValue;
  LRoot: TJSONObject;
begin
  Result := False;
  AError := '';
  LValue := TJSONObject.ParseJSONValue(AContent);
  try
    if not (LValue is TJSONObject) then begin AError := 'Raiz SPDX deve ser um objeto JSON.'; Exit; end;
    LRoot := TJSONObject(LValue);
    if LRoot.GetValue<string>('spdxVersion', '') <> 'SPDX-2.3' then begin AError := 'spdxVersion deve ser SPDX-2.3.'; Exit; end;
    if LRoot.GetValue<string>('dataLicense', '') <> 'CC0-1.0' then begin AError := 'dataLicense deve ser CC0-1.0.'; Exit; end;
    if not (LRoot.GetValue('creationInfo') is TJSONObject) then begin AError := 'creationInfo ausente.'; Exit; end;
    if not (LRoot.GetValue('packages') is TJSONArray) then begin AError := 'packages ausente.'; Exit; end;
    if not (LRoot.GetValue('relationships') is TJSONArray) then begin AError := 'relationships ausente.'; Exit; end;
    Result := True;
  finally
    LValue.Free;
  end;
end;

end.
