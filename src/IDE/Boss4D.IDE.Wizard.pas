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

  TBoss4DProjectManagerMenu = class(TNotifierObject, IOTALocalMenu, IOTAProjectManagerMenu)
  private
    FCaption: string;
    FName: string;
    FParent: string;
    FPosition: Integer;
    FVerb: string;
    FProjectDir: string;
    FCommand: string;
    FIsMultiSelectable: Boolean;
    procedure RunBoss4DCommand(const AProjectDir: string; const ACommand: string);
  public
    constructor Create(const ACaption, AName, AParent, AVerb, AProjectDir, ACommand: string; APosition: Integer);

    { IOTAProjectManagerMenu }
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

    // Métodos adicionados na ToolsAPI moderna
    function GetIsMultiSelectable: Boolean;
    procedure SetIsMultiSelectable(Value: Boolean);
    procedure Execute(const MenuContextList: IInterfaceList);
    function PreExecute(const MenuContextList: IInterfaceList): Boolean;
    function PostExecute(const MenuContextList: IInterfaceList): Boolean;
  end;

  TBoss4DProjectMenuItemCreatorNotifier = class(TNotifierObject, IOTAProjectMenuItemCreatorNotifier)
  public
    { IOTAProjectMenuItemCreatorNotifier }
    procedure AddMenu(const Project: IOTAProject; const IdentList: TStrings;
      const ProjectManagerMenuList: IInterfaceList; IsMultiSelect: Boolean);
  end;

  TBoss4DIDEWizard = class(TNotifierObject, IOTAWizard)
  private
    FTimer: TTimer;
    FNotifier: IOTAProjectMenuItemCreatorNotifier;
    FMenuCreatorIdx: Integer;
    procedure OnTimerEvent(Sender: TObject);
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

{ TBoss4DIDEWizard }

constructor TBoss4DIDEWizard.Create;
begin
  inherited Create;
  // Incrementa contagem de referencias da BPL para mante-la na memoria
  {$IFDEF IDE_PLUGIN}
  GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, PChar(@Register), GModuleHandle);
  {$ENDIF}

  FMenuCreatorIdx := -1;
  FTimer := nil;
  FNotifier := TBoss4DProjectMenuItemCreatorNotifier.Create;
  {$IFDEF IDE_PLUGIN}
  var LProjectManager: IOTAProjectManager;
  if Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
  begin
    FMenuCreatorIdx := LProjectManager.AddMenuItemCreatorNotifier(FNotifier);
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
  {$IFDEF IDE_PLUGIN}
  if (FMenuCreatorIdx <> -1) and Assigned(BorlandIDEServices) then
  begin
    var LProjectManager: IOTAProjectManager;
    if Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
    begin
      LProjectManager.RemoveMenuItemCreatorNotifier(FMenuCreatorIdx);
    end;
  end;
  {$ENDIF}

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
  var LProjectManager: IOTAProjectManager;
  if Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
  begin
    FMenuCreatorIdx := LProjectManager.AddMenuItemCreatorNotifier(FNotifier);
    if FMenuCreatorIdx <> -1 then
    begin
      FTimer.Enabled := False;
    end;
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
        '1.0.1'
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
      // Silencia falhas no startup
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

{ TBoss4DProjectManagerMenu }

constructor TBoss4DProjectManagerMenu.Create(const ACaption, AName, AParent, AVerb, AProjectDir, ACommand: string; APosition: Integer);
begin
  inherited Create;
  FCaption := ACaption;
  FName := AName;
  FParent := AParent;
  FVerb := AVerb;
  FProjectDir := AProjectDir;
  FCommand := ACommand;
  FPosition := APosition;
  FIsMultiSelectable := False;
end;

function TBoss4DProjectManagerMenu.GetCaption: string; begin Result := FCaption; end;
function TBoss4DProjectManagerMenu.GetChecked: Boolean; begin Result := False; end;
function TBoss4DProjectManagerMenu.GetEnabled: Boolean; begin Result := True; end;
function TBoss4DProjectManagerMenu.GetHelpContext: Integer; begin Result := 0; end;
function TBoss4DProjectManagerMenu.GetName: string; begin Result := FName; end;
function TBoss4DProjectManagerMenu.GetParent: string; begin Result := FParent; end;
function TBoss4DProjectManagerMenu.GetPosition: Integer; begin Result := FPosition; end;
function TBoss4DProjectManagerMenu.GetVerb: string; begin Result := FVerb; end;

procedure TBoss4DProjectManagerMenu.SetCaption(const Value: string); begin FCaption := Value; end;
procedure TBoss4DProjectManagerMenu.SetChecked(Value: Boolean); begin end;
procedure TBoss4DProjectManagerMenu.SetEnabled(Value: Boolean); begin end;
procedure TBoss4DProjectManagerMenu.SetHelpContext(Value: Integer); begin end;
procedure TBoss4DProjectManagerMenu.SetName(const Value: string); begin FName := Value; end;
procedure TBoss4DProjectManagerMenu.SetParent(const Value: string); begin FParent := Value; end;
procedure TBoss4DProjectManagerMenu.SetPosition(Value: Integer); begin FPosition := Value; end;
procedure TBoss4DProjectManagerMenu.SetVerb(const Value: string); begin FVerb := Value; end;

function TBoss4DProjectManagerMenu.GetIsMultiSelectable: Boolean;
begin
  Result := FIsMultiSelectable;
end;

procedure TBoss4DProjectManagerMenu.SetIsMultiSelectable(Value: Boolean);
begin
  FIsMultiSelectable := Value;
end;

procedure TBoss4DProjectManagerMenu.Execute(const MenuContextList: IInterfaceList);
var
  LDlg: TBoss4DInstallDialog;
  LURL: string;
  LVers: string;
  LCmd: string;
begin
  if FCommand = 'install-dialog' then
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
          RunBoss4DCommand(FProjectDir, LCmd);
        end;
      end;
    finally
      LDlg.Free;
    end;
  end
  else if FCommand <> '' then
  begin
    RunBoss4DCommand(FProjectDir, FCommand);
  end;
end;

function TBoss4DProjectManagerMenu.PreExecute(const MenuContextList: IInterfaceList): Boolean;
begin
  Result := True;
end;

function TBoss4DProjectManagerMenu.PostExecute(const MenuContextList: IInterfaceList): Boolean;
begin
  Result := True;
end;

procedure TBoss4DProjectManagerMenu.RunBoss4DCommand(const AProjectDir: string; const ACommand: string);
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
                  LOptions: IOTAProjectOptions;
                  function BuildProjectSearchPaths(const AProjectDir: string): TArray<string>;
                  var
                    LPaths: TStringList;
                    LLockPath: string;
                    LJSONStr: string;
                    LJSONObj, LModulesObj: TJSONObject;
                    Idx: Integer;
                    LModName: string;
                    LModDir: string;
                    LPkgPath: string;
                    LPkgJSON: TJSONObject;
                    LMainSrc: string;
                    LSubPaths: TArray<string>;
                    LSubPath: string;
                  begin
                    LPaths := TStringList.Create;
                    try
                      LPaths.Add('.\modules\dcu\$(Platform)\$(Config)');
                      LLockPath := TPath.Combine(AProjectDir, 'boss-lock.json');
                      if TFile.Exists(LLockPath) then
                      begin
                        try
                          LJSONStr := TFile.ReadAllText(LLockPath, TEncoding.UTF8);
                          LJSONObj := TJSONObject.ParseJSONValue(LJSONStr) as TJSONObject;
                          if LJSONObj <> nil then
                          begin
                            try
                              LModulesObj := LJSONObj.GetValue('installedModules') as TJSONObject;
                              if LModulesObj <> nil then
                              begin
                                for Idx := 0 to LModulesObj.Count - 1 do
                                begin
                                  var LPair := LModulesObj.Pairs[Idx];
                                  var LModInfo := LPair.JsonValue as TJSONObject;
                                  if LModInfo <> nil then
                                  begin
                                    LModName := LModInfo.GetValue('name').Value;
                                    if LModName <> '' then
                                    begin
                                      LModDir := TPath.Combine(TPath.Combine(AProjectDir, 'modules'), LModName);
                                      if TDirectory.Exists(LModDir) then
                                      begin
                                        LPaths.Add('.\modules\' + LModName);
                                        LPkgPath := TPath.Combine(LModDir, 'boss.json');
                                        if TFile.Exists(LPkgPath) then
                                        begin
                                          try
                                            var LPkgStr := TFile.ReadAllText(LPkgPath, TEncoding.UTF8);
                                            LPkgJSON := TJSONObject.ParseJSONValue(LPkgStr) as TJSONObject;
                                            if LPkgJSON <> nil then
                                            begin
                                              try
                                                var LMainSrcValue := LPkgJSON.GetValue('mainsrc');
                                                if LMainSrcValue <> nil then
                                                begin
                                                  LMainSrc := LMainSrcValue.Value;
                                                  if LMainSrc <> '' then
                                                  begin
                                                    LSubPaths := LMainSrc.Split([';']);
                                                    for LSubPath in LSubPaths do
                                                    begin
                                                      var LTrimmed := LSubPath.Trim.Replace('/', '\');
                                                      if LTrimmed.EndsWith('\') and (Length(LTrimmed) > 1) then
                                                        LTrimmed := LTrimmed.Substring(0, LTrimmed.Length - 1);
                                                      if LTrimmed <> '' then
                                                        LPaths.Add('.\modules\' + LModName + '\' + LTrimmed);
                                                    end;
                                                  end;
                                                end;
                                              finally
                                                LPkgJSON.Free;
                                              end;
                                            end;
                                          except
                                            on E: Exception do
                                            begin
                                              LMessageServices.AddTitleMessage(
                                                '[AVISO] Erro ao ler boss.json de ' + LModName + ': ' + E.Message,
                                                LGroup
                                              );
                                            end;
                                          end;
                                        end;
                                      end;
                                    end;
                                  end;
                                end;
                              end;
                            finally
                              LJSONObj.Free;
                            end;
                          end;
                        except
                          on E: Exception do
                          begin
                            LMessageServices.AddTitleMessage(
                              '[AVISO] Erro ao ler boss-lock.json: ' + E.Message,
                              LGroup
                            );
                          end;
                        end;
                      end;
                      SetLength(Result, LPaths.Count);
                      for Idx := 0 to LPaths.Count - 1 do
                        Result[Idx] := LPaths[Idx];
                    finally
                      LPaths.Free;
                    end;
                  end;
                  procedure CheckAndAdd(const AProj: IOTAProject; const AOptionName: string; const APathToAdd: string);
                  var
                    LVal: string;
                  begin
                    try
                      LVal := VarToStr(LOptions.Values[AOptionName]);
                      if not LVal.Contains(APathToAdd) then
                      begin
                        if LVal <> '' then
                          LVal := LVal + ';' + APathToAdd
                        else
                          LVal := APathToAdd;
                        LOptions.Values[AOptionName] := LVal;
                        AProj.MarkModified;
                      end;
                    except
                      on E: Exception do
                      begin
                        LMessageServices.AddTitleMessage(
                          '[AVISO] Erro ao atualizar a opcao ' + AOptionName + ': ' + E.Message,
                          LGroup
                        );
                      end;
                    end;
                  end;
                  procedure UpdateProj(const AProj: IOTAProject);
                  var
                    LProjDir: string;
                    LSearchPaths: TArray<string>;
                    LPath: string;
                  begin
                    if AProj = nil then Exit;
                    LOptions := AProj.ProjectOptions;
                    if LOptions <> nil then
                    begin
                      LProjDir := TPath.GetDirectoryName(AProj.FileName);
                      LSearchPaths := BuildProjectSearchPaths(LProjDir);
                      for LPath in LSearchPaths do
                      begin
                        CheckAndAdd(AProj, 'UnitSearchPath', LPath);
                        CheckAndAdd(AProj, 'DCC_UnitSearchPath', LPath);
                        CheckAndAdd(AProj, 'SearchPath', LPath);
                      end;
                    end;
                  end;
                begin
                  LMessageServices.AddTitleMessage('Finalizado com sucesso!', LGroup);

                  if SameText(ACommand, 'install') or ACommand.StartsWith('install ') then
                  begin
                    if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
                    begin
                      LProjectGroup := LModuleServices.MainProjectGroup;
                      if LProjectGroup <> nil then
                      begin
                        for I := 0 to LProjectGroup.ProjectCount - 1 do
                        begin
                          LProject := LProjectGroup.Projects[I];
                          UpdateProj(LProject);
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

{ TBoss4DProjectMenuItemCreatorNotifier }

procedure AddScriptsSubmenus(const AProjectDir, AProjectName: string; const AMenuList: IInterfaceList);
var
  LBossJsonFile: string;
  LContent: string;
  LJSON, LScripts: TJSONObject;
  LScript: TJSONPair;
begin
  LBossJsonFile := TPath.Combine(AProjectDir, 'boss.json');
  if not TFile.Exists(LBossJsonFile) then
    Exit;

  try
    LContent := TFile.ReadAllText(LBossJsonFile, TEncoding.UTF8);
    LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
    if LJSON <> nil then
    begin
      try
        LScripts := LJSON.GetValue('scripts') as TJSONObject;
        if LScripts <> nil then
        begin
          for var I := 0 to LScripts.Count - 1 do
          begin
            LScript := LScripts.Pairs[I];
            var LScriptName := LScript.JsonString.Value;
            AMenuList.Add(TBoss4DProjectManagerMenu.Create(
              'Boss4D Run: ' + LScriptName,
              'mnuBoss4DRun_' + LScriptName + '_' + AProjectName,
              '',
              'Boss4DRun_' + LScriptName + '_' + AProjectName + 'Verb',
              AProjectDir,
              'run ' + LScriptName,
              200 + I
            ));
          end;
        end;
      finally
        LJSON.Free;
      end;
    end;
  except
    // Falha silenciosa na leitura do JSON
  end;
end;

procedure TBoss4DProjectMenuItemCreatorNotifier.AddMenu(const Project: IOTAProject; const IdentList: TStrings;
  const ProjectManagerMenuList: IInterfaceList; IsMultiSelect: Boolean);
var
  LProjectDir: string;
  LProjFile: string;
  LProjectName: string;
begin
  if Project = nil then
    Exit;

  LProjFile := Project.FileName;
  // Seguranca: So adiciona se o projeto estiver salvo em disco!
  if (LProjFile = '') or (not TFile.Exists(LProjFile)) then
    Exit;

  LProjectDir := TPath.GetDirectoryName(LProjFile);
  if (LProjectDir = '') or (not TDirectory.Exists(LProjectDir)) then
    Exit;

  LProjectName := TPath.GetFileNameWithoutExtension(LProjFile);
  LProjectName := LProjectName.Replace(' ', '_').Replace('-', '_').Replace('.', '_');

  // Project Manager menus must reference existing IDE parents. Keep Boss4D
  // commands at the top level to avoid parent resolution errors.
  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Init',
    'mnuBoss4DInit_' + LProjectName,
    '',
    'Boss4DInitVerb_' + LProjectName,
    LProjectDir,
    'init --quiet',
    110
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Install',
    'mnuBoss4DInstall_' + LProjectName,
    '',
    'Boss4DInstallVerb_' + LProjectName,
    LProjectDir,
    'install',
    120
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Install Package...',
    'mnuBoss4DInstallPkg_' + LProjectName,
    '',
    'Boss4DInstallPkgVerb_' + LProjectName,
    LProjectDir,
    'install-dialog',
    130
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Clean',
    'mnuBoss4DClean_' + LProjectName,
    '',
    'Boss4DCleanVerb_' + LProjectName,
    LProjectDir,
    'clean',
    135
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Outdated',
    'mnuBoss4DOutdated_' + LProjectName,
    '',
    'Boss4DOutdatedVerb_' + LProjectName,
    LProjectDir,
    'outdated',
    140
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Dependency Tree',
    'mnuBoss4DTree_' + LProjectName,
    '',
    'Boss4DTreeVerb_' + LProjectName,
    LProjectDir,
    'tree',
    150
  ));

  // Popula os comandos dinamicos de scripts
  AddScriptsSubmenus(LProjectDir, LProjectName, ProjectManagerMenuList);

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D GetIt: Set Online Mode',
    'mnuBoss4DGetItOnline_' + LProjectName,
    '',
    'Boss4DGetItOnlineVerb_' + LProjectName,
    LProjectDir,
    'getit mode-online',
    180
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D GetIt: Set Offline Mode',
    'mnuBoss4DGetItOffline_' + LProjectName,
    '',
    'Boss4DGetItOfflineVerb_' + LProjectName,
    LProjectDir,
    'getit mode-offline',
    190
  ));

  // Demais utilitarios
  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Doctor',
    'mnuBoss4DDoctor_' + LProjectName,
    '',
    'Boss4DDoctorVerb_' + LProjectName,
    LProjectDir,
    'doctor',
    300
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D License Report',
    'mnuBoss4DLicense_' + LProjectName,
    '',
    'Boss4DLicenseVerb_' + LProjectName,
    LProjectDir,
    'license report',
    310
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Cache: Clean',
    'mnuBoss4DCacheClean_' + LProjectName,
    '',
    'Boss4DCacheCleanVerb_' + LProjectName,
    LProjectDir,
    'cache clean',
    330
  ));

  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Cache: Prune',
    'mnuBoss4DCachePrune_' + LProjectName,
    '',
    'Boss4DCachePruneVerb_' + LProjectName,
    LProjectDir,
    'cache prune',
    340
  ));
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
