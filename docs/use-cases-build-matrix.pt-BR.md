# Casos de uso de build Multi-Delphi

A identidade do target é pacote, compilador, plataforma e configuração. O
Boss4D isola saídas e estado por essa identidade completa para impedir que DCU
ou BPL de um target satisfaça silenciosamente outro.

## 1. Detectar packages runtime e design em componente existente

**Situação:** o repositório possui `.dproj` e `.dpk`, mas não uma matriz
declarativa.

```powershell
boss4d spec --detect
git diff -- boss.json
boss4d doctor
```

**Resultado esperado:** o Boss4D detecta packages runtime/design-time,
relacionamentos locais de `requires`, compiladores, plataformas, configurações
e caminhos determinísticos.

**Controles de risco:** revise projetos e arestas detectadas. A detecção não
decide qual design package deve ser instalado em cada IDE.

**Recuperação:** restaure `boss.json`, corrija metadados ou diretórios e detecte
novamente. Não edite arestas geradas sem conferir `requires` dos `.dpk`.

## 2. Compilar um target rápido de desenvolvimento

**Situação:** desenvolvedor altera código para uma versão Delphi instalada.

```powershell
boss4d build --compiler d13 --platform Win64 `
  --configuration Debug --explain
```

**Resultado esperado:** somente a seleção e suas dependências de projeto são
compiladas.

**Controles de risco:** use target explícito no cotidiano. `build` sem filtros
usa defaults declarados, que devem ser revisados em `boss.json`.

**Recuperação:** execute `boss4d doctor` se faltar toolchain. Use `--explain`
antes de forçar rebuild.

## 3. Validar release em todos os compiladores declarados

**Situação:** pull request ou candidata a release deve provar a matriz.

```powershell
boss4d build --compiler all --platform all `
  --configuration Release --jobs 4
```

**Resultado esperado:** todo target compatível runtime/design compila em sua
árvore isolada.

**Controles de risco:** use apenas compiladores instalados no runner ou divida
a matriz em runners rotulados. Preserve logs por identidade.

**Recuperação:** repita o target exato com `--jobs 1 --explain`; não descarte
evidências dos targets aprovados.

## 4. Entender por que target recompilou ou foi ignorado

**Situação:** target compilou, restaurou cache ou foi ignorado inesperadamente.

```powershell
boss4d build --compiler d12 --platform Win32 `
  --configuration Release --explain
```

**Resultado esperado:** cada target informa primeira compilação, mudança de
fonte/dependência, saída ausente, cache restaurado ou estado atual.

**Controles de risco:** recompilação sem explicação exige inspeção de inputs,
fingerprints e inventário de saídas. Não apague todo o cache como primeiro
passo.

**Recuperação:** remova apenas o target em
`modules/artifacts/<pacote>/<compilador>/<plataforma>/<configuração>/` e repita.
Saída ausente deve provocar rebuild normal.

## 5. Forçar um target sem reconstruir toda a matriz

**Situação:** comportamento do compilador ou etapa externa exige recompilação
limpa da seleção.

```powershell
boss4d build --compiler d11 --platform Win32 `
  --configuration Release --force --explain
```

**Resultado esperado:** targets selecionados compilam mesmo com fingerprints
atuais; demais eixos permanecem intactos.

**Controles de risco:** `--force` ignora restauração do cache do target. Use
depois de capturar a explicação incremental.

**Recuperação:** builds normais seguintes voltam às decisões de fingerprint e
cache.

## 6. Fazer validação completa e limpa da matriz

**Situação:** engenharia de release precisa selecionar e recompilar todos os
eixos.

```powershell
boss4d build --full --jobs 4
```

**Resultado esperado:** todos os compiladores, plataformas e configurações são
selecionados e forçados.

**Controles de risco:** `--full` custa mais e pode exigir todas as toolchains.
Use em release, não como comando cotidiano.

**Recuperação:** se faltar capacidade, particione targets exatos entre runners;
não remova eixos declarados silenciosamente.

## 7. Usar paralelismo sem colisões

**Situação:** a matriz está correta, mas validação sequencial é lenta.

```powershell
boss4d doctor
boss4d build --compiler all --platform Win32 `
  --configuration Release --jobs 4
```

**Resultado esperado:** targets com roots distintos rodam em paralelo; projetos
que compartilham root são serializados e dependentes aguardam pré-requisitos.

**Controles de risco:** não aponte dois targets ao mesmo caminho customizado.
`--jobs` acima de memória, disco ou licenças disponíveis reduz confiabilidade.

**Recuperação:** repita com `--jobs 1` para separar problema de recurso/agendamento
de falha do compilador. Corrija colisões do `doctor`.

## 8. Diagnosticar colisão de unit ou saída

**Situação:** DCU errado é carregado, BPL é sobrescrito ou `doctor` acusa
duplicidade.

```powershell
boss4d doctor
boss4d build --compiler d13 --platform Win32 `
  --configuration Release --explain
```

**Resultado esperado:** diagnóstico identifica declarações duplicadas, caminhos
que escapam da raiz, outputs, projetos ausentes ou identidade conflitante.

**Controles de risco:** preserve o layout:

```text
modules/artifacts/<pacote>/<compilador>/<plataforma>/<configuração>/
```

Não resolva colisão adicionando Library Paths globais amplos.

**Recuperação:** corrija caminhos/nomes, remova apenas saídas afetadas e
recompile o target exato.

## 9. Migrar manifest legado gradualmente

**Situação:** `boss.json` usa `projects`, `toolchain` ou mapas string/string
legados.

```powershell
boss4d spec --detect
boss4d build --compiler d13 --platform Win32 `
  --configuration Release --explain
```

**Resultado esperado:** `buildMatrix` aditivo convive com campos antigos e um
target explícito funciona antes da expansão.

**Controles de risco:** não reescreva mapas de dependências apenas para adotar a
matriz. Separe migração de mudanças no componente.

**Recuperação:** remova a seção aditiva para retornar à seleção legada; mapas
originais continuam válidos.

## 10. Alvejar Delphi 10/10.1 sem misturar convenções

**Situação:** o componente suporta o perfil legado de código Delphi.

Use:

- Delphi 10 Seattle: BDS `17.0`, alias `d10`, sufixo `230`, `VER300`;
- Delphi 10.1 Berlin: BDS `18.0`, alias `d101`, sufixo `240`, `VER310`.

```powershell
boss4d build --compiler d10 --platform Win32 `
  --configuration Release --explain
boss4d build --compiler d101 --platform Win32 `
  --configuration Release --explain
```

**Resultado esperado:** `{compiler}`, `{alias}` e `{libsuffix}` expandem para
projetos e outputs corretos.

**Controles de risco:** build Seattle é evidência conservadora do perfil de
código compartilhado, mas BPL publicado especificamente para Berlin deve ser
produzido pelo BDS 18.0.

**Recuperação:** inspecione caminhos com `--explain`, corrija aliases/tokens e
nunca renomeie binário de um compilador para representar outro.

## Tabela de decisão

| Necessidade | Comando |
|---|---|
| Desenvolvimento diário | Target exato com `--explain` |
| Rebuild da seleção | Target exato mais `--force` |
| Matriz de release | `--compiler all --platform all --configuration Release` |
| Validação completa forçada | `--full` |
| Investigar scheduler | Repetir com `--jobs 1` |
| Encontrar configuração/colisão | `boss4d doctor` |

Veja [contrato da matriz](build-matrix-contract.pt-BR.md),
[melhorias de build](build-improvements.pt-BR.md),
[estratégia de cache](cache-strategy.pt-BR.md) e o
[exemplo de matriz](../examples/build-matrix/README.md).

