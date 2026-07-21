# Adequação SBOM do Boss4Delphi

Status: proposta arquitetural — Fase 0
Escopo inicial: dependências gerenciadas pelo Boss4D
Formato inicial: CycloneDX 1.7 JSON

## 1. Objetivo

O Boss4D deverá gerar e manter inventários de componentes de software interoperáveis, auditáveis e adequados para automação em CI/CD. A implementação deverá registrar a identidade, a versão resolvida, a proveniência, a integridade e as relações entre as dependências gerenciadas pelo Boss4D.

O SBOM é um artefato de transparência da cadeia de fornecimento. Sua geração, isoladamente, não comprova conformidade com CRA, DORA ou outra legislação e não substitui análise de vulnerabilidades, assinatura de releases, proteção da infraestrutura de distribuição ou resposta a incidentes.

## 2. Terminologia normativa

Os termos **DEVE**, **NÃO DEVE**, **DEVERIA**, **NÃO DEVERIA** e **PODE** expressam, respectivamente, requisito obrigatório, proibição, recomendação e comportamento opcional deste projeto.

- **Manifesto**: arquivo `boss.json`, com a intenção declarada pelo projeto.
- **Lock**: arquivo `boss-lock.json`, com o resultado exato da resolução.
- **Componente raiz**: produto, aplicação, biblioteca, ferramenta ou plugin descrito pelo manifesto do projeto corrente.
- **Componente gerenciado**: dependência resolvida e instalada pelo Boss4D.
- **Componente externo**: componente relevante para o produto, mas não resolvido pelo Boss4D, como RTL, SDK, GetIt, DLL, BPL ou biblioteca comercial.
- **Proveniência**: evidência da origem e da revisão exata do conteúdo obtido.
- **SBOM**: documento de inventário e relações entre componentes.
- **SCA**: análise do inventário para identificar vulnerabilidades, riscos e problemas de licença.

## 3. Princípios de projeto

1. O `boss-lock.json` é a fonte autoritativa para versões e revisões resolvidas.
2. O SBOM DEVE poder ser gerado sem a pasta `modules/` quando o lock contiver todos os dados necessários.
3. A saída NÃO DEVE declarar cobertura completa quando componentes externos não tiverem sido inventariados.
4. O gerador NÃO DEVE inventar versão, licença, fornecedor, PURL ou revisão ausente.
5. Ausência de informação DEVE ser representada explicitamente ou reportada conforme o modo de qualidade selecionado.
6. O modelo de domínio interno NÃO DEVE depender de CycloneDX ou SPDX.
7. A serialização DEVE ser determinística quando habilitado o modo reprodutível.
8. Dados enviados a `stdout` NÃO DEVEM ser misturados com mensagens de log.
9. A leitura de locks antigos DEVE permanecer compatível durante a migração para a versão 2.
10. Toda alegação de completude DEVE ser sustentada por evidência coletada pelo Boss4D.

## 4. Escopo de cobertura

### 4.1 MVP

O primeiro SBOM cobrirá:

- o componente raiz descrito por `boss.json`;
- dependências diretas e transitivas gerenciadas pelo Boss4D;
- versões e revisões efetivamente resolvidas;
- repositórios de origem;
- hashes com algoritmo explícito;
- licenças declaradas ou identificadas, com a respectiva origem;
- relações diretas entre componentes;
- versão da ferramenta geradora e lifecycle de geração;
- declaração explícita de completude da composição.

### 4.2 Fora do MVP

Os itens seguintes NÃO serão implicitamente considerados cobertos:

- RTL e bibliotecas fornecidas pelo RAD Studio;
- compilador Delphi, MSBuild e SDKs de plataforma;
- componentes instalados pelo GetIt;
- DCUs, BPLs, DLLs, AARs, JARs, frameworks e bibliotecas adicionadas manualmente;
- serviços remotos consumidos pela aplicação;
- vulnerabilidades conhecidas e VEX;
- assinatura ou attestations do SBOM e do release.

Enquanto esses coletores não existirem, o SBOM DEVE declarar composição incompleta ou cobertura limitada a `boss-managed-dependencies`.

## 5. Contrato planejado do `boss-lock.json` v2

O lock v2 deverá preservar a leitura dos campos existentes e adicionar, no mínimo:

```json
{
  "lockVersion": 2,
  "hash": "hash-do-manifesto",
  "updated": "2026-07-21T12:00:00Z",
  "installedModules": {
    "github.com/hashload/horse": {
      "name": "horse",
      "version": "3.1.0",
      "repository": "https://github.com/hashload/horse",
      "revision": "commit-sha-completo",
      "resolvedFrom": "refs/tags/v3.1.0",
      "checksum": {
        "algorithm": "SHA-256",
        "value": "checksum-do-conteudo"
      },
      "license": {
        "expression": "MIT",
        "source": "boss.json"
      },
      "dependencies": [
        "github.com/vendor/dependency"
      ],
      "artifacts": {
        "bin": [],
        "dcp": [],
        "dcu": [],
        "bpl": []
      }
    }
  }
}
```

### 5.1 Identidade

- A chave canônica DEVE evitar colisões entre repositórios diferentes com o mesmo nome.
- `name` é uma apresentação humana e NÃO DEVE ser usado sozinho como identidade.
- `revision` DEVE registrar o commit completo efetivamente obtido.
- `resolvedFrom` PODE registrar tag, branch ou referência usada na resolução.
- URLs com credenciais ou tokens NÃO DEVEM ser persistidas no lock nem no SBOM.

### 5.2 Integridade

- Todo hash DEVE informar seu algoritmo.
- O projeto deverá distinguir o hash do manifesto, a revisão Git e o checksum do conteúdo instalado.
- A semântica de inclusão de arquivos no checksum DEVE ser documentada e testada entre plataformas.

### 5.3 Grafo

- Cada componente DEVE registrar suas dependências diretas resolvidas.
- A ordem de componentes e relações na saída serializada DEVE ser estável.
- Dependências compartilhadas e ciclos DEVEM ser representados sem duplicação infinita.

## 6. Comando planejado

Interface mínima:

```text
boss4d sbom --format cyclonedx --output bom.json
```

Evolução prevista:

```text
boss4d sbom --format cyclonedx|spdx
             --output <arquivo>
             --type application|library|framework
             --lock-only
             --strict
             --validate
             --reproducible
```

Requisitos de automação:

- Sem `--output`, o documento DEVERÁ ser escrito em `stdout`.
- Logs e diagnósticos DEVERÃO ser escritos em `stderr`.
- Falha de leitura, construção, serialização ou validação DEVERÁ produzir exit code diferente de zero.
- `--lock-only` NÃO DEVERÁ consultar `modules/` nem a rede.
- `--strict` DEVERÁ falhar para identidade, revisão, grafo ou hash obrigatório ausente.
- `--validate` DEVERÁ validar o documento contra o schema suportado.
- `--reproducible` DEVERÁ estabilizar ordenação e omitir ou controlar valores voláteis como timestamp, UUID e caminho local.

## 7. Mapeamento mínimo para CycloneDX 1.7

| Boss4D | CycloneDX |
| --- | --- |
| Projeto raiz | `metadata.component` |
| Dependência resolvida | `components[]` |
| Identidade estável | `bom-ref` |
| Nome e versão | `name`, `version` |
| Revisão e origem Git | `externalReferences` e propriedades namespaced |
| Checksum | `hashes[]` |
| Licença | `licenses[]` |
| Grafo resolvido | `dependencies[]` e `dependsOn[]` |
| Cobertura | `compositions[]` e propriedades Boss4D |
| Boss4D | `metadata.tools` |
| Momento de captura | lifecycle `build` |

O Boss4D NÃO DEVE criar um tipo Package URL privado `pkg:delphi` sem padronização externa. Até haver uma decisão interoperável, a identidade deverá usar `bom-ref`, referência VCS e propriedades com namespace `boss4d:`. O uso de `pkg:generic` deverá ser validado com consumidores reais antes de se tornar padrão.

## 8. Licenças

- IDs e expressões SPDX reconhecidos DEVERÃO ser preservados.
- Texto livre NÃO DEVERÁ ser apresentado como ID SPDX.
- Licença ausente, não reconhecida e comercial/proprietária DEVERÃO permanecer estados distintos.
- O sistema DEVERÁ registrar se o dado veio de `boss.json`, arquivo de licença, declaração manual ou outra fonte.
- O comando existente `boss4d license report` e o SBOM DEVERÃO consumir o mesmo modelo normalizado no fim da Fase 4.

## 9. Componentes manuais e coletores futuros

A arquitetura deverá aceitar coletores independentes:

```text
SBOM Builder
  -> dependências Boss4D
  -> componentes manuais
  -> GetIt
  -> toolchain e RTL
  -> artefatos e dependências binárias
```

Componentes manuais deverão permitir documentar bibliotecas comerciais ou externas sem afirmar que foram descobertas automaticamente. O SBOM deverá registrar a origem da declaração.

## 10. Fases e critérios de saída

### Fase 0 — contrato e escopo

- Documento de arquitetura versionado.
- Escopo, não objetivos e terminologia definidos.
- Compatibilidade e critérios de qualidade definidos.

### Fase 1 — lock v2

- Leitura de locks v1 preservada.
- Escrita determinística do lock v2.
- Grafo, repositório, revisão, proveniência e hashes explícitos.
- Testes de leitura, migração, round-trip, ciclos e dependência compartilhada.

### Fase 2 — domínio neutro

- Documento, componente, relação, hash, licença e referência externa modelados sem tipos CycloneDX/SPDX.
- Builder funcional usando somente manifesto e lock v2.
- Testes sem acesso à rede ou ao filesystem global.

### Fase 3 — CycloneDX e CLI/CI

- `boss4d sbom --format cyclonedx` funcional.
- CycloneDX 1.7 JSON validado contra schema.
- Modos `--output`, `--lock-only`, `--strict`, `--validate` e `--reproducible` documentados e testados.
- `stdout`, `stderr` e exit codes adequados para CI.

### Fase 4 — metadados e licenças

- Licenças normalizadas e origem preservada.
- Componentes manuais suportados.
- Relatório de licenças e SBOM usando o mesmo modelo.

### Fase 5 — cobertura Delphi

- Coletores de GetIt, toolchain/RTL e dependências binárias implementados separadamente.
- Cobertura e completude recalculadas a partir da evidência de cada coletor.
- Suporte documentado por plataforma.

### Fase 6 — SPDX e segurança integrada

- Serializador SPDX baseado no mesmo domínio neutro.
- Pontos de extensão para SCA, VEX, merge e assinatura definidos.
- Geração de SBOM permanece utilizável sem serviço comercial ou rede.

### Fase 7 — entrega

- Migração, changelog e documentação em português e inglês.
- SBOM do próprio Boss4D gerado no processo de release.
- Testes unitários e de integração executados nas plataformas suportadas.
- Exemplos validados por pelo menos um consumidor CycloneDX externo.

## 11. Não objetivos

- Declarar que o Boss4D torna um produto legalmente conforme.
- Implementar um banco próprio de vulnerabilidades no primeiro ciclo.
- Inferir licença por heurística e apresentá-la como certeza.
- Analisar código-fonte ou binários como substituto de ferramentas SCA especializadas.
- Exigir serviço comercial, conta externa ou conectividade para gerar o SBOM básico.
- Alterar silenciosamente o significado de campos existentes do lock.

## 12. Referências

- npm CLI: `npm sbom`, como referência de experiência de uso e geração a partir do lock.
- OWASP CycloneDX 1.7, como primeiro formato interoperável.
- SPDX, como segundo serializador planejado.
- Cyber Resilience Act, como contexto de transparência e gestão do ciclo de vida, não como certificação produzida pela ferramenta.
- DORA, como contexto de gestão de risco de TIC no setor financeiro.
- Material da Embarcadero e DerScanner sobre SBOM/SCA no ecossistema Delphi.
