unit Boss4D.Adapters.Compiler;

interface

uses
  Boss4D.Core.Ports, Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Lock;

type
  { Adaptador de Compilador Delphi que executa MSBuild usando configuracao boss.cfg }
  TBoss4DDelphiCompilerAdapter = class(TInterfacedObject, IBoss4DCompiler)
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;

    function GetConfiguredDelphiPath: string;
    function ExecuteBatch(const ABatchPath: string; const AWorkingDir: string; out AOutput: string): Boolean;
    function GetCompilerParameters(
      const ARootPath: string;
      const ADep: TBoss4DDependency;
      const APlatform: string
    ): string;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);

    function FindRsvarsPath(out ARsvarsPath: string; out APlatform: string): Boolean;
    function Compile(const ADprojPath: string; const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock): Boolean;
    function BuildSearchPath(const ADep: TBoss4DDependency): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON,
  Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Package,
  Boss4D.Adapters.Json,
  Winapi.Windows;

{ TBoss4DDelphiCompilerAdapter }

constructor TBoss4DDelphiCompilerAdapter.Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
end;

function TBoss4DDelphiCompilerAdapter.GetConfiguredDelphiPath: string;
var
  LCfgPath: string;
  LJSONStr: string;
  LJSONObj: TJSONObject;
  LVal: TJSONValue;
  LConfiguredVal, LRegPath: string;
begin
  Result := '';
  LCfgPath := GetGlobalConfigPath;
  if not TFile.Exists(LCfgPath) then
    Exit;

  try
    LJSONStr := TFile.ReadAllText(LCfgPath, TEncoding.UTF8);
    if LJSONStr.Trim.IsEmpty then
      Exit;

    LJSONObj := TJSONObject.ParseJSONValue(LJSONStr) as TJSONObject;
    if not Assigned(LJSONObj) then
      Exit;

    try
      LVal := LJSONObj.FindValue('delphiPath');
      if Assigned(LVal) and not LVal.Value.Trim.IsEmpty then
      begin
        LConfiguredVal := LVal.Value.Trim;
        if TDirectory.Exists(LConfiguredVal) then
          Exit(LConfiguredVal);

        LRegPath := FRegistry.GetDelphiPath(LConfiguredVal);
        if not LRegPath.IsEmpty and TDirectory.Exists(LRegPath) then
          Exit(LRegPath);

        Exit(LConfiguredVal);
      end;
    finally
      LJSONObj.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Log(TBoss4DLogLevel.Warning, 'Erro ao analisar configuracao global: ' + E.Message);
    end;
  end;
end;

function TBoss4DDelphiCompilerAdapter.FindRsvarsPath(out ARsvarsPath: string; out APlatform: string): Boolean;
var
  LVersions: TArray<string>;
  LRootDir: string;
begin
  Result := False;
  ARsvarsPath := '';
  APlatform := 'Win32';

  // 1. Tenta obter o caminho preferencial configurado globalmente no boss.cfg.json
  LRootDir := GetConfiguredDelphiPath;

  // 2. Se nao configurado de forma explicita, autodetecta a versao mais recente no Registro
  if LRootDir.IsEmpty then
  begin
    LVersions := FRegistry.GetInstalledDelphiVersions;
    if Length(LVersions) > 0 then
    begin
      // Ordena as versoes e pega a mais recente (Delphi 13 tem indice maior)
      TArray.Sort<string>(LVersions);
      var LLatestVersion := LVersions[Length(LVersions) - 1];
      LRootDir := FRegistry.GetDelphiPath(LLatestVersion);
    end;
  end;

  if not LRootDir.IsEmpty then
  begin
    ARsvarsPath := TPath.Combine(TPath.Combine(LRootDir, 'bin'), 'rsvars.bat');
    Result := TFile.Exists(ARsvarsPath);
  end;
end;

function TBoss4DDelphiCompilerAdapter.GetCompilerParameters(
  const ARootPath: string;
  const ADep: TBoss4DDependency;
  const APlatform: string
): string;
var
  LModuleName: string;
  LBinPath: string;
  LBplPath: string;
  LDcpPath: string;
  LDcuPath: string;
begin
  LModuleName := '';
  if Assigned(ADep) then
    LModuleName := ADep.Name;

  LBinPath := TPath.Combine(ARootPath, TPath.Combine(LModuleName, FOLDER_BIN));
  LBplPath := TPath.Combine(ARootPath, TPath.Combine(LModuleName, FOLDER_BPL));
  LDcpPath := TPath.Combine(ARootPath, TPath.Combine(LModuleName, FOLDER_DCP));
  LDcuPath := TPath.Combine(ARootPath, TPath.Combine(LModuleName, FOLDER_DCU));

  Result := ' /p:DCC_BplOutput="' + LBplPath + '"' +
            ' /p:DCC_DcpOutput="' + LDcpPath + '"' +
            ' /p:DCC_DcuOutput="' + LDcuPath + '"' +
            ' /p:DCC_ExeOutput="' + LBinPath + '"' +
            ' /target:Build' +
            ' /p:config=Debug' +
            ' /p:DCC_UseMSBuildExternally=true' +
            ' /p:platform=' + APlatform + ' ';
end;

function TBoss4DDelphiCompilerAdapter.BuildSearchPath(const ADep: TBoss4DDependency): string;
var
  LSearchPath: string;
  LPackagePath: string;
  LPackageData: TBoss4DPackage;
begin
  Result := '';
  if not Assigned(ADep) then
    Exit;

  LSearchPath := TPath.Combine(GetModulesDir, ADep.Name);
  LPackagePath := TPath.Combine(LSearchPath, FILE_PACKAGE);
  if not TFile.Exists(LPackagePath) then
  begin
    Result := LSearchPath;
    Exit;
  end;

  var LRepo := TBoss4DPackageJsonRepository.Create;
  LPackageData := LRepo.Load(LPackagePath);
  try
    if not LPackageData.MainSrc.IsEmpty then
    begin
      var LMainSrcs := LPackageData.MainSrc.Split([';']);
      for var LSubPath in LMainSrcs do
      begin
        var LTrimmedPath := LSubPath.Trim;
        if not LTrimmedPath.IsEmpty then
          LSearchPath := LSearchPath + ';' + TPath.Combine(TPath.Combine(GetModulesDir, ADep.Name), LTrimmedPath);
      end;
    end;

    var LSubDeps := LPackageData.GetParsedDependencies;
    for var LSubDep in LSubDeps do
    begin
      LSearchPath := LSearchPath + ';' + BuildSearchPath(LSubDep);
      LSubDep.Free;
    end;
  finally
    LPackageData.Free;
    LRepo.Free;
  end;
  Result := LSearchPath;
end;

function TBoss4DDelphiCompilerAdapter.ExecuteBatch(const ABatchPath: string; const AWorkingDir: string;
  out AOutput: string): Boolean;
begin
  Result := ExecuteCommandLine('cmd.exe /c "' + ABatchPath + '"', AWorkingDir, AOutput);
end;

function TBoss4DDelphiCompilerAdapter.Compile(const ADprojPath: string; const ADep: TBoss4DDependency;
  const ARootLock: TBoss4DLock): Boolean;
var
  LRsvarsPath, LPlatform: string;
  LAbsDir, LBuildLog, LBuildBat, LCfgPath: string;
  LCfgContent: TStringBuilder;
  LBatchContent: TStringList;
  LOutput: string;
begin
  Result := False;

  if not FindRsvarsPath(LRsvarsPath, LPlatform) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Delphi Environment (rsvars.bat) nao encontrado no registro.');
    Exit;
  end;

  FLogger.Log(TBoss4DLogLevel.Info, '  🔨 Compilando ' + TPath.GetFileName(ADprojPath));

  LAbsDir := TPath.GetDirectoryName(TPath.GetFullPath(ADprojPath));
  var LFileRes := 'build_boss4d_' + TPath.GetFileNameWithoutExtension(ADprojPath);
  LBuildLog := TPath.Combine(LAbsDir, LFileRes + '.log');
  LBuildBat := TPath.Combine(LAbsDir, LFileRes + '.bat');
  LCfgPath := TPath.Combine(LAbsDir, 'boss.cfg');

  // 1. Cria o boss.cfg para guardar os Search Paths gigantes (Prevenindo a Issue #205)
  LCfgContent := TStringBuilder.Create;
  try
    var LDcuPath := TPath.Combine(GetModulesDir, FOLDER_DCU);
    var LDcpPath := TPath.Combine(GetModulesDir, FOLDER_DCP);
    LCfgContent.AppendLine('-I"' + LDcuPath + '"');
    LCfgContent.AppendLine('-U"' + LDcuPath + '"');
    LCfgContent.AppendLine('-I"' + LDcpPath + '"');
    LCfgContent.AppendLine('-U"' + LDcpPath + '"');

    var LSearchPathStr := BuildSearchPath(ADep);
    if not LSearchPathStr.IsEmpty then
    begin
      var LPaths := LSearchPathStr.Split([';']);
      for var LPath in LPaths do
      begin
        var LCleanPath := LPath.Trim;
        if not LCleanPath.IsEmpty then
        begin
          LCfgContent.AppendLine('-I"' + LCleanPath + '"');
          LCfgContent.AppendLine('-U"' + LCleanPath + '"');
        end;
      end;
    end;

    TFile.WriteAllText(LCfgPath, LCfgContent.ToString, TEncoding.UTF8);
  finally
    LCfgContent.Free;
  end;

  // 2. Cria o script batch que carrega o rsvars.bat e executa o msbuild com a diretiva @boss.cfg
  LBatchContent := TStringList.Create;
  try
    LBatchContent.Add('call "' + LRsvarsPath + '"');
    LBatchContent.Add('set PATH=%PATH%;' + TPath.Combine(GetModulesDir, FOLDER_BPL) + ';');

    var LMsbuildCmd := 'msbuild "' + TPath.GetFullPath(ADprojPath) + '" /p:Configuration=Debug ' +
                       GetCompilerParameters(GetModulesDir, ADep, LPlatform) +
                       ' /p:DCC_AdditionalParameters="@' + LCfgPath + '"';

    LBatchContent.Add(LMsbuildCmd + ' > "' + LBuildLog + '" 2>&1');
    LBatchContent.SaveToFile(LBuildBat, TEncoding.UTF8);
  finally
    LBatchContent.Free;
  end;

  // 3. Executa o batch
  try
    Result := ExecuteBatch(LBuildBat, LAbsDir, LOutput);

    if not Result then
    begin
      FLogger.Log(TBoss4DLogLevel.Error,
        '  ❌ Erro ao compilar. Veja o arquivo de log para mais informacoes: %s',
        [LBuildLog]);
    end
    else
    begin
      FLogger.Log(TBoss4DLogLevel.Info, '  ✅ Compilado com sucesso!');

      // Apaga arquivos de log e batch gerados apenas em caso de sucesso
      if TFile.Exists(LBuildLog) then TFile.Delete(LBuildLog);
      if TFile.Exists(LBuildBat) then TFile.Delete(LBuildBat);
    end;
  finally
    // Sempre remove o boss.cfg temporario
    if TFile.Exists(LCfgPath) then TFile.Delete(LCfgPath);
  end;
end;

end.
