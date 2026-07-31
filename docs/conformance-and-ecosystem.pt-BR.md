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
boss4d registry search-index registry/index-v2.json registry/search-index.json
```

O portal aponta para um formulário de entrada aberto à comunidade. Qualquer
pessoa pode propor um pacote, mas a proposta permanece como issue e não entra
sozinha no índice do protocolo nem nos resultados de busca. A publicação exige
pull request de um publisher autorizado, todos os checks automáticos do
Registry, uma aprovação explícita do `CODEOWNER` do Registry e a resolução das
discussões de revisão. Novos pushes invalidam aprovações anteriores. O ruleset
da `main` aplica esses requisitos; os mantenedores preservam bypass
administrativo para recuperação do repositório e operações de suas próprias
releases.

O portal responsivo apresenta estatísticas e filtra pacotes por texto,
confiança do publisher, estado da migração verificada, plataforma e compilador.
Os contadores de migração diferenciam intencionalmente um namespace registrado
de um pacote verificado: somente metadados schema v2 cujo fingerprint declarado
é autorizado para o publisher contam como migrados. Também exibe histórico
v1/v2, revogações e evidências disponíveis de SHA-256, assinatura e
proveniência. Todo metadado não confiável é escapado no HTML. O índice de busca complementar é um
snapshot JSON determinístico e completamente composto, adequado para GitHub
Pages, CDN ou um serviço de busca hospedado. A pasta `registry/` pode ser
servida pelo GitHub Pages, CDN ou qualquer servidor HTTP estático; o índice
JSON é a autoridade do protocolo e o portal é somente sua projeção legível.

Para uma entrada v2 local, o comando compõe recursivamente os documentos de
`includes` e `sparse`, carrega cada documento uma única vez e aplica suas
revogações antes da renderização. As referências devem permanecer dentro do
diretório da entrada. Travessia para o diretório pai e referências HTTP são
rejeitadas; materialize localmente um registry remoto antes de gerar um portal
determinístico.

Quando existe um `publishers.json` ao lado da entrada, o portal também projeta
a identidade do publisher. `registered namespace` significa somente que o
repositório corresponde a um prefixo revisado. `authorized publisher` também
exige que o pacote declare um fingerprint permitido. Nenhum dos rótulos
substitui a verificação do artefato: SHA-256, assinatura destacada e
proveniência continuam sendo evidências independentes e aparecem separadamente.

O desempenho e o determinismo do pack podem ser acompanhados com:

```powershell
./scripts/benchmark-pack.ps1 -Iterations 5
```

O benchmark gera JSON com latências mínima/média/máxima e falha se qualquer
iteração produzir SHA-256 diferente.

## Publicação estática oficial

O `.github/workflows/registry-pages.yml` valida catálogo composto, portal,
índice de busca e cadastro de publishers antes de enviar somente `registry/`
como artefato do GitHub Pages. O deploy usa o ambiente protegido
`github-pages`, OIDC e `pages: write` restrito ao job; o padrão do workflow
permanece `contents: read`.

Depois que o workflow chegar ao `main`, um administrador precisa selecionar
**GitHub Actions** como origem do Pages uma única vez. As mudanças seguintes do
Registry serão validadas e publicadas automaticamente. Índice de busca
desatualizado, pacote ausente, referência insegura, estado de migração ausente
ou portal incompleto interrompem a publicação.
