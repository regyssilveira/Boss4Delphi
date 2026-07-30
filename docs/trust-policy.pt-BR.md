# Política de confiança de assinaturas Git

O projeto pode exigir verificação criptográfica antes do checkout:

```json
{
  "trust": {
    "requireSignedCommits": true,
    "requireSignedTags": true,
    "allowedSigners": ["release@example.com"]
  }
}
```

O Boss4D executa `git verify-commit` e `git verify-tag` no repositório em cache.
Quando `allowedSigners` não está vazio, o signatário informado pelo Git precisa
corresponder a uma entrada. Uma falha interrompe a instalação antes do checkout
e aciona o rollback do projeto.

A validade depende da configuração de confiança Git/GPG ou SSH do usuário. O
Boss4D não baixa chaves nem estabelece confiança silenciosamente.
