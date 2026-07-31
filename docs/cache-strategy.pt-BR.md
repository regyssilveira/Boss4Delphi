# Cache de objetos Git e artefatos compilados

As fontes permanecem em árvores de trabalho isoladas. O Boss4D clona do cache
Git global com `--reference-if-able --no-hardlinks`, compartilha objetos apenas
durante o checkout e remove `.git` depois. Os arquivos do projeto não dependem
de hardlinks nem da existência futura do cache global.

Executáveis compilados são armazenados por:

- checksum normalizado dos fontes;
- plataforma alvo;
- versão do compilador/toolchain;
- configuração do build.

Cada entrada contém inventário determinístico e SHA-256 de todos os artefatos.
A restauração usa staging e promoção atômica, rejeitando arquivos ausentes,
extras ou alterados. Divergência de plataforma, compilador, configuração ou
checksum força compilação normal.

```console
boss4d build --remote-cache X:\boss4d-cache
boss4d restore --ci --remote-cache X:\boss4d-cache
```

Uma entrada remota válida recupera cache local ausente ou corrompido. Cache
remoto inválido nunca é promovido. `.boss4d-state` é regenerado no target
restaurado e não é tratado como artefato portátil.

No Linux/FPC, mirrors Git bare ficam em `~/.boss/cache/git`. Instalações online
os atualizam e clonam com `--reference-if-able --no-hardlinks`.
`boss4d cache size|prune|clean` consulta e mantém esse cache; prune remove
entradas com mais de 30 dias.
