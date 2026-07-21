# Exemplos de SBOM

Estes exemplos usam o comando `boss4d sbom` implementado pela CLI Delphi nativa.
Execute-os no diretório do projeto, salvo indicação contrária.

## Preparar evidências autoritativas no lock

```bash
boss4d install
```

Versione o `boss-lock.json` resultante. O schema v2 guarda metadados da raiz,
dependências diretas, revisões resolvidas, checksums tipados, licenças e arestas.

## Gerar um SBOM de desenvolvimento

Este modo lê `boss.json` e `boss-lock.json`:

```bash
boss4d sbom --format cyclonedx --output bom.cdx.json --validate
boss4d sbom --format spdx --output bom.spdx.json --validate
```

Sem `--output`, o JSON vai para a saída padrão. Diagnósticos permanecem na saída de
erro para não corromper um JSON redirecionado.

## Gerar SBOMs reproduzíveis de release apenas com o lock

O manifesto do projeto não é necessário neste modo:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible \
  --type application --output dist/sbom/app.cdx.json \
  --attestation-output dist/sbom/app.cdx.intoto.json

boss4d sbom --format spdx --lock-only --strict --validate --reproducible \
  --type application --output dist/sbom/app.spdx.json \
  --attestation-output dist/sbom/app.spdx.intoto.json
```

`--strict` recusa evidência incompleta de raiz, revisão, checksum, identidade ou
grafo. `--reproducible` remove identificadores/timestamps voláteis e estabiliza a
ordenação. O `--type` da raiz aceita `application`, `library` ou `framework`.

## Verificar atestações destacadas

Gere novamente o mesmo documento reproduzível e confronte-o com a atestação salva:

```bash
boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible \
  --type application --output dist/sbom/app.cdx.json \
  --verify-attestation dist/sbom/app.cdx.intoto.json
```

A verificação falha quando os bytes do SBOM divergem. A atestação atual, em envelope
in-toto Statement v1, registra o digest SHA-256: ela comprova integridade do conteúdo,
não identidade do emissor. Não é assinatura digital nem publicação em transparency log.

## Adicionar evidências controladas do ambiente de build

Coletores ambientais não podem ser combinados com `--lock-only`:

```bash
boss4d sbom --format cyclonedx --strict --validate \
  --include-getit --include-toolchain --include-artifacts \
  --output ambiente-build.cdx.json
```

- `--include-getit` registra pacotes instalados como inventário ambiental com uso
  desconhecido; não transforma todos eles em dependências do projeto.
- `--include-toolchain` registra `dcc32`, `dcc64` e `System.dcu` Win32/Win64
  detectados, com versões e hashes SHA-256.
- `--include-artifacts` calcula hashes dos arquivos declarados pelas dependências
  resolvidas no lock.

Os coletores são opt-in e podem tornar a saída específica da máquina. Falha de
descoberta vira cobertura incompleta e é fatal sob `--strict`.

## Declarar uso de GetIt ou outro componente manual

Inventário GetIt instalado só vira dependência quando o uso é declarado:

```json
{
  "sbom": {
    "components": [
      {
        "id": "vendor-grid",
        "name": "Vendor Grid",
        "version": "4.2",
        "type": "library",
        "source": "getit",
        "license": "Commercial"
      }
    ]
  }
}
```

Para SDKs fora do GetIt, omita `source` e, opcionalmente, adicione `repository` e um
objeto `hash` SHA-256. Declarações manuais são identificadas como declarações, não
como evidências descobertas automaticamente.

## Escolher a base dos artefatos da dependência

Um módulo instalado no `boss-lock.json` pode declarar:

```json
{
  "artifacts": {
    "base": "module",
    "bin": ["bin/vendor.dll"],
    "dcp": ["lib/vendor.dcp"],
    "dcu": ["lib/vendor.dcu"],
    "bpl": ["bin/vendor.bpl"]
  }
}
```

As bases aceitas são `project`, `module` (`modules/<dependência>`) e `absolute`.
Omitir `base` mantém o comportamento retrocompatível `project`. Caminhos absolutos
exigem base `absolute`; traversal relativo para fora da base é rejeitado.

## Importar VEX offline no CycloneDX

Crie `security.vex.json`:

```json
{
  "vulnerabilities": [
    {
      "id": "CVE-2099-0001",
      "component": "meu-projeto",
      "state": "not_affected",
      "detail": "O caminho de código afetado não está presente.",
      "source": "Revisão interna de segurança"
    }
  ]
}
```

Gere e ateste o documento enriquecido:

```bash
boss4d sbom --format cyclonedx --strict --validate --reproducible \
  --vex security.vex.json --output dist/sbom/app.vex.cdx.json \
  --attestation-output dist/sbom/app.vex.cdx.intoto.json
```

`component` deve corresponder ao ID ou nome de um componente do SBOM. Estados
aceitos: `affected`, `not_affected`, `fixed` e `under_investigation`. VEX é recusado
com SPDX 2.3 em vez de ser descartado silenciosamente.

## Validar a matriz de release do Boss4D

No Windows com Delphi 13, Docker, Java e GitHub CLI:

```powershell
./scripts/test-sbom-runner.ps1 -RequireDockerDaemon
./scripts/ci-verify-sbom.ps1
```

O segundo comando compila e testa Win32/Win64, compara saídas reproduzíveis,
verifica atestações e executa os validadores oficiais CycloneDX e SPDX. A execução
local no commit da release é autoritativa; o workflow GitHub Actions, acionado
manualmente, é apenas uma automação opcional da mesma matriz.
