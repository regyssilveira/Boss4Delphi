# Onboarding de publishers

O Registry público é mantido por pull requests Git revisados. Um publisher não
pode enviar metadados mutáveis diretamente ao repositório.

## Proposta comunitária e aprovação

Use **Enviar pacote para revisão** no portal do Registry para abrir o
formulário estruturado da comunidade. Um colaborador pode propor um pacote
antes de se tornar seu publisher, mas deve identificar o proprietário do
repositório e sua autoridade para representá-lo. O formulário nunca deve
conter credenciais, chaves privadas, senhas de assinatura ou outros segredos.

Uma issue é entrada para triagem, não publicação. Os mantenedores primeiro
verificam propriedade, licença, compatibilidade, evidências de testes e
prontidão da release. O cadastro do publisher e do signatário acontece depois
por mudanças Git revisáveis. Somente um publisher autorizado pode enviar os
metadados finais do pacote assinado. O workflow do Registry usa permissão
somente de leitura, e o ruleset da `main` exige uma aprovação do `CODEOWNER` e
a resolução das discussões. Somente após o merge o pacote entra no índice
oficial e recebe o estado verificado no portal quando seu signatário também
corresponde à política do publisher.

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

## Estabelecendo um signatário de release protegido

No Windows, o Boss4D pode usar o executável GnuPG incluído no Git for Windows:

```powershell
$gpg = 'C:\Program Files\Git\usr\bin\gpg.exe'
& $gpg --version
& $gpg --full-generate-key
& $gpg --list-secret-keys --keyid-format LONG --with-fingerprint
```

Crie uma chave capaz de assinar para a identidade durável de release do
publisher, defina uma expiração que será realmente mantida e informe a senha
somente pelo pinentry protegido do GnuPG. Nunca coloque a senha em argumento,
variável de ambiente, script, log de CI ou arquivo do repositório. Copie
exatamente o fingerprint primário completo de 40 caracteres; IDs curtos não
são aceitos pelo Registry.

Exporte somente a chave pública para distribuição:

```powershell
& $gpg --armor --export <fingerprint-de-40-caracteres> |
  Set-Content -Encoding ascii boss4d-release-public.asc
```

Mantenha o backup da chave secreta e o certificado de revogação criptografados
e offline, separados da estação e do repositório. Teste recuperação e
revogação antes de confiar nessa identidade para releases. Se uma chave
organizacional existente for importada, confira seu fingerprint por um canal
independente antes de adicioná-lo a `allowedSigners`.

O workflow entrega `github.actor` ao validador. Um publisher novo deve incluir
essa conta em `githubOwners`. Mudanças de publisher existente são autorizadas
contra os owners presentes no branch de destino; assim, um colaborador não
consegue adicionar a si próprio e um novo signatário na mesma PR. Submissões de
pacotes também ficam limitadas aos owners cadastrados.
Para publisher legado anterior a `githubOwners`, uma única atualização de
bootstrap é permitida somente quando o login do autor corresponde ao namespace
pessoal `github.com/<login>/` já presente no branch de destino. As mudanças
seguintes usam exclusivamente `githubOwners`.

## Gerando uma submissão de pacote

Depois de cadastrar publisher e signatário, gere o documento do pacote e a
entrada do índice sparse em conjunto:

O caminho recomendado cria o bundle assinado, atualiza um checkout limpo,
envia um branch dedicado e abre o pull request:

```console
boss4d publish --official --open-pr \
  --publisher meu-publisher \
  --repository github.com/owner/meu-pacote \
  --fingerprint 0123456789ABCDEF0123456789ABCDEF01234567 \
  --sign 0123456789ABCDEF0123456789ABCDEF01234567 \
  --artifact-url https://github.com/owner/meu-pacote/releases/download/v1.0.0/MeuPacote-1.0.0.b4dpkg \
  --registry-root /src/Boss4Delphi
```

Para um fork, selecione seu remote Git e informe o head da PR:
`--registry-remote fork --registry-pr-head owner:branch`. A CLI adiciona ao
staging somente o arquivo do pacote e `registry/index-v2.json`. Execute antes
com `--dry-run`; nenhum artefato, alteração no checkout, branch, push ou pull
request será criado.
Envie o pacote, assinatura e proveniência gerados para as URLs imutáveis
declaradas antes do merge do pull request.

O gerador PowerShell continua disponível para mantenedores que precisam
preparar os metadados sem compilar ou assinar o pacote:

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

Para a release seguinte, repita as evidências com a mesma identidade e use
`-AppendVersion`:

```powershell
./scripts/new-registry-submission.ps1 `
  -PackageName MeuPacote -Publisher meu-publisher `
  -Repository github.com/owner/meu-pacote `
  -SignerFingerprint 0123456789ABCDEF0123456789ABCDEF01234567 `
  -Version 1.1.0 `
  -Artifact https://github.com/owner/meu-pacote/releases/download/v1.1.0/MeuPacote-1.1.0.b4dpkg `
  -Sha256 <64-caracteres-hexadecimais> `
  -Signature https://github.com/owner/meu-pacote/releases/download/v1.1.0/MeuPacote-1.1.0.b4dpkg.asc `
  -Provenance https://github.com/owner/meu-pacote/releases/download/v1.1.0/MeuPacote-1.1.0.b4dpkg.intoto.json `
  -AppendVersion
```

O modo append preserva todas as versões existentes, rejeita SemVer duplicado e
não permite trocar identidade, repositório ou signatário do pacote.

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
