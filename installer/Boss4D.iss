[Setup]
AppName=Boss4D
AppVersion=1.0.0
DefaultDirName={userappdata}\Boss4D
DefaultGroupName=Boss4D
OutputDir=Output
OutputBaseFilename=Boss4D_Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
ChangesEnvironment=yes

[Files]
Source: "..\dist\bin\boss4d.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\bin\boss4d_x64.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\bin\Boss4D.GUI.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\bin\Boss4D.GUI_x64.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\plugins\Boss4D.IDE.Plugin_11.bpl"; DestDir: "{app}\plugins"; Flags: ignoreversion; Check: IsDelphi11Installed
Source: "..\dist\plugins\Boss4D.IDE.Plugin_12.bpl"; DestDir: "{app}\plugins"; Flags: ignoreversion; Check: IsDelphi12Installed
Source: "..\dist\plugins\Boss4D.IDE.Plugin_13.bpl"; DestDir: "{app}\plugins"; Flags: ignoreversion; Check: IsDelphi13Installed

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Icons]
Name: "{group}\Boss4D GUI"; Filename: "{app}\bin\Boss4D.GUI_x64.exe"; Check: Is64BitInstallMode
Name: "{group}\Boss4D GUI"; Filename: "{app}\bin\Boss4D.GUI.exe"; Check: not Is64BitInstallMode
Name: "{userdesktop}\Boss4D GUI"; Filename: "{app}\bin\Boss4D.GUI_x64.exe"; Tasks: desktopicon; Check: Is64BitInstallMode
Name: "{userdesktop}\Boss4D GUI"; Filename: "{app}\bin\Boss4D.GUI.exe"; Tasks: desktopicon; Check: not Is64BitInstallMode

[Code]
var
  IDEOptionPage: TInputOptionWizardPage;
  Delphi11Idx, Delphi12Idx, Delphi13Idx: Integer;

function IsDelphi11Installed: Boolean;
begin
  Result := RegKeyExists(HKCU, 'Software\Embarcadero\BDS\22.0');
end;

function IsDelphi12Installed: Boolean;
begin
  Result := RegKeyExists(HKCU, 'Software\Embarcadero\BDS\23.0');
end;

function IsDelphi13Installed: Boolean;
begin
  Result := RegKeyExists(HKCU, 'Software\Embarcadero\BDS\37.0');
end;

procedure InitializeWizard;
begin
  Delphi11Idx := -1;
  Delphi12Idx := -1;
  Delphi13Idx := -1;

  // Cria pagina customizada para selecao das IDEs
  IDEOptionPage := CreateInputOptionPage(wpSelectDir,
    'Integracao com a IDE do Delphi', 'Selecione em quais IDEs deseja instalar o plugin contextual do Boss4D',
    'As versoes compativeis encontradas estao listadas abaixo:',
    False, False);

  if IsDelphi11Installed then
    Delphi11Idx := IDEOptionPage.Add('Delphi 11 (Alexandria)');
  
  if IsDelphi12Installed then
    Delphi12Idx := IDEOptionPage.Add('Delphi 12 (Athens)');

  if IsDelphi13Installed then
    Delphi13Idx := IDEOptionPage.Add('Delphi 13 (Florence)');
end;

procedure RegisterPlugin(BDSVersion: string; BPLName: string);
var
  RegKey: string;
begin
  RegKey := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known Packages';
  if RegWriteStringValue(HKCU, RegKey, ExpandConstant('{app}\plugins\' + BPLName), 'Boss4D IDE Integration Plugin') then
    Log('Plugin registrado com sucesso na IDE ' + BDSVersion)
  else
    Log('Falha ao registrar o plugin na IDE ' + BDSVersion);
end;

procedure UnregisterPlugin(BDSVersion: string; BPLName: string);
var
  RegKey: string;
  BPLPath: string;
begin
  RegKey := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known Packages';
  BPLPath := ExpandConstant('{app}\plugins\' + BPLName);
  if RegValueExists(HKCU, RegKey, BPLPath) then
  begin
    if RegDeleteValue(HKCU, RegKey, BPLPath) then
      Log('Plugin removido com sucesso da IDE ' + BDSVersion)
    else
      Log('Falha ao remover o plugin da IDE ' + BDSVersion);
  end;
end;

procedure AddToPath;
var
  PathStr: string;
  BinPath: string;
begin
  BinPath := ExpandConstant('{app}\bin');
  if RegQueryStringValue(HKCU, 'Environment', 'PATH', PathStr) then
  begin
    if Pos(BinPath, PathStr) = 0 then
    begin
      PathStr := PathStr + ';' + BinPath;
      RegWriteExpandStringValue(HKCU, 'Environment', 'PATH', PathStr);
    end;
  end
  else
  begin
    RegWriteExpandStringValue(HKCU, 'Environment', 'PATH', BinPath);
  end;
end;

procedure RemoveFromPath;
var
  PathStr: string;
  BinPath: string;
  PosBin: Integer;
begin
  BinPath := ExpandConstant('{app}\bin');
  if RegQueryStringValue(HKCU, 'Environment', 'PATH', PathStr) then
  begin
    PosBin := Pos(BinPath, PathStr);
    if PosBin > 0 then
    begin
      if PosBin = 1 then
      begin
        if Length(PathStr) > Length(BinPath) then
          Delete(PathStr, 1, Length(BinPath) + 1)
        else
          PathStr := '';
      end
      else
      begin
        Delete(PathStr, PosBin - 1, Length(BinPath) + 1);
      end;
      
      if PathStr = '' then
        RegDeleteValue(HKCU, 'Environment', 'PATH')
      else
        RegWriteExpandStringValue(HKCU, 'Environment', 'PATH', PathStr);
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Delphi 11 (Alexandria)
    if Delphi11Idx <> -1 then
    begin
      if IDEOptionPage.Values[Delphi11Idx] then
        RegisterPlugin('22.0', 'Boss4D.IDE.Plugin_11.bpl')
      else
        UnregisterPlugin('22.0', 'Boss4D.IDE.Plugin_11.bpl');
    end;

    // Delphi 12 (Athens)
    if Delphi12Idx <> -1 then
    begin
      if IDEOptionPage.Values[Delphi12Idx] then
        RegisterPlugin('23.0', 'Boss4D.IDE.Plugin_12.bpl')
      else
        UnregisterPlugin('23.0', 'Boss4D.IDE.Plugin_12.bpl');
    end;

    // Delphi 13 (Florence)
    if Delphi13Idx <> -1 then
    begin
      if IDEOptionPage.Values[Delphi13Idx] then
        RegisterPlugin('37.0', 'Boss4D.IDE.Plugin_13.bpl')
      else
        UnregisterPlugin('37.0', 'Boss4D.IDE.Plugin_13.bpl');
    end;

    // Adiciona pasta bin no PATH do Usuario
    AddToPath;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    // Limpa registros de todas as IDEs
    UnregisterPlugin('22.0', 'Boss4D.IDE.Plugin_11.bpl');
    UnregisterPlugin('23.0', 'Boss4D.IDE.Plugin_12.bpl');
    UnregisterPlugin('37.0', 'Boss4D.IDE.Plugin_13.bpl');

    // Limpa variavel de ambiente PATH
    RemoveFromPath;
  end;
end;
