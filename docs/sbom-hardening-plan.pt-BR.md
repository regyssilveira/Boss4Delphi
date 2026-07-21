# Hardening do suporte SBOM

Este plano transforma o suporte funcional entregue no PR #1 em uma capacidade de
produção. Um item só pode ser encerrado quando possuir evidência executável; presença
de código ou documentação, isoladamente, não comprova o critério.

## Contratos congelados

- `boss-lock.json` v1 continua legível e v2 continua sendo a versão gravada.
- O modelo de domínio não depende de CycloneDX, SPDX, rede ou ferramentas comerciais.
- A geração básica é offline; coletores ambientais são opt-in.
- `--reproducible` produz bytes idênticos para entradas idênticas.
- Falha de descoberta nunca significa inventário vazio ou cobertura completa.
- CycloneDX permanece em 1.7 e SPDX permanece em 2.3 neste ciclo.

## Fases e provas exigidas

| Fase | Resultado | Evidência de encerramento |
|---|---|---|
| H0 | Contratos e riscos residuais auditados | Este documento versionado e critérios associados a testes/comandos |
| H1 | Build e automação de CI | matriz local Win32/Win64 com testes e validadores externos; workflow Windows versionado para uso quando houver runner |
| H2 | Lock-only autônomo | geração sem `boss.json`; matriz de flags e exit codes coberta por testes |
| H3 | GetIt semanticamente correto | inventário ambiental separado de dependências comprovadas; fixture positiva e negativa |
| H4 | Toolchain e artefatos auditáveis | versão de arquivo e SHA-256 do compilador/RTL; base de caminho explícita no lock |
| H5 | Segurança concreta | assinatura/atestação verificável e importação/geração SCA/VEX opcional testada |
| H6 | Boss4D autorreferente | lock não-placeholder; SBOMs de release gerados e validados no build completo |
| H7 | Promoção | testes negativos, migração bilíngue, release checklist e PR pronto para revisão |

## Riscos residuais encontrados no PR #1

1. `build_release.bat` apaga `dist` antes de provar que o novo build é válido.
2. Não existe workflow de CI e os validadores externos só foram executados localmente.
3. `--lock-only` ainda carrega obrigatoriamente o `boss.json`.
4. O GetIt lista tudo que está instalado, sem evidência de uso pelo projeto.
5. A toolchain registra apenas a versão BDS, não a versão/hash dos arquivos usados.
6. Caminhos de artefatos não declaram se são relativos ao projeto, módulo ou cache.
7. SCA, VEX e assinatura são somente portas, sem adaptadores concretos.
8. O lock do próprio Boss4D é estruturalmente válido, mas ainda é um placeholder vazio.

## Política de validação

- A evidência obrigatória é a execução local de `scripts/ci-verify-sbom.ps1` no
  commit da release, usando Delphi 13, Win32/Win64 e os validadores externos.
- O GitHub Actions é uma automação opcional acionada apenas manualmente por
  `workflow_dispatch`. Quando houver runner, ele deve ter os
  rótulos `self-hosted`, `windows` e `delphi-13`.
- Segredos e licenças do RAD Studio não são copiados para artefatos ou logs.
- O pipeline não altera `boss.json` nem `boss-lock.json`.
- Artefatos só são publicados depois de testes e validação externa dos dois formatos.
- A promoção para release exige um build limpo Win32 e Win64 no mesmo commit.

## Preparação do runner

O job opcional requer um runner GitHub Actions Windows self-hosted com os rótulos exatos
`self-hosted`, `windows` e `delphi-13`. A conta que executa o serviço do runner deve
ter acesso à instalação/licença do Delphi 13 (BDS 37.0), ao Docker Desktop ou Engine,
ao Java e ao GitHub CLI. Quando o Delphi não estiver registrado em `HKCU` para essa
conta, configure `BOSS4D_BDS_ROOT` no ambiente do serviço.

Antes de registrar ou reiniciar o serviço, execute na mesma conta:

```powershell
pwsh -File scripts/test-sbom-runner.ps1 -RequireDockerDaemon
```

Esse diagnóstico comprova Windows, `rsvars.bat`, `dcc32`, `dcc64`, Docker com daemon
acessível, Java e `gh`. O workflow executa o mesmo diagnóstico antes do build. O
registro do runner e a instalação/licenciamento do Delphi permanecem operações do
administrador da infraestrutura; nenhum token ou segredo deve ser versionado.
Sua ausência não bloqueia a release quando a matriz local obrigatória estiver
registrada e aprovada para o mesmo commit.
