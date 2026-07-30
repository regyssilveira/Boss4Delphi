# Dependências de runtime e desenvolvimento

O Boss4D separa dependências entregues das ferramentas de desenvolvimento:

```json
{
  "dependencies": {"github.com/hashload/horse": "^3.1.0"},
  "devDependencies": {"github.com/example/test-kit": "1.0.0"}
}
```

Use `boss4d add <pacote> --dev` para uma dependência de desenvolvimento. Um
`install` normal resolve os dois escopos. `install --production` e
`ci --production` instalam apenas runtime.

O schema v3 do lock registra `runtime` ou `development` em cada pacote e mantém
listas separadas na raiz. CycloneDX exporta `boss4d:scope`; SPDX 2.3 exporta o
escopo no comentário do pacote.
