# Boss4D - Manual Completo de Uso (Instalador, GUI, CLI e IDE)

[Read in English](usage.md) | [Leia em Português](usage.pt-BR.md)

O **Boss4D** é uma suíte completa de gerenciamento de dependências projetada especificamente para o ecossistema Delphi. Ele oferece uma interface de linha de comando (CLI) rápida, um aplicativo gráfico moderno (GUI) standalone, assistentes integrados dentro do RAD Studio (Plugin) e um instalador offline centralizado.

---

## 📦 0. Início Rápido com o Instalador Offline

Para usuários finais, o Boss4D fornece um instalador offline executável unificado (**`Boss4D_Setup.exe`**) gerado com o Inno Setup, simplificando todo o setup inicial:

1. **Baixar o Setup**: Baixe o instalador `Boss4D_Setup.exe` da seção de releases no GitHub.
2. **Execução de Privilégios Mínimos**: O instalador roda de forma segura no escopo do usuário atual (não requer privilégios de administrador/UAC).
3. **Autodetecção e Integração com Delphi**:
   * O instalador consulta automaticamente o Registro do Windows e localiza as instalações do **Delphi 11 (Alexandria)**, **Delphi 12 (Athens)** e **Delphi 13 (Florence)**.
   * Ele exibe caixas de seleção interativas para que você selecione em quais IDEs deseja ativar a integração do Boss4D (outras versões desmarcadas ou desinstaladas são removidas automaticamente).
4. **Variáveis de Ambiente**: O instalador injeta o caminho binário do Boss4D no seu `PATH` de usuário e notifica o Windows instantaneamente, tornando a CLI disponível em novos terminais de forma imediata sem necessidade de reiniciar.

---

## 🗂️ 1. Inicialização do Projeto (`init`)

Para começar a gerenciar dependências em um projeto Delphi novo ou existente, navegue até a pasta raiz do seu projeto no terminal e execute:

```bash
boss4d init
```

* **Modo Silencioso (`-q` ou `--quiet`)**: Cria o arquivo instantaneamente usando valores padrão (o nome da pasta atual como nome do projeto e a versão `1.0.0`):
  ```bash
  boss4d init --quiet
  ```

  * **Exemplo de Saída**:
    ```text
    Pronto. boss.json inicializado com sucesso em D:\Projetos\meu-projeto\boss.json
    ```

Este comando gera um arquivo **`boss.json`** na pasta raiz:
```json
{
  "name": "meu-projeto-delphi",
  "version": "1.0.0",
  "dependencies": {}
}
```

---

## 📥 2. Instalando Dependências (`install`)

O Boss4D faz o download das dependências do Git, realiza o checkout na versão correta, posiciona os fontes na pasta local `modules/` do seu projeto e atualiza as diretivas de caminhos de busca do compilador.

### Instalando um Novo Pacote
Para adicionar e instalar uma nova dependência, informe a URL do repositório Git e a faixa de versão desejada separadas por `@`:

```bash
boss4d install github.com/hashload/horse@^3.1.0
```

### Regras de Alvo de Instalação (SemVer e Branches)
O Boss4D suporta múltiplos tipos de alvos para checkout:
1. **Faixas de Versão Semântica (SemVer)**:
   * `^3.1.0`: Instala a última versão que atenda `>=3.1.0 <4.0.0` (ex: `v3.2.0`).
   * `~3.1.0`: Instala a última versão que atenda `>=3.1.0 <3.2.0`.
   * `*`: Instala a última tag de release disponível.
2. **Branches do Git ou Hashes de Commits**:
   * `@master`: Efetua checkout da última atualização da branch `master`.
   * `@main`: Efetua checkout da última atualização da branch `main`.
   * `@dev`: Efetua checkout da branch de desenvolvimento `dev`.
   * `@a1b2c3d4`: Efetua checkout de um hash SHA de commit específico.
3. **Instalação sem Alvo Definido**:
   * Se você rodar `boss4d install github.com/hashload/horse` sem informar um alvo `@`, o gerenciador buscará a última tag publicada. Se não houver tags no repositório, ele fará o checkout automático da branch padrão do Git (HEAD remota).

### Restaurando Dependências
Para instalar todas as dependências declaradas em um `boss.json` existente (por exemplo, logo após clonar um repositório da sua equipe):

```bash
boss4d install
```

* **Exemplo de Saída**:
  ```text
  Baixando dependencias do projeto...
  Compilando modulos instalados...
    Compilando horse.dproj
    Compilado com sucesso!
  Instalacao concluida com sucesso!
  ```

Este comando lê o `boss.json`, resolve a árvore de dependências recursivas concorrentemente e gera ou atualiza o arquivo **`boss-lock.json`** que trava as versões exatas baixadas.

---

## ⚙️ 3. Gerenciamento de Configurações (`config`)

O Boss4D salva suas preferências globais em um arquivo `boss.cfg.json` na sua pasta de usuário. Ajuste estas preferências usando o comando `config`.

### Configurando a Instalação do Delphi (Caminho ou Versão)
Para compilar pacotes baixados de forma nativa via MSBuild, o Boss4D precisa localizar a instalação do Delphi. Você pode configurar de três formas distintas:

1. **Informando a Versão de Release (Recomendado)**: O Boss4D consultará automaticamente o Registro do Windows para obter o caminho físico (ex: `23.0`, `22.0`, `21.0`):
   ```bash
   boss4d config delphi use 23.0
   ```

2. **Informando o Caminho Físico do Diretório**: Passe o caminho raiz absoluto de instalação do RAD Studio/Delphi:
   ```bash
   boss4d config delphi use "C:\Program Files (x86)\Embarcadero\Studio\23.0"
   ```

3. **Autodetectando Dinamicamente (Padrão/Vazio)**: Se você limpar a configuração ou deixá-la em branco, o compilador autodetectará e utilizará a versão mais recente instalada na máquina:
   ```bash
   boss4d config delphi use ""
   ```

### Configurando Shallow Clone no Git
Clones rasos baixam apenas os commits mais recentes do histórico do Git, tornando o download de dependências muito mais rápido:

* **Habilitar Shallow Clones** (Padrão):
  ```bash
  boss4d config git shallow true
  ```
* **Desabilitar Shallow Clones**:
  ```bash
  boss4d config git shallow false
  ```

* **Exemplo de Saída**:
  ```text
  ✅ Configuracao git shallow definida para: False
  ```

---

## 🩺 4. Auto-Diagnóstico do Ambiente (`doctor`)

O comando `doctor` executa uma série de verificações estruturadas no seu ambiente de desenvolvimento para garantir que a compilação paralela ocorra perfeitamente.

* **Executar verificação padrão**:
  ```bash
  boss4d doctor
  ```
  O diagnóstico valida a instalação e conectividade do **Git CLI**, as versões do **RAD Studio/Delphi** registradas no Windows, e se as ferramentas de compilação (`dcc32`, `msbuild`) estão configuradas e acessíveis no `PATH`.
  
* **Auto-Correção e Configuração Automatizada (`-fix`)**:
  ```bash
  boss4d doctor -fix
  ```
  Se executado com o parâmetro `-fix`, o Boss4D mapeia automaticamente as instalações do Delphi em sua máquina e configura a versão mais recente identificada no registro como padrão de compilação global do utilitário.

* **Exemplo de Saída (`boss4d doctor`)**:
  ```text
  [INFO] Iniciando verificacoes de diagnostico...
  [OK] Git instalado e acessivel no PATH (versao 2.45.0)
  [OK] Conectividade com GitHub estabelecida com sucesso.
  [OK] Versoes do Delphi detectadas no registro: 22.0, 23.0
  [OK] Compilador dcc32 localizado no PATH.
  [OK] MSBuild localizado no PATH.
  [OK] Diretorio modules/ possui permissoes de leitura e escrita.
  [INFO] Diagnostico concluido! Seu ambiente esta configurado corretamente.
  ```

---

## 🧹 5. Gerenciamento do Cache Global (`cache`)

O Boss4D armazena cópias em cache dos repositórios Git clonados para que instalações subsequentes de projetos que compartilham dependências sejam instantâneas e sem tráfego de rede desnecessário.

* **Exibir tamanho total do cache**:
  ```bash
  boss4d cache size
  ```
* **Limpar todo o cache global**:
  ```bash
  boss4d cache clean
  ```
* **Expurgar caches obsoletos**:
  ```bash
  boss4d cache prune
  ```
  Remove automaticamente do disco pastas de caches de dependências que não foram alteradas ou acessadas nos últimos 30 dias, prevenindo acúmulo desnecessário de gigabytes em seu HD.

* **Exemplo de Saída (`boss4d cache size`)**:
  ```text
  Tamanho total do cache global do Git: 145.28 MB
  ```

* **Exemplo de Saída (`boss4d cache clean`)**:
  ```text
  ✅ Cache global limpo com sucesso! 45 pastas removidas.
  ```

---

## 📜 6. Execução de Scripts Customizados (`run`)

O desenvolvedor pode centralizar e padronizar rotinas de build, testes de integração ou tarefas repetitivas diretamente no manifesto `boss.json` do projeto, eliminando arquivos `.bat` ad-hoc.

Cadastre seus scripts na seção `"scripts"` do seu `boss.json`:
```json
{
  "name": "meu-projeto",
  "version": "1.0.0",
  "scripts": {
    "test": "tests\\Win32\\Debug\\Boss4DTests.exe",
    "build": "msbuild meu-projeto.dproj /p:Configuration=Release"
  }
}
```

* **Executar um script cadastrado**:
  ```bash
  boss4d run test
  boss4d run build
  ```
  O comando executa o comando associado e exibe o log de saída e status diretamente no seu terminal de trabalho.

* **Exemplo de Saída**:
  ```text
  > Win32\Debug\Boss4DTests.exe
  DUnitX - Starting Tests...
  Tests Passed: 44
  ```

---

## 📄 7. Auditoria de Licenças e Conformidade (`license`)

Útil para empresas que exigem conformidade legal de código aberto antes de publicar softwares ou compilar releases.

* **Gerar relatório de compliance**:
  ```bash
  boss4d license report
  ```
  O comando varre todos os submódulos instalados na pasta `modules/`, inspeciona o campo `"license"` dos pacotes e lê arquivos físicos locais como `LICENSE` ou `COPYING`.
  
  Ele gera automaticamente os seguintes arquivos de auditoria sob a pasta `docs/`:
  1. `docs/license_report.md`: Um documento Markdown visual contendo a tabela organizada com dependência, versão, licença detectada e a origem do dado.
  2. `docs/license_report.csv`: Uma tabela de dados brutos (formato CSV) ideal para ser consumida em pipelines automáticos de segurança e compliance.

* **Exemplo de Saída**:
  ```text
  ✅ Relatorio de conformidade gerado com sucesso em: docs/license_report.md
  ✅ Relatorio em formato CSV gerado com sucesso em: docs/license_report.csv
  ```

---

## 7.1. Geração de SBOM (`sbom`)

Gere um Software Bill of Materials em CycloneDX 1.7 JSON usando o `boss.json`
e o `boss-lock.json` v2:

```bash
boss4d sbom --format cyclonedx --output bom.cdx.json --validate
```

O mesmo modelo neutro também pode ser serializado como SPDX 2.3 JSON:

```bash
boss4d sbom --format spdx --output bom.spdx.json --validate
```

Para CI e releases reproduzíveis:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate \
  --reproducible --type application --output dist/bom.cdx.json
```

Sem `--output`, o JSON é escrito na saída padrão e diagnósticos são escritos na
saída de erro. `--strict` recusa revisão, identidade, checksum ou evidência de
grafo ausente. `--reproducible` omite UUID e timestamp voláteis e garante
ordenação estável.
`--lock-only` garante que nenhum coletor consulte GetIt, instalações Delphi ou
arquivos de artefatos; por isso, não pode ser combinado com `--include-*`.

O SBOM básico cobre as dependências gerenciadas pelo Boss4D. Para enriquecê-lo
com evidências da máquina de build:

```bash
boss4d sbom --include-getit --include-toolchain --include-artifacts \
  --output bom-enriquecido.cdx.json --validate
```

`--include-getit` consulta os pacotes instalados pelo `GetItCmd`;
`--include-toolchain` registra as instalações RAD Studio detectadas e a cobertura
de compilador/RTL, incluindo versão e SHA-256 de `dcc32`, `dcc64` e `System.dcu`;
`--include-artifacts` verifica os caminhos `artifacts` do lock e
calcula SHA-256 dos arquivos encontrados. Falha de consulta nunca é interpretada
como inventário vazio. Os coletores são opt-in porque refletem o ambiente local e
podem tornar o SBOM não reproduzível. SDKs externos ainda devem ser declarados
manualmente.

Cada bloco `artifacts` do lock possui uma base explícita: `project` (padrão
retrocompatível), `module` (`modules/<dependência>`) ou `absolute`. Caminhos
absolutos são aceitos somente com base `absolute`; caminhos relativos que escapem
da base com `..` são rejeitados.

Pacotes apenas instalados no GetIt entram como inventário ambiental com uso
desconhecido e não são ligados à raiz como dependências. Para afirmar uso pelo
projeto, declare o componente em `sbom.components` com `"source": "getit"`;
o coletor reconciliará nome/versão com a instalação e reportará divergências.

O núcleo expõe transformadores de documento para integrações futuras de merge,
SCA e VEX, além de um assinador pós-serialização. Nenhum deles é necessário para
gerar CycloneDX ou SPDX localmente; assinatura e consulta de vulnerabilidades
continuam responsabilidades de adaptadores opcionais.

Um VEX offline pode enriquecer a saída CycloneDX sem consulta de rede:

```bash
boss4d sbom --format cyclonedx --vex security.vex.json \
  --attestation-output bom.intoto.json --output bom.cdx.json --validate
boss4d sbom --format cyclonedx --vex security.vex.json \
  --verify-attestation bom.intoto.json --output bom-verificado.cdx.json
```

O arquivo VEX contém `vulnerabilities` com `id`, `component`, `state`, `detail` e
`source`. Estados aceitos: `affected`, `not_affected`, `fixed` e
`under_investigation`. A atestação destacada segue o envelope in-toto Statement v1
e fixa o SHA-256 do SBOM; qualquer alteração posterior falha na verificação. O VEX
é restrito ao CycloneDX porque SPDX 2.3 não possui o perfil de segurança do SPDX 3.

Componentes que o Boss4D não consegue descobrir automaticamente, inclusive
bibliotecas comerciais, podem ser declarados explicitamente no `boss.json`:

```json
{
  "sbom": {
    "components": [
      {
        "id": "vendor-database-driver",
        "name": "Vendor Database Driver",
        "version": "5.4",
        "type": "library",
        "license": "Commercial",
        "repository": "https://vendor.example/driver",
        "hash": {
          "algorithm": "SHA-256",
          "value": "..."
        }
      }
    ]
  }
}
```

Componentes manuais são marcados como declarações provenientes do `boss.json`;
eles não são apresentados como evidência descoberta automaticamente.

---

## 🌳 8. Diagnóstico de Dependências (`tree` e `outdated`)

### Visualizando a Árvore de Dependências
Para analisar visualmente toda a hierarquia de módulos instalados em seu projeto e entender quais submódulos são carregados recursivamente:

```bash
boss4d tree
```

* **Exemplo de Saída**:
  ```text
  meu-projeto (1.0.0)
  ├── github.com/hashload/horse (3.1.0)
  │   └── github.com/hashload/dataset-serialize (2.4.0)
  └── github.com/viniciusanchez/restrequest4delphi (1.5.0)
  ```

### Verificando Pacotes Desatualizados
Para comparar as versões declaradas no seu arquivo `boss-lock.json` com as versões de tags mais recentes disponíveis remotamente nos repositórios Git:

```bash
boss4d outdated
```

* **Exemplo de Saída**:
  ```text
  Buscando informacoes de atualizacao de pacotes...
  Dependencia: github.com/hashload/horse
    Versao instalada: 3.1.0
    Versao mais recente disponivel: 3.5.2
    Status: Desatualizado

  Dependencia: github.com/viniciusanchez/restrequest4delphi
    Versao instalada: 1.5.0
    Versao mais recente disponivel: 1.5.0
    Status: Atualizado
  ```

---

## 🔐 9. Repositórios Privados e Credenciais (`config auth`)

O Boss4D suporta dependências privadas hospedadas no GitHub ou GitLab. Para configurar tokens de autenticação PAT (Personal Access Token) globais com segurança (as credenciais são salvas criptografadas no arquivo `boss.cfg.json` local e ocultadas automaticamente com `***` nos logs de erro):

```bash
boss4d config auth github ghp_meutokengithubsecreto
boss4d config auth gitlab glpat-meutokengitlabsecreto
```

* **Exemplo de Saída**:
  ```text
  ✅ Token de autenticacao do GitHub configurado com sucesso.
  ```

### Suporte a Caminhos Locais e de Rede
Além de repositórios remotos privados, você pode declarar dependências locais de forma direta em seu `boss.json`:
* Caminhos Locais: `"file:///d:/Projetos/MinhaLib"` ou `"d:\Projetos\MinhaLib"`
* Caminhos de Rede UNC: `"\\servidor\compartilhado\MinhaLib"`

### 🌳 Suporte a Workspaces (Monorepos)
Em repositórios contendo múltiplos subprojetos Delphi que compartilham dependências, declare as pastas do workspace no `boss.json` raiz:
```json
{
  "name": "meu-monorepo",
  "workspaces": [
    "subprojects/*"
  ]
}
```
Ao executar `boss4d install` na raiz do monorepo, o resolvedor:
1. Mapeia e unifica recursivamente todas as dependências declaradas na raiz e nos subprojetos.
2. Baixa e compila uma única vez na pasta `modules/` raiz.
3. Cria Junções de Diretório (`Directory Junctions` via `mklink /J` no Windows) da pasta `modules/` raiz dentro de cada subprojeto automaticamente, eliminando duplicações de arquivos e permitindo a compilação local transparente na IDE.

---

## 🌐 10. Compilação Multiplataforma (`--platform`)

Por padrão, o Boss4D compila dependências para Windows (Win32/Win64). Para automatizar o build de dependências em projetos direcionados a outras plataformas suportadas pelo compilador Delphi (ex: Win64, Linux64, Android, OSX64):

```bash
boss4d install --platform Linux64
boss4d install github.com/hashload/horse -p Win64
```

* **Exemplo de Saída**:
  ```text
  Baixando dependencias do projeto...
  Compilando modulos instalados...
    Compilando horse.dproj
    Compilado com sucesso!
  Instalacao concluida com sucesso!
  Iniciando integracao de Library Paths na IDE...
    [OK] Library Path atualizado para Delphi 23.0 (Linux64).
  Integracao concluida!
  ```

* **Integração de Library Path na IDE**: O Boss4D detecta automaticamente as chaves do Delphi instaladas na sua máquina e atualiza o `Search Path` no Registro do Windows com o caminho absoluto das DCUs do Boss (`modules\dcu`) para a plataforma selecionada, garantindo conformidade imediata com a IDE RAD Studio.

---

## 🚀 11. Instalação Global de Ferramentas CLI (`tool`)

Você pode instalar utilitários de linha de comando feitos em Delphi de forma global em sua máquina com apenas um comando. O Boss4D baixa as fontes, compila de forma nativa e distribui o executável final em uma pasta global adicionável ao seu PATH.

```bash
# Instalar uma ferramenta globalmente
boss4d tool install -g github.com/hashload/boss

# Atualizar uma ferramenta global instalada
boss4d tool update boss github.com/hashload/boss

# Desinstalar uma ferramenta global
boss4d tool uninstall boss
```

* **Exemplo de Saída (`uninstall`)**:
  ```text
  ✅ Ferramenta "boss" desinstalada com sucesso.
  ```

* **Exemplo de Saída (`update`)**:
  ```text
  Atualizando ferramenta "boss"...
  Iniciando instalacao global da ferramenta: github.com/hashload/boss
    Clonando fontes...
    Compilando executavel...
  🚀 Ferramenta "boss" instalada com sucesso em: C:\Users\regys\.boss\bin\boss.exe
  ```

---

---

## 🔌 12. Instalação de Plugins e Extensões da IDE (`plugin`)

Você pode compilar e instalar plugins e assistentes diretamente na IDE do RAD Studio de forma totalmente automatizada. O Boss4D detecta as IDEs instaladas no Registry, compila o arquivo de extensão (.bpl), copia-o para a pasta `%APPDATA%\Boss4D\plugins\` e o registra na chave `Known Packages` correspondente do RAD Studio.

```bash
boss4d plugin install github.com/user/my-plugin
```

* **Exemplo de Saída**:
  ```text
  Iniciando instalacao de plugin de IDE: github.com/user/my-plugin
    Clonando fontes do plugin...
    Compilando plugin...
    Registrando plugin no RAD Studio...
    [OK] Plugin registrado em Known Packages (Delphi 23.0).
  🚀 Plugin "my-plugin" instalado e registrado com sucesso!
  ```

### Instalando o Plugin Oficial do Boss4D no Delphi
O Boss4D acompanha um plugin nativo de IDE (`Boss4D.IDE.Plugin`) que adiciona atalhos de gerenciamento no Project Manager e canaliza mensagens de build diretamente no Message View.

* **Como instalar**:
  1. Abra o arquivo de projeto do pacote `src/IDE/Boss4D.IDE.Plugin.dproj` na sua IDE do Delphi.
  2. No Project Manager, clique com o botão direito no pacote e selecione **Install**.
  3. A IDE carregará o Wizard e exibirá uma confirmação de registro.
* **Como usar**:
  1. No Project Manager, clique com o botão direito sobre o seu projeto ou grupo de projetos.
  2. Navegue até o menu **Boss4D** e escolha **Boss4D Init** (para inicializar) ou **Boss4D Install** (para baixar e compilar dependências).
  3. O progresso da compilação e download da CLI será impresso em tempo real na aba **Boss4D** do painel inferior Message View no rodapé da IDE.

---

## 📦 13. Integração e Ponte com GetIt (`getit`)

O Boss4D fornece uma ponte direta e integrada com o repositório oficial Embarcadero GetIt. Isso permite a instalação automatizada e silenciosa de bibliotecas oficiais diretamente através do utilitário `GetItCmd.exe` da IDE Delphi, além do gerenciamento de conectividade online/offline da IDE em ambientes corporativos.

```bash
# Instalar um pacote oficial do GetIt
boss4d getit install Jcl

# Mudar o GetIt para modo online
boss4d getit mode-online

# Mudar o GetIt para modo offline (corporativo)
boss4d getit mode-offline
```

* **Exemplo de Saída (`getit install`)**:
  ```text
  Iniciando instalacao via GetIt: Jcl
  🚀 Pacote "Jcl" instalado com sucesso via GetIt!
  ```

---

## 🔍 14. Comandos Utilitários

### Verificar Versão da CLI
Exibe a versão atual do binário:
```bash
boss4d version
```

### Menu de Ajuda
Lista todos os comandos e opções suportados com descrições breves:
```bash
boss4d help
```

### Limpar Dependências do Projeto
Apaga a pasta `modules/` e o arquivo `boss-lock.json` para reinicializar as dependências do projeto local:
```bash
boss4d clean
```

---

## 🖥️ 15. Interface Gráfica Standalone (GUI)

A interface gráfica do **Boss4D** (**`Boss4D.GUI.exe`**) fornece uma aplicação visual moderna e amigável integrada in-process com o motor de negócios do Boss4D.

### Como Acessar
* O instalador cria atalhos opcionais na **Área de Trabalho** e no **Menu Iniciar** (pasta `Boss4D`).
* Você também pode executá-la digitando `Boss4D.GUI` em qualquer terminal (pois o PATH estará configurado).

### Funcionalidades
1. **Navegação Lateral (Sidebar SPA)**:
   * **Projeto Local**: Selecione um diretório de projeto no disco. O Boss4D lerá o arquivo `boss.json` e listará as dependências, a versão declarada e a versão instalada em tempo real. Oferece botões rápidos para `Init`, `Install`, `Verificar Updates` (outdated) e `Árvore de Módulos`.
   * **Buscar Pacotes**: Catálogo visual contendo as bibliotecas mais populares do ecossistema Delphi (Horse, RESTRequest4Delphi, mORMot, Skia, etc.) permitindo a busca filtrada e instalação silenciosa in-process com um clique.
   * **Boss4D Doctor**: Executa verificações estruturadas e auto-correções no ambiente do Delphi sem precisar da linha de comando.
   * **Gerenciar Cache**: Exibe o uso de disco do cache global e fornece opções para limpar (`Clean`) ou realizar o prune (`Otimizar Cache`) de versões antigas.
2. **Terminal de Logs Integrado**: A área inferior exibe os logs, avisos e andamento de downloads concorrentes e compilação de pacotes gerados em segundo plano (via PPL) de forma thread-safe.

---

## 🔌 16. Integração RAD Studio IDE (Plugin)

O assistente integrado do Boss4D adiciona recursos e atalhos na IDE para agilizar o desenvolvimento:

### Principais Recursos
1. **Atalhos no Project Manager (Gerenciador de Projetos)**:
   * Ao clicar com o botão direito sobre um projeto `.dproj` ou grupo de projetos `.groupproj` ativo no Project Manager do Delphi, navegue no menu contextual até **Boss4D**.
   * Você poderá disparar comandos rápidos (`Init`, `Install`, `Doctor`, `Cache`, `Licensing`) diretamente de dentro da IDE.
2. **Submenus Dinâmicos de Scripts**:
   * O assistente lê as definições declaradas na seção `"scripts"` do seu manifesto `boss.json` (ex: `"build"`, `"test"`, `"deploy"`).
   * Ele gera submenus contextuais dinamicamente para cada script sob a opção **Boss4D -> Scripts** da IDE, permitindo que você os execute com um clique e visualize o output em tempo de desenvolvimento.
3. **Caixa de Diálogo do Install**:
   * A opção **Install Package...** abre uma janela integrada da IDE permitindo que você digite a URL e versão do repositório Git de forma rápida, disparando a instalação silenciosa.
4. **Message View Integrado**: O progresso e os logs coloridos do Boss4D são direcionados para uma aba exclusiva no Message View (painel de mensagens na parte inferior do RAD Studio).
