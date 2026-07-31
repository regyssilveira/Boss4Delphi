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

## 📦 Submissões ao Registry

Preencha somente quando a PR altera `registry/`:

- [ ] A PR foi aberta por uma conta registrada em `githubOwners`.
- [ ] O nome do arquivo do pacote está normalizado e consta em `index-v2.json`.
- [ ] Cada versão possui `.b4dpkg`, SHA-256, assinatura OpenPGP e proveniência in-toto.
- [ ] Não alterei nem removi uma versão ou entrada sparse já publicada.
- [ ] Usei `new-registry-submission.ps1` para uma entrada nova ou preservei integralmente as versões existentes.
- [ ] Executei `./scripts/validate-registry-submission.ps1 -Submitter <meu-login>` e `./scripts/test-registry-submission.ps1`.
