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
      "provenance": "https://packages.example.com/InternalLib-2.4.0.b4dpkg.intoto.json"
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

As fontes adicionais ficam na configuração global. A falha de uma fonte gera
aviso sem ocultar resultados das demais. Schemas desconhecidos são rejeitados,
e a URL de um artefato sempre deve estar acompanhada de seu SHA-256 imutável,
inclusive dentro de `versions`.

O catálogo da GUI e a busca do RAD Studio usam o mesmo serviço da CLI.
