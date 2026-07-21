unit Boss4D.Adapters.Sbom.Security;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Sbom;

type
  TBoss4DSbomSha256Attestor = class(TInterfacedObject, IBoss4DSbomAttestor)
  public
    function CreateAttestation(const AContent, AFormat: string): string;
    function VerifyAttestation(const AContent, AAttestation: string;
      out AError: string): Boolean;
  end;

  TBoss4DOfflineVexTransformer = class(TInterfacedObject, IBoss4DSbomTransformer)
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    procedure Transform(const ADocument: TBoss4DSbomDocument);
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, System.Hash;

function ContentDigest(const AContent: string): string;
begin
  Result := THashSHA2.GetHashString(AContent).ToLower;
end;

function TBoss4DSbomSha256Attestor.CreateAttestation(const AContent,
  AFormat: string): string;
var
  LRoot, LSubject, LDigest, LPredicate: TJSONObject;
  LSubjects: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('_type', 'https://in-toto.io/Statement/v1');
    LRoot.AddPair('predicateType', 'https://boss4d.dev/attestation/sbom/v1');
    LSubjects := TJSONArray.Create;
    LSubject := TJSONObject.Create;
    LSubject.AddPair('name', 'boss4d-sbom-' + AFormat.ToLower);
    LDigest := TJSONObject.Create;
    LDigest.AddPair('sha256', ContentDigest(AContent));
    LSubject.AddPair('digest', LDigest);
    LSubjects.AddElement(LSubject);
    LRoot.AddPair('subject', LSubjects);
    LPredicate := TJSONObject.Create;
    LPredicate.AddPair('format', AFormat.ToLower);
    LPredicate.AddPair('generator', 'Boss4D');
    LRoot.AddPair('predicate', LPredicate);
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

function TBoss4DSbomSha256Attestor.VerifyAttestation(const AContent,
  AAttestation: string; out AError: string): Boolean;
var
  LValue: TJSONValue;
begin
  Result := False;
  AError := '';
  LValue := TJSONObject.ParseJSONValue(AAttestation);
  try
    if not (LValue is TJSONObject) then begin AError := 'Atestacao deve ser um objeto JSON.'; Exit; end;
    var LSubjects := TJSONObject(LValue).GetValue<TJSONArray>('subject');
    if not Assigned(LSubjects) or (LSubjects.Count <> 1) or
       not (LSubjects[0] is TJSONObject) then begin AError := 'Subject da atestacao ausente.'; Exit; end;
    var LDigest := TJSONObject(LSubjects[0]).GetValue<TJSONObject>('digest');
    if not Assigned(LDigest) then begin AError := 'Digest da atestacao ausente.'; Exit; end;
    var LExpected := LDigest.GetValue<string>('sha256', '');
    if not SameText(LExpected, ContentDigest(AContent)) then begin AError := 'SHA-256 do SBOM nao confere.'; Exit; end;
    Result := True;
  finally
    LValue.Free;
  end;
end;

constructor TBoss4DOfflineVexTransformer.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

procedure TBoss4DOfflineVexTransformer.Transform(const ADocument: TBoss4DSbomDocument);
var
  LValue: TJSONValue;
begin
  if not TFile.Exists(FFileName) then
    raise Exception.Create('Arquivo VEX nao encontrado: ' + FFileName);
  LValue := TJSONObject.ParseJSONValue(TFile.ReadAllText(FFileName, TEncoding.UTF8));
  try
    if not (LValue is TJSONObject) then
      raise Exception.Create('VEX offline deve ser um objeto JSON.');
    var LEntries := TJSONObject(LValue).GetValue<TJSONArray>('vulnerabilities');
    if not Assigned(LEntries) then
      raise Exception.Create('VEX offline nao contem vulnerabilities.');
    for var I := 0 to LEntries.Count - 1 do
    begin
      if not (LEntries[I] is TJSONObject) then
        raise Exception.CreateFmt('Entrada VEX invalida no indice %d.', [I]);
      var LEntry := TJSONObject(LEntries[I]);
      var LId := LEntry.GetValue<string>('id', '');
      var LTarget := LEntry.GetValue<string>('component', '');
      var LState := LEntry.GetValue<string>('state', '').ToLower;
      if LId.IsEmpty or LTarget.IsEmpty or LState.IsEmpty then
        raise Exception.CreateFmt('Entrada VEX incompleta no indice %d.', [I]);
      var LComponent := ADocument.FindComponent(LTarget);
      if not Assigned(LComponent) then
        for var LCandidate in ADocument.Components do
          if SameText(LCandidate.Name, LTarget) then begin LComponent := LCandidate; Break; end;
      if not Assigned(LComponent) then
      begin
        ADocument.Issues.Add('VEX aponta para componente ausente: ' + LTarget);
        Continue;
      end;
      if (LState <> 'affected') and (LState <> 'not_affected') and
         (LState <> 'fixed') and (LState <> 'under_investigation') then
        raise Exception.Create('Estado VEX nao suportado: ' + LState);
      var LVulnerability := TBoss4DSbomVulnerability.Create;
      LVulnerability.Id := LId;
      LVulnerability.ComponentId := LComponent.Id;
      LVulnerability.State := LState;
      LVulnerability.Detail := LEntry.GetValue<string>('detail', '');
      LVulnerability.Source := LEntry.GetValue<string>('source', 'offline-vex');
      ADocument.Vulnerabilities.Add(LVulnerability);
    end;
  finally
    LValue.Free;
  end;
end;

end.
