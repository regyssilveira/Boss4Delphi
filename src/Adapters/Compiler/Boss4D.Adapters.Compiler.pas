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
    function DetectDelphiVersionFromDproj: string;
    function ExecuteBatch(const ABatchPath: string; const AWorkingDir: string; out AOutput: string): Boolean;
    function CompileLazarus(const AProjectPath, APlatform: string): Boolean;
    function GetCompilerParameters(
      const ARootPath: string;
      const ADep: TBoss4DDependency;
      const APlatform: string
    ): string;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);

    function FindRsvarsPath(out ARsvarsPath: string; out APlatform: string;
      const ACompilerVersion: string = ''): Boolean;
    function Compile(const AProjectPath: string; const ADep: TBoss4DDependency;
      const ARootLock: TBoss4DLock; const APlatform: string = '';
      const ACompilerVersion: string = ''): Boolean;
    function BuildSearchPath(const ADep: TBoss4DDependency; const APlatform: string = ''): string;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON,
  Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Package,
  Boss4D.Adapters.Json;

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

function TBoss4DDelphiCompilerAdapter.DetectDelphiVersionFromDproj: string;
var
  LFiles: TArray<string>;
  LContent: string;
  LStartIdx, LEndIdx: Integer;
  LVerStr: string;
  LVerFloat: Double;
begin
  Result := '';
  try
    if not TDirectory.Exists(TDirectory.GetCurrentDirectory) then
      Exit;

    LFiles := TDirectory.GetFiles(TDirectory.GetCurrentDirectory, '*.dproj');
    if Length(LFiles) = 0 then
      Exit;

    LContent := TFile.ReadAllText(LFiles[0]);
    LStartIdx := LContent.IndexOf('<ProjectVersion>');
    if LStartIdx = -1 then
      Exit;

    Inc(LStartIdx, Length('<ProjectVersion>'));
    LEndIdx := LContent.IndexOf('</ProjectVersion>', LStartIdx);
    if LEndIdx = -1 then
      Exit;

    LVerStr := LContent.Substring(LStartIdx, LEndIdx - LStartIdx).Trim;
    if LVerStr.IsEmpty then
      Exit;

    LVerStr := LVerStr.Replace(',', '.');

    var LFormatSettings := TFormatSettings.Invariant;
    if TryStrToFloat(LVerStr, LVerFloat, LFormatSettings) then
    begin
      if LVerFloat >= 20.3 then
        Result := '37.0' // Delphi 13 Florence (ProjectVersion >= 20.3)
      else if LVerFloat >= 20.0 then
        Result := '23.0' // Delphi 12 Athens (ProjectVersion >= 20.0)
      else if LVerFloat >= 19.2 then
        Result := '22.0' // Delphi 11 Alexandria (ProjectVersion 19.3, 19.4, 19.5)
      else if LVerFloat >= 19.0 then
        Result := '21.0' // Delphi 10.4 Sydney (ProjectVersion 19.0)
      else if LVerFloat >= 18.4 then
        Result := '20.0' // Delphi 10.3 Rio (ProjectVersion 18.4, 18.5, 18.8)
      else if LVerFloat >= 18.1 then
        Result := '19.0' // Delphi 10.2 Tokyo (ProjectVersion 18.1, 18.2, 18.3)
      else if LVerFloat >= 18.0 then
        Result := '18.0' // Delphi 10.1 Berlin (ProjectVersion 18.0)
      else if LVerFloat >= 17.0 then
        Result := '17.0'; // Delphi 10 Seattle / XE8 (ProjectVersion 17.0)
    end;
  except
    on E: Exception do
    begin
      FLogger.Log(TBoss4DLogLevel.Warning, 'Falha silenciosa ao detectar versao do Delphi a partir do dproj: ' + E.Message);
    end;
  end;
end;

function TBoss4DDelphiCompilerAdapter.FindRsvarsPath(out ARsvarsPath: string;
  out APlatform: string; const ACompilerVersion: string = ''): Boolean;
var
  LVersions: TArray<string>;
  LRootDir: string;
  LDetectedVer: string;
begin
  Result := False;
  ARsvarsPath := '';
  APlatform := 'Win32';

  // 1. A versao declarada no toolchain tem precedencia sobre autodeteccao.
  LDetectedVer := ACompilerVersion;
  if LDetectedVer.IsEmpty then
    LDetectedVer := DetectDelphiVersionFromDproj;
  if not LDetectedVer.IsEmpty then
  begin
    LRootDir := FRegistry.GetDelphiPath(LDetectedVer);
    if not LRootDir.IsEmpty then
      FLogger.Log(TBoss4DLogLevel.Info, '  Detectado Delphi %s pelo arquivo .dproj local.', [LDetectedVer]);
  end;

  // 2. Se nao detectado via dproj, tenta obter o caminho preferencial configurado globalmente no boss.cfg.json
  if LRootDir.IsEmpty then
    LRootDir := GetConfiguredDelphiPath;

  // 3. Se nao detectado ou nao instalado, faz o fallback para a versao mais recente instalada no Registro
  if LRootDir.IsEmpty then
  begin
    LVersions := FRegistry.GetInstalledDelphiVersions;
    if Length(LVersions) > 0 then
    begin
      TArray.Sort<string>(LVersions);
      for var I := Length(LVersions) - 1 downto 0 do
      begin
        var LVer := LVersions[I];
        var LTempPath := FRegistry.GetDelphiPath(LVer);
        if not LTempPath.IsEmpty and TFile.Exists(TPath.Combine(TPath.Combine(LTempPath, 'bin'), 'rsvars.bat')) then
        begin
          LRootDir := LTempPath;
          Break;
        end;
      end;
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
  LBplPath := TPath.Combine(ARootPath, TPath.Combine(FOLDER_BPL, TPath.Combine(APlatform, 'Debug')));
  LDcpPath := TPath.Combine(ARootPath, TPath.Combine(FOLDER_DCP, TPath.Combine(APlatform, 'Debug')));
  LDcuPath := TPath.Combine(ARootPath, TPath.Combine(FOLDER_DCU, TPath.Combine(APlatform, 'Debug')));

  if not TDirectory.Exists(LBplPath) then
    TDirectory.CreateDirectory(LBplPath);
  if not TDirectory.Exists(LDcpPath) then
    TDirectory.CreateDirectory(LDcpPath);
  if not TDirectory.Exists(LDcuPath) then
    TDirectory.CreateDirectory(LDcuPath);

  Result := ' /p:DCC_BplOutput="' + LBplPath + '"' +
            ' /p:DCC_DcpOutput="' + LDcpPath + '"' +
            ' /p:DCC_DcuOutput="' + LDcuPath + '"' +
            ' /p:DCC_ExeOutput="' + LBinPath + '"' +
            ' /target:Build' +
            ' /p:config=Debug' +
            ' /p:DCC_UseMSBuildExternally=true' +
            ' /p:platform=' + APlatform + ' ';
end;

function TBoss4DDelphiCompilerAdapter.BuildSearchPath(const ADep: TBoss4DDependency; const APlatform: string = ''): string;
var
  LSearchPath: string;
  LPackagePath: string;
  LPackageData: TBoss4DPackage;
  function CleanPath(const APath: string): string;
  begin
    Result := APath.Replace('/', '\').Trim;
    if Result.EndsWith('\') and (Length(Result) > 3) then
      Result := Result.Substring(0, Result.Length - 1);
  end;
begin
  Result := '';
  if not Assigned(ADep) then
    Exit;

  LSearchPath := CleanPath(TPath.Combine(GetModulesDir, ADep.StorageName));
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
          LSearchPath := LSearchPath + ';' + CleanPath(TPath.Combine(
            TPath.Combine(GetModulesDir, ADep.StorageName), LTrimmedPath));
      end;
    end;

    var LSubDeps := LPackageData.GetParsedDependencies;
    for var LSubDep in LSubDeps do
    begin
      LSearchPath := LSearchPath + ';' + BuildSearchPath(LSubDep, APlatform);
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

function TBoss4DDelphiCompilerAdapter.Compile(const AProjectPath: string;
  const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock;
  const APlatform: string = ''; const ACompilerVersion: string = ''): Boolean;
var
  LRsvarsPath, LPlatform: string;
  LAbsDir, LBuildLog, LBuildBat, LCfgPath: string;
  LCfgContent: TStringBuilder;
  LBatchContent: TStringList;
  LOutput: string;
begin
  Result := False;

  if SameText(TPath.GetExtension(AProjectPath), EXT_LPI) or
     SameText(TPath.GetExtension(AProjectPath), EXT_LPK) then
    Exit(CompileLazarus(AProjectPath, APlatform));

  if not FindRsvarsPath(LRsvarsPath, LPlatform, ACompilerVersion) then
  begin
    FLogger.Log(TBoss4DLogLevel.Error, 'Delphi Environment (rsvars.bat) nao encontrado no registro.');
    Exit;
  end;

  if not APlatform.IsEmpty then
    LPlatform := APlatform;

  FLogger.Log(TBoss4DLogLevel.Info, '  Compilando ' + TPath.GetFileName(AProjectPath));

  LAbsDir := TPath.GetDirectoryName(TPath.GetFullPath(AProjectPath));
  var LFileRes := 'build_boss4d_' + TPath.GetFileNameWithoutExtension(AProjectPath);
  LBuildLog := TPath.Combine(LAbsDir, LFileRes + '.log');
  LBuildBat := TPath.Combine(LAbsDir, LFileRes + '.bat');
  LCfgPath := TPath.Combine(LAbsDir, 'boss.cfg');

  // 1. Cria o boss.cfg para guardar os Search Paths gigantes (Prevenindo a Issue #205)
  LCfgContent := TStringBuilder.Create;
  try
    var LDcuPath := TPath.Combine(GetModulesDir, TPath.Combine(FOLDER_DCU, TPath.Combine(LPlatform, 'Debug')));
    var LDcpPath := TPath.Combine(GetModulesDir, TPath.Combine(FOLDER_DCP, TPath.Combine(LPlatform, 'Debug')));

    if not TDirectory.Exists(LDcuPath) then
      TDirectory.CreateDirectory(LDcuPath);
    if not TDirectory.Exists(LDcpPath) then
      TDirectory.CreateDirectory(LDcpPath);

    LCfgContent.AppendLine('-I"' + LDcuPath + '"');
    LCfgContent.AppendLine('-U"' + LDcuPath + '"');
    LCfgContent.AppendLine('-I"' + LDcpPath + '"');
    LCfgContent.AppendLine('-U"' + LDcpPath + '"');

    var LSearchPathStr := BuildSearchPath(ADep, LPlatform);
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
    var LBplPath := TPath.Combine(GetModulesDir, TPath.Combine(FOLDER_BPL, TPath.Combine(LPlatform, 'Debug')));
    if not TDirectory.Exists(LBplPath) then
      TDirectory.CreateDirectory(LBplPath);

    LBatchContent.Add('call "' + LRsvarsPath + '"');
    LBatchContent.Add('set PATH=%PATH%;' + LBplPath + ';');

    var LMsbuildCmd := 'msbuild "' + TPath.GetFullPath(AProjectPath) + '" /p:Configuration=Debug ' +
                       GetCompilerParameters(GetModulesDir, ADep, LPlatform) +
                       ' /p:DCC_AdditionalSwitches="@' + LCfgPath + '"';

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
        '  Erro ao compilar. Veja o arquivo de log para mais informacoes: %s',
        [LBuildLog]);
    end
    else
    begin
      FLogger.Log(TBoss4DLogLevel.Info, '  Compilado com sucesso!');

      if TFile.Exists(LBuildLog) then TFile.Delete(LBuildLog);
      if TFile.Exists(LBuildBat) then TFile.Delete(LBuildBat);
    end;
  finally
    // Sempre remove o boss.cfg temporario
    if TFile.Exists(LCfgPath) then TFile.Delete(LCfgPath);
  end;
end;

function TBoss4DDelphiCompilerAdapter.CompileLazarus(
  const AProjectPath, APlatform: string): Boolean;
var
  LWorkingDirectory, LBatchPath, LLogPath, LOutput: string;
  LBatch: TStringList;
  LTargetArguments: string;
begin
  LWorkingDirectory := TPath.GetDirectoryName(TPath.GetFullPath(AProjectPath));
  LBatchPath := TPath.Combine(LWorkingDirectory, 'build_boss4d_lazarus.bat');
  LLogPath := TPath.Combine(LWorkingDirectory, 'build_boss4d_lazarus.log');
  LTargetArguments := '';
  if SameText(APlatform, 'Win64') then
    LTargetArguments := '--os=win64 --cpu=x86_64 '
  else if SameText(APlatform, 'Win32') then
    LTargetArguments := '--os=win32 --cpu=i386 ';

  LBatch := TStringList.Create;
  try
    LBatch.Add('@where lazbuild >nul 2>&1 || (echo lazbuild nao encontrado & exit /b 1)');
    LBatch.Add('lazbuild ' + LTargetArguments + '"' +
      TPath.GetFullPath(AProjectPath) + '" > "' + LLogPath + '" 2>&1');
    LBatch.SaveToFile(LBatchPath, TEncoding.UTF8);
  finally
    LBatch.Free;
  end;

  try
    FLogger.Log(TBoss4DLogLevel.Info, '  Compilando com Lazarus: ' +
      TPath.GetFileName(AProjectPath));
    Result := ExecuteBatch(LBatchPath, LWorkingDirectory, LOutput);
    if Result then
    begin
      if TFile.Exists(LLogPath) then
        TFile.Delete(LLogPath);
    end
    else
      FLogger.Log(TBoss4DLogLevel.Error,
        '  Falha no lazbuild. Veja o log: ' + LLogPath);
  finally
    if TFile.Exists(LBatchPath) then
      TFile.Delete(LBatchPath);
  end;
end;

end.
