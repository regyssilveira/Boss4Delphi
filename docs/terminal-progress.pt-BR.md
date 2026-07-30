# Progresso no terminal

O Boss4D expõe o andamento como eventos estruturados, permitindo que pessoas,
CI e automações observem a mesma operação sem interpretar logs incidentais.

```text
boss4d install --progress interactive
boss4d install --progress plain
boss4d install --json
boss4d install --quiet
boss4d ci --json
```

- `interactive` atualiza operações ativas no terminal;
- `plain` produz linhas estáveis e é o padrão;
- `--json` produz um objeto JSON válido por evento;
- `--quiet` desativa os eventos.

Cada evento contém `operationId`, `package`, `phase`, `current`, `total`,
`message` e `timestamp` ISO 8601. As fases cobrem resolução, download,
verificação, instalação, compilação, cache, conclusão e falha. A saída nunca
contém tokens ou credenciais.

A CLI nativa Linux/FPC oferece os mesmos modos em `install`, `ci` e
`package install`. `SIGINT`/Ctrl+C solicita cancelamento cooperativo; o comando
para em um limite seguro e retorna 130.

## Códigos de saída estáveis

| Código | Significado |
|---:|---|
| 0 | Sucesso |
| 1 | Falha geral ou de ambiente |
| 2 | Comando, opção ou uso inválido |
| 3 | Pacote não encontrado |
| 4 | Rejeição de integridade, assinatura, proveniência ou caminho inseguro |
| 5 | Falha de rede ou cache offline |
| 130 | Cancelamento pelo usuário |

Saída redirecionada sempre usa linhas completas. Eventos concorrentes não podem
produzir JSON intercalado.
