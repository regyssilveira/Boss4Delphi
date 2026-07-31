unit Boss4D.Core.Services.BuildCommand;

interface

uses
  Boss4D.Core.Ports,
  Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Lock,
  Boss4D.Core.Domain.BuildMatrix,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.BuildInventory;

type
  TBoss4DIDERegistrationHandler = reference to procedure(
    const ARegistration: TBoss4DIDERegistration);

  TBoss4DBuildCommandOptions = record
    Selection: TBoss4DBuildSelection;
    Force: Boolean;
    Explain: Boolean;
    RegisterTargets: Boolean;
    WithDependents: Boolean;
    Affected: Boolean;
    AllInstalledIDEs: Boolean;
    Jobs: Integer;
    class function Parse(
      const AArgs: TArray<string>): TBoss4DBuildCommandOptions; static;
  end;

  TBoss4DBuildCommandResult = record
    Scheduled: Integer;
    Built: Integer;
    Skipped: Integer;
    Restored: Integer;
    Registered: Integer;
  end;

  TBoss4DBuildCommand = class
  private
    FCompiler: IBoss4DCompiler;
    FLogger: IBoss4DLogger;
    FRegistrationHandler: TBoss4DIDERegistrationHandler;
    FInventory: TBoss4DBuildInventory;
    function SourceChecksum(const APackage: TBoss4DPackage;
      const ARootDirectory: string): string;
  public
    constructor Create(const ACompiler: IBoss4DCompiler;
      const ALogger: IBoss4DLogger;
      const ARegistrationHandler: TBoss4DIDERegistrationHandler = nil;
      const AInventory: TBoss4DBuildInventory = nil);
    function Execute(const APackage: TBoss4DPackage;
      const ALock: TBoss4DLock; const ARootDirectory: string;
      const AOptions: TBoss4DBuildCommandOptions): TBoss4DBuildCommandResult;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Hash,
  System.Generics.Collections,
  Boss4D.Core.Domain.Dependency,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.Consts,
  Boss4D.Core.Services.BuildConventions,
  Boss4D.Core.Services.BuildExecutor,
  Boss4D.Core.Services.BuildMatrix,
  Boss4D.Core.Services.BuildPaths;

class function TBoss4DBuildCommandOptions.Parse(
  const AArgs: TArray<string>): TBoss4DBuildCommandOptions;
var
  LCompiler: string;
  LPlatform: string;
  LConfiguration: string;
  LCompilerAll: Boolean;
  LPlatformAll: Boolean;
  LConfigurationAll: Boolean;
  I: Integer;
begin
  Result := Default(TBoss4DBuildCommandOptions);
  Result.Jobs := 1;
  LCompilerAll := False;
  LPlatformAll := False;
  LConfigurationAll := False;
  I := 1;
  while I < Length(AArgs) do
  begin
    if SameText(AArgs[I], '--force') then
      Result.Force := True
    else if SameText(AArgs[I], '--explain') then
      Result.Explain := True
    else if SameText(AArgs[I], '--register') then
      Result.RegisterTargets := True
    else if SameText(AArgs[I], '--with-dependents') then
      Result.WithDependents := True
    else if SameText(AArgs[I], '--affected') then
    begin
      Result.Affected := True;
      Result.WithDependents := True;
    end
    else if SameText(AArgs[I], '--all-installed') then
    begin
      Result.AllInstalledIDEs := True;
      Result.RegisterTargets := True;
    end
    else if SameText(AArgs[I], '--full') then
    begin
      Result.Force := True;
      LCompilerAll := True;
      LPlatformAll := True;
      LConfigurationAll := True;
    end
    else if SameText(AArgs[I], '--compiler') or
            SameText(AArgs[I], '--platform') or
            SameText(AArgs[I], '--configuration') or
            SameText(AArgs[I], '--jobs') then
    begin
      if I + 1 >= Length(AArgs) then
        raise EArgumentException.Create(
          'Informe um valor para ' + AArgs[I] + '.');
      var LOption := AArgs[I].ToLower;
      Inc(I);
      if LOption = '--compiler' then
      begin
        LCompilerAll := SameText(AArgs[I], 'all');
        if LCompilerAll then
          LCompiler := ''
        else
          LCompiler :=
            TBoss4DBuildConventions.ResolveCompiler(AArgs[I]).BDSVersion;
      end
      else if LOption = '--platform' then
      begin
        LPlatformAll := SameText(AArgs[I], 'all');
        if LPlatformAll then
          LPlatform := ''
        else if SameText(AArgs[I], 'Win32') then
          LPlatform := 'Win32'
        else if SameText(AArgs[I], 'Win64') then
          LPlatform := 'Win64'
        else
          raise EArgumentException.CreateFmt(
            'Plataforma Delphi nao suportada: %s.', [AArgs[I]]);
      end
      else if LOption = '--configuration' then
      begin
        LConfigurationAll := SameText(AArgs[I], 'all');
        if LConfigurationAll then
          LConfiguration := ''
        else if SameText(AArgs[I], 'Debug') then
          LConfiguration := 'Debug'
        else if SameText(AArgs[I], 'Release') then
          LConfiguration := 'Release'
        else
          raise EArgumentException.CreateFmt(
            'Configuracao Delphi nao suportada: %s.', [AArgs[I]]);
      end
      else
      begin
        Result.Jobs := StrToInt(AArgs[I]);
        if Result.Jobs < 1 then
          raise EArgumentException.Create('--jobs deve ser maior que zero.');
      end;
    end
    else
      raise EArgumentException.Create(
        'Opcao desconhecida para build: ' + AArgs[I]);
    Inc(I);
  end;
  Result.Selection := TBoss4DBuildSelection.Create(
    LCompiler, LPlatform, LConfiguration, LCompilerAll, LPlatformAll,
    LConfigurationAll);
end;

constructor TBoss4DBuildCommand.Create(const ACompiler: IBoss4DCompiler;
  const ALogger: IBoss4DLogger;
  const ARegistrationHandler: TBoss4DIDERegistrationHandler;
  const AInventory: TBoss4DBuildInventory);
begin
  inherited Create;
  if not Assigned(ACompiler) then
    raise EArgumentNilException.Create('ACompiler');
  FCompiler := ACompiler;
  FLogger := ALogger;
  FRegistrationHandler := ARegistrationHandler;
  FInventory := AInventory;
end;

function TBoss4DBuildCommand.SourceChecksum(const APackage: TBoss4DPackage;
  const ARootDirectory: string): string;
var
  LContent: string;
  LPath: string;
begin
  LContent := APackage.Name + '|' + APackage.Version;
  LPath := TPath.Combine(ARootDirectory, FILE_PACKAGE);
  if TFile.Exists(LPath) then
    LContent := LContent + '|' + TFile.ReadAllText(LPath, TEncoding.UTF8);
  LPath := TPath.Combine(ARootDirectory, FILE_PACKAGE_LOCK);
  if TFile.Exists(LPath) then
    LContent := LContent + '|' + TFile.ReadAllText(LPath, TEncoding.UTF8);
  Result := THashSHA2.GetHashString(LContent).ToLower;
end;

function TBoss4DBuildCommand.Execute(const APackage: TBoss4DPackage;
  const ALock: TBoss4DLock; const ARootDirectory: string;
  const AOptions: TBoss4DBuildCommandOptions): TBoss4DBuildCommandResult;
var
  LDependency: TBoss4DDependency;
  LExecutor: TBoss4DBuildExecutor;
  LTargets: TBoss4DBuildTargetList;
  LExecutionOptions: TBoss4DBuildExecutionOptions;
begin
  Result := Default(TBoss4DBuildCommandResult);
  LDependency := TBoss4DDependency.Create(
    'local/' + APackage.Name, APackage.Version);
  LExecutor := TBoss4DBuildExecutor.Create(FCompiler);
  try
    LExecutionOptions := TBoss4DBuildExecutionOptions.Create(
      AOptions.Selection, SourceChecksum(APackage, ARootDirectory));
    LExecutionOptions.Force := AOptions.Force;
    LExecutionOptions.Jobs := AOptions.Jobs;
    Result.Scheduled := LExecutor.Execute(APackage, LDependency, ALock,
      ARootDirectory, LExecutionOptions);
    Result.Built := LExecutor.BuiltCount;
    Result.Skipped := LExecutor.SkippedCount;
    Result.Restored := LExecutor.RestoredCount;
    if AOptions.Explain and Assigned(FLogger) then
      for var LExplanation in LExecutor.LastExplanations do
        FLogger.Log(TBoss4DLogLevel.Info, LExplanation);

    if AOptions.RegisterTargets then
    begin
      if not Assigned(FRegistrationHandler) then
        raise EInvalidOpException.Create(
          'O registro na IDE nao esta disponivel neste ambiente.');
      LTargets := TBoss4DBuildMatrixExpander.Expand(APackage,
        AOptions.Selection);
      try
        for var LTarget in LTargets do
          if SameText(LTarget.ProjectKind, 'design') then
          begin
            var LRoot := TBoss4DBuildPaths.TargetRoot(TPath.Combine(
              ARootDirectory, FOLDER_DEPENDENCIES),
              LDependency.StorageName, LTarget.Compiler, LTarget.Platform,
              LTarget.Configuration);
            var LBplDirectory := TPath.Combine(LRoot, 'bpl');
            if not TDirectory.Exists(LBplDirectory) then
              raise EFileNotFoundException.CreateFmt(
                'Diretorio BPL nao encontrado para %s.',
                [LTarget.Identity]);
            for var LDllFile in TDirectory.GetFiles(LRoot, '*.dll',
              TSearchOption.soAllDirectories) do
            begin
              var LDllTarget := TPath.Combine(LBplDirectory,
                TPath.GetFileName(LDllFile));
              if not SameText(TPath.GetFullPath(LDllFile),
                TPath.GetFullPath(LDllTarget)) then
                TFile.Copy(LDllFile, LDllTarget, True);
            end;
            var LBplFiles := TDirectory.GetFiles(LBplDirectory, '*.bpl',
              TSearchOption.soAllDirectories);
            if Length(LBplFiles) = 0 then
              raise EFileNotFoundException.CreateFmt(
                'Nenhum BPL de design-time encontrado para %s.',
                [LTarget.Identity]);
            TArray.Sort<string>(LBplFiles);
            for var LBplIndex := 0 to Length(LBplFiles) - 1 do
            begin
              var LBplFile := LBplFiles[LBplIndex];
              var LRegistration := TBoss4DIDERegistration.Create;
              try
                LRegistration.PackageName :=
                  ChangeFileExt(ExtractFileName(LBplFile), '');
                LRegistration.OwnerPackage := APackage.Name;
                LRegistration.Compiler := LTarget.Compiler;
                LRegistration.Platform := LTarget.Platform;
                LRegistration.BplPath := LBplFile;
                LRegistration.Description := APackage.Description;
                LRegistration.SearchPath := TPath.Combine(LRoot, 'dcu');
                LRegistration.BrowsingPath := LRegistration.SearchPath;
                LRegistration.DebugDcuPath := LRegistration.SearchPath;
                if LBplIndex = 0 then
                begin
                  LRegistration.RuntimePath := LBplDirectory;
                  LRegistration.ArtifactRoot := LRoot;
                  for var LArtifact in TDirectory.GetFiles(LRoot, '*',
                    TSearchOption.soAllDirectories) do
                    if not LArtifact.Contains(
                      TPath.DirectorySeparatorChar + '.boss4d-state' +
                      TPath.DirectorySeparatorChar) then
                      LRegistration.Artifacts.Add(
                        TPath.GetFullPath(LArtifact));
                  LRegistration.Artifacts.Sort;
                  for var LHelpFile in TDirectory.GetFiles(LRoot, '*.chm',
                    TSearchOption.soAllDirectories) do
                    LRegistration.HelpFiles.Add(
                      TPath.GetFullPath(LHelpFile));
                  LRegistration.HelpFiles.Sort;
                end;
                FRegistrationHandler(LRegistration);
                Inc(Result.Registered);
              finally
                LRegistration.Free;
              end;
            end;
          end;
      finally
        LTargets.Free;
      end;
    end;
    if Assigned(FLogger) then
      FLogger.Log(TBoss4DLogLevel.Info,
        'Build: %d agendados, %d compilados, %d restaurados, %d ignorados.',
        [Result.Scheduled, Result.Built, Result.Restored, Result.Skipped]);
    if Assigned(FInventory) then
    begin
      var LDependencies := TList<string>.Create;
      try
        for var LName in APackage.Dependencies.Keys do
          LDependencies.Add(LName);
        for var LName in APackage.DevDependencies.Keys do
          if not LDependencies.Contains(LName) then
            LDependencies.Add(LName);
        FInventory.RegisterPackage(APackage.Name, ARootDirectory,
          LDependencies.ToArray);
        FInventory.Save;
      finally
        LDependencies.Free;
      end;
    end;
  finally
    LExecutor.Free;
    LDependency.Free;
  end;
end;

end.
