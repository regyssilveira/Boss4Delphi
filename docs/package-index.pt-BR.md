# Índices e descoberta de pacotes

O Boss4D possui um catálogo inicial embutido e combina múltiplos índices
públicos, privados, HTTP ou arquivos JSON locais.

```console
boss4d registry add https://packages.example.com/boss4d-index.json
boss4d registry add C:\empresa\boss4d-index.json
boss4d registry list
boss4d search database
boss4d info InternalLib
boss4d registry remove C:\empresa\boss4d-index.json
```

Formato do índice:

```json
{
  "schemaVersion": 1,
  "packages": [{
    "name": "InternalLib",
    "repository": "git.example.com/team/internal",
    "description": "Biblioteca Delphi interna",
    "version": "2.4.0",
    "license": "MIT",
    "artifact": "https://packages.example.com/InternalLib-2.4.0.b4dpkg",
    "sha256": "..."
  }]
}
```

As fontes ficam na configuração global. A falha de uma fonte gera aviso sem
ocultar resultados das demais. O catálogo da GUI e a busca do RAD Studio usam
o mesmo serviço da CLI.
