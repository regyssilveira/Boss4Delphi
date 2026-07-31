# Pacotes imutáveis do Boss4D

`boss4d pack` cria um artefato `.b4dpkg` determinístico:

```text
boss4d pack
boss4d pack --output dist/minha-biblioteca-1.0.0.b4dpkg
boss4d pack --output dist/minha-biblioteca-1.0.0.b4dpkg --sign release@example.com
```

O formato v1 é um envelope JSON canônico com `format`, `schemaVersion` e uma
lista de arquivos ordenada. Cada arquivo possui caminho normalizado, digest
SHA-256 e conteúdo Base64. Saídas geradas, `.git`, `modules`, `dist` e scratch
são excluídos.

A mesma árvore produz os mesmos bytes e SHA-256. O empacotamento também grava
uma declaração in-toto Statement v1 em `.intoto.json`. Com `--sign`, o GPG cria
e verifica uma assinatura destacada `.asc`.

No Windows, o Boss4D descobre o GnuPG por `BOSS4D_GPG`, pelo Git for Windows ou
por uma instalação padrão do GnuPG antes de recorrer ao `gpg` do `PATH`. Assim
o fluxo de release pode usar o `usr\bin\gpg.exe` incluído no Git sem alterar o
`PATH` global da máquina. `BOSS4D_GPG` deve conter somente o caminho do
executável, nunca material da chave ou senha.

## Instalação verificada

Uma versão no Registry v2 pode publicar as evidências:

```json
{
  "version": "1.0.0",
  "artifact": "https://packages.example/minha-biblioteca-1.0.0.b4dpkg",
  "sha256": "...",
  "signature": "https://packages.example/minha-biblioteca-1.0.0.b4dpkg.asc",
  "provenance": "https://packages.example/minha-biblioteca-1.0.0.b4dpkg.intoto.json"
}
```

```text
boss4d package install minha-biblioteca
boss4d package install minha-biblioteca --platform linux --compiler 3.2.2
boss4d package install minha-biblioteca --no-source-fallback
```

O Boss4D baixa para uma área isolada, confere o SHA-256 externo, valida caminhos
e digests internos, verifica assinatura OpenPGP e o subject in-toto declarados,
e somente então substitui o módulo. Uma falha preserva o destino anterior.

Por padrão, um artefato ausente ou recusado usa a fonte Git indexada.
`--no-source-fallback` torna o artefato imutável obrigatório. A CLI nativa
Linux/FPC oferece o mesmo fluxo e seleciona variantes por
plataforma/compilador. Ela requer `gpg` no `PATH` quando houver assinatura e
`sha256sum` para as verificações de integridade.

Consumidores rejeitam versões desconhecidas do formato em vez de inferir sua
semântica.
