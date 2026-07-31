# Casos de uso de projeto e dependências

Estes casos cobrem as operações com maior chance de alterar `boss.json`,
`boss-lock.json`, `modules/` ou o cache compartilhado.

## 1. Adotar o Boss4D em um projeto existente

**Situação:** o repositório já possui projetos Delphi, mas ainda não tem
manifest do Boss4D.

**Antes de começar:** use uma árvore Git limpa e execute na raiz do
repositório.

```powershell
boss4d init
boss4d doctor
git diff -- boss.json boss-lock.json
```

**Resultado esperado:** `boss.json` existe, `doctor` identifica a instalação
Delphi pretendida e o diff não contém caminhos específicos da máquina.

**Controles de risco:** não apague um `boss.json` compatível já existente; o
Boss4D preserva mapas string/string legados. Revise nome, versão, plataforma e
toolchain antes de adicionar dependências.

**Recuperação:** restaure somente o manifest recém-gerado se a inicialização
ocorreu no diretório errado e repita na raiz correta.

## 2. Adicionar dependência de runtime com faixa explícita

**Situação:** a aplicação precisa de uma biblioteca como Horse.

```powershell
boss4d add github.com/hashload/horse@^3.1.0
boss4d tree
git diff -- boss.json boss-lock.json
```

**Resultado esperado:** o manifest registra a faixa solicitada, o lock registra
a revisão e as evidências exatas e `tree` mostra a dependência.

**Controles de risco:** prefira uma faixa compatível explícita a um padrão sem
limite. Versione manifest e lock na mesma alteração.

**Recuperação:** se a resolução escolher versão inadequada, não edite o lock
manualmente. Remova ou altere a restrição e resolva novamente.

## 3. Adicionar ferramenta somente de desenvolvimento

**Situação:** testes ou geração de código precisam de uma dependência que não
deve entrar no ambiente de produção.

```powershell
boss4d add github.com/example/test-tool@^2.0.0 --dev
boss4d install --production
```

**Resultado esperado:** o pacote fica em `devDependencies`; a instalação de
produção não o inclui.

**Controles de risco:** nunca coloque units exigidas em runtime no escopo de
desenvolvimento.

**Recuperação:** remova e adicione novamente sem `--dev` se a compilação de
produção precisar do pacote.

## 4. Reproduzir o build da equipe na CI

**Situação:** a CI deve usar exatamente o grafo revisado no pull request.

```powershell
boss4d install --locked
```

Para runner isolado da rede com cache previamente preenchido:

```powershell
boss4d install --locked --offline
```

**Resultado esperado:** a instalação termina sem alterar `boss-lock.json`.
Drift do manifest, lock ausente ou conteúdo offline indisponível falham o job.

**Controles de risco:** não substitua `--locked` por instalação livre em
pipeline de release. Trate qualquer diff do lock produzido pela CI como falha.

**Recuperação:** regenere o lock em uma máquina de desenvolvimento, revise,
versione, preencha o cache do runner quando necessário e repita a CI.

## 5. Atualizar uma dependência sem mover todo o grafo

**Situação:** um pacote precisa de atualização controlada.

```powershell
boss4d outdated
boss4d why horse
boss4d update horse
boss4d tree
git diff -- boss.json boss-lock.json
```

Para mudar deliberadamente a faixa permitida:

```powershell
boss4d update github.com/hashload/horse@^3.2.0
```

**Resultado esperado:** apenas o pacote pretendido e mudanças transitivas
inevitáveis avançam.

**Controles de risco:** revise os diffs do manifest e do lock. Rode os testes do
projeto antes de aceitar atualização transitiva.

**Recuperação:** reverta manifest e lock juntos; a próxima instalação travada
restaura o grafo anterior.

## 6. Descobrir por que um pacote transitivo está instalado

**Situação:** licença, vulnerabilidade ou conflito cita pacote não declarado
diretamente.

```powershell
boss4d why nome-do-pacote
boss4d tree
boss4d audit
```

**Resultado esperado:** `why` identifica o caminho da dependência e `tree`
fornece o contexto completo.

**Controles de risco:** não remova conteúdo transitivo diretamente de
`modules/`. Altere a dependência direta responsável ou sua restrição.

**Recuperação:** se o grafo divergir do lock, faça uma instalação travada antes
de continuar a investigação.

## 7. Trabalhar sem acesso à rede

**Situação:** ambiente corporativo ou viagem sem acesso ao Registry/Git.

```powershell
boss4d cache size
boss4d install --locked --offline
```

**Resultado esperado:** todos os pacotes travados são restaurados do cache
local verificado.

**Controles de risco:** teste o restore offline antes de desconectar. Não use
`cache clean`, pois ele remove a fonte de recuperação.

**Recuperação:** reconecte em rede confiável, execute uma vez a instalação
travada para preencher entradas ausentes e tente novamente offline.

## 8. Recuperar cache possivelmente corrompido

**Situação:** a verificação falha para conteúdo que deveria corresponder ao
lock.

```powershell
boss4d doctor
boss4d cache size
boss4d cache prune
boss4d install --locked
```

Use `boss4d cache clean` somente quando for possível baixar o cache novamente.

**Resultado esperado:** entradas inválidas ou sem uso são removidas e
artefatos verificados são obtidos novamente.

**Controles de risco:** manutenção do cache afeta a máquina inteira. Não limpe
agentes compartilhados ou offline durante uma release.

**Recuperação:** restaure o cache de backup confiável ou preencha novamente
online; nunca ignore a verificação de digest.

## 9. Remover uma dependência com segurança

**Situação:** um pacote direto não é mais referenciado pelo projeto.

```powershell
boss4d why nome-do-pacote
boss4d remove nome-do-pacote
boss4d install --locked
boss4d tree
git diff -- boss.json boss-lock.json
```

**Resultado esperado:** a entrada direta desaparece e transitivas sem uso são
removidas do grafo resolvido.

**Controles de risco:** pesquise o código e os arquivos de projeto antes da
remoção. Compile todos os targets suportados depois da mudança.

**Recuperação:** reverta manifest e lock juntos e execute instalação travada.

## Tabela de decisão cotidiana

| Necessidade | Comando |
|---|---|
| Restaurar dependências revisadas | `boss4d install --locked` |
| Comprovar build offline | `boss4d install --locked --offline` |
| Ver atualizações disponíveis | `boss4d outdated` |
| Explicar um pacote | `boss4d why <nome>` |
| Inspecionar o grafo | `boss4d tree` |
| Remover entradas de cache sem uso | `boss4d cache prune` |
| Diagnosticar ambiente e projeto | `boss4d doctor` |

Veja também [ciclo de dependências](dependency-lifecycle.pt-BR.md),
[escopos de dependência](dependency-scopes.pt-BR.md),
[instalação reproduzível](reproducible-install.pt-BR.md) e
[estratégia de cache](cache-strategy.pt-BR.md).

