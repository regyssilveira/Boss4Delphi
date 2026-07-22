# Boss4D - Complete User Manual (Installer, GUI, CLI, and IDE)

[Read in English](usage.md) | [Leia em Português](usage.pt-BR.md)

**Boss4D** is a complete package management suite designed specifically for the Delphi ecosystem. It provides a fast command-line interface (CLI), a modern standalone graphic application (GUI), integrated wizards inside the RAD Studio IDE (Plugin), and a unified offline installer.

---

## 📦 0. Quick Start with the Offline Installer

For end users, Boss4D provides a unified offline executable installer (**`Boss4D_Setup.exe`**) generated using Inno Setup, simplifying the entire initial setup:

1. **Download the Setup**: Get the installer `Boss4D_Setup.exe` from the releases section on GitHub.
2. **Lowest Privileges Execution**: The installer runs safely within the current user scope (does not require administrator/UAC elevation).
3. **Autodetection and Delphi Integration**:
   * The installer automatically queries the Windows Registry to locate installations of **Delphi 11 (Alexandria)**, **Delphi 12 (Athens)**, and **Delphi 13 (Florence)**.
   * It displays interactive checkboxes so you can select which IDEs you want to integrate with Boss4D (other unselected or uninstalled versions are cleaned up automatically).
4. **Environment Variables**: The installer registers the Boss4D binary directory in your user `PATH` and notifies the Windows OS instantly, making the CLI available in new terminals immediately without needing a logoff/reboot.

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

## 7.1. SBOM generation (`sbom`)

Generate a CycloneDX 1.7 JSON Software Bill of Materials from `boss.json` and
`boss-lock.json` v2:

```bash
boss4d sbom --format cyclonedx --output bom.cdx.json --validate
```

The same neutral model can also be serialized as SPDX 2.3 JSON:

```bash
boss4d sbom --format spdx --output bom.spdx.json --validate
```

For CI and reproducible releases:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate \
  --reproducible --type application --output dist/bom.cdx.json
```

Without `--output`, the JSON document is written to standard output and
diagnostics are written to standard error. `--strict` rejects missing revision,
identity, checksum, or graph evidence. `--reproducible` omits volatile UUID and
timestamp fields and guarantees stable ordering.
`--lock-only` guarantees that no collector queries GetIt, Delphi installations,
or artifact files, so it cannot be combined with any `--include-*` option.

The basic SBOM covers dependencies managed by Boss4D. To enrich it with build
machine evidence:

```bash
boss4d sbom --include-getit --include-toolchain --include-artifacts \
  --output enriched-bom.cdx.json --validate
```

`--include-getit` queries packages installed through `GetItCmd`;
`--include-toolchain` records detected RAD Studio installations and compiler/RTL
coverage, including versions and SHA-256 for `dcc32`, `dcc64`, and `System.dcu`;
`--include-artifacts` checks lock-file `artifacts` paths and calculates
SHA-256 for files found. A failed query is never interpreted as an empty inventory.
The collectors are opt-in because they reflect the local environment and can make
the SBOM non-reproducible. External SDKs must still be declared manually.

Packages that are merely installed through GetIt are recorded as environment
inventory with unknown usage and are not linked to the root as dependencies. To
assert project usage, declare the component under `sbom.components` with
`"source": "getit"`; the collector reconciles its name/version with the installed
inventory and reports mismatches.

The core exposes extension points for merge, SCA, VEX, signing, and attestation.
The CLI includes a concrete offline VEX transformer and a detached SHA-256
attestor; neither is required for basic CycloneDX or SPDX generation. Network SCA
lookups and identity-bearing digital signatures remain optional adapter concerns.

An offline VEX file can enrich CycloneDX output without a network lookup:

```bash
boss4d sbom --format cyclonedx --vex security.vex.json \
  --attestation-output bom.intoto.json --output bom.cdx.json --validate
boss4d sbom --format cyclonedx --vex security.vex.json \
  --verify-attestation bom.intoto.json --output verified-bom.cdx.json
```

The VEX file contains `vulnerabilities` entries with `id`, `component`, `state`,
`detail`, and `source`. Supported states are `affected`, `not_affected`, `fixed`,
and `under_investigation`. The detached attestation uses an in-toto Statement v1
envelope and binds the SBOM SHA-256; any later modification fails verification.
VEX is limited to CycloneDX because SPDX 2.3 does not include SPDX 3's security
profile.

Every lock-file `artifacts` block has an explicit base: `project` (the
backward-compatible default), `module` (`modules/<dependency>`), or `absolute`.
Absolute paths are accepted only with the `absolute` base, and relative paths
that escape their selected base through `..` are rejected.

Components that Boss4D cannot discover automatically, including commercial
libraries, can be declared explicitly in `boss.json`:

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

Manual components are marked as declarations originating from `boss.json`; they
are not presented as automatically discovered evidence.

See [SBOM examples](sbom-examples.md) for complete copyable release, collector,
artifact, VEX, and attestation workflows.

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

### 🌳 Workspaces Support (Monorepos)
For repositories containing multiple subprojects sharing dependencies, declare your workspace subfolders in the root `boss.json` manifest:
```json
{
  "name": "my-monorepo",
  "workspaces": [
    "subprojects/*"
  ]
}
```
When running `boss4d install` in the root of the monorepo, the resolver:
1. Recursively collects and unifies all dependencies across root and subprojects.
2. Clones and compiles everything once in the root `modules/` folder.
3. Automatically creates Directory Junctions (`mklink /J` in Windows) pointing from the subproject `modules` folder back to the root `modules` directory, saving disk space and ensuring transparent local compilation inside the IDE.

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
# Install a tool globally
boss4d tool install -g github.com/hashload/boss

# Update an installed global tool
boss4d tool update boss github.com/hashload/boss

# Uninstall a global tool
boss4d tool uninstall boss
```

* **Example Output (`uninstall`)**:
  ```text
  ✅ Ferramenta "boss" desinstalada com sucesso.
  ```

* **Example Output (`update`)**:
  ```text
  Atualizando ferramenta "boss"...
  Iniciando instalacao global da ferramenta: github.com/hashload/boss
    Clonando fontes...
    Compilando executavel...
  🚀 Ferramenta "boss" instalada com sucesso em: C:\Users\regys\.boss\bin\boss.exe
  ```

---

## 🔌 12. IDE Plugins and Assistants Installation (`plugin`)

Compile and register IDE plugins and assistants directly into your RAD Studio installations. Boss4D compiles the extension package (.bpl), copies it to your global `%APPDATA%\Boss4D\plugins\` directory, and registers it under the `Known Packages` key in the Windows Registry.

```bash
boss4d plugin install github.com/user/my-plugin
```

* **Example Output**:
  ```text
  Iniciando instalacao de plugin de IDE: github.com/user/my-plugin
    Clonando fontes do plugin...
    Compilando plugin...
    Registrando plugin no RAD Studio...
    [OK] Plugin registered in Known Packages (Delphi 23.0).
  🚀 Plugin "my-plugin" installed and registered with success!
  ```

### Installing the Official Boss4D Plugin in Delphi IDE
Boss4D comes with a native IDE plugin (`Boss4D.IDE.Plugin`) that adds management shortcuts directly into the Project Manager and channels execution logs into the Message View.

* **How to Install**:
  1. Open the package project file `src/IDE/Boss4D.IDE.Plugin.dproj` in your Delphi IDE.
  2. In the Project Manager, right-click on the package and select **Install**.
  3. The IDE will load the Wizard and show a registration success confirmation.
* **How to Use**:
  1. In the Project Manager, right-click on your project or project group.
  2. Select the **Boss4D** menu item and choose **Boss4D Init** (to initialize) or **Boss4D Install** (to download and build dependencies).
  3. The CLI execution and build progress will be printed in real-time under the custom **Boss4D** tab in the Message View panel at the bottom of the IDE.

---

## 📦 13. Integration and Bridge with GetIt (`getit`)

Boss4D provides a direct bridge to Embarcadero's official GetIt package manager catalog. This enables silent, automated installations of official Delphi packages using `GetItCmd.exe` and network connectivity mode updates (online/offline) for corporate environments.

```bash
# Install an official package from GetIt
boss4d getit install Jcl

# Set GetIt connectivity mode to online
boss4d getit mode-online

# Set GetIt connectivity mode to offline (corporate)
boss4d getit mode-offline
```

* **Example Output (`getit install`)**:
  ```text
  Iniciando instalacao via GetIt: Jcl
  🚀 Pacote "Jcl" instalado com sucesso via GetIt!
  ```

---

## 🔍 14. Utility Commands

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

### Cleaning Project Dependencies
Deletes the local `modules/` folder and `boss-lock.json` file to reset dependencies of the current project:
```bash
boss4d clean
```

---

## 15. Deterministic builds and scaffolding

```powershell
boss4d new app MyConsole
boss4d new package MyLibrary --path D:\work\MyLibrary
```

`--platform` overrides `toolchain.platform`, followed by the first
`engines.platforms` entry and Win32. `toolchain.compiler` selects RAD Studio.
An ordered `projects` array may contain `.dproj`, `.lpi`, or `.lpk`; paths must
remain inside the package root. Delphi uses MSBuild and Lazarus requires
`lazbuild` on `PATH`. Text sources are normalized before checksum verification.

See [the complete guide](build-improvements.md) and
[copyable example](../examples/build-improvements/README.md).

---

## 🖥️ 16. Standalone Graphical User Interface (GUI)

The **Boss4D** graphical user interface (**`Boss4D.GUI.exe`**) provides a modern, user-friendly desktop application integrated in-process with the Boss4D business logic engine.

### How to Access
* The installer creates optional shortcuts on the **Desktop** and in the **Start Menu** (folder `Boss4D`).
* You can also run it by typing `Boss4D.GUI` in any command terminal (as the PATH will be configured).

### Key Features
1. **Lateral Navigation (SPA Sidebar)**:
   * **Project Local**: Open any local project directory. Boss4D reads the `boss.json` and lists the package dependencies, declared version, and installed lock version in real-time. Features quick buttons for `Init`, `Install`, `Check Updates` (outdated), and `Dependency Tree`.
   * **Search Packages**: A visual catalogue showing the most popular libraries in the Delphi community (Horse, RESTRequest4Delphi, mORMot, Skia, etc.) allowing for filtered search and single-click silent in-process installation.
   * **Boss4D Doctor**: Run environmental diagnostics and auto-fixes for Delphi compiler installations without writing command lines.
   * **Manage Cache**: Displays global cache disk usage and provides options to clean (`Clean`) or prune (`Otimizar Cache`) stale downloaded versions.
2. **Integrated Log Console**: The bottom area prints real-time logs, compilation outputs, and concurrent download tasks running in background threads (via PPL) in a thread-safe UI component.

---

## 🔌 17. RAD Studio IDE Integration (Plugin)

The integrated RAD Studio wizard adds tools and menu options to speed up package management workflow:

### Key Features
1. **Project Manager Context Menus**:
   * Right-click any active project `.dproj` or project group `.groupproj` in the Project Manager, and navigate to **Boss4D**.
   * Run quick commands (`Init`, `Install`, `Doctor`, `Cache`, `Licensing`) directly inside the IDE.
2. **Dynamic Script Submenus**:
   * The plugin reads the customized scripts defined under the `"scripts"` section in your project's `boss.json` (e.g. `"build"`, `"test"`, `"deploy"`).
   * It dynamically registers submenus for each script under **Boss4D -> Scripts**, allowing you to execute tasks with a single click and review the terminal outputs in real-time.
3. **Install Package Dialog**:
   * The **Install Package...** option opens an integrated prompt window to capture the Git repository URL and version range, triggering a silent, background package installation.
4. **Integrated Message View**: The progress and colored log messages of the Boss4D tasks are piped into a dedicated **Boss4D** tab inside the RAD Studio Message View.
