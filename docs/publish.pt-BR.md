# Publicação de pacotes

`boss4d publish` cria um registro determinístico a partir de `boss.json` e
`boss-lock.json`, valida seu conteúdo e, opcionalmente, envia-o a um registro
privado. Assim, o manifesto revisado e as evidências travadas da cadeia de
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

## Contrato do registro

O Boss4D envia um `POST` autenticado com JSON para `<registro>/packages`. O
payload contém identidade e metadados descritivos do pacote, versão do schema do
lock e dependências ordenadas pela chave canônica, com versão, repositório,
revisão imutável, checksum e escopo. O registro deve retornar um status 2xx.
Tokens nunca são gravados no manifesto, lock ou payload.

O comando publica metadados e evidências da cadeia de suprimentos; binários de
release e arquivos de código-fonte continuam sendo artefatos do pipeline de
release do projeto.
