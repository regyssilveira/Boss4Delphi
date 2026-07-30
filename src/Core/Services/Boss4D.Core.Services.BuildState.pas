unit Boss4D.Core.Services.BuildState;

interface

uses
  Boss4D.Core.Domain.BuildMatrix;

type
  TBoss4DBuildDecisionReason = (
    UpToDate,
    Forced,
    MissingState,
    MissingOutputs,
    SourceChanged,
    DependencyChanged,
    CorruptState
  );

  TBoss4DBuildDecision = record
    ShouldBuild: Boolean;
    Reason: TBoss4DBuildDecisionReason;
    SourceFingerprint: string;
    DependencyFingerprint: string;
    Fingerprint: string;
  end;

  TBoss4DBuildStateService = class
  private
    function SourceFingerprint(const AProjectPath: string): string;
    function DependencyFingerprint(
      const AFingerprints: TArray<string>): string;
    function CombinedFingerprint(const ATarget: TBoss4DBuildTarget;
      const ASourceFingerprint, ADependencyFingerprint: string): string;
    function HasOutputs(const ATargetRoot: string): Boolean;
    function StatePath(const ATarget: TBoss4DBuildTarget;
      const ATargetRoot: string): string;
  public
    function Evaluate(const ATarget: TBoss4DBuildTarget;
      const AProjectPath, ATargetRoot: string;
      const ADependencyFingerprints: TArray<string>;
      const AForce: Boolean): TBoss4DBuildDecision;
    procedure Save(const ATarget: TBoss4DBuildTarget;
      const ATargetRoot: string; const ADecision: TBoss4DBuildDecision);
    function LoadFingerprint(const ATarget: TBoss4DBuildTarget;
      const ATargetRoot: string): string;
    function Explain(const ADecision: TBoss4DBuildDecision): string;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Hash,
  System.NetEncoding,
  System.RegularExpressions,
  System.JSON,
  System.Generics.Collections,
  System.Generics.Defaults;

function IsSourceFile(const AFilePath: string): Boolean;
var
  LExtension: string;
begin
  LExtension := TPath.GetExtension(AFilePath).ToLower;
  Result := (LExtension = '.pas') or (LExtension = '.dpr') or
    (LExtension = '.dpk') or (LExtension = '.dproj') or
    (LExtension = '.inc') or (LExtension = '.dfm') or
    (LExtension = '.fmx') or (LExtension = '.res') or
    (LExtension = '.rc') or (LExtension = '.asm') or
    (LExtension = '.obj') or (LExtension = '.lib');
end;

function HashText(const AValue: string): string;
begin
  Result := THashSHA2.GetHashString(AValue).ToLower;
end;

function TBoss4DBuildStateService.StatePath(
  const ATarget: TBoss4DBuildTarget; const ATargetRoot: string): string;
begin
  var LIdentityHash := HashText(ATarget.Identity.ToLower);
  Result := TPath.Combine(TPath.Combine(ATargetRoot, '.boss4d-state'),
    LIdentityHash.Substring(0, 16) + '.json');
end;

function TBoss4DBuildStateService.SourceFingerprint(
  const AProjectPath: string): string;
var
  LRoot: string;
  LFiles: TList<string>;
  LLogicalNames: TDictionary<string, string>;
  LInput: TStringBuilder;
begin
  if not TFile.Exists(AProjectPath) then
    raise EFileNotFoundException.CreateFmt(
      'Projeto nao encontrado para fingerprint: %s.', [AProjectPath]);
  LRoot := IncludeTrailingPathDelimiter(
    TPath.GetDirectoryName(TPath.GetFullPath(AProjectPath)));
  LFiles := TList<string>.Create;
  LLogicalNames := TDictionary<string, string>.Create;
  LInput := TStringBuilder.Create;
  try
    var LAbsoluteProject := TPath.GetFullPath(AProjectPath);
    LFiles.Add(LAbsoluteProject);
    LLogicalNames.Add(LAbsoluteProject.ToLower,
      TPath.GetFileName(LAbsoluteProject).ToLower);
    for var LFile in TDirectory.GetFiles(LRoot, '*',
      TSearchOption.soAllDirectories) do
      if IsSourceFile(LFile) and
         not LLogicalNames.ContainsKey(LFile.ToLower) then
      begin
        LFiles.Add(LFile);
        LLogicalNames.Add(LFile.ToLower,
          LFile.Substring(Length(LRoot)).Replace('\', '/').ToLower);
      end;

    var LProjectContent := TFile.ReadAllText(LAbsoluteProject,
      TEncoding.UTF8);
    for var LMatch in TRegEx.Matches(LProjectContent,
      'Include\s*=\s*"([^"]+)"',
      [roIgnoreCase]) do
    begin
      var LIncludePath := LMatch.Groups[1].Value.Trim;
      if LIncludePath.Contains('$(') then
        Continue;
      var LIncludedFile := TPath.GetFullPath(TPath.Combine(LRoot,
        LIncludePath.Replace('/', TPath.DirectorySeparatorChar)));
      if TFile.Exists(LIncludedFile) and IsSourceFile(LIncludedFile) and
         not LLogicalNames.ContainsKey(LIncludedFile.ToLower) then
      begin
        LFiles.Add(LIncludedFile);
        LLogicalNames.Add(LIncludedFile.ToLower,
          ('include/' + LIncludePath.Replace('\', '/')).ToLower);
      end;
    end;
    LFiles.Sort(TComparer<string>.Construct(
      function(const ALeft, ARight: string): Integer
      begin
        Result := CompareText(LLogicalNames[ALeft.ToLower],
          LLogicalNames[ARight.ToLower]);
      end));
    for var LFile in LFiles do
    begin
      LInput.Append(LLogicalNames[LFile.ToLower]);
      LInput.Append('=');
      LInput.Append(HashText(TNetEncoding.Base64.EncodeBytesToString(
        TFile.ReadAllBytes(LFile))));
      LInput.AppendLine;
    end;
    Result := HashText(LInput.ToString);
  finally
    LInput.Free;
    LLogicalNames.Free;
    LFiles.Free;
  end;
end;

function TBoss4DBuildStateService.DependencyFingerprint(
  const AFingerprints: TArray<string>): string;
var
  LValues: TList<string>;
begin
  LValues := TList<string>.Create;
  try
    LValues.AddRange(AFingerprints);
    LValues.Sort(TComparer<string>.Construct(
      function(const ALeft, ARight: string): Integer
      begin
        Result := CompareText(ALeft, ARight);
      end));
    Result := HashText(string.Join('|', LValues.ToArray));
  finally
    LValues.Free;
  end;
end;

function TBoss4DBuildStateService.CombinedFingerprint(
  const ATarget: TBoss4DBuildTarget; const ASourceFingerprint,
  ADependencyFingerprint: string): string;
begin
  Result := HashText(ATarget.Identity.ToLower + '|' + ASourceFingerprint +
    '|' + ADependencyFingerprint);
end;

function TBoss4DBuildStateService.HasOutputs(
  const ATargetRoot: string): Boolean;
begin
  Result := False;
  if not TDirectory.Exists(ATargetRoot) then
    Exit;
  for var LFile in TDirectory.GetFiles(ATargetRoot, '*',
    TSearchOption.soAllDirectories) do
    if not LFile.Contains(TPath.DirectorySeparatorChar + '.boss4d-state' +
      TPath.DirectorySeparatorChar) then
      Exit(True);
end;

function TBoss4DBuildStateService.Evaluate(
  const ATarget: TBoss4DBuildTarget; const AProjectPath,
  ATargetRoot: string; const ADependencyFingerprints: TArray<string>;
  const AForce: Boolean): TBoss4DBuildDecision;
var
  LStateObject: TJSONObject;
  LStateFile: string;
  LSavedSource: string;
  LSavedDependencies: string;
  LSavedFingerprint: string;
  LOutputs: TJSONArray;
begin
  if not Assigned(ATarget) then
    raise EArgumentNilException.Create('ATarget');
  Result.SourceFingerprint := SourceFingerprint(AProjectPath);
  Result.DependencyFingerprint :=
    DependencyFingerprint(ADependencyFingerprints);
  Result.Fingerprint := CombinedFingerprint(ATarget,
    Result.SourceFingerprint, Result.DependencyFingerprint);
  Result.ShouldBuild := True;

  if AForce then
  begin
    Result.Reason := TBoss4DBuildDecisionReason.Forced;
    Exit;
  end;

  LStateFile := StatePath(ATarget, ATargetRoot);
  if not TFile.Exists(LStateFile) then
  begin
    Result.Reason := TBoss4DBuildDecisionReason.MissingState;
    Exit;
  end;
  if not HasOutputs(ATargetRoot) then
  begin
    Result.Reason := TBoss4DBuildDecisionReason.MissingOutputs;
    Exit;
  end;

  LStateObject := nil;
  try
    try
      LStateObject := TJSONObject.ParseJSONValue(
        TFile.ReadAllText(LStateFile, TEncoding.UTF8)) as TJSONObject;
      if not Assigned(LStateObject) then
        raise EConvertError.Create('JSON de estado invalido.');
      LSavedSource := LStateObject.GetValue<string>('sourceFingerprint', '');
      LSavedDependencies := LStateObject.GetValue<string>(
        'dependencyFingerprint', '');
      LSavedFingerprint := LStateObject.GetValue<string>('fingerprint', '');
      if LSavedSource.IsEmpty or LSavedDependencies.IsEmpty or
         LSavedFingerprint.IsEmpty then
        raise EConvertError.Create('Estado de build incompleto.');
      LOutputs := LStateObject.GetValue<TJSONArray>('outputs');
      if not Assigned(LOutputs) then
        raise EConvertError.Create('Inventario de outputs ausente.');
      for var I := 0 to LOutputs.Count - 1 do
        if not TFile.Exists(TPath.Combine(ATargetRoot,
          LOutputs[I].Value.Replace('/', TPath.DirectorySeparatorChar))) then
        begin
          Result.Reason := TBoss4DBuildDecisionReason.MissingOutputs;
          Exit;
        end;
    except
      Result.Reason := TBoss4DBuildDecisionReason.CorruptState;
      Exit;
    end;
  finally
    LStateObject.Free;
  end;

  if not SameText(LSavedSource, Result.SourceFingerprint) then
  begin
    Result.Reason := TBoss4DBuildDecisionReason.SourceChanged;
    Exit;
  end;
  if not SameText(LSavedDependencies, Result.DependencyFingerprint) then
  begin
    Result.Reason := TBoss4DBuildDecisionReason.DependencyChanged;
    Exit;
  end;
  if not SameText(LSavedFingerprint, Result.Fingerprint) then
  begin
    Result.Reason := TBoss4DBuildDecisionReason.CorruptState;
    Exit;
  end;

  Result.ShouldBuild := False;
  Result.Reason := TBoss4DBuildDecisionReason.UpToDate;
end;

procedure TBoss4DBuildStateService.Save(const ATarget: TBoss4DBuildTarget;
  const ATargetRoot: string; const ADecision: TBoss4DBuildDecision);
var
  LStateObject: TJSONObject;
  LEncoding: TEncoding;
  LOutputs: TJSONArray;
  LOutputFiles: TList<string>;
begin
  if not Assigned(ATarget) then
    raise EArgumentNilException.Create('ATarget');
  TDirectory.CreateDirectory(ATargetRoot);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(
    StatePath(ATarget, ATargetRoot)));
  LStateObject := TJSONObject.Create;
  try
    LStateObject.AddPair('schemaVersion', TJSONNumber.Create(1));
    LStateObject.AddPair('target', ATarget.Identity);
    LStateObject.AddPair('sourceFingerprint',
      ADecision.SourceFingerprint);
    LStateObject.AddPair('dependencyFingerprint',
      ADecision.DependencyFingerprint);
    LStateObject.AddPair('fingerprint', ADecision.Fingerprint);
    LOutputs := TJSONArray.Create;
    LOutputFiles := TList<string>.Create;
    try
      for var LFile in TDirectory.GetFiles(ATargetRoot, '*',
        TSearchOption.soAllDirectories) do
        if not LFile.Contains(TPath.DirectorySeparatorChar +
          '.boss4d-state' + TPath.DirectorySeparatorChar) then
          LOutputFiles.Add(LFile.Substring(
            Length(IncludeTrailingPathDelimiter(ATargetRoot))).Replace(
              '\', '/'));
      LOutputFiles.Sort;
      for var LOutputFile in LOutputFiles do
        LOutputs.Add(LOutputFile);
    finally
      LOutputFiles.Free;
    end;
    LStateObject.AddPair('outputs', LOutputs);
    LEncoding := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(StatePath(ATarget, ATargetRoot),
        LStateObject.Format(2),
        LEncoding);
    finally
      LEncoding.Free;
    end;
  finally
    LStateObject.Free;
  end;
end;

function TBoss4DBuildStateService.LoadFingerprint(
  const ATarget: TBoss4DBuildTarget; const ATargetRoot: string): string;
var
  LStateObject: TJSONObject;
begin
  Result := '';
  if not Assigned(ATarget) then
    raise EArgumentNilException.Create('ATarget');
  if not TFile.Exists(StatePath(ATarget, ATargetRoot)) then
    Exit;
  LStateObject := TJSONObject.ParseJSONValue(TFile.ReadAllText(
    StatePath(ATarget, ATargetRoot), TEncoding.UTF8)) as TJSONObject;
  if not Assigned(LStateObject) then
    Exit;
  try
    Result := LStateObject.GetValue<string>('fingerprint', '');
  finally
    LStateObject.Free;
  end;
end;

function TBoss4DBuildStateService.Explain(
  const ADecision: TBoss4DBuildDecision): string;
begin
  case ADecision.Reason of
    TBoss4DBuildDecisionReason.UpToDate:
      Result := 'target atualizado; rebuild dispensado';
    TBoss4DBuildDecisionReason.Forced:
      Result := 'rebuild forcado pela linha de comando';
    TBoss4DBuildDecisionReason.MissingState:
      Result := 'estado incremental ainda nao existe';
    TBoss4DBuildDecisionReason.MissingOutputs:
      Result := 'outputs esperados estao ausentes';
    TBoss4DBuildDecisionReason.SourceChanged:
      Result := 'fontes ou metadados do projeto foram alterados';
    TBoss4DBuildDecisionReason.DependencyChanged:
      Result := 'fingerprint de dependencia foi alterado';
    TBoss4DBuildDecisionReason.CorruptState:
      Result := 'estado incremental invalido ou corrompido';
  else
    Result := 'motivo de rebuild desconhecido';
  end;
end;

end.
