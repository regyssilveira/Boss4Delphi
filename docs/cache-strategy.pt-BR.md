# Cache de objetos Git e artefatos compilados

As fontes permanecem em árvores de trabalho isoladas. O Boss4D clona do cache
Git global com `--reference-if-able --no-hardlinks`, compartilha objetos apenas
durante o checkout e remove `.git` depois. Os arquivos do projeto não dependem
de hardlinks nem da existência futura do cache global.

Executáveis compilados são armazenados por:

- checksum normalizado dos fontes;
- plataforma alvo;
- versão do compilador/toolchain.

Somente entradas completas são restauradas. Divergência de plataforma ou
compilador força compilação normal. DCU/DCP/BPL compartilhados permanecem fora
do cache até poderem ser isolados por dependência sem contaminação.

No Linux/FPC, mirrors Git bare ficam em `~/.boss/cache/git`. Instalações online
os atualizam e clonam com `--reference-if-able --no-hardlinks`.
`boss4d cache size|prune|clean` consulta e mantém esse cache; prune remove
entradas com mais de 30 dias.
