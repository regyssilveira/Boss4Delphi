# Templates de projeto

`boss4d new <template> <nome> [--path diretório]` oferece:

| Template | Resultado |
| --- | --- |
| `app` | Aplicação console Delphi |
| `package` | Esqueleto de unit/pacote reutilizável |
| `vcl` | Aplicação de formulários VCL |
| `fmx` | Aplicação FireMonkey |
| `api`, `horse-api`, `dext-api` | API HTTP Horse incluindo Dext |
| `dunitx` | Runner DUnitX e fixture de exemplo |
| `lazarus-app` | Aplicação Lazarus `.lpr`/`.lpi` |
| `lazarus-package` | Pacote Lazarus `.lpk` |
| `workspace` | Monorepo `apps/*` e `packages/*` |

Todo template cria `boss.json`, recusa sobrescrever destino não vazio e declara
projetos, dependências, dependências de desenvolvimento ou workspaces conforme
necessário.
