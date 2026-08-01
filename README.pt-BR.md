# Boss4D

<p align="center">
  <img src="docs/imgs/header_boss4d.jpg" alt="Boss4D Header" width="100%">
</p>

O **Boss4D** é um gerenciador de dependências nativo e moderno para projetos
Delphi e Lazarus. A CLI Windows é compilada com Delphi 13, o plugin da IDE tem
como alvo os Delphi 10/10.1 e é validado localmente com Delphi 10, 11, 12 e 13, e a
CLI Linux x86-64 é compilada nativamente com FPC 3.2.2.

---

## ⚡ Diferenciais do Boss4D

1. **Nativo e Leve**: Executáveis compilados nativamente em Delphi ou FPC, sem
   runtime Go. Operações específicas usam ferramentas do host como Git,
   MSBuild, `lazbuild`, GnuPG ou Secret Service.
2. **Arquitetura Hexagonal (Ports & Adapters)**: Rigorosa separação entre o domínio (regras de negócio do pacote), os serviços e a infraestrutura (adaptadores de Git, HTTP e Compilador).
3. **Downloads Concorrentes**: Utiliza a biblioteca **PPL (Parallel Programming Library)** do Delphi (`TTask` e `TParallel`) para baixar e clonar múltiplos pacotes simultaneamente na fase de instalação.
4. **Prevenção de Comandos Longos e Múltiplos Caminhos**: Adota a técnica do arquivo `boss.cfg` temporário (evitando estouro da linha de comando no Windows - Issue #205) e suporta múltiplos caminhos separados por ponto-e-vírgula no `mainsrc` (alinhado ao PR #256 do BOSS Go).
5. **Logs Avançados e Thread-Safe**: Saída do console colorida de forma assíncrona usando semáforos críticos, com gravação opcional de arquivos `.log` em modo debug.
6. **100% Testável**: Suíte de testes unitários que utiliza injeção de dependências e classes Mock para simular Git, HTTP e compilador sem necessitar de conexões de rede ou ferramentas instaladas no ambiente de testes.
7. **Build Determinístico**: Diretórios sem colisão, ordem declarada de projetos, precedência de toolchain e normalização CRLF segura.
8. **Projetos Delphi e Lazarus**: Compila `.dproj`, `.lpi` e `.lpk` declarados
   usando MSBuild ou `lazbuild` e integra automaticamente os paths das
   dependências nos projetos e modos de build do Lazarus.
9. **Matriz Multi-Delphi**: Declara Delphi 10/10.1/11/12/13, Win32/Win64,
   Debug/Release, projetos runtime/design, dependências, artefatos isolados,
   rebuild incremental, paralelismo seguro e registro transacional na IDE sem
   quebrar manifests legados.

---

## 🤝 Compatibilidade com projetos BOSS

O **Boss4D** aceita manifestos legados como caminho de migração sem exigir uma
reestruturação do projeto:
* **Manifesto Compatível**: O Boss4D lê e preserva os mapas string/string do
  `boss.json` usados pelo BOSS.
* **Estrutura de Pastas Idêntica**: As dependências continuam sendo salvas localmente na pasta `modules/`.
* **Lock Evolutivo**: Locks antigos continuam legíveis, mas o `boss-lock.json`
  v3 acrescenta escopos, checksums, grafo e evidências próprias do Boss4D; essa
  extensão não implica compatibilidade bidirecional com outras ferramentas.

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
* Abra **`src/Boss4D.dpr`** ou **`tests/Boss4DTests.dpr`** na IDE; o RAD Studio cria os metadados locais do projeto quando necessário.
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
* `boss4d add|remove|update|list|why`
  Gerencia e consulta todo o ciclo de vida das dependências, com rollback
  automático de `boss.json`, `boss-lock.json` e `modules/` em caso de falha.
  Consulte o [guia do ciclo de vida](docs/dependency-lifecycle.pt-BR.md).
* `boss4d package versions`, `pin|unpin`, `upgrade|downgrade` e `rollback`
  Oferece seleção SemVer determinística, pins exatos, snapshots duráveis do
  histórico de versões e recuperação transacional. Consulte
  [gerenciamento de versões](docs/version-management.pt-BR.md).
* `boss4d ci` / `boss4d install --locked|--frozen-lockfile|--offline|--production [--jobs <n>]`
  Executa instalações reproduzíveis com CI limpo, cache offline e dependências
  somente de produção.
* `boss4d dependencies|tree|why|outdated` e `boss4d run <script>`
  Inspeciona o grafo, explica dependências, encontra atualizações e executa
  scripts do manifesto.
* `boss4d registry add|remove|list|health`, `search` e `info`
  Gerencia fontes públicas/privadas, audita o catálogo Registry v1/v2 completo
  e consulta seus pacotes. O catálogo atual contém 55 pacotes: 16 releases
  schema v2 assinadas e 39 entradas legadas de descoberta.
* `boss4d package install <nome>@<versão>` e `boss4d pack`
  Instala ou produz `.b4dpkg` determinísticos com seleção por compilador e
  plataforma, SHA-256, OpenPGP e proveniência in-toto.
* `boss4d publish [--dry-run]`, `boss4d publish --official --open-pr` e
  `boss4d conformance registry|package <arquivo>`
  Publica versões imutáveis, atualiza um checkout limpo e abre a PR revisada
  do Registry público.
* `boss4d audit [--fail-on <severidade>]`
  Consulta vulnerabilidades OSV das revisões travadas, com cache offline e VEX.
* `boss4d doctor`, `cache`, `tool`, `plugin`, `getit` e `license report`
  Cobre diagnóstico, cache, ferramentas globais, integrações Windows e licenças.
  A Central de Saúde da GUI agrupa as verificações de ambiente e oferece
  remediação, auto-correção, reparo/undo da IDE e otimização de cache.
* `boss4d doc [-o <diretório>] [--no-dependencies]`
  Gera um site pesquisável usando comentários PascalDoc/XML Doc do projeto e
  das dependências instaladas. Consulte o
  [guia de documentação estática de APIs](docs/api-documentation.pt-BR.md).
* `boss4d spec --detect [--compiler <versão>]`
  Detecta `.dproj`/`.dpk`, diretivas runtime/design e dependências locais,
  persistindo uma `buildMatrix` determinística.
* `boss4d build [--compiler <versão>|all] [--platform Win32|Win64|all]`
  `[--configuration Debug|Release|all] [--jobs <n>] [--force] [--full]`
  `[--explain] [--register]`
  Executa a matriz selecionada com outputs isolados, rebuild incremental,
  paralelismo seguro pelo grafo, explicações e registro exato opcional.
* `boss4d support [--compiler <versão>|all] [--platform <target>|all]`
  `[--kind runtime|design|application|tool|binary] [--project <path>]`
  Informa `certified`, `compatible`, `experimental` ou `unsupported` para a
  combinação solicitada.
* `boss4d ide unregister <pacote> --compiler <versão> --platform <plataforma>`
  e `boss4d ide repair`
  Removem um registro exato ou reconciliam divergências transacionalmente.
* `boss4d ide profile list|create|show|target|clone|remove|export|import|launch`,
  `snapshot|diff|restore|history|undo` e
  `preview-install|install|repair|preview-uninstall|uninstall`
  Gerencia Registry branches isolados do RAD Studio e executa instalação
  transacional de produtos com preview. A GUI apresenta o diário imutável de
  operações como uma linha do tempo estruturada com evidências de recuperação
  e desfazer, além de um dashboard de perfis com drift real, comparação de
  produtos instalados e abertura direta da IDE isolada. A instalação de
  componentes usa uma confirmação guiada explícita para perfil, package,
  políticas, targets exatos, Registry branch e mudanças transacionais, seguida
  por progresso determinado e saída estruturada ao vivo. O console estruturado
  oferece filtros por severidade, pesquisa, foco nos erros e exportação de
  diagnóstico em JSON. Consulte o
  [guia de perfis e componentes](docs/ide-component-management.pt-BR.md).
* `boss4d config delphi use <caminho_ou_versao>`
  Configura o caminho global do Delphi ou a versão de release (ex: "23.0", "22.0") para a compilação do MSBuild. Se não configurado, o resolvedor autodetecta dinamicamente a versão mais recente instalada.
* `boss4d config git shallow <true/false>`
  Habilita ou desabilita o uso de clones rasos (shallow clone) para downloads mais velozes.
* `boss4d version`
  Exibe a versão atual do Boss4D (`v1.6.0-delphi-native`).
* `boss4d self-update`
  Atualiza Windows ou Linux com os arquivos oficiais, verificação por
  `SHA256SUMS.txt`, staging transacional e rollback.
* `boss4d new <template> <nome> [--path <diretório>]`
  Cria projetos Delphi, VCL, FMX, API Horse+Dext, DUnitX, Lazarus ou workspace
  sem sobrescrever um diretório não vazio.
* `boss4d sbom --format cyclonedx|spdx --output <arquivo> --validate`
  Gera CycloneDX 1.7 ou SPDX 2.3 usando `boss.json` e `boss-lock.json` v3.
  Com `--lock-only`, gera um SBOM reproduzível de release usando apenas as
  evidências da raiz e das dependências gravadas no lock. Coletores opcionais
  adicionam inventário GetIt, proveniência do compilador/RTL Delphi e hashes dos
  artefatos declarados. CycloneDX também aceita VEX offline e ambos os formatos
  suportam atestações SHA-256 destacadas. Consulte
  [por que e como funciona o suporte SBOM](docs/sbom.pt-BR.md), a
  [referência da CLI](docs/usage.pt-BR.md#71-geração-de-sbom-sbom), os
  [exemplos copiáveis](docs/sbom-examples.pt-BR.md) e o
  [guia de migração v3](docs/sbom-migration.pt-BR.md).
* `boss4d help`
  Exibe o menu de ajuda com todos os comandos descritos em português.

---

## 📖 Documentação Adicional
* **[Comece pelo seu Caso de Uso](docs/use-cases.pt-BR.md)**: Fluxos cotidianos orientados a risco para dependências, credenciais de Registry, publicação, conformidade, builds Multi-Delphi, recuperação da IDE, Linux, CI, releases e autoatualização.
* **[Guia da Feature SBOM](docs/sbom.pt-BR.md)**: Motivação, modelo de evidências, cobertura, VEX, atestações, limites e fluxo recomendado de release.
* **[Melhorias de Build Determinístico](docs/build-improvements.pt-BR.md)**: Paths sem colisão, toolchains, projetos declarados, Lazarus, scaffolding e normalização.
* **[Guia e Contrato da Matriz de Build](docs/build-matrix-contract.pt-BR.md)**: Schema, fluxo da CLI, convenções, migração, diagnóstico, troubleshooting e critérios para builds Delphi multiversão.
* **[Build de Componentes e Ciclo de Vida da IDE](docs/component-build-and-ide.pt-BR.md)**: Guia completo de tipos, níveis de suporte, cache compartilhado, ativos da IDE, conflitos, reparo ativo e remoção segura.
* **[Perfis da IDE e Gerenciamento de Componentes](docs/ide-component-management.pt-BR.md)**: Registry branches isolados, produtos runtime/design, vínculo por projeto, snapshots, drift, restauração/undo, fluxos CLI/GUI e exemplos cotidianos.
* **[Ciclo de Vida de Dependências](docs/dependency-lifecycle.pt-BR.md)**: Add, update e remove transacionais, além de list e why baseados no grafo.
* **[Instalação Reproduzível](docs/reproducible-install.pt-BR.md)**: Lock congelado, cache offline, instalação limpa em CI e garantias de rollback.
* **[Escopos de Dependências](docs/dependency-scopes.pt-BR.md)**: `devDependencies`, instalação de produção, lock v3 e escopo no SBOM.
* **[Auditoria de Vulnerabilidades](docs/audit.pt-BR.md)**: OSV por commit, cache offline, políticas de severidade e VEX.
* **[Política de Confiança Git](docs/trust-policy.pt-BR.md)**: Verificação de commits/tags assinados e signatários permitidos.
* **[Índices de Pacotes](docs/package-index.pt-BR.md)**: Registries
  públicos/privados, search/info, catálogo GUI rico, instalação guiada por
  versão/plataforma, progresso cancelável/retry e busca na IDE.
* **[GitHub Dependency Submission](docs/github-dependency-submission.pt-BR.md)**: Publicação do lock v3 no Dependency Graph.
* **[Estratégia de Cache](docs/cache-strategy.pt-BR.md)**: Reuso seguro de objetos Git e executáveis isolados por plataforma/compilador.
* **[Templates de Projeto](docs/templates.pt-BR.md)**: Presets Delphi, VCL, FMX, API Horse+Dext, DUnitX, Lazarus e workspace.
* **[Publicação de Pacotes](docs/publish.pt-BR.md)**: Dry-run, bloqueios de validação, tratamento do token e contratos dos registros público e privados.
* **[Portabilidade de Plataforma](docs/platform-portability.pt-BR.md)**: Contratos portáveis, paridade Linux atual e próximos alvos POSIX.
* **[Progresso no Terminal](docs/terminal-progress.pt-BR.md)**: Saída de progresso interativa, linear, JSON Lines e silenciosa para instalações e CI.
* **[Autoatualização Segura](docs/self-update.pt-BR.md)**: Descoberta de release, verificação SHA-256, staging e início do instalador.
* **[Matriz de Artefatos da Release](docs/release-artifact-matrix.pt-BR.md)**: Builders Windows/Linux, checksums, proveniência OIDC e gates de promoção.
* **[Onboarding de Publishers](docs/publisher-onboarding.pt-BR.md)**: Identidade, signatários e metadados imutáveis do Registry público.
* **[Plano de Migração do Registry](docs/registry-migration-plan.pt-BR.md)**: Ondas curadas para migrar descoberta legada para pacotes schema v2 assinados.
* **[Auditoria Final de Paridade](docs/parity-audit-2026-07-30.pt-BR.md)**: Evidência de implementação e verificação para cada requisito.
* **[Formato de Pacote Imutável](docs/package-format.pt-BR.md)**: `.b4dpkg` determinístico, instalação verificada, evidências OpenPGP/in-toto, fallback para fontes e variantes por compilador/plataforma.
* **[Compatibilidade com Delphi Legado](docs/legacy-delphi.pt-BR.md)**: Wizard moderno completo e perfis legados para Delphi 10 Seattle/BDS 17.0 e Delphi 10.1 Berlin/BDS 18.0.
* **[CLI FPC/Linux](docs/posix-cli.pt-BR.md)**: Build Linux nativo, ciclo de dependências, lock v3, CI frozen/offline, resolução SemVer e testes FPCUnit.
* **[Documentação Estática de APIs](docs/api-documentation.pt-BR.md)**: Motivação, sintaxe, declarações suportadas, varredura segura, uso em CI e limites atuais.
* **[Posicionamento competitivo](docs/competitive-positioning.pt-BR.md)**: Comparação baseada em evidências com BOSS, DPM, GetIt, OPM do Lazarus e ecossistemas maduros.
* **[Resolução e Credenciais Seguras](docs/resolution-and-credentials.pt-BR.md)**: Políticas SemVer highest/minimal e armazenamento nativo de segredos.
* **[Conformidade e Ecossistema](docs/conformance-and-ecosystem.pt-BR.md)**: Validação pública do protocolo, portal estático e benchmarks determinísticos.
* **[Manual de Uso da CLI](docs/usage.pt-BR.md)**: Guia completo detalhado de todos os parâmetros e opções de instalação de dependências.
* **[Guia de Contribuição](CONTRIBUTING.pt-BR.md)**: Padrões de código e fluxo de desenvolvimento para contribuir com o projeto.
* **[Guia de Lançamento de Release](RELEASE_GUIDE.md)**: Passos e instruções para compilar com Delphi 13 (37.0) e publicar releases no GitHub.
* **[Backlog do Projeto](docs/backlog.pt-BR.md)**: Estado consolidado das entregas e próximos investimentos em macOS, documentação, performance e ecossistema.
* **[Priorização do Backlog](docs/matriz_priorizacao.pt-BR.md)**: Análise de ROI técnico priorizando os épicos do projeto.

---

## ❤️ Agradecimentos Especiais

Este projeto é uma evolução direta e migração nativa do **[HashLoad BOSS](https://github.com/HashLoad/boss)** original. Expressamos nossa sincera gratidão e reconhecimento à equipe da **HashLoad** e a todos os seus contribuidores pela brilhante iniciativa de introduzir um ecossistema moderno de gerenciamento de pacotes para a comunidade Delphi mundial.
