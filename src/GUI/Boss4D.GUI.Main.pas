unit Boss4D.GUI.Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Boss4D.Core.Ports, Boss4D.Core.Domain.Dependency, Boss4D.Core.Domain.Package;

type
  TFormMain = class(TForm)
    PanelSidebar: TPanel;
    BtnPageProject: TButton;
    BtnPageCatalog: TButton;
    BtnPageDoctor: TButton;
    BtnPageCache: TButton;
    Splitter1: TSplitter;
    PanelContent: TPanel;
    PageControlMain: TPageControl;
    TabProject: TTabSheet;
    TabCatalog: TTabSheet;
    TabDoctor: TTabSheet;
    TabCache: TTabSheet;
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
    PanelLogs: TPanel;
    MemoLogs: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure BtnPageProjectClick(Sender: TObject);
    procedure BtnPageCatalogClick(Sender: TObject);
    procedure BtnPageDoctorClick(Sender: TObject);
    procedure BtnPageCacheClick(Sender: TObject);
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
  private
    FCurrentProjectDir: string;
    procedure LoadProjectDependencies(const AProjectDir: string);
    procedure LogMessage(const AMessage: string);
    procedure PopulateCatalog;
    procedure RunAsyncCommand(const ATitle, ACommand: string; const AArgs: string = '');
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
  Boss4D.Core.Services.Outdated;

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
  PopulateCatalog;
  LogMessage('Boss4D GUI Inicializada com sucesso.');
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
  LPackages: TArray<TArray<string>>;
  I: Integer;
begin
  ListCatalog.Items.Clear;

  LPackages := [
    ['Horse', 'github.com/hashload/horse'],
    ['RESTRequest4Delphi', 'github.com/viniciussanchez/RESTRequest4Delphi'],
    ['mORMot', 'github.com/synopse/mORMot2'],
    ['Skia4Delphi', 'github.com/skia4delphi/skia4delphi'],
    ['Dext', 'github.com/regyssilveira/dext'],
    ['Boss4Delphi', 'github.com/regyssilveira/Boss4Delphi'],
    ['DataSet-Serialize', 'github.com/viniciussanchez/dataset-serialize']
  ];

  for I := 0 to Length(LPackages) - 1 do
  begin
    LItem := ListCatalog.Items.Add;
    LItem.Caption := LPackages[I][0];
    LItem.SubItems.Add(LPackages[I][1]);
  end;
end;

procedure TFormMain.EditSearchChange(Sender: TObject);
var
  LText: string;
  I: Integer;
  LItem: TListItem;
begin
  LText := Trim(EditSearch.Text);
  PopulateCatalog;
  if LText = '' then
    Exit;

  for I := ListCatalog.Items.Count - 1 downto 0 do
  begin
    LItem := ListCatalog.Items[I];
    if (not LItem.Caption.ToLower.Contains(LText.ToLower)) and
       (not LItem.SubItems[0].ToLower.Contains(LText.ToLower)) then
    begin
      LItem.Delete;
    end;
  end;
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

end.
