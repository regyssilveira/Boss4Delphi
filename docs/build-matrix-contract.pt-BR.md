# Contrato da matriz de build

Este documento registra as decisões de compatibilidade que orientam a evolução
do Boss4D para compilar e instalar componentes em múltiplas versões do Delphi.
Ele descreve o contrato; a sintaxe declarativa da matriz será documentada quando
for implementada.

## Escopo inicial

A primeira matriz avançada cobre:

- Delphi 10.1 (`BDS 18.0`), Delphi 11 (`BDS 28.0`), Delphi 12 (`BDS 23.0`) e
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

## Identidade de um target

Um target de build é identificado pelo conjunto:

`pacote + projeto + compilador + plataforma + configuração`

Essa identidade será usada para diretórios de saída, fingerprints, cache,
diagnósticos e registro na IDE. Artefatos produzidos por compiladores,
plataformas ou configurações diferentes nunca poderão compartilhar o mesmo
diretório final.

## Precedência esperada

Quando a matriz estiver disponível, a seleção seguirá esta ordem:

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

