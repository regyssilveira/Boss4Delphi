# Boss4D - Manual de Uso da CLI

[Read in English](usage.md) | [Leia em Português](usage.pt-BR.md)

O **Boss4D** é um gerenciador de dependências de linha de comando (CLI) projetado especificamente para projetos Delphi. Este guia aborda como inicializar, configurar, instalar e atualizar pacotes de dependências em suas aplicações.

---

## 🗂️ 1. Inicialização do Projeto (`init`)

Para começar a gerenciar dependências em um projeto Delphi novo ou existente, navegue até a pasta raiz do seu projeto no terminal e execute:

```bash
boss4d init
```

* **Modo Interativo**: Por padrão, o assistente perguntará no console o nome e a versão inicial do seu projeto.
* **Modo Silencioso (`-q` ou `--quiet`)**: Cria o arquivo instantaneamente usando valores padrão (o nome da pasta atual como nome do projeto e a versão `1.0.0`):
  ```bash
  boss4d init --quiet
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
boss4d tool install -g github.com/hashload/boss
```

* **Exemplo de Saída**:
  ```text
  Iniciando instalacao global da ferramenta: github.com/hashload/boss
    Clonando fontes...
    Compilando executavel...
  🚀 Ferramenta "boss" instalada com sucesso em: C:\Users\regys\.boss\bin\boss.exe
  Dica: Certifique-se de adicionar a pasta "C:\Users\regys\.boss\bin" ao PATH do sistema.
  ```

---

## 🔍 12. Comandos Utilitários

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
