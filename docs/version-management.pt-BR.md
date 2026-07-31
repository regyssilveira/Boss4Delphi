# Seleção de versões, pin e rollback

O Boss4D resolve todas as versões imutáveis publicadas em um índice Registry
v2. A resolução usa SemVer, ignora releases revogadas e não depende da ordem
dos itens no documento JSON.

```console
boss4d package versions Horse
boss4d package install Horse@^3.0.0
boss4d package install Horse@3.2.1 --platform Win64 --compiler 37.0
```

`package versions` mantém releases revogadas visíveis para auditoria, mas elas
nunca são selecionadas para instalação. A variante é escolhida de forma
determinística pela plataforma e pelo compilador. A URL primária e seus mirrors
ordenados precisam corresponder ao mesmo SHA-256 declarado. A instalação
verificada grava `.boss4d-package.json` no módulo com versão, variante, hash,
assinatura e proveniência.

## Pin e unpin

Fixe uma dependência direta na versão SemVer exata já registrada no
`boss-lock.json`:

```console
boss4d pin horse
boss4d unpin horse
```

`pin` troca a faixa do manifesto pela versão resolvida no lock. `unpin`
restaura uma faixa compatível com `^`. O lock continua sendo a autoridade para
instalações reproduzíveis com `--locked` e `ci`.

## Upgrade, downgrade e rollback

Mudanças explícitas criam um snapshot durável antes da instalação:

```console
boss4d upgrade github.com/hashload/horse@3.2.1
boss4d downgrade github.com/hashload/horse@3.1.0
boss4d rollback
```

Os snapshots ficam em `.boss4d/version-history/` e contêm `boss.json`,
`boss-lock.json` e `modules/`. `upgrade` aceita somente uma versão SemVer exata
maior; `downgrade`, somente uma menor. `rollback` restaura o snapshot mais
recente de forma transacional, inclusive as fontes instaladas.

## Disponibilidade do Registry

Índices HTTP são armazenados em `BOSS_HOME/registry-cache`. Uma resposta válida
substitui o cache. Se o servidor falhar depois, o Boss4D usa o último documento
válido e emite um aviso. Metadados sparse e seus mirrors ordenados seguem a
mesma política.

