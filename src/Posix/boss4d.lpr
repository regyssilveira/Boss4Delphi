program boss4d;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, DateUtils, fpjson, Boss4D.Posix.Core, Boss4D.Posix.Registry,
  Boss4D.Posix.Config, Boss4D.Posix.Package, Boss4D.Posix.Operations,
  Boss4D.Posix.Compliance, Boss4D.Posix.Audit, Boss4D.Posix.Workflows,
  Boss4D.Posix.Update, Boss4D.Posix.Tools, Boss4D.Posix.Publish,
  Boss4D.Posix.RegistryCheckout, Boss4D.Posix.Project,
  Boss4D.Posix.Documentation;

procedure Help;
begin
  WriteLn('Boss4D portable CLI');
  WriteLn('Commands: version, platform, init, install, ci, add, remove, list,');
  WriteLn('          search, info, registry, package, doctor, sbom, audit,');
  WriteLn('          config, cache, self-update, tool, publish, update,');
  WriteLn('          dependencies, tree, why, run, outdated, doc');
  WriteLn('Install options: --locked --frozen-lockfile --offline --production');
  WriteLn('                 --resolution=highest|minimal');
  WriteLn('                 --progress plain|interactive --json --quiet');
  WriteLn('Add options: boss4d add <repository> [version] [--dev]');
  WriteLn('Registry options: --registry=<index-v1-or-v2-path-or-url>');
  WriteLn('Package: boss4d package install <name> [--platform <name>]');
  WriteLn('         [--compiler <version>] [--no-source-fallback]');
  WriteLn('SBOM: boss4d sbom --format cyclonedx|spdx --lock-only');
  WriteLn('      [--output <file>] [--reproducible] [--vex <file>]');
  WriteLn('Audit: boss4d audit [--fail-on low|medium|high|critical]');
  WriteLn('       [--offline] [--cache-hours <hours>] [--vex <file>]');
  WriteLn('Credentials: boss4d config auth <provider> <token>');
  WriteLn('             boss4d config auth remove <provider>');
  WriteLn('Cache: boss4d cache size|clean|prune');
  WriteLn('Update: boss4d self-update');
  WriteLn('Tools: boss4d tool install -g <source> [--name <name>]');
  WriteLn('       boss4d tool update <name> <source>|uninstall <name>|list');
  WriteLn('Publish: boss4d publish --dry-run [--output <file>]');
  WriteLn('         boss4d publish --registry <url> [--allow-dirty]');
  WriteLn('         boss4d publish --official --publisher <id>');
  WriteLn('           --repository <host/owner/name> --fingerprint <hex>');
  WriteLn('           --sign <key> --artifact-url <https-url>');
  WriteLn('           [--registry-root <checkout>] [--append-version]');
  WriteLn('Docs: boss4d doc [-o <folder>] [--no-dependencies]');
end;

function OptionValue(const APrefix, ADefault: string): string;
var
  I: Integer;
begin
  Result := ADefault;
  for I := 2 to ParamCount do
  begin
    if Pos(APrefix + '=', LowerCase(ParamStr(I))) = 1 then
      Exit(Copy(ParamStr(I), Length(APrefix) + 2, MaxInt));
    if SameText(ParamStr(I), APrefix) and (I < ParamCount) then
      Exit(ParamStr(I + 1));
  end;
end;

function HasOption(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 2 to ParamCount do
    if SameText(ParamStr(I), AName) then Exit(True);
end;

function BossHome: string;
begin
  Result := GetEnvironmentVariable('BOSS_HOME');
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
      '.boss';
end;

function FormatBytes(const AValue: Int64): string;
begin
  if AValue >= Int64(1024) * 1024 * 1024 then
    Result := FormatFloat('0.00 GB', AValue / (1024 * 1024 * 1024))
  else if AValue >= 1024 * 1024 then
    Result := FormatFloat('0.00 MB', AValue / (1024 * 1024))
  else if AValue >= 1024 then
    Result := FormatFloat('0.00 KB', AValue / 1024)
  else
    Result := IntToStr(AValue) + ' B';
end;

var
  LCommand, LVersion: string;
  LOptions: TBoss4DInstallOptions;
  LItems: TStringList;
  LRegistry: TBoss4DRegistryService;
  LEntries, LMatches: TBoss4DRegistryEntries;
  LSource: string;
  LSources, LConfigured, LSeen: TStringList;
  LConfig: TBoss4DPosixConfig;
  J: Integer;
  LFound: TBoss4DRegistryEntry;
  LVariant: TBoss4DArtifactVariant;
  LPackageService: TBoss4DPackageService;
  LPackageRequest: TBoss4DPackageRequest;
  LPackageResult: TBoss4DPackageResult;
  LPlatform, LCompiler, LTarget, LFailure: string;
  LAllowFallback: Boolean;
  LProgressMode: TBoss4DProgressMode;
  LReporter: TBoss4DProgressReporter;
  LOperationId: string;
  LDoctorResults: TStringList;
  LDoctorOk: Boolean;
  LSbomFormat: TBoss4DSbomFormat;
  LSbomOptions: TBoss4DSbomOptions;
  LSbomFormatName, LSbomOutput, LVexPath: string;
  LAuditOptions: TBoss4DAuditOptions;
  LAuditService: TBoss4DAuditService;
  LAuditSummary: TBoss4DAuditSummary;
  LCacheHoursText: string;
  LCredentialStore: TBoss4DPosixCredentialStore;
  LCacheDirectory: string;
  LRemoved: Integer;
  LUpdateService: TBoss4DPosixUpdateService;
  LUpdateResult: TBoss4DUpdateResult;
  LToolService: TBoss4DPosixToolService;
  LToolPath, LToolName, LToolSource: string;
  LTools: TStringList;
  LPublishService: TBoss4DPosixPublishService;
  LPublishOptions: TBoss4DPublishOptions;
  LOfficialPublishResult: TBoss4DOfficialPublishResult;
  LRegistryCheckoutResult: TBoss4DRegistryCheckoutResult;
  LPublishPayload, LPublishOutput, LTokenEnvironment: string;
  LPublishManifest: TJSONObject;
  LOfficialDryRun: Boolean;
  LFoundFlag: Boolean;
  LDocumentationResult: TBoss4DDocumentationResult;
  LDocumentationOutput: string;
  I: Integer;
begin
  InstallCancellationHandler;
  try
    if ParamCount = 0 then
    begin
      Help;
      Halt(0);
    end;
    LCommand := LowerCase(ParamStr(1));
    if (LCommand = 'version') or (LCommand = '--version') then
      WriteLn('v' + Boss4DVersion + '-fpc')
    else if LCommand = 'platform' then
      WriteLn(PlatformName)
    else if LCommand = 'init' then
      InitProject(GetCurrentDir)
    else if (LCommand = 'install') or (LCommand = 'ci') then
    begin
      LProgressMode := ParseProgressMode(OptionValue('--progress', ''),
        HasOption('--json'), HasOption('--quiet'));
      LReporter := TBoss4DProgressReporter.Create(LProgressMode);
      LOperationId := LCommand + '-' + IntToHex(Random(MaxInt), 8);
      FillChar(LOptions, SizeOf(LOptions), 0);
      LOptions.Locked := HasOption('--locked') or (LCommand = 'ci');
      LOptions.FrozenLockfile := HasOption('--frozen-lockfile') or
        (LCommand = 'ci');
      LOptions.Offline := HasOption('--offline');
      LOptions.Production := HasOption('--production');
      LOptions.Resolution := OptionValue('--resolution', 'highest');
      if not SameText(LOptions.Resolution, 'highest') and
         not SameText(LOptions.Resolution, 'minimal') then
        raise Exception.Create('resolution must be highest or minimal');
      try
        LReporter.Emit(NewProgressEvent(LOperationId, '', 'resolution',
          'reading manifest and lock', 0, 0));
        CheckCancelled;
        LReporter.Emit(NewProgressEvent(LOperationId, '', 'installation',
          'installing dependencies', 0, 0));
        InstallProject(GetCurrentDir, LOptions);
        CheckCancelled;
        LReporter.Emit(NewProgressEvent(LOperationId, '', 'completion',
          'dependencies installed', 1, 1));
      finally
        LReporter.Free;
      end;
    end
    else if LCommand = 'add' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d add <repository> [version] [--dev]');
      LVersion := '*';
      if (ParamCount >= 3) and (ParamStr(3)[1] <> '-') then
        LVersion := ParamStr(3);
      AddDependency(GetCurrentDir, ParamStr(2), LVersion, HasOption('--dev'));
    end
    else if LCommand = 'remove' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d remove <repository>');
      RemoveDependency(GetCurrentDir, ParamStr(2));
    end
    else if LCommand = 'list' then
    begin
      LItems := ListProject(GetCurrentDir, HasOption('--production'));
      try
        for I := 0 to LItems.Count - 1 do WriteLn(LItems[I]);
      finally
        LItems.Free;
      end;
    end
    else if (LCommand = 'dependencies') or (LCommand = 'tree') then
    begin
      LItems := DependencyTree(GetCurrentDir);
      try
        for I := 0 to LItems.Count - 1 do WriteLn(LItems[I]);
      finally
        LItems.Free;
      end;
    end
    else if LCommand = 'why' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d why <dependency>');
      LItems := WhyDependency(GetCurrentDir, ParamStr(2));
      try
        if LItems.Count = 0 then
          raise Exception.Create('dependency not found: ' + ParamStr(2));
        for I := 0 to LItems.Count - 1 do WriteLn(LItems[I]);
      finally
        LItems.Free;
      end;
    end
    else if LCommand = 'run' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d run <script>');
      RunProjectScript(GetCurrentDir, ParamStr(2));
    end
    else if LCommand = 'outdated' then
    begin
      LItems := OutdatedDependencies(GetCurrentDir);
      try
        if LItems.Count = 0 then WriteLn('all dependencies are current')
        else for I := 0 to LItems.Count - 1 do WriteLn(LItems[I]);
      finally
        LItems.Free;
      end;
    end
    else if LCommand = 'update' then
    begin
      UpdateProject(GetCurrentDir);
      WriteLn('dependencies updated');
    end
    else if LCommand = 'doc' then
    begin
      LDocumentationOutput := OptionValue('--output',
        OptionValue('-o', 'docs-api'));
      if Trim(LDocumentationOutput) = '' then
        raise Exception.Create('documentation output directory cannot be empty');
      LDocumentationResult := GenerateDocumentation(GetCurrentDir,
        LDocumentationOutput, not HasOption('--no-dependencies'));
      WriteLn(Format('%d documented symbols from %d source files written to %s',
        [LDocumentationResult.Symbols, LDocumentationResult.Files,
         LDocumentationResult.OutputDirectory]));
    end
    else if (LCommand = 'search') or (LCommand = 'info') then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d ' + LCommand + ' <query>');
      LSource := OptionValue('--registry', GetEnvironmentVariable(
        'BOSS4D_REGISTRY'));
      LSources := TStringList.Create;
      LConfigured := nil;
      LSeen := TStringList.Create;
      if LSource <> '' then LSources.Add(LSource)
      else
      begin
        LSources.Add(PublicRegistryUrl);
        LConfig := TBoss4DPosixConfig.Create;
        try
          LConfigured := LConfig.Registries;
          for I := 0 to LConfigured.Count - 1 do
            if LSources.IndexOf(LConfigured[I]) < 0 then
              LSources.Add(LConfigured[I]);
        finally
          LConfigured.Free;
          LConfig.Free;
        end;
      end;
      LRegistry := TBoss4DRegistryService.Create;
      try
        if LCommand = 'search' then
          for J := 0 to LSources.Count - 1 do
          begin
            LEntries := LRegistry.Load(LSources[J], HasOption('--offline'));
            try
              LMatches := LEntries.Search(ParamStr(2));
              try
                for I := 0 to LMatches.Count - 1 do
                  if LSeen.IndexOf(LowerCase(LMatches[I].Name)) < 0 then
                  begin
                    LSeen.Add(LowerCase(LMatches[I].Name));
                    WriteLn(LMatches[I].Name + #9 + LMatches[I].Version + #9 +
                      LMatches[I].Repository);
                  end;
              finally
                LMatches.Free;
              end;
            finally
              LEntries.Free;
            end;
          end
        else
        begin
          LFoundFlag := False;
          for J := 0 to LSources.Count - 1 do
          begin
            LEntries := LRegistry.Load(LSources[J], HasOption('--offline'));
            try
              LFound := LEntries.Find(ParamStr(2));
              if Assigned(LFound) then
              begin
                WriteLn('name: ' + LFound.Name);
                WriteLn('version: ' + LFound.Version);
                WriteLn('repository: ' + LFound.Repository);
                WriteLn('license: ' + LFound.LicenseName);
                WriteLn('description: ' + LFound.Description);
                WriteLn('source: ' + LFound.Source);
                if LFound.Revoked then
                  WriteLn('revoked: true (' + LFound.RevocationReason + ')');
                LFoundFlag := True;
                Break;
              end;
            finally
              LEntries.Free;
            end;
          end;
          if not LFoundFlag then
            raise Exception.Create('package not found: ' + ParamStr(2));
        end;
      finally
        LRegistry.Free;
        LSeen.Free;
        LSources.Free;
      end;
    end
    else if LCommand = 'registry' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d registry add|remove|list [source]');
      LConfig := TBoss4DPosixConfig.Create;
      try
        if SameText(ParamStr(2), 'add') then
        begin
          if ParamCount < 3 then raise Exception.Create('registry source is required');
          LConfig.AddRegistry(ParamStr(3));
        end
        else if SameText(ParamStr(2), 'remove') then
        begin
          if ParamCount < 3 then raise Exception.Create('registry source is required');
          LConfig.RemoveRegistry(ParamStr(3));
        end
        else if SameText(ParamStr(2), 'list') then
        begin
          LConfigured := LConfig.Registries;
          try
            WriteLn(PublicRegistryUrl + #9 + '[public]');
            for I := 0 to LConfigured.Count - 1 do
              WriteLn(LConfigured[I] + #9 + '[configured]');
          finally
            LConfigured.Free;
          end;
        end
        else
          raise Exception.Create('unknown registry command: ' + ParamStr(2));
      finally
        LConfig.Free;
      end;
    end
    else if LCommand = 'package' then
    begin
      if (ParamCount < 3) or not SameText(ParamStr(2), 'install') then
        raise Exception.Create('usage: boss4d package install <name>');
      LAllowFallback := not HasOption('--no-source-fallback');
      LProgressMode := ParseProgressMode(OptionValue('--progress', ''),
        HasOption('--json'), HasOption('--quiet'));
      LReporter := TBoss4DProgressReporter.Create(LProgressMode);
      LOperationId := 'package-' + IntToHex(Random(MaxInt), 8);
      LPlatform := OptionValue('--platform', PlatformName);
      LCompiler := OptionValue('--compiler', '');
      LSource := OptionValue('--registry', GetEnvironmentVariable(
        'BOSS4D_REGISTRY'));
      LSources := TStringList.Create;
      LConfigured := nil;
      if LSource <> '' then LSources.Add(LSource)
      else
      begin
        LSources.Add(PublicRegistryUrl);
        LConfig := TBoss4DPosixConfig.Create;
        try
          LConfigured := LConfig.Registries;
          for I := 0 to LConfigured.Count - 1 do
            if LSources.IndexOf(LConfigured[I]) < 0 then
              LSources.Add(LConfigured[I]);
        finally
          LConfigured.Free;
          LConfig.Free;
        end;
      end;
      try
        LRegistry := TBoss4DRegistryService.Create;
        LFoundFlag := False;
        try
          LReporter.Emit(NewProgressEvent(LOperationId, ParamStr(3),
            'resolution', 'searching registries', 0, 0));
          CheckCancelled;
          for J := 0 to LSources.Count - 1 do
          begin
            LEntries := LRegistry.Load(LSources[J], HasOption('--offline'));
            try
              LFound := LEntries.Find(ParamStr(3));
              if not Assigned(LFound) then Continue;
              if LFound.Revoked then
                raise Exception.Create('registry version revoked: ' +
                  LFound.Name + '@' + LFound.Version + ' - ' +
                  LFound.RevocationReason);
              LFoundFlag := True;
            LVariant := LFound.SelectVariant(LPlatform, LCompiler);
            if Assigned(LVariant) then
            begin
              LFound.ArtifactUrl := LVariant.ArtifactUrl;
              LFound.ArtifactDigest := LVariant.ArtifactDigest;
              LFound.SignatureUrl := LVariant.SignatureUrl;
              LFound.ProvenanceUrl := LVariant.ProvenanceUrl;
              LFound.ArtifactMirrors := LVariant.ArtifactMirrors;
            end
            else if LFound.Variants.Count > 0 then
            begin
              LFound.ArtifactUrl := '';
              LFound.ArtifactDigest := '';
            end;
            if (LFound.ArtifactUrl <> '') and
               (LFound.ArtifactDigest <> '') then
            begin
              LPackageRequest.ArtifactUrl := ResolveRegistryReference(
                LFound.Source, LFound.ArtifactUrl);
              LPackageRequest.ArtifactMirrors := ResolveRegistryReferences(
                LFound.Source, LFound.ArtifactMirrors);
              LPackageRequest.Sha256 := LFound.ArtifactDigest;
              LPackageRequest.SignatureUrl := ResolveRegistryReference(
                LFound.Source, LFound.SignatureUrl);
              LPackageRequest.ProvenanceUrl := ResolveRegistryReference(
                LFound.Source, LFound.ProvenanceUrl);
              LTarget := IncludeTrailingPathDelimiter(GetCurrentDir) +
                'modules' + DirectorySeparator +
                DependencyTarget(LFound.Repository);
              LPackageRequest.TargetDirectory := LTarget;
              LPackageService := TBoss4DPackageService.Create;
              try
                try
                  LReporter.Emit(NewProgressEvent(LOperationId, LFound.Name,
                    'verification', 'verifying immutable artifact', 0, 0));
                  CheckCancelled;
                  LPackageResult := LPackageService.Install(LPackageRequest);
                  RecordArtifactDependency(GetCurrentDir, LFound.Repository,
                    LFound.Version, LPackageResult.Digest,
                    'modules/' + DependencyTarget(LFound.Repository));
                  LReporter.Emit(NewProgressEvent(LOperationId, LFound.Name,
                    'completion', 'verified package installed', 1, 1));
                  Exit;
                except
                  on E: Exception do
                  begin
                    LFailure := E.Message;
                    if not LAllowFallback then raise;
                    LReporter.Emit(NewProgressEvent(LOperationId, LFound.Name,
                      'fallback', 'artifact rejected; using Git: ' +
                      LFailure, 0, 0));
                  end;
                end;
              finally
                LPackageService.Free;
              end;
            end
            else if not LAllowFallback then
              raise Exception.Create(
                'package has no compatible immutable artifact');
            AddDependency(GetCurrentDir, LFound.Repository,
              LFound.Version, False);
            CheckCancelled;
            InstallProject(GetCurrentDir);
            LReporter.Emit(NewProgressEvent(LOperationId, LFound.Name,
              'completion', 'package installed from Git', 1, 1));
            Exit;
            finally
              LEntries.Free;
            end;
          end;
        finally
          LRegistry.Free;
        end;
      finally
        LSources.Free;
        LReporter.Free;
      end;
      if not LFoundFlag then
        raise Exception.Create('package not found: ' + ParamStr(3));
    end
    else if LCommand = 'doctor' then
    begin
      LDoctorResults := RunDoctor;
      try
        for I := 0 to LDoctorResults.Count - 1 do
          WriteLn(LDoctorResults[I]);
        LDoctorOk := DoctorPassed(LDoctorResults);
      finally
        LDoctorResults.Free;
      end;
      if not LDoctorOk then
        raise Exception.Create('doctor found required tools missing');
    end
    else if LCommand = 'sbom' then
    begin
      LSbomFormatName := LowerCase(OptionValue('--format',
        OptionValue('--type', 'cyclonedx')));
      if LSbomFormatName = 'cyclonedx' then
      begin
        LSbomFormat := sfCycloneDX;
        LSbomOutput := OptionValue('--output', 'sbom.cdx.json');
      end
      else if LSbomFormatName = 'spdx' then
      begin
        LSbomFormat := sfSpdx;
        LSbomOutput := OptionValue('--output', 'sbom.spdx.json');
      end
      else
        raise Exception.Create('usage: --format must be cyclonedx or spdx');
      LVexPath := OptionValue('--vex', '');
      LSbomOptions := DefaultSbomOptions(LSbomFormat);
      LSbomOptions.VexPath := LVexPath;
      LSbomOptions.Reproducible := HasOption('--reproducible');
      LSbomOptions.Strict := HasOption('--strict');
      LSbomOptions.Validate := HasOption('--validate');
      GenerateLockSbom(IncludeTrailingPathDelimiter(GetCurrentDir) +
        'boss-lock.json', LSbomOutput, LSbomOptions);
      WriteLn('SBOM generated: ' + ExpandFileName(LSbomOutput));
    end
    else if LCommand = 'audit' then
    begin
      LAuditOptions := DefaultAuditOptions;
      LAuditOptions.Offline := HasOption('--offline');
      LAuditOptions.FailOn := LowerCase(OptionValue('--fail-on', 'high'));
      LAuditOptions.VexPath := OptionValue('--vex', '');
      LCacheHoursText := OptionValue('--cache-hours', '24');
      if not TryStrToInt(LCacheHoursText, LAuditOptions.CacheHours) or
         (LAuditOptions.CacheHours < 0) then
        raise Exception.Create('usage: --cache-hours requires a non-negative integer');
      LAuditService := TBoss4DAuditService.Create;
      try
        LAuditSummary := LAuditService.Execute(
          IncludeTrailingPathDelimiter(GetCurrentDir) + 'boss-lock.json',
          LAuditOptions);
        for I := 0 to LAuditService.Findings.Count - 1 do
          WriteLn(LAuditService.Findings[I]);
      finally
        LAuditService.Free;
      end;
      WriteLn('audited packages: ' + IntToStr(LAuditSummary.Packages));
      WriteLn('vulnerabilities: ' +
        IntToStr(LAuditSummary.Vulnerabilities));
      WriteLn('suppressed: ' + IntToStr(LAuditSummary.Suppressed));
      if LAuditSummary.PolicyViolations > 0 then
        raise Exception.Create('audit policy violation: ' +
          IntToStr(LAuditSummary.PolicyViolations));
    end
    else if LCommand = 'config' then
    begin
      if (ParamCount < 3) or not SameText(ParamStr(2), 'auth') then
        raise Exception.Create(
          'usage: boss4d config auth <provider> <token>');
      LCredentialStore := TBoss4DPosixCredentialStore.Create;
      try
        if SameText(ParamStr(3), 'remove') then
        begin
          if ParamCount < 4 then
            raise Exception.Create(
              'usage: boss4d config auth remove <provider>');
          LCredentialStore.Remove(ParamStr(4));
          WriteLn('credential removed: ' + LowerCase(ParamStr(4)));
        end
        else
        begin
          if ParamCount < 4 then
            raise Exception.Create(
              'usage: boss4d config auth <provider> <token>');
          LCredentialStore.Store(ParamStr(3), ParamStr(4));
          WriteLn('credential stored in Secret Service: ' +
            LowerCase(ParamStr(3)));
        end;
      finally
        LCredentialStore.Free;
      end;
    end
    else if LCommand = 'cache' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d cache size|clean|prune');
      LCacheDirectory := IncludeTrailingPathDelimiter(BossHome) + 'cache';
      if SameText(ParamStr(2), 'size') then
        WriteLn(FormatBytes(DirectorySize(LCacheDirectory)))
      else if SameText(ParamStr(2), 'clean') then
      begin
        LRemoved := CleanCacheDirectory(LCacheDirectory);
        WriteLn('cache entries removed: ' + IntToStr(LRemoved));
      end
      else if SameText(ParamStr(2), 'prune') then
      begin
        LRemoved := PruneCacheDirectory(LCacheDirectory, IncDay(Now, -30));
        WriteLn('stale cache entries removed: ' + IntToStr(LRemoved));
      end
      else
        raise Exception.Create('usage: boss4d cache size|clean|prune');
    end
    else if (LCommand = 'self-update') or (LCommand = 'upgrade') then
    begin
      LUpdateService := TBoss4DPosixUpdateService.Create;
      try
        LUpdateResult := LUpdateService.Execute(Boss4DVersion,
          ExpandFileName(ParamStr(0)));
      finally
        LUpdateService.Free;
      end;
      if LUpdateResult.Updated then
        WriteLn('Boss4D updated to ' + LUpdateResult.Version)
      else
        WriteLn('Boss4D is current: ' + LUpdateResult.Version);
    end
    else if LCommand = 'tool' then
    begin
      if ParamCount < 2 then
        raise Exception.Create('usage: boss4d tool install|update|uninstall|list');
      LToolService := TBoss4DPosixToolService.Create;
      try
        if SameText(ParamStr(2), 'install') then
        begin
          if (ParamCount < 4) or not SameText(ParamStr(3), '-g') then
            raise Exception.Create(
              'usage: boss4d tool install -g <source> [--name <name>]');
          LToolSource := ParamStr(4);
          LToolName := OptionValue('--name', '');
          LToolPath := LToolService.Install(LToolSource, LToolName);
          WriteLn('global tool installed: ' + LToolPath);
        end
        else if SameText(ParamStr(2), 'update') then
        begin
          if ParamCount < 4 then
            raise Exception.Create(
              'usage: boss4d tool update <name> <source>');
          LToolPath := LToolService.Install(ParamStr(4), ParamStr(3));
          WriteLn('global tool updated: ' + LToolPath);
        end
        else if SameText(ParamStr(2), 'uninstall') then
        begin
          if ParamCount < 3 then
            raise Exception.Create('usage: boss4d tool uninstall <name>');
          LToolService.Uninstall(ParamStr(3));
          WriteLn('global tool uninstalled: ' + ParamStr(3));
        end
        else if SameText(ParamStr(2), 'list') then
        begin
          LTools := LToolService.List;
          try
            for I := 0 to LTools.Count - 1 do WriteLn(LTools[I]);
          finally
            LTools.Free;
          end;
        end
        else
          raise Exception.Create(
            'usage: boss4d tool install|update|uninstall|list');
      finally
        LToolService.Free;
      end;
    end
    else if LCommand = 'publish' then
    begin
      LPublishOptions := Default(TBoss4DPublishOptions);
      LPublishOptions.RegistryUrl := OptionValue('--registry', '');
      LOfficialDryRun := HasOption('--dry-run');
      LPublishOptions.DryRun := LOfficialDryRun;
      LPublishOptions.RequireCleanGit := not HasOption('--allow-dirty');
      LPublishOptions.RunTests := not HasOption('--skip-tests');
      LPublishOptions.Official := HasOption('--official');
      LPublishOptions.Publisher := OptionValue('--publisher', '');
      LPublishOptions.Repository := OptionValue('--repository', '');
      LPublishOptions.SignerFingerprint :=
        OptionValue('--fingerprint', '');
      LPublishOptions.SigningKey := OptionValue('--sign', '');
      LPublishOptions.ArtifactUrl := OptionValue('--artifact-url', '');
      LPublishOptions.ArtifactOutput :=
        OptionValue('--artifact-output', '');
      LPublishOptions.SubmissionOutput :=
        OptionValue('--submission-output', '');
      LPublishOptions.RegistryRoot := OptionValue('--registry-root', '');
      LPublishOptions.AppendVersion := HasOption('--append-version');
      if LPublishOptions.Official then
      begin
        LPublishManifest := LoadJsonObject(IncludeTrailingPathDelimiter(
          GetCurrentDir) + 'boss.json');
        try
          if LPublishOptions.ArtifactOutput = '' then
            LPublishOptions.ArtifactOutput :=
              IncludeTrailingPathDelimiter(GetCurrentDir) + 'dist/' +
              LPublishManifest.Get('name', 'package') + '-' +
              LPublishManifest.Get('version', '0.0.0') + '.b4dpkg';
          if LPublishOptions.SubmissionOutput = '' then
            LPublishOptions.SubmissionOutput :=
              IncludeTrailingPathDelimiter(GetCurrentDir) + 'dist/' +
              LPublishManifest.Get('name', 'package') + '-' +
              LPublishManifest.Get('version', '0.0.0') +
              '.registry.json';
        finally
          LPublishManifest.Free;
        end;
        LPublishOptions.DryRun := True;
      end;
      LTokenEnvironment := OptionValue('--token-env',
        'BOSS4D_PUBLISH_TOKEN');
      LPublishOptions.Token := GetEnvironmentVariable(LTokenEnvironment);
      if (not LPublishOptions.DryRun) and
         (LPublishOptions.Token = '') then
      begin
        LCredentialStore := TBoss4DPosixCredentialStore.Create;
        try
          try
            LPublishOptions.Token := LCredentialStore.Retrieve('registry');
          except
            LPublishOptions.Token := '';
          end;
        finally
          LCredentialStore.Free;
        end;
      end;
      LPublishOutput := OptionValue('--output', '');
      LPublishService := TBoss4DPosixPublishService.Create;
      try
        LPublishPayload := LPublishService.Execute(GetCurrentDir,
          LPublishOptions);
        if LPublishOptions.Official then
        begin
          if LPublishOptions.SigningKey = '' then
            raise Exception.Create('signing key is required');
          LPublishService.BuildOfficialDocument(GetCurrentDir,
            StringOfChar('0', 64), LPublishOptions);
          if LOfficialDryRun then
            WriteLn('official dry-run approved: artifact=' +
              ExpandFileName(LPublishOptions.ArtifactOutput) +
              '; submission=' +
              ExpandFileName(LPublishOptions.SubmissionOutput))
          else
          begin
            LOfficialPublishResult := LPublishService.PrepareOfficial(
              GetCurrentDir, LPublishOptions);
            try
              if LPublishOptions.RegistryRoot <> '' then
              begin
                LRegistryCheckoutResult := ApplyRegistrySubmission(
                  LPublishOptions.RegistryRoot,
                  LOfficialPublishResult.SubmissionPath,
                  LPublishOptions.AppendVersion);
                WriteLn('Registry checkout updated: ' +
                  LRegistryCheckoutResult.PackagePath);
              end;
              WriteLn('official bundle prepared: ' +
                LOfficialPublishResult.ArtifactPath);
              WriteLn('registry PR document: ' +
                LOfficialPublishResult.SubmissionPath);
            except
              if FileExists(LOfficialPublishResult.SubmissionPath) then
                DeleteFile(LOfficialPublishResult.SubmissionPath);
              if FileExists(LOfficialPublishResult.SignaturePath) then
                DeleteFile(LOfficialPublishResult.SignaturePath);
              if FileExists(LOfficialPublishResult.ProvenancePath) then
                DeleteFile(LOfficialPublishResult.ProvenancePath);
              if FileExists(LOfficialPublishResult.ArtifactPath) then
                DeleteFile(LOfficialPublishResult.ArtifactPath);
              raise;
            end;
          end;
        end
        else if LPublishOutput <> '' then
        begin
          LItems := TStringList.Create;
          try
            LItems.Text := LPublishPayload;
            LItems.SaveToFile(ExpandFileName(LPublishOutput));
          finally
            LItems.Free;
          end;
        end
        else if LPublishOptions.DryRun then
          WriteLn(LPublishPayload)
        else
          WriteLn('package published');
      finally
        LPublishService.Free;
      end;
    end
    else if (LCommand = 'help') or (LCommand = '--help') then
      Help
    else
      raise Exception.Create('unknown command: ' + LCommand);
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'boss4d: ' + E.Message);
      Halt(ClassifyExitCode(E.Message));
    end;
  end;
end.
