# Política de resolução e credenciais seguras

Instalações podem escolher explicitamente como uma faixa SemVer compatível é
resolvida:

```text
boss4d install --resolution highest
boss4d install --resolution minimal
```

`highest` é o padrão e seleciona a maior versão compatível conforme a ordenação
SemVer. `minimal` seleciona a menor versão compatível, independentemente da
ordem retornada pelo Git. Tags inválidas ou fora da faixa são ignoradas. A
revisão selecionada continua registrada no lock.

Tokens configurados por `boss4d config auth` ficam no Windows Credential
Manager sob `Boss4D/github` e `Boss4D/gitlab`. O `boss.cfg.json` contém somente
configurações não secretas. O contrato do cofre é portável para que hosts Linux
usem Secret Service ou outro cofre nativo sem alterar os serviços de
configuração ou Git.

Segredos são injetados somente ao preparar URLs Git autenticadas e são
mascarados nas falhas. Não versione exportações do cofre nem passe tokens
diretamente como argumentos em CI; prefira o cofre da plataforma ou credenciais
temporárias de ambiente.

Na CLI nativa Linux/FPC, os tokens ficam no Secret Service via `secret-tool` e
são enviados ao cofre por stdin. `BOSS4D_GITHUB_TOKEN`, `GITHUB_TOKEN`,
`BOSS4D_GITLAB_TOKEN` e `GITLAB_TOKEN` têm precedência em CI. A autenticação Git
é configurada no ambiente do processo, sem incluir o token na URL.
