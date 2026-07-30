# Ciclo de vida de dependências

O Boss4D oferece comandos explícitos para alterar e consultar o grafo de
dependências do projeto:

```console
boss4d add github.com/hashload/horse@^3.1.0
boss4d update horse
boss4d update github.com/hashload/horse@^3.2.0
boss4d list
boss4d why horse
boss4d remove horse
```

## Garantias transacionais

Os comandos que instalam, atualizam ou removem pacotes criam um snapshot de
`boss.json`, `boss-lock.json` e `modules/` antes da alteração. Se houver falha de
resolução, checkout, integridade ou compilação, o Boss4D restaura os arquivos e
módulos anteriores. Em caso de sucesso, as três partes são confirmadas juntas.

O comando `remove` também elimina do lock as dependências transitivas que
deixaram de ser alcançáveis pelas dependências diretas e exclui seus diretórios
de módulo. Uma dependência transitiva compartilhada permanece no lock enquanto
ainda for utilizada.

## Consultas

`list` mostra a versão resolvida e classifica cada item como `direct` ou
`transitive`. `why <dependência>` mostra o caminho mais curto entre uma
dependência direta e o pacote consultado. Os dois comandos apenas leem o grafo
resolvido e não alteram o projeto.

`install <dependência>` continua compatível e recebe as mesmas garantias
transacionais de `add`.
