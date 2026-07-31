# Matriz de artefatos da release

Cada tag `v*` somente é promovida depois que os jobs Windows, Linux e macOS
terminam com sucesso no mesmo commit.

O contrato legível por máquina é publicado em
`release/artifact-matrix.json`. Atualmente ele garante Delphi 13/37.0 para
Windows x86 e x86_64, FPC 3.2.2 para Linux x86_64 e FPC 3.2.2 para
macOS arm64.

| Artefato | Builder | Validação obrigatória |
|---|---|---|
| `boss4d-windows.zip` | Runner próprio com Delphi 13 | Build Win32/Win64, geração dos SBOMs e promoção transacional de `dist` |
| `boss4d-linux-x86_64.tar.gz` | Ubuntu 24.04 com FPC | Compilação nativa da CLI e suíte FPCUnit completa |
| `boss4d-macos-arm64.tar.gz` | GitHub macOS 15 arm64 com FPC | Compilação nativa da CLI, suíte FPCUnit completa e verificação do host e `shasum` |
| `SHA256SUMS.txt` | Job de publicação | SHA-256 dos arquivos Windows, Linux e macOS realmente enviados |
| CycloneDX, SPDX e documentos in-toto | Build Delphi | Geração e validação estritas a partir do lock da release |
| Atestações de proveniência do GitHub | GitHub OIDC | Atestação vinculada à identidade para todos os arquivos de plataforma |

O job de publicação não executa em pull requests. Ele exige os três jobs de
plataforma, baixa seus artefatos imutáveis, recalcula o manifesto conjunto de
checksums, cria atestações de proveniência e publica tudo na release da tag.

Os nomes dos arquivos POSIX são derivados da plataforma e CPU e fazem parte do
contrato de autoatualização. Qualquer alteração também deve atualizar
`Boss4D.Posix.Update` e seus testes unitários.

Valide o workflow localmente com:

```powershell
./scripts/test-release-workflow.ps1
./scripts/test-release-artifact-matrix.ps1
./scripts/test-linux-release-artifact.ps1
docker run --rm -v "${PWD}:/repo" -w /repo rhysd/actionlint:latest `
  -config-file .github/actionlint.yaml .github/workflows/release.yml
```
