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

As fontes adicionais ficam na configuração global. A falha de uma fonte gera
aviso sem ocultar resultados das demais. Protocolos com versão desconhecida
são rejeitados, e a URL do artefato sempre é associada ao seu SHA-256 imutável.
O catálogo da GUI e a busca do RAD Studio usam o mesmo serviço da CLI.
