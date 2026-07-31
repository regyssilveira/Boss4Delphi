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
- saúde: 55 pacotes, 109 avisos de migração e zero erros estruturais.

## Onda 0 — estabelecer identidade de assinatura

1. Instalar uma implementação OpenPGP na estação de release.
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
| horse-rate-limit | v1.0.0 | Pronto após onboarding do signer |
| horse-compression-v2 | v1.0.0 | Pronto após onboarding do signer |
| horse-static | v1.0.0 | Pronto após onboarding do signer |
| horse-dto | v1.0.0 | Pronto após onboarding do signer |
| horse-rbac | v1.0.0 | Pronto após onboarding do signer |
| horse-schema-validation | v1.0.0 | Pronto após onboarding do signer |
| horse-multipart | v1.0.0 | Pronto após onboarding do signer |
| horse-helmet | v1.0.0 | Pronto após onboarding do signer |
| horse-ssl-redirect | v1.0.0 | Pronto após onboarding do signer |
| horse-request-id | v1.0.0 | Pronto após onboarding do signer |
| horse-opentelemetry | v1.0.0 | Pronto após onboarding do signer |
| horse-prometheus | v1.0.0 | Pronto após onboarding do signer |

Cada migração deve compilar e testar a tag imutável, produzir `.b4dpkg`,
assinatura OpenPGP e proveniência in-toto, enviar os arquivos para a release da
tag e usar `boss4d publish --official --open-pr`.

## Onda 2 — pacotes do publisher sem release

`Dext`, `horse-crud` e `horse-sanitize` ainda não possuem tag/release
publicada. Antes da migração precisam de tag SemVer exata, testes, assets
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
