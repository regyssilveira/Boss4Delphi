# Plano de migração schema v2 do Registry público

Este plano foi auditado contra os repositórios públicos do GitHub em 31 de
julho de 2026. Ele é planejamento operacional, não metadado confiável de
pacote. Um pacote só se torna confiável depois que publisher, escopo do
repositório, fingerprint OpenPGP, digest, assinatura destacada e proveniência
passarem nos checks do pull request do Registry.

## Ponto de partida

- 55 pacotes legados v1 pesquisáveis;
- 18 responsáveis por repositórios;
- 16 pacotes no namespace `regyssilveira`, já cadastrado;
- 10 pacotes no namespace `HashLoad`;
- zero pacotes schema v2 e zero fingerprints autorizados;
- 3 pacotes do publisher aprovados nos gates atuais de reprodutibilidade;
- 13 pacotes do publisher que precisam de release ou correção da tag;
- saúde: 55 pacotes, 109 avisos de migração e zero erros estruturais.

O portal gerado do Registry é o painel público do progresso. No momento ele
informa 0 pacotes verificados, 55 pacotes legados e 0% de migração verificada.
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

### Primeiro artefato preparado

A tag imutável `v1.6.0` (`e53b8eb`) já foi empacotada com o packer
determinístico atual:

- artefato: `Boss4Delphi-1.6.0.b4dpkg`;
- tamanho: 9.166.284 bytes;
- SHA-256:
  `903d6c3349fe75892430273a577d1b13f65d81f2f0ebe854b046ba9b4d1bda0b`;
- digest do subject in-toto: verificado como igual ao digest do artefato;
- gates restantes: assinatura OpenPGP, fingerprint autorizado, upload do asset
  e pull request oficial do Registry.

## Onda 1 — pacotes do publisher com release pronta

Os repositórios abaixo já possuem release GitHub com tag e pertencem ao escopo
do publisher cadastrado:

| Pacote | Candidato | Estado |
|---|---:|---|
| Boss4Delphi | v1.6.0 | Primeira prova ponta a ponta |
| horse-rate-limit | v1.0.0 | Bloqueado: dependência REST de teste não declarada e unit ausente |
| horse-compression-v2 | v1.0.0 | Bloqueado: tag declara `2.0.0` no `boss.json` |
| horse-static | v1.0.0 | Bloqueado: manifesto de testes referencia repositório inexistente |
| horse-dto | v1.0.0 | Bloqueado: não compila com o Horse 3.2.0 resolvido |
| horse-rbac | v1.0.0 | Bloqueado: testes não compilam com o Horse 3.2.0 resolvido |
| horse-schema-validation | v1.0.0 | Pronto: instalação, compilação e 10/10 testes aprovados |
| horse-multipart | v1.0.0 | Pronto: instalação, compilação e teste real de upload aprovados |
| horse-helmet | v1.0.0 | Bloqueado: manifesto de testes referencia repositório inexistente |
| horse-ssl-redirect | v1.0.0 | Bloqueado: testes não compilam com o Horse 3.2.0 resolvido |
| horse-request-id | v1.0.0 | Bloqueado: usa request services ausentes no Horse 3.2.0 |
| horse-opentelemetry | v1.0.0 | Bloqueado: dependência legada resolve para `https://horse/` |
| horse-prometheus | v1.0.0 | Bloqueado: dependência legada resolve para `https://horse/` |

Cada migração deve compilar e testar a tag imutável, produzir `.b4dpkg`,
assinatura OpenPGP e proveniência in-toto, enviar os arquivos para a release da
tag e usar `boss4d publish --official --open-pr`.

Onze candidatos de middleware com manifestos `v1.0.0` coerentes já foram
empacotados a partir de checkouts imutáveis detached. Todos os onze arquivos
`.b4dpkg` passam na conformidade de pacote e os onze digests do subject in-toto
correspondem aos artefatos. Eles continuam sendo preparação local até que
testes dos projetos, assinaturas OpenPGP, uploads nas releases e submissões ao
Registry estejam concluídos.
Somente `horse-schema-validation` e `horse-multipart` passam atualmente pelo
gate de testes do projeto; conformidade do pacote sozinha não significa que a
release está pronta.

### Primeiro lote de publicação

Depois que o signatário estiver protegido e autorizado, publique nesta ordem:

1. Boss4Delphi `v1.6.0` como prova ponta a ponta da política;
2. `horse-schema-validation` `v1.0.0`, com 10 testes Delphi aprovados;
3. `horse-multipart` `v1.0.0`, com teste real de upload aprovado.

Para cada pacote, repita a mesma sequência imutável: assine e verifique o
`.b4dpkg` preparado, envie `.b4dpkg`, `.asc` e `.intoto.json` para aquela
release exata do GitHub, valide as três URLs públicas e o digest, execute
`publish --official --dry-run` e depois `publish --official --open-pr`. Nunca
reutilize a URL de evidência de um pacote em outro.

## Onda 2 — pacotes do publisher que precisam de release

`Dext`, `horse-crud` e `horse-sanitize` ainda não possuem tag/release
publicada. Os dez pacotes bloqueados da Onda 1 também precisam de manifestos,
testes ou compatibilidade com Horse corrigidos em novas releases imutáveis.
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
