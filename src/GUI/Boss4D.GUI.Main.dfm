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
          Height = 360
          Align = alClient
          Columns = <
            item
              Caption = 'Nome do Pacote'
              Width = 250
            end
            item
              Caption = 'Repositorio GitHub'
              Width = 400
            end>
          GridLines = True
          ReadOnly = True
          RowSelect = True
          ViewStyle = vsReport
          TabOrder = 1
        end
      end
      object TabDoctor: TTabSheet
        Caption = 'Doctor'
        ImageIndex = 2
        object PanelDocTop: TPanel
          Left = 0
          Top = 0
          Width = 689
          Height = 60
          Align = alTop
          BevelOuter = bvNone
          TabOrder = 0
          object BtnDocCheck: TButton
            Left = 10
            Top = 15
            Width = 150
            Height = 30
            Caption = 'Rodar Diagnostico'
            TabOrder = 0
            OnClick = BtnDocCheckClick
          end
          object BtnDocFix: TButton
            Left = 170
            Top = 15
            Width = 150
            Height = 30
            Caption = 'Corrigir Ambiente'
            TabOrder = 1
            OnClick = BtnDocFixClick
          end
        end
        object MemoDoctor: TMemo
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
    object MemoLogs: TMemo
      Left = 0
      Top = 0
      Width = 900
      Height = 147
      Align = alClient
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
end
