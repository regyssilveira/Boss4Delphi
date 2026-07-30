# Auditoria de vulnerabilidades

`boss4d audit` consulta a [API OSV](https://osv.dev) usando o commit Git exato
registrado para cada dependência no `boss-lock.json`.

```console
boss4d audit
boss4d audit --fail-on high
boss4d audit --offline
boss4d audit --cache-hours 48
boss4d audit --vex security.vex.json --fail-on medium
```

As respostas são armazenadas por revisão no diretório global do Boss4D. O modo
offline nunca acessa o OSV e falha se não houver cache atual.

`--fail-on low|medium|high|critical` retorna erro quando uma ocorrência não
suprimida atinge a severidade escolhida. Uma entrada VEX `not_affected`, `fixed`
ou `resolved` suprime o ID correspondente; outros estados continuam sujeitos à
política.

A auditoria identifica revisões de código-fonte, não nomes de pacotes Delphi.
Um relatório vazio não prova ausência de vulnerabilidades.
