# Índices e descoberta de pacotes

O Boss4D consulta o registro público oficial por padrão e combina múltiplos
índices privados, HTTP ou arquivos JSON locais. Se o registro público estiver
temporariamente indisponível, a busca continua funcionando com o catálogo
inicial offline embutido e todas as demais fontes configuradas.

```console
boss4d registry add https://packages.example.com/boss4d-index.json
boss4d registry add C:\empresa\boss4d-index.json
boss4d registry list
boss4d search database
boss4d info InternalLib
boss4d package versions InternalLib
boss4d package install InternalLib@^2.0.0
boss4d registry remove C:\empresa\boss4d-index.json
```

O ponto de entrada oficial usa o schema v2 e fica versionado no Git. A versão
2 compõe catálogos por referências relativas, permitindo manter famílias de
pacotes em arquivos ou repositórios separados:

```json
{
  "schemaVersion": 2,
  "includes": [
    "community/index-v1.json",
    "company/index-v2.json"
  ],
  "packages": [{
    "name": "InternalLib",
    "repository": "git.example.com/team/internal",
    "description": "Biblioteca Delphi interna",
    "license": "MIT",
    "versions": [{
      "version": "2.4.0",
      "artifact": "https://packages.example.com/InternalLib-2.4.0.b4dpkg",
      "sha256": "...",
      "signature": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.asc",
      "provenance": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.intoto.json",
      "variants": [{
        "platform": "Win64",
        "compiler": "37.0",
        "artifact": "https://packages.example.com/InternalLib-2.4.0-win64-d37.b4dpkg",
        "sha256": "..."
      }, {
        "platform": "Linux64",
        "artifact": "https://packages.example.com/InternalLib-2.4.0-linux64.b4dpkg",
        "sha256": "..."
      }]
    }]
  }]
}
```

As referências podem ser URLs HTTP(S), caminhos locais absolutos ou caminhos
relativos ao índice que as declara. Ciclos são detectados e carregados apenas
uma vez. O validador de conformidade rejeita travessia insegura para diretórios
pais.

O schema v1 continua totalmente suportado. Índices existentes e o mapa
string/string original de `dependencies` no `boss.json` não precisam de
migração. No v2, `versions` é opcional, e um pacote ainda pode expor os campos
compatíveis com v1 `version`, `artifact` e `sha256` no nível superior.

## Metadados esparsos e revogação

Registros grandes no schema v2 podem manter um documento de metadados por
pacote. O índice principal referencia esses documentos em `sparse`; cada um
segue o contrato normal de `packages`:

```json
{
  "schemaVersion": 2,
  "sparse": [
    "packages/horse.json",
    {
      "path": "packages/dext.json",
      "mirrors": ["https://mirror.example/packages/dext.json"]
    }
  ],
  "revocations": [{
    "name": "InternalLib",
    "version": "2.4.0",
    "reason": "solicitação do publisher"
  }],
  "packages": []
}
```

Uma versão também pode declarar `"revoked": true` e `revocationReason`. A
resolução escolhe a primeira versão não revogada. Uma revogação no índice raiz
prevalece sobre metadados incluídos ou esparsos, e a instalação recusa a versão
selecionada quando revogada. O histórico permanece disponível para preservar
as evidências de lockfiles e auditorias.

Objetos de metadados esparsos tentam primeiro `path` e depois cada item de
`mirrors` na ordem declarada. Versões e variantes de plataforma/compilador
também podem declarar `mirrors` com URLs alternativas do artefato. Todo
candidato precisa corresponder ao mesmo SHA-256 imutável; um mirror acessível,
mas alterado, é rejeitado e a resolução continua na próxima origem.

As variantes de artefato são opcionais e não alteram o `boss.json`. Para
selecioná-las:

```text
boss4d package install InternalLib --platform Win64 --compiler 37.0
```

A seleção é determinística: plataforma e compilador exatos, somente plataforma,
somente compilador e, por fim, uma variante genérica. Uma variante com seletor
não vazio incompatível nunca é escolhida. Quando não há artefato compatível, a
instalação usa a fonte Git indexada, exceto com `--no-source-fallback`.

As fontes adicionais ficam na configuração global. A falha de uma fonte gera
aviso sem ocultar resultados das demais. Schemas desconhecidos são rejeitados,
e a URL de um artefato sempre deve estar acompanhada de seu SHA-256 imutável,
inclusive dentro de `versions`.

O catálogo da GUI e a busca do RAD Studio usam o mesmo serviço da CLI.

Metadados HTTP são persistidos após cada resposta válida. Falhas de rede ou do
servidor usam a última cópia válida. O cliente POSIX também utiliza requisições
condicionais com `ETag` e `Last-Modified` e oferece resolução estrita somente
por cache com `--offline`.
