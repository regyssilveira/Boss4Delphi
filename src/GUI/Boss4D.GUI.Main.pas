unit Boss4D.GUI.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Boss4D.Core.Ports, Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Package,
  Boss4D.Core.Domain.Progress,
  Boss4D.Core.Services.BuildInventory, Boss4D.Core.Services.IDEProfiles,
  Boss4D.Core.Services.IDEProfileApplication,
  Boss4D.Core.Services.BuildExecutor,
  Boss4D.Core.Services.IDEManagementQuery,
  Boss4D.GUI.IDE.Presenter,
  Boss4D.GUI.IDE.Timeline,
  Boss4D.GUI.IDE.Dashboard,
  Boss4D.GUI.Logs,
  Boss4D.GUI.Catalog.Presenter,
  Boss4D.GUI.Install.Presenter,
  Boss4D.GUI.IDE.Install.Presenter,
  Boss4D.GUI.Operation.Presenter,
  Boss4D.GUI.TargetProgress,
  Boss4D.GUI.Health.Presenter;

type
  TBoss4DGUIOperationKind = (OperationNone, OperationRegistryInstall,
    OperationProjectInstall, OperationProjectRebuild, OperationIDEInstall);

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
    PanelCatalogDetails: TPanel;
    MemoCatalogDetails: TMemo;
    PanelCatalogLinks: TPanel;
    BtnCatalogRepository: TButton;
    BtnCatalogChangelog: TButton;
    BtnCatalogSbom: TButton;
    PanelDocTop: TPanel;
    BtnDocCheck: TButton;
    BtnDocFix: TButton;
    BtnDocRepairIDE: TButton;
    BtnDocUndoIDE: TButton;
    BtnDocOptimizeCache: TButton;
    BtnDocRebuild: TButton;
    BtnDocReregister: TButton;
    LblDocSummary: TLabel;
    ListDoctorHealth: TListView;
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
    BtnIDEDashboard: TButton;
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
    BtnIDEHistory: TButton;
    BtnIDESnapshot: TButton;
    BtnIDEDiff: TButton;
    BtnIDERestoreSnapshot: TButton;
    ComboIDEConflictPolicy: TComboBox;
    ComboIDEOpenPolicy: TComboBox;
    LblIDEConflictPolicy: TLabel;
    LblIDEOpenPolicy: TLabel;
    ListIDETargets: TListBox;
    LblIDEStatus: TLabel;
    PanelLogs: TPanel;
    PanelOperation: TPanel;
    LblOperation: TLabel;
    ProgressOperation: TProgressBar;
    BtnCancelOperation: TButton;
    BtnRetryOperation: TButton;
    PanelLogFilters: TPanel;
    ComboLogLevel: TComboBox;
    EditLogSearch: TEdit;
    BtnLogErrors: TButton;
    BtnLogExport: TButton;
    BtnLogClear: TButton;
    ListLogs: TListView;
    TimerOperation: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
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
    procedure ListCatalogSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure BtnCatalogRepositoryClick(Sender: TObject);
    procedure BtnCatalogChangelogClick(Sender: TObject);
    procedure BtnCatalogSbomClick(Sender: TObject);
    procedure BtnDocCheckClick(Sender: TObject);
    procedure BtnDocFixClick(Sender: TObject);
    procedure BtnDocRepairIDEClick(Sender: TObject);
    procedure BtnDocUndoIDEClick(Sender: TObject);
    procedure BtnDocOptimizeCacheClick(Sender: TObject);
    procedure BtnDocRebuildClick(Sender: TObject);
    procedure BtnDocReregisterClick(Sender: TObject);
    procedure ListDoctorHealthSelectItem(Sender: TObject;
      Item: TListItem; Selected: Boolean);
    procedure BtnCacheCleanClick(Sender: TObject);
    procedure BtnCachePruneClick(Sender: TObject);
    procedure ComboIDEProfilesChange(Sender: TObject);
    procedure BtnIDERefreshClick(Sender: TObject);
    procedure BtnIDECreateProfileClick(Sender: TObject);
    procedure BtnIDECloneProfileClick(Sender: TObject);
    procedure BtnIDERemoveProfileClick(Sender: TObject);
    procedure BtnIDELaunchClick(Sender: TObject);
    procedure BtnIDEDashboardClick(Sender: TObject);
    procedure BtnIDESaveTargetClick(Sender: TObject);
    procedure BtnIDEPreviewInstallClick(Sender: TObject);
    procedure BtnIDEInstallClick(Sender: TObject);
    procedure BtnIDERepairClick(Sender: TObject);
    procedure BtnIDEPreviewRemoveClick(Sender: TObject);
    procedure BtnIDERemoveClick(Sender: TObject);
    procedure BtnIDEUndoClick(Sender: TObject);
    procedure BtnIDEHistoryClick(Sender: TObject);
    procedure BtnIDESnapshotClick(Sender: TObject);
    procedure BtnIDEDiffClick(Sender: TObject);
    procedure BtnIDERestoreSnapshotClick(Sender: TObject);
    procedure BtnCancelOperationClick(Sender: TObject);
    procedure BtnRetryOperationClick(Sender: TObject);
    procedure TimerOperationTimer(Sender: TObject);
    procedure ComboLogLevelChange(Sender: TObject);
    procedure EditLogSearchChange(Sender: TObject);
    procedure BtnLogErrorsClick(Sender: TObject);
    procedure BtnLogExportClick(Sender: TObject);
    procedure BtnLogClearClick(Sender: TObject);
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
    FCatalogRows: TArray<TBoss4DGUICatalogRow>;
    FOperationPresenter: TBoss4DGUIOperationPresenter;
    FLogStore: TBoss4DGUILogStore;
    FCancelRequested: Integer;
    FLastInstallRequest: TBoss4DGUIInstallRequest;
    FHasLastInstallRequest: Boolean;
    FLastIDEInstallRequest: TBoss4DGUIIDEInstallRequest;
    FHasLastIDEInstallRequest: Boolean;
    FOperationKind: TBoss4DGUIOperationKind;
    FOperationTitle: string;
    FHealthRows: TArray<TBoss4DGUIHealthRow>;
    procedure InitializeIDEManagement;
    function SelectedIDEPackage: string;
    procedure LoadProjectDependencies(const AProjectDir: string);
    procedure LogMessage(const AMessage: string);
    procedure LogStructured(const ALevel: TBoss4DLogLevel;
      const ASource, AMessage: string);
    procedure QueueLogEntry(const AEntry: TBoss4DGUILogEntry);
    procedure RefreshLogs;
    function CurrentLogFilter: TBoss4DGUILogFilter;
    procedure PopulateCatalog;
    procedure ShowCatalogDetails(const AIndex: Integer);
    procedure OpenCatalogUrl(const AUrl, ALabel: string);
    procedure RunAsyncCommand(const ATitle, ACommand: string; const AArgs: string = '');
    procedure RunAsyncGuidedInstall(
      const ARequest: TBoss4DGUIInstallRequest);
    procedure FinishGuidedInstall(const ACancelled: Boolean;
      const AOutput, AError, AProjectDirectory: string);
    procedure QueueProjectProgress(const AEvent: TBoss4DProgressEvent);
    procedure HandleProjectProgress(const AEvent: TBoss4DProgressEvent);
    procedure FinishProjectInstall(const AError,
      AProjectDirectory: string);
    procedure RunAsyncIDEInstall(
      const ARequest: TBoss4DGUIIDEInstallRequest);
    procedure QueueIDETargetProgress(
      const AEvent: TBoss4DBuildTargetProgressEvent);
    procedure HandleIDETargetProgress(
      const AEvent: TBoss4DBuildTargetProgressEvent);
    procedure FinishIDEInstall(const ARequest: TBoss4DGUIIDEInstallRequest;
      const AAffected: Integer; const AError: string;
      const ACancelled: Boolean);
    procedure UpdateOperationUI;
    procedure RunHealthCheck(const AFix: Boolean);
    procedure RunAsyncProjectRebuild;
    procedure UpdateHealthActions;
    procedure PopulateHealth(const ARows: TArray<TBoss4DGUIHealthRow>;
      const ASummary: string);
    function FindBoss4DExecutable: string;
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
    procedure ShowHistory(
      const ARows: TArray<TBoss4DGUITimelineRow>);
    procedure ShowDashboard(
      const ARows: TArray<TBoss4DGUIProfileDashboardRow>);
    procedure ShowIDEStatus(const AMessage: string);
    procedure ShowIDEError(const AMessage: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.Threading, System.JSON, System.StrUtils,
  System.SyncObjs,
  Winapi.ShellAPI,
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
  Boss4D.GUI.Install.Dialog,
  Boss4D.GUI.Process.Windows,
  Boss4D.Core.Domain.Env,
  Boss4D.Core.Domain.IDEProfile,
  Boss4D.Core.Services.IDERegistration,
  Boss4D.Core.Services.BuildDoctor,
  Boss4D.Core.Services.BuildCommand,
  Boss4D.Core.Services.BuildCoordinator,
  Boss4D.Core.Services.IDEOperationResult,
  Boss4D.Core.Services.IDEProcessPolicy,
  Boss4D.GUI.IDE.Backend,
  Boss4D.GUI.IDE.Timeline.Dialog,
  Boss4D.GUI.IDE.Dashboard.Dialog,
  Boss4D.GUI.IDE.Install.Dialog;

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
begin
  FForm.LogStructured(ALevel, 'Core', AMessage);
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
  FOperationPresenter := TBoss4DGUIOperationPresenter.Create;
  FLogStore := TBoss4DGUILogStore.Create;
  FIDEProfileIds := TStringList.Create;
  InitializeIDEManagement;
  PopulateCatalog;
  LogMessage('Boss4D GUI Inicializada com sucesso.');
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  TInterlocked.Exchange(FCancelRequested, 1);
  FIDEPresenter.Free;
  FIDEBackend := nil;
  FIDEQuery.Free;
  FIDEOperations.Free;
  FIDEBuildInventory.Free;
  FIDEProfiles.Free;
  FIDEProfileStore.Free;
  FIDEProfileIds.Free;
  FLogStore.Free;
  FOperationPresenter.Free;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FOperationPresenter.State <> GUIRunning;
  if not CanClose then
    ShowMessage('Cancele a operacao atual e aguarde sua finalizacao antes ' +
      'de fechar a GUI.');
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
  LPresenter: TBoss4DGUICatalogPresenter;
begin
  ListCatalog.Items.Clear;
  FCatalogRows := nil;
  MemoCatalogDetails.Clear;
  LLogger := TGUILogger.Create(Self);
  LHttp := TBoss4DHttpNativeAdapter.Create;
  LConfig := TBoss4DConfigService.Create(LLogger);
  LService := TBoss4DPackageIndexService.Create(LConfig, LHttp, LLogger);
  LPresenter := TBoss4DGUICatalogPresenter.Create;
  try
    var LEntries := LService.Search(Trim(EditSearch.Text));
    try
      FCatalogRows := LPresenter.BuildRows(LEntries);
      for var LRow in FCatalogRows do
      begin
        LItem := ListCatalog.Items.Add;
        LItem.Caption := LRow.Name;
        LItem.SubItems.Add(LRow.Version);
        LItem.SubItems.Add(LRow.VersionSummary);
        LItem.SubItems.Add(LRow.Repository);
      end;
    finally
      LEntries.Free;
    end;
  finally
    LPresenter.Free;
    LService.Free;
    LConfig.Free;
  end;
end;

procedure TFormMain.ShowCatalogDetails(const AIndex: Integer);
var
  LRow: TBoss4DGUICatalogRow;
begin
  MemoCatalogDetails.Clear;
  BtnCatalogRepository.Enabled := False;
  BtnCatalogChangelog.Enabled := False;
  BtnCatalogSbom.Enabled := False;
  if (AIndex < 0) or (AIndex >= Length(FCatalogRows)) then
    Exit;
  LRow := FCatalogRows[AIndex];
  MemoCatalogDetails.Lines.Add(LRow.Name + ' ' + LRow.Version);
  if LRow.Description <> '' then
    MemoCatalogDetails.Lines.Add(LRow.Description);
  MemoCatalogDetails.Lines.Add('Licenca: ' +
    IfThen(LRow.License <> '', LRow.License, 'nao informada'));
  MemoCatalogDetails.Lines.Add('Versoes: ' +
    IfThen(LRow.Versions <> '', LRow.Versions, 'nao informadas'));
  MemoCatalogDetails.Lines.Add('Variantes: ' + LRow.VariantSummary);
  MemoCatalogDetails.Lines.Add('Compatibilidade: ' +
    LRow.CompatibilitySummary);
  MemoCatalogDetails.Lines.Add('Dependencias: ' + LRow.DependencyGraph);
  MemoCatalogDetails.Lines.Add('Conformidade: ' + LRow.SupplyChainSummary);
  if LRow.ChangelogUrl.IsEmpty then
    MemoCatalogDetails.Lines.Add('Changelog: nao informado no Registry')
  else
    MemoCatalogDetails.Lines.Add('Changelog: disponivel');
  if LRow.SbomUrl.IsEmpty then
    MemoCatalogDetails.Lines.Add('SBOM: nao informado no Registry')
  else
    MemoCatalogDetails.Lines.Add('SBOM: disponivel');
  MemoCatalogDetails.Lines.Add('Repositorio: ' + LRow.Repository);
  BtnCatalogRepository.Enabled := not LRow.Repository.Trim.IsEmpty;
  BtnCatalogChangelog.Enabled :=
    TBoss4DGUICatalogPresenter.IsNavigableUrl(LRow.ChangelogUrl);
  BtnCatalogSbom.Enabled :=
    TBoss4DGUICatalogPresenter.IsNavigableUrl(LRow.SbomUrl);
end;

procedure TFormMain.OpenCatalogUrl(const AUrl, ALabel: string);
begin
  var LUrl := AUrl.Trim;
  if not LUrl.Contains('://') then
    LUrl := 'https://' + LUrl;
  if not TBoss4DGUICatalogPresenter.IsNavigableUrl(LUrl) then
  begin
    ShowMessage(ALabel + ' nao possui uma URL HTTP valida.');
    Exit;
  end;
  if ShellExecute(Handle, 'open', PChar(LUrl), nil, nil,
     SW_SHOWNORMAL) <= 32 then
    ShowMessage('Nao foi possivel abrir ' + ALabel + '.');
end;

procedure TFormMain.BtnCatalogRepositoryClick(Sender: TObject);
begin
  if Assigned(ListCatalog.Selected) then
    OpenCatalogUrl(FCatalogRows[ListCatalog.Selected.Index].Repository,
      'o repositorio');
end;

procedure TFormMain.BtnCatalogChangelogClick(Sender: TObject);
begin
  if Assigned(ListCatalog.Selected) then
    OpenCatalogUrl(FCatalogRows[ListCatalog.Selected.Index].ChangelogUrl,
      'o changelog');
end;

procedure TFormMain.BtnCatalogSbomClick(Sender: TObject);
begin
  if Assigned(ListCatalog.Selected) then
    OpenCatalogUrl(FCatalogRows[ListCatalog.Selected.Index].SbomUrl,
      'o SBOM');
end;

procedure TFormMain.ListCatalogSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  if Selected then
    ShowCatalogDetails(Item.Index)
  else if ListCatalog.Selected = nil then
    ShowCatalogDetails(-1);
end;

procedure TFormMain.EditSearchChange(Sender: TObject);
begin
  PopulateCatalog;
end;

procedure TFormMain.LogMessage(const AMessage: string);
begin
  QueueLogEntry(TBoss4DGUILogs.ParseLegacy(AMessage));
end;

procedure TFormMain.LogStructured(const ALevel: TBoss4DLogLevel;
  const ASource, AMessage: string);
begin
  QueueLogEntry(TBoss4DGUILogEntry.Create(
    ALevel, ASource, AMessage));
end;

procedure TFormMain.QueueLogEntry(const AEntry: TBoss4DGUILogEntry);
var
  LEntry: TBoss4DGUILogEntry;
begin
  LEntry := AEntry;
  TThread.Queue(nil,
    TThreadProcedure(
      procedure
      begin
        if not Assigned(FLogStore) then
          Exit;
        FLogStore.Add(LEntry);
        RefreshLogs;
      end
    )
  );
end;

function TFormMain.CurrentLogFilter: TBoss4DGUILogFilter;
begin
  case ComboLogLevel.ItemIndex of
    1: Result := TBoss4DGUILogFilter.DebugLogs;
    2: Result := TBoss4DGUILogFilter.InfoLogs;
    3: Result := TBoss4DGUILogFilter.WarningLogs;
    4: Result := TBoss4DGUILogFilter.ErrorLogs;
  else
    Result := TBoss4DGUILogFilter.AllLogs;
  end;
end;

procedure TFormMain.RefreshLogs;
begin
  if not Assigned(FLogStore) then
    Exit;
  var LEntries := FLogStore.Query(
    CurrentLogFilter, EditLogSearch.Text);
  ListLogs.Items.BeginUpdate;
  try
    ListLogs.Items.Clear;
    for var LEntry in LEntries do
    begin
      var LItem := ListLogs.Items.Add;
      LItem.Caption := LEntry.OccurredAt;
      LItem.SubItems.Add(LEntry.LevelName);
      LItem.SubItems.Add(LEntry.Source);
      LItem.SubItems.Add(LEntry.MessageText);
    end;
  finally
    ListLogs.Items.EndUpdate;
  end;
  if ListLogs.Items.Count > 0 then
    ListLogs.Items[ListLogs.Items.Count - 1].MakeVisible(False);
end;

procedure TFormMain.ComboLogLevelChange(Sender: TObject);
begin
  RefreshLogs;
end;

procedure TFormMain.EditLogSearchChange(Sender: TObject);
begin
  RefreshLogs;
end;

procedure TFormMain.BtnLogErrorsClick(Sender: TObject);
begin
  ComboLogLevel.ItemIndex := 4;
  RefreshLogs;
  if ListLogs.Items.Count > 0 then
  begin
    ListLogs.Selected := ListLogs.Items[ListLogs.Items.Count - 1];
    ListLogs.Selected.MakeVisible(False);
    ListLogs.SetFocus;
  end;
end;

procedure TFormMain.BtnLogExportClick(Sender: TObject);
begin
  var LDialog := TSaveDialog.Create(Self);
  try
    LDialog.Title := 'Exportar diagnostico da GUI';
    LDialog.Filter := 'JSON (*.json)|*.json';
    LDialog.DefaultExt := 'json';
    LDialog.FileName := 'boss4d-gui-diagnostics.json';
    if LDialog.Execute then
    begin
      TBoss4DGUILogs.SaveJson(LDialog.FileName,
        FLogStore.Query(TBoss4DGUILogFilter.AllLogs));
      ShowMessage('Diagnostico exportado para ' + LDialog.FileName);
    end;
  finally
    LDialog.Free;
  end;
end;

procedure TFormMain.BtnLogClearClick(Sender: TObject);
begin
  FLogStore.Clear;
  RefreshLogs;
end;

procedure TFormMain.QueueProjectProgress(
  const AEvent: TBoss4DProgressEvent);
var
  LEvent: TBoss4DProgressEvent;
begin
  LEvent := AEvent;
  TThread.Queue(nil,
    procedure
    begin
      HandleProjectProgress(LEvent);
    end);
end;

procedure TFormMain.HandleProjectProgress(
  const AEvent: TBoss4DProgressEvent);
begin
  var LPhase := Boss4DProgressPhaseName(AEvent.Phase);
  if AEvent.Total > 0 then
  begin
    ProgressOperation.Style := pbstNormal;
    ProgressOperation.Min := 0;
    ProgressOperation.Max := AEvent.Total;
    ProgressOperation.Position := AEvent.Current;
    LblOperation.Caption := Format('%s - %s %d/%d - %s',
      [FOperationTitle, AEvent.PackageName, AEvent.Current,
       AEvent.Total, AEvent.Message]);
  end
  else
  begin
    ProgressOperation.Style := pbstMarquee;
    LblOperation.Caption := FOperationTitle + ' - ' +
      AEvent.PackageName + ' - ' + AEvent.Message;
  end;
  if AEvent.Phase = TBoss4DProgressPhase.Failed then
    LogStructured(TBoss4DLogLevel.Error, 'Project Build',
      '[' + LPhase + '] ' + AEvent.PackageName + ': ' + AEvent.Message)
  else
    LogStructured(TBoss4DLogLevel.Info, 'Project Build',
      '[' + LPhase + '] ' + AEvent.PackageName + ': ' + AEvent.Message);
end;

procedure TFormMain.FinishProjectInstall(const AError,
  AProjectDirectory: string);
begin
  if (FOperationKind = OperationProjectRebuild) and
     (TInterlocked.CompareExchange(FCancelRequested, 0, 0) <> 0) then
  begin
    FOperationPresenter.Cancel(GetTickCount64);
    LogStructured(TBoss4DLogLevel.Warning, 'Project Build',
      'Rebuild cancelado pelo usuario.');
  end
  else if not AError.IsEmpty then
  begin
    FOperationPresenter.Fail(AError, GetTickCount64);
    LogStructured(TBoss4DLogLevel.Error, 'Project Build', AError);
  end
  else
  begin
    FOperationPresenter.Complete(GetTickCount64);
    LoadProjectDependencies(AProjectDirectory);
    LogStructured(TBoss4DLogLevel.Info, 'Project Build',
      'Operacao de projeto concluida.');
  end;
  UpdateOperationUI;
end;

procedure TFormMain.RunAsyncCommand(const ATitle, ACommand: string; const AArgs: string);
begin
  if FCurrentProjectDir = '' then
  begin
    ShowMessage('Por favor, selecione a pasta do projeto local primeiro!');
    Exit;
  end;

  if SameText(ACommand, 'install') then
  begin
    if FOperationPresenter.State = GUIRunning then
    begin
      ShowMessage('Aguarde ou cancele a operacao atual.');
      Exit;
    end;
    FOperationKind := OperationProjectInstall;
    FOperationTitle := ATitle;
    FOperationPresenter.Start(GetTickCount64);
    ProgressOperation.Style := pbstMarquee;
    ProgressOperation.Position := 0;
    UpdateOperationUI;
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
      LError: string;
    begin
      LError := '';
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
            LInstallService.SetProgressReporter(
              TBoss4DGUIProgressReporter.Create(
                procedure(const AEvent: TBoss4DProgressEvent)
                begin
                  QueueProjectProgress(AEvent);
                end));
            TDirectory.SetCurrentDirectory(FCurrentProjectDir);
            LInstallService.Execute(AArgs);
            LogMessage('Comando finalizado com sucesso: ' + ATitle);
            TThread.Queue(nil,
              TThreadProcedure(
                procedure
                begin
                  FinishProjectInstall('', FCurrentProjectDir);
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
        begin
          LError := E.Message;
          LogMessage('[FALHA] Erro ao executar ' + ATitle + ': ' + E.Message);
          if SameText(ACommand, 'install') then
            TThread.Queue(nil,
              procedure
              begin
                FinishProjectInstall(LError, FCurrentProjectDir);
              end);
        end;
      end;
    end
  );
end;

function TFormMain.FindBoss4DExecutable: string;
var
  LBuffer: array[0..MAX_PATH] of Char;
  LLength: DWORD;
  LFilePart: PChar;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'boss4d.exe');
  if TFile.Exists(Result) then
    Exit;
  LFilePart := nil;
  LLength := Winapi.Windows.SearchPath(nil, 'boss4d.exe', nil,
    Length(LBuffer), LBuffer, LFilePart);
  if (LLength > 0) and (LLength < Length(LBuffer)) then
    SetString(Result, LBuffer, LLength)
  else
    Result := '';
end;

procedure TFormMain.RunAsyncGuidedInstall(
  const ARequest: TBoss4DGUIInstallRequest);
var
  LExecutable: string;
  LProjectDirectory: string;
  LRequest: TBoss4DGUIInstallRequest;
begin
  if FOperationPresenter.State = GUIRunning then
  begin
    ShowMessage('Aguarde ou cancele a operacao atual.');
    Exit;
  end;
  if FCurrentProjectDir = '' then
  begin
    ShowMessage('Por favor, selecione a pasta do projeto local primeiro!');
    Exit;
  end;
  LExecutable := FindBoss4DExecutable;
  if LExecutable = '' then
  begin
    ShowMessage('boss4d.exe nao foi encontrado ao lado da GUI ou no PATH.');
    Exit;
  end;
  LProjectDirectory := FCurrentProjectDir;
  LRequest := ARequest;
  FLastInstallRequest := ARequest;
  FHasLastInstallRequest := True;
  FOperationKind := OperationRegistryInstall;
  FOperationTitle := 'Instalando pacote';
  TInterlocked.Exchange(FCancelRequested, 0);
  FOperationPresenter.Start(GetTickCount64);
  ProgressOperation.Style := pbstMarquee;
  ProgressOperation.Position := 0;
  UpdateOperationUI;
  LogMessage('Iniciando: ' +
    TBoss4DGUIInstallPresenter.BuildEquivalentCommand(LRequest));
  TTask.Run(
    procedure
    var
      LExecutor: TBoss4DGUIInstallExecutor;
      LOutput: string;
      LError: string;
      LCancelled: Boolean;
    begin
      LCancelled := False;
      LError := '';
      LExecutor := TBoss4DGUIInstallExecutor.Create(
        TBoss4DGUIWindowsProcessRunner.Create);
      try
        try
          LOutput := LExecutor.Execute(LExecutable,
            LProjectDirectory, LRequest,
            function: Boolean
            begin
              Result := TInterlocked.CompareExchange(
                FCancelRequested, 0, 0) <> 0;
            end,
            LCancelled);
        except
          on E: Exception do
            LError := E.Message;
        end;
      finally
        LExecutor.Free;
      end;
      TThread.Queue(nil,
        TThreadProcedure(
          procedure
          begin
            FinishGuidedInstall(LCancelled, LOutput, LError,
              LProjectDirectory);
          end
        )
      );
    end
  );
end;

procedure TFormMain.QueueIDETargetProgress(
  const AEvent: TBoss4DBuildTargetProgressEvent);
var
  LEvent: TBoss4DBuildTargetProgressEvent;
begin
  LEvent := AEvent;
  TThread.Queue(nil,
    procedure
    begin
      HandleIDETargetProgress(LEvent);
    end);
end;

procedure TFormMain.HandleIDETargetProgress(
  const AEvent: TBoss4DBuildTargetProgressEvent);
begin
  var LRow := TBoss4DGUITargetProgress.FromBuildEvent(AEvent);
  ProgressOperation.Style := pbstNormal;
  ProgressOperation.Min := 0;
  ProgressOperation.Max := LRow.Total;
  ProgressOperation.Position := LRow.Current;
  LblOperation.Caption := Format('%s - %d/%d (%d%%) - %s',
    [FOperationTitle, LRow.Current, LRow.Total, LRow.Percentage,
     LRow.TargetIdentity]);
  if LRow.IsFailure then
    LogStructured(TBoss4DLogLevel.Error, 'IDE Build',
      LRow.TargetIdentity + ' [' + LRow.State + '] ' + LRow.Message)
  else
    LogStructured(TBoss4DLogLevel.Info, 'IDE Build',
      LRow.TargetIdentity + ' [' + LRow.State + '] ' + LRow.Message);
end;

procedure TFormMain.RunAsyncIDEInstall(
  const ARequest: TBoss4DGUIIDEInstallRequest);
var
  LRequest: TBoss4DGUIIDEInstallRequest;
begin
  if FOperationPresenter.State = GUIRunning then
  begin
    ShowMessage('Aguarde ou cancele a operacao atual.');
    Exit;
  end;
  LRequest := ARequest;
  FLastIDEInstallRequest := ARequest;
  FHasLastIDEInstallRequest := True;
  FOperationKind := OperationIDEInstall;
  FOperationTitle := 'Instalando ' + ARequest.PackageName;
  TInterlocked.Exchange(FCancelRequested, 0);
  FOperationPresenter.Start(GetTickCount64);
  ProgressOperation.Style := pbstNormal;
  ProgressOperation.Min := 0;
  ProgressOperation.Max := Length(ARequest.Targets);
  ProgressOperation.Position := 0;
  PanelIDEActions.Enabled := False;
  FIDEOperations.TargetProgress :=
    procedure(const AEvent: TBoss4DBuildTargetProgressEvent)
    begin
      QueueIDETargetProgress(AEvent);
    end;
  FIDEOperations.BuildCancellation :=
    function: Boolean
    begin
      Result := TInterlocked.CompareExchange(
        FCancelRequested, 0, 0) <> 0;
    end;
  UpdateOperationUI;
  LogStructured(TBoss4DLogLevel.Info, 'IDE Build',
    'Iniciando ' + ARequest.PackageName + ' em ' +
    ARequest.ProfileName + ' com ' +
    Length(ARequest.Targets).ToString + ' target(s).');
  TTask.Run(
    procedure
    var
      LAffected: Integer;
      LError: string;
      LCancelled: Boolean;
    begin
      LAffected := 0;
      LError := '';
      LCancelled := False;
      try
        LAffected := FIDEBackend.Install(LRequest.ProfileId,
          LRequest.PackageName, LRequest.ConflictPolicy,
          LRequest.OpenPolicy);
      except
        on E: Exception do
        begin
          LCancelled := TInterlocked.CompareExchange(
            FCancelRequested, 0, 0) <> 0;
          if not LCancelled then
            LError := E.Message;
        end;
      end;
      TThread.Queue(nil,
        procedure
        begin
          FinishIDEInstall(LRequest, LAffected, LError, LCancelled);
        end);
    end);
end;

procedure TFormMain.FinishIDEInstall(
  const ARequest: TBoss4DGUIIDEInstallRequest;
  const AAffected: Integer; const AError: string;
  const ACancelled: Boolean);
begin
  FIDEOperations.TargetProgress := nil;
  FIDEOperations.BuildCancellation := nil;
  PanelIDEActions.Enabled := True;
  if ACancelled then
  begin
    FOperationPresenter.Cancel(GetTickCount64);
    LogStructured(TBoss4DLogLevel.Warning, 'IDE Build',
      'Instalacao cancelada pelo usuario.');
    ShowIDEStatus('Instalacao de componente cancelada.');
  end
  else if not AError.IsEmpty then
  begin
    FOperationPresenter.Fail(AError, GetTickCount64);
    LogStructured(TBoss4DLogLevel.Error, 'IDE Build', AError);
    ShowIDEError(AError);
  end
  else
  begin
    FOperationPresenter.Complete(GetTickCount64);
    ProgressOperation.Position := ProgressOperation.Max;
    LogStructured(TBoss4DLogLevel.Info, 'IDE Build',
      Format('Instalacao concluida: %d registro(s) afetado(s).',
        [AAffected]));
    FIDEPresenter.ChooseProfile(ARequest.ProfileId);
    ShowIDEStatus(Format(
      'Instalacao concluida: %d registro(s) afetado(s).',
      [AAffected]));
  end;
  UpdateOperationUI;
end;

procedure TFormMain.FinishGuidedInstall(const ACancelled: Boolean;
  const AOutput, AError, AProjectDirectory: string);
begin
  if AOutput <> '' then
    LogMessage(AOutput);
  if ACancelled then
  begin
    FOperationPresenter.Cancel(GetTickCount64);
    LogMessage('Instalacao cancelada pelo usuario.');
  end
  else if AError <> '' then
  begin
    FOperationPresenter.Fail(AError, GetTickCount64);
    LogMessage('[ERRO] ' + AError);
  end
  else
  begin
    FOperationPresenter.Complete(GetTickCount64);
    LogMessage('Instalacao guiada concluida com sucesso.');
    LoadProjectDependencies(AProjectDirectory);
  end;
  UpdateOperationUI;
end;

procedure TFormMain.UpdateOperationUI;
var
  LState: string;
begin
  case FOperationPresenter.State of
    GUIIdle: LState := 'Nenhuma operacao';
    GUIRunning: LState := Format('%s (tentativa %d) - %s',
      [FOperationTitle, FOperationPresenter.Attempt,
       FOperationPresenter.ElapsedText(GetTickCount64)]);
    GUISucceeded: LState := 'Instalacao concluida - ' +
      FOperationPresenter.ElapsedText(GetTickCount64);
    GUIFailed: LState := 'Instalacao falhou - ' +
      FOperationPresenter.ElapsedText(GetTickCount64);
    GUICancelled: LState := 'Instalacao cancelada - ' +
      FOperationPresenter.ElapsedText(GetTickCount64);
  else
    LState := '';
  end;
  LblOperation.Caption := LState;
  ProgressOperation.Visible := FOperationPresenter.State = GUIRunning;
  BtnCancelOperation.Enabled := FOperationPresenter.CanCancel and
    (FOperationKind <> OperationProjectInstall);
  BtnRetryOperation.Enabled := FOperationPresenter.CanRetry and
    (((FOperationKind = OperationRegistryInstall) and
      FHasLastInstallRequest) or
     ((FOperationKind = OperationIDEInstall) and
      FHasLastIDEInstallRequest));
  TimerOperation.Enabled := FOperationPresenter.State = GUIRunning;
end;

procedure TFormMain.BtnCancelOperationClick(Sender: TObject);
begin
  if FOperationPresenter.CanCancel then
  begin
    TInterlocked.Exchange(FCancelRequested, 1);
    BtnCancelOperation.Enabled := False;
    LblOperation.Caption := 'Cancelando operacao...';
  end;
end;

procedure TFormMain.BtnRetryOperationClick(Sender: TObject);
begin
  if not FOperationPresenter.CanRetry then
    Exit;
  case FOperationKind of
    OperationRegistryInstall:
      if FHasLastInstallRequest then
        RunAsyncGuidedInstall(FLastInstallRequest);
    OperationIDEInstall:
      if FHasLastIDEInstallRequest then
        RunAsyncIDEInstall(FLastIDEInstallRequest);
  end;
end;

procedure TFormMain.TimerOperationTimer(Sender: TObject);
begin
  UpdateOperationUI;
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
begin
  if ListCatalog.Selected = nil then
  begin
    ShowMessage('Por favor, selecione um pacote do catalogo para instalar!');
    Exit;
  end;

  var LIndex := ListCatalog.Selected.Index;
  if LIndex >= Length(FCatalogRows) then
    Exit;
  var LRequest := Default(TBoss4DGUIInstallRequest);
  if TBoss4DGUIInstallDialog.Execute(Self, FCatalogRows[LIndex].Name,
    FCatalogRows[LIndex].InstallVersions, LRequest) then
    RunAsyncGuidedInstall(LRequest);
end;

procedure TFormMain.BtnDocCheckClick(Sender: TObject);
begin
  RunHealthCheck(False);
end;

procedure TFormMain.BtnDocFixClick(Sender: TObject);
begin
  RunHealthCheck(True);
end;

procedure TFormMain.RunHealthCheck(const AFix: Boolean);
var
  LFix: Boolean;
  LProjectDirectory: string;
  LProfileId: string;
begin
  LFix := AFix;
  LProjectDirectory := FCurrentProjectDir;
  LProfileId := FIDEPresenter.SelectedProfile;
  ListDoctorHealth.Items.Clear;
  if LFix then
    LblDocSummary.Caption := 'Aplicando correcoes e verificando...'
  else
    LblDocSummary.Caption := 'Verificando ambiente...';
  BtnDocCheck.Enabled := False;
  BtnDocFix.Enabled := False;
  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LRegistry: IBoss4DRegistryService;
      LService: TBoss4DDoctorService;
      LReport: TBoss4DDoctorReport;
      LRows: TArray<TBoss4DGUIHealthRow>;
      LSummary: string;
      LError: string;
      LPackageRepository: IBoss4DPackageRepository;
      LPackage: TBoss4DPackage;
      LBuildDoctor: TBoss4DBuildDoctor;
      LBuildReport: TBoss4DBuildDoctorResult;
    begin
      LError := '';
      LLogger := TGUILogger.Create(Self);
      LRegistry := TBoss4DWindowsRegistryAdapter.Create;
      LService := TBoss4DDoctorService.Create(LRegistry, LLogger);
      try
        try
          LReport := LService.Diagnose(LFix);
          try
            LRows := TBoss4DGUIHealthPresenter.BuildRows(LReport);
            LSummary := TBoss4DGUIHealthPresenter.Summarize(LReport).Text;
          finally
            LReport.Free;
          end;
          if not LProjectDirectory.IsEmpty and
             TFile.Exists(TPath.Combine(
            LProjectDirectory, 'boss.json')) then
          begin
            LPackageRepository := TBoss4DPackageJsonRepository.Create;
            LPackage := LPackageRepository.Load(TPath.Combine(
              LProjectDirectory, 'boss.json'));
            try
              LBuildDoctor := TBoss4DBuildDoctor.Create(LRegistry,
                function: TArray<string>
                begin
                  if LProfileId.IsEmpty then
                    Result := nil
                  else
                    Result := FIDEOperations.FindDrift(LProfileId);
                end);
              try
                LBuildReport := LBuildDoctor.Diagnose(
                  LPackage, LProjectDirectory);
                try
                  LRows := TBoss4DGUIHealthPresenter.AppendBuildRows(
                    LRows, LBuildReport);
                  LSummary := LSummary + Format(
                    '; projeto/build: %d diagnostico(s)',
                    [LBuildReport.Issues.Count]);
                finally
                  LBuildReport.Free;
                end;
              finally
                LBuildDoctor.Free;
              end;
            finally
              LPackage.Free;
            end;
          end;
        except
          on E: Exception do
            LError := E.Message;
        end;
      finally
        LService.Free;
      end;
      TThread.Queue(nil,
        TThreadProcedure(
          procedure
          begin
            BtnDocCheck.Enabled := True;
            BtnDocFix.Enabled := True;
            if LError <> '' then
            begin
              LblDocSummary.Caption := 'Falha no diagnostico: ' + LError;
              LogMessage('[ERRO] ' + LError);
            end
            else
              PopulateHealth(LRows, LSummary);
          end
        )
      );
    end
  );
end;

procedure TFormMain.PopulateHealth(
  const ARows: TArray<TBoss4DGUIHealthRow>; const ASummary: string);
begin
  FHealthRows := Copy(ARows);
  ListDoctorHealth.Items.BeginUpdate;
  try
    ListDoctorHealth.Items.Clear;
    for var LRow in ARows do
    begin
      var LItem := ListDoctorHealth.Items.Add;
      LItem.Caption := LRow.Group;
      LItem.SubItems.Add(LRow.Status);
      LItem.SubItems.Add(LRow.Code);
      LItem.SubItems.Add(LRow.Message);
      LItem.SubItems.Add(LRow.Remediation);
      LItem.SubItems.Add(LRow.ActionLabel);
    end;
    LblDocSummary.Caption := ASummary;
  finally
    ListDoctorHealth.Items.EndUpdate;
  end;
  UpdateHealthActions;
end;

procedure TFormMain.ListDoctorHealthSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  UpdateHealthActions;
end;

procedure TFormMain.UpdateHealthActions;
begin
  BtnDocRebuild.Enabled := False;
  BtnDocReregister.Enabled := False;
  if not Assigned(ListDoctorHealth.Selected) or
     (ListDoctorHealth.Selected.Index >= Length(FHealthRows)) then
    Exit;
  case FHealthRows[ListDoctorHealth.Selected.Index].Action of
    HealthActionRebuild: BtnDocRebuild.Enabled := True;
    HealthActionReregister: BtnDocReregister.Enabled := True;
  end;
end;

procedure TFormMain.BtnDocRepairIDEClick(Sender: TObject);
begin
  FIDEPresenter.Repair;
end;

procedure TFormMain.BtnDocUndoIDEClick(Sender: TObject);
begin
  FIDEPresenter.Undo;
end;

procedure TFormMain.BtnDocOptimizeCacheClick(Sender: TObject);
begin
  BtnCachePruneClick(Sender);
end;

procedure TFormMain.BtnDocRebuildClick(Sender: TObject);
begin
  RunAsyncProjectRebuild;
end;

procedure TFormMain.BtnDocReregisterClick(Sender: TObject);
begin
  if not Assigned(ListDoctorHealth.Selected) or
     (ListDoctorHealth.Selected.Index >= Length(FHealthRows)) then
    Exit;
  var LRow := FHealthRows[ListDoctorHealth.Selected.Index];
  if (LRow.Action <> HealthActionReregister) or
     LRow.ActionTarget.IsEmpty then
    Exit;
  if FIDEPresenter.SelectedProfile.IsEmpty then
  begin
    ShowMessage('Selecione um perfil IDE antes de registrar novamente.');
    Exit;
  end;
  if MessageDlg('Registrar novamente apenas o target ' +
    LRow.ActionTarget + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  try
    var LAffected := FIDEBackend.RepairTarget(
      FIDEPresenter.SelectedProfile, LRow.ActionTarget);
    ShowIDEStatus(Format(
      'Novo registro exato concluido: %d alteracao(oes).',
      [LAffected]));
    RunHealthCheck(False);
  except
    on E: Exception do
      ShowIDEError(E.Message);
  end;
end;

procedure TFormMain.RunAsyncProjectRebuild;
var
  LProjectDirectory: string;
begin
  if FCurrentProjectDir.IsEmpty then
  begin
    ShowMessage('Selecione a pasta do projeto antes do rebuild.');
    Exit;
  end;
  if FOperationPresenter.State = GUIRunning then
  begin
    ShowMessage('Aguarde ou cancele a operacao atual.');
    Exit;
  end;
  LProjectDirectory := FCurrentProjectDir;
  FOperationKind := OperationProjectRebuild;
  FOperationTitle := 'Rebuild completo';
  TInterlocked.Exchange(FCancelRequested, 0);
  FOperationPresenter.Start(GetTickCount64);
  ProgressOperation.Style := pbstMarquee;
  ProgressOperation.Position := 0;
  UpdateOperationUI;
  TTask.Run(
    procedure
    var
      LLogger: IBoss4DLogger;
      LRegistry: IBoss4DRegistryService;
      LCompiler: IBoss4DCompiler;
      LPackageRepository: IBoss4DPackageRepository;
      LLockRepository: IBoss4DLockRepository;
      LInventory: TBoss4DBuildInventory;
      LCoordinator: TBoss4DBuildCoordinator;
      LOptions: TBoss4DBuildCommandOptions;
      LError: string;
    begin
      LError := '';
      try
        LLogger := TGUILogger.Create(Self);
        LRegistry := TBoss4DWindowsRegistryAdapter.Create;
        LCompiler := TBoss4DDelphiCompilerAdapter.Create(
          LRegistry, LLogger);
        LPackageRepository := TBoss4DPackageJsonRepository.Create;
        LLockRepository := TBoss4DLockJsonRepository.Create;
        LInventory := TBoss4DBuildInventory.Create(TPath.Combine(
          GetBossHome, 'build-inventory.json'));
        try
          LInventory.Load;
          LCoordinator := TBoss4DBuildCoordinator.Create(
            LCompiler, LLogger, LPackageRepository, LLockRepository,
            nil, LInventory);
          try
            LOptions := Default(TBoss4DBuildCommandOptions);
            LOptions.Force := True;
            LOptions.Jobs := 1;
            LOptions.Cancellation :=
              function: Boolean
              begin
                Result := TInterlocked.CompareExchange(
                  FCancelRequested, 0, 0) <> 0;
              end;
            LOptions.TargetProgress :=
              procedure(
                const AEvent: TBoss4DBuildTargetProgressEvent)
              begin
                var LPhase := TBoss4DProgressPhase.Compiling;
                if AEvent.State = TargetFailed then
                  LPhase := TBoss4DProgressPhase.Failed;
                QueueProjectProgress(TBoss4DProgressEvent.Create(
                  'project-rebuild', 'projeto', LPhase,
                  AEvent.Current, AEvent.Total,
                  AEvent.TargetIdentity + ': ' + AEvent.Message));
              end;
            LCoordinator.Execute(LProjectDirectory, LOptions);
          finally
            LCoordinator.Free;
          end;
        finally
          LInventory.Free;
        end;
      except
        on E: Exception do
          LError := E.Message;
      end;
      TThread.Queue(nil,
        procedure
        begin
          FinishProjectInstall(LError, LProjectDirectory);
        end);
    end);
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

procedure TFormMain.ShowHistory(
  const ARows: TArray<TBoss4DGUITimelineRow>);
begin
  var LOperationId := TBoss4DGUITimelineDialog.Execute(Self, ARows);
  if not LOperationId.IsEmpty and
     (MessageDlg(
       'Restaurar o estado anterior a esta operacao? ' +
       'Um snapshot de seguranca sera criado antes do rollback.',
       mtConfirmation, [mbYes, mbNo], 0) = mrYes) then
    FIDEPresenter.Rollback(LOperationId);
end;

procedure TFormMain.ShowDashboard(
  const ARows: TArray<TBoss4DGUIProfileDashboardRow>);
begin
  var LProfileId := TBoss4DGUIProfileDashboardDialog.Execute(
    Self, ARows);
  if not LProfileId.IsEmpty then
  begin
    FIDEPresenter.ChooseProfile(LProfileId);
    FIDEPresenter.Launch;
  end;
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

procedure TFormMain.BtnIDEDashboardClick(Sender: TObject);
begin
  FIDEPresenter.Dashboard;
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
  var LRequest := Default(TBoss4DGUIIDEInstallRequest);
  if TBoss4DGUIIDEInstallDialog.Execute(Self, FIDEBackend,
    FIDEPresenter.SelectedProfile, SelectedIDEPackage,
    LConflictPolicy, LOpenPolicy, LRequest) then
    RunAsyncIDEInstall(LRequest);
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

procedure TFormMain.BtnIDEHistoryClick(Sender: TObject);
begin
  FIDEPresenter.History;
end;

procedure TFormMain.BtnIDESnapshotClick(Sender: TObject);
begin
  var LDialog := TSaveDialog.Create(Self);
  try
    LDialog.Filter := 'Boss4D profile snapshot|*.json';
    LDialog.DefaultExt := 'json';
    if LDialog.Execute then FIDEPresenter.Snapshot(LDialog.FileName);
  finally
    LDialog.Free;
  end;
end;

procedure TFormMain.BtnIDEDiffClick(Sender: TObject);
begin
  var LDialog := TOpenDialog.Create(Self);
  try
    LDialog.Filter := 'Boss4D profile snapshot|*.json';
    if LDialog.Execute then FIDEPresenter.Diff(LDialog.FileName);
  finally
    LDialog.Free;
  end;
end;

procedure TFormMain.BtnIDERestoreSnapshotClick(Sender: TObject);
begin
  var LDialog := TOpenDialog.Create(Self);
  try
    LDialog.Filter := 'Boss4D profile snapshot|*.json';
    if LDialog.Execute and
       (MessageDlg('Restaurar este snapshot de perfil?',
        mtConfirmation, [mbYes, mbNo], 0) = mrYes) then
      FIDEPresenter.RestoreSnapshot(LDialog.FileName);
  finally
    LDialog.Free;
  end;
end;

end.
