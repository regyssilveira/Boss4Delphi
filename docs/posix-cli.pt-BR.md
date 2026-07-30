# CLI FPC/Linux

O Boss4D inclui um host nativo em FPC 3.2.2, compilado e testado no Linux, em
vez de apenas cross-compilado no Windows:

```powershell
./scripts/ci-fpc-linux.ps1
```

O script usa a imagem Docker existente `fpc-test:latest`, gera um executável
Linux x86-64, executa a suíte FPCUnit e valida `version` e `platform`.

O host portável oferece:

- `version` e `platform`;
- `init`, produzindo um `boss.json` compatível;
- `add`, `remove` e `list`, incluindo `devDependencies`;
- `install`, clonando dependências Git declaradas para `modules`;
- geração do lock schema v3 e detecção de divergência do manifesto;
- `install --locked`, `--frozen-lockfile`, `--offline` e `--production`;
- `ci`, como atalho de automação locked e frozen;
- `--resolution=highest|minimal` para intervalos de tags Git `^` e `~`.

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

A transação Linux prepara cada clone em um diretório temporário e remove os
módulos criados quando a operação falha. O modo offline nunca consulta o Git e
falha quando um módulo local necessário não existe. Os testes FPCUnit cobrem
manifesto legado, edição de dependências, escopo de produção, lock v3,
divergência em modo frozen, nome físico da dependência e seleção SemVer
highest/minimal.

O CLI Windows continua responsável por integração IDE/GetIt, coleta da
toolchain no SBOM, alterações no Registro e autoatualização. O comportamento do
Registro do Windows não é simulado no POSIX.
