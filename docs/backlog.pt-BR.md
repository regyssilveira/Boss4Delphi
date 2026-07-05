# Backlog de Desenvolvimento do Boss4D

Este documento detalha o planejamento futuro, as novas funcionalidades (backlog) e a evolução arquitetônica do **Boss4D**, com base no feedback da comunidade e nas melhores práticas do ecossistema Delphi (inspirado nas ferramentas como o *TMS Smart Setup*).

---

## 🗺️ Épico 1: Interface Visual (Boss4D GUI)
*Objetivo: Oferecer uma alternativa visual e amigável para desenvolvedores que preferem não utilizar a linha de comando.*

- [ ] **[Story] Interface Desktop Nativa (VCL / FMX)**
  - Criar um executável visual standalone (`boss4d-gui.exe`) em Delphi nativo para gerenciar projetos.
- [ ] **[Story] Gerenciamento de Projetos e Dependências**
  - Tela para abrir pastas de projetos Delphi, visualizar o manifesto `boss.json` atual e gerenciar pacotes.
- [ ] **[Story] Catálogo e Busca de Pacotes Públicos**
  - Criar um painel de descoberta de pacotes populares (ex: Horse, Dext, RESTRequest4Delphi, mORMot) permitindo instalação com um clique.
- [ ] **[Story] Painel de Logs de Compilação Visual**
  - Exibir o andamento das tarefas de download concorrentes e logs de compilação em componentes visuais ricos com progresso e alertas.

---

## 🔌 Épico 2: Integração com RAD Studio IDE (Plugin / Wizard)
*Objetivo: Integrar o gerenciador de dependências diretamente no fluxo de trabalho do desenvolvedor dentro do RAD Studio.*

- [ ] **[Story] Menu de Contexto no Project Manager**
  - Adicionar as opções "Boss4D Init" e "Boss4D Install" no clique direito do gerenciador de projetos da IDE do Delphi.
- [ ] **[Story] IDE Package Manager Wizard**
  - Criar um Wizard interno (Plugin via ToolsAPI do Delphi) para buscar e gerenciar pacotes diretamente de dentro da IDE.
- [ ] **[Story] Atalhos de Teclado e Atalho de Build**
  - Sincronizar o build de dependências com as teclas de atalho de compilação nativas da IDE.

---

## 🩺 Épico 3: Ferramenta de Auto-Diagnóstico (`boss4d doctor`)
*Objetivo: Identificar e corrigir problemas de caminhos de compilador, variáveis de ambiente e ferramentas Git locais de forma automatizada (Inspirado no `tms doctor`).*

- [ ] **[Story] Comando CLI `boss4d doctor`**
  - Analisar o ambiente da máquina física do desenvolvedor, verificando:
    * Instalações do Delphi ativas e caminhos no Registro.
    * Presença e versão do compilador `dcc32`, `dcc64` e `MSBuild`.
    * Acessibilidade ao executável `git` no PATH do sistema.
    * Permissões de escrita e leitura de pastas.
- [ ] **[Story] Auto-Correção de Caminhos (`boss4d doctor -fix`)**
  - Implementar a capacidade de injetar e corrigir caminhos no Registro ou no PATH local do usuário para reestabelecer o funcionamento da compilação de forma automática.

---

## ⚙️ Épico 4: Integração de Componentes e Library Paths na IDE
*Objetivo: Automatizar as tarefas de configuração manual pós-instalação de componentes de Design-Time na paleta de componentes do Delphi.*

- [ ] **[Story] Injeção e Registro de BPLs de Design-Time**
  - Analisar as dependências recém-baixadas, localizar as BPLs de Design-time geradas e registrá-las no registro do Windows do Delphi (`HKEY_CURRENT_USER\Software\Embarcadero\BDS\<versao>\Known Packages`) para que os componentes apareçam na paleta da IDE automaticamente.
- [ ] **[Story] Gerenciamento Automático de Library Paths da IDE**
  - Injetar de forma inteligente as pastas de DCU unificadas (`modules/dcu`) ou caminhos de busca no Library Path global do RAD Studio do desenvolvedor, eliminando a necessidade de configurar os caminhos manualmente após a instalação.
- [ ] **[Story] DCU Megafolders e Otimização de Cache**
  - Unificar de forma otimizada os arquivos compilados do projeto em pastas centralizadas por plataforma/configuração, melhorando o tempo de build subsequente.
