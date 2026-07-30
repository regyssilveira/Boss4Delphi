# Pacotes imutáveis do Boss4D

`boss4d pack` cria um artefato `.b4dpkg` determinístico a partir do projeto:

```text
boss4d pack
boss4d pack --output dist/minha-biblioteca-1.0.0.b4dpkg
```

O formato v1 é um envelope JSON canônico. Ele registra `format`,
`schemaVersion` e uma lista de arquivos ordenada pelo caminho. Cada arquivo
possui caminho normalizado com barras, digest SHA-256 e conteúdo Base64.
Binários gerados, `.git`, `modules`, `dist`, dados de scratch e saídas do
compilador são excluídos.

A mesma árvore de fontes produz os mesmos bytes e o mesmo SHA-256 do pacote.
`boss4d publish` inclui esse artefato imutável e seu digest no payload do
protocolo v1, permitindo que o registro armazene conteúdo pelo digest em vez de
estado mutável do repositório.

O formato prioriza auditoria e determinismo. Versões futuras podem introduzir
compactação, mas consumidores devem rejeitar versões desconhecidas em vez de
inferir sua semântica.
