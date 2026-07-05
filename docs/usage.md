# Boss4D - CLI Usage Manual

[Read in English](usage.md) | [Leia em Português](usage.pt-BR.md)

**Boss4D** is a command-line interface (CLI) dependency manager designed specifically for Delphi projects. This guide covers how to initialize, configure, install, and update package dependencies in your applications.

---

## 🗂️ 1. Project Initialization (`init`)

To start managing dependencies in a new or existing Delphi project, navigate to the project's root folder and run:

```bash
boss4d init
```

* **Silent Mode (`-q` or `--quiet`)**: Initializes the file instantly using default values (folder name as project name and version `1.0.0`):
  ```bash
  boss4d init --quiet
  ```

  * **Example Output**:
    ```text
    Pronto. boss.json inicializado com sucesso em D:\Projetos\meu-projeto\boss.json
    ```

This command creates a **`boss.json`** file in your directory:
```json
{
  "name": "my-delphi-project",
  "version": "1.0.0",
  "dependencies": {}
}
```

---

## 📥 2. Installing Dependencies (`install`)

Boss4D downloads dependencies, checks out the correct version from Git, places them in a local `modules/` folder, and updates compilation paths.

### Installing a New Package
To add a new dependency, pass its repository URL and version range separated by `@`:

```bash
boss4d install github.com/hashload/horse@^3.1.0
```

### Installation Target Rules (SemVer & Branches)
Boss4D supports different target types:
1. **Semantic Version Ranges (SemVer)**:
   * `^3.1.0`: Resolves to the latest tag matching `>=3.1.0 <4.0.0` (ex: `v3.2.0`).
   * `~3.1.0`: Resolves to the latest tag matching `>=3.1.0 <3.2.0`.
   * `*`: Resolves to the absolute latest tag.
2. **Git Branches or Commit Hashes**:
   * `@master`: Checks out the head of the `master` branch.
   * `@main`: Checks out the head of the `main` branch.
   * `@development`: Checks out the development branch.
   * `@a1b2c3d4`: Checks out a specific commit SHA hash.
3. **No Target Provided**:
   * If you run `boss4d install github.com/hashload/horse` without a target, it tries to match the latest tag. If no tags exist, it falls back to checking out the repository's default branch.

### Restoring Packages
To install all dependencies declared in an existing `boss.json` (for example, after cloning a repository):

```bash
boss4d install
```

* **Example Output**:
  ```text
  Baixando dependencias do projeto...
  Compilando modulos instalados...
    Compilando horse.dproj
    Compilado com sucesso!
  Instalacao concluida com sucesso!
  ```

This reads the `boss.json`, resolves the full dependency graph recursively, downloads all packages concurrently, and generates/updates the **`boss-lock.json`** file to lock the exact versions resolved.

---

## ⚙️ 3. Configuration Management (`config`)

Boss4D stores global preferences in a `boss.cfg.json` file. Use the `config` command to adjust them.

### Setting the Delphi Installation (Path or Release Version)
To compile packages using MSBuild, Boss4D needs to locate the Delphi installation directory. You can set this in three different ways:

1. **Specifying the Release Version (Recommended)**: Boss4D will query the Windows Registry to automatically resolve the installation path (e.g. `23.0`, `22.0`, `21.0`):
   ```bash
   boss4d config delphi use 23.0
   ```

2. **Specifying the Absolute Directory Path**: Provide the absolute root installation directory of your RAD Studio/Delphi IDE:
   ```bash
   boss4d config delphi use "C:\Program Files (x86)\Embarcadero\Studio\23.0"
   ```

3. **Dynamic Autodetection (Default/Empty)**: If you clear the preference or leave it blank, the compiler adapter will automatically detect and use the latest installed version found on the machine:
   ```bash
   boss4d config delphi use ""
   ```

### Setting Git Shallow Clone
Shallow clones download only the latest commits, significantly speeding up package downloads:

* **Enable Shallow Clones** (Default):
  ```bash
  boss4d config git shallow true
  ```
* **Disable Shallow Clones**:
  ```bash
  boss4d config git shallow false
  ```

* **Example Output**:
  ```text
  ✅ Configuracao git shallow definida para: False
  ```

---

## 🩺 4. Environment Diagnostics (`doctor`)

The `doctor` command runs structured diagnostics to ensure your local compilation environment is healthy.

* **Run default diagnostic**:
  ```bash
  boss4d doctor
  ```
  This command validates the installation and availability of the **Git CLI**, maps the **RAD Studio/Delphi** installations in the Windows Registry, and checks if tools like `dcc32` and `msbuild` are available in your `PATH`.

* **Auto-Correction (`-fix` / `--fix`)**:
  ```bash
  boss4d doctor -fix
  ```
  Attempts to auto-resolve compiler issues. If Delphi versions are found in the Registry but missing from the path, it configures the latest detected release version in the global Boss4D settings as the default compiler root.

* **Example Output (`boss4d doctor`)**:
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

## 🧹 5. Cache Management (`cache`)

Boss4D caches cloned Git repositories globally to make subsequent installations instantaneous.

* **Check total cache size**:
  ```bash
  boss4d cache size
  ```
* **Clear all global cache**:
  ```bash
  boss4d cache clean
  ```
* **Prune obsolete caches**:
  ```bash
  boss4d cache prune
  ```
  Scans and removes cached package folders that have not been modified or accessed for more than 30 days to free up disk space.

* **Example Output (`boss4d cache size`)**:
  ```text
  Tamanho total do cache global do Git: 145.28 MB
  ```

* **Example Output (`boss4d cache clean`)**:
  ```text
  ✅ Cache global limpo com sucesso! 45 pastas removidas.
  ```

---

## 📜 6. Custom Scripts Execution (`run`)

You can define custom task scripts (such as build, test, lint, or staging tasks) directly in the `"scripts"` object inside `boss.json` and execute them via CLI:

```json
{
  "name": "my-delphi-project",
  "version": "1.0.0",
  "scripts": {
    "test": "tests\\Win32\\Debug\\Boss4DTests.exe",
    "build": "msbuild my-delphi-project.dproj /p:Configuration=Release"
  }
}
```

* **Run a custom script**:
  ```bash
  boss4d run test
  boss4d run build
  ```
  This executes the CLI command mapped to the script and prints all output and execution logs directly into the terminal.

* **Example Output**:
  ```text
  > Win32\Debug\Boss4DTests.exe
  DUnitX - Starting Tests...
  Tests Passed: 44
  ```

---

## 📄 7. License Compliance Auditing (`license`)

Essential for corporate environments that require open-source licensing validation before compiling releases or releasing code.

* **Generate compliance report**:
  ```bash
  boss4d license report
  ```
  Scans all modules installed under the `modules/` directory, reading the `"license"` attribute in their `boss.json` manifest, or scanning local license files (like `LICENSE`, `COPYING`).

  It generates two audit files inside the local `docs/` folder:
  1. `docs/license_report.md`: A formatted Markdown table listing dependency name, installed version, detected license, and source of information.
  2. `docs/license_report.csv`: A raw data CSV file ideal for automated compliance parsing in security pipelines.

* **Example Output**:
  ```text
  ✅ Relatorio de conformidade gerado com sucesso em: docs/license_report.md
  ✅ Relatorio em formato CSV gerado com sucesso em: docs/license_report.csv
  ```

---

## 🌳 8. Dependency Diagnostics (`tree` and `outdated`)

### Viewing Dependency Tree
To visually analyze the complete dependency hierarchy installed in your project and understand what sub-modules are loaded recursively:

```bash
boss4d tree
```

* **Example Output**:
  ```text
  meu-projeto (1.0.0)
  ├── github.com/hashload/horse (3.1.0)
  │   └── github.com/hashload/dataset-serialize (2.4.0)
  └── github.com/viniciusanchez/restrequest4delphi (1.5.0)
  ```

### Checking for Outdated Packages
To compare the versions locked in your `boss-lock.json` with the latest tags available on their remote Git repositories:

```bash
boss4d outdated
```

* **Example Output**:
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

## 🔐 9. Private Repositories & Credentials (`config auth`)

Boss4D supports private packages hosted on GitHub or GitLab. Configure Personal Access Tokens (PATs) globally with security (stored encrypted in `boss.cfg.json` and automatically masked with `***` in error logs):

```bash
boss4d config auth github ghp_mysecretgithubtoken
boss4d config auth gitlab glpat-mysecretgitlabtoken
```

* **Example Output**:
  ```text
  ✅ Token de autenticacao do GitHub configurado com sucesso.
  ```

### Local Paths and UNC Network Paths
In addition to private remote repositories, you can reference local repositories in your `boss.json`:
* Local Drive Paths: `"file:///d:/Projects/MyLib"` or `"d:\Projects\MyLib"`
* UNC Network Shares: `"\\server\shared\MyLib"`

---

## 🌐 10. Multiplatform Compilation (`--platform`)

By default, Boss4D compiles packages targeting Windows (Win32/Win64). Automate library builds for other platforms supported by your Delphi compiler (e.g. Win64, Linux64, Android, OSX64):

```bash
boss4d install --platform Linux64
boss4d install github.com/hashload/horse -p Win64
```

* **Example Output**:
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

* **IDE Library Path Integration**: Boss4D automatically updates your Delphi Global `Search Path` in the Windows Registry to include the absolute path of Boss compiled DCUs (`modules\dcu`) for the target platform, making dependencies instantly visible to the Delphi RAD Studio IDE.

---

## 🚀 11. Global CLI Tools Installation (`tool`)

Install command-line utilities written in Delphi globally on your machine with one command. Boss4D clones the tool, compiles it using MSBuild, and copies the resulting binary into a global folder added to your system's PATH.

```bash
boss4d tool install -g github.com/hashload/boss
```

* **Example Output**:
  ```text
  Iniciando instalacao global da ferramenta: github.com/hashload/boss
    Clonando fontes...
    Compilando executavel...
  🚀 Ferramenta "boss" instalada com sucesso em: C:\Users\regys\.boss\bin\boss.exe
  Dica: Certifique-se de adicionar a pasta "C:\Users\regys\.boss\bin" ao PATH do sistema.
  ```

---

## 🔍 12. Utility Commands

### Checking CLI Version
Prints the current native binary version:
```bash
boss4d version
```

### Help Menu
Prints all available commands and flags:
```bash
boss4d help
```
