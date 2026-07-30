# Matriz de artefatos da release

Cada tag `v*` somente é promovida depois que os jobs Windows e Linux terminam
com sucesso no mesmo commit.

| Artefato | Builder | Validação obrigatória |
|---|---|---|
| `boss4d-windows.zip` | Runner próprio com Delphi 13 | Build Win32/Win64, geração dos SBOMs e promoção transacional de `dist` |
| `boss4d-linux-x86_64.tar.gz` | Ubuntu 24.04 com FPC | Compilação nativa da CLI e suíte FPCUnit completa |
| `SHA256SUMS.txt` | Job de publicação | SHA-256 dos arquivos Windows e Linux realmente enviados |
| CycloneDX, SPDX e documentos in-toto | Build Delphi | Geração e validação estritas a partir do lock da release |
| Atestações de proveniência do GitHub | GitHub OIDC | Atestação vinculada à identidade para os dois arquivos |

O job de publicação não executa em pull requests. Ele exige os dois jobs de
plataforma, baixa seus artefatos imutáveis, recalcula o manifesto conjunto de
checksums, cria atestações de proveniência e publica tudo na release da tag.

O nome do arquivo Linux faz parte do contrato de autoatualização. Qualquer
alteração também deve atualizar `Boss4D.Posix.Update` e seus testes unitários.

Valide o workflow localmente com:

```powershell
./scripts/test-release-workflow.ps1
docker run --rm -v "${PWD}:/repo" -w /repo rhysd/actionlint:latest `
  -config-file .github/actionlint.yaml .github/workflows/release.yml
```

