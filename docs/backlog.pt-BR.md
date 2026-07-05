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

---

## 📜 Épico 5: Execução de Scripts Customizados (`boss4d run <script>`)
*Objetivo: Permitir a automatização e padronização de tarefas e fluxos de trabalho nos projetos Delphi (Inspirado no `npm run` do Node.js).*

- [ ] **[Story] Declaração de Scripts no `boss.json`**
  - Adicionar suporte a um bloco `"scripts": { "build": "msbuild ...", "test": "Win32\\Debug\\Tests.exe" }` no manifesto do projeto.
- [ ] **[Story] Comando CLI `boss4d run <script>`**
  - Executar o script especificado invocando o subprocesso correto no shell do Windows e repassando logs e códigos de erro de saída de forma transparente.

---

## 🛠️ Épico 6: Distribuição de Ferramentas CLI Globais (`boss4d tool`)
*Objetivo: Permitir que desenvolvedores Delphi instalem e utilizem utilitários de desenvolvimento de forma global na máquina (Inspirado no `dotnet tool` do .NET).*

- [ ] **[Story] Instalação Global de Ferramentas (`boss4d tool install -g <repo>`)**
  - Baixar, compilar e registrar no PATH do Windows executáveis utilitários criados em Delphi (ex: formatadores de código, geradores de código, linters).
- [ ] **[Story] Gerenciamento de Versões de Ferramentas**
  - Permitir a atualização (`boss4d tool update`) e desinstalação (`boss4d tool uninstall`) de utilitários globais.

---

## 🌳 Épico 7: Diagnóstico Avançado de Dependências (`boss4d tree` / `outdated`)
*Objetivo: Fornecer visibilidade profunda sobre a árvore de dependências transitivas e o status de atualização de pacotes (Inspirado em `cargo tree` do Rust e `pub outdated` do Dart/Flutter).*

- [ ] **[Story] Exibição de Árvore de Dependências (`boss4d tree`)**
  - Imprimir graficamente no console a estrutura de dependências do projeto, indicando quais subdependências pertencem a quais pacotes e resolvendo conflitos visuais.
- [ ] **[Story] Relatório de Pacotes Desatualizados (`boss4d outdated`)**
  - Consultar de forma assíncrona as últimas tags compatíveis com SemVer no GitHub para cada dependência e gerar uma tabela exibindo a versão atual, versão compatível declarada e versão mais recente do autor.

---

## 🗂️ Épico 8: Suporte a Workspaces e Multi-Projetos (Monorepos)
*Objetivo: Facilitar a manutenção de múltiplos projetos locais Delphi sob o mesmo repositório que compartilham dependências comuns (Inspirado em Rust/npm Workspaces).*

- [ ] **[Story] Manifesto de Workspaces no `boss.json` raiz**
  - Suportar a declaração de `"workspaces": [ "projects/*" ]` no manifesto da raiz do repositório.
- [ ] **[Story] Compartilhamento Inteligente da pasta `modules/`**
  - Evitar downloads e compilações redundantes mantendo todas as dependências centralizadas na pasta `modules/` raiz, com o resolvedor interligando as referências relativas dos subprojetos internos automaticamente.

---

## 🔌 Épico 9: Instalação de Plugins e Extensões Globais do RAD Studio
*Objetivo: Permitir a instalação automatizada e registro de plugins e assistentes da própria IDE do Delphi (como o RadIA-Plugin) de forma global na máquina.*

- [ ] **[Story] Suporte a Tipo "Plugin" no `boss.json`**
  - Reconhecer e configurar manifestos com o atributo `"type": "plugin"` ou `"type": "ide-extension"`.
- [ ] **[Story] Instalação de Plugins via CLI (`boss4d plugin install <repo>`)**
  - Clonar o repositório do assistente, compilar sua BPL de design-time, movê-la para o diretório central de plugins `%APPDATA%\Boss4D\plugins\` e registrá-la automaticamente no Registro do Windows do RAD Studio sob a chave `Known Packages` das IDEs detectadas.

---

## 📦 Épico 10: Integração e Ponte com o GetIt Package Manager
*Objetivo: Integrar e unificar o gerenciamento de dependências Git open-source com o catálogo de pacotes comerciais e oficiais do GetIt do Delphi.*

- [ ] **[Story] Interação de Ponte com o `GetItCmd.exe`**
  - Executar comandos de busca, listagem e instalação de dependências oficiais chamando silenciosamente o utilitário CLI do GetIt nativo do Delphi ativo.
- [ ] **[Story] Configuração do Modo Online/Offline do GetIt**
  - Disponibilizar atalhos CLI no Boss4D para reconfigurar a conectividade do GetIt (ex: `boss4d getit mode-online`) de forma simplificada em ambientes corporativos ou pós-instalação da IDE.

---

## 🔒 Épico 11: Segurança e Verificação de Integridade de Dependências (Checksums)
*Objetivo: Prevenir ataques de supply chain e garantir a integridade dos fontes baixados em ambientes corporativos de alta segurança.*

- [ ] **[Story] Geração de Hash de Segurança no Lock**
  - Calcular e registrar o hash SHA-256 do estado do repositório/commit baixado dentro do arquivo `boss-lock.json`.
- [ ] **[Story] Validação de Integridade na Instãlação**
  - Recalcular e validar o hash SHA-256 dos fontes locais clonados durante o `boss4d install`, emitindo alertas e interrompendo o build caso haja qualquer discrepância com o esperado do lock.

---

## 🧹 Épico 12: Gerenciamento e Otimização do Cache Global (`boss4d cache`)
*Objetivo: Evitar que o diretório global de caches locais de Git no disco do desenvolvedor cresça de forma descontrolada.*

- [ ] **[Story] Diagnóstico de Armazenamento (`boss4d cache size`)**
  - Exibir o tamanho em disco e a lista de pacotes/versões cacheados na pasta `%USERPROFILE%\.boss\cache\`.
- [ ] **[Story] Limpeza Seletiva (`boss4d cache prune` / `clean`)**
  - Implementar o comando `clean` (para apagar 100% dos caches) e `prune` (para apagar de forma inteligente apenas caches de pacotes antigos ou não utilizados há mais de 30 dias).
