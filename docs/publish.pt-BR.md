# Publicação de pacotes

`boss4d publish` cria um registro determinístico a partir de `boss.json` e
`boss-lock.json` e valida seu conteúdo. Existem dois destinos explícitos:

- um Registry HTTP compatível recebe o payload autenticado do protocolo;
- o Registry público oficial é governado por Git e recebe pull requests
  revisados, não publicação HTTP.

Assim, o manifesto
revisado e as evidências travadas da cadeia de
suprimentos são a origem dos metadados publicados.

## Bloqueios de segurança

A publicação para quando manifesto ou lock não existem, a identidade do pacote
diverge entre eles, o lock não usa o schema v3 ou alguma dependência não possui
revisão e checksum SHA-256. Por padrão, o worktree Git deve estar limpo e o
script `test` do manifesto é executado quando existir.

Inspecione o payload exato sem acesso à rede:

```console
boss4d publish --dry-run --output publish.json
```

Para um envio real, mantenha o token fora do histórico do terminal:

```console
set BOSS4D_PUBLISH_TOKEN=seu-token
boss4d publish --registry https://registry.example/api
```

## Preparar submissão para o Registry público oficial

Um único comando local executa os gates, cria o `.b4dpkg` imutável, gera a
proveniência in-toto, assina e verifica o artefato com OpenPGP e produz o
documento schema v2:

```console
boss4d publish --official ^
  --publisher meu-publisher ^
  --repository github.com/owner/projeto ^
  --fingerprint 0123456789ABCDEF0123456789ABCDEF01234567 ^
  --sign 0123456789ABCDEF0123456789ABCDEF01234567 ^
  --artifact-url https://github.com/owner/projeto/releases/download/v1.2.3/projeto-1.2.3.b4dpkg
```

As saídas padrão são `dist/<nome>-<versão>.b4dpkg`, sua assinatura `.asc`,
sua proveniência `.intoto.json` e
`dist/<nome>-<versão>.registry.json`. Use `--artifact-output` e
`--submission-output` para alterar os caminhos.

`--dry-run` executa os gates de manifesto, lock, worktree limpo, testes,
identidade, SemVer, HTTPS, formato do hash e signer sem criar o bundle. O
comando não envia assets nem modifica o repositório do Registry. Envie as três
evidências para a URL imutável da release, copie o documento gerado para o
checkout do Registry e abra a PR revisada. O workflow do Registry verifica
novamente ownership, escopo do repositório, fingerprint autorizado,
imutabilidade, assinatura, proveniência e digest.

O mesmo comando está disponível no Linux/FPC. Ele cria localmente o `.b4dpkg`
determinístico e sua proveniência in-toto, inclui ambos no payload do protocolo
e exige evidências do lock v3. Dependências Git precisam de revisão e checksum;
artefatos verificados do registro usam seu checksum imutável como evidência.

A CLI Linux lê o token de `BOSS4D_PUBLISH_TOKEN` por padrão ou da variável
indicada por `--token-env`. Se nenhuma estiver definida, consulta a credencial
`registry` no Secret Service. O token é enviado somente no cabeçalho de
autorização HTTP e nunca é gravado no payload.

Identidades publicadas `(nome, versão)` são imutáveis. Uma resposta HTTP 409 é
informada como conflito de versão; a CLI nunca tenta sobrescrever a release
existente. Publique uma nova versão ou uma revogação explícita.

Use `--token-env NOME` para escolher outra variável de ambiente. As opções
`--allow-dirty` e `--skip-tests` ignoram explicitamente os respectivos bloqueios
e devem ficar restritas a fluxos controlados de recuperação.

## Contrato do Registry HTTP

O Boss4D envia um `POST` autenticado com JSON para `<registro>/packages`. O
payload contém identidade e metadados descritivos do pacote, versão do schema do
lock e dependências ordenadas pela chave canônica, com versão, repositório,
revisão imutável, checksum e escopo. O registro deve retornar um status 2xx.
Tokens nunca são gravados no manifesto, lock ou payload.

No modo HTTP, o comando publica metadados e evidências embutidas. No modo
oficial, os assets permanecem sob controle do pipeline de release do projeto e
a alteração do Registry continua revisável em Git.
