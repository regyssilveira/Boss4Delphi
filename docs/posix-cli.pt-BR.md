# CLI FPC/Linux

O Boss4D inclui um host nativo em FPC 3.2.2, compilado e testado no Linux, em
vez de apenas cross-compilado no Windows:

```powershell
./scripts/ci-fpc-linux.ps1
```

O script usa a imagem Docker existente `fpc-test:latest`, gera um executável
Linux x86-64, executa a suíte FPCUnit e valida comandos reais da CLI.

O host portável oferece:

- `version` e `platform`;
- `init`, produzindo um `boss.json` compatível;
- `add`, `remove` e `list`, incluindo `devDependencies`;
- `install`, clonando dependências Git declaradas para `modules`;
- geração do lock schema v3 e detecção de divergência do manifesto;
- `install --locked`, `--frozen-lockfile`, `--offline` e `--production`;
- `ci`, como atalho de automação locked e frozen;
- `--resolution=highest|minimal` para intervalos de tags Git `^` e `~`;
- `search` e `info` para Registry v1/v2, incluindo índices compostos;
- fontes persistentes com `registry add|remove|list` no `boss.cfg.json`;
- cache HTTP do Registry, modo `--offline` e fallback automático para cache.
- instalação `.b4dpkg`, mirrors verificados, OpenPGP e proveniência;
- SBOM CycloneDX/SPDX, VEX e auditoria OSV;
- credenciais seguras, cache, workspaces e ferramentas globais FPC;
- `dependencies`/`tree`, `why`, `outdated`, `update` transacional e `run`;
- documentação estática pesquisável de APIs com `doc`;
- autoatualização verificada, empacotamento determinístico e publicação segura.

```console
boss4d registry add https://packages.example/index-v2.json
boss4d registry list
boss4d search horse
boss4d info Horse
boss4d search horse --offline
boss4d search horse --registry=./registry/index-v2.json
boss4d dependencies
boss4d why horse
boss4d outdated
boss4d update
boss4d run test
boss4d doc --output docs-api
```

O mapa original de dependências não muda:

```json
{
  "dependencies": {
    "github.com/hashload/horse": "^3.0.0"
  }
}
```

Manifestos existentes não precisam de migração. Metadados novos ficam no
`boss-lock.json`; seções opcionais ausentes, como `devDependencies`, continuam
válidas.

A transação Linux prepara cada clone em diretório temporário e remove os
módulos criados quando a operação falha. O modo offline nunca consulta o Git e
falha quando um módulo local necessário não existe. Os testes FPCUnit cobrem
manifesto legado, ciclo de dependências, lock v3, frozen, SemVer, composição
Registry v1/v2, prevenção de ciclos, persistência de fontes, compatibilidade da
configuração, cache offline e fallback por falha de rede.

A CLI Windows continua responsável pela integração RAD Studio IDE/GetIt e pela
coleta da toolchain Windows. O comportamento do Registro do Windows não é
simulado no POSIX; dependências, Registry, conformidade, publicação,
atualização e ferramentas globais são nativos no Linux.
