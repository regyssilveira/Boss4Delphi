# Contrato da matriz de build

Este documento define as regras de compatibilidade e o modelo declarativo usado
pelo Boss4D para descrever builds em múltiplas versões do Delphi.

> **Escopo atual:** o modelo cobre Delphi XE a Delphi 13, Win32/Win64 e as
> plataformas Linux64, macOS, iOS e Android disponíveis em cada geração. Os
> tipos são `runtime`, `design`, `application`, `tool` e `binary`; `.cbproj`
> C++Builder está experimental em Win32/Win64. Consulte a combinação real com
> `boss4d support --compiler <versão> --platform <target> --kind <tipo>`.
> Cache compartilhado com SHA-256 usa `--remote-cache`; registro aceita
> `--conflict fail|warn|adopt|replace`; `ide repair` recompila artefatos
> gerenciados ausentes antes de reaplicar o estado da IDE. Ferramentas,
> templates e valores BDS restritos podem ser declarados em `ideAssets`.

## Escopo inicial

A primeira matriz avançada cobre:

- Delphi 10 (`BDS 17.0`), Delphi 10.1 (`BDS 18.0`), Delphi 11 (`BDS 22.0`), Delphi 12 (`BDS 23.0`) e
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

A matriz é aditiva. Campos novos não alteram a leitura, a gravação ou
o resultado efetivo de um manifesto legado.

## Sintaxe declarativa

```json
{
  "buildMatrix": {
    "compilers": ["17.0", "18.0", "22.0", "23.0", "37.0"],
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
registra relações de build pelo path do projeto. Dependências são resolvidas
para o mesmo compilador, plataforma e configuração do target consumidor. O
Boss4D executa uma ordenação topológica estável, recusa targets compatíveis
ausentes e informa todos os projetos participantes de um ciclo antes de
compilar.

A seleção padrão expande um target por projeto aplicável. A seleção completa
expande o produto cartesiano após aplicar as restrições por projeto. O resultado
é ordenado pela identidade do target e não depende da ordem de declaração.

## Identidade de um target

Um target de build é identificado pelo conjunto:

`pacote + projeto + compilador + plataforma + configuração`

Essa identidade é usada para diretórios de saída, fingerprints, cache,
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

## Rebuild incremental

Cada target de projeto mantém um documento de estado independente em
`.boss4d-state/`. O estado registra:

- identidade do target;
- fingerprint dos fontes;
- fingerprints das dependências diretas entre projetos;
- fingerprint combinado;
- inventário dos outputs produzidos.

Um target só é ignorado quando estado, fingerprints de fontes/dependências e
outputs registrados continuam válidos. O executor diferencia e explica:

- target atualizado;
- rebuild forçado;
- primeiro build (estado ausente);
- output ausente;
- mudança em fontes ou metadados do projeto;
- mudança no fingerprint de uma dependência;
- estado inválido ou corrompido.

Alterar um pacote runtime invalida seus consumidores design-time compatíveis
mesmo quando os fontes deles não foram modificados.

## Agendamento paralelo

O scheduler executa um nível topológico por vez e nunca inicia um consumidor
antes de todas as dependências diretas terminarem. Dentro de um nível, targets
com diretórios de output diferentes podem executar em paralelo até o limite de
jobs configurado. Projetos que compartilham o mesmo output de
pacote/compilador/plataforma/configuração são agrupados e serializados para
evitar corridas no compilador e no filesystem.

O cancelamento é consultado antes do agendamento e antes de cada target. A
primeira falha impede novos trabalhos, aguarda com segurança as tarefas já em
execução e informa o projeto que falhou. Assim, nenhum nível consumidor começa
depois da falha de uma dependência.

## Registro transacional na IDE

Pacotes design-time são registrados apenas na toolchain e plataforma Delphi que
os produziu. O Boss4D deixa de considerar que um mesmo BPL seja compatível com
todas as IDEs instaladas.

Para cada target, a transação administra:

- `Known Packages` e a limpeza da entrada correspondente em
  `Known IDE Packages`;
- `Search Path`;
- `Browsing Path`;
- `Debug DCU Path`.

Cada valor do Registro é fotografado antes da alteração. Uma falha de escrita
ou de atualização do inventário restaura os valores na ordem inversa e não
persiste registro parcial. O estado desejado fica em
`%BOSS_HOME%\ide-registrations.json`.

O desregistro remove somente os paths e o BPL pertencentes ao
pacote/compilador/plataforma selecionado, preservando paths do usuário. Registrar
novamente o mesmo target substitui seus paths e pacote anteriores. O reparo
compara inventário e Registro e reaplica apenas as entradas com divergência.

## Convenções do Delphi

A CLI aceita versões BDS ou aliases curtos:

| Delphi | Seletor BDS/compilador | Alias | Sufixo do package | Símbolo |
|---|---:|---|---:|---|
| 10 Seattle | `17.0` | `d10` | `230` | `VER300` |
| 10.1 Berlin | `18.0` | `d101` | `240` | `VER310` |
| 11 Alexandria | `22.0` | `d11` | `280` | `VER350` |
| 12 Athens | `23.0` | `d12` | `290` | `VER360` |
| 13 Florence | `37.0` | `d13` | `370` | `VER370` |

Paths podem usar `{compiler}`, `{alias}`, `{libsuffix}`, `{platform}` e
`{configuration}`. Por exemplo,
`packages/{alias}/Component{libsuffix}.dproj` vira
`packages/d13/Component370.dproj` no Delphi 13. Os valores seguem as convenções
de compilador/package do RAD Studio; `libsuffix` permite que outputs de
packages de diferentes gerações coexistam.

## Fluxo da CLI

Detecte uma matriz inicial a partir de `.dproj` e `.dpk`:

```console
boss4d spec --detect
boss4d spec --detect --compiler d13
```

A detecção reconhece `{$RUNONLY}` e `{$DESIGNONLY}`, converte entradas locais
de `requires` em `dependsOn`, ignora diretórios de dependências/artefatos,
preserva `projects` legados e grava paths determinísticos com `/`.

Compile um target, uma seleção mista ou a matriz completa:

```console
boss4d build
boss4d build --compiler d13 --platform Win64 --configuration Release
boss4d build --compiler all --platform Win32 --configuration Release --jobs 4
boss4d build --compiler d13 --platform Win32 --configuration Release --explain
boss4d build --full
```

- `--compiler`, `--platform` e `--configuration` aceitam um valor ou `all`
  independentemente.
- `--jobs n` limita targets isolados concorrentes.
- `--force` recompila os targets selecionados e ignora restauração do cache.
- `--full` seleciona todos os eixos e força recompilação.
- `--explain` mostra a decisão incremental de cada target.
- `--register` registra os BPLs produzidos por targets design-time.

Os comandos de ciclo de vida da IDE são intencionalmente exatos:

```console
boss4d ide unregister ComponentDesign370 --compiler d13 --platform Win32
boss4d ide repair
```

## Doctor e troubleshooting

`boss4d doctor` verifica as ferramentas do host e o projeto atual. Os
diagnósticos do projeto usam códigos estáveis e apresentam remediação para:

- matriz inválida, dependências compatíveis ausentes e ciclos no grafo;
- versões Delphi declaradas mas não instaladas ou paths registrados ausentes;
- projetos inexistentes e paths fora da raiz do pacote;
- nomes de output repetidos e declarações duplicadas de units Delphi;
- divergência entre `%BOSS_HOME%\ide-registrations.json` e o Registro.

Ações comuns de recuperação:

- execute `boss4d spec --detect` após mover ou adicionar packages;
- use `boss4d build --explain` antes de forçar um rebuild;
- remova somente o target afetado em `modules/artifacts/` ao investigar um
  output corrompido; o rebuild normal já detecta outputs ausentes;
- execute `boss4d ide repair` após alterar manualmente Library Paths;
- confirme que a versão BDS selecionada está instalada antes de usar
  `--compiler`.

## Migração de um manifest legado

A migração é opcional. Um manifest legado continua funcionando sem alterações.
Para adotar a matriz:

1. faça commit do `boss.json` existente;
2. execute `boss4d spec --detect`;
3. revise os tipos dos projetos e seus `dependsOn`;
4. restrinja eixos por projeto quando um design package não existir em todos;
5. execute primeiro um target explícito com `--explain`;
6. avance para `--compiler all` ou `--full` somente após esse target passar.

Remover `buildMatrix` restaura a seleção legada; listas de strings e mapas
string/string de dependências nunca são reescritos.

## Precedência esperada

A seleção segue esta ordem:

1. filtros explícitos da CLI;
2. targets declarados no projeto;
3. defaults declarados na matriz;
4. contrato legado de `toolchain` e `engines`;
5. defaults compatíveis do Boss4D.

Uma seleção vazia ou incompatível falha com mensagem acionável, sem
executar parcialmente a instalação.

## Evidências de validação

O branch atual foi validado com:

- 184 testes DUnitX no Delphi 13 Win32 e Win64;
- builds da CLI de produção no Delphi 13 Win32 e Win64;
- builds reais do plugin da IDE com Delphi 10/BDS 17.0, Delphi 11/BDS 22.0, Delphi 12/BDS 23.0 e
  Delphi 13/BDS 37.0;
- 61 testes FPCUnit, smoke tests da CLI e do artefato de release em Linux/FPC
  3.2.2 via Docker;
- Sonar Quality Gate `OK`, sem novas violações.

Delphi 10 Seattle é validado com BDS 17.0 e aceito como gate conservador de
compilador real para o perfil de código-fonte legado compartilhado com o
Delphi 10.1. Berlin continua mapeado ao BDS 18.0, e um BPL binário publicado
especificamente para Berlin ainda deve ser produzido pelo BDS 18.0.

## Critérios de aceitação

Cada incremento deste contrato exige:

- testes unitários cobrindo comportamento novo e regressão legada;
- erro determinístico para combinações inválidas;
- serialização determinística;
- nenhuma colisão de artefatos entre targets;
- builds reais proporcionais à mudança nas versões instaladas do Delphi;
- atualização da documentação em português e inglês;
- quality gate do Sonar aprovado antes do encerramento da versão.
