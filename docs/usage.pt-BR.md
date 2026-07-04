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

## 🔍 4. Comandos Utilitários

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
