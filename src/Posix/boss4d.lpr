program boss4d;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Boss4D.Posix.Core, Boss4D.Posix.Registry;

procedure Help;
begin
  WriteLn('Boss4D portable CLI');
  WriteLn('Commands: version, platform, init, install, ci, add, remove, list, search, info');
  WriteLn('Install options: --locked --frozen-lockfile --offline --production');
  WriteLn('                 --resolution=highest|minimal');
  WriteLn('Add options: boss4d add <repository> [version] [--dev]');
  WriteLn('Registry options: --registry=<index-v1-or-v2-path-or-url>');
end;

function OptionValue(const APrefix, ADefault: string): string;
var
  I: Integer;
begin
  Result := ADefault;
  for I := 2 to ParamCount do
    if Pos(APrefix + '=', LowerCase(ParamStr(I))) = 1 then
      Exit(Copy(ParamStr(I), Length(APrefix) + 2, MaxInt));
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
  LEntry: TBoss4DRegistryEntry;
  LSource: string;
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
      if LSource = '' then LSource := PublicRegistryUrl;
      LRegistry := TBoss4DRegistryService.Create;
      try
        LEntries := LRegistry.Load(LSource);
        try
          if LCommand = 'search' then
          begin
            LMatches := LEntries.Search(ParamStr(2));
            try
              for I := 0 to LMatches.Count - 1 do
                WriteLn(LMatches[I].Name + #9 + LMatches[I].Version + #9 +
                  LMatches[I].Repository);
            finally
              LMatches.Free;
            end;
          end
          else
          begin
            LEntry := LEntries.Find(ParamStr(2));
            if not Assigned(LEntry) then
              raise Exception.Create('package not found: ' + ParamStr(2));
            WriteLn('name: ' + LEntry.Name);
            WriteLn('version: ' + LEntry.Version);
            WriteLn('repository: ' + LEntry.Repository);
            WriteLn('license: ' + LEntry.LicenseName);
            WriteLn('description: ' + LEntry.Description);
            WriteLn('source: ' + LEntry.Source);
          end;
        finally
          LEntries.Free;
        end;
      finally
        LRegistry.Free;
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
      Halt(1);
    end;
  end;
end.
