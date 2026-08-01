# Exemplo de toolchain e projetos declarados

Copie o `boss.json` para a raiz de um pacote e ajuste os nomes dos projetos. O
Boss4D compila somente os arquivos declarados, na ordem informada.
`runtime.dproj` usa Delphi/MSBuild e `runtime.lpk` usa Lazarus/lazbuild.

Em um projeto Lazarus raiz, `boss4d install` também mescla os diretórios das
units resolvidas em cada seção
`CompilerOptions/SearchPaths/OtherUnitFiles`. Os paths existentes são
preservados e instalações repetidas são idempotentes.

```powershell
boss4d install
boss4d install --platform Win32
```

A plataforma informada na CLI prevalece sobre o manifesto. Dois repositórios
com o mesmo nome-base podem coexistir porque os diretórios físicos incluem um
hash do repositório.
