# Boss4D

<p align="center">
  <img src="docs/imgs/header_boss4d.jpg" alt="Boss4D Header" width="100%">
</p>

O **Boss4D** é um gerenciador de dependências nativo e moderno para projetos Delphi, desenvolvido do zero com foco em **Delphi 13 em diante**. Ele é uma migração direta e otimizada do projeto original [HashLoad BOSS](https://github.com/HashLoad/boss) (escrito originalmente em Go), tornando-o nativo da própria plataforma para a qual é utilizado.

---

## ⚡ Diferenciais do Boss4D

1. **Nativo e Leve**: Executável único compilado nativamente em Delphi, com zero dependências externas ou runtime Go.
2. **Arquitetura Hexagonal (Ports & Adapters)**: Rigorosa separação entre o domínio (regras de negócio do pacote), os serviços e a infraestrutura (adaptadores de Git, HTTP e Compilador).
3. **Downloads Concorrentes**: Utiliza a biblioteca **PPL (Parallel Programming Library)** do Delphi (`TTask` e `TParallel`) para baixar e clonar múltiplos pacotes simultaneamente na fase de instalação.
4. **Prevenção de Comandos Longos e Múltiplos Caminhos**: Adota a técnica do arquivo `boss.cfg` temporário (evitando estouro da linha de comando no Windows - Issue #205) e suporta múltiplos caminhos separados por ponto-e-vírgula no `mainsrc` (alinhado ao PR #256 do BOSS Go).
5. **Logs Avançados e Thread-Safe**: Saída do console colorida de forma assíncrona usando semáforos críticos, com gravação opcional de arquivos `.log` em modo debug.
6. **100% Testável**: Suíte de testes unitários que utiliza injeção de dependências e classes Mock para simular Git, HTTP e compilador sem necessitar de conexões de rede ou ferramentas instaladas no ambiente de testes.

---

## 🤝 Compatibilidade Total com o BOSS Original

O **Boss4D** foi projetado para ser um substituto direto (*drop-in replacement*) para o gerenciador BOSS clássico da HashLoad. Isso significa que:
* **Mesmo Formato de Arquivos**: O Boss4D lê, edita e gera os mesmos manifestos `boss.json` e `boss-lock.json` utilizados pela comunidade.
* **Estrutura de Pastas Idêntica**: As dependências continuam sendo salvas localmente na pasta `modules/`.
* **Compatibilidade Retroativa**: Projetos Delphi criados originalmente usando o BOSS clássico em Go podem ser migrados e mantidos com o Boss4D imediatamente, sem necessidade de qualquer alteração estrutural no projeto.

---

## 📂 Estrutura de Diretórios

O código fonte está estruturado da seguinte forma:

* **`src/`**: Código fonte da aplicação de produção.
  * **`Core/Domain/`**: Modelos puros e regras de negócio (`SemVer`, `Dependency`, `Package`, `Lock`, `Consts`, `Env`).
  * **`Core/Ports/`**: Definição das interfaces desacopladas (Ports).
  * **`Core/Services/`**: Casos de uso centrais (`Init`, `Config`, `Install`).
  * **`Adapters/`**: Implementações de infraestrutura (`Json` usando `System.JSON`, `Http` usando `THTTPClient`, `Git` usando subprocessos CLI, `Registry` do Windows, `Compiler` usando MSBuild e `Logger` console).
  * **`CLI/`**: Parser de argumentos e orquestrador de comandos da linha de comando.
* **`tests/`**: Suíte de testes automatizados usando o framework **DUnitX**.

---

## 🚀 Como Compilar e Validar o Projeto

Como o Boss4D é escrito no Delphi moderno, você pode compilá-lo de duas formas:

### 1. Pela IDE do Delphi 13
* Abra o projeto de produção **`src/Boss4D.dproj`** ou o de testes **`tests/Boss4DTests.dproj`** diretamente na IDE.
* Pressione **Ctrl + F9** para compilar.
* Pressione **F9** no projeto de testes para executar as suites do DUnitX no terminal integrado.

### 2. Pelo Prompt de Comando do RAD Studio
Abra o prompt de comando do RAD Studio no menu iniciar (o qual inicializa os caminhos das ferramentas como o MSBuild) e navegue até a raiz do projeto:

```cmd
cd /d d:\Projetos\BossDelphi
```

* **Para compilar e executar a suíte de testes unitários**:
  ```cmd
  msbuild tests\Boss4DTests.dpr /p:Configuration=Debug
  tests\Win32\Debug\Boss4DTests.exe
  ```

* **Para compilar o executável final de produção**:
  ```cmd
  msbuild src\Boss4D.dpr /p:Configuration=Release
  ```
  O executável `Boss4D.exe` será gerado sob a pasta `src\Win32\Release\` (ou `Win64` dependendo da plataforma selecionada).

---

## 📚 Comandos Suportados

* `boss4d init`
  Inicializa um novo arquivo `boss.json` no diretório atual de forma interativa.
  * *Flags*: `-q`, `--quiet` (inicializa de forma silenciosa com dados padrão).
* `boss4d install`
  Faz a leitura do `boss.json` do diretório atual, resolve a árvore recursiva de versões do SemVer e instala todas as dependências na pasta `modules/`, atualizando o `boss-lock.json` e executando a compilação paralela.
* `boss4d install <url>@<versao>`
  Adiciona e instala uma dependência específica ao projeto.
  * *Exemplo*: `boss4d install github.com/hashload/horse@^3.1.0`
* `boss4d config delphi use <caminho_ou_versao>`
  Configura o caminho global do Delphi ou a versão de release (ex: "23.0", "22.0") para a compilação do MSBuild. Se não configurado, o resolvedor autodetecta dinamicamente a versão mais recente instalada.
* `boss4d config git shallow <true/false>`
  Habilita ou desabilita o uso de clones rasos (shallow clone) para downloads mais velozes.
* `boss4d version`
  Exibe a versão atual do Boss4D (`v1.1.0-delphi-native`).
* `boss4d sbom --format cyclonedx|spdx --output <arquivo> --validate`
  Gera CycloneDX 1.7 ou SPDX 2.3 usando `boss.json` e `boss-lock.json` v2.
  Com `--lock-only`, gera um SBOM reproduzível de release usando apenas as
  evidências da raiz e das dependências gravadas no lock. Coletores opcionais
  adicionam inventário GetIt, proveniência do compilador/RTL Delphi e hashes dos
  artefatos declarados. CycloneDX também aceita VEX offline e ambos os formatos
  suportam atestações SHA-256 destacadas. Consulte o
  [guia SBOM](docs/usage.pt-BR.md#71-geração-de-sbom-sbom), os
  [exemplos copiáveis](docs/sbom-examples.pt-BR.md) e o
  [guia de migração v2](docs/sbom-migration.pt-BR.md).
* `boss4d help`
  Exibe o menu de ajuda com todos os comandos descritos em português.

---

## 📖 Documentação Adicional
* **[Manual de Uso da CLI](docs/usage.pt-BR.md)**: Guia completo detalhado de todos os parâmetros e opções de instalação de dependências.
* **[Guia de Contribuição](CONTRIBUTING.pt-BR.md)**: Padrões de código e fluxo de desenvolvimento para contribuir com o projeto.
* **[Guia de Lançamento de Release](RELEASE_GUIDE.md)**: Passos e instruções para compilar com Delphi 13 (37.0) e publicar releases no GitHub.
* **[Backlog do Projeto](docs/backlog.pt-BR.md)**: Planejamento futuro de novas funcionalidades, diagnóstico CLI (`boss4d doctor`), interface visual (GUI) e integração com o RAD Studio.
* **[Priorização do Backlog](docs/matriz_priorizacao.pt-BR.md)**: Análise de ROI técnico priorizando os épicos do projeto.

---

## ❤️ Agradecimentos Especiais

Este projeto é uma evolução direta e migração nativa do **[HashLoad BOSS](https://github.com/HashLoad/boss)** original. Expressamos nossa sincera gratidão e reconhecimento à equipe da **HashLoad** e a todos os seus contribuidores pela brilhante iniciativa de introduzir um ecossistema moderno de gerenciamento de pacotes para a comunidade Delphi mundial.
