# Contrato da matriz de build

Este documento define as regras de compatibilidade e o modelo declarativo usado
pelo Boss4D para descrever builds em múltiplas versões do Delphi.

## Escopo inicial

A primeira matriz avançada cobre:

- Delphi 10.1 (`BDS 18.0`), Delphi 11 (`BDS 22.0`), Delphi 12 (`BDS 23.0`) e
  Delphi 13 (`BDS 37.0`);
- plataformas `Win32` e `Win64`;
- configurações `Debug` e `Release`;
- pacotes runtime e design-time;
- seleção de um target, de vários targets ou da matriz completa.

O suporte existente ao Lazarus permanece válido, mas a expansão avançada de
matriz para Lazarus não faz parte desta primeira etapa.

## Compatibilidade do `boss.json`

Os formatos existentes continuam válidos sem migração:

- `projects` permanece aceitando uma lista de strings;
- `scripts`, `dependencies` e `devDependencies` permanecem mapas
  `string: string`;
- `engines.compiler`, `engines.platforms` e `toolchain` mantêm o significado
  atual;
- sem uma matriz declarada, o Boss4D preserva a precedência atual:
  argumento da CLI, `toolchain`, `engines` e padrão `Win32`;
- salvar um manifesto legado não converte silenciosamente strings em objetos.

A matriz será aditiva. Campos novos não podem alterar a leitura, a gravação ou
o resultado efetivo de um manifesto legado.

## Sintaxe declarativa

```json
{
  "buildMatrix": {
    "compilers": ["18.0", "22.0", "23.0", "37.0"],
    "platforms": ["Win32", "Win64"],
    "configurations": ["Debug", "Release"],
    "defaults": {
      "compiler": "37.0",
      "platform": "Win64",
      "configuration": "Release"
    },
    "projects": [
      {
        "path": "packages/ComponentRuntime.dproj",
        "kind": "runtime"
      },
      {
        "path": "packages/ComponentDesign.dproj",
        "kind": "design",
        "dependsOn": ["packages/ComponentRuntime.dproj"],
        "compilers": ["22.0", "23.0", "37.0"],
        "platforms": ["Win32"],
        "configurations": ["Release"]
      }
    ]
  }
}
```

Os eixos globais declaram todos os valores suportados. As listas opcionais de
um projeto restringem esse projeto a um subconjunto de cada eixo global.
Restrições fora do eixo, valores duplicados, plataforma/configuração não
suportada, paths de projeto duplicados e seleções sem targets são recusados
antes da compilação.

`kind` aceita `runtime` ou `design` e usa `runtime` como padrão. `dependsOn`
registra relações de build pelo path do projeto; a ordenação das dependências é
responsabilidade da etapa de grafo.

A seleção padrão expande um target por projeto aplicável. A seleção completa
expande o produto cartesiano após aplicar as restrições por projeto. O resultado
é ordenado pela identidade do target e não depende da ordem de declaração.

## Identidade de um target

Um target de build é identificado pelo conjunto:

`pacote + projeto + compilador + plataforma + configuração`

Essa identidade será usada para diretórios de saída, fingerprints, cache,
diagnósticos e registro na IDE. Artefatos produzidos por compiladores,
plataformas ou configurações diferentes nunca poderão compartilhar o mesmo
diretório final.

Os outputs da matriz usam este layout:

```text
modules/artifacts/<pacote>/<compilador>/<plataforma>/<configuração>/
  bin/
  bpl/
  dcp/
  dcu/
```

A árvore completa do target é armazenada no cache como uma unidade. A chave
inclui identidade da dependência, checksum dos fontes, compilador, plataforma e
configuração. Assim, restaurar um target nunca sobrescreve nem satisfaz outro.
Manifests legados preservam o layout existente até serem compilados
explicitamente pelo executor da matriz.

## Precedência esperada

A seleção segue esta ordem:

1. filtros explícitos da CLI;
2. targets declarados no projeto;
3. defaults declarados na matriz;
4. contrato legado de `toolchain` e `engines`;
5. defaults compatíveis do Boss4D.

Uma seleção vazia ou incompatível deverá falhar com mensagem acionável, sem
executar parcialmente a instalação.

## Critérios de aceitação

Cada incremento deste contrato exige:

- testes unitários cobrindo comportamento novo e regressão legada;
- erro determinístico para combinações inválidas;
- serialização determinística;
- nenhuma colisão de artefatos entre targets;
- builds reais proporcionais à mudança nas versões instaladas do Delphi;
- atualização da documentação em português e inglês;
- quality gate do Sonar aprovado antes do encerramento da versão.
