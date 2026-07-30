# Submissão ao GitHub Dependency Graph

O Boss4D envia o grafo resolvido do lock para a Dependency Submission API:

```console
set GITHUB_TOKEN=github-token
boss4d dependency submit ^
  --repo owner/repositorio ^
  --sha 0123456789abcdef0123456789abcdef01234567 ^
  --ref refs/heads/main ^
  --job-id boss4d-ci
```

`--token-env` altera o nome da variável de ambiente; o token nunca é salvo nem
registrado nos logs. A credencial precisa das permissões exigidas pelo GitHub
para gravar snapshots de dependências.

O snapshot usa Package URLs genéricos, identifica raízes diretas, preserva o
escopo runtime/desenvolvimento e inclui arestas transitivas do lock v3. Informe
o SHA e a referência Git exatos do build reportado.
