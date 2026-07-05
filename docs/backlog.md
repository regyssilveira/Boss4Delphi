# Boss4D Development Backlog

This document details the future planning, new features (backlog), and architectural evolution of **Boss4D**, based on community feedback and best practices in the Delphi ecosystem (inspired by tools such as *TMS Smart Setup*).

---

## 🗺️ Epic 1: Visual Interface (Boss4D GUI)
*Objective: Provide a visual and user-friendly alternative for developers who prefer not to use the command line.*

- [ ] **[Story] Native Desktop Interface (VCL / FMX)**
  - Create a standalone visual executable (`boss4d-gui.exe`) in native Delphi to manage projects.
- [ ] **[Story] Project and Dependency Management**
  - Screens to open Delphi project folders, view the current `boss.json` manifest, and manage packages.
- [ ] **[Story] Public Package Catalog and Search**
  - Create a discovery panel for popular packages (e.g., Horse, Dext, RESTRequest4Delphi, mORMot) allowing one-click installation.
- [ ] **[Story] Visual Compilation Logs Panel**
  - Display the progress of parallel download tasks and compilation logs in rich visual components with progress indicators and warnings.

---

## 🔌 Epic 2: RAD Studio IDE Integration (Plugin / Wizard)
*Objective: Integrate the dependency manager directly into the developer's workflow inside RAD Studio.*

- [ ] **[Story] Context Menu in the Project Manager**
  - Add "Boss4D Init" and "Boss4D Install" options to the right-click menu of the Delphi IDE Project Manager.
- [ ] **[Story] IDE Package Manager Wizard**
  - Create an internal Wizard (Plugin via Delphi ToolsAPI) to search for and manage packages directly from within the IDE.
- [ ] **[Story] Keyboard Shortcuts and Build Bindings**
  - Synchronize dependency builds with native IDE compilation keyboard shortcuts.

---

## 🩺 Epic 3: Self-Diagnosis Tool (`boss4d doctor`)
*Objective: Automatically identify and resolve compiler paths, environment variables, and local Git tool issues (Inspired by `tms doctor`).*

- [ ] **[Story] CLI Command `boss4d doctor`**
  - Analyze the developer's local environment, verifying:
    * Active Delphi installations and Registry paths.
    * Presence and version of the `dcc32`, `dcc64`, and `MSBuild` compilers.
    * Accessibility of the `git` executable in the system PATH.
    * Read and write folder permissions.
- [ ] **[Story] Auto-Correction of Paths (`boss4d doctor -fix`)**
  - Implement the ability to inject and correct Registry paths or the user's local PATH to automatically restore compilation functionality.

---

## ⚙️ Epic 4: IDE Component and Library Path Integration
*Objective: Automate post-install configuration tasks of Design-time components inside the Delphi component palette.*

- [ ] **[Story] Design-Time BPL Injection and Registration**
  - Parse newly downloaded dependencies, locate generated Design-time BPLs, and register them in the Delphi Windows Registry (`HKEY_CURRENT_USER\Software\Embarcadero\BDS\<version>\Known Packages`) so components show up in the IDE palette automatically.
- [ ] **[Story] Automatic IDE Library Path Management**
  - Intelligently inject unified DCU folders (`modules/dcu`) or search paths into the developer's global RAD Studio Library Path, eliminating the need to configure search paths manually.
- [ ] **[Story] DCU Megafolders and Cache Optimization**
  - Optimally unify compiled project files into centralized folders grouped by platform/configuration, improving subsequent build times.

---

## 📜 Epic 5: Custom Script Execution (`boss4d run <script>`)
*Objective: Allow automation and standardization of tasks and workflows in Delphi projects (Inspired by `npm run` from Node.js).*

- [ ] **[Story] Script Declaration in `boss.json`**
  - Add support for a `"scripts": { "build": "msbuild ...", "test": "Win32\\Debug\\Tests.exe" }` block in the project manifest.
- [ ] **[Story] CLI Command `boss4d run <script>`**
  - Execute the specified script by invoking the correct subprocess in the Windows shell, seamlessly forwarding output logs and exit error codes.

---

## 🛠️ Epic 6: Global CLI Tool Distribution (`boss4d tool`)
*Objective: Allow Delphi developers to install and use development utilities globally on their machine (Inspired by `dotnet tool` from .NET).*

- [ ] **[Story] Global Tool Installation (`boss4d tool install -g <repo>`)**
  - Download, compile, and register Delphi-based utility executables (e.g., code formatters, code generators, linters) in the Windows PATH.
- [ ] **[Story] Tool Version Management**
  - Allow upgrading (`boss4d tool update`) and uninstalling (`boss4d tool uninstall`) global utilities.

---

## 🌳 Epic 7: Advanced Dependency Diagnostics (`boss4d tree` / `outdated`)
*Objective: Provide deep visibility into the transitive dependency tree and package update status (Inspired by `cargo tree` from Rust and `pub outdated` from Dart/Flutter).*

- [ ] **[Story] Dependency Tree Visualization (`boss4d tree`)**
  - Graphically print the project's dependency structure in the console, highlighting which sub-dependencies belong to which packages and resolving visual conflicts.
- [ ] **[Story] Outdated Packages Report (`boss4d outdated`)**
  - Asynchronously query GitHub for the latest SemVer-compatible tags for each dependency, generating a table displaying the current version, compatible declared version, and latest available version.

---

## 🗂️ Epic 8: Workspaces and Multi-Project Support (Monorepos)
*Objective: Simplify maintenance of multiple local Delphi projects sharing common dependencies under the same repository (Inspired by Rust/npm Workspaces).*

- [ ] **[Story] Workspaces Manifesto in root `boss.json`**
  - Support declaring `"workspaces": [ "projects/*" ]` in the root repository manifest.
- [ ] **[Story] Intelligent Folder Sharing for `modules/`**
  - Prevent redundant downloads and builds by centralizing all dependencies in the root `modules/` folder, with the resolver automatically mapping relative references for internal subprojects.
