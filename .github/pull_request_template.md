## 📝 Descrição do PR
Descreva de forma sucinta o que este Pull Request altera, corrige ou implementa.

## 🔗 Issues Relacionadas
Indique a issue que este PR resolve (ex: `Fixes #123`, `Resolves #45`).

## 🛠️ Tipo de Alteração
- [ ] 🐛 Bugfix (correção de erro existente)
- [ ] ✨ Feature (nova funcionalidade)
- [ ] ⚡ Refatoração ou Melhoria de Desempenho
- [ ] 📚 Documentação (README, comentários, etc.)

## 🧪 Checklist de Qualidade de Código (Delphi 13)
Antes de enviar o PR, por favor marque todas as opções válidas:
- [ ] **Compilação**: O código compila sem erros ou warnings no Delphi 12 e Delphi 13.
- [ ] **Testes de Regressão (TDD para Bugs)**: Se for uma correção de bug, foi criado um teste unitário na suite do DUnitX que reproduzia o erro *antes* de aplicar a correção lógica.
- [ ] **Suíte de Testes**: Todos os testes unitários (DUnitX) passam com sucesso absoluto.
- [ ] **Memory Leaks**: Validei que a execução do projeto e testes não gera vazamentos de memória (Memory Leaks).
- [ ] **Princípios S.O.L.I.D.**: O design de classes e interfaces foi respeitado.
- [ ] **Limpeza de Recursos**: Todo objeto criado localmente está devidamente protegido por blocos `try..finally` para desalocação segura.
- [ ] **Nomenclatura**: Adotei a padronização namespace `Boss4D.Core.*` e nomenclatura de classes `T/I` + `Boss4D`.
