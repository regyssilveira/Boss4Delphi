unit Boss4D.Core.Services.BuildDoctor;

interface

uses
  System.Generics.Collections,
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package;

type
  TBoss4DDoctorSeverity = (Info, Warning, Error);
  TBoss4DRegistryDriftProbe = reference to function: TArray<string>;

  TBoss4DBuildDoctorIssue = class
  private
    FCode: string;
    FSeverity: TBoss4DDoctorSeverity;
    FMessage: string;
    FRemediation: string;
  public
    property Code: string read FCode write FCode;
    property Severity: TBoss4DDoctorSeverity read FSeverity write FSeverity;
    property Message: string read FMessage write FMessage;
    property Remediation: string read FRemediation write FRemediation;
  end;

  TBoss4DBuildDoctorResult = class
  private
    FIssues: TObjectList<TBoss4DBuildDoctorIssue>;
    function GetPassed: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function HasCode(const ACode: string): Boolean;
    property Issues: TObjectList<TBoss4DBuildDoctorIssue> read FIssues;
    property Passed: Boolean read GetPassed;
  end;

  TBoss4DBuildDoctor = class
  private
    FRegistry: IBoss4DRegistryService;
    FDriftProbe: TBoss4DRegistryDriftProbe;
    procedure AddIssue(const AResult: TBoss4DBuildDoctorResult;
      const ACode: string; const ASeverity: TBoss4DDoctorSeverity;
      const AMessage, ARemediation: string);
  public
    constructor Create(const ARegistry: IBoss4DRegistryService;
      const ADriftProbe: TBoss4DRegistryDriftProbe = nil);
    function Diagnose(const APackage: TBoss4DPackage;
      const ARootDirectory: string): TBoss4DBuildDoctorResult;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.RegularExpressions,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.BuildMatrix,
  Boss4D.Core.Services.BuildGraph;

constructor TBoss4DBuildDoctorResult.Create;
begin
  inherited Create;
  FIssues := TObjectList<TBoss4DBuildDoctorIssue>.Create(True);
end;

destructor TBoss4DBuildDoctorResult.Destroy;
begin
  FIssues.Free;
  inherited Destroy;
end;

function TBoss4DBuildDoctorResult.GetPassed: Boolean;
begin
  Result := True;
  for var LIssue in FIssues do
    if LIssue.Severity = TBoss4DDoctorSeverity.Error then
      Exit(False);
end;

function TBoss4DBuildDoctorResult.HasCode(const ACode: string): Boolean;
begin
  Result := False;
  for var LIssue in FIssues do
    if SameText(LIssue.Code, ACode) then
      Exit(True);
end;

constructor TBoss4DBuildDoctor.Create(
  const ARegistry: IBoss4DRegistryService;
  const ADriftProbe: TBoss4DRegistryDriftProbe);
begin
  inherited Create;
  FRegistry := ARegistry;
  FDriftProbe := ADriftProbe;
end;

procedure TBoss4DBuildDoctor.AddIssue(
  const AResult: TBoss4DBuildDoctorResult; const ACode: string;
  const ASeverity: TBoss4DDoctorSeverity;
  const AMessage, ARemediation: string);
begin
  var LIssue := TBoss4DBuildDoctorIssue.Create;
  LIssue.Code := ACode;
  LIssue.Severity := ASeverity;
  LIssue.Message := AMessage;
  LIssue.Remediation := ARemediation;
  AResult.Issues.Add(LIssue);
end;

function ContainsText(const AValues: TArray<string>;
  const AValue: string): Boolean;
begin
  Result := False;
  for var LItem in AValues do
    if SameText(LItem, AValue) then
      Exit(True);
end;

function IsIgnoredPath(const ARoot, APath: string): Boolean;
begin
  var LRelative := '/' + StringReplace(ExtractRelativePath(
    IncludeTrailingPathDelimiter(ARoot), APath), '\', '/',
    [rfReplaceAll]).ToLower;
  Result := LRelative.Contains('/modules/') or
    LRelative.Contains('/artifacts/') or LRelative.Contains('/.git/');
end;

function TBoss4DBuildDoctor.Diagnose(const APackage: TBoss4DPackage;
  const ARootDirectory: string): TBoss4DBuildDoctorResult;
var
  LTargets: TBoss4DBuildTargetList;
  LInstalled: TArray<string>;
  LOutputs: TDictionary<string, string>;
  LUnits: TDictionary<string, string>;
begin
  Result := TBoss4DBuildDoctorResult.Create;
  if not Assigned(APackage) then
  begin
    AddIssue(Result, 'MANIFEST_MISSING', TBoss4DDoctorSeverity.Error,
      'O manifesto do projeto nao foi carregado.',
      'Execute o doctor em um diretorio com boss.json.');
    Exit;
  end;

  try
    LTargets := TBoss4DBuildMatrixExpander.Expand(APackage,
      TBoss4DBuildSelection.All);
    try
      TBoss4DBuildGraph.Sort(LTargets);
    finally
      LTargets.Free;
    end;
  except
    on E: Exception do
      AddIssue(Result, 'MATRIX_GRAPH_INVALID',
        TBoss4DDoctorSeverity.Error, E.Message,
        'Corrija buildMatrix e execute boss4d spec --detect para regenerar.');
  end;

  if Assigned(FRegistry) then
  begin
    LInstalled := FRegistry.GetInstalledDelphiVersions;
    for var LCompiler in APackage.BuildMatrix.Compilers do
      if not ContainsText(LInstalled, LCompiler) then
        AddIssue(Result, 'TOOLCHAIN_MISSING',
          TBoss4DDoctorSeverity.Warning,
          'Delphi ' + LCompiler + ' declarado, mas nao instalado.',
          'Instale a toolchain ou filtre o build com --compiler.')
      else if not TDirectory.Exists(FRegistry.GetDelphiPath(LCompiler)) then
        AddIssue(Result, 'TOOLCHAIN_PATH_MISSING',
          TBoss4DDoctorSeverity.Warning,
          'O caminho registrado do Delphi ' + LCompiler +
          ' nao existe: ' + FRegistry.GetDelphiPath(LCompiler) + '.',
          'Repare a instalacao ou atualize a configuracao da toolchain.');
  end;

  LOutputs := TDictionary<string, string>.Create;
  try
    for var LProject in APackage.BuildMatrix.Projects do
    begin
      var LRoot := IncludeTrailingPathDelimiter(
        TPath.GetFullPath(ARootDirectory));
      var LFullPath := TPath.GetFullPath(TPath.Combine(
        ARootDirectory, LProject.Path));
      if not LFullPath.StartsWith(LRoot, True) then
      begin
        AddIssue(Result, 'PROJECT_OUTSIDE_ROOT',
          TBoss4DDoctorSeverity.Error,
          'Projeto declarado fora da raiz: ' + LProject.Path,
          'Use apenas paths relativos contidos no diretorio do pacote.');
        Continue;
      end;
      if not TFile.Exists(LFullPath) then
      begin
        AddIssue(Result, 'PROJECT_MISSING', TBoss4DDoctorSeverity.Error,
          'Projeto declarado nao encontrado: ' + LProject.Path,
          'Corrija o path ou execute boss4d spec --detect.');
        Continue;
      end;
      var LOutputName :=
        ChangeFileExt(ExtractFileName(StringReplace(LProject.Path, '/',
          '\', [rfReplaceAll])), '').ToLower;
      var LPrevious := '';
      if LOutputs.TryGetValue(LOutputName, LPrevious) and
         not SameText(LPrevious, LProject.Path) then
        AddIssue(Result, 'OUTPUT_COLLISION', TBoss4DDoctorSeverity.Error,
          'Projetos podem gerar o mesmo output "' + LOutputName +
          '": ' + LPrevious + ' e ' + LProject.Path + '.',
          'Use nomes de package distintos ou configure sufixos por Delphi.')
      else
        LOutputs.AddOrSetValue(LOutputName, LProject.Path);
    end;
  finally
    LOutputs.Free;
  end;

  LUnits := TDictionary<string, string>.Create;
  try
    if TDirectory.Exists(ARootDirectory) then
      for var LFile in TDirectory.GetFiles(ARootDirectory, '*.pas',
        TSearchOption.soAllDirectories) do
        if not IsIgnoredPath(ARootDirectory, LFile) then
        begin
          var LContent := TFile.ReadAllText(LFile);
          var LMatch := TRegEx.Match(LContent,
            '(?im)^\s*unit\s+([A-Za-z_][A-Za-z0-9_.]*)\s*;');
          if not LMatch.Success then
            Continue;
          var LUnitName := LMatch.Groups[1].Value.ToLower;
          var LPrevious := '';
          if LUnits.TryGetValue(LUnitName, LPrevious) and
             not SameText(LPrevious, LFile) then
            AddIssue(Result, 'UNIT_COLLISION',
              TBoss4DDoctorSeverity.Error,
              'Unidade Delphi duplicada "' + LMatch.Groups[1].Value +
              '": ' + LPrevious + ' e ' + LFile + '.',
              'Renomeie a unidade ou remova a copia ambigua do search path.')
          else
            LUnits.AddOrSetValue(LUnitName, LFile);
        end;
  finally
    LUnits.Free;
  end;

  if Assigned(FDriftProbe) then
    for var LIdentity in FDriftProbe() do
      AddIssue(Result, 'IDE_REGISTRY_DRIFT',
        TBoss4DDoctorSeverity.Warning,
        'Registro IDE divergente: ' + LIdentity,
        'Execute boss4d ide repair.');
end;

end.
