# Plano de migração schema v2 do Registry público

Este plano foi auditado contra os repositórios públicos do GitHub em 31 de
julho de 2026. Ele é planejamento operacional, não metadado confiável de
pacote. Um pacote só se torna confiável depois que publisher, escopo do
repositório, fingerprint OpenPGP, digest, assinatura destacada e proveniência
passarem nos checks do pull request do Registry.

## Ponto de partida

- 41 pacotes legados v1 pesquisáveis;
- 18 responsáveis por repositórios;
- 16 pacotes no namespace `regyssilveira`, já cadastrado;
- 10 pacotes no namespace `HashLoad`;
- 14 pacotes schema v2 assinados e um fingerprint autorizado;
- 14 pacotes do publisher publicados pelos gates de reprodutibilidade;
- 2 pacotes do publisher que precisam de release;
- saúde: 55 pacotes, 82 avisos de migração e zero erros estruturais.

O portal gerado do Registry é o painel público do progresso. No momento ele
informa 14 pacotes verificados, 41 pacotes legados e 25% de migração verificada.
Cada pacote schema v2 aceito com fingerprint autorizado para o publisher
incrementa essa métrica automaticamente.

## Onda 0 — estabelecer identidade de assinatura

1. Usar a implementação GnuPG 2.4.9 incluída no Git for Windows da estação de
   release.
2. Criar ou importar a identidade de assinatura e guardar o certificado de
   revogação fora do repositório.
3. Adicionar somente o fingerprint público completo ao publisher `boss4d`.
4. Verificar assinatura e proveniência com
   `boss4d publish --official --dry-run`.
5. Publicar primeiro o próprio Boss4D e exigir que o workflow valide os assets
   externos da release.

Chave privada, senha e material de revogação nunca devem ser commitados.

### Primeiro artefato publicado

A tag imutável `v1.6.0` (`e53b8eb`) já foi empacotada com o packer
determinístico atual:

- artefato: `Boss4Delphi-1.6.0.b4dpkg`;
- tamanho: 9.166.284 bytes;
- SHA-256:
  `903d6c3349fe75892430273a577d1b13f65d81f2f0ebe854b046ba9b4d1bda0b`;
- digest do subject in-toto: verificado como igual ao digest do artefato;
- assinatura OpenPGP, fingerprint autorizado, upload na release, instalação
  independente e metadados do Registry estão completos na PR ativa.

## Onda 1 — pacotes do publisher com release pronta

Os repositórios abaixo já possuem release GitHub com tag e pertencem ao escopo
do publisher cadastrado:

| Pacote | Candidato | Estado |
|---|---:|---|
| Boss4Delphi | v1.6.0 | Publicado e verificado ponta a ponta |
| horse-rate-limit | v1.0.1 | Publicado; suíte reparada, 14/14 testes e instalação verificada aprovados |
| horse-compression-v2 | v2.0.0 | Publicado; tag e manifesto coerentes, 3/3 testes e instalação verificada aprovados |
| horse-static | v1.0.1 | Publicado; 6/6 testes de integração estáveis e instalação verificada aprovados |
| horse-dto | v1.0.1 | Publicado; compatibilidade com Horse 3.2, 9/9 testes e instalação verificada aprovados |
| horse-rbac | v1.0.1 | Publicado; 6/6 testes de integração de autorização e instalação verificada aprovados |
| horse-schema-validation | v1.0.0 | Publicado; instalação, assinatura, proveniência e 10/10 testes aprovados |
| horse-multipart | v1.0.0 | Publicado; instalação, assinatura, proveniência e teste real de upload aprovados |
| horse-helmet | v1.0.1 | Publicado; manifesto reparado, 12/12 testes e instalação verificada aprovados |
| horse-ssl-redirect | v1.0.1 | Publicado; 8/8 testes de integração de redirect e instalação verificada aprovados |
| horse-request-id | v1.0.1 | Publicado; compatibilidade com Horse 3.2, 4/4 testes de isolamento e instalação verificada aprovados |
| horse-opentelemetry | v1.0.1 | Publicado; contexto por requisição, 62/62 asserções e instalação verificada aprovados |
| horse-prometheus | v1.0.1 | Publicado; 11/11 asserções unitárias, 5/5 asserções HTTP reais e instalação verificada aprovados |

Cada migração deve compilar e testar a tag imutável, produzir `.b4dpkg`,
assinatura OpenPGP e proveniência in-toto, enviar os arquivos para a release da
tag e usar `boss4d publish --official --open-pr`.

Onze candidatos de middleware com manifestos `v1.0.0` coerentes já foram
empacotados a partir de checkouts imutáveis detached. Todos os onze arquivos
`.b4dpkg` passam na conformidade de pacote e os onze digests do subject in-toto
correspondem aos artefatos. Eles continuam sendo preparação local até que
testes dos projetos, assinaturas OpenPGP, uploads nas releases e submissões ao
Registry estejam concluídos.
`horse-schema-validation` e `horse-multipart` concluíram os gates de testes,
assinatura, upload, Registry e instalação verificada. A conformidade do pacote
sozinha continua insuficiente para os demais candidatos.

O incremento seguinte concluiu o `horse-compression-v2` `v2.0.0`. A tag
imutável agora corresponde ao manifesto, a suíte DUnitX passa no Delphi 10
Seattle com Horse 3.2.0 e o pacote assinado instala sem fallback para o código
fonte.

Em seguida, o `horse-static` `v1.0.1` concluiu os mesmos gates após corrigir a
interrupção da cadeia nas respostas HTTP 304/416, a compatibilidade com
Seattle, o tamanho do stream de range e o isolamento dos testes. Cinco
execuções consecutivas dos seis testes passaram antes de o pacote do tag
detached limpo ser assinado e instalado sem fallback para o código-fonte.

O `horse-helmet` `v1.0.1` foi concluído em seguida após reparar a identidade da
dependência de testes e adicionar um runner reproduzível. Três execuções
consecutivas dos 12 testes, além de uma execução limpa após o merge, passaram
no Seattle antes da publicação assinada e da instalação verificada.

O `horse-rate-limit` `v1.0.1` veio em seguida após restaurar a unit de limpeza
ausente, declarar as dependências de teste e atualizar as APIs de Horse/tasks
usadas apenas nos testes para o Seattle. Quatro execuções completas dos 14
testes passaram, incluindo concorrência, Redis, CIDR, métricas e sliding
window, antes da publicação verificada.

O `horse-dto` `v1.0.1` restaurou em seguida a compatibilidade das APIs de
request, exceção, roteamento e encerramento com o Horse 3.2, além de corrigir o
binding somente por JSON sem uma requisição web ativa. Quatro execuções
consecutivas dos 9 testes, mais uma execução limpa após o merge, passaram no
Seattle. Seu pacote também motivou uma correção de regressão que exclui
ponteiros de worktree Git dos artefatos determinísticos; o bundle corrigido de
11 arquivos passou nas verificações independentes de assinatura, proveniência,
digest, conformidade e instalação sem fallback.

O `horse-rbac` `v1.0.1` veio em seguida com a adaptação dos testes de middleware
por rota e posse da sessão para o Horse 3.2 e um runner Seattle não interativo.
Quatro execuções completas dos seis cenários HTTP, além de uma execução limpa
após o merge, cobriram decisões sem autenticação, sem claim, OR e AND antes de
o bundle de 10 arquivos passar na verificação independente da assinatura e na
instalação verificada sem fallback.

O `horse-ssl-redirect` `v1.0.1` veio depois com compatibilidade dos testes por
rota com o Horse 3.2 e um runner Seattle reproduzível. Quatro execuções
completas dos oito testes, mais uma execução limpa após o merge, cobriram
política de localhost, headers HTTPS de proxy, portas TLS e status de redirect
personalizados antes de o bundle assinado de nove arquivos passar na
conformidade e na instalação verificada sem fallback.

O `horse-request-id` `v1.0.1` substituiu em seguida a dependência da API de
serviços de request indisponível por armazenamento local à requisição
compatível com Horse 3.2 e adicionou um runner Seattle reproduzível. Cinco
execuções completas dos quatro testes, mais uma execução limpa após o merge,
cobriram geração de ID, propagação dos headers de request e correlação e
isolamento concorrente antes de o bundle assinado de 10 arquivos passar nas
verificações independentes de assinatura, conformidade e instalação sem
fallback.

O `horse-opentelemetry` `v1.0.1` veio depois com a correção da identidade da
dependência Horse e a migração do contexto de trace para sessões isoladas por
requisição. Quatro execuções completas com 62 asserções, mais uma execução
limpa após o merge, cobriram criação e recuperação de contexto, parsing W3C de
`traceparent` e geração de IDs hexadecimais antes de o bundle assinado de 15
arquivos passar nas verificações independentes de assinatura, conformidade e
instalação sem fallback.

O `horse-prometheus` `v1.0.1` concluiu a Onda 1 com a correção da identidade da
dependência Horse, das APIs de request suportadas e da interrupção da cadeia
do middleware para `/metrics`. Cinco execuções completas combinaram 11
asserções unitárias e cinco asserções HTTP reais para métodos, caminhos,
status, contadores e latências antes de o bundle assinado de 16 arquivos
passar nas verificações independentes de assinatura, conformidade e instalação
sem fallback.

### Primeiro lote de publicação

O primeiro lote de publicação foi concluído nesta ordem:

1. Boss4Delphi `v1.6.0` como prova ponta a ponta da política;
2. `horse-schema-validation` `v1.0.0`, com 10 testes Delphi aprovados;
3. `horse-multipart` `v1.0.0`, com teste real de upload aprovado.

Para cada pacote, repita a mesma sequência imutável: assine e verifique o
`.b4dpkg` preparado, envie `.b4dpkg`, `.asc` e `.intoto.json` para aquela
release exata do GitHub, valide as três URLs públicas e o digest, execute
`publish --official --dry-run` e depois `publish --official --open-pr`. Nunca
reutilize a URL de evidência de um pacote em outro.

## Onda 2 — pacotes do publisher que precisam de release

O `horse-sanitize` `v1.0.0` concluiu esta onda. Sua cópia vendorizada de 107
arquivos do Horse foi substituída por uma dependência resolvida e travada pelo
Boss4D. Cinco execuções completas dos sete testes no Seattle, mais uma
execução limpa após o merge, cobriram tags, URIs JavaScript, atributos de
evento, dicionários, JSON aninhado, arrays e concorrência sem leaks. O bundle
assinado de 13 arquivos passou nas verificações independentes de assinatura,
conformidade e instalação sem fallback.

`Dext` e `horse-crud` ainda precisam de sua primeira tag/release publicada.
Antes da migração esses pacotes precisam de tag SemVer exata, testes, assets
imutáveis e o mesmo fluxo de publicação assinada.

## Onda 3 — onboarding de publishers externos

Prioridade:

1. Horse e sua família de middlewares HashLoad;
2. RESTRequest4Delphi;
3. jhonson;
4. middlewares Horse da Academia do Código;
5. demais repositórios ativos por evidência de manutenção e adoção.

O publisher externo precisa autorizar owners GitHub, prefixos de repositório e
fingerprint. Mantenedores do Registry não devem se passar pelo proprietário ou
publicar artefatos de terceiros sem assinatura como pacotes schema v2
confiáveis.

## Critérios de conclusão

- toda versão migrada possui evidências imutáveis recuperáveis;
- `boss4d registry health` a contabiliza como confiável;
- instalação verifica digest, assinatura e proveniência;
- CI Linux e macOS preservam zero erros estruturais/de confiança;
- avisos legados só diminuem quando o metadado confiável equivalente estiver
  publicado.
