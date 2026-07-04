# Contributing to Boss4D

[Read in English](CONTRIBUTING.md) | [Leia em Português](CONTRIBUTING.pt-BR.md)

Thank you for your interest in contributing to **Boss4D**! This guide is designed to help developers and AI agents configure the local environment, understand our architecture, and submit changes in compliance with our code quality standards.

---

## 🏛️ 1. Architecture (Hexagonal)

Boss4D is built under the principles of **Hexagonal Architecture (Ports & Adapters)**. This guarantees full decoupling between business rules and infrastructure details (such as networks, terminal consoles, compilers, and Windows registry).

* **Core/Domain**: Contains pure business entities (`SemVer`, `Dependency`, `Package`, `Lock`). **It must not import any infrastructure units or concrete adapters (do not import System.JSON, Registry, or Git)**.
* **Core/Ports**: Defines interfaces (`IBoss4DLogger`, `IBoss4DGitClient`, etc.) serving as communication contracts.
* **Core/Services**: CLI use cases orchestrating workflow logic calling exclusively Port interfaces via dependency injection.
* **Adapters**: Concrete infrastructure adapters (e.g. `TBoss4DHttpNativeAdapter` implementing `IBoss4DHttpClient`).

---

## 🎨 2. Delphi Style Guide

To maintain repository consistency, follow these Delphi coding guidelines:

### Prefix and Naming Standards
* **Classes**: Must start with `T` (e.g. `TBoss4DPackage`).
* **Interfaces**: Must start with `I` (e.g. `IBoss4DLogger`).
* **Method Arguments**: Must start with `A` (e.g. `const AVersionStr: string`).
* **Local Variables**: Must start with `L` (e.g. `var LResolvedVersion: string`).
* **Private Fields**: Must start with `F` (e.g. `FLogger: IBoss4DLogger`).

### Syntax & Formatting
* **Indentation**: 2 spaces.
* **Inline Variables**: Use Delphi inline variables and type inference where possible (e.g. `var LVal := LJSONObj.FindValue('name');`).
* **Clean Code**: Keep procedures and functions small and focused on a single responsibility.

### Resource Allocation and try..finally
* **try..finally**: Always wrap local object creation in `try..finally` blocks to guarantee resource release and prevent memory leaks:
  ```pascal
  var LPkg := TBoss4DPackage.Create;
  try
    // Logic goes here
  finally
    LPkg.Free;
  end;
  ```
* **Dictionaries**: If using `TObjectDictionary`, initialize it with `TMapOption.doOwnsValues` to automatically release entries.

---

## 🧪 3. Work Cycle for Bug Fixes (Mandatory TDD)

To maintain a robust codebase, we enforce a strict **TDD for Bugs** cycle:

1. **Write a Failing Unit Test**: Before modifying any production code, add a test case in the corresponding **DUnitX** suite (located in `tests/`) that replicates the bug. This test **must fail** on its initial execution.
2. **Implement the Fix**: Modify production files under `src/` until the test passes.
3. **Verify the Suite**: Ensure all 28 tests continue to pass with zero memory leaks.

---

## 🚀 4. How to Compile and Run Tests Locally

Verify your changes before submitting:

### Running Tests (DUnitX) via RAD Studio Command Prompt
```cmd
msbuild tests\Boss4DTests.dpr /p:Configuration=Debug
tests\Win32\Debug\Boss4DTests.exe
```

### Compiling the Release CLI
```cmd
msbuild src\Boss4D.dpr /p:Configuration=Release
```

---

## 📝 5. Submitting Pull Requests

Fill out the checklist in `.github/pull_request_template.md` when opening a PR to verify your code follows these guidelines.
