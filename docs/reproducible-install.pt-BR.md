# Instalação reproduzível e offline

O Boss4D pode instalar exatamente o grafo registrado no `boss-lock.json` sem
alterar o lock:

```console
boss4d install --locked
boss4d install --frozen-lockfile
boss4d install --locked --offline
boss4d ci
boss4d ci --offline
```

`--locked` e seu alias `--frozen-lockfile` exigem um lock com metadados da raiz.
O Boss4D recusa um manifesto cujo conjunto de dependências diretas diverge do
lock, faz checkout de cada revisão Git registrada e valida seu checksum SHA-256.
O arquivo de lock, inclusive seu timestamp, não é regravado.

`--offline` desativa clone e atualização do cache. Todas as dependências precisam
existir previamente no cache global do Boss4D; a ausência de qualquer uma
interrompe o comando.

`ci` é o modo indicado para releases e automações. Ele reinstala `modules/` do
zero a partir do lock congelado. Como a operação é transacional, uma falha
restaura manifesto, lock e árvore de módulos anteriores.

Sequência recomendada na CI:

```console
boss4d ci
boss4d sbom --lock-only --reproducible --strict --validate \
  --format cyclonedx --output bom.cdx.json
```
