# Onboarding de publishers

O Registry público é mantido por pull requests Git revisados. Um publisher não
pode enviar metadados mutáveis diretamente ao repositório.

## Primeiro cadastro

1. Adicione uma entrada única em `registry/publishers.json`.
2. Adicione em `githubOwners` os logins GitHub autorizados a enviar mudanças.
   Para organizações, liste os mantenedores humanos autorizados.
3. Declare somente prefixos de repositórios controlados pelo publisher.
4. Adicione ao menos um fingerprint OpenPGP completo de 40 caracteres em
   `allowedSigners`.
5. Copie `registry/package-template.json` para
   `registry/packages/<nome-normalizado>.json`.
6. Preencha `publisher` e `signerFingerprint` com valores cadastrados.
7. Adicione `packages/<nome-normalizado>.json` em `sparse` no
   `registry/index-v2.json`.
8. Abra a PR usando uma conta declarada em `githubOwners`.

Cada versão exige o `.b4dpkg`, seu SHA-256 exato, assinatura OpenPGP destacada
e proveniência in-toto. Escopo do repositório, autorização do signatário,
versão semântica, variantes e evidências são verificados automaticamente.
Um cadastro somente de publisher pode começar com `allowedSigners` vazio;
nenhum pacote será aceito até que um owner autorizado cadastre um signatário.

O workflow entrega `github.actor` ao validador. Um publisher novo deve incluir
essa conta em `githubOwners`. Mudanças de publisher existente são autorizadas
contra os owners presentes no branch de destino; assim, um colaborador não
consegue adicionar a si próprio e um novo signatário na mesma PR. Submissões de
pacotes também ficam limitadas aos owners cadastrados.

## Gerando uma submissão de pacote

Depois de cadastrar publisher e signatário, gere o documento do pacote e a
entrada do índice sparse em conjunto:

```powershell
./scripts/new-registry-submission.ps1 `
  -PackageName MeuPacote `
  -Publisher meu-publisher `
  -Repository github.com/owner/meu-pacote `
  -SignerFingerprint 0123456789ABCDEF0123456789ABCDEF01234567 `
  -Version 1.0.0 `
  -Artifact https://github.com/owner/meu-pacote/releases/download/v1.0.0/MeuPacote-1.0.0.b4dpkg `
  -Sha256 <64-caracteres-hexadecimais> `
  -Signature https://github.com/owner/meu-pacote/releases/download/v1.0.0/MeuPacote-1.0.0.b4dpkg.asc `
  -Provenance https://github.com/owner/meu-pacote/releases/download/v1.0.0/MeuPacote-1.0.0.b4dpkg.intoto.json `
  -Description "Meu pacote" `
  -License MIT
```

O gerador valida publisher, escopo do repositório, signatário, SemVer, SHA-256
e URLs HTTPS antes de gravar. Ele cria
`registry/packages/<nome-normalizado>.json` e atualiza `index-v2.json` em
conjunto, recusando sobrescrever metadados existentes.

## Imutabilidade

Objetos de versões existentes não podem ser alterados nem removidos. O
publisher adiciona outra versão ou envia uma revogação no índice raiz. O check
do pull request compara a submissão com o branch de destino; mudanças em
checksum, URL, assinatura, proveniência ou seletores de uma versão existente
falham.

Execute localmente:

```powershell
./scripts/validate-registry-submission.ps1 -Submitter <seu-login-github>
./scripts/test-registry-submission.ps1
./scripts/test-new-registry-submission.ps1
```

A aprovação no Registry estabelece a política do catálogo; durante a
instalação, o cliente ainda verifica checksum, assinatura OpenPGP e
proveniência.

O portal gerado distingue deliberadamente um repositório que apenas corresponde
a um namespace registrado de um pacote schema v2 cujo signatário declarado é
autorizado. O cadastro do publisher é identidade administrativa, não prova de
que uma release específica foi assinada.
