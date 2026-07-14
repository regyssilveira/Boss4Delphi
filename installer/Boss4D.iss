[Setup]
AppName=Boss4D
AppVersion=1.0.2
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
Source: "..\dist\plugins\11\Boss4D.IDE.Plugin.bpl"; DestDir: "{commondocs}\Embarcadero\Studio\22.0\Bpl"; Flags: ignoreversion; Check: IsDelphi11Installed
Source: "..\dist\plugins\12\Boss4D.IDE.Plugin.bpl"; DestDir: "{commondocs}\Embarcadero\Studio\23.0\Bpl"; Flags: ignoreversion; Check: IsDelphi12Installed
Source: "..\dist\plugins\13\Boss4D.IDE.Plugin.bpl"; DestDir: "{commondocs}\Embarcadero\Studio\37.0\Bpl"; Flags: ignoreversion; Check: IsDelphi13Installed

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

  // Cria pagina customizada para selecao das IDEs com nota explicativa sobre suporte
  IDEOptionPage := CreateInputOptionPage(wpSelectDir,
    'Integracao com a IDE do Delphi', 
    'Selecione em quais IDEs deseja registrar o plugin de integracao do Boss4D.',
    'Nota: Apenas as versoes do Delphi 11 (Alexandria), Delphi 12 (Athens) e Delphi 13 (Florence) sao compativeis. ' +
    'Versoes anteriores nao sao suportadas.' + #13#10 + #13#10 +
    'Abaixo sao mostradas apenas as instalacoes suportadas que foram identificadas na sua maquina:',
    False, False);

  if IsDelphi11Installed then
    Delphi11Idx := IDEOptionPage.Add('Delphi 11 (Alexandria)')
  else
    Log('Delphi 11 nao detectado.');
  
  if IsDelphi12Installed then
    Delphi12Idx := IDEOptionPage.Add('Delphi 12 (Athens)')
  else
    Log('Delphi 12 nao detectado.');

  if IsDelphi13Installed then
    Delphi13Idx := IDEOptionPage.Add('Delphi 13 (Florence)')
  else
    Log('Delphi 13 nao detectado.');

  if (not IsDelphi11Installed) and (not IsDelphi12Installed) and (not IsDelphi13Installed) then
  begin
    IDEOptionPage.Add('(Nenhuma versao do Delphi 11, 12 ou 13 foi identificada no seu sistema)');
  end;
end;

procedure RegisterPlugin(BDSVersion: string; SubFolder: string);
var
  RegKey: string;
  BPLPath: string;
  OldRegKey: string;
begin
  BPLPath := ExpandConstant('{commondocs}\Embarcadero\Studio\' + BDSVersion + '\Bpl\Boss4D.IDE.Plugin.bpl');
  
  // Limpa registro antigo em Known IDE Packages caso exista
  OldRegKey := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known IDE Packages';
  if RegValueExists(HKCU, OldRegKey, BPLPath) then
    RegDeleteValue(HKCU, OldRegKey, BPLPath);

  // Registra na chave Known Packages (como design-time package)
  RegKey := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known Packages';
  if RegWriteStringValue(HKCU, RegKey, BPLPath, 'Boss4D - RAD Studio IDE Integration Plugin') then
    Log('Plugin registrado com sucesso na chave Known Packages da IDE ' + BDSVersion)
  else
    Log('Falha ao registrar o plugin na chave Known Packages da IDE ' + BDSVersion);
end;

procedure UnregisterPlugin(BDSVersion: string; SubFolder: string);
var
  RegKey1, RegKey2: string;
  BPLPath: string;
begin
  BPLPath := ExpandConstant('{commondocs}\Embarcadero\Studio\' + BDSVersion + '\Bpl\Boss4D.IDE.Plugin.bpl');
  
  // Remove da Known IDE Packages
  RegKey1 := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known IDE Packages';
  if RegValueExists(HKCU, RegKey1, BPLPath) then
    RegDeleteValue(HKCU, RegKey1, BPLPath);

  // Remove da Known Packages (limpeza de seguranca caso tenha sido registrado antes)
  RegKey2 := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known Packages';
  if RegValueExists(HKCU, RegKey2, BPLPath) then
    RegDeleteValue(HKCU, RegKey2, BPLPath);

  // Deleta o arquivo fisico de BPL na desinstalacao
  if FileExists(BPLPath) then
    DeleteFile(BPLPath);
end;

procedure CleanObsoleteRegistry(BDSVersion: string; BPLName: string);
var
  RegKey1, RegKey2, RegKey3: string;
  BPLPathObsolete: string;
begin
  BPLPathObsolete := ExpandConstant('{app}\plugins\' + BPLName);
  
  // Limpa da chave Known Packages
  RegKey1 := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known Packages';
  if RegValueExists(HKCU, RegKey1, BPLPathObsolete) then
    RegDeleteValue(HKCU, RegKey1, BPLPathObsolete);

  // Limpa da chave Known IDE Packages
  RegKey2 := 'Software\Embarcadero\BDS\' + BDSVersion + '\Known IDE Packages';
  if RegValueExists(HKCU, RegKey2, BPLPathObsolete) then
    RegDeleteValue(HKCU, RegKey2, BPLPathObsolete);

  // Limpa da chave Wizards
  RegKey3 := 'Software\Embarcadero\BDS\' + BDSVersion + '\Wizards';
  if RegValueExists(HKCU, RegKey3, 'Boss4D.IDE.Plugin') then
    RegDeleteValue(HKCU, RegKey3, 'Boss4D.IDE.Plugin');
  if RegValueExists(HKCU, RegKey3, BPLPathObsolete) then
    RegDeleteValue(HKCU, RegKey3, BPLPathObsolete);
  if RegValueExists(HKCU, RegKey3, 'Boss4D.IDE.Plugin_11') then
    RegDeleteValue(HKCU, RegKey3, 'Boss4D.IDE.Plugin_11');
  if RegValueExists(HKCU, RegKey3, 'Boss4D.IDE.Plugin_12') then
    RegDeleteValue(HKCU, RegKey3, 'Boss4D.IDE.Plugin_12');
  if RegValueExists(HKCU, RegKey3, 'Boss4D.IDE.Plugin_13') then
    RegDeleteValue(HKCU, RegKey3, 'Boss4D.IDE.Plugin_13');
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
    // Limpa registros obsoletos de instalacoes anteriores para evitar conflito de units na IDE
    CleanObsoleteRegistry('22.0', 'Boss4D.IDE.Plugin_11.bpl');
    CleanObsoleteRegistry('23.0', 'Boss4D.IDE.Plugin_12.bpl');
    CleanObsoleteRegistry('37.0', 'Boss4D.IDE.Plugin_13.bpl');

    // Delphi 11 (Alexandria)
    if Delphi11Idx <> -1 then
    begin
      if IDEOptionPage.Values[Delphi11Idx] then
        RegisterPlugin('22.0', '11')
      else
        UnregisterPlugin('22.0', '11');
    end;

    // Delphi 12 (Athens)
    if Delphi12Idx <> -1 then
    begin
      if IDEOptionPage.Values[Delphi12Idx] then
        RegisterPlugin('23.0', '12')
      else
        UnregisterPlugin('23.0', '12');
    end;

    // Delphi 13 (Florence)
    if Delphi13Idx <> -1 then
    begin
      if IDEOptionPage.Values[Delphi13Idx] then
        RegisterPlugin('37.0', '13')
      else
        UnregisterPlugin('37.0', '13');
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
    UnregisterPlugin('22.0', '11');
    UnregisterPlugin('23.0', '12');
    UnregisterPlugin('37.0', '13');

    // Limpa variavel de ambiente PATH
    RemoveFromPath;
  end;
end;
