program boss4d;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Boss4D.Posix.Core, Boss4D.Posix.Registry,
  Boss4D.Posix.Config, Boss4D.Posix.Package;

procedure Help;
begin
  WriteLn('Boss4D portable CLI');
  WriteLn('Commands: version, platform, init, install, ci, add, remove, list, search, info, registry, package');
  WriteLn('Install options: --locked --frozen-lockfile --offline --production');
  WriteLn('                 --resolution=highest|minimal');
  WriteLn('Add options: boss4d add <repository> [version] [--dev]');
  WriteLn('Registry options: --registry=<index-v1-or-v2-path-or-url>');
  WriteLn('Package: boss4d package install <name> [--platform <name>]');
  WriteLn('         [--compiler <version>] [--no-source-fallback]');
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
  LFoundFlag: Boolean;
  I: Integer;
begin
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
      InstallProject(GetCurrentDir, LOptions);
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
      LRegistry := TBoss4DRegistryService.Create;
      LFoundFlag := False;
      try
        for J := 0 to LSources.Count - 1 do
        begin
          LEntries := LRegistry.Load(LSources[J], HasOption('--offline'));
          try
            LFound := LEntries.Find(ParamStr(3));
            if not Assigned(LFound) then Continue;
            LFoundFlag := True;
            LVariant := LFound.SelectVariant(LPlatform, LCompiler);
            if Assigned(LVariant) then
            begin
              LFound.ArtifactUrl := LVariant.ArtifactUrl;
              LFound.ArtifactDigest := LVariant.ArtifactDigest;
              LFound.SignatureUrl := LVariant.SignatureUrl;
              LFound.ProvenanceUrl := LVariant.ProvenanceUrl;
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
                  LPackageResult := LPackageService.Install(LPackageRequest);
                  RecordArtifactDependency(GetCurrentDir, LFound.Repository,
                    LFound.Version, LPackageResult.Digest,
                    'modules/' + DependencyTarget(LFound.Repository));
                  WriteLn('verified package installed: ' + LFound.Name +
                    ' (' + IntToStr(LPackageResult.FileCount) + ' files)');
                  Exit;
                except
                  on E: Exception do
                  begin
                    LFailure := E.Message;
                    if not LAllowFallback then raise;
                    WriteLn(StdErr, 'boss4d: artifact rejected; using Git: ' +
                      LFailure);
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
            InstallProject(GetCurrentDir);
            WriteLn('package installed from Git: ' + LFound.Name);
            Exit;
          finally
            LEntries.Free;
          end;
        end;
      finally
        LRegistry.Free;
        LSources.Free;
      end;
      if not LFoundFlag then
        raise Exception.Create('package not found: ' + ParamStr(3));
    end
    else if (LCommand = 'help') or (LCommand = '--help') then
      Help
    else
      raise Exception.Create('unknown command: ' + LCommand);
  except
    on E: Exception do
    begin
      WriteLn(StdErr, 'boss4d: ' + E.Message);
      Halt(1);
    end;
  end;
end.
