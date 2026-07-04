unit Boss4D.Adapters.Compiler;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, Boss4D.Core.Ports,
  Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Lock, Boss4D.Core.Domain.Consts,
  Boss4D.Core.Domain.Env;

type
  { Adaptador de Compilador Delphi que executa MSBuild usando configuracao boss.cfg }
  TBoss4DDelphiCompilerAdapter = class(TInterfacedObject, IBoss4DCompiler)
  private
    FRegistry: IBoss4DRegistryService;
    FLogger: IBoss4DLogger;

    function ExecuteBatch(const ABatchPath: string; const AWorkingDir: string; out AOutput: string): Boolean;
    function GetCompilerParameters(const ARootPath: string; const ADep: TBoss4DDependency; const APlatform: string): string;
  public
    constructor Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);

    function FindRsvarsPath(out ARsvarsPath: string; out APlatform: string): Boolean;
    function Compile(const ADprojPath: string; const ADep: TBoss4DDependency; const ARootLock: TBoss4DLock): Boolean;
    function BuildSearchPath(const ADep: TBoss4DDependency): string;
  end;

implementation

uses
  System.Generics.Collections,
  System.JSON,
  Boss4D.Core.Domain.Package,
  Boss4D.Adapters.Json
  {$IFDEF MSWINDOWS}, Winapi.Windows{$ENDIF};

{ TBoss4DDelphiCompilerAdapter }

constructor TBoss4DDelphiCompilerAdapter.Create(const ARegistry: IBoss4DRegistryService; const ALogger: IBoss4DLogger);
begin
  inherited Create;
  FRegistry := ARegistry;
  FLogger := ALogger;
end;

function TBoss4DDelphiCompilerAdapter.FindRsvarsPath(out ARsvarsPath: string; out APlatform: string): Boolean;
var
  LVersions: TArray<string>;
  LRootDir: string;
  LCfgPath: string;
begin
  Result := False;
  ARsvarsPath := '';
  APlatform := 'Win32';
  LRootDir := '';

  // 1. Tenta obter o caminho preferencial configurado globalmente no boss.cfg.json
  LCfgPath := GetGlobalConfigPath;
  if TFile.Exists(LCfgPath) then
  begin
    try
      var LJSONStr := TFile.ReadAllText(LCfgPath, TEncoding.UTF8);
      if not LJSONStr.Trim.IsEmpty then
      begin
        var LJSONObj := TJSONObject.ParseJSONValue(LJSONStr) as TJSONObject;
        if Assigned(LJSONObj) then
        try
          var LVal := LJSONObj.FindValue('delphiPath');
          if Assigned(LVal) and not LVal.Value.Trim.IsEmpty then
          begin
            var LConfiguredVal := LVal.Value.Trim;
            if TDirectory.Exists(LConfiguredVal) then
              LRootDir := LConfiguredVal
            else
            begin
              var LRegPath := FRegistry.GetDelphiPath(LConfiguredVal);
              if not LRegPath.IsEmpty and TDirectory.Exists(LRegPath) then
                LRootDir := LRegPath
              else
                LRootDir := LConfiguredVal;
            end;
          end;
        finally
          LJSONObj.Free;
        end;
      end;
    except
      // Ignora erro de parse de JSON corrompido e segue para o Registro
    end;
  end;

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

function TBoss4DDelphiCompilerAdapter.GetCompilerParameters(const ARootPath: string; const ADep: TBoss4DDependency;
  const APlatform: string): string;
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
  LSearchPath := '';
  if Assigned(ADep) then
  begin
    LSearchPath := TPath.Combine(GetModulesDir, ADep.Name);
    LPackagePath := TPath.Combine(LSearchPath, FILE_PACKAGE);
    
    // Carrega boss.json da dependencia de forma tardia para ler MainSrc
    if TFile.Exists(LPackagePath) then
    begin
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
        
        // Resolve recursivamente caminhos de subdependencias
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
    end;
  end;
  Result := LSearchPath;
end;

function TBoss4DDelphiCompilerAdapter.ExecuteBatch(const ABatchPath: string; const AWorkingDir: string;
  out AOutput: string): Boolean;
{$IFDEF MSWINDOWS}
var
  LSA: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LStartInfo: TStartUpInfo;
  LProcInfo: TProcessInformation;
  LBuffer: array[0..255] of AnsiChar;
  LBytesRead: DWORD;
  LCommandLine: string;
  LWorkingDir: string;
  LTempOutput: string;
begin
  Result := False;
  AOutput := '';
  LTempOutput := '';

  LSA.nLength := SizeOf(TSecurityAttributes);
  LSA.bInheritHandle := True;
  LSA.lpSecurityDescriptor := nil;

  if not CreatePipe(LReadPipe, LWritePipe, @LSA, 0) then
    Exit;

  try
    FillChar(LStartInfo, SizeOf(TStartUpInfo), 0);
    LStartInfo.cb := SizeOf(TStartUpInfo);
    LStartInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LStartInfo.hStdOutput := LWritePipe;
    LStartInfo.hStdError := LWritePipe;
    LStartInfo.wShowWindow := SW_HIDE;

    LCommandLine := 'cmd.exe /c "' + ABatchPath + '"';
    UniqueString(LCommandLine);

    LWorkingDir := AWorkingDir;
    if LWorkingDir.IsEmpty then
      LWorkingDir := TDirectory.GetCurrentDirectory;

    if CreateProcess(nil, PChar(LCommandLine), nil, nil, True, 0, nil, PChar(LWorkingDir), LStartInfo, LProcInfo) then
    begin
      try
        CloseHandle(LWritePipe);
        LWritePipe := 0;

        repeat
          LBytesRead := 0;
          if ReadFile(LReadPipe, LBuffer[0], SizeOf(LBuffer) - 1, LBytesRead, nil) and (LBytesRead > 0) then
          begin
            LBuffer[LBytesRead] := #0;
            LTempOutput := LTempOutput + string(AnsiString(LBuffer));
          end;
        until LBytesRead = 0;

        WaitForSingleObject(LProcInfo.hProcess, INFINITE);
        
        var LExitCode: DWORD := 0;
        GetExitCodeProcess(LProcInfo.hProcess, LExitCode);
        Result := LExitCode = 0;
      finally
        CloseHandle(LProcInfo.hProcess);
        CloseHandle(LProcInfo.hThread);
      end;
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    CloseHandle(LReadPipe);
  end;

  AOutput := LTempOutput.Trim;
end;
{$ELSE}
begin
  Result := False;
  AOutput := '';
end;
{$ENDIF}

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
      FLogger.Log(TBoss4DLogLevel.Error, '  ❌ Erro ao compilar. Veja o arquivo de log para mais informacoes: %s', [LBuildLog]);
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
