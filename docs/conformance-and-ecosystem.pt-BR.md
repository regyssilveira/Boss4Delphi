# Conformidade, portal do registro e benchmarks

Implementadores do protocolo podem validar artefatos públicos com as mesmas
regras usadas pelo Boss4D:

```text
boss4d conformance registry registry/index-v1.json
boss4d conformance package dist/biblioteca.b4dpkg
```

A conformidade do registro exige schema v1, nome e repositório dos pacotes e
metadados pareados de URL/SHA-256. A conformidade do pacote verifica formato
v1, caminhos relativos seguros, conteúdo Base64 e o SHA-256 de cada arquivo.

Um portal estático e independente de host pode ser gerado de qualquer índice
conforme:

```text
boss4d registry portal registry/index-v1.json registry/index.html
```

Todo metadado não confiável é escapado no HTML. A pasta `registry/` pode ser
servida pelo GitHub Pages, CDN ou qualquer servidor HTTP estático; o índice
JSON é a autoridade do protocolo e o portal é somente sua projeção legível.

O desempenho e o determinismo do pack podem ser acompanhados com:

```powershell
./scripts/benchmark-pack.ps1 -Iterations 5
```

O benchmark gera JSON com latências mínima/média/máxima e falha se qualquer
iteração produzir SHA-256 diferente.
