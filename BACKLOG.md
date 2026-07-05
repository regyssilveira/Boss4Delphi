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
