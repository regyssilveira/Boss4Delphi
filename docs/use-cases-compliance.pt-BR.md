# Casos de uso de conformidade e auditoria

Um SBOM só é útil quando escopo, evidências e política de geração estão claros.
Estes casos separam inventário rápido de desenvolvimento, evidência de release
e aplicação de política de vulnerabilidades.

## 1. Gerar inventário rápido de desenvolvimento

**Situação:** desenvolvedor quer inspecionar dependências atuais ao investigar
pacote ou licença.

```powershell
boss4d sbom --format cyclonedx --output bom.cdx.json --validate
boss4d license report
```

**Resultado esperado:** documento CycloneDX válido e relatório legível de
licenças são produzidos.

**Controles de risco:** este é inventário exploratório, não automaticamente
evidência de release. Registre se coletores ambientais foram usados.

**Recuperação:** execute `boss4d doctor`, corrija evidências do manifest/lock e
gere novamente em vez de editar o SBOM.

## 2. Gerar SBOMs reproduzíveis de release

**Situação:** a release precisa de CycloneDX e SPDX derivados somente do lock
revisado.

```powershell
boss4d sbom --format cyclonedx --lock-only --strict --validate `
  --reproducible --type application --output dist/sbom/app.cdx.json `
  --attestation-output dist/sbom/app.cdx.intoto.json

boss4d sbom --format spdx --lock-only --strict --validate `
  --reproducible --type application --output dist/sbom/app.spdx.json `
  --attestation-output dist/sbom/app.spdx.intoto.json
```

**Resultado esperado:** os dois formatos validam, contêm o mesmo escopo
revisado e são estáveis entre builds limpos idênticos.

**Controles de risco:** mantenha `--strict`. `--lock-only` impede que GetIt,
toolchain e artefatos locais tornem a evidência dependente da máquina.

**Recuperação:** se faltar evidência, corrija `boss-lock.json` por instalação
normal verificada. Não remova `--strict` para forçar publicação.

## 3. Inventariar o ambiente real de build

**Situação:** suporte ou perícia precisa saber quais Delphi, GetIt e artefatos
existiam em uma máquina.

```powershell
boss4d sbom --format cyclonedx --strict --validate `
  --include-getit --include-toolchain --include-artifacts `
  --output ambiente-build.cdx.json
```

**Resultado esperado:** o documento inclui componentes ambientais e informa a
cobertura dos coletores.

**Controles de risco:** não combine coletores ambientais com `--lock-only`.
Identifique a saída como específica da máquina; ela não substitui o SBOM
reproduzível da release.

**Recuperação:** evidência ausente é fatal em `--strict`. Corrija caminho ou
permissão e repita no mesmo host.

## 4. Registrar decisão de vulnerabilidade com VEX

**Situação:** uma vulnerabilidade é conhecida, mas seu estado no produto foi
analisado.

```powershell
boss4d sbom --format cyclonedx --strict --validate --reproducible `
  --vex security.vex.json --output dist/sbom/app.vex.cdx.json `
  --attestation-output dist/sbom/app.vex.cdx.intoto.json
```

**Resultado esperado:** o CycloneDX contém análise VEX ligada à identidade
correta do componente e vulnerabilidade.

**Controles de risco:** estado VEX é decisão de segurança revisada, não forma de
ocultar achados. Preserve justificativa, resposta, datas quando exigidas e
responsável. A saída SPDX não aceita esse caminho de enriquecimento VEX.

**Recuperação:** corrija o VEX fonte e regenere todas as evidências derivadas.
Nunca edite diretamente o SBOM publicado.

## 5. Aplicar severidade de vulnerabilidade na CI

**Situação:** pull request ou release deve falhar com vulnerabilidade alta ou
crítica não suprimida.

```powershell
boss4d audit --fail-on high
```

Com VEX revisado:

```powershell
boss4d audit --vex security.vex.json --fail-on high
```

**Resultado esperado:** sucesso quando a política é atendida e código de saída
6 quando há violação.

**Controles de risco:** falha de rede/cache não é auditoria limpa. Versione o
limite na CI e revise cada supressão VEX.

**Recuperação:** atualize a dependência, publique decisão VEX justificada ou
interrompa a release. Não reduza o limite apenas para deixar o job verde.

## 6. Auditar em ambiente offline ou restrito

**Situação:** o build não pode consultar OSV durante a execução.

```powershell
boss4d audit --cache-hours 48
boss4d audit --offline --fail-on high
```

O primeiro comando roda conectado e atualiza evidências; o segundo comprova o
gate offline.

**Resultado esperado:** auditoria offline usa respostas ainda válidas e falha
claramente se faltar evidência.

**Controles de risco:** escolha validade do cache segundo a política. Sucesso
offline com evidência antiga não equivale a avaliação online atual.

**Recuperação:** reconecte em ambiente confiável, atualize cache e repita.

## 7. Verificar atestação destacada do SBOM

**Situação:** consumidor recebeu SBOM e statement in-toto destacado.

```powershell
boss4d sbom --format cyclonedx --vex security.vex.json `
  --verify-attestation dist/sbom/app.cdx.intoto.json `
  --output bom-verificado.cdx.json
```

**Resultado esperado:** o digest do subject corresponde ao conteúdo exato do
SBOM gerado.

**Controles de risco:** statement SHA-256 destacado prova vínculo de
integridade, não identidade do assinante sozinho. Aplique política de assinatura
e proveniência além do digest.

**Recuperação:** rejeite evidências divergentes e obtenha artefatos originais da
release confiável. Não gere nova atestação para bytes não confiáveis.

## 8. Montar pacote de conformidade da release

**Situação:** engenharia de release precisa de conjunto revisável de evidências.

Inclua:

- documentos CycloneDX e SPDX reproduzíveis;
- statements in-toto destacados;
- VEX quando aplicável;
- saída da auditoria e limite da política;
- relatório de licenças;
- checksums e proveniência dos artefatos.

```powershell
boss4d license report
boss4d audit --vex security.vex.json --fail-on high
```

**Resultado esperado:** cada binário publicado corresponde a inventário,
integridade, vulnerabilidades e licenças retidos.

**Controles de risco:** gere tudo do commit e artefatos exatos da release. Não
misture documentos de builds diferentes.

**Recuperação:** descarte o pacote parcial e regenere todas as evidências juntas
em workspace limpo.

## Tabela de decisão

| Necessidade | Modo exigido |
|---|---|
| Inventário rápido | CycloneDX com `--validate` |
| Evidência reproduzível | `--lock-only --strict --validate --reproducible` |
| Inventário da máquina | Coletores ambientais sem `--lock-only` |
| Decisão de segurança | VEX revisado com CycloneDX |
| Gate de vulnerabilidade | `audit --fail-on <severidade>` |
| Auditoria sem rede | Cache preenchido e `audit --offline` |

Veja [guia de SBOM](sbom.pt-BR.md),
[exemplos de SBOM](sbom-examples.pt-BR.md), [auditoria](audit.pt-BR.md),
[política de confiança](trust-policy.pt-BR.md) e
[checklist de release](sbom-release-checklist.pt-BR.md).

