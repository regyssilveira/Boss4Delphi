unit Boss4D.IDE.Wizard;

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus, Vcl.Forms, Vcl.StdCtrls, Vcl.Controls, Vcl.Graphics, Vcl.ExtCtrls
  {$IFDEF IDE_PLUGIN}
  , ToolsAPI, DesignIntf
  {$ENDIF};

{$IFNDEF IDE_PLUGIN}
type
  IOTAProject = interface(IUnknown)
    ['{842BB564-9642-4D3C-80E2-C68C090886AA}']
    function GetFileName: string;
    property FileName: string read GetFileName;
  end;

  TNotifierObject = class(TInterfacedObject)
  end;

  IOTALocalMenu = interface(IUnknown)
    ['{335D2E7C-E22A-4D46-9D92-B7AE1A3DE8E0}']
    function GetCaption: string;
    function GetChecked: Boolean;
    function GetEnabled: Boolean;
    function GetHelpContext: Integer;
    function GetName: string;
    function GetParent: string;
    function GetPosition: Integer;
    function GetVerb: string;
    procedure SetCaption(const Value: string);
    procedure SetChecked(Value: Boolean);
    procedure SetEnabled(Value: Boolean);
    procedure SetHelpContext(Value: Integer);
    procedure SetName(const Value: string);
    procedure SetParent(const Value: string);
    procedure SetPosition(Value: Integer);
    procedure SetVerb(const Value: string);
  end;

  IOTAProjectManagerMenu = interface(IOTALocalMenu)
    ['{5E3B2F18-306E-4922-9067-3F71843C51FA}']
    function GetIsMultiSelectable: Boolean;
    procedure SetIsMultiSelectable(Value: Boolean);
    procedure Execute(const MenuContextList: IInterfaceList);
    function PreExecute(const MenuContextList: IInterfaceList): Boolean;
    function PostExecute(const MenuContextList: IInterfaceList): Boolean;
  end;

  IOTAProjectMenuItemCreatorNotifier = interface(IUnknown)
    ['{8209348C-2114-439C-AD4E-BFB7049A636A}']
    procedure AddMenu(const Project: IOTAProject; const IdentList: TStrings;
      const ProjectManagerMenuList: IInterfaceList; IsMultiSelect: Boolean);
  end;

  IOTAWizard = interface(IUnknown)
    ['{0B902A2E-BF56-4BEB-848D-5D88406F8EA9}']
    function GetIDString: string;
    function GetName: string;
  end;

  TOTAProjectMock = class(TInterfacedObject, IOTAProject)
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function GetFileName: string;
  end;
{$ENDIF}

type
  TBoss4DInstallDialog = class(TForm)
  private
    FEditURL: TEdit;
    FEditVersion: TEdit;
    FBtnOK: TButton;
    FBtnCancel: TButton;
    procedure SetupUI;
  public
    constructor Create(AOwner: TComponent); override;
    property EditURL: TEdit read FEditURL;
    property EditVersion: TEdit read FEditVersion;
  end;

  TBoss4DIDEWizard = class(TNotifierObject, IOTAWizard)
  private
    FTimer: TTimer;
    FBossMenuItem: TMenuItem;
    procedure CreateToolsMenuItems;
    procedure RemoveToolsMenuItems;
    procedure OnTimerEvent(Sender: TObject);
    procedure MenuActionClick(Sender: TObject);
    function GetActiveProjectDir: string;
    procedure RunBoss4DCommand(const AProjectDir: string; const ACommand: string);
    procedure ExecuteInstallDialog(const AProjectDir: string);
    procedure ExecuteRunScriptDialog(const AProjectDir: string);
  public
    constructor Create;
    destructor Destroy; override;

    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    {$IFDEF IDE_PLUGIN}
    function GetState: TWizardState;
    procedure Execute;
    {$ENDIF}
  end;

procedure Register;

implementation

uses
  Winapi.Windows, System.IOUtils, System.Diagnostics, System.Threading, System.JSON, System.Variants;

const
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = $00000004;

function GetModuleHandleEx(ADwFlags: DWORD; ALpModuleName: PChar; var APhModule: HMODULE): BOOL; stdcall;
  external 'kernel32.dll' name 'GetModuleHandleExW';

var
  GWizardIndex: Integer = -1;
  GModuleHandle: HMODULE = 0;

{$IFDEF IDE_PLUGIN}
function BuildProjectSearchPaths(const AProjectDir: string; const AMessageServices: IOTAMessageServices; const AGroup: IOTAMessageGroup): TArray<string>;
  procedure ParseModulePkg(const AModName, AModDir: string; LPaths: TStringList);
  var
    LPkgPath: string;
    LPkgJSON: TJSONObject;
    LMainSrc: string;
    LSubPaths: TArray<string>;
    LSubPath: string;
  begin
    LPkgPath := TPath.Combine(AModDir, 'boss.json');
    if not TFile.Exists(LPkgPath) then Exit;
    try
      var LPkgStr := TFile.ReadAllText(LPkgPath, TEncoding.UTF8);
      LPkgJSON := TJSONObject.ParseJSONValue(LPkgStr) as TJSONObject;
      if not Assigned(LPkgJSON) then Exit;
      try
        var LMainSrcValue := LPkgJSON.GetValue('mainsrc');
        if not Assigned(LMainSrcValue) then Exit;
        LMainSrc := LMainSrcValue.Value;
        if LMainSrc = '' then Exit;
        LSubPaths := LMainSrc.Split([';']);
        for LSubPath in LSubPaths do
        begin
          var LTrimmed := LSubPath.Trim.Replace('/', '\');
          if LTrimmed.EndsWith('\') and (Length(LTrimmed) > 1) then
            LTrimmed := LTrimmed.Substring(0, LTrimmed.Length - 1);
          if LTrimmed <> '' then
            LPaths.Add('.\modules\' + AModName + '\' + LTrimmed);
        end;
      finally
        LPkgJSON.Free;
      end;
    except
      on E: Exception do
      begin
        AMessageServices.AddTitleMessage(
          '[AVISO] Erro ao ler boss.json de ' + AModName + ': ' + E.Message,
          AGroup
        );
      end;
    end;
  end;
  procedure ParseLockModules(const ALockPath: string; LPaths: TStringList);
  var
    LJSONStr: string;
    LJSONObj, LModulesObj: TJSONObject;
    Idx: Integer;
    LModName: string;
    LModDir: string;
  begin
    if not TFile.Exists(ALockPath) then Exit;
    try
      LJSONStr := TFile.ReadAllText(ALockPath, TEncoding.UTF8);
      LJSONObj := TJSONObject.ParseJSONValue(LJSONStr) as TJSONObject;
      if not Assigned(LJSONObj) then Exit;
      try
        LModulesObj := LJSONObj.GetValue('installedModules') as TJSONObject;
        if not Assigned(LModulesObj) then Exit;
        for Idx := 0 to LModulesObj.Count - 1 do
        begin
          var LPair := LModulesObj.Pairs[Idx];
          var LModInfo := LPair.JsonValue as TJSONObject;
          if not Assigned(LModInfo) then Continue;
          LModName := LModInfo.GetValue('name').Value;
          if LModName = '' then Continue;
          LModDir := TPath.Combine(TPath.Combine(AProjectDir, 'modules'), LModName);
          if not TDirectory.Exists(LModDir) then Continue;
          LPaths.Add('.\modules\' + LModName);
          ParseModulePkg(LModName, LModDir, LPaths);
        end;
      finally
        LJSONObj.Free;
      end;
    except
      on E: Exception do
      begin
        AMessageServices.AddTitleMessage(
          '[AVISO] Erro ao ler boss-lock.json: ' + E.Message,
          AGroup
        );
      end;
    end;
  end;
var
  LPaths: TStringList;
  LLockPath: string;
  Idx: Integer;
begin
  LPaths := TStringList.Create;
  try
    LPaths.Add('.\modules\dcu\$(Platform)\$(Config)');
    LLockPath := TPath.Combine(AProjectDir, 'boss-lock.json');
    ParseLockModules(LLockPath, LPaths);
    SetLength(Result, LPaths.Count);
    for Idx := 0 to LPaths.Count - 1 do
      Result[Idx] := LPaths[Idx];
  finally
    LPaths.Free;
  end;
end;

procedure CheckAndAdd(const AProj: IOTAProject; const AOptions: IOTAProjectOptions; const AOptionName: string; const APathToAdd: string; const AMessageServices: IOTAMessageServices; const AGroup: IOTAMessageGroup);
begin
  try
    var LVal := VarToStr(AOptions.Values[AOptionName]);
    if not LVal.Contains(APathToAdd) then
    begin
      if LVal <> '' then
        LVal := LVal + ';' + APathToAdd
      else
        LVal := APathToAdd;
      AOptions.Values[AOptionName] := LVal;
      AProj.MarkModified;
    end;
  except
    on E: Exception do
    begin
      AMessageServices.AddTitleMessage(
        '[AVISO] Erro ao atualizar a opcao ' + AOptionName + ': ' + E.Message,
        AGroup
      );
    end;
  end;
end;

procedure UpdateProj(const AProj: IOTAProject; const AMessageServices: IOTAMessageServices; const AGroup: IOTAMessageGroup);
var
  LProjDir: string;
  LOptions: IOTAProjectOptions;
  LSearchPaths: TArray<string>;
  LPath: string;
begin
  if not Assigned(AProj) then Exit;
  LOptions := AProj.ProjectOptions;
  if Assigned(LOptions) then
  begin
    LProjDir := TPath.GetDirectoryName(AProj.FileName);
    LSearchPaths := BuildProjectSearchPaths(LProjDir, AMessageServices, AGroup);
    for LPath in LSearchPaths do
    begin
      CheckAndAdd(AProj, LOptions, 'UnitSearchPath', LPath, AMessageServices, AGroup);
      CheckAndAdd(AProj, LOptions, 'DCC_UnitSearchPath', LPath, AMessageServices, AGroup);
      CheckAndAdd(AProj, LOptions, 'SearchPath', LPath, AMessageServices, AGroup);
    end;
  end;
end;
{$ENDIF}

{ TBoss4DIDEWizard }

constructor TBoss4DIDEWizard.Create;
begin
  inherited Create;
  // Incrementa contagem de referencias da BPL para mante-la na memoria
  {$IFDEF IDE_PLUGIN}
  GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, PChar(@Register), GModuleHandle);
  {$ENDIF}

  FBossMenuItem := nil;
  FTimer := nil;

  {$IFDEF IDE_PLUGIN}
  var LNTAServices: INTAServices;
  if Supports(BorlandIDEServices, INTAServices, LNTAServices) and Assigned(LNTAServices.MainMenu) then
  begin
    FBossMenuItem := TMenuItem.Create(nil);
    FBossMenuItem.Caption := 'Boss4D';
    FBossMenuItem.Name := 'mnuBoss4DRoot';
    CreateToolsMenuItems;
    LNTAServices.AddActionMenu('ToolsMenu', nil, FBossMenuItem, True, True);
  end
  else
  {$ENDIF}
  begin
    FTimer := TTimer.Create(nil);
    FTimer.Interval := 1000;
    FTimer.OnTimer := OnTimerEvent;
    FTimer.Enabled := True;
  end;
end;

destructor TBoss4DIDEWizard.Destroy;
begin
  if Assigned(FTimer) then
  begin
    FTimer.Enabled := False;
    FreeAndNil(FTimer);
  end;

  RemoveToolsMenuItems;

  // Libera a referencia da BPL na memoria se nao for shutdown geral
  {$IFDEF IDE_PLUGIN}
  if (not Application.Terminated) and (GModuleHandle <> 0) then
  begin
    FreeLibrary(GModuleHandle);
    GModuleHandle := 0;
  end;
  {$ENDIF}

  inherited Destroy;
end;

procedure TBoss4DIDEWizard.OnTimerEvent(Sender: TObject);
begin
  {$IFDEF IDE_PLUGIN}
  var LNTAServices: INTAServices;
  if Supports(BorlandIDEServices, INTAServices, LNTAServices) and Assigned(LNTAServices.MainMenu) then
  begin
    FBossMenuItem := TMenuItem.Create(nil);
    FBossMenuItem.Caption := 'Boss4D';
    FBossMenuItem.Name := 'mnuBoss4DRoot';
    CreateToolsMenuItems;
    LNTAServices.AddActionMenu('ToolsMenu', nil, FBossMenuItem, True, True);
    FTimer.Enabled := False;
  end;
  {$ENDIF}
end;

function TBoss4DIDEWizard.GetIDString: string;
begin
  Result := 'Boss4D.IDE.Plugin.Wizard';
end;

function TBoss4DIDEWizard.GetName: string;
begin
  Result := 'Boss4D IDE Wizard';
end;

{$IFDEF IDE_PLUGIN}
function TBoss4DIDEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TBoss4DIDEWizard.Execute;
begin
  // Nada a executar sob demanda
end;
{$ENDIF}

procedure TBoss4DIDEWizard.CreateToolsMenuItems;
  procedure AddSubItem(const ACaption, ACommand: string; APosition: Integer);
  var
    LSubItem: TMenuItem;
  begin
    LSubItem := TMenuItem.Create(FBossMenuItem);
    LSubItem.Caption := ACaption;
    LSubItem.Hint := ACommand;
    LSubItem.OnClick := MenuActionClick;
    FBossMenuItem.Add(LSubItem);
  end;
  procedure AddSeparator;
  var
    LSep: TMenuItem;
  begin
    LSep := TMenuItem.Create(FBossMenuItem);
    LSep.Caption := '-';
    FBossMenuItem.Add(LSep);
  end;
begin
  AddSubItem('Init', 'init --quiet', 10);
  AddSubItem('Install', 'install', 20);
  AddSubItem('Install Package...', 'install-dialog', 30);
  AddSubItem('Clean', 'clean', 40);
  AddSubItem('Outdated', 'outdated', 50);
  AddSubItem('Dependency Tree', 'tree', 60);
  AddSeparator;
  AddSubItem('Run Script...', 'run-script', 70);
  AddSeparator;
  AddSubItem('GetIt: Set Online Mode', 'getit mode-online', 80);
  AddSubItem('GetIt: Set Offline Mode', 'getit mode-offline', 90);
  AddSeparator;
  AddSubItem('Doctor', 'doctor', 100);
  AddSubItem('License Report', 'license report', 110);
  AddSeparator;
  AddSubItem('Cache: Clean', 'cache clean', 120);
  AddSubItem('Cache: Prune', 'cache prune', 130);
end;

procedure TBoss4DIDEWizard.RemoveToolsMenuItems;
begin
  FreeAndNil(FBossMenuItem);
end;

procedure TBoss4DIDEWizard.MenuActionClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;
  var LCmd := TMenuItem(Sender).Hint;
  var LProjDir := GetActiveProjectDir;

  if LProjDir = '' then
  begin
    MessageBox(0, 'Por favor, abra um projeto salvo antes de executar comandos do Boss4D.', 'Boss4D', MB_ICONWARNING or MB_OK);
    Exit;
  end;

  if LCmd = 'install-dialog' then
  begin
    ExecuteInstallDialog(LProjDir);
  end
  else if LCmd = 'run-script' then
  begin
    ExecuteRunScriptDialog(LProjDir);
  end
  else if LCmd <> '' then
  begin
    RunBoss4DCommand(LProjDir, LCmd);
  end;
end;

function TBoss4DIDEWizard.GetActiveProjectDir: string;
begin
  Result := '';
  {$IFDEF IDE_PLUGIN}
  var LModuleServices: IOTAModuleServices;
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    var LProjectGroup := LModuleServices.MainProjectGroup;
    if Assigned(LProjectGroup) then
    begin
      var LProject := LProjectGroup.ActiveProject;
      if Assigned(LProject) and (LProject.FileName <> '') then
        Exit(TPath.GetDirectoryName(LProject.FileName));
    end;

    // Fallback: tentar obter do arquivo ativo aberto no editor se for um projeto
    for var I := 0 to LModuleServices.ModuleCount - 1 do
    begin
      var LModule := LModuleServices.Modules[I];
      var LProject: IOTAProject;
      if Supports(LModule, IOTAProject, LProject) then
      begin
        if LProject.FileName <> '' then
          Exit(TPath.GetDirectoryName(LProject.FileName));
      end;
    end;
  end;
  {$ENDIF}
end;

procedure TBoss4DIDEWizard.ExecuteInstallDialog(const AProjectDir: string);
var
  LDlg: TBoss4DInstallDialog;
  LURL: string;
  LVers: string;
  LCmd: string;
begin
  LDlg := TBoss4DInstallDialog.Create(nil);
  try
    if LDlg.ShowModal = mrOk then
    begin
      LURL := Trim(LDlg.EditURL.Text);
      if LURL <> '' then
      begin
        LVers := Trim(LDlg.EditVersion.Text);
        LCmd := 'install ' + LURL;
        if LVers <> '' then
          LCmd := LCmd + '@' + LVers;
        RunBoss4DCommand(AProjectDir, LCmd);
      end;
    end;
  finally
    LDlg.Free;
  end;
end;

procedure TBoss4DIDEWizard.ExecuteRunScriptDialog(const AProjectDir: string);
var
  LBossJsonFile: string;
  LContent: string;
  LJSON, LScripts: TJSONObject;
  LScriptNames: TStringList;
  Idx: Integer;
begin
  LBossJsonFile := TPath.Combine(AProjectDir, 'boss.json');
  if not TFile.Exists(LBossJsonFile) then
  begin
    MessageBox(0, 'O arquivo boss.json nao foi encontrado neste projeto.', 'Boss4D', MB_ICONWARNING or MB_OK);
    Exit;
  end;

  LScriptNames := TStringList.Create;
  try
    try
      LContent := TFile.ReadAllText(LBossJsonFile, TEncoding.UTF8);
      LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
      if Assigned(LJSON) then
      begin
        try
          LScripts := LJSON.GetValue('scripts') as TJSONObject;
          if Assigned(LScripts) then
          begin
            for Idx := 0 to LScripts.Count - 1 do
            begin
              LScriptNames.Add(LScripts.Pairs[Idx].JsonString.Value);
            end;
          end;
        finally
          LJSON.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        MessageBox(0, PChar('Erro ao ler os scripts do boss.json: ' + E.Message), 'Boss4D', MB_ICONERROR or MB_OK);
        Exit;
      end;
    end;

    if LScriptNames.Count = 0 then
    begin
      MessageBox(0, 'Nenhum script foi definido no boss.json deste projeto.', 'Boss4D', MB_ICONINFORMATION or MB_OK);
      Exit;
    end;

    var LSelDialog := TForm.Create(nil);
    try
      LSelDialog.Caption := 'Boss4D - Executar Script';
      LSelDialog.BorderStyle := bsDialog;
      LSelDialog.Position := poScreenCenter;
      LSelDialog.Width := 300;
      LSelDialog.Height := 250;

      var LLabel := TLabel.Create(LSelDialog);
      LLabel.Parent := LSelDialog;
      LLabel.Caption := 'Selecione o script para executar:';
      LLabel.SetBounds(16, 16, 250, 16);

      var LListBox := TListBox.Create(LSelDialog);
      LListBox.Parent := LSelDialog;
      LListBox.SetBounds(16, 36, 250, 120);
      for var LName in LScriptNames do
        LListBox.Items.Add(LName);
      LListBox.ItemIndex := 0;

      var LBtnOK := TButton.Create(LSelDialog);
      LBtnOK.Parent := LSelDialog;
      LBtnOK.Caption := 'Executar';
      LBtnOK.ModalResult := mrOk;
      LBtnOK.SetBounds(110, 170, 75, 25);
      LBtnOK.Default := True;

      var LBtnCancel := TButton.Create(LSelDialog);
      LBtnCancel.Parent := LSelDialog;
      LBtnCancel.Caption := 'Cancelar';
      LBtnCancel.ModalResult := mrCancel;
      LBtnCancel.SetBounds(191, 170, 75, 25);

      if LSelDialog.ShowModal = mrOk then
      begin
        if LListBox.ItemIndex <> -1 then
        begin
          var LSelectedScript := LListBox.Items[LListBox.ItemIndex];
          RunBoss4DCommand(AProjectDir, 'run ' + LSelectedScript);
        end;
      end;
    finally
      LSelDialog.Free;
    end;
  finally
    LScriptNames.Free;
  end;
end;

procedure TBoss4DIDEWizard.RunBoss4DCommand(const AProjectDir: string; const ACommand: string);
{$IFDEF IDE_PLUGIN}
var
  LMessageServices: IOTAMessageServices;
  LGroup: IOTAMessageGroup;
{$ENDIF}
begin
  {$IFDEF IDE_PLUGIN}
  if not Supports(BorlandIDEServices, IOTAMessageServices, LMessageServices) then
    Exit;

  LGroup := LMessageServices.AddMessageGroup('Boss4D');
  LMessageServices.ClearMessageGroup(LGroup);
  LMessageServices.ShowMessageView(LGroup);
  LMessageServices.AddTitleMessage('Executando: boss4d ' + ACommand, LGroup);

  TThread.CreateAnonymousThread(
    procedure
    var
      LSA: TSecurityAttributes;
      LReadPipe, LWritePipe: THandle;
      LStartInfo: TStartupInfo;
      LProcInfo: TProcessInformation;
      LBuffer: TBytes;
      LBytesRead: DWORD;
      LOutputLine: string;
      LCmdLine: string;
      LHomePath: string;
      LExecutable: string;
      LTextBuffer: string;
      LPos: Integer;
    begin
      LExecutable := 'boss4d.exe';
      LHomePath := TPath.Combine(GetEnvironmentVariable('USERPROFILE'), '.boss\bin');
      if TFile.Exists(TPath.Combine(LHomePath, 'boss4d.exe')) then
        LExecutable := TPath.Combine(LHomePath, 'boss4d.exe')
      else if TFile.Exists(TPath.Combine(LHomePath, 'boss.exe')) then
        LExecutable := TPath.Combine(LHomePath, 'boss.exe');

      LCmdLine := '"' + LExecutable + '" ' + ACommand;
      SetLength(LBuffer, 4096);

      LSA.nLength := SizeOf(TSecurityAttributes);
      LSA.bInheritHandle := True;
      LSA.lpSecurityDescriptor := nil;

      if CreatePipe(LReadPipe, LWritePipe, @LSA, 0) then
      begin
        try
          FillChar(LStartInfo, SizeOf(TStartupInfo), 0);
          LStartInfo.cb := SizeOf(TStartupInfo);
          LStartInfo.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
          LStartInfo.wShowWindow := SW_HIDE;
          LStartInfo.hStdOutput := LWritePipe;
          LStartInfo.hStdError := LWritePipe;

          UniqueString(LCmdLine);
          if CreateProcess(nil, PChar(LCmdLine), nil, nil, True, 0, nil, PChar(AProjectDir), LStartInfo, LProcInfo) then
          begin
            CloseHandle(LWritePipe);
            LWritePipe := 0;

            LTextBuffer := '';
            while ReadFile(LReadPipe, LBuffer[0], Length(LBuffer), LBytesRead, nil) and (LBytesRead > 0) do
            begin
              LTextBuffer := LTextBuffer + TEncoding.UTF8.GetString(LBuffer, 0, LBytesRead);

              while True do
              begin
                LPos := LTextBuffer.IndexOf(#10);
                if LPos = -1 then
                  Break;

                LOutputLine := LTextBuffer.Substring(0, LPos).TrimRight([#13, #10]);
                LTextBuffer := LTextBuffer.Substring(LPos + 1);

                var LMsg := LOutputLine;
                TThread.Queue(nil,
                  TThreadProcedure(
                    procedure
                    begin
                      LMessageServices.AddTitleMessage(LMsg, LGroup);
                    end
                  )
                );
              end;
            end;

            if Trim(LTextBuffer) <> '' then
            begin
              var LMsg := Trim(LTextBuffer);
              TThread.Queue(nil,
                TThreadProcedure(
                  procedure
                  begin
                    LMessageServices.AddTitleMessage(LMsg, LGroup);
                  end
                )
              );
            end;

            WaitForSingleObject(LProcInfo.hProcess, INFINITE);
            CloseHandle(LProcInfo.hProcess);
            CloseHandle(LProcInfo.hThread);

            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                var
                  LModuleServices: IOTAModuleServices;
                  LProjectGroup: IOTAProjectGroup;
                  LProject: IOTAProject;
                  I: Integer;
                begin
                  LMessageServices.AddTitleMessage('Finalizado com sucesso!', LGroup);

                  if SameText(ACommand, 'install') or ACommand.StartsWith('install ') then
                  begin
                    if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
                    begin
                      LProjectGroup := LModuleServices.MainProjectGroup;
                      if Assigned(LProjectGroup) then
                      begin
                        for I := 0 to LProjectGroup.ProjectCount - 1 do
                        begin
                          LProject := LProjectGroup.Projects[I];
                          UpdateProj(LProject, LMessageServices, LGroup);
                        end;
                      end;
                    end;
                  end;
                end
              )
            );
          end
          else
          begin
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  LMessageServices.AddTitleMessage('[ERRO] Nao foi possivel iniciar o processo: ' + LCmdLine, LGroup);
                end
              )
            );
          end;
        finally
          if LWritePipe <> 0 then
            CloseHandle(LWritePipe);
          CloseHandle(LReadPipe);
        end;
      end;
    end).Start;
  {$ENDIF}
end;

procedure Register;
{$IFDEF IDE_PLUGIN}
var
  LBitmap: Vcl.Graphics.TBitmap;
  LSplashServices: IOTASplashScreenServices;
  LAboutServices: IOTAAboutBoxServices;
  LWizardServices: IOTAWizardServices;
begin
  // Impede o descarregamento sob demanda do pacote pela IDE
  ForceDemandLoadState(dlDisable);

  if not Assigned(BorlandIDEServices) then
    Exit;

  // Registro na Splash Screen usando a variavel global oficial da ToolsAPI com check de seguranca
  if Assigned(SplashScreenServices) and Supports(SplashScreenServices, IOTASplashScreenServices, LSplashServices) then
  begin
    LBitmap := Vcl.Graphics.TBitmap.Create;
    try
      LBitmap.SetSize(24, 24);
      LBitmap.Canvas.Brush.Color := clPurple;
      LBitmap.Canvas.FillRect(Rect(0, 0, 24, 24));
      LBitmap.Canvas.Font.Color := clWhite;
      LBitmap.Canvas.Font.Name := 'Segoe UI';
      LBitmap.Canvas.Font.Style := [fsBold];
      LBitmap.Canvas.TextOut(4, 4, 'B4D');

      LSplashServices.AddPluginBitmap(
        'Boss4D IDE Integration Plugin',
        LBitmap.Handle,
        False,
        'Registered',
        'Production'
      );
    finally
      LBitmap.Free;
    end;
  end;

  // Registro no About Box usando BorlandIDEServices com check de seguranca
  if Assigned(BorlandIDEServices) and Supports(BorlandIDEServices, IOTAAboutBoxServices, LAboutServices) then
  begin
    LBitmap := Vcl.Graphics.TBitmap.Create;
    try
      LBitmap.SetSize(24, 24);
      LBitmap.Canvas.Brush.Color := clPurple;
      LBitmap.Canvas.FillRect(Rect(0, 0, 24, 24));
      LBitmap.Canvas.Font.Color := clWhite;
      LBitmap.Canvas.Font.Name := 'Segoe UI';
      LBitmap.Canvas.Font.Style := [fsBold];
      LBitmap.Canvas.TextOut(4, 4, 'B4D');

      LAboutServices.AddPluginInfo(
        'Boss4D IDE Integration Plugin',
        'Plugin do Boss4D para gerenciamento nativo de dependencias',
        LBitmap.Handle,
        False,
        '1.1.0'
      );
    finally
      LBitmap.Free;
    end;
  end;

  // Adiciona o Wizard na IDE
  if Supports(BorlandIDEServices, IOTAWizardServices, LWizardServices) then
  begin
    try
      GWizardIndex := LWizardServices.AddWizard(TBoss4DIDEWizard.Create);
    except
      on E: Exception do
      begin
        OutputDebugString(PChar('Erro ao registrar Boss4D Wizard: ' + E.Message));
      end;
    end;
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}



{ TBoss4DInstallDialog }

constructor TBoss4DInstallDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  SetupUI;
end;

procedure TBoss4DInstallDialog.SetupUI;
var
  LLabelURL, LLabelVersion: TLabel;
begin
  Self.Caption := 'Boss4D - Instalar Pacote';
  Self.BorderStyle := bsDialog;
  Self.Position := poScreenCenter;
  Self.Width := 400;
  Self.Height := 200;

  LLabelURL := TLabel.Create(Self);
  LLabelURL.Parent := Self;
  LLabelURL.Caption := 'URL do Pacote (ex: github.com/hashload/horse):';
  LLabelURL.SetBounds(16, 16, 350, 16);

  FEditURL := TEdit.Create(Self);
  FEditURL.Parent := Self;
  FEditURL.SetBounds(16, 36, 350, 24);

  LLabelVersion := TLabel.Create(Self);
  LLabelVersion.Parent := Self;
  LLabelVersion.Caption := 'Versao / Tag / Faixa de SemVer (Opcional):';
  LLabelVersion.SetBounds(16, 70, 350, 16);

  FEditVersion := TEdit.Create(Self);
  FEditVersion.Parent := Self;
  FEditVersion.SetBounds(16, 90, 350, 24);

  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := Self;
  FBtnOK.Caption := 'Instalar';
  FBtnOK.ModalResult := mrOk;
  FBtnOK.SetBounds(210, 130, 75, 25);
  FBtnOK.Default := True;

  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := Self;
  FBtnCancel.Caption := 'Cancelar';
  FBtnCancel.ModalResult := mrCancel;
  FBtnCancel.SetBounds(291, 130, 75, 25);
end;


{$IFNDEF IDE_PLUGIN}
{ TOTAProjectMock }
constructor TOTAProjectMock.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
end;

function TOTAProjectMock.GetFileName: string;
begin
  Result := FFileName;
end;
{$ENDIF}

initialization

finalization

end.
