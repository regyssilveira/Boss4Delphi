# Progresso no terminal

O Boss4D expõe o progresso da instalação como eventos estruturados. Assim,
pessoas, pipelines de CI e automações observam a mesma operação sem interpretar
mensagens incidentais de log.

## Modos de saída

```text
boss4d install --progress interactive
boss4d install --progress plain
boss4d install --json
boss4d install --quiet
boss4d ci --json
```

- `interactive` atualiza operações ativas na mesma linha quando a saída é um terminal.
- `plain` produz linhas estáveis e é o modo padrão.
- `--json` produz um objeto JSON válido por evento (JSON Lines).
- `--quiet` desativa os eventos de progresso.

Cada evento contém `operationId`, `package`, `phase`, `current`, `total`,
`message` e `timestamp` em ISO 8601. Total igual a zero significa que o volume
de trabalho ainda é desconhecido. As fases cobrem resolução, download,
verificação, instalação, compilação, uso do cache, conclusão e falha.

A saída de progresso nunca contém credenciais de repositório ou tokens de
autenticação. JSON Lines foi pensado para coletores de CI; logs de diagnóstico
comuns ainda podem ser produzidos separadamente.

## Compatibilidade

Quando a saída é redirecionada, o modo `interactive` automaticamente usa linhas
completas. Downloads concorrentes compartilham um reporter thread-safe, evitando
eventos intercalados ou JSON inválido.
