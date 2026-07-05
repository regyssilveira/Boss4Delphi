unit Boss4D.IDE.Wizard;

interface

uses
  System.SysUtils, System.Classes, Vcl.Menus
  {$IFDEF IDE_PLUGIN}
  , ToolsAPI
  {$ENDIF};

{$IFNDEF IDE_PLUGIN}
type
  // Mock stubs para compilar fora da IDE / testes unitarios
  IOTAProject = interface(IUnknown)
    function GetFileName: string;
    property FileName: string read GetFileName;
  end;

  TNotifierObject = class(TInterfacedObject)
  end;

  IOTAProjectManagerMenu = interface(IUnknown)
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
    function GetIsMultiSelectable: Boolean;
    procedure SetIsMultiSelectable(Value: Boolean);
    procedure Execute(const MenuContextList: IInterfaceList);
    function PreExecute(const MenuContextList: IInterfaceList): Boolean;
    function PostExecute(const MenuContextList: IInterfaceList): Boolean;
  end;

  IOTAProjectMenuItemCreatorNotifier = interface(IUnknown)
    procedure AddMenu(const Project: IOTAProject; const IdentList: TStrings;
      const ProjectManagerMenuList: IInterfaceList; IsMultiSelect: Boolean);
  end;

  IOTAWizard = interface(IUnknown)
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
  TBoss4DProjectManagerMenu = class(TNotifierObject, IOTAProjectManagerMenu)
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
    FMenuCreatorIdx: Integer;
    FNotifier: IOTAProjectMenuItemCreatorNotifier;
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
  Winapi.Windows, System.IOUtils, System.Diagnostics, System.Threading;

var
  GWizardIdx: Integer = -1;

procedure Register;
begin
  {$IFDEF IDE_PLUGIN}
  var LWizardServices: IOTAWizardServices;
  if Supports(BorlandIDEServices, IOTAWizardServices, LWizardServices) then
  begin
    GWizardIdx := LWizardServices.AddWizard(TBoss4DIDEWizard.Create);
  end;
  {$ENDIF}
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
begin
  if not FCommand.IsEmpty then
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
begin
  {$IFDEF IDE_PLUGIN}
  TThread.CreateAnonymousThread(
    procedure
    var
      LMessageServices: IOTAMessageServices;
      LGroup: IOTAMessageGroup;
      LSA: TSecurityAttributes;
      LReadPipe, LWritePipe: THandle;
      LStartInfo: TStartupInfo;
      LProcInfo: TProcessInformation;
      LBuffer: array[0..1023] of AnsiChar;
      LBytesRead: DWORD;
      LOutputLine: string;
      LCmdLine: string;
      LHomePath: string;
      LExecutable: string;
      LTextBuffer: string;
      LPos: Integer;
    begin
      if not Supports(BorlandIDEServices, IOTAMessageServices, LMessageServices) then
        Exit;

      LGroup := LMessageServices.AddMessageGroup('Boss4D');
      
      TThread.Queue(nil,
        TThreadProcedure(
          procedure
          begin
            LMessageServices.ClearMessageGroup(LGroup);
            LMessageServices.ShowMessageView(LGroup);
            LMessageServices.AddTitleMessage('Executando: boss4d ' + ACommand, LGroup);
          end
        )
      );

      LExecutable := 'boss4d.exe';
      LHomePath := TPath.Combine(GetEnvironmentVariable('USERPROFILE'), '.boss\bin');
      if TFile.Exists(TPath.Combine(LHomePath, 'boss4d.exe')) then
        LExecutable := TPath.Combine(LHomePath, 'boss4d.exe')
      else if TFile.Exists(TPath.Combine(LHomePath, 'boss.exe')) then
        LExecutable := TPath.Combine(LHomePath, 'boss.exe');

      LCmdLine := '"' + LExecutable + '" ' + ACommand;

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
            while ReadFile(LReadPipe, LBuffer, SizeOf(LBuffer) - 1, LBytesRead, nil) and (LBytesRead > 0) do
            begin
              LBuffer[LBytesRead] := #0;
              LTextBuffer := LTextBuffer + string(AnsiString(LBuffer));

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

            if not LTextBuffer.Trim.IsEmpty then
            begin
              var LMsg := LTextBuffer.Trim;
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
                begin
                  LMessageServices.AddTitleMessage('Finalizado com sucesso!', LGroup);
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

procedure TBoss4DProjectMenuItemCreatorNotifier.AddMenu(const Project: IOTAProject; const IdentList: TStrings;
  const ProjectManagerMenuList: IInterfaceList; IsMultiSelect: Boolean);
var
  LProjectDir: string;
begin
  if Project = nil then
    Exit;

  LProjectDir := TPath.GetDirectoryName(Project.FileName);

  // Adiciona o item principal "Boss4D"
  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D',
    'mnuBoss4D',
    '',
    'Boss4DVerb',
    LProjectDir,
    '',
    100
  ));

  // Adiciona o sub-menu "Boss4D Init"
  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Init',
    'mnuBoss4DInit',
    'mnuBoss4D',
    'Boss4DInitVerb',
    LProjectDir,
    'init --quiet',
    110
  ));

  // Adiciona o sub-menu "Boss4D Install"
  ProjectManagerMenuList.Add(TBoss4DProjectManagerMenu.Create(
    'Boss4D Install',
    'mnuBoss4DInstall',
    'mnuBoss4D',
    'Boss4DInstallVerb',
    LProjectDir,
    'install',
    120
  ));
end;

{ TBoss4DIDEWizard }

constructor TBoss4DIDEWizard.Create;
begin
  inherited Create;
  FMenuCreatorIdx := -1;
  FNotifier := TBoss4DProjectMenuItemCreatorNotifier.Create;
  {$IFDEF IDE_PLUGIN}
  var LProjectManager: IOTAProjectManager;
  if Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
  begin
    FMenuCreatorIdx := LProjectManager.AddMenuItemCreatorNotifier(FNotifier);
  end;
  {$ENDIF}
end;

destructor TBoss4DIDEWizard.Destroy;
begin
  {$IFDEF IDE_PLUGIN}
  var LProjectManager: IOTAProjectManager;
  if (FMenuCreatorIdx <> -1) and Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
  begin
    LProjectManager.RemoveMenuItemCreatorNotifier(FMenuCreatorIdx);
  end;
  {$ENDIF}
  inherited Destroy;
end;

function TBoss4DIDEWizard.GetIDString: string;
begin
  Result := 'Boss4D.IDE.Plugin.Wizard';
end;

function TBoss4DIDEWizard.GetName: string;
begin
  Result := 'Boss4D IDE Integration Wizard';
end;

{$IFDEF IDE_PLUGIN}
function TBoss4DIDEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TBoss4DIDEWizard.Execute;
begin
end;
{$ENDIF}

initialization

finalization

end.
