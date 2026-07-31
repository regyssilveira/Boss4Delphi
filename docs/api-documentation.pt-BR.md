# Documentação estática de APIs

O comando `boss4d doc` transforma comentários do código Pascal em um site local
e pesquisável. Ele é útil quando o projeto consome várias bibliotecas e a equipe
precisa consultar, em um único lugar, o código da aplicação e suas dependências.

## Por que gerar a documentação a partir das dependências?

Documentações de API frequentemente estão espalhadas entre repositórios,
correspondem a outra versão ou não estão disponíveis em ambientes offline. O
Boss4D gera a referência usando exatamente os fontes presentes no workspace.
O resultado pode ser arquivado com o build, consultado offline ou publicado
pelo CI.

Esta feature complementa SBOM e auditoria. O SBOM identifica o que existe na
release; a documentação explica a superfície de programação documentada. Ela
não substitui SBOM, VEX, relatório de licenças ou auditoria de vulnerabilidades.

## Comentários e declarações reconhecidos

O Boss4D lê arquivos Delphi/FPC `.pas` e `.pp` e associa o comentário à próxima
declaração suportada:

- comentários XML Doc `///`, incluindo textos em `<summary>`;
- blocos PascalDoc `{** ... }`;
- units, programs, libraries e packages;
- classes, records, interfaces e objects;
- procedures, functions, constructors, destructors e operators;
- properties.

Tags HTML são removidas e todos os metadados são escapados na saída HTML. O
texto da documentação nunca é inserido como marcação executável.

## Gerando o site

Execute na raiz do projeto:

```console
boss4d doc
```

A saída padrão é:

```text
docs-api/
├── index.html
└── search-index.json
```

Abra `index.html` diretamente no navegador. A página não precisa de servidor e
filtra símbolos por nome, tipo, arquivo-fonte ou resumo.

Escolha outro diretório com qualquer uma das formas:

```console
boss4d doc --output artifacts/api
boss4d doc -o artifacts/api
```

Por padrão, `modules/` é incluído. Para documentar apenas o projeto atual:

```console
boss4d doc --no-dependencies
```

O comando está disponível nas CLIs nativas Delphi/Windows e FPC/Linux.

## Situações cotidianas

### Consultar a API disponível para a aplicação travada

```console
boss4d ci
boss4d doc --output artifacts/api
```

Restaurar primeiro garante que o site descreva os mesmos fontes usados pelo
build reproduzível.

### Publicar documentação pelo CI

```console
boss4d ci
boss4d doc --output public/api
```

Publique `public/api` como artefato ou site estático. Os dois arquivos são
determinísticos para a mesma árvore documentada e ordem de varredura.

### Consumir o índice legível por máquina

`search-index.json` contém `schemaVersion`, `symbolCount` e o array `symbols`.
CI ou outras ferramentas podem consumi-lo sem analisar HTML. Atualmente o
Boss4D indexa símbolos documentados; ainda não calcula a cobertura das
declarações sem documentação.

## Regras de varredura e segurança

O gerador pesquisa recursivamente, mas exclui:

- o diretório de saída escolhido;
- `.git`, `.codex-build` e `.ci-build`;
- diretórios Delphi `__history` e `__recovery`;
- `modules/` quando `--no-dependencies` é usado.

Tags são removidas e os valores são escapados no HTML. O gerador não executa
código-fonte nem documentação fornecida pelos pacotes.

## Limites atuais

- o parser é orientado a declarações e não substitui um compilador Pascal;
- apenas comentários associados imediatamente às declarações são indexados;
- referências cruzadas, visibilidade, overloads e diagramas ainda não são
  modelados;
- normalmente os arquivos gerados devem ser tratados como artefatos.

Consulte o [manual completo da CLI](usage.pt-BR.md) e a
[CLI FPC/Linux](posix-cli.pt-BR.md).
