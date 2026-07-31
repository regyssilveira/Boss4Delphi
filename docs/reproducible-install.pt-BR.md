# Instalação reproduzível e offline

O Boss4D pode instalar exatamente o grafo registrado no `boss-lock.json` sem
alterar o lock:

```console
boss4d install --locked
boss4d install --frozen-lockfile
boss4d install --locked --offline
boss4d ci
boss4d ci --offline
boss4d restore --ci --remote-cache X:\boss4d-cache
boss4d install --build-only --locked --remote-cache X:\boss4d-cache
```

`--locked` e seu alias `--frozen-lockfile` exigem um lock com metadados da raiz.
O Boss4D recusa um manifesto cujo conjunto de dependências diretas diverge do
lock, faz checkout de cada revisão Git registrada e valida seu checksum SHA-256.
O arquivo de lock, inclusive seu timestamp, não é regravado.

`--offline` desativa clone e atualização do cache. Todas as dependências precisam
existir previamente no cache global do Boss4D; a ausência de qualquer uma
interrompe o comando.

`ci` e `restore --ci` são o modo de release e automação. Eles impõem o lock,
limpam `modules/` e desativam o registro na IDE na fronteira do serviço.
A fronteira de `install --build-only` e `--no-register` cobre tanto o registro
de packages design-time quanto alterações no Library Path global do Delphi.
Como a operação é transacional, uma falha restaura manifesto, lock e árvore de
módulos anteriores. `--remote-cache` compartilha targets compilados
verificados sem enfraquecer essas regras.

Sequência recomendada na CI:

```console
boss4d ci
boss4d sbom --lock-only --reproducible --strict --validate \
  --format cyclonedx --output bom.cdx.json
```
