program boss4d;

{$mode objfpc}{$H+}

uses
  SysUtils, Boss4D.Posix.Core;

procedure Help;
begin
  WriteLn('Boss4D portable CLI');
  WriteLn('Commands: version, platform, init, install');
end;

var
  LCommand: string;
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
    else if LCommand = 'install' then
      InstallProject(GetCurrentDir)
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
