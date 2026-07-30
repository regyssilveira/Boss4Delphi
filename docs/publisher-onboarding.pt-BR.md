# Onboarding de publishers

O Registry público é mantido por pull requests Git revisados. Um publisher não
pode enviar metadados mutáveis diretamente ao repositório.

## Primeiro cadastro

1. Adicione uma entrada única em `registry/publishers.json`.
2. Declare somente prefixos de repositórios controlados pelo publisher.
3. Adicione ao menos um fingerprint OpenPGP completo de 40 caracteres em
   `allowedSigners`.
4. Copie `registry/package-template.json` para
   `registry/packages/<nome-normalizado>.json`.
5. Preencha `publisher` e `signerFingerprint` com valores cadastrados.
6. Adicione `packages/<nome-normalizado>.json` em `sparse` no
   `registry/index-v2.json`.
7. Abra um pull request.

Cada versão exige o `.b4dpkg`, seu SHA-256 exato, assinatura OpenPGP destacada
e proveniência in-toto. Escopo do repositório, autorização do signatário,
versão semântica, variantes e evidências são verificados automaticamente.

## Imutabilidade

Objetos de versões existentes não podem ser alterados nem removidos. O
publisher adiciona outra versão ou envia uma revogação no índice raiz. O check
do pull request compara a submissão com o branch de destino; mudanças em
checksum, URL, assinatura, proveniência ou seletores de uma versão existente
falham.

Execute localmente:

```powershell
./scripts/validate-registry-submission.ps1
./scripts/test-registry-submission.ps1
```

A aprovação no Registry estabelece a política do catálogo; durante a
instalação, o cliente ainda verifica checksum, assinatura OpenPGP e
proveniência.
