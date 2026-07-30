# Melhorias de build determinístico

O Boss4D oferece armazenamento determinístico de dependências, seleção explícita
de toolchain, builds Delphi/Lazarus e um modelo reproduzível de evidências lock/SBOM.

## Diretórios de dependências sem colisão

O nome exibido continua sendo o último segmento do repositório, mas os arquivos
são instalados em `modules/<nome>-<prefixo-do-hash-canônico>`. As formas HTTPS e
SSH do mesmo repositório convergem; repositórios diferentes chamados `common`
não se sobrescrevem. Lock e SBOM continuam identificados pela URL canônica.

## Precedência do toolchain

A plataforma efetiva é escolhida nesta ordem:

1. `boss4d install --platform <plataforma>`;
2. `toolchain.platform` do `boss.json` raiz;
3. primeira entrada de `engines.platforms`;
4. `Win32`.

`toolchain.compiler` seleciona a versão do RAD Studio antes da autodetecção pelo
`.dproj` e do fallback para a configuração global.

## Projetos Delphi e Lazarus declarados

Quando uma dependência declara `projects`, somente esses arquivos são
compilados, na ordem informada. Os caminhos devem existir, permanecer dentro da
raiz e usar `.dproj`, `.lpi` ou `.lpk`. Sem `projects`, permanece a descoberta
recursiva, ignorando diretórios comuns de testes e exemplos. Delphi usa MSBuild;
Lazarus usa `lazbuild`, que deve estar no `PATH`.

Durante `boss4d install`, os paths de units das dependências resolvidas são
mesclados em `OtherUnitFiles` de todas as seções `CompilerOptions` dos arquivos
`.lpi` e `.lpk` da raiz, incluindo opções do pacote e todos os modos de build.
As entradas existentes preservam sua ordem, as novas entradas são ordenadas de
forma determinística, a comparação ignora maiúsculas/minúsculas e instalações
repetidas não duplicam paths nem regravam um arquivo inalterado.

Quando `projects` é declarado, somente os arquivos Lazarus listados são
atualizados e todos os paths devem permanecer dentro da raiz. Sem `projects`, o
Boss4D descobre arquivos `.lpi` e `.lpk` no diretório raiz. Arquivos Delphi
`.dproj` nunca são modificados por essa integração.

## Criação de projetos

```powershell
boss4d new app MeuConsole
boss4d new package MinhaBiblioteca --path D:\trabalho\MinhaBiblioteca
```

O destino deve estar vazio. O Boss4D cria `boss.json`, `src`, `tests` e o fonte
inicial sem sobrescrever arquivos existentes.

## Normalização reproduzível

Após o checkout e antes do checksum, fontes textuais Delphi/Lazarus (`.pas`,
`.inc`, `.dfm`, `.dpk`, `.dproj`, `.lpi`, `.lpk`) são normalizados para CRLF.
Arquivos com byte nulo são considerados binários e preservados. Assim, lock e
SBOM descrevem exatamente os bytes instalados.

O helper de DPK inclui dependências ausentes em `requires` sem reconstruir a
cláusula, preservando comentários e diretivas condicionais.

Veja o [exemplo copiável](../examples/build-improvements/README.md).
