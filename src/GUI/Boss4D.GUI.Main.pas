unit Boss4D.GUI.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Boss4D.Core.Ports, Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Package,
  Boss4D.Core.Services.BuildInventory, Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDEProfileApplication,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.GUI.IDE.Presenter;

type
  TFormMain = class(TForm, IBoss4DIDEManagementView)
    PanelSidebar: TPanel;
    BtnPageProject: TButton;
    BtnPageCatalog: TButton;
    BtnPageDoctor: TButton;
    BtnPageCache: TButton;
    BtnPageIDE: TButton;
    Splitter1: TSplitter;
    PanelContent: TPanel;
    PageControlMain: TPageControl;
    TabProject: TTabSheet;
    TabCatalog: TTabSheet;
    TabDoctor: TTabSheet;
    TabCache: TTabSheet;
    TabIDE: TTabSheet;
    PanelProjTop: TPanel;
    LblProjPath: TLabel;
    EditProjPath: TEdit;
    BtnSelectProj: TButton;
    ListDependencies: TListView;
    PanelProjBottom: TPanel;
    BtnProjInit: TButton;
    BtnProjInstall: TButton;
    BtnProjOutdated: TButton;
    BtnProjTree: TButton;
    PanelCatTop: TPanel;
    LblSearch: TLabel;
    EditSearch: TEdit;
    BtnInstallSelected: TButton;
    ListCatalog: TListView;
    PanelDocTop: TPanel;
    BtnDocCheck: TButton;
    BtnDocFix: TButton;
    MemoDoctor: TMemo;
    PanelCacheTop: TPanel;
    BtnCacheClean: TButton;
    BtnCachePrune: TButton;
    MemoCache: TMemo;
    PanelIDEProfile: TPanel;
    ComboIDEProfiles: TComboBox;
    BtnIDERefresh: TButton;
    BtnIDECreateProfile: TButton;
    BtnIDECloneProfile: TButton;
    BtnIDERemoveProfile: TButton;
    BtnIDELaunch: TButton;
    ComboIDETargetPlatform: TComboBox;
    ComboIDETargetConfiguration: TComboBox;
    BtnIDESaveTarget: TButton;
    LblIDETarget: TLabel;
    ListIDEPackages: TListView;
    PanelIDEActions: TPanel;
    BtnIDEPreviewInstall: TButton;
    BtnIDEInstall: TButton;
    BtnIDERepair: TButton;
    BtnIDEPreviewRemove: TButton;
    BtnIDERemove: TButton;
    BtnIDEUndo: TButton;
    ComboIDEConflictPolicy: TComboBox;
    ComboIDEOpenPolicy: TComboBox;
    LblIDEConflictPolicy: TLabel;
    LblIDEOpenPolicy: TLabel;
    ListIDETargets: TListBox;
    LblIDEStatus: TLabel;
    PanelLogs: TPanel;
    MemoLogs: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnPageProjectClick(Sender: TObject);
    procedure BtnPageCatalogClick(Sender: TObject);
    procedure BtnPageDoctorClick(Sender: TObject);
    procedure BtnPageCacheClick(Sender: TObject);
    procedure BtnPageIDEClick(Sender: TObject);
    procedure BtnSelectProjClick(Sender: TObject);
    procedure BtnProjInitClick(Sender: TObject);
    procedure BtnProjInstallClick(Sender: TObject);
    procedure BtnProjOutdatedClick(Sender: TObject);
    procedure BtnProjTreeClick(Sender: TObject);
    procedure EditSearchChange(Sender: TObject);
    procedure BtnInstallSelectedClick(Sender: TObject);
    procedure BtnDocCheckClick(Sender: TObject);
    procedure BtnDocFixClick(Sender: TObject);
    procedure BtnCacheCleanClick(Sender: TObject);
    procedure BtnCachePruneClick(Sender: TObject);
    procedure ComboIDEProfilesChange(Sender: TObject);
    procedure BtnIDERefreshClick(Sender: TObject);
    procedure BtnIDECreateProfileClick(Sender: TObject);
    procedure BtnIDECloneProfileClick(Sender: TObject);
    procedure BtnIDERemoveProfileClick(Sender: TObject);
    procedure BtnIDELaunchClick(Sender: TObject);
    procedure BtnIDESaveTargetClick(Sender: TObject);
    procedure BtnIDEPreviewInstallClick(Sender: TObject);
    procedure BtnIDEInstallClick(Sender: TObject);
    procedure BtnIDERepairClick(Sender: TObject);
    procedure BtnIDEPreviewRemoveClick(Sender: TObject);
    procedure BtnIDERemoveClick(Sender: TObject);
    procedure BtnIDEUndoClick(Sender: TObject);
  private
    FCurrentProjectDir: string;
    FIDEProfileIds: TStringList;
    FIDEProfileStore: TBoss4DIDEProfileStore;
    FIDEProfiles: TBoss4DIDEProfileService;
    FIDEBuildInventory: TBoss4DBuildInventory;
    FIDEOperations: TBoss4DIDEProfileApplication;
    FIDEQuery: TBoss4DIDEManagementQuery;
    FIDEBackend: IBoss4DIDEManagementBackend;
    FIDEPresenter: TBoss4DIDEManagementPresenter;
    procedure InitializeIDEManagement;
    function SelectedIDEPackage: string;
    procedure LoadProjectDependencies(const AProjectDir: string);
    procedure LogMessage(const AMessage: string);
    procedure PopulateCatalog;
    procedure RunAsyncCommand(const ATitle, ACommand: string; const AArgs: string = '');
    procedure ClearProfiles;
    procedure AddProfile(const AId, AName, ACompiler,
      ARegistryBranch: string; const APackageCount: Integer);
    procedure SelectProfile(const AId: string);
    procedure SelectTarget(const APlatform, AConfiguration: string);
    procedure ClearPackages;
    procedure AddPackage(const AName, ARootDirectory: string;
      const AInstalled: Boolean);
    procedure ClearTargets;
    procedure AddTarget(const AIdentity: string);
    procedure ShowIDEStatus(const AMessage: string);
    procedure ShowIDEError(const AMessage: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.Threading, System.JSON,
  Boss4D.Adapters.Json,
  Boss4D.Adapters.Http,
  Boss4D.Adapters.Git,
  Boss4D.Adapters.Registry,
  Boss4D.Adapters.Compiler,
  Boss4D.Core.Services.Install,
  Boss4D.Core.Services.Init,
  Boss4D.Core.Services.Config,
  Boss4D.Core.Services.Doctor,
  Boss4D.Core.Services.Cache,
  Boss4D.Core.Services.Tree,
  Boss4D.Core.Services.Outdated,
  Boss4D.Core.Services.PackageIndex,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.IDEOperationResult,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.GUI.IDE.Backend;

type
  TGUILogger = class(TInterfacedObject, IBoss4DLogger)
  private
    FForm: TFormMain;
    FDebugMode: Boolean;
  public
    constructor Create(AForm: TFormMain);
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string); overload;
    procedure Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const); overload;
    procedure SetDebugMode(const AEnabled: Boolean);
  end;

constructor TGUILogger.Create(AForm: TFormMain);
begin
  inherited Create;
  FForm := AForm;
  FDebugMode := False;
end;

procedure TGUILogger.Log(const ALevel: TBoss4DLogLevel; const AMessage: string);
var
  LPrefix: string;
begin
  case ALevel of
    Debug: LPrefix := '[DEBUG] ';
    Info: LPrefix := '[INFO] ';
    Warning: LPrefix := '[WARN] ';
    Error: LPrefix := '[ERRO] ';
  end;
  FForm.LogMessage(LPrefix + AMessage);
end;

procedure TGUILogger.Log(const ALevel: TBoss4DLogLevel; const AMessage: string; const AArgs: array of const);
begin
  Log(ALevel, Format(AMessage, AArgs));
end;

procedure TGUILogger.SetDebugMode(const AEnabled: Boolean);
begin
  FDebugMode := AEnabled;
end;

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
begin
  // Oculta abas do PageControl para simular interface SPA
  for var I := 0 to PageControlMain.PageCount - 1 do
    PageControlMain.Pages[I].TabVisible := False;

  PageControlMain.ActivePage := TabProject;
  FIDEProfileIds := TStringList.Create;
  InitializeIDEManagement;
  PopulateCatalog;
  LogMessage('Boss4D GUI Inicializada com sucesso.');
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FIDEPresenter.Free;
  FIDEBackend := nil;
  FIDEQuery.Free;
  FIDEOperations.Free;
  FIDEBuildInventory.Free;
  FIDEProfiles.Free;
  FIDEProfileStore.Free;
  FIDEProfileIds.Free;
end;

procedure TFormMain.InitializeIDEManagement;
begin
  FIDEProfileStore := TBoss4DIDEProfileStore.Create(TPath.Combine(
    GetBossHome, 'ide-profiles.json'));
  FIDEProfiles := TBoss4DIDEProfileService.Create(FIDEProfileStore,
    TPath.Combine(GetBossHome, 'ide-profiles'));
  FIDEBuildInventory := TBoss4DBuildInventory.Create(TPath.Combine(
    GetBossHome, 'build-inventory.json'));
  FIDEBuildInventory.Load;
  var LRegistry: IBoss4DRegistryService :=
    TBoss4DWindowsRegistryAdapter.Create;
  var LCompiler: IBoss4DCompiler :=
    TBoss4DDelphiCompilerAdapter.Create(LRegistry, TGUILogger.Create(Self));
  FIDEOperations := TBoss4DIDEProfileApplication.Create(
    FIDEProfiles, FIDEBuildInventory,
    TBoss4DPackageJsonRepository.Create,
    TBoss4DLockJsonRepository.Create, LCompiler, TGUILogger.Create(Self),
    function(const AProfile: TBoss4DIDEProfile):
      TBoss4DIDERegistrationService
    begin
      Result := TBoss4DIDERegistrationService.Create(
        TBoss4DWindowsIDERegistryStore.Create,
        AProfile.InventoryPath, nil, nil, AProfile.Id, 30000,
        nil, AProfile.Executable, AProfile.RegistryRoot);
    end,
    TBoss4DJsonIDEOperationResultStore.Create(TPath.Combine(
      GetBossHome, 'ide-operation-results')));
  FIDEQuery := TBoss4DIDEManagementQuery.Create(
    FIDEProfiles, FIDEBuildInventory, FIDEOperations);
  FIDEBackend := TBoss4DGUIIDEManagementBackend.Create(
    FIDEQuery, FIDEProfiles, FIDEOperations);
  FIDEPresenter := TBoss4DIDEManagementPresenter.Create(
    FIDEBackend, Self);
  FIDEPresenter.Refresh;
end;

procedure TFormMain.BtnPageProjectClick(Sender: TObject);
begin
  PageControlMain.ActivePage := TabProject;
end;

procedure TFormMain.BtnPageCatalogClick(Sender: TObject);
begin
  PageControlMain.ActivePage := TabCatalog;
end;

procedure TFormMain.BtnPageDoctorClick(Sender: TObject);
begin
  PageControlMain.ActivePage := TabDoctor;
end;

procedure TFormMain.BtnPageCacheClick(Sender: TObject);
begin
  PageControlMain.ActivePage := TabCache;
end;

procedure TFormMain.BtnPageIDEClick(Sender: TObject);
begin
  PageControlMain.ActivePage := TabIDE;
  FIDEPresenter.Refresh;
end;

procedure TFormMain.BtnSelectProjClick(Sender: TObject);
var
  LDialog: TFileOpenDialog;
begin
  LDialog := TFileOpenDialog.Create(nil);
  try
    LDialog.Options := [fdoPickFolders];
    LDialog.Title := 'Selecionar Pasta do Projeto Delphi';
    if LDialog.Execute then
    begin
      FCurrentProjectDir := LDialog.FileName;
      EditProjPath.Text := FCurrentProjectDir;
      LoadProjectDependencies(FCurrentProjectDir);
    end;
  finally
    LDialog.Free;
  end;
end;

procedure TFormMain.LoadProjectDependencies(const AProjectDir: string);
var
  LBossJsonFile: string;
  LBossLockFile: string;
  LContent: string;
  LJSON, LDeps: TJSONObject;
  LPair: TJSONPair;
  LItem: TListItem;
  LLockJson: string;
  LLockObj: TJSONObject;
  LLockDep: TJSONObject;
  LDepInfo: TJSONObject;
  LInstalledVersion: string;
  I: Integer;
begin
  ListDependencies.Items.Clear;
  LBossJsonFile := TPath.Combine(AProjectDir, 'boss.json');
  if not TFile.Exists(LBossJsonFile) then
  begin
    LogMessage('[AVISO] Nenhum arquivo boss.json encontrado no diretorio selecionado.');
    Exit;
  end;

  try
    LContent := TFile.ReadAllText(LBossJsonFile, TEncoding.UTF8);
    LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
    if Assigned(LJSON) then
    begin
      try
        LDeps := LJSON.GetValue('dependencies') as TJSONObject;
        if Assigned(LDeps) then
        begin
          LBossLockFile := TPath.Combine(AProjectDir, 'boss-lock.json');
          LLockObj := nil;
          if TFile.Exists(LBossLockFile) then
          begin
            try
              LLockJson := TFile.ReadAllText(LBossLockFile, TEncoding.UTF8);
              LLockObj := TJSONObject.ParseJSONValue(LLockJson) as TJSONObject;
            except
              LLockObj := nil;
            end;
          end;

          try
            for I := 0 to LDeps.Count - 1 do
            begin
              LPair := LDeps.Pairs[I];
              LItem := ListDependencies.Items.Add;
              LItem.Caption := LPair.JsonString.Value;
              LItem.SubItems.Add(LPair.JsonValue.Value);

              // Busca versao instalada no lock
              LInstalledVersion := 'Nao instalada';
              if Assigned(LLockObj) then
              begin
                LLockDep := LLockObj.GetValue('dependencies') as TJSONObject;
                if Assigned(LLockDep) then
                begin
                  LDepInfo := LLockDep.GetValue(LPair.JsonString.Value) as TJSONObject;
                  if Assigned(LDepInfo) then
                    LInstalledVersion := LDepInfo.GetValue('version').Value;
                end;
              end;
              LItem.SubItems.Add(LInstalledVersion);
            end;
          finally
            LLockObj.Free;
          end;
        end;
      finally
        LJSON.Free;
      end;
    end;
    LogMessage('Manifesto boss.json lido e dependencias listadas com sucesso.');
  except
    on E: Exception do
      LogMessage('[ERRO] Falha ao ler boss.json: ' + E.Message);
  end;
end;

procedure TFormMain.PopulateCatalog;
var
  LItem: TListItem;
  LConfig: TBoss4DConfigService;
  LService: TBoss4DPackageIndexService;
  LLogger: IBoss4DLogger;
  LHttp: IBoss4DHttpClient;
begin
  ListCatalog.Items.Clear;
  LLogger := TGUILogger.Create(Self);
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LConfig := TBoss4DConfigService.Create(LLogger);
  LService := TBoss4DPackageIndexService.Create(LConfig, LHttp, LLogger);
  try
    var LEntries := LService.Search(Trim(EditSearch.Text));
    try
      for var LEntry in LEntries do
      begin
        LItem := ListCatalog.Items.Add;
        LItem.Caption := LEntry.Name;
        LItem.SubItems.Add(LEntry.Repository);
      end;
    finally
      LEntries.Free;
    end;
  finally
    LService.Free;
    LConfig.Free;
  end;
end;

procedure TFormMain.EditSearchChange(Sender: TObject);
begin
  PopulateCatalog;
end;

procedure TFormMain.LogMessage(const AMessage: string);
var
  LMsg: string;
begin
  LMsg := AMessage;
  TThread.Queue(nil,
    TThreadProcedure(
      procedure
      begin
        MemoLogs.Lines.Add(LMsg);
      end
    )
  );
end;

procedure TFormMain.RunAsyncCommand(const ATitle, ACommand: string; const AArgs: string);
begin
  if FCurrentProjectDir = '' then
  begin
    ShowMessage('Por favor, selecione a pasta do projeto local primeiro!');
    Exit;
  end;

  LogMessage('Iniciando: ' + ATitle);

  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LPackageRepo: IBoss4DPackageRepository;
      LLockRepo: IBoss4DLockRepository;
      LHttpClient: IBoss4DHttpClient;
      LRegistry: IBoss4DRegistryService;
      LCompiler: IBoss4DCompiler;
      LConfigService: TBoss4DConfigService;
      LGlobalConfig: TBoss4DGlobalConfig;
      LGitClient: IBoss4DGitClient;
      LInstallService: TBoss4DInstallService;
      LInitService: TBoss4DInitService;
    begin
      try
        LLogger := TGUILogger.Create(Self);
        LPackageRepo := TBoss4DPackageJsonRepository.Create;
        LLockRepo := TBoss4DLockJsonRepository.Create;
        LHttpClient := TBoss4DHttpNativeAdapter.Create;
        LRegistry := TBoss4DWindowsRegistryAdapter.Create;
        LCompiler := TBoss4DDelphiCompilerAdapter.Create(LRegistry, LLogger);

        LConfigService := TBoss4DConfigService.Create(LLogger);
        LGlobalConfig := LConfigService.Load;
        try
          LGitClient := TBoss4DGitCliAdapter.Create(LGlobalConfig.GitShallow);
        finally
          LGlobalConfig.Free;
          LConfigService.Free;
        end;

        if ACommand = 'install' then
        begin
          LInstallService := TBoss4DInstallService.Create(
            LPackageRepo, LLockRepo, LGitClient, LHttpClient, LCompiler, LLogger);
          try
            TDirectory.SetCurrentDirectory(FCurrentProjectDir);
            LInstallService.Execute(AArgs);
            LogMessage('Comando finalizado com sucesso: ' + ATitle);
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  LoadProjectDependencies(FCurrentProjectDir);
                end
              )
            );
          finally
            LInstallService.Free;
          end;
        end
        else if ACommand = 'init' then
        begin
          LInitService := TBoss4DInitService.Create(LPackageRepo, LLogger);
          try
            TDirectory.SetCurrentDirectory(FCurrentProjectDir);
            LInitService.Execute(True);
            LogMessage('Comando finalizado com sucesso: ' + ATitle);
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  LoadProjectDependencies(FCurrentProjectDir);
                end
              )
            );
          finally
            LInitService.Free;
          end;
        end;
      except
        on E: Exception do
          LogMessage('[FALHA] Erro ao executar ' + ATitle + ': ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.BtnProjInitClick(Sender: TObject);
begin
  RunAsyncCommand('Boss4D Init', 'init');
end;

procedure TFormMain.BtnProjInstallClick(Sender: TObject);
begin
  RunAsyncCommand('Boss4D Install', 'install');
end;

procedure TFormMain.BtnProjOutdatedClick(Sender: TObject);
begin
  if FCurrentProjectDir = '' then Exit;
  LogMessage('Verificando pacotes desatualizados...');
  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LPackageRepo: IBoss4DPackageRepository;
      LLockRepo: IBoss4DLockRepository;
      LConfigService: TBoss4DConfigService;
      LGlobalConfig: TBoss4DGlobalConfig;
      LGitClient: IBoss4DGitClient;
      LService: TBoss4DOutdatedService;
    begin
      try
        LLogger := TGUILogger.Create(Self);
        LPackageRepo := TBoss4DPackageJsonRepository.Create;
        LLockRepo := TBoss4DLockJsonRepository.Create;
        LConfigService := TBoss4DConfigService.Create(LLogger);
        LGlobalConfig := LConfigService.Load;
        try
          LGitClient := TBoss4DGitCliAdapter.Create(LGlobalConfig.GitShallow);
        finally
          LGlobalConfig.Free;
          LConfigService.Free;
        end;

        TDirectory.SetCurrentDirectory(FCurrentProjectDir);
        LService := TBoss4DOutdatedService.Create(LPackageRepo, LLockRepo, LGitClient, LLogger);
        try
          LService.CheckOutdated;
        finally
          LService.Free;
        end;
      except
        on E: Exception do
          LogMessage('[ERRO] ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.BtnProjTreeClick(Sender: TObject);
begin
  if FCurrentProjectDir = '' then Exit;
  LogMessage('Gerando arvore de dependencias...');
  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LPackageRepo: IBoss4DPackageRepository;
      LService: TBoss4DTreeService;
    begin
      try
        LLogger := TGUILogger.Create(Self);
        LPackageRepo := TBoss4DPackageJsonRepository.Create;
        TDirectory.SetCurrentDirectory(FCurrentProjectDir);
        LService := TBoss4DTreeService.Create(LPackageRepo, LLogger);
        try
          LService.GenerateTree;
        finally
          LService.Free;
        end;
      except
        on E: Exception do
          LogMessage('[ERRO] ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.BtnInstallSelectedClick(Sender: TObject);
var
  LRepo: string;
begin
  if ListCatalog.Selected = nil then
  begin
    ShowMessage('Por favor, selecione um pacote do catalogo para instalar!');
    Exit;
  end;

  LRepo := ListCatalog.Selected.SubItems[0];
  RunAsyncCommand('Instalacao de ' + ListCatalog.Selected.Caption, 'install', LRepo);
end;

procedure TFormMain.BtnDocCheckClick(Sender: TObject);
begin
  MemoDoctor.Clear;
  MemoDoctor.Lines.Add('Iniciando diagnostico do ambiente...');
  TTask.Run(
    procedure
      var
        LLogger: IBoss4DLogger;
        LRegistry: IBoss4DRegistryService;
        LService: TBoss4DDoctorService;
      begin
        try
          LLogger := TGUILogger.Create(Self);
          LRegistry := TBoss4DWindowsRegistryAdapter.Create;
          LService := TBoss4DDoctorService.Create(LRegistry, LLogger);
          try
            LService.Check(False);
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  MemoDoctor.Lines.Add('Diagnostico finalizado.');
                end
              )
            );
          finally
            LService.Free;
          end;
      except
        on E: Exception do
          MemoDoctor.Lines.Add('[ERRO] ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.BtnDocFixClick(Sender: TObject);
begin
  MemoDoctor.Clear;
  MemoDoctor.Lines.Add('Iniciando auto-correcao do ambiente...');
  TTask.Run(
    procedure
      var
        LLogger: IBoss4DLogger;
        LRegistry: IBoss4DRegistryService;
        LService: TBoss4DDoctorService;
      begin
        try
          LLogger := TGUILogger.Create(Self);
          LRegistry := TBoss4DWindowsRegistryAdapter.Create;
          LService := TBoss4DDoctorService.Create(LRegistry, LLogger);
          try
            LService.Check(True);
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  MemoDoctor.Lines.Add('Auto-correcao finalizada.');
                end
              )
            );
          finally
            LService.Free;
          end;
      except
        on E: Exception do
          MemoDoctor.Lines.Add('[ERRO] ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.BtnCacheCleanClick(Sender: TObject);
begin
  MemoCache.Clear;
  MemoCache.Lines.Add('Limpando cache global...');
  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LService: TBoss4DCacheService;
    begin
      try
        LLogger := TGUILogger.Create(Self);
        LService := TBoss4DCacheService.Create(LLogger);
        try
          LService.Clean;
          TThread.Queue(nil,
            TThreadProcedure(
              procedure
              begin
                MemoCache.Lines.Add('Cache limpo com sucesso.');
              end
            )
          );
        finally
          LService.Free;
        end;
      except
        on E: Exception do
          MemoCache.Lines.Add('[ERRO] ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.BtnCachePruneClick(Sender: TObject);
begin
  MemoCache.Clear;
  MemoCache.Lines.Add('Realizando prune inteligente do cache global...');
  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LService: TBoss4DCacheService;
    begin
      try
        LLogger := TGUILogger.Create(Self);
        LService := TBoss4DCacheService.Create(LLogger);
        try
          LService.Prune;
          TThread.Queue(nil,
            TThreadProcedure(
              procedure
              begin
                MemoCache.Lines.Add('Prune finalizado com sucesso.');
              end
            )
          );
        finally
          LService.Free;
        end;
      except
        on E: Exception do
          MemoCache.Lines.Add('[ERRO] ' + E.Message);
      end;
    end
  );
end;

procedure TFormMain.ClearProfiles;
begin
  ComboIDEProfiles.Items.BeginUpdate;
  try
    ComboIDEProfiles.Clear;
    FIDEProfileIds.Clear;
  finally
    ComboIDEProfiles.Items.EndUpdate;
  end;
end;

procedure TFormMain.AddProfile(const AId, AName, ACompiler,
  ARegistryBranch: string; const APackageCount: Integer);
begin
  FIDEProfileIds.Add(AId);
  ComboIDEProfiles.Items.Add(Format('%s — Delphi %s — %d package(s)',
    [AName, ACompiler, APackageCount]));
end;

procedure TFormMain.SelectProfile(const AId: string);
begin
  var LIndex := FIDEProfileIds.IndexOf(AId);
  if LIndex >= 0 then
    ComboIDEProfiles.ItemIndex := LIndex;
end;

procedure TFormMain.SelectTarget(const APlatform,
  AConfiguration: string);
begin
  var LIndex := ComboIDETargetPlatform.Items.IndexOf(APlatform);
  if LIndex < 0 then
    LIndex := ComboIDETargetPlatform.Items.Add(APlatform);
  ComboIDETargetPlatform.ItemIndex := LIndex;
  LIndex := ComboIDETargetConfiguration.Items.IndexOf(AConfiguration);
  if LIndex < 0 then
    LIndex := ComboIDETargetConfiguration.Items.Add(AConfiguration);
  ComboIDETargetConfiguration.ItemIndex := LIndex;
end;

procedure TFormMain.ClearPackages;
begin
  ListIDEPackages.Items.Clear;
end;

procedure TFormMain.AddPackage(const AName, ARootDirectory: string;
  const AInstalled: Boolean);
begin
  var LItem := ListIDEPackages.Items.Add;
  LItem.Caption := AName;
  if AInstalled then
    LItem.SubItems.Add('Instalado')
  else
    LItem.SubItems.Add('Disponivel');
  LItem.SubItems.Add(ARootDirectory);
end;

procedure TFormMain.ClearTargets;
begin
  ListIDETargets.Clear;
end;

procedure TFormMain.AddTarget(const AIdentity: string);
begin
  ListIDETargets.Items.Add(AIdentity);
end;

procedure TFormMain.ShowIDEStatus(const AMessage: string);
begin
  LblIDEStatus.Caption := AMessage;
  LogMessage('[IDE] ' + AMessage);
end;

procedure TFormMain.ShowIDEError(const AMessage: string);
begin
  LblIDEStatus.Caption := 'Erro: ' + AMessage;
  LogMessage('[IDE][ERRO] ' + AMessage);
  MessageDlg(AMessage, mtError, [mbOK], 0);
end;

function TFormMain.SelectedIDEPackage: string;
begin
  if Assigned(ListIDEPackages.Selected) then
    Result := ListIDEPackages.Selected.Caption
  else
    Result := '';
end;

procedure TFormMain.ComboIDEProfilesChange(Sender: TObject);
begin
  if (ComboIDEProfiles.ItemIndex >= 0) and
     (ComboIDEProfiles.ItemIndex < FIDEProfileIds.Count) then
    FIDEPresenter.ChooseProfile(
      FIDEProfileIds[ComboIDEProfiles.ItemIndex]);
end;

procedure TFormMain.BtnIDERefreshClick(Sender: TObject);
begin
  FIDEPresenter.Refresh;
end;

procedure TFormMain.BtnIDECreateProfileClick(Sender: TObject);
begin
  var LName := '';
  var LCompiler := '37.0';
  var LExecutable := '';
  if not InputQuery('Novo perfil IDE', 'Nome do perfil:', LName) then
    Exit;
  if not InputQuery('Novo perfil IDE', 'Versao BDS/compilador:',
    LCompiler) then
    Exit;
  if not InputQuery('Novo perfil IDE',
    'Executavel bds.exe (opcional):', LExecutable) then
    Exit;
  FIDEPresenter.CreateProfile(LName, '', LCompiler, LExecutable);
end;

procedure TFormMain.BtnIDECloneProfileClick(Sender: TObject);
begin
  var LName := '';
  if InputQuery('Clonar perfil IDE', 'Nome do novo perfil:', LName) then
    FIDEPresenter.CloneProfile(LName);
end;

procedure TFormMain.BtnIDERemoveProfileClick(Sender: TObject);
begin
  if MessageDlg('Remover o perfil selecionado? O perfil default nao pode ' +
    'ser removido.', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    FIDEPresenter.RemoveProfile;
end;

procedure TFormMain.BtnIDELaunchClick(Sender: TObject);
begin
  FIDEPresenter.Launch;
end;

procedure TFormMain.BtnIDESaveTargetClick(Sender: TObject);
begin
  FIDEPresenter.ConfigureTarget(
    ComboIDETargetPlatform.Text,
    ComboIDETargetConfiguration.Text);
end;

procedure TFormMain.BtnIDEPreviewInstallClick(Sender: TObject);
begin
  FIDEPresenter.PreviewInstall(SelectedIDEPackage);
end;

procedure TFormMain.BtnIDEInstallClick(Sender: TObject);
begin
  if MessageDlg('Compilar e registrar o package selecionado neste perfil?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    var LConflictPolicy := TBoss4DIDEConflictPolicy.Fail;
    case ComboIDEConflictPolicy.ItemIndex of
      1: LConflictPolicy := TBoss4DIDEConflictPolicy.Warn;
      2: LConflictPolicy := TBoss4DIDEConflictPolicy.Adopt;
      3: LConflictPolicy := TBoss4DIDEConflictPolicy.Replace;
    end;
    var LOpenPolicy := TBoss4DIDEOpenPolicy.Fail;
    case ComboIDEOpenPolicy.ItemIndex of
      1: LOpenPolicy := TBoss4DIDEOpenPolicy.Defer;
      2: LOpenPolicy := TBoss4DIDEOpenPolicy.Force;
    end;
    Screen.Cursor := crHourGlass;
    PanelIDEActions.Enabled := False;
    try
      ShowIDEStatus('Compilando e registrando o package...');
      Vcl.Forms.Application.ProcessMessages;
      FIDEPresenter.Install(SelectedIDEPackage,
        LConflictPolicy, LOpenPolicy);
    finally
      PanelIDEActions.Enabled := True;
      Screen.Cursor := crDefault;
    end;
  end;
end;

procedure TFormMain.BtnIDERepairClick(Sender: TObject);
begin
  FIDEPresenter.Repair;
end;

procedure TFormMain.BtnIDEPreviewRemoveClick(Sender: TObject);
begin
  FIDEPresenter.PreviewUninstall(SelectedIDEPackage);
end;

procedure TFormMain.BtnIDERemoveClick(Sender: TObject);
begin
  if MessageDlg('Remover os registros e artefatos gerenciados deste ' +
    'package?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    FIDEPresenter.Uninstall(SelectedIDEPackage);
end;

procedure TFormMain.BtnIDEUndoClick(Sender: TObject);
begin
  if MessageDlg('Desfazer a ultima instalacao ou remocao concluida?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    FIDEPresenter.Undo;
end;

end.
