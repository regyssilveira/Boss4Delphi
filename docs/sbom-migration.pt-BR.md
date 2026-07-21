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
boss4d sbom --format cyclonedx --lock-only --strict --validate --reproducible \
  --output dist/sbom/boss4d.cdx.json \
  --attestation-output dist/sbom/boss4d.cdx.intoto.json
boss4d sbom --format spdx --lock-only --strict --validate --reproducible \
  --output dist/sbom/boss4d.spdx.json \
  --attestation-output dist/sbom/boss4d.spdx.intoto.json
```

`--lock-only` não lê nem exige `boss.json` e rejeita todos os coletores ambientais
`--include-*`. Sem `--lock-only`, os arquivos de projeto e lock são usados e os
coletores opcionais podem enriquecer o resultado.

Os coletores de ambiente são opt-in. Use-os em um agente de build controlado quando
o inventário GetIt instalado, o compilador/RTL Delphi ou os artefatos binários
declarados no lock fizerem parte do escopo. Falha de coletor é registrada como
cobertura incompleta; nunca é convertida em inventário vazio.

Pacotes GetIt instalados são inventário ambiental com uso desconhecido; eles só
viram dependências da raiz quando o uso pelo projeto é declarado em
`sbom.components` com `"source": "getit"`. Cada bloco `artifacts` do lock pode usar
`"base"` igual a `project`, `module` ou `absolute`; a omissão mantém o comportamento
compatível `project`. Traversal para fora da base selecionada é rejeitado.

CycloneDX pode importar um VEX offline com `--vex`. Atestações destacadas criadas
por `--attestation-output` podem ser verificadas depois com `--verify-attestation`;
a verificação falha se os bytes do SBOM forem alterados. SPDX 2.3 não aceita
`--vex` porque não possui perfil de segurança equivalente.

A saída CycloneDX usa a versão 1.7 e a saída SPDX usa a versão 2.3. Consumidores
devem validar o documento contra a versão correspondente. O SBOM fornece evidência
de inventário e proveniência; isoladamente, não comprova conformidade legal nem
substitui análise de vulnerabilidades.
Consulte os [exemplos SBOM](sbom-examples.pt-BR.md) para comandos e entradas JSON
completos.
