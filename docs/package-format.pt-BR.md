# Pacotes imutáveis do Boss4D

`boss4d pack` cria um artefato `.b4dpkg` determinístico a partir do projeto:

```text
boss4d pack
boss4d pack --output dist/minha-biblioteca-1.0.0.b4dpkg
boss4d pack --output dist/minha-biblioteca-1.0.0.b4dpkg --sign release@example.com
```

O formato v1 é um envelope JSON canônico. Ele registra `format`,
`schemaVersion` e uma lista de arquivos ordenada pelo caminho. Cada arquivo
possui caminho normalizado com barras, digest SHA-256 e conteúdo Base64.
Binários gerados, `.git`, `modules`, `dist`, dados de scratch e saídas do
compilador são excluídos.

A mesma árvore de fontes produz os mesmos bytes e o mesmo SHA-256 do pacote.
Cada execução também grava uma declaração in-toto Statement v1 em
`.intoto.json`, vinculando nome e SHA-256 do artefato ao builder Boss4D e à
quantidade de arquivos. Com `--sign`, o Boss4D solicita ao GPG uma assinatura
destacada ASCII `.asc` e a verifica imediatamente antes de informar sucesso.
`boss4d publish` inclui esse artefato imutável e seu digest no payload de
publicação, permitindo que o registro armazene conteúdo pelo digest em vez de
estado mutável do repositório.

## Instalação verificada

Uma release no Registry v2 pode publicar as evidências do artefato em conjunto:

```json
{
  "version": "1.0.0",
  "artifact": "https://packages.example/minha-biblioteca-1.0.0.b4dpkg",
  "sha256": "...",
  "signature": "https://packages.example/minha-biblioteca-1.0.0.b4dpkg.asc",
  "provenance": "https://packages.example/minha-biblioteca-1.0.0.b4dpkg.intoto.json"
}
```

Para instalar um pacote indexado:

```text
boss4d package install minha-biblioteca
boss4d package install minha-biblioteca --no-source-fallback
```

O Boss4D baixa o conteúdo para uma área isolada, confere o SHA-256 do pacote,
valida cada caminho e digest interno, verifica a assinatura OpenPGP declarada
e o digest do subject in-toto, e somente depois substitui o diretório do
módulo. Uma falha de verificação preserva o destino anterior.

Por padrão, um artefato indisponível ou recusado usa o repositório Git indexado
como fallback. `--no-source-fallback` torna obrigatório o artefato imutável.
Assinatura e proveniência são obrigatórias sempre que suas URLs forem
declaradas pelo registro.

O formato prioriza auditoria e determinismo. Versões futuras podem introduzir
compactação, mas consumidores devem rejeitar versões desconhecidas em vez de
inferir sua semântica.
