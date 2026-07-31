object FormMain: TFormMain
  Left = 0
  Top = 0
  Caption = 'Boss4D GUI - Gerenciador de Dependencias'
  ClientHeight = 600
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnCloseQuery = FormCloseQuery
  OnDestroy = FormDestroy
  TextHeight = 15
  object Splitter1: TSplitter
    Left = 200
    Top = 0
    Height = 450
    ExplicitLeft = 250
    ExplicitTop = 150
    ExplicitHeight = 100
  end
  object PanelSidebar: TPanel
    Left = 0
    Top = 0
    Width = 200
    Height = 450
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object BtnPageProject: TButton
      Left = 10
      Top = 20
      Width = 180
      Height = 40
      Caption = 'Projeto Local'
      TabOrder = 0
      OnClick = BtnPageProjectClick
    end
    object BtnPageCatalog: TButton
      Left = 10
      Top = 70
      Width = 180
      Height = 40
      Caption = 'Buscar Pacotes'
      TabOrder = 1
      OnClick = BtnPageCatalogClick
    end
    object BtnPageDoctor: TButton
      Left = 10
      Top = 120
      Width = 180
      Height = 40
      Caption = 'Boss4D Doctor'
      TabOrder = 2
      OnClick = BtnPageDoctorClick
    end
    object BtnPageCache: TButton
      Left = 10
      Top = 170
      Width = 180
      Height = 40
      Caption = 'Gerenciar Cache'
      TabOrder = 3
      OnClick = BtnPageCacheClick
    end
    object BtnPageIDE: TButton
      Left = 10
      Top = 220
      Width = 180
      Height = 40
      Caption = 'Componentes e IDEs'
      TabOrder = 4
      OnClick = BtnPageIDEClick
    end
  end
  object PanelContent: TPanel
    Left = 203
    Top = 0
    Width = 697
    Height = 450
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object PageControlMain: TPageControl
      Left = 0
      Top = 0
      Width = 697
      Height = 450
      ActivePage = TabProject
      Align = alClient
      TabOrder = 0
      object TabProject: TTabSheet
        Caption = 'Projeto'
        object PanelProjTop: TPanel
          Left = 0
          Top = 0
          Width = 689
          Height = 50
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object LblProjPath: TLabel
            Left = 10
            Top = 17
            Width = 108
            Height = 15
            Caption = 'Diretorio do Projeto:'
          end
          object EditProjPath: TEdit
            Left = 130
            Top = 13
            Width = 430
            Height = 23
            ReadOnly = True
            TabOrder = 0
          end
          object BtnSelectProj: TButton
            Left = 570
            Top = 12
            Width = 100
            Height = 25
            Caption = 'Selecionar...'
            TabOrder = 1
            OnClick = BtnSelectProjClick
          end
        end
        object ListDependencies: TListView
          Left = 0
          Top = 50
          Width = 689
          Height = 310
          Align = alClient
          Columns = <
            item
              Caption = 'Pacote / Dependencia'
              Width = 350
            end
            item
              Caption = 'Versao Declarada'
              Width = 150
            end
            item
              Caption = 'Versao Instalada (Lock)'
              Width = 150
            end>
          GridLines = True
          ReadOnly = True
          RowSelect = True
          ViewStyle = vsReport
          TabOrder = 1
        end
        object PanelProjBottom: TPanel
          Left = 0
          Top = 360
          Width = 689
          Height = 50
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 2
          object BtnProjInit: TButton
            Left = 10
            Top = 12
            Width = 100
            Height = 25
            Caption = 'Boss4D Init'
            TabOrder = 0
            OnClick = BtnProjInitClick
          end
          object BtnProjInstall: TButton
            Left = 120
            Top = 12
            Width = 100
            Height = 25
            Caption = 'Boss4D Install'
            TabOrder = 1
            OnClick = BtnProjInstallClick
          end
          object BtnProjOutdated: TButton
            Left = 230
            Top = 12
            Width = 110
            Height = 25
            Caption = 'Verificar Updates'
            TabOrder = 2
            OnClick = BtnProjOutdatedClick
          end
          object BtnProjTree: TButton
            Left = 350
            Top = 12
            Width = 110
            Height = 25
            Caption = 'Arvore de Modulos'
            TabOrder = 3
            OnClick = BtnProjTreeClick
          end
        end
      end
      object TabCatalog: TTabSheet
        Caption = 'Catalogo'
        ImageIndex = 1
        object PanelCatTop: TPanel
          Left = 0
          Top = 0
          Width = 689
          Height = 50
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object LblSearch: TLabel
            Left = 10
            Top = 17
            Width = 79
            Height = 15
            Caption = 'Buscar Pacote:'
          end
          object EditSearch: TEdit
            Left = 100
            Top = 13
            Width = 460
            Height = 23
            TabOrder = 0
            OnChange = EditSearchChange
          end
          object BtnInstallSelected: TButton
            Left = 570
            Top = 12
            Width = 100
            Height = 25
            Caption = 'Instalar'
            TabOrder = 1
            OnClick = BtnInstallSelectedClick
          end
        end
        object ListCatalog: TListView
          Left = 0
          Top = 50
          Width = 689
          Height = 235
          Align = alClient
          Columns = <
            item
              Caption = 'Nome do Pacote'
              Width = 180
            end
            item
              Caption = 'Versao'
              Width = 90
            end
            item
              Caption = 'Historico'
              Width = 150
            end
            item
              Caption = 'Repositorio GitHub'
              Width = 260
            end>
          GridLines = True
          ReadOnly = True
          RowSelect = True
          ViewStyle = vsReport
          TabOrder = 1
          OnSelectItem = ListCatalogSelectItem
        end
        object PanelCatalogDetails: TPanel
          Left = 0
          Top = 285
          Width = 689
          Height = 125
          Align = alBottom
          BevelOuter = bvNone
          Caption = ''
          TabOrder = 2
          object MemoCatalogDetails: TMemo
            Left = 0
            Top = 0
            Width = 689
            Height = 125
            Align = alClient
            ReadOnly = True
            ScrollBars = ssVertical
            TabOrder = 0
          end
        end
      end
      object TabDoctor: TTabSheet
        Caption = 'Doctor'
        ImageIndex = 2
        object PanelDocTop: TPanel
          Left = 0
          Top = 0
          Width = 689
          Height = 88
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object BtnDocCheck: TButton
            Left = 10
            Top = 10
            Width = 125
            Height = 30
            Caption = 'Rodar Diagnostico'
            TabOrder = 0
            OnClick = BtnDocCheckClick
          end
          object BtnDocFix: TButton
            Left = 142
            Top = 10
            Width = 125
            Height = 30
            Caption = 'Corrigir Ambiente'
            TabOrder = 1
            OnClick = BtnDocFixClick
          end
          object BtnDocRepairIDE: TButton
            Left = 274
            Top = 10
            Width = 125
            Height = 30
            Caption = 'Reparar IDE'
            TabOrder = 2
            OnClick = BtnDocRepairIDEClick
          end
          object BtnDocUndoIDE: TButton
            Left = 406
            Top = 10
            Width = 125
            Height = 30
            Caption = 'Desfazer IDE'
            TabOrder = 3
            OnClick = BtnDocUndoIDEClick
          end
          object BtnDocOptimizeCache: TButton
            Left = 538
            Top = 10
            Width = 125
            Height = 30
            Caption = 'Otimizar Cache'
            TabOrder = 4
            OnClick = BtnDocOptimizeCacheClick
          end
          object LblDocSummary: TLabel
            Left = 10
            Top = 56
            Width = 167
            Height = 15
            Caption = 'Diagnostico ainda nao executado'
          end
        end
        object ListDoctorHealth: TListView
          Left = 0
          Top = 88
          Width = 689
          Height = 322
          Align = alClient
          Columns = <
            item
              Caption = 'Grupo'
              Width = 90
            end
            item
              Caption = 'Estado'
              Width = 75
            end
            item
              Caption = 'Codigo'
              Width = 115
            end
            item
              Caption = 'Diagnostico'
              Width = 260
            end
            item
              Caption = 'Acao recomendada'
              Width = 300
            end>
          GridLines = True
          ReadOnly = True
          RowSelect = True
          TabOrder = 1
          ViewStyle = vsReport
        end
      end
      object TabCache: TTabSheet
        Caption = 'Cache'
        ImageIndex = 3
        object PanelCacheTop: TPanel
          Left = 0
          Top = 0
          Width = 689
          Height = 60
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object BtnCacheClean: TButton
            Left = 10
            Top = 15
            Width = 150
            Height = 30
            Caption = 'Limpar Tudo'
            TabOrder = 0
            OnClick = BtnCacheCleanClick
          end
          object BtnCachePrune: TButton
            Left = 170
            Top = 15
            Width = 150
            Height = 30
            Caption = 'Otimizar Cache'
            TabOrder = 1
            OnClick = BtnCachePruneClick
          end
        end
        object MemoCache: TMemo
          Left = 0
          Top = 60
          Width = 689
          Height = 350
          Align = alClient
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 1
        end
      end
      object TabIDE: TTabSheet
        Caption = 'Componentes e IDEs'
        ImageIndex = 4
        object PanelIDEProfile: TPanel
          Left = 0
          Top = 0
          Width = 689
          Height = 130
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object ComboIDEProfiles: TComboBox
            Left = 8
            Top = 8
            Width = 300
            Height = 23
            Style = csDropDownList
            TabOrder = 0
            OnChange = ComboIDEProfilesChange
          end
          object BtnIDERefresh: TButton
            Left = 316
            Top = 7
            Width = 72
            Height = 25
            Caption = 'Atualizar'
            TabOrder = 1
            OnClick = BtnIDERefreshClick
          end
          object BtnIDECreateProfile: TButton
            Left = 8
            Top = 39
            Width = 88
            Height = 25
            Caption = 'Novo perfil'
            TabOrder = 2
            OnClick = BtnIDECreateProfileClick
          end
          object BtnIDECloneProfile: TButton
            Left = 102
            Top = 39
            Width = 88
            Height = 25
            Caption = 'Clonar'
            TabOrder = 3
            OnClick = BtnIDECloneProfileClick
          end
          object BtnIDERemoveProfile: TButton
            Left = 196
            Top = 39
            Width = 88
            Height = 25
            Caption = 'Remover'
            TabOrder = 4
            OnClick = BtnIDERemoveProfileClick
          end
          object BtnIDELaunch: TButton
            Left = 290
            Top = 39
            Width = 98
            Height = 25
            Caption = 'Abrir IDE'
            TabOrder = 5
            OnClick = BtnIDELaunchClick
          end
          object BtnIDEDashboard: TButton
            Left = 400
            Top = 39
            Width = 120
            Height = 25
            Caption = 'Dashboard'
            TabOrder = 12
            OnClick = BtnIDEDashboardClick
          end
          object LblIDEStatus: TLabel
            Left = 400
            Top = 12
            Width = 270
            Height = 23
            AutoSize = False
            Caption = 'Pronto.'
            WordWrap = True
          end
          object LblIDETarget: TLabel
            Left = 8
            Top = 77
            Width = 76
            Height = 15
            Caption = 'Target padrao:'
          end
          object ComboIDETargetPlatform: TComboBox
            Left = 90
            Top = 72
            Width = 100
            Height = 23
            Style = csDropDownList
            ItemIndex = 0
            TabOrder = 6
            Text = 'Win32'
            Items.Strings = (
              'Win32'
              'Win64'
              'Linux64')
          end
          object ComboIDETargetConfiguration: TComboBox
            Left = 196
            Top = 72
            Width = 100
            Height = 23
            Style = csDropDownList
            ItemIndex = 1
            TabOrder = 7
            Text = 'Release'
            Items.Strings = (
              'Debug'
              'Release')
          end
          object BtnIDESaveTarget: TButton
            Left = 302
            Top = 71
            Width = 86
            Height = 25
            Caption = 'Aplicar target'
            TabOrder = 8
            OnClick = BtnIDESaveTargetClick
          end
          object BtnIDESnapshot: TButton
            Left = 400
            Top = 71
            Width = 82
            Height = 25
            Caption = 'Snapshot'
            TabOrder = 9
            OnClick = BtnIDESnapshotClick
          end
          object BtnIDEDiff: TButton
            Left = 488
            Top = 71
            Width = 82
            Height = 25
            Caption = 'Comparar'
            TabOrder = 10
            OnClick = BtnIDEDiffClick
          end
          object BtnIDERestoreSnapshot: TButton
            Left = 576
            Top = 71
            Width = 98
            Height = 25
            Caption = 'Restaurar'
            TabOrder = 11
            OnClick = BtnIDERestoreSnapshotClick
          end
        end
        object PanelIDEActions: TPanel
          Left = 0
          Top = 295
          Width = 689
          Height = 75
          Align = alBottom
          BevelOuter = bvNone
          TabOrder = 1
          object BtnIDEPreviewInstall: TButton
            Left = 8
            Top = 39
            Width = 105
            Height = 28
            Caption = 'Preview instalar'
            TabOrder = 0
            OnClick = BtnIDEPreviewInstallClick
          end
          object BtnIDEInstall: TButton
            Left = 119
            Top = 39
            Width = 82
            Height = 28
            Caption = 'Instalar'
            TabOrder = 1
            OnClick = BtnIDEInstallClick
          end
          object BtnIDERepair: TButton
            Left = 207
            Top = 39
            Width = 82
            Height = 28
            Caption = 'Reparar'
            TabOrder = 2
            OnClick = BtnIDERepairClick
          end
          object BtnIDEPreviewRemove: TButton
            Left = 295
            Top = 39
            Width = 105
            Height = 28
            Caption = 'Preview remover'
            TabOrder = 3
            OnClick = BtnIDEPreviewRemoveClick
          end
          object BtnIDERemove: TButton
            Left = 406
            Top = 39
            Width = 82
            Height = 28
            Caption = 'Remover'
            TabOrder = 4
            OnClick = BtnIDERemoveClick
          end
          object BtnIDEUndo: TButton
            Left = 494
            Top = 39
            Width = 82
            Height = 28
            Caption = 'Desfazer'
            TabOrder = 5
            OnClick = BtnIDEUndoClick
          end
          object BtnIDEHistory: TButton
            Left = 582
            Top = 39
            Width = 82
            Height = 28
            Caption = 'Historico'
            TabOrder = 6
            OnClick = BtnIDEHistoryClick
          end
          object LblIDEConflictPolicy: TLabel
            Left = 8
            Top = 11
            Width = 51
            Height = 15
            Caption = 'Conflitos:'
          end
          object ComboIDEConflictPolicy: TComboBox
            Left = 64
            Top = 7
            Width = 105
            Height = 23
            Style = csDropDownList
            ItemIndex = 0
            TabOrder = 5
            Text = 'Falhar'
            Items.Strings = (
              'Falhar'
              'Avisar'
              'Adotar'
              'Substituir')
          end
          object LblIDEOpenPolicy: TLabel
            Left = 184
            Top = 11
            Width = 62
            Height = 15
            Caption = 'IDE aberta:'
          end
          object ComboIDEOpenPolicy: TComboBox
            Left = 252
            Top = 7
            Width = 105
            Height = 23
            Style = csDropDownList
            ItemIndex = 0
            TabOrder = 6
            Text = 'Falhar'
            Items.Strings = (
              'Falhar'
              'Adiar'
              'Forcar')
          end
        end
        object ListIDETargets: TListBox
          Left = 0
          Top = 370
          Width = 689
          Height = 40
          Align = alBottom
          ItemHeight = 15
          ScrollWidth = 1000
          TabOrder = 2
        end
        object ListIDEPackages: TListView
          Left = 0
          Top = 100
          Width = 689
          Height = 195
          Align = alClient
          Columns = <
            item
              Caption = 'Package'
              Width = 180
            end
            item
              Caption = 'Estado'
              Width = 90
            end
            item
              Caption = 'Raiz'
              Width = 380
            end>
          ReadOnly = True
          RowSelect = True
          TabOrder = 3
          ViewStyle = vsReport
        end
      end
    end
  end
  object PanelLogs: TPanel
    Left = 0
    Top = 453
    Width = 900
    Height = 147
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    object PanelOperation: TPanel
      Left = 0
      Top = 0
      Width = 900
      Height = 34
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object LblOperation: TLabel
        Left = 10
        Top = 10
        Width = 89
        Height = 15
        Caption = 'Nenhuma operacao'
      end
      object ProgressOperation: TProgressBar
        Left = 260
        Top = 8
        Width = 430
        Height = 18
        MarqueeInterval = 40
        Style = pbstMarquee
        TabOrder = 0
        Visible = False
      end
      object BtnCancelOperation: TButton
        Left = 700
        Top = 5
        Width = 90
        Height = 25
        Caption = 'Cancelar'
        Enabled = False
        TabOrder = 1
        OnClick = BtnCancelOperationClick
      end
      object BtnRetryOperation: TButton
        Left = 800
        Top = 5
        Width = 90
        Height = 25
        Caption = 'Tentar novamente'
        Enabled = False
        TabOrder = 2
        OnClick = BtnRetryOperationClick
      end
    end
    object MemoLogs: TMemo
      Left = 0
      Top = 34
      Width = 900
      Height = 113
      Align = alClient
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
    end
  end
  object TimerOperation: TTimer
    Enabled = False
    Interval = 500
    OnTimer = TimerOperationTimer
    Left = 824
    Top = 16
  end
end
