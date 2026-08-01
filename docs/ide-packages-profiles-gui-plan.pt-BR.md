# Plano de packages, perfis isolados e GUI

Este documento é o mapa oficial de implementação e aceite do goal de maturidade
na instalação de componentes.

## Estado da entrega

As fases 1 a 5 e os gates originais de validação foram concluídos e integrados
em 31 de julho de 2026 pelo pull request 48. A tabela de lacunas abaixo preserva
o ponto de partida histórico; ela não representa o estado atual do produto. As
evidências atuais incluem:

- identidades runtime/design tipadas e planos determinísticos de componentes;
- instalação, reparo e remoção com preview, lock e transação;
- perfis isolados com targets, clone, import/export, snapshot, diff, restore,
  histórico, undo e abertura com `/r:`;
- serviços compartilhados e presenters testáveis para CLI e GUI;
- fluxos GUI para packages, targets, perfis, preview, políticas, instalação,
  reparo, remoção, snapshots e histórico;
- 332 testes Delphi 13 aprovados em Win32 e Win64, 74 testes FPC, artefatos do
  Registry validados, CI FPC em Linux/macOS e Quality Gate Sonar limpo.

As melhorias de experiência visual posteriores à entrega são acompanhadas
separadamente no [Épico 24 do backlog](backlog.pt-BR.md).

## Evidência inicial e lacunas

O Boss4D já possui matriz runtime/design, detecção de `.dpk`, grafo e build
paralelo, artefatos isolados, registro exato, snapshots do Registro, rollback,
reparo ativo, uninstall seguro, conflitos e ativos como DLL, CHM, ferramentas e
templates.

A tabela abaixo registra as lacunas identificadas antes da implementação:

| Área | Estado atual | Lacuna |
|---|---|---|
| Runtime/design | `kind` textual e dependências no grafo | Falta identidade tipada, plano de instalação e estado completo do componente |
| Transação da IDE | Registro exato e rollback | Falta contexto de perfil, preview, lock entre processos e política para IDE aberta |
| Perfis | Store aceita apenas o HKEY raiz | Não há perfil nomeado, Registry branch alternativo, inventário próprio, migração, clone ou `/r:` |
| Arquitetura da GUI | Um form VCL chama serviços | O form lê JSON, instancia infraestrutura, altera o diretório global e não possui apresentação testável |
| Cobertura da GUI | Projeto, catálogo, doctor e cache | Faltam targets, packages, perfis, preview, install/update/repair/uninstall e progresso estruturado |

## Decisões obrigatórias

1. Regras ficam em domínio e serviços de aplicação independentes da interface.
2. CLI, wizard e GUI usam os mesmos contratos.
3. Perfil passa a fazer parte da identidade e da propriedade do registro.
4. A instalação atual será migrada para o perfil `default`.
5. Forms não montam keys do Registro nem alteram arquivos diretamente.
6. Toda mutação gera primeiro um plano imutável de preview.
7. Arquivos, Registro, inventários e perfil formam uma única transação.
8. Testes usam adapters falsos; Registro real somente em subárvore HKCU descartável.
9. IDEs ausentes são modeladas e testadas, mas não certificadas.
10. Nenhuma feature será commitada sem testes unitários correspondentes.

## Fase 1 — packages runtime/design

- criar roles tipados preservando compatibilidade JSON;
- definir identidade por owner, package/BPL, role, compiler, plataforma,
  configuração e perfil;
- validar direção e compatibilidade das dependências runtime/design;
- detectar colisões de BPL antes de compilar;
- aceitar metadados opcionais de paleta/registro;
- gerar plano determinístico de build e instalação;
- expor estados declarado, compilado, instalado, divergente e quebrado;
- preservar application/tool/binary e C++Builder experimental.

Aceite: testes de detecção, identidade, grafo, sufixos, duplicidade,
incompatibilidade, migração e determinismo.

## Fase 2 — instalação transacional completa

- preview/dry-run de builds, arquivos, Registro, conflitos e remoções;
- lock entre processos por perfil/toolchain;
- política para IDE aberta: falhar, adiar ou forçar explicitamente;
- install/update/reinstall idempotentes;
- runtime e design na mesma operação de produto;
- paths compartilhados e arquivos não gerenciados preservados;
- repair recompila o target exato;
- remoção por target, produto e cascata;
- resultado persistido com instrução de recuperação.

Aceite: fault injection em cada fronteira, rollback integral, reinstalação sem
mutação adicional e `doctor -> repair -> doctor` limpo.

## Fase 3 — perfis isolados

Campos: id, nome, descrição, BDS/compiler, executável, Registry branch,
plataforma/configuração padrão, inventário, packages e versão do schema.

CLI:

```console
boss4d ide profile list
boss4d ide profile create <nome> --compiler <versao>
boss4d ide profile show <nome>
boss4d ide profile clone <origem> <destino>
boss4d ide profile remove <nome>
boss4d ide profile export <nome> --output <arquivo>
boss4d ide profile import <arquivo>
boss4d ide profile install <nome> <pacote>
boss4d ide profile repair <nome>
boss4d ide profile launch <nome>
```

Aceite: dois perfis da mesma IDE mantêm packages diferentes; modificar ou
remover um nunca altera o outro; migração para `default` preserva registros.

## Fase 4 — serviços compartilhados

- DTOs para IDEs, perfis, produtos, packages, targets, drift e operações;
- casos de uso para plano, install, update, repair, uninstall e perfis;
- progresso estruturado, cancelamento e códigos de recuperação;
- CLI, wizard e GUI passam a usar a mesma orquestração;
- eliminar alteração do current directory global.

Aceite: serviços testáveis sem VCL/ToolsAPI/Registro real e resultados iguais
entre CLI e GUI.

## Fase 5 — GUI

- dashboard de IDEs, perfis, produtos e divergências;
- catálogo com instalação no perfil selecionado;
- detalhe do componente com grafo runtime/design e targets;
- gestão de perfis, comparação, import/export e launch;
- preview de builds, arquivos, Registro, conflitos e remoções;
- diagnóstico e reparo;
- progresso estruturado, cancelamento e navegação até artefatos.

Forms usarão apenas presenters/view models. Nenhuma regra ou mutação ficará
exclusivamente na interface.

## Documentação, validação e fechamento

- atualizar documentação e exemplos em português e inglês;
- testar automaticamente todos os manifestos de exemplo;
- suíte Delphi Win32/Win64;
- CLI e GUI Delphi 13 Win32/Win64;
- plugin Delphi 10/11/12/13 disponíveis;
- integração em Registro descartável com `default` e dois perfis;
- FPC/Linux Docker verde;
- Sonar com Quality Gate `OK` e zero issues;
- commits e pushes incrementais, worktree limpo e auditoria requisito por
  requisito.

