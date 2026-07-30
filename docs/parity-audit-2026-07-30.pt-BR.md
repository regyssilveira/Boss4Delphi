# Auditoria final de paridade do Boss4D — 30 de julho de 2026

Esta auditoria relaciona cada critério trabalhado à evidência autoritativa no
repositório. “Completo” significa implementado e coberto por teste unitário, de
contrato, integração ou compilador real; não significa possuir escala de npm.

| Critério | Estado | Evidência autoritativa |
|---|---|---|
| Registry público consolidado | Completo | `registry/index-v2.json`, composição legada, pacotes sparse e cadastro de publishers |
| Busca e informações | Completo | testes DUnitX e FPCUnit de search/info |
| Pacotes por compilador/plataforma | Completo | seleção determinística de variantes e `release/artifact-matrix.json` |
| Metadados sparse e cache HTTP | Completo | testes ETag/Last-Modified/304 e cache offline |
| Mirrors e revogação | Completo | testes de mirrors ordenados, rejeição por digest e revogação |
| Publicação imutável | Completo | teste determinístico, gates do lock, token fora do payload e conflito HTTP 409 |
| Onboarding de publishers | Completo | validador de escopo/fingerprint/assinatura/proveniência e testes negativos |
| Compiladores Delphi antigos | Completo | compilação real do plugin com Delphi 10.1, 11, 12 e 13 |
| CLI Linux nativa | Completo | build FPC 3.2.2 x86_64, FPCUnit e smoke tests reais |
| Manutenção cotidiana | Completo | testes install/update/tree/why/outdated/run e rollback transacional |
| Ferramentas globais/workspaces/cache | Completo | testes de ciclo de vida, links, prune e ferramenta FPC real |
| Credenciais seguras | Completo | contrato Secret Service, precedência do ambiente e mascaramento |
| Progresso no terminal | Completo | plain/interativo/JSON/quiet, cancelamento e exit codes |
| Autoatualização | Completo | seleção da release, SHA-256, extração, promoção e rollback |
| Conformidade/auditoria | Completo | CycloneDX, SPDX, VEX, OSV, lock estrito e validadores externos |
| Distribuição da release | Completo | workflow de tag, arquivos Windows/Linux, checksums, OIDC e execução do tarball |
| Qualidade | Completo | Delphi Win32/Win64, FPC/Linux, contratos de workflow e Sonar sem issues |

## Invariantes obrigatórios

- Mapas string/string legados do `boss.json` continuam válidos.
- Registros publicados `(nome, versão)` não podem ser alterados nem
  sobrescritos.
- Um artefato somente é instalado após validar SHA-256 externo e interno;
  assinatura e proveniência configuradas também precisam ser válidas.
- Tokens vêm do ambiente do processo ou Secret Service e nunca são embutidos
  em URLs Git ou payloads de publicação.
- A promoção da release depende dos builders Windows e Linux no mesmo commit.
- Nenhuma capacidade de produção deste programa foi aceita sem teste
  automatizado correspondente.

## Comandos de verificação final

```powershell
./scripts/ci-fpc-linux.ps1
./scripts/test-linux-release-artifact.ps1
./scripts/test-delphi-plugin-matrix.ps1
./scripts/test-release-workflow.ps1
./scripts/test-release-artifact-matrix.ps1
./scripts/test-registry-submission.ps1
docker run --rm -v "${PWD}:/repo" -w /repo rhysd/actionlint:latest `
  -config-file .github/actionlint.yaml
```

O DUnitX Delphi 13 é executado separadamente com `dcc32` e `dcc64`. O Sonar usa
o runner local protegido; credenciais e tokens não são gravados nos logs nem
neste documento.

## Fora dos critérios concluídos

Os próximos investimentos legítimos dependem de crescimento do ecossistema ou
de um novo objetivo de plataforma: pacotes assinados fornecidos pelos
publishers, operação de busca/CDN hospedada, distribuição macOS e identidade
opcional em log de transparência.
