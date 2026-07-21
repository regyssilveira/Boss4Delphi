# Migração para SBOM e `boss-lock.json` v2

Locks v1 existentes continuam legíveis. Execute `boss4d install` com a CLI atualizada
para resolver novamente as dependências e salvar identidades canônicas dos
repositórios, revisões Git, checksums SHA-256 tipados, origem das licenças e arestas
do grafo no schema v2. Versione o `boss-lock.json` resultante.

O lock v2 atualizado contém uma seção `root` com nome, versão, licença e as
dependências diretas do projeto. Essa evidência permite que `--lock-only` funcione
mesmo quando `boss.json` não está disponível. No modo estrito, locks antigos sem
`root` são recusados com uma orientação para executar novamente `boss4d install`.

Gere SBOMs determinísticos de release com:

```bash
boss4d sbom --format cyclonedx --strict --validate --reproducible -o dist/sbom/boss4d.cdx.json
boss4d sbom --format spdx --strict --validate --reproducible -o dist/sbom/boss4d.spdx.json
```

Os coletores de ambiente são opt-in. Use-os em um agente de build controlado quando
o inventário GetIt instalado, o compilador/RTL Delphi ou os artefatos binários
declarados no lock fizerem parte do escopo. Falha de coletor é registrada como
cobertura incompleta; nunca é convertida em inventário vazio.

A saída CycloneDX usa a versão 1.7 e a saída SPDX usa a versão 2.3. Consumidores
devem validar o documento contra a versão correspondente. O SBOM fornece evidência
de inventário e proveniência; isoladamente, não comprova conformidade legal nem
substitui análise de vulnerabilidades.
