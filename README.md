# Boss4D

<p align="center">
  <img src="docs/imgs/header_boss4d.jpg" alt="Boss4D Header" width="100%">
</p>

[Read in English](README.md) | [Leia em Português](README.pt-BR.md)

**Boss4D** is a native, modern dependency manager for Delphi projects, built from scratch with a primary focus on **Delphi 13 and newer**. It is a direct and optimized migration of the original [HashLoad BOSS](https://github.com/HashLoad/boss) (originally written in Go), bringing dependency management natively to the Delphi ecosystem.

---

## ⚡ Key Features

1. **Native & Lightweight**: Single executable compiled natively in Delphi, with zero external dependencies or Go runtime requirements.
2. **Hexagonal Architecture (Ports & Adapters)**: Rigorous separation between core domain logic (package rules), use case services, and infrastructure adapters (Git, HTTP, and Compiler).
3. **Concurrent Downloads**: Employs Delphi's **Parallel Programming Library (PPL)** (`TTask` and `TParallel`) to download and clone multiple package dependencies concurrently during the installation phase.
4. **Command Buffer Overflow Prevention**: Implements the `@boss.cfg` configuration file technique to pass search paths directly to MSBuild, avoiding the Windows command-line 8191-character limit (Issue #205).
5. **Multi-path mainsrc Support**: Fully supports multiple paths separated by semicolons in the `mainsrc` option (aligned with BOSS Go PR #256).
6. **Thread-Safe Colored Logging**: Outputs clean, colored console logs asynchronously using critical sections, with optional `.log` file persistence for debug mode.
7. **100% Testable**: Comprehensive DUnitX unit-testing suite using Mock adapters to isolate network (HTTP), Git processes, and compiler executions.

---

## 🤝 Drop-in Compatibility with Original BOSS

**Boss4D** is designed to be a direct drop-in replacement for the classic HashLoad BOSS dependency manager. This means:
* **Same File Formats**: Boss4D reads, edits, and writes the exact same `boss.json` and `boss-lock.json` manifests used by the community.
* **Identical Directory Structure**: All project dependencies continue to be resolved locally under the `modules/` folder.
* **Backward Compatibility**: Delphi projects originally managed with the Go-based BOSS can transition to Boss4D instantly, with no structural or code changes required.

---

## 📂 Project Directory Structure

```text
Boss4D/
├── src/
│   ├── Core/
│   │   ├── Domain/       # Domain entities and validation (SemVer, Dependency, Package, Lock)
│   │   ├── Ports/        # Deserialized Ports (interfaces) decoupling logic and infrastructure
│   │   └── Services/     # Use cases (Init, Config, Install)
│   ├── Adapters/         # Concrete adapters (Json, Http, Git, Registry, Compiler, Logger)
│   ├── CLI/              # Command line argument parser
│   └── Boss4D.dpr        # Executable console entry point
└── tests/                # DUnitX test project, mocks, and suites
```

---

## 🚀 Compiling and Validating the Project

Since Boss4D is written in modern Delphi, you can build it in two ways:

### 1. Via the RAD Studio IDE
* Open the production project **`src/Boss4D.dproj`** or the test project **`tests/Boss4DTests.dproj`** in the IDE.
* Press **Ctrl + F9** to build.
* Press **F9** on the test project to run the DUnitX test runner.

### 2. Via RAD Studio Command Prompt
Open the RAD Studio Command Prompt and navigate to the project directory:

```cmd
cd /d d:\Projetos\BossDelphi
```

* **To compile and run the unit test suite**:
  ```cmd
  msbuild tests\Boss4DTests.dpr /p:Configuration=Debug
  tests\Win32\Debug\Boss4DTests.exe
  ```

* **To compile the production CLI**:
  ```cmd
  msbuild src\Boss4D.dpr /p:Configuration=Release
  ```

---

## 📚 Supported Commands

* `boss4d init`
  Interactively initializes a new `boss.json` file in the current directory.
  * *Flags*: `-q`, `--quiet` (creates a default file silently).
* `boss4d install`
  Reads the local `boss.json`, resolves the dependency graph recursively using SemVer, downloads modules to the `modules/` folder, updates `boss-lock.json`, and triggers compilation.
* `boss4d install <url>@<version>`
  Adds and installs a specific package dependency.
  * *Example*: `boss4d install github.com/hashload/horse@^3.1.0`
  * *Git references*: Supports tags, branches (e.g. `@master`), or commit hashes.
* `boss4d config delphi use <path_or_release_version>`
  Sets the global path or the release version (e.g. "23.0", "22.0") of the Delphi installation directory for MSBuild. If not specified, the compiler adapter will automatically detect the latest installed Delphi version.
* `boss4d config git shallow <true/false>`
  Enables or disables shallow clones for faster Git download processes.
* `boss4d version`
  Prints the CLI version (`v1.0.0-delphi-native`).
* `boss4d help`
  Prints the CLI help menu.

---

## 📖 Additional Documentation
* **[CLI Usage Manual](docs/usage.md)**: Detailed step-by-step guide covering all command options and dependency configurations.
* **[Contribution Guide](CONTRIBUTING.md)**: Coding standards and guidelines for contribution.
* **[Release Guide](RELEASE_GUIDE.md)**: Steps and instructions to compile with Delphi 13 (37.0) and publish releases on GitHub.
* **[Project Backlog](docs/backlog.md)**: Future features, CLI diagnostics (`boss4d doctor`), visual interface (GUI), and RAD Studio integration roadmap.
* **[Backlog Prioritization](docs/backlog_prioritization.md)**: Technical ROI analysis prioritizing the 15 project epics.

---

## ❤️ Special Thanks

This project is a direct evolution and native port of the original **[HashLoad BOSS](https://github.com/HashLoad/boss)**. We express our sincere gratitude and recognition to the **HashLoad** team and all their contributors for their brilliant initiative in introducing a modern package management ecosystem to the global Delphi community.

