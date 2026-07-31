# Conformidade, portal do registro e benchmarks

Implementadores do protocolo podem validar artefatos públicos com as mesmas
regras usadas pelo Boss4D:

```text
boss4d conformance registry registry/index-v2.json
boss4d conformance package dist/biblioteca.b4dpkg
```

A conformidade do registro aceita schemas v1/v2, nome e repositório dos pacotes e
metadados pareados de URL/SHA-256. A conformidade do pacote verifica formato
v1, caminhos relativos seguros, conteúdo Base64 e o SHA-256 de cada arquivo.

Um portal estático e independente de host pode ser gerado de qualquer índice
conforme:

```text
boss4d registry portal registry/index-v2.json registry/index.html
```

O portal pesquisável apresenta pacotes v1/v2, histórico de versões, revogações
e evidências disponíveis de SHA-256, assinatura e proveniência. Todo metadado
não confiável é escapado no HTML. A pasta `registry/` pode ser
servida pelo GitHub Pages, CDN ou qualquer servidor HTTP estático; o índice
JSON é a autoridade do protocolo e o portal é somente sua projeção legível.

Para uma entrada v2 local, o comando compõe recursivamente os documentos de
`includes` e `sparse`, carrega cada documento uma única vez e aplica suas
revogações antes da renderização. As referências devem permanecer dentro do
diretório da entrada. Travessia para o diretório pai e referências HTTP são
rejeitadas; materialize localmente um registry remoto antes de gerar um portal
determinístico.

O desempenho e o determinismo do pack podem ser acompanhados com:

```powershell
./scripts/benchmark-pack.ps1 -Iterations 5
```

O benchmark gera JSON com latências mínima/média/máxima e falha se qualquer
iteração produzir SHA-256 diferente.
