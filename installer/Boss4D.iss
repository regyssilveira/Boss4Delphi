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

[Files]
Source: "..\dist\bin\boss4d.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\bin\boss4d_x64.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\bin\Boss4D.GUI.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\bin\Boss4D.GUI_x64.exe"; DestDir: "{app}\bin"; Flags: ignoreversion
Source: "..\dist\plugins\Boss4D.IDE.Plugin_11.bpl"; DestDir: "{app}\plugins"; Flags: ignoreversion; Check: IsDelphi11Installed
Source: "..\dist\plugins\Boss4D.IDE.Plugin_12.bpl"; DestDir: "{app}\plugins"; Flags: ignoreversion; Check: IsDelphi12Installed
Source: "..\dist\plugins\Boss4D.IDE.Plugin_13.bpl"; DestDir: "{app}\plugins"; Flags: ignoreversion; Check: IsDelphi13Installed

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

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Grava no Registro das IDEs selecionadas
    if (Delphi11Idx <> -1) and IDEOptionPage.Values[Delphi11Idx] then
      RegisterPlugin('22.0', 'Boss4D.IDE.Plugin_11.bpl');

    if (Delphi12Idx <> -1) and IDEOptionPage.Values[Delphi12Idx] then
      RegisterPlugin('23.0', 'Boss4D.IDE.Plugin_12.bpl');

    if (Delphi13Idx <> -1) and IDEOptionPage.Values[Delphi13Idx] then
      RegisterPlugin('37.0', 'Boss4D.IDE.Plugin_13.bpl');

    // Adiciona pasta bin no PATH do Usuario
    AddToPath;
  end;
end;
