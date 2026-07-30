# CLI FPC/Linux

O Boss4D inclui um host nativo em FPC 3.2.2, compilado e testado no Linux em
vez de apenas cross-compiled no Windows:

```powershell
./scripts/ci-fpc-linux.ps1
```

O script usa a imagem Docker existente `fpc-test:latest`, gera um executável
Linux x86-64, executa a suíte FPCUnit e valida `version` e `platform`.

O host portável atualmente oferece:

- `version` e `platform`;
- `init`, produzindo um `boss.json` compatível;
- `install`, clonando dependências Git declaradas para `modules`.

Nome do diretório da dependência, argumentos de clone com tag exata, parsing
do manifesto e detecção de plataforma possuem cobertura FPCUnit. O CLI Windows
continua sendo o host completo para integração IDE/GetIt, coleta de toolchain
no SBOM, mutação do registro e autoatualização. Essas capacidades são
declaradas indisponíveis no POSIX até existirem adaptadores portáveis; o
comportamento do Windows Registry não é simulado.
